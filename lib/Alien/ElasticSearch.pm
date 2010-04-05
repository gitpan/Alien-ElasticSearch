package Alien::ElasticSearch;

use warnings;
use strict;
use File::Temp();
use File::Spec::Functions qw(catfile catpath splitdir rel2abs catdir devnull);

=head1 NAME

Alien::ElasticSearch - Downloads, builds and installs ElasticSearch from github

=head1 VERSION

Version 0.09

=cut

our $VERSION = '0.09';
our $MASTER_URL
    = 'http://github.com/elasticsearch/elasticsearch/zipball/master';

=head1 SYNOPSIS

    # install latest version from Git to $install_dir
    $install_dir = Alien::ElasticSearch->install($install_dir);

    # upgrade existing installation
    $install_dir = Alien::ElasticSearch->update();

    # get current install dir
    $install_dir = Alien::ElasticSearch->install_dir();

    # set install dir
    $install_dir = Alien::ElasticSearch->install_dir($install_dir);


=head1 DESCRIPTION

This module handles downloading ElasticSearch from github, building,
and installing it.

It then writes a config file to remember where it was installed.

It also adds a script called C<install_elasticsearch.pl> into your perl bin
directory, which can be called as follows:

    install_elasticsearch.pl           # upgrade existing installation
    install_elasticsearch.pl /path     # install to /path

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
    eval { require Alien::ElasticSearch::ConfigData; 1 }
        or return undef;
    if (@_) {
        Alien::ElasticSearch::ConfigData->set_config( 'install_dir', shift );
        Alien::ElasticSearch::ConfigData->write;
    }
    my $dir = Alien::ElasticSearch::ConfigData->config('install_dir');
    return undef unless $dir && -d $dir;
    return $dir;
}

#===================================
sub install {
#===================================
    my $class = shift;
    my $dest_dir = shift or die "No installation path specified";

    $class->check_for_java;

    my $temp_dir = File::Temp->newdir();

    my $source_dir = $class->_download( $temp_dir->dirname, $MASTER_URL );
    my $archive = $class->_build($source_dir);
    return $class->_install( $archive, $dest_dir );
}

#===================================
sub upgrade {
#===================================
    my $class    = shift;
    my $dest_dir = $class->install_dir
        or die "Can't update ElasticSearch - not installed";
    $class->install($dest_dir);
}

#===================================
sub _download {
#===================================
    my $class = shift;
    my $dir   = shift;
    my $uri   = shift;
    require File::Fetch;
    require Archive::Extract;

    my $ff = File::Fetch->new( uri => $uri );
    print "\nDownloading ElasticSearch from: $uri to $dir\n ";
    my $archive = $ff->fetch( to => $dir ) or die $ff->error();

    my $ae = Archive::Extract->new( archive => $archive, type => 'zip' );
    $ae->extract( to => $dir ) or die $ae->error;

    return $ae->extract_path;
}

#===================================
sub _build {
#===================================
    my $class = shift;
    my $dir   = shift;

    my ( $archive, $error );

    my $gradlew = $^O eq 'MSWin32' ? 'gradlew.bat' : 'gradlew';
    $gradlew = catfile( $dir, $gradlew );

    print "\nBuilding ElasticSearch\n";
    system( $gradlew, '-p', $dir ) == 0
        or die "Problem building ElasticSearch";

    ($archive)
        = glob(
        catfile( $dir, 'build', 'distributions', 'elasticsearch*.zip' ) );

    die "Couldn't find the compiled distribution file - not sure what failed"
        unless $archive;

    return rel2abs($archive);
}

#===================================
sub _install {
#===================================
    my $class    = shift;
    my $archive  = shift;
    my $dest_dir = shift;

    require File::Copy::Recursive;

    my $temp_dir = File::Temp->newdir;

    my $ae = Archive::Extract->new( archive => $archive );
    $ae->extract( to => $temp_dir )
        or die "Couldn't extract archive '$archive' to '$dest_dir': "
        . $ae->error;
    my $dir = $ae->extract_path;

    if ( -e $dest_dir ) {
        die "$dest_dir already exists but is not a directory"
            unless -d _;

        for my $file (qw(elasticsearch.yml logging.yml)) {
            my $dest_file = catfile( $dest_dir, 'config', $file );
            next unless -e $dest_file;
            print "Config file $dest_file exists.\n"
                . " -> Creating as $dest_file.orig\n";
            my $source_file = catfile( $dir, 'config', $file );
            rename $source_file, "$source_file.orig"
                or die "Couldn't rename $source_file : $!";
        }
    }

    File::Copy::Recursive::rcopy_glob( catfile( $dir, '*' ), $dest_dir )
        or die "Couldn't install to $dest_dir : $!";

    # repeat the copy to overcome a bug in File::Copy::Recursive
    # that results in some files not being copied the first time
    File::Copy::Recursive::rcopy_glob( catfile( $dir, '*' ), $dest_dir )
        or die "Couldn't install to $dest_dir : $!";

    print "\nElasticSearch installed to $dest_dir\n";
    return $class->install_dir($dest_dir);
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
        if ( $major < 2 && $minor < 6 ) {
            print "Java version 6 required, you have version $minor."
                . " Trying anyway\n";
        }
        return;

    }

    print "Can't find java in "
        . ( $ENV{JAVA_HOME} ? $java : 'your path' )
        . ".\nYou either need to install it "
        . 'or add it to your $JAVA_HOME.' . "\n";
    exit(0);
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
