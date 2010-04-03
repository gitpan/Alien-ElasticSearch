use strict;
use warnings;
use lib 'inc';
use MY::Build;

my $builder = MY::Build->new(
    module_name       => 'Alien::ElasticSearch',
    license           => 'perl',
    dist_author       => q{Clinton Gormley <drtech@cpan.org>},
    dist_version_from => 'lib/Alien/ElasticSearch.pm',
    build_requires    => { 'Test::More' => 0 },
    requires          => {
        'Archive::Extract'      => 0,
        'File::Copy::Recursive' => 0,
        'File::Fetch'           => 0
    },
    add_to_cleanup     => ['Alien-ElasticSearch-*'],
    create_makefile_pl => 'small',
);

my $install_dir;
eval {
    require Alien::ElasticSearch;
    $install_dir = Alien::ElasticSearch->install_dir;
};

$builder->config_data( install_dir => $install_dir );

unshift @INC, 'lib';
require Alien::ElasticSearch;
Alien::ElasticSearch->check_for_java();

$builder->create_build_script();

