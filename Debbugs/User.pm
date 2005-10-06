
package Debbugs::User;

=head1 NAME

Debbugs::User -- User settings

=head1 SYNOPSIS

use Debbugs::User qw(is_valid_user read_usertags write_usertags);

read_usertags(\%ut, $userid);
write_usertags(\%ut, $userid);

=head1 EXPORT TAGS

=over

=item :all -- all functions that can be exported

=back

=head1 FUNCTIONS

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

BEGIN {
    ($VERSION) = q$Revision: 1.1 $ =~ /^Revision:\s+([^\s+])/;
    $DEBUG = 0 unless defined $DEBUG;

    @EXPORT = ();
    @EXPORT_OK = qw(is_valid_user read_usertags write_usertags);
    $EXPORT_TAGS{all} = [@EXPORT_OK];
}


my $gSpoolPath = "/org/bugs.debian.org/spool";

sub esc { 
    my $s = shift;
    if ($s =~ m/^[0-9a-zA-Z_+.-]$/) { return $s; } 
    else { return sprintf("%%%02X", ord($s)); } 
} 

sub filefromemail {
    my $e = shift;
    my $l = length($e) % 7;
    return "$gSpoolPath/user/$l/" . join("", map { esc($_); } split //, $e);
}

sub read_stanza {
    my $f = shift;
    my $field = 0;
    my @res;
    while (<$f>) {
	chomp;
	last if (m/^$/);

        if ($field && m/^ (.*)$/) {
            $res[-1] .= "\n" . $1;
	} elsif (m/^([^:]+):\s+(.*)$/) {
            $field = $1;
	    push @res, ($1, $2);
        }
    }
    return @res;
}

sub read_usertags {
    my $ut = shift;
    my $u = shift;
    my $p = filefromemail($u);
    my $uf;

    open($uf, "< $p") or return;
    while(1) {
        my @stanza = read_stanza($uf);
	last if ($#stanza == -1);
	if ($stanza[0] eq "Tag") {
            my %tag = @stanza;
            my $t = $tag{"Tag"};
            $ut->{$t} = [] unless defined $ut->{$t};
            push @{$ut->{$t}}, split /\s*,\s*/, $tag{Bugs};
        }
    }
    close($uf);
}
               
sub fmt {
    my $s = shift;
    my $n = shift;
    my $sofar = 0;
    my $res = "";
    while ($s =~ m/^([^,]*,\s*)(.*)$/ || $s =~ m/^([^,]+)()$/) {
        my $k = $1;
	$s = $2;
        unless ($sofar == 0 or $sofar + length($k) <= $n) {
	    $res .= "\n ";
	    $sofar = 1;
	}
	$res .= $k;
	$sofar += length($k);
    }
    return $res . $s;
}

sub write_usertags {
    my $ut = shift;
    my $u = shift;
    my $p = filefromemail($u);

    open(U, "> $p") or die "couldn't write to $p";
    for my $t (keys %{$ut}) {
        next if @{$ut->{$t}} == 0;
        print U "Tag: $t\n";
        print U fmt("Bugs: " . join(", ", @{$ut->{$t}}), 77) . "\n";
        print U "\n";
    }
    close(U);
}

sub is_valid_user {
    my $u = shift;
    return ($u =~ /^[a-zA-Z0-9._+-]+[@][a-z0-9-.]{4,}$/);
}


1;

__END__
