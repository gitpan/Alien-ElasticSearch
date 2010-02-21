#!perl

use Test::More tests => 2;

BEGIN {
    use_ok( 'Alien::ElasticSearch' ) || print "Bail out!
";
}

diag( "Testing Alien::ElasticSearch $Alien::ElasticSearch::VERSION, Perl $], $^X" );
ok(Alien::ElasticSearch->install_dir,'Has installed ElasticSearch');

