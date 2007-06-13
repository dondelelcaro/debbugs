# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# go here too.]
# Copyright 2004 by Collin Watson <cjwatson@debian.org>
# Copyright 2007 by Don Armstrong <don@donarmstrong.com>


package Debbugs::Log;


use warnings;
use strict;

use vars qw($VERSION $DEBUG @EXPORT @EXPORT_OK %EXPORT_TAGS);
use base qw(Exporter);

BEGIN {
    $VERSION = 1.00;
    $DEBUG = 0 unless defined $DEBUG;

    @EXPORT = ();
    %EXPORT_TAGS = (write => [qw(write_log_records),
			     ],
		    read  => [qw(read_log_records),
			     ],
		    misc  => [qw(escape_log),
			     ],
		   );
    @EXPORT_OK = ();
    Exporter::export_ok_tags(qw(write read misc));
    $EXPORT_TAGS{all} = [@EXPORT_OK];
}

=head1 NAME

Debbugs::Log - an interface to debbugs .log files

=head1 DESCRIPTION

The Debbugs::Log module provides a convenient way for scripts to read and
write the .log files used by debbugs to store the complete textual records
of all bug transactions.

=head2 The .log File Format

.log files consist of a sequence of records, of one of the following four
types. ^A, ^B, etc. represent those control characters.

=over 4

=item incoming-recv

  ^G
  [mail]
  ^C

C<[mail]> must start with /^Received: \(at \S+\) by \S+;/, and is copied to
the output.

=item autocheck

Auto-forwarded messages are recorded like this:

  ^A
  [mail]
  ^C

C<[mail]> must contain /^X-Debian-Bugs(-\w+)?: This is an autoforward from
\S+/. The first line matching that is removed; all lines in the message body
that begin with 'X' will be copied to the output, minus the 'X'.

Nothing in debbugs actually generates this record type any more, but it may
still be in old .logs at some sites.

=item recips

  ^B
  [recip]^D[recip]^D[...] OR -t
  ^E
  [mail]
  ^C

Each [recip] is output after "Message sent"; C<-t> represents the same
sendmail option, indicating that the recipients are taken from the headers
of the message itself.

=item html

  ^F
  [html]
  ^C

[html] is copied unescaped to the output. The record immediately following
this one is considered "boring" and only shown in certain output modes.

(This is a design flaw in the log format, since it makes it difficult to
change the HTML presentation later, or to present the data in an entirely
different format.)

=back

No other types of records are permitted, and the file must end with a ^C
line.

=cut

my %states = (
    1 => 'autocheck',
    2 => 'recips',
    3 => 'kill-end',
    5 => 'go',
    6 => 'html',
    7 => 'incoming-recv',
);

=head2 Perl Record Representation

Each record is a hash. The C<type> field is C<incoming-recv>, C<autocheck>,
C<recips>, or C<html> as above; C<text> contains text from C<[mail]> or
C<[html]> as above; C<recips> is a reference to an array of recipients
(strings), or undef for C<-t>.

=head1 FUNCTIONS

=over 4

=item new

Creates a new log reader based on a .log filehandle.

=cut

sub new
{
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $self->{logfh} = shift;
    $self->{state} = 'kill-init';
    $self->{linenum} = 0;
    return $self;
}

=item read_record

Reads and returns a single record from a log reader object. At end of file,
returns undef. Throws exceptions using die(), so you may want to wrap this
in an eval().

=cut

