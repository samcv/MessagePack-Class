#!/usr/bin/env perl6

use v6.c;

use Test;

use MessagePack::Class;

class TestClass does MessagePack::Class {
    has Str     $.string;
    has Bool    $.bool;
    has Int     $.int;
    has Rat     $.num;
}

my $original = TestClass.new(string => "test value", bool => True, int => 42, num => 2.5);

my $pack;

lives-ok { $pack = $original.to-messagepack }, "to messagepack";
ok $pack ~~ Blob, "and we got a Blob back";

my $new;

lives-ok { $new = TestClass.from-messagepack($pack) }, "from messagepack";

is $new.string, $original.string, "got right string value";
is $new.bool, $original.bool, "got right bool value";
is $new.int, $original.int, "got right int value";
is $new.num, $original.num, "got right num value";


done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
