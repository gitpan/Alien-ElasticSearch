package MY::Build;

use strict;
use warnings;
use base qw(Module::Build);

sub ACTION_install {
    my $self = shift;
    $self->SUPER::ACTION_install;
    my $temp_dir;
    require Alien::ElasticSearch;
    my $install_dir = Alien::ElasticSearch->install_dir;
    if ($install_dir) {
        print "\nUpgrading ElasticSearch in : $install_dir\n";
    }
    else {
        if ( !Module::Build->_is_interactive ) {
            $temp_dir    = File::Temp->newdir;
            $install_dir = $temp_dir->dirname;
        }
        $install_dir
            = Module::Build->prompt(
            "Enter install dir for ElasticSearch (leave empty to skip)",
            $install_dir );
        return install_skipped() unless $install_dir;
        chomp $install_dir;
        print "\nInstalling ElasticSearch in : $install_dir\n";
    }
    Alien::ElasticSearch->install($install_dir) if $install_dir;
}

#===================================
sub install_skipped {
#===================================
    print <<'SKIPPED';

I won't install ElasticSearch now, but I will continue to install
Alien::ElasticSearch.

You can always install ElasticSearch later by typing this on the command line:

   install_elasticsearch.pl  /install/path

Alternatively, if you already have ElasticSearch installed, you can set the
install directory by doing the following (probably as root/administrator):

   perl -MAlien::ElasticSearch -e 'Alien::ElasticSearch->install_dir("/path")'

SKIPPED

}
1;