sub read_record
{
    my $this = shift;
    my $logfh = $this->{logfh};

    # This comes from bugreport.cgi, but is much simpler since it doesn't
    # worry about the details of output.

    my $record = {};

    while (defined (my $line = <$logfh>)) {
	chomp $line;
	++$this->{linenum};
	if (length($line) == 1 and exists $states{ord($line)}) {
	    # state transitions
	    my $newstate = $states{ord($line)};

	    # disallowed transitions
	    $_ = "$this->{state} $newstate";
	    unless (/^(go|go-nox|html) kill-end$/ or
		    /^(kill-init|kill-end) (incoming-recv|autocheck|recips|html)$/ or
		    /^kill-body go$/) {
		die "transition from $this->{state} to $newstate at $this->{linenum} disallowed";
	    }

	    $this->{state} = $newstate;

	    if ($this->{state} =~ /^(autocheck|recips|html|incoming-recv)$/) {
		$record->{type} = $this->{state};
	    } elsif ($this->{state} eq 'kill-end') {
		return $record;
	    }

	    next;
	}

	$_ = $line;
	if ($this->{state} eq 'incoming-recv') {
	    my $pl = $_;
	    unless (/^Received: \(at \S+\) by \S+;/) {
		die "bad line '$pl' in state incoming-recv";
	    }
	    $this->{state} = 'go';
	    $record->{text} .= "$_\n";
	} elsif ($this->{state} eq 'html') {
	    $record->{text} .= "$_\n";
	} elsif ($this->{state} eq 'go') {
	    s/^\030//;
	    $record->{text} .= "$_\n";
	} elsif ($this->{state} eq 'go-nox') {
	    $record->{text} .= "$_\n";
	} elsif ($this->{state} eq 'recips') {
	    if (/^-t$/) {
		undef $record->{recips};
	    } else {
		# preserve trailing null fields, e.g. #2298
		$record->{recips} = [split /\04/, $_, -1];
	    }
	    $this->{state} = 'kill-body';
	} elsif ($this->{state} eq 'autocheck') {
	    $record->{text} .= "$_\n";
	    next if !/^X-Debian-Bugs(-\w+)?: This is an autoforward from (\S+)/;
	    $this->{state} = 'autowait';
	} elsif ($this->{state} eq 'autowait') {
	    $record->{text} .= "$_\n";
	    next if !/^$/;
	    $this->{state} = 'go-nox';
	} else {
	    die "state $this->{state} at line $this->{linenum} ('$_')";
	}
    }
    die "state $this->{state} at end" unless $this->{state} eq 'kill-end';

    if (keys %$record) {
	return $record;
    } else {
	return undef;
    }
}

=item read_log_records

Takes a .log filehandle as input, and returns an array of all records in
that file. Throws exceptions using die(), so you may want to wrap this in an
eval().

=cut

sub read_log_records (*)
{
    my $logfh = shift;

    my @records;
    my $reader = Debbugs::Log->new($logfh);
    while (defined(my $record = $reader->read_record())) {
	push @records, $record;
    }
    return @records;
}

=item write_log_records

Takes a filehandle and a list of records as input, and prints the .log
format representation of those records to that filehandle.

=cut

sub write_log_records (*@)
{
    my $logfh = shift;
    my @records = @_;

    for my $record (@records) {
	my $type = $record->{type};
	my ($text) = escapelog($record->{text});
	die "type '$type' with no text field" unless defined $text;
	if ($type eq 'autocheck') {
	    print $logfh "\01\n$text\03\n";
	} elsif ($type eq 'recips') {
	    print $logfh "\02\n";
	    my $recips = $record->{recips};
	    if (defined $recips) {
		die "recips not undef or array"
		    unless ref($recips) eq 'ARRAY';
		print $logfh join("\04", @$recips) . "\n";
	    } else {
		print $logfh "-t\n";
	    }
	    #$text =~ s/^([\01-\07\030])/\030$1/gm;
	    print $logfh "\05\n$text\03\n";
	} elsif ($type eq 'html') {
	    print $logfh "\06\n$text\03\n";
	} elsif ($type eq 'incoming-recv') {
	    #$text =~ s/^([\01-\07\030])/\030$1/gm;
	    print $logfh "\07\n$text\03\n";
	} else {
	    die "unknown type '$type'";
	}
    }

    1;
}

=head2 escapelog

     print {$log} escapelog(@log)

Applies the log escape regex to the passed logfile.

=cut

sub escape_log {
	my @log = @_;
	return map { s/^([\01-\07\030])/\030$1/gm; $_ } @log;
}


=back

=head1 CAVEATS

This module does none of the formatting that bugreport.cgi et al do. It's
simply a means for extracting and rewriting raw records.

=cut

1;
