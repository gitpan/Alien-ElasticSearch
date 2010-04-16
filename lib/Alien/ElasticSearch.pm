package Alien::ElasticSearch;

use warnings;
use strict;
use File::Temp();
use File::Spec::Functions qw(catfile splitdir rel2abs catdir devnull);

=head1 NAME

Alien::ElasticSearch - Downloads, builds and installs ElasticSearch from github

=head1 VERSION

Version 0.10

=cut

our $VERSION = '0.10';
our $DOWNLOAD_URL
    = 'http://github.com/downloads/elasticsearch/elasticsearch/elasticsearch-';
our $TAG_URL       = 'http://github.com/elasticsearch/elasticsearch/zipball/';
our $VERSION_REGEX = qr/^\d+\.\d+.\d+$/;

=head1 SYNOPSIS

    # install latest version from Git to $install_dir
    $install_dir = Alien::ElasticSearch->install(
        dir     => '/path/to/elasticsearch',
        version => '0.6.0',           # released version
      | tag     => 'master',          # or a git tag or sha1
        plugins => ['attachments'],
        user    => 'elasticsearch',   # unix/linux only
        group   => 'users',           # unix/linux only
        temp    => 1 | 0              # do installation, but don't store config
    );

    # upgrade existing installation
    $install_dir = Alien::ElasticSearch->upgrade(
        tag     => 'master'           # accepts same args as install()
    );

    # get/set current install dir
    $install_dir = Alien::ElasticSearch->install_dir($install_dir);

    # get/set current version
    $version = Alien::ElasticSearch->version($version);

    # get/set current plugins
    $plugins = Alien::ElasticSearch->plugins(\@plugin_names);

    # get/set current user
    $user = Alien::ElasticSearch->user($user);

    # get/set current group
    $group = Alien::ElasticSearch->group($group);

=head1 DESCRIPTION

This module handles downloading ElasticSearch from github, building,
and installing it.

It then writes a config file to remember where it was installed.

It also adds a script called C<install_elasticsearch.pl> into your perl bin
directory, which can be called as follows:

    install_elasticsearch.pl              # upgrade existing installation
    install_elasticsearch.pl --dir /path  # install to /path

To see all available options, try:

    install_elasticsearch.pl --help

=head1 REQUIREMENTS

=over

=item  * Java version 6 or above

=back

=head1 SEE ALSO

L<ElasticSearch>

=cut

#===================================
sub install_dir {
#===================================
    my $self = shift;
    my $dir = $self->_get_set_key( 'install_dir', @_ );
    return undef unless $dir && -d $dir;
    return $dir;
}

#===================================
sub version { return shift->_get_set_key( 'version', @_ ) }
sub user    { return shift->_get_set_key( 'user',    @_ ) }
sub group   { return shift->_get_set_key( 'group',   @_ ) }
#===================================

#===================================
sub plugins {
#===================================
    my $class = shift;
    my @args = ref $_[0] eq 'ARRAY' ? @{ $_[0] } : @_;
    return $class->_get_set_key( 'plugins', @args ? \@args : () ) || [];
}

#===================================
sub install {
#===================================
    my $class = shift;

    my %args
        = @_ != 1 ? @_
        : ref $_[0] eq 'HASH' ? %{ $_[0] }
        :                       { dir => shift };

    $class->check_for_java
        unless $args{skip_java_check};

    my $dest_dir = $args{dir} or die "No installation path specified";
    die "Trying to do a temp install but dir $dest_dir is not empty"
        if $args{temp} && -e $dest_dir && glob( catfile( $dest_dir, '*' ) );

    my $dir = File::Temp->newdir();
    my @plugins = sort @{ $args{plugins} || [] };
    my $plugin_desc
        = @plugins
        ? 'with plugins: ' . join( ', ', @plugins )
        : 'without plugins';

    my $version = $args{version};
    my $main_dir;
    if ($version) {
        print "\n"
            . "Installing ElasticSearch version $version to "
            . "$dest_dir $plugin_desc" . "\n\n";
        $main_dir = $class->_download_version( $dir, $version, \@plugins );
    }
    else {
        my $tag = $args{tag} || 'master';
        print "\n"
            . "Installing ElasticSearch tag '$tag' to "
            . "$dest_dir $plugin_desc" . "\n\n";
        my $paths = $class->_build_from_source( $dir, $tag, \@plugins );
        $main_dir = $paths->{main_dir};
        $version  = $paths->{version};
    }

    $class->_install( $main_dir, $dest_dir );
    $class->_chown( $dest_dir, $args{user}, $args{group} );
    print "\nElasticSearch version $version installed "
        . "to $dest_dir $plugin_desc\n\n";

    unless ( $args{temp} ) {
        print "Storing installation settings\n";
        $class->install_dir($dest_dir);
        $class->version($version);
        $class->plugins( \@plugins );
        $class->user( $args{user} );
        $class->group( $args{group} );
    }
    return $dest_dir;
}

