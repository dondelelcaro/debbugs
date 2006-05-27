
package Debbugs::Common;

=head1 NAME

Debbugs::Common -- Common routines for all of Debbugs

=head1 SYNOPSIS

use Debbugs::Common qw(:url :html);


=head1 DESCRIPTION

This module is a replacement for the general parts of errorlib.pl.
subroutines in errorlib.pl will be gradually phased out and replaced
with equivalent (or better) functionality here.

=head1 BUGS

This module currently requires /etc/debbugs/config; it should use a
general configuration module so that more intelligent things can be
done.

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
     %EXPORT_TAGS = (#status => [qw(getbugstatus)],
		     read   => [qw(readbug)],
		     util   => [qw(getbugcomponent getbuglocation getlocationpath get_hashname),
			       ],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(qw(read util));
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

#use Debbugs::Config qw(:globals);
use Debbugs::Config qw(:config);
use IO::File;
use Debbugs::MIME qw(decode_rfc1522);

=head2 readbug

     readbug($bug_number,$location)

Reads a summary file from the archive given a bug number and a bug
location. Valid locations are those understood by L</getbugcomponent>

=cut


my %fields = (originator     => 'submitter',
              date           => 'date',
              subject        => 'subject',
              msgid          => 'message-id',
              'package'      => 'package',
              keywords       => 'tags',
              done           => 'done',
              forwarded      => 'forwarded-to',
              mergedwith     => 'merged-with',
              severity       => 'severity',
              owner          => 'owner',
              found_versions => 'found-in',
              fixed_versions => 'fixed-in',
              blocks         => 'blocks',
              blockedby      => 'blocked-by',
             );

# Fields which need to be RFC1522-decoded in format versions earlier than 3.
my @rfc1522_fields = qw(originator subject done forwarded owner);

sub readbug {
    my ($lref, $location) = @_;
    my $status = getbugcomponent($lref, 'summary', $location);
    return undef unless defined $status;
    my $status_fh = new IO::File $status, 'r' or
	 warn "Unable to open $status for reading: $!" and return undef;

    my %data;
    my @lines;
    my $version = 2;
    local $_;

    while (<$status_fh>) {
        chomp;
        push @lines, $_;
        $version = $1 if /^Format-Version: ([0-9]+)/i;
    }

    # Version 3 is the latest format version currently supported.
    return undef if $version > 3;

    my %namemap = reverse %fields;
    for my $line (@lines) {
        if ($line =~ /(\S+?): (.*)/) {
            my ($name, $value) = (lc $1, $2);
            $data{$namemap{$name}} = $value if exists $namemap{$name};
        }
    }
    for my $field (keys %fields) {
        $data{$field} = '' unless exists $data{$field};
    }

    $data{severity} = $config{default_severity} if $data{severity} eq '';
    $data{found_versions} = [split ' ', $data{found_versions}];
    $data{fixed_versions} = [split ' ', $data{fixed_versions}];

    if ($version < 3) {
	for my $field (@rfc1522_fields) {
	    $data{$field} = decode_rfc1522($data{$field});
	}
    }

    return \%data;
}


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
    return undef if not defined $location;
    my $dir = getlocationpath($location);
    return undef if not defined $dir;
    if ($location eq 'db') {
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




1;

__END__
