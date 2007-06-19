# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# go here too.]
# Copyright 2007 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Common;

=head1 NAME

Debbugs::Common -- Common routines for all of Debbugs

=head1 SYNOPSIS

use Debbugs::Common qw(:url :html);


=head1 DESCRIPTION

This module is a replacement for the general parts of errorlib.pl.
subroutines in errorlib.pl will be gradually phased out and replaced
with equivalent (or better) functionality here.

=head1 FUNCTIONS

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

BEGIN{
     $VERSION = 1.00;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (util   => [qw(getbugcomponent getbuglocation getlocationpath get_hashname),
				qw(appendfile buglog getparsedaddrs getmaintainers),
				qw(getmaintainers_reverse)
			       ],
		     misc   => [qw(make_list)],
		     date   => [qw(secs_to_english)],
		     quit   => [qw(quit)],
		     lock   => [qw(filelock unfilelock @cleanups lockpid)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(qw(lock quit date util misc));
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

#use Debbugs::Config qw(:globals);
use Debbugs::Config qw(:config);
use IO::File;
use Debbugs::MIME qw(decode_rfc1522);
use Mail::Address;
use Cwd qw(cwd);

use Fcntl qw(:flock);

our $DEBUG_FH = \*STDERR if not defined $DEBUG_FH;

=head1 UTILITIES

The following functions are exported by the C<:util> tag

=head2 getbugcomponent

     my $file = getbugcomponent($bug_number,$extension,$location)

Returns the path to the bug file in location C<$location>, bug number
C<$bugnumber> and extension C<$extension>

=cut

sub getbugcomponent {
    my ($bugnum, $ext, $location) = @_;

    if (not defined $location) {
	$location = getbuglocation($bugnum, $ext);
	# Default to non-archived bugs only for now; CGI scripts want
	# archived bugs but most of the backend scripts don't. For now,
	# anything that is prepared to accept archived bugs should call
	# getbuglocation() directly first.
	return undef if defined $location and
			($location ne 'db' and $location ne 'db-h');
    }
    my $dir = getlocationpath($location);
    return undef if not defined $dir;
    if (defined $location and $location eq 'db') {
	return "$dir/$bugnum.$ext";
    } else {
	my $hash = get_hashname($bugnum);
	return "$dir/$hash/$bugnum.$ext";
    }
}

=head2 getbuglocation

     getbuglocation($bug_number,$extension)

Returns the the location in which a particular bug exists; valid
locations returned currently are archive, db-h, or db. If the bug does
not exist, returns undef.

=cut

sub getbuglocation {
    my ($bugnum, $ext) = @_;
    my $archdir = get_hashname($bugnum);
    return 'archive' if -r getlocationpath('archive')."/$archdir/$bugnum.$ext";
    return 'db-h' if -r getlocationpath('db-h')."/$archdir/$bugnum.$ext";
    return 'db' if -r getlocationpath('db')."/$bugnum.$ext";
    return undef;
}


=head2 getlocationpath

     getlocationpath($location)

Returns the path to a specific location

=cut

sub getlocationpath {
     my ($location) = @_;
     if (defined $location and $location eq 'archive') {
	  return "$config{spool_dir}/archive";
     } elsif (defined $location and $location eq 'db') {
	  return "$config{spool_dir}/db";
     } else {
	  return "$config{spool_dir}/db-h";
     }
}


=head2 get_hashname

     get_hashname

Returns the hash of the bug which is the location within the archive

=cut

sub get_hashname {
    return "" if ( $_[ 0 ] < 0 );
    return sprintf "%02d", $_[ 0 ] % 100;
}

=head2 buglog

     buglog($bugnum);

Returns the path to the logfile corresponding to the bug.

=cut

sub buglog {
    my $bugnum = shift;
    my $location = getbuglocation($bugnum, 'log');
    return getbugcomponent($bugnum, 'log', $location) if ($location);
    $location = getbuglocation($bugnum, 'log.gz');
    return getbugcomponent($bugnum, 'log.gz', $location);
}


=head2 appendfile

     appendfile($file,'data','to','append');

Opens a file for appending and writes data to it.

=cut

sub appendfile {
	my $file = shift;
	if (!open(AP,">>$file")) {
		print $DEBUG_FH "failed open log<\n" if $DEBUG;
		print $DEBUG_FH "failed open log err $!<\n" if $DEBUG;
		&quit("opening $file (appendfile): $!");
	}
	print(AP @_) || &quit("writing $file (appendfile): $!");
	close(AP) || &quit("closing $file (appendfile): $!");
}

=head2 getparsedaddrs

     my $address = getparsedaddrs($address);
     my @address = getparsedaddrs($address);

Returns the output from Mail::Address->parse, or the cached output if
this address has been parsed before. In SCALAR context returns the
first address parsed.

=cut


our %_parsedaddrs;
sub getparsedaddrs {
    my $addr = shift;
    return () unless defined $addr;
    return wantarray?@{$_parsedaddrs{$addr}}:$_parsedaddrs{$addr}[0]
	 if exists $_parsedaddrs{$addr};
    @{$_parsedaddrs{$addr}} = Mail::Address->parse($addr);
    return wantarray?@{$_parsedaddrs{$addr}}:$_parsedaddrs{$addr}[0];
}

our $_maintainer;
our $_maintainer_rev;
sub getmaintainers {
    return $_maintainer if $_maintainer;
    my %maintainer;
    my %maintainer_rev;
    for my $file (@config{qw(maintainer_file maintainer_file_override)}) {
	 next unless defined $file;
	 my $maintfile = new IO::File $file,'r' or
	      &quitcgi("Unable to open $file: $!");
	 while(<$maintfile>) {
	      next unless m/^(\S+)\s+(\S.*\S)\s*$/;
	      ($a,$b)=($1,$2);
	      $a =~ y/A-Z/a-z/;
	      $maintainer{$a}= $b;
	      for my $maint (map {lc($_->address)} getparsedaddrs($b)) {
		   push @{$maintainer_rev{$maint}},$a;
	      }
	 }
	 close($maintfile);
    }
    $_maintainer = \%maintainer;
    $_maintainer_rev = \%maintainer_rev;
    return $_maintainer;
}
sub getmaintainers_reverse{
     return $_maintainer_rev if $_maintainer_rev;
     getmaintainers();
     return $_maintainer_rev;
}

=head1 DATE

    my $english = secs_to_english($seconds);
    my ($days,$english) = secs_to_english($seconds);

XXX This should probably be changed to use Date::Calc

=cut

sub secs_to_english{
     my ($seconds) = @_;

     my $days = int($seconds / 86400);
     my $years = int($days / 365);
     $days %= 365;
     my $result;
     my @age;
     push @age, "1 year" if ($years == 1);
     push @age, "$years years" if ($years > 1);
     push @age, "1 day" if ($days == 1);
     push @age, "$days days" if ($days > 1);
     $result .= join(" and ", @age);

     return wantarray?(int($seconds/86400),$result):$result;
}


=head1 LOCK

These functions are exported with the :lock tag

=head2 filelock

     filelock

FLOCKs the passed file. Use unfilelock to unlock it.

=cut

our @filelocks;
our @cleanups;

sub filelock {
    # NB - NOT COMPATIBLE WITH `with-lock'
    my ($lockfile) = @_;
    if ($lockfile !~ m{^/}) {
	 $lockfile = cwd().'/'.$lockfile;
    }
    my ($count,$errors);
    $count= 10; $errors= '';
    for (;;) {
	my $fh = eval {
	     my $fh2 = IO::File->new($lockfile,'w')
		  or die "Unable to open $lockfile for writing: $!";
	     flock($fh2,LOCK_EX|LOCK_NB)
		  or die "Unable to lock $lockfile $!";
	     return $fh2;
	};
	if ($@) {
	     $errors .= $@;
	}
	if ($fh) {
	     push @filelocks, {fh => $fh, file => $lockfile};
	     last;
	}
        if (--$count <=0) {
            $errors =~ s/\n+$//;
            &quit("failed to get lock on $lockfile -- $errors");
        }
        sleep 10;
    }
    push(@cleanups,\&unfilelock);
}


=head2 unfilelock

     unfilelock()

Unlocks the file most recently locked.

Note that it is not currently possible to unlock a specific file
locked with filelock.

=cut

sub unfilelock {
    if (@filelocks == 0) {
        warn "unfilelock called with no active filelocks!\n";
        return;
    }
    my %fl = %{pop(@filelocks)};
    pop(@cleanups);
    flock($fl{fh},LOCK_UN)
	 or warn "Unable to unlock lockfile $fl{file}: $!";
    close($fl{fh})
	 or warn "Unable to close lockfile $fl{file}: $!";
    unlink($fl{file})
	 or warn "Unable to unlink lockfile $fl{file}: $!";
}

=head2 lockpid

      lockpid('/path/to/pidfile');

Creates a pidfile '/path/to/pidfile' if one doesn't exist or if the
pid in the file does not respond to kill 0.

Returns 1 on success, false on failure; dies on unusual errors.

=cut

sub lockpid {
     my ($pidfile) = @_;
     if (-e $pidfile) {
	  my $pidfh = IO::File->new($pidfile, 'r') or
	       die "Unable to open pidfile $pidfile: $!";
	  local $/;
	  my $pid = <$pidfh>;
	  ($pid) = $pid =~ /(\d+)/;
	  if (defined $pid and kill(0,$pid)) {
	       return 0;
	  }
	  close $pidfh;
	  unlink $pidfile or
	       die "Unable to unlink stale pidfile $pidfile $!";
     }
     my $pidfh = IO::File->new($pidfile,'w') or
	  die "Unable to open $pidfile for writing: $!";
     print {$pidfh} $$ or die "Unable to write to $pidfile $!";
     close $pidfh or die "Unable to close $pidfile $!";
     return 1;
}


=head1 QUIT

These functions are exported with the :quit tag.

=head2 quit

     quit()

Exits the program by calling die after running some cleanups.

This should be replaced with an END handler which runs the cleanups
instead. (Or possibly a die handler, if the cleanups are important)

=cut

sub quit {
    print $DEBUG_FH "quitting >$_[0]<\n" if $DEBUG;
    my ($u);
    while ($u= $cleanups[$#cleanups]) { &$u; }
    die "*** $_[0]\n";
}

=head1 MISC

These functions are exported with the :misc tag

=head2 make_list

     LIST = make_list(@_);

Turns a scalar or an arrayref into a list; expands a list of arrayrefs
into a list.

That is, make_list([qw(a b c)]); returns qw(a b c); make_list([qw(a
b)],[qw(c d)] returns qw(a b c d);

=cut

sub make_list {
     return map {(ref($_) eq 'ARRAY')?@{$_}:$_} @_;
}



1;

__END__
