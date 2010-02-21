use strict;
use warnings;
use Module::Build;
use lib qw(lib);
use File::Spec::Functions qw(splitdir catfile);

my ( $install_dir, $temp_install );

build_es();

my $builder = Module::Build->new(
                          module_name => 'Alien::ElasticSearch',
                          license     => 'perl',
                          dist_author => q{Clinton Gormley <drtech@cpan.org>},
                          dist_version_from  => 'lib/Alien/ElasticSearch.pm',
                          build_requires     => { 'Test::More' => 0 },
                          requires           => { 'Archive::Extract' => 0 },
                          add_to_cleanup     => ['Alien-ElasticSearch-*'],
                          create_makefile_pl => 'small',
);

$builder->config_data( install_dir => $install_dir );
$builder->feature( temp_install => 1 );

$builder->create_build_script();

sub build_es {
    use Alien::ElasticSearch;
    use File::Temp;

    Alien::ElasticSearch->check_for_git;
    Alien::ElasticSearch->check_for_java;

    my $temp_dir;
    my $dir;
    if ( $dir = Alien::ElasticSearch->install_dir ) {
        my @parts = splitdir($dir);
        pop @parts;
        $dir = catfile(@parts);
    }

    print "Enter the path to the parent folder where you would like to "
        . "install ElasticSearch.\n";

    $dir = Module::Build->prompt( "Install path:", $dir );
    return if $dir eq '-';

    my $temp_install;
    if ( defined $dir ) {
        chomp $dir;
        $dir = '.' if $dir eq '';
    }
    else {
        $temp_dir     = File::Temp->newdir();
        $dir          = $temp_dir->dirname;
        $temp_install = 1;
    }

    $install_dir  = Alien::ElasticSearch->install_from_git($dir);
    $temp_install = 1;

}

