#! /usr/bin/perl -w
use strict;
use MLDBM qw(DB_File Storable);
use Fcntl;

$MLDBM::DumpMeth=q(portable);

my %db;
my %db2;
tie %db, "MLDBM", "versions.idx.new", O_CREAT|O_RDWR, 0664
    or die "tie versions.idx.new: $!";
tie %db2, "MLDBM", "versions_time.idx.new",O_CREAT|O_RDWR, 0664
     or die "tie versions_time.idx.new failed: $!";

my $archive = shift;
my $dist = shift;
my $arch = shift;
print "$archive/$dist/$arch\n";

my $time = time;
my ($p, $v);
my $extra_source_only = 0;
while (<>) {
    if (/^Package: (.*)/)    { $p = $1; }
    elsif (/^Version: (.*)/) { $v = $1; }
    elsif (/^Extra-Source-Only: yes/) {
        $extra_source_only = 1;
    }
    elsif (/^$/) {
        if ($extra_source_only) {
            $extra_source_only = 0;
            next;
        }
        update_package_version($p,$v,$time);
    }
}
update_package_version($p,$v,$time) unless $extra_source_only;

sub update_package_version {
    my ($p,$v,$t) = @_;
	# see MLDBM(3pm)/BUGS
	my $tmp = $db{$p};
	# we allow multiple versions in an architecture now; this
	# should really only happen in the case of source, however.
	push @{$tmp->{$dist}{$arch}}, $v;
	$db{$p} = $tmp;
	$tmp = $db2{$p};
	$tmp->{$dist}{$arch}{$v} = $time if not exists
	     $tmp->{$dist}{$arch}{$v};
	$db2{$p} = $tmp;
}

