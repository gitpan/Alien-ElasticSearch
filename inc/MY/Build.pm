package MY::Build;
our @ISA = 'Module::Build';
use Module::Build;
use File::Spec::Functions qw(splitdir catpath);

use lib qw(lib inc);

sub ACTION_build {
    my $self = shift;
    require Alien::ElasticSearch;
    require File::Temp;
    Alien::ElasticSearch->check_for_git;
    Alien::ElasticSearch->check_for_java;

    my $temp_dir;
    my $dir;
    if ($dir = Alien::ElasticSearch->install_dir) {
        my @parts = splitdir($dir);
        pop @parts;
        $dir = catpath(@parts);
    }

    print "Enter the path to the parent folder where you would like to "
        . "install ElasticSearch.\n";

    $dir = Module::Build->prompt( "Install path:", $dir);

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

    $dir = Alien::ElasticSearch->install_from_git($dir);
    $self->config_data( install_dir => $dir );
    $self->feature( temp_install => $temp_install );
    return $self->SUPER::ACTION_code(@_);
}