#===================================
sub _download_version {
#===================================
    my ( $class, $dir, $version, $plugins ) = @_;

    die "Unrecognised version format: '$version'"
        unless $version =~ /$VERSION_REGEX/;

    my $main_dir = $class->_download( $DOWNLOAD_URL . $version . '.zip', $dir,
        'unpack' );

    my $plugin_dir = $class->_create_plugins_dir($main_dir);

    for (@$plugins) {
        print "Installing plugin '$_'\n";
        my $url = $DOWNLOAD_URL . $_ . '-' . $version . '.zip';
        $class->_download( $url, $plugin_dir );
    }

    return $main_dir;
}

#===================================
sub _build_from_source {
#===================================
    my ( $class, $dir, $tag, $plugins ) = @_;

    die "Unrecognised tag format: '$tag"
        unless $tag =~ /^[a-z0-9._-]+$/;

    my $download_dir = File::Temp->newdir;
    my $source_dir
        = $class->_download( $TAG_URL . $tag, $download_dir, 'unpack' );
    my $paths = $class->_build($source_dir);

    $paths->{main_dir} = $class->_unpack( $paths->{archive}, $dir );
    my $plugin_dir = $class->_create_plugins_dir($dir);

    foreach (@$plugins) {
        print "Installing plugin '$_'\n";
        my $archive = $paths->{plugins}{$_}
            or die "Plugin '$_' not built. Available plugins: "
            . join( ', ', sort keys %{ $paths->{plugins} } );
        $class->_move( $archive, $plugin_dir );
    }
    return $paths;
}

#===================================
sub _install {
#===================================
    my ( $class, $source_dir, $dest_dir ) = @_;
    if ( -e $dest_dir ) {
        die "$dest_dir already exists but is not a directory"
            unless -d _;

        for my $file (qw(elasticsearch.yml logging.yml)) {
            my $dest_file = catfile( $dest_dir, 'config', $file );
            next unless -e $dest_file;
            print "Config file $dest_file exists.\n"
                . " -> Creating as $dest_file.orig\n";
            my $source_file = catfile( $source_dir, 'config', $file );
            rename $source_file, "$source_file.orig"
                or die "Couldn't rename $source_file : $!";
        }
    }
    print "Installing to $dest_dir";
    $class->_move( $source_dir, $dest_dir );
}

#===================================
sub _chown {
#===================================
    my ( $class, $dir, $user, $group ) = @_;
    return unless $user || $group;
    if ( $^O !~ /^(unix|linux)$/ ) {
        warn "Cannot chown dir $dir - not supported on $^O";
        return;
    }

    if ($>) {
        warn "Cannot chown $dir - not running as root";
        return;
    }

    if ($user) {
        die "Unrecognised username format: '$user'"
            unless $user =~ /^[.\w][-.\w]*$/;
        print "Chown'ing $dir to user '$user'\n";
        system( 'chown', '-R', $user, "$dir" ) == 0
            or die "Couldn't chown $dir to '$user'";
    }
    if ($group) {
        die "Unrecognised groupname format: '$group'"
            unless $group =~ /^[.\w][-.\w]*$/;
        print "Chgrp'ing $dir to group '$group'\n";
        system( 'chgrp', '-R', $group, "$dir" ) == 0
            or die "Couldn't chgrp $dir to '$group'";
    }

}

#===================================
sub _create_plugins_dir {
#===================================
    my $class      = shift;
    my $dir        = shift;
    my $plugin_dir = catdir( $dir, 'plugins' );
    if ( -e $plugin_dir ) {
        print "\nPlugin dir $plugin_dir already exists\n";
    }
    else {
        print "\nCreating plugin dir $plugin_dir\n";
        mkdir $plugin_dir or die $!;
    }
    return $plugin_dir;
}

#===================================
sub upgrade {
#===================================
    my $class = shift;
    my %args
        = @_ != 1 ? @_
        : ref $_[0] eq 'HASH' ? %{ $_[0] }
        :                       { dir => shift };

    my $dest_dir = $class->install_dir
        or die "Can't update ElasticSearch - not installed";

    %args = (
        dir     => $dest_dir,
        plugins => $class->plugins,
        user    => $class->user,
        group   => $class->group,
        %args
    );

    if ( !$args{version} && !$args{tag} ) {
        my $version = $class->version || '';
        $args{version} = $version
            if $version =~ /$VERSION_REGEX/;
    }

    $class->install( \%args );
}

