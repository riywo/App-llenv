#!/usr/bin/env perl

my $name = $ARGV[0] or die;

open my $in,  "<", "script/$name.PL" or die $!;
open my $out, ">", "$name.tmp" or die $!;

print STDERR "Generating llenv from script/$name.PL\n";

while (<$in>) {
    next if /Auto-removed/;
    s/DEVELOPERS:.*/DO NOT EDIT -- this is an auto generated file/;
    s/.*__FATPACK__/zomg_hfs(scalar `$^X -e "use App::FatPacker -run_script" file`)/e;
    print $out $_;
}

close $out;

unlink "$name";
rename "$name.tmp", "$name";
chmod 0755, "$name";

END { unlink "$name.tmp" }

# HFS is case sensitive, we have fatlib/version that contains Version/Requirements.pm :(
sub zomg_hfs {
    local $_ = shift;
    s!version/Requirements.pm!Version/Requirements.pm!;
    return $_;
}
