#!/usr/local/bin/perl

use strict;
use warnings;
use Alien::ElasticSearch();

my $install_dir;
if ( $install_dir = shift @ARGV ) {
    print "\nInstalling ElasticSearch in: $install_dir\n";
}
elsif ( $install_dir = Alien::ElasticSearch->install_dir ) {
    print "\nUpgrading the ElasticSearch installation in: $install_dir\n";
}
else { die "\nUSAGE:   $0 install_dir\n\n" }

Alien::ElasticSearch->install($install_dir);

