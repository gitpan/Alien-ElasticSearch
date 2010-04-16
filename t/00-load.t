#!perl

our ( $Target_Version, @Plugins, @Plugin_Files );

BEGIN {
    $Target_Version = '0.6.0';
    @Plugins        = qw(attachments);
    @Plugin_Files   = qw(elasticsearch-attachments-0.6.0.zip);
}

use Test::More tests => 4 + @Plugin_Files;
use File::Temp();
use File::Spec::Functions qw(catdir catfile);

BEGIN {
    use_ok('Alien::ElasticSearch') || print "Bail out!
";
}

diag(
    "Testing Alien::ElasticSearch $Alien::ElasticSearch::VERSION, Perl $], $^X"
);

my $has_java = eval { Alien::ElasticSearch->check_for_java(); 1 };
unless ($has_java) {
    diag "*** WARNING - JAVA NOT INSTALLED ***";
    diag "*** I can test and install Alien::ElasticSearch";
    diag "*** but I can't install a working server without Java";
    diag "";
}

my $test_dir = File::Temp->newdir();
my $install_dir;

diag "Installing ElasticSearch $Target_Version in $test_dir";
ok $install_dir = Alien::ElasticSearch->install(
    dir             => $test_dir,
    version         => $Target_Version,
    plugins         => \@Plugins,
    temp            => 1,
    skip_java_check => 1,
    ),
    "install version $Target_Version";

ok $install_dir eq $test_dir, 'installed to correct dir';

my $plugins_dir = catdir( $install_dir, 'plugins' );
ok -e $plugins_dir && -d _, 'plugins dir exists';

for (@Plugin_Files) {
    ok -e catfile( $plugins_dir, $_ ), " - plugin $_ exists";
}

