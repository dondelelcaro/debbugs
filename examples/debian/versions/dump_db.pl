#!/usr/bin/perl

use warnings;
use strict;
use MLDBM qw(DB_File Storable);
use Data::Dumper;
use Fcntl;

$MLDBM::DumpMeth=q(portable);


my %db;

my $db_name = (shift @ARGV || 'versions.idx');

tie %db, MLDBM => $db_name,O_RDONLY or die "unable to tie $db_name: $!";
if (@ARGV) {
     print Dumper([@db{@ARGV}]);
}
else {
     print Dumper(\%db);
}



