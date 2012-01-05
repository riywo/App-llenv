#!/usr/bin/env perl

open my $in,  "<", "script/llenv.PL" or die $!;
open my $out, ">", "llenv.tmp" or die $!;

print STDERR "Generating llenv from script/llenv.PL\n";

while (<$in>) {
    next if /Auto-removed/;
    s/DEVELOPERS:.*/DO NOT EDIT -- this is an auto generated file/;
    s/.*__FATPACK__/zomg_hfs(scalar `$^X -e "use App::FatPacker -run_script" file`)/e;
    print $out $_;
}

close $out;

unlink "llenv";
rename "llenv.tmp", "llenv";
chmod 0755, "llenv";

END { unlink "llenv.tmp" }

# HFS is case sensitive, we have fatlib/version that contains Version/Requirements.pm :(
sub zomg_hfs {
    local $_ = shift;
    s!version/Requirements.pm!Version/Requirements.pm!;
    return $_;
}
