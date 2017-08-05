# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# go here too.]
# Copyright 2004 by Anthony Towns
# Copyright 2008 by Don Armstrong <don@donarmstrong.com>


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

=head1 USERTAG FILE FORMAT

Usertags are in a file which has (roughly) RFC822 format, with stanzas
separated by newlines. For example:

 Tag: search
 Bugs: 73671, 392392
 
 Value: priority
 Bug-73671: 5
 Bug-73487: 2
 
 Value: bugzilla
 Bug-72341: http://bugzilla/2039471
 Bug-1022: http://bugzilla/230941
 
 Category: normal
 Cat1: status
 Cat2: debbugs.tasks
 
 Category: debbugs.tasks
 Hidden: yes
 Cat1: debbugs.tasks

 Cat1Options:
  tag=quick
  tag=medium
  tag=arch
  tag=not-for-me


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
use Exporter qw(import);

use Debbugs::Config qw(:config);
use List::AllUtils qw(min);

use Carp;
use IO::File;

BEGIN {
    ($VERSION) = q$Revision: 1.4 $ =~ /^Revision:\s+([^\s+])/;
    $DEBUG = 0 unless defined $DEBUG;

    @EXPORT = ();
    @EXPORT_OK = qw(is_valid_user read_usertags write_usertags);
    $EXPORT_TAGS{all} = [@EXPORT_OK];
}


#######################################################################
# Helper functions

sub is_valid_user {
    my $u = shift;
    return ($u =~ /^[a-zA-Z0-9._+-]+[@][a-z0-9-.]{4,}$/);
}

=head2 usertag_file_from_email

     my $filename = usertag_file_from_email($email)

Turns an email into the filename where the usertag can be located.

=cut

sub usertag_file_from_email {
    my ($email) = @_;
    my $email_length = length($email) % 7;
    my $escaped_email = $email;
    $escaped_email =~ s/([^0-9a-zA-Z_+.-])/sprintf("%%%02X", ord($1))/eg;
    return "$config{usertag_dir}/$email_length/$escaped_email";
}


#######################################################################
# The real deal

sub get_user {
     return Debbugs::User->new(@_);
}

=head2 new

     my $user = Debbugs::User->new('foo@bar.com',$lock);

Reads the user file associated with 'foo@bar.com' and returns a
Debbugs::User object.

=cut

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my ($email,$need_lock) = @_;
    $need_lock ||= 0;

    my $ut = {};
    my $self = {"tags" => $ut,
		"categories" => {},
		"visible_cats" => [],
		"unknown_stanzas" => [],
		values => {},
		email => $email,
	       };
    bless $self, $class;

    $self->{filename} = usertag_file_from_email($self->{email});
    if (not -r $self->{filename}) {
	 return $self;
    }
    my $uf = IO::File->new($self->{filename},'r')
	 or die "Unable to open file $self->{filename} for reading: $!";
    if ($need_lock) {
        flock($uf, LOCK_EX);
        $self->{"locked"} = $uf;
    }

    while(1) {
        my @stanza = _read_stanza($uf);
        last unless @stanza;
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
                    if (defined $stanza{"Cat${i}Order"}) {
			 my @temp = split /\s*,\s*/, $stanza{"Cat${i}Order"};
			 my %temp;
			 my $min = min(@temp);
			 # Order to 0 minimum; strip duplicates
			 $c{ord} = [map {$temp{$_}++;
					 $temp{$_}>1?():($_-$min);
				    } @temp
				   ];
		    }
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
            $self->{"categories"}->{$catname} = [@cat];
            push @{$self->{"visible_cats"}}, $catname
                unless ($stanza{"Hidden"} || "no") eq "yes";
	}
	elsif ($stanza[0] eq 'Value') {
	    my ($value,$value_name,%bug_values) = @stanza;
	    while (my ($k,$v) = each %bug_values) {
		my ($bug) = $k =~ m/^Bug-(\d+)/;
		next unless defined $bug;
		$self->{values}{$bug}{$value_name} = $v;
	    }
	}
	else {
            push @{$self->{"unknown_stanzas"}}, [@stanza];
        }
    }

    return $self;
}

