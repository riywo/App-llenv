#!perl -w
use strict;
use Test::More;

eval q{ use Test::Spelling };
plan skip_all => q{Test::Spelling is not available.}
    if $@;

my @stopwords;
while(my $line = <DATA>) {
    $line =~ s/ \# [^\n]+ //xms;
    push @stopwords, $line =~ /(\w+)/g;
}
add_stopwords(@stopwords);

$ENV{LC_ALL} = 'C';
all_pod_files_spelling_ok('lib');

__DATA__
riywo
riywo.jp@gmail.com
App::llenv

# computer terms
API
APIs
arrayrefs
arity
Changelog
codebase
committer
committers
compat
cpan
extention
datetimes
dec
definedness
destructor
destructors
destructuring
dev
DWIM
GitHub
hashrefs
hotspots
immutabilize
immutabilizes
immutabilized
inline
inlines
invocant
invocant's
irc
IRC
isa
JSON
login
namespace
namespaced
namespaces
namespacing
OO
OOP
ORM
overridable
parameterizable
parameterization
parameterize
parameterized
parameterizes
params
pluggable
prechecking
prepends
rebase
rebased
rebasing
reblesses
refactored
refactoring
rethrows
RT
runtime
serializer
stacktrace
subclassable
subname
subtyping
TODO
unblessed
unexport
unimporting
Unported
unsets
unsettable
utils
whitelist
Whitelist
workflow
XS
MacOS
MacOSX
CLI
HTTP

versa # vice versa
ish   # something-ish
ness  # something-ness
pre   # pre-something
maint # co-maint
