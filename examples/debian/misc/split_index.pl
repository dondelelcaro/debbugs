#!/usr/bin/perl

use warnings;
use strict;

use Debbugs::Config qw(:config);

my $index_db = IO::File->new("$config{spool}/index.db",'r') or
     die "Unable to open $config{spool}/index.db for reading: $!";

my %severity_fh;

for my $severity  (@{$config{severity_list}}) {
     my $temp_fh = IO::File->new("$config{spool}/index-${severity}.db",'w') or
	  die "Unable to open $config{spool}/index-${severity}.db for writing: $!";
     $severity_fh{$severity} = $temp_fh;
}

while (<$index_db>) {
     my $line = $_;
     next unless m/^(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+\[\s*([^]]*)\s*\]\s+(\w+)\s+(.*)$/;
     my ($pkg,$bug,$time,$status,$submitter,$severity,$tags) = ($1,$2,$3,$4,$5,$6,$7);
     print {$severity_fh{$severity}} $line if exists $severity_fh{$severity};
}

for my $severity (@{$config{severity_list}}) {
     close $severity_fh{$severity};
     system('gzip','-f',"$config{spool}/index-${severity}.db") == 0 or
	  die "Failure while compressing $config{spool}/index-${severity}.db";
}