sub write {
    my $self = shift;

    my $ut = $self->{"tags"};
    my $p = $self->{"filename"};

    if (not defined $self->{filename} or not
	length $self->{filename}) {
	 carp "Tried to write a usertag with no filename defined";
	 return;
    }
    my $uf = IO::File->new($self->{filename},'w');
    if (not $uf) {
	 carp "Unable to open $self->{filename} for writing: $!";
	 return;
    }

    for my $us (@{$self->{"unknown_stanzas"}}) {
        my @us = @{$us};
        while (my ($k,$v) = splice (@us,0,2)) {
	    $v =~ s/\n/\n /g;
	    print {$uf} "$k: $v\n";
	}
        print {$uf} "\n";
    }

    for my $t (keys %{$ut}) {
        next if @{$ut->{$t}} == 0;
        print {$uf} "Tag: $t\n";
        print {$uf} _wrap_to_length("Bugs: " . join(", ", @{$ut->{$t}}), 77) . "\n";
        print $uf "\n";
    }

    my $uc = $self->{"categories"};
    my %vis = map { $_, 1 } @{$self->{"visible_cats"}};
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
    # handle the value stanzas
    my %value;
    # invert the bug->value hash slightly
    for my $bug (keys %{$self->{values}}) {
	 for my $value (keys %{$self->{values}{$bug}}) {
	      $value{$value}{$bug} = $self->{values}{$bug}{$value}
	 }
    }
    for my $value (keys %value) {
	 print {$uf} "Value: $value\n";
	 for my $bug (keys %{$value{$value}}) {
	      my $bug_value = $value{$value}{$bug};
	      $bug_value =~ s/\n/\n /g;
	      print {$uf} "Bug-$bug: $bug_value\n";
	 }
	 print {$uf} "\n";
    }

    close($uf);
    delete $self->{"locked"};
}

=head1 OBSOLETE FUNCTIONS

=cut

=head2 read_usertags

     read_usertags($usertags,$email)


=cut

sub read_usertags {
    my ($usertags,$email) = @_;

#    carp "read_usertags is deprecated";
    my $user = get_user($email);
    for my $tag (keys %{$user->{"tags"}}) {
        $usertags->{$tag} = [] unless defined $usertags->{$tag};
        push @{$usertags->{$tag}}, @{$user->{"tags"}->{$tag}};
    }
    return $usertags;
}

=head2 write_usertags

     write_usertags($usertags,$email);

Gets a lock on the usertags, applies the usertags passed, and writes
them out.

=cut

sub write_usertags {
    my ($usertags,$email) = @_;

#    carp "write_usertags is deprecated";
    my $user = Debbugs::User->new($email,1); # locked
    $user->{"tags"} = { %{$usertags} };
    $user->write();
}


=head1 PRIVATE FUNCTIONS

=head2 _read_stanza

     my @stanza = _read_stanza($fh);

Reads a single stanza from a filehandle and returns it

=cut

sub _read_stanza {
    my ($file_handle) = @_;
    my $field = 0;
    my @res;
    while (<$file_handle>) {
	 chomp;
	 last if (m/^$/);
	 if ($field && m/^ (.*)$/) {
	      $res[-1] .= "\n" . $1;
	 } elsif (m/^([^:]+):(\s+(.*))?$/) {
	      $field = $1;
	      push @res, ($1, $3||'');
	 }
    }
    return @res;
}


=head2 _wrap_to_length

     _wrap_to_length

Wraps a line to a specific length by splitting at commas

=cut

sub _wrap_to_length {
    my ($content,$line_length) = @_;
    my $current_line_length = 0;
    my $result = "";
    while ($content =~ m/^([^,]*,\s*)(.*)$/ || $content =~ m/^([^,]+)()$/) {
        my $current_word = $1;
        $content = $2;
        if ($current_line_length != 0 and
	    $current_line_length + length($current_word) <= $line_length) {
	    $result .= "\n ";
	    $current_line_length = 1;
	}
	$result .= $current_word;
	$current_line_length += length($current_word);
    }
    return $result . $content;
}




1;

__END__
