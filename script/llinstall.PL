#!/usr/bin/env perl
# DEVELOPERS: Read script/build.PL in the repo how to update this
# __FATPACK__
use strict;
use FindBin qw($RealBin);                    # For dev -- Auto-removed
use lib "$RealBin/../lib", "$RealBin/../local/lib/perl5"; # For dev -- Auto-removed
use App::llinstall;

unless (caller) {
    my $app = App::llinstall->new;
    $app->init;
    $app->parse_options(@ARGV);
    $app->run or exit(1);
}

__END__
