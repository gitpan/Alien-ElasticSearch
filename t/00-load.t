#!perl

use Test::More tests => 1;

BEGIN {
    use_ok( 'Alien::ElasticSearch' ) || print "Bail out!
";
}

diag( "Testing Alien::ElasticSearch $Alien::ElasticSearch::VERSION, Perl $], $^X" );


