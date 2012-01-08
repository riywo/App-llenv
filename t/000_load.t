#!perl -w
use strict;
use Test::More tests => 2;

BEGIN {
    use_ok 'App::llenv';
    use_ok 'App::llinstall';
}

diag "Testing App::llenv/$App::llenv::VERSION";
