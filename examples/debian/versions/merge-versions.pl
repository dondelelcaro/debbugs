#! /usr/bin/perl -w
use strict;
use File::Find;
use Debbugs::Versions;
use Debbugs::Versions::Dpkg;

my %pkgs;

sub search {
    return unless -f;
    my ($pkg) = split /_/;
    push @{$pkgs{$pkg}}, "$File::Find::dir/$_";
}

find(\&search, 'cl-data');

for my $pkg (sort keys %pkgs) {
    print STDERR "$pkg\n";
    my $tree = Debbugs::Versions->new(\&Debbugs::Versions::Dpkg::vercmp);
    for my $file (@{$pkgs{$pkg}}) {
	unless (open FILE, "< $file") {
	    warn "can't open $file: $!\n";
	    next;
	}
	$tree->load(*FILE);
	close FILE;
    }
    my $pkghash = substr $pkg, 0, 1;
    unless (-d "pkg/$pkghash") {
	unless (mkdir "pkg/$pkghash") {
	    warn "can't mkdir pkg/$pkghash: $!\n";
	    next;
	}
    }
    unless (open OUT, "> pkg/$pkghash/$pkg") {
	warn "can't open pkg/$pkghash/$pkg for writing: $!\n";
	next;
    }
    $tree->save(*OUT);
    close OUT;
}
