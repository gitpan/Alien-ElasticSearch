package Alien::ElasticSearch;

use warnings;
use strict;
use File::Temp();
use File::Spec::Functions qw(catfile splitdir rel2abs catdir devnull);

=head1 NAME

Alien::ElasticSearch - Downloads, builds and installs ElasticSearch from github

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';
our $GIT_URL = 'git://github.com/elasticsearch/elasticsearch.git';

=head1 SYNOPSIS

    $install_dir = Alien::ElasticSearch->install_from_git($parent_dir);

    $install_dir = Alien::ElasticSearch->install_dir();

    $install_dir = Alien::ElasticSearch->update_from_git();

=head1 DESCRIPTION

This module handles downloading ElasticSearch from github, building,
and installing it.

It then writes a config file to remember where it was installed.

=head1 REQUIREMENTS

=over

=item  * git (needs to be in your PATH)

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
    }
    return Alien::ElasticSearch::ConfigData->config('install_dir');
}

#===================================
sub temp_install {
#===================================
    my $self = shift;
    eval { require Alien::ElasticSearch::ConfigData; 1 }
        or return undef;
    if (@_) {
        Alien::ElasticSearch::ConfigData->set_feature( 'temp_install', shift );
    }
    return Alien::ElasticSearch::ConfigData->temp_install('temp_install');
}

#===================================
sub update_from_git {
#===================================
    my $class      = shift;
    my $install_dir = $class->install_dir or die "ElasticSearch not installed yet";
    my @parts = splitdir($install_dir);
    pop @parts;
    $class->install_from_git(catpath(@parts));
}

#===================================
sub install_from_git {
#===================================
    my $class      = shift;
    my $dest_dir   = shift or die "No installation path specified";
    my $source_dir = $class->_download_with_git;
    my $archive    = $class->_build( $source_dir->dirname );
    return $class->_install( $archive, $dest_dir );

}

#===================================
sub _download_with_git {
#===================================
    my $class = shift;
    $class->check_for_git;
    my $git_version = `git --version`;
    die "Can't find git in your PATH. "
        . 'You either need to install it'
        . 'or add it to your $PATH.'
        unless $git_version && $git_version =~ /git/;

    my $dir = File::Temp->newdir();
    print "\nDownloading latest version of ElasticSearch from: $GIT_URL\n ";
    system( 'git', 'clone', $GIT_URL, $dir->dirname ) == 0
        or die "Couldn't download source";
    return $dir;
}

#===================================
sub check_for_git {
#===================================
    my $class       = shift;
    my $git_version = `git --version`;
    return if $git_version && $git_version =~ /git/;

    print "Can't find git in your PATH. "
        . 'You either need to install it'
        . 'or add it to your $PATH.' . "\n";
    exit(0);
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


#===================================
sub _build {
#===================================
    my $class = shift;
    my $dir   = shift;

    my $gradlew = $^O eq 'MSWin32' ? 'gradlew.bat' : 'gradlew';
    $gradlew = catfile( $dir, $gradlew );

    print "\nBuilding ElasticSearch\n";
    system( $gradlew, '-p', $dir, 'clean', 'devRelease' ) == 0
        or die "Problem building ElasticSearch";

    my ($archive)
        = glob( catfile( $dir, 'build', 'distributions', '*.zip' ) );
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

    $class->check_for_java;

    $dest_dir = catfile( rel2abs($dest_dir), '' );
    my ($volume) = splitdir($dest_dir);
    require Archive::Extract;
    my $a = Archive::Extract->new( archive => $archive );
    $a->extract( to => $dest_dir )
        or die "Couldn't extract archive '$archive' to '$dest_dir': "
        . $a->error;
    my $install_dir = $a->extract_path;
    print "\nElasticSearch installed to $install_dir\n";
    $class->install_dir($install_dir);
    return $install_dir;
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
