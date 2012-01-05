#!/usr/bin/env perl
# DEVELOPERS: Read script/build.PL in the repo how to update this
# __FATPACK__
use strict;
use FindBin qw($Bin);                    # For dev -- Auto-removed
use lib "$Bin/../lib", "$Bin/../fatlib"; # For dev -- Auto-removed
use App::llenv;

unless (caller) {
    my $app = App::llenv->new;
    $app->parse_options(@ARGV);
    $app->run or exit(1);
}

__END__
