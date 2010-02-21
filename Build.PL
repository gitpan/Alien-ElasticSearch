use strict;
use warnings;
use Module::Build;
use lib qw(inc);
use MY::Build();

my $builder = MY::Build->new(
                          module_name => 'Alien::ElasticSearch',
                          license     => 'perl',
                          dist_author => q{Clinton Gormley <drtech@cpan.org>},
                          dist_version_from  => 'lib/Alien/ElasticSearch.pm',
                          build_requires     => { 'Test::More' => 0 },
                          requires           => { 'Archive::Extract' => 0 },
                          add_to_cleanup     => ['Alien-ElasticSearch-*'],
                          create_makefile_pl => 'small',
);

$builder->create_build_script();

