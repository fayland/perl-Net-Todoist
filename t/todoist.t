#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Data::Dumper;
use Net::Todoist;
    
my $nt = Net::Todoist->new();
my @timezone = $nt->getTimezones();

ok( grep { $_->[1] and $_->[1] eq "GMT+08:00 - Beijing" } @timezone );

done_testing();

1;