package MY::Build;

use strict;
use warnings;
use base qw(Module::Build);

our $Target_Version = '0.6.0';

my @keys = qw(install_dir version plugins );
if ( $^O =~ /^(unix|linux)$/ ) {
    push @keys, qw(user group);
}

my %description = (
    install_dir => [
        'The path where I should install ElasticSearch. ',
        " - Enter '--' to skip installation"
    ],
    plugins =>
        ['A comma separated list of plugins that you would like to install'],
    version => [
        'The version of ElasticSearch you would like to install.',
        " - eg 0.6.0",
        ' - #tag or #sha1 to install a particular version from git, eg #v0.6.0 or #master'
    ],
    user  => ['The user who will own this installation (chown)'],
    group => ['The group who whill own this installation (chgrp)'],
);

sub ACTION_install {
    my $self = shift;
    $self->SUPER::ACTION_install;
    require Alien::ElasticSearch;

    unless ( eval { Alien::ElasticSearch->check_for_java(); 1 } ) {
        print "\n"
            . ( '*' x 60 )
            . "\n** CANNOT INSTALL ELASTICSEARCH SERVER: \n** $@"
            . ( '*' x 60 ) . "\n";
        install_skipped();
    }

    my $current = current_info();
    $current->{install_dir} ||= '--';
    $current->{version} = $Target_Version;
    print "Configuring ElasticSearch installation. Please enter: \n\n";
    for my $key (@keys) {
        my $val
            = $self->prompt( " * " . join( "\n", @{ $description{$key} } ),
            $current->{$key} );
        $val = $val || '';
        chomp $val;
        $current->{$key} = $val && $val ne '--' ? $val : '';
        install_skipped() unless $current->{install_dir};
    }
    $current->{dir} = delete $current->{install_dir};
    $current->{plugins} = [ split /\s*,\s*/, $current->{plugins} ];
    if ( $current->{version} =~ s/^#// ) {
        $current->{tag} = delete $current->{version};
    }
    Alien::ElasticSearch->install($current);
}

#===================================
sub current_info {
#===================================
    my %vals = map { $_ => Alien::ElasticSearch->$_ } @keys;
    if ( $vals{install_dir} ) {
        print "\n";
        $vals{plugins} = join( ', ', @{ $vals{plugins} } );
        print "ElasticSearch is currently installed as:\n";
        for (@keys) {
            printf " - %-15s : %s\n", $_, $vals{$_} || '';
        }
        print "\n";
    }
    return \%vals;
}

#===================================
sub install_skipped {
#===================================
    print <<'SKIPPED';

I won't install the ElasticSearch server now, but I will continue to install
Alien::ElasticSearch.

You can always install ElasticSearch later by typing this on the command line:

   install_elasticsearch.pl  --dir /install/path

Alternatively, if you already have ElasticSearch installed, you can set the
install directory by doing the following (probably as root/administrator):

   perl -MAlien::ElasticSearch -e 'Alien::ElasticSearch->install_dir("/path")'

SKIPPED

    exit;
}

1;