#===================================
sub _download {
#===================================
    my ( $class, $uri, $dest_dir, $unpack ) = @_;
    require File::Fetch;

    my $download_dir = $dest_dir;
    if ($unpack) {
        $download_dir = File::Temp->newdir();
    }
    my $ff = File::Fetch->new( uri => $uri );
    print " - Downloading $uri to $download_dir\n";

    my $archive;
    {
        no warnings 'once';
        local $File::Fetch::WARN = 0;
        $archive = $ff->fetch( to => $download_dir )
            or die "Couldn't download $uri: " . $ff->error();
    }
    return $unpack
        ? $class->_unpack( $archive, $dest_dir )
        : $dest_dir;
}

#===================================
sub _unpack {
#===================================
    my ( $class, $archive, $dest_dir ) = @_;
    require Archive::Extract;

    my $unpack_dir = File::Temp->newdir();
    print " - Unpacking $archive into $unpack_dir\n";
    my $ae = Archive::Extract->new( archive => $archive, type => 'zip' );
    $ae->extract( to => $unpack_dir ) or die $ae->error;
    return $class->_move( $ae->extract_path(), $dest_dir );
}

#===================================
sub _move {
#===================================
    my $class    = shift;
    my $source   = shift;
    my $dest_dir = shift;

    require File::Copy::Recursive;

    if ( -d $source ) {
        print " - Moving the contents of $source to $dest_dir\n";
        $source = catfile( $source, '*' );
    }
    else {
        print " - Moving $source to $dest_dir\n";
    }

    # repeat the copy to overcome a bug in File::Copy::Recursive
    # that results in some files not being copied the first time

    for ( 1 .. 2 ) {
        File::Copy::Recursive::rcopy_glob( $source, $dest_dir )
            or die $!;
    }
    return $dest_dir;

}

#===================================
sub _build {
#===================================
    my $class = shift;
    my $dir   = shift;

    my $gradlew = $^O eq 'MSWin32' ? 'gradlew.bat' : 'gradlew';
    $gradlew = catfile( $dir, $gradlew );

    print "\nBuilding ElasticSearch from source\n";
    system( $gradlew, '-p', $dir ) == 0
        or die "Problem building ElasticSearch";

    my ($archive)
        = glob catfile( $dir, 'build', 'distributions',
        'elasticsearch*.zip' );

    die "Couldn't find the compiled distribution file - not sure what failed"
        unless $archive;

    my @parts    = splitdir($archive);
    my $filename = pop @parts;
    my ($version) = ( $filename =~ /^elasticsearch-(.+)\.zip$/ );
    die "Couldn't extract the version number from '$filename'"
        unless $version;

    my @plugin_paths
        = glob catfile( @parts, 'plugins', 'elasticsearch*.zip' );

    my %plugins;
    for my $path (@plugin_paths) {
        my $filename = ( splitdir($path) )[-1];
        if ( $filename =~ /^elasticsearch-(\w+)-\Q$version/ ) {
            $plugins{$1} = rel2abs $path;
        }
        else { die "Couldn't extract plugin name from '$path" }
    }

    return {
        archive => rel2abs($archive),
        plugins => \%plugins,
        version => $version,
    };
}

#===================================
sub check_for_java {
#===================================
    my $class = shift;

    my $java
        = $ENV{JAVA_HOME}
        ? catfile( $ENV{JAVA_HOME}, 'bin', 'java' )
        : 'java';

    if ( my $java_version = `$java -version 2>&1` ) {
        my ( $major, $minor ) = ( $java_version =~ /version "(\d+)\.(\d+)/ );
        $major ||= 0;
        $minor ||= 0;
        return if $major >= 2 || $major == 1 && $minor >= 6;
        die "Java version 6 required, you have version $minor.\n";
    }

    die "Can't find java in "
        . ( $ENV{JAVA_HOME} ? $java : 'your path' )
        . ".\nYou either need to install it "
        . 'or to set $JAVA_HOME.' . "\n";
}

#===================================
sub _get_set_key {
#===================================
    my $self = shift;
    my $key  = shift;
    eval { require Alien::ElasticSearch::ConfigData; 1 }
        or return undef;
    if (@_) {
        Alien::ElasticSearch::ConfigData->set_config( $key, shift );
        Alien::ElasticSearch::ConfigData->write;
    }
    return Alien::ElasticSearch::ConfigData->config($key);
}

=head1 AUTHOR

Clinton Gormley, C<< <drtech at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-alien-elasticsearch at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Alien-ElasticSearch>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Alien::ElasticSearch


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Alien-ElasticSearch>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Alien-ElasticSearch>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Alien-ElasticSearch>

=item * Search CPAN

L<http://search.cpan.org/dist/Alien-ElasticSearch/>

=back


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Clinton Gormley.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of Alien::ElasticSearch
