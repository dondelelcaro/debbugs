# CrossAssassin.pm 2004/04/12 blarson 

package Mail::CrossAssassin;

use strict;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(ca_init ca_keys ca_set ca_score ca_expire);
our $VERSION = 0.1;

use Digest::MD5 qw(md5_base64);
use DB_File;

our %database;
our $init;
our $addrpat = '\b\d{3,8}(?:-(?:close|done|forwarded|maintonly|submitter|quiet))?\@bugs\.debian\.org';

sub ca_init(;$$) {
    my $ap = shift;
    $addrpat = $ap if(defined $ap);
    my $dir = shift;
    return if ($init && ! defined($dir));
    $dir = "$ENV{'HOME'}/.crosssassassin" unless (defined($dir));
    (mkdir $dir or die "Could not create \"$dir\"") unless (-d $dir);
    untie %database;
    tie %database, 'DB_File', "$dir/Crossdb"
	or die "Could not initialize crosassasin database \"$dir/Crossdb\": $!";
    $init = 1;
}

sub ca_keys($) {
    my $body = shift;
    my @keys;
    my $m = join('',@$body);
    $m =~ s/\n(?:\s*\n)+/\n/gm;
    if (length($m) > 4000) {
	my $m2 = $m;
	$m2 =~ s/\S\S+/\*/gs;
	push @keys, '0'.md5_base64($m2);
    }
#    $m =~ s/^--.*$/--/m;
    $m =~ s/$addrpat/LOCAL\@ADDRESS/iogm;
    push @keys, '1'.md5_base64($m);
    return join(' ',@keys);
}

sub ca_set($) {
    my @keys = split(' ', $_[0]);
    my $now = time;
    my $score = 0;
    my @scores;
    foreach my $k (@keys) {
	my ($count,$date) = split(' ',$database{$k});
        $count++;
        $score = $count if ($count > $score);
        $database{$k} = "$count $now";
	push @scores, $count;
    }
    return (wantarray ? @scores : $score);
}

sub ca_score($) {
    my @keys = split(' ', $_[0]);
    my $score = 0;
    my @scores;
    my $i = 0;
    foreach my $k (@keys) {
	my ($count,$date) = split(' ',$database{$k});
	$score = $count if ($count > $score);
	$i++;
	push @scores, $count;
    }
    return (wantarray ? @scores : $score);
}

sub ca_expire($) {
    my $when = shift;
    my @ret;
    my $num = 0;
    my $exp = 0;
    while (my ($k, $v) = each %database) {
	$num++;
	my ($count, $date) = split(' ', $v);
	if ($date <= $when) {
	    delete $database{$k};
	    $exp++;
	}
    }
    return ($num, $exp);
}

END {
    return unless($init);
    untie %database;
    undef($init);
}

1;
