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

eval {
    require Alien::ElasticSearch;
    for (qw(install_dir version plugins user group)) {

 $builder->config_data( $_, Alien::ElasticSearch->$_ )
         if Alien::ElasticSearch->can($_) ;
    }
};

$builder->create_build_script();


