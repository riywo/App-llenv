#!/usr/bin/env perl
use strict;
use App::FatPacker ();
use File::Path;
use Cwd;

my $modules = [ split /\s+/, <<MODULES ];
Text/Aligner.pm
Text/Table.pm
Getopt/Compact/WithCmd.pm
MODULES

my $packer = App::FatPacker->new;
my @packlists = $packer->packlists_containing($modules);
$packer->packlists_to_tree(cwd . "/fatlib", \@packlists);

use Config;
rmtree("fatlib/$Config{archname}");
