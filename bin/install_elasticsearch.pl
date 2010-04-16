#!/usr/local/bin/perl

use strict;
use warnings;

use lib 'lib';

use Alien::ElasticSearch();
use Getopt::Long;
my %params;
eval {
    GetOptions(
        \%params,  'dir=s', 'version=s', 'tag=s', 'plugins=s', 'user=s',
        'group=s', 'temp',  'current',   'help'
    );
} or die usage();

if ( $params{help} ) {
    print usage();
    exit;
}

$params{plugins} = [ split /,/, $params{plugins} || '' ];
if ( $params{current} ) {
    print "\n";
    my @keys = qw(install_dir version plugins user group);
    my %vals = map { $_ => Alien::ElasticSearch->$_ } @keys;
    if ( $vals{install_dir} ) {
        $vals{plugins} = join( ', ', @{ $vals{plugins} } );
        print "ElasticSearch is installed as:\n";
        for (@keys) {
            printf " - %-15s : %s\n", $_, $vals{$_} || '';
        }
    }
    else {
        print "ElasticSearch is not installed\n";
    }
    print "\n";
    exit;
}

if ( my $install_dir = $params{dir} ) {
    Alien::ElasticSearch->install( \%params );
}
elsif ( $install_dir = Alien::ElasticSearch->install_dir ) {
    Alien::ElasticSearch->upgrade( \%params );
}
else { die usage() }

sub usage {
    <<USAGE

 $0 [options]
    --dir        /path/to/install_dir
    --version    0.6.0
 or --tag        master | v0.6.0 | 9549b9c2d3cd4151a03bacebea13b96b19478291
    --plugins    attachments,groovy
    --user       username
    --group      groupname
    --temp
    --current
    --help

 * --version is a released version number eg 0.6.0
 * --tag can be master, or a git tag, or a git SHA1

 If no version or tag is specified, then the latest master is installed

 * --plugins are a comma separated list of plugins that should be installed
 * --user and --group will chown the installation - UNIX/Linux only
 * --temp means that the new installation details will not be stored
 * --current prints the current installation deatils
 * --help prints this page

USAGE

}

