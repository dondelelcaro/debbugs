
package Debbugs::User;

=head1 NAME

Debbugs::User -- User settings

=head1 SYNOPSIS

use Debbugs::User qw(is_valid_user read_usertags write_usertags);

Debbugs::User::is_valid_user($userid);

$u = Debbugs::User::open($userid);
$u = Debbugs::User::open(user => $userid, locked => 0);

$u = Debbugs::User::open(user => $userid, locked => 1);
$u->write();

$u->{"tags"}
$u->{"categories"}
$u->{"is_locked"}
$u->{"name"}


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
use Fcntl ':flock';
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

BEGIN {
    ($VERSION) = q$Revision: 1.4 $ =~ /^Revision:\s+([^\s+])/;
    $DEBUG = 0 unless defined $DEBUG;

    @EXPORT = ();
    @EXPORT_OK = qw(is_valid_user open);
    $EXPORT_TAGS{all} = [@EXPORT_OK];
}

my $gSpoolDir = "/org/bugs.debian.org/spool";
if (defined($debbugs::gSpoolDir)) {
    $gSpoolDir = $debbugs::gSpoolDir;
}

# Obsolete compatability functions

sub read_usertags {
    my $ut = shift;
    my $u = shift;
    
    my $user = get_user($u);
    for my $t (keys %{$user->{"tags"}}) {
        $ut->{$t} = [] unless defined $ut->{$t};
        push @{$ut->{$t}}, @{$user->{"tags"}->{$t}};
    }
}

sub write_usertags {
    my $ut = shift;
    my $u = shift;
    
    my $user = get_user($u, 1); # locked
    $user->{"tags"} = { %{$ut} };
    $user->write();
}

#######################################################################
# Helper functions

sub filefromemail {
    my $e = shift;
    my $l = length($e) % 7;
    return "$gSpoolDir/user/$l/" . join("", 
        map { m/^[0-9a-zA-Z_+.-]$/ ? $_ : sprintf("%%%02X", ord($_)) }
            split //, $e);
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
        } elsif (m/^([^:]+):(\s+(.*))?$/) {
            $field = $1;
            push @res, ($1, $3);
        }
    }
    return @res;
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

sub is_valid_user {
    my $u = shift;
    return ($u =~ /^[a-zA-Z0-9._+-]+[@][a-z0-9-.]{4,}$/);
}

#######################################################################
# The real deal

sub get_user {
    my $ut = {};
    my $user = { 
        "tags" => $ut, 
        "categories" => {}, 
        "visible_cats" => [],
        "unknown_stanzas" => [] 
    };

    my $u = shift;
    my $need_lock = shift || 0;
    my $p = filefromemail($u);

    my $uf;
    $user->{"filename"} = $p;
    if (not -r $p) {
	 return bless $user, "Debbugs::User";
    }
    open($uf, "< $p") or die "Unable to open file $p for reading: $!";
    if ($need_lock) {
        flock($uf, LOCK_EX); 
        $user->{"locked"} = $uf;
    }
    
    while(1) {
        my @stanza = read_stanza($uf);
        last if ($#stanza == -1);
        if ($stanza[0] eq "Tag") {
            my %tag = @stanza;
            my $t = $tag{"Tag"};
            $ut->{$t} = [] unless defined $ut->{$t};
            push @{$ut->{$t}}, split /\s*,\s*/, $tag{Bugs};
        } elsif ($stanza[0] eq "Category") {
            my @cat = ();
            my %stanza = @stanza;
            my $catname = $stanza{"Category"};
            my $i = 0;
            while (++$i && defined $stanza{"Cat${i}"}) {
                if (defined $stanza{"Cat${i}Options"}) {
                    # parse into a hash
                    my %c = ("nam" => $stanza{"Cat${i}"});
                    $c{"def"} = $stanza{"Cat${i}Default"}
                        if defined $stanza{"Cat${i}Default"};
                    $c{"ord"} = [ split /,/, $stanza{"Cat${i}Order"} ]
                        if defined $stanza{"Cat${i}Order"};
                    my @pri; my @ttl;
                    for my $l (split /\n/, $stanza{"Cat${i}Options"}) {
                        if ($l =~ m/^\s*(\S+)\s+-\s+(.*\S)\s*$/) {
                            push @pri, $1;
                            push @ttl, $2;
                        } elsif ($l =~ m/^\s*(\S+)\s*$/) {
                            push @pri, $1;
                            push @ttl, $1;
                        }
                    }
                    $c{"ttl"} = [@ttl];
                    $c{"pri"} = [@pri];
                    push @cat, { %c };                    
                } else {
                    push @cat, $stanza{"Cat${i}"};
                }
            }
            $user->{"categories"}->{$catname} = [@cat];
            push @{$user->{"visible_cats"}}, $catname
                unless ($stanza{"Hidden"} || "no") eq "yes";                        
        } else {
            push @{$user->{"unknown_stanzas"}}, [@stanza];
        }
    }
    close($uf) unless $need_lock;

    bless $user, "Debbugs::User";
    return $user;
}

sub write {
    my $user = shift;
    my $uf;
    my $ut = $user->{"tags"};
    my $p = $user->{"filename"};

    if ($p =~ m/^(.+)$/) { $p = $1; } else { return; } 
    open $uf, "> $p" or return;

    for my $us (@{$user->{"unknown_stanzas"}}) {
        my @us = @{$us};
        while (@us) {
            my $k = shift @us; my $v = shift @us;
	    $v =~ s/\n/\n /g;
            print $uf "$k: $v\n";
        }
        print $uf "\n";
    }

    for my $t (keys %{$ut}) {
        next if @{$ut->{$t}} == 0;
        print $uf "Tag: $t\n";
        print $uf fmt("Bugs: " . join(", ", @{$ut->{$t}}), 77) . "\n";
        print $uf "\n";
    }

    my $uc = $user->{"categories"};
    my %vis = map { $_, 1 } @{$user->{"visible_cats"}};
    for my $c (keys %{$uc}) {
        next if @{$uc->{$c}} == 0;

        print $uf "Category: $c\n";
	print $uf "Hidden: yes\n" unless defined $vis{$c};
	my $i = 0;
	for my $cat (@{$uc->{$c}}) {
	    $i++;
	    if (ref($cat) eq "HASH") {
	        printf $uf "Cat%d: %s\n", $i, $cat->{"nam"};
	        printf $uf "Cat%dOptions:\n", $i;
	        for my $j (0..$#{$cat->{"pri"}}) {
	            if (defined $cat->{"ttl"}->[$j]) {
		        printf $uf " %s - %s\n",
		            $cat->{"pri"}->[$j], $cat->{"ttl"}->[$j];
		    } else {
		        printf $uf " %s\n", $cat->{"pri"}->[$j];
		    }
		}
	        printf $uf "Cat%dDefault: %s\n", $i, $cat->{"def"}
	    	    if defined $cat->{"def"};
		printf $uf "Cat%dOrder: %s\n", $i, join(", ", @{$cat->{"ord"}})
		    if defined $cat->{"ord"};
	    } else {
	        printf $uf "Cat%d: %s\n", $i, $cat;
	    }
	}
	print $uf "\n";
    }

    close($uf);
    delete $user->{"locked"};
}

1;

__END__
