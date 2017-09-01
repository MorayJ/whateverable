#!/usr/bin/env perl6
BEGIN %*ENV<PERL6_TEST_DIE_ON_FAIL> = 1;
%*ENV<TESTABLE> = 1;

use lib ‘t/lib’;
use Test;
use IRC::Client;
use Testable;

my $t = Testable.new: bot => ‘Greppable’;

$t.common-tests: help => “Like this: {$t.bot-nick}: password”;

$t.shortcut-tests: <grep: grep6:>,
                   <grep grep, grep6 grep6,>;

# Basics

$t.test(‘basic query’,
        “{$t.bot-nick}: password”,
        “{$t.our-nick}, https://whatever.able/fakeupload”);

$t.test-gist(‘something was found’,
             %(‘result.md’ => /‘password’/));

$t.test-gist(‘is case insensitive’,
             %(‘result.md’ => /‘PASSWORD’/));

$t.test-gist(‘“…” is added to long paths’,
             %(‘result.md’ => /‘``…/01-basic.t``’/));

$t.test-gist(‘“…” is not added to root files’,
             %(‘result.md’ => none /‘``…/README.md``’/));


$t.test(‘another query’,
        “{$t.bot-nick}: I have no idea”,
        “{$t.our-nick}, https://whatever.able/fakeupload”);

$t.test-gist(‘Proper format’, # assume that tadzik's modules don't change
             %(‘result.md’ =>
               /^^ ‘| [tadzik/File-Find<br>``…/01-file-find.t`` :*85*:]’
               ‘(https://github.com/tadzik/File-Find/blob/’
               <.xdigit>**40
               ‘/t/01-file-find.t#L85) | <code>exit 0; # <b>I have no idea</b>’
               ‘ what I'm doing, but I get Non-zero exit status w/o this</code> |’ $$/));

$t.test(‘the output of git grep is split by \n, not something else’,
        “{$t.bot-nick}: foo”,
        “{$t.our-nick}, https://whatever.able/fakeupload”);

$t.test-gist(‘“\r” is actually in the output’,
             %(‘result.md’ => /“\r”/));

# Non-bot tests

my $timestamp = run :out, cwd => ‘data/all-modules’,
                    ‘git’, ‘show’, ‘-s’, ‘--format=%ct’, ‘HEAD’;

ok $timestamp, ‘Got the timestamp of HEAD in data/all-modules repo’;
my $age = now - $timestamp.out.slurp-rest;
cmp-ok $age, &[<], 24 × 60 × 60, ‘data/all-modules repo updated in 24h’;


$t.last-test;
done-testing;
END $t.end;

# vim: expandtab shiftwidth=4 ft=perl6