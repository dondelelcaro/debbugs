package Debbugs::Log;

use strict;

use Exporter ();
use vars qw($VERSION @ISA @EXPORT);

BEGIN {
    $VERSION = 1.00;

    @ISA = qw(Exporter);
    @EXPORT = qw(read_log_records write_log_records);
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

[mail] must start with /^Received: \(at \S+\) by \S+;/, and is copied to the
output.

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

No other types of records are permitted, and the file must end with a ^C
line.

=back

=head2 Perl Record Representation

Each record is a hash. The C<type> field is C<incoming-recv>, C<autocheck>,
C<recips>, or C<html> as above; C<mail> and C<html> contain text as above;
C<recips> is a reference to an array of recipients (strings), or undef for
C<-t>.

=head1 FUNCTIONS

=over 4

=item read_log_records

Takes a .log filehandle as input, and returns an array of all records in
that file. Throws exceptions using die(), so you may want to wrap this in an
eval().

=cut

sub read_log_records (*)
{
    my $logfh = shift;

    # This comes from bugreport.cgi, but is much simpler since it doesn't
    # worry about the details of output.

    my %states = (
	1 => 'autocheck',
	2 => 'recips',
	3 => 'kill-end',
	5 => 'go',
	6 => 'html',
	7 => 'incoming-recv',
    );

    my @records;

    my $normstate = 'kill-init';
    my $linenum = 0;
    my $record = {};

    while (defined (my $line = <$logfh>)) {
	chomp $line;
	++$linenum;
	if (length($line) == 1 and exists $states{ord($line)}) {
	    # state transitions
	    my $newstate = $states{ord($line)};

	    # disallowed transitions
	    $_ = "$normstate $newstate";
	    unless (/^(go|go-nox|html) kill-end$/ or
		    /^(kill-init|kill-end) (incoming-recv|autocheck|recips|html)$/ or
		    /^kill-body go$/) {
		die "transition from $normstate to $newstate at $linenum disallowed";
	    }

	    if ($newstate =~ /^(autocheck|recips|html|incoming-recv)$/) {
		$record->{type} = $newstate;
	    } elsif ($newstate eq 'kill-end') {
		push @records, $record;
		$record = {};
	    }

	    $normstate = $newstate;
	    next;
	}

	$_ = $line;
	if ($normstate eq 'incoming-recv') {
	    my $pl = $_;
	    unless (/^Received: \(at \S+\) by \S+;/) {
		die "bad line '$pl' in state incoming-recv";
	    }
	    $normstate = 'go';
	    $record->{text} .= "$_\n";
	} elsif ($normstate eq 'html') {
	    $record->{text} .= "$_\n";
	} elsif ($normstate eq 'go') {
	    s/^\030//;
	    $record->{text} .= "$_\n";
	} elsif ($normstate eq 'go-nox') {
	    $record->{text} .= "$_\n";
	} elsif ($normstate eq 'recips') {
	    if (/^-t$/) {
		undef $record->{recips};
	    } else {
		# preserve trailing null fields, e.g. #2298
		$record->{recips} = [split /\04/, $_, -1];
	    }
	    $normstate = 'kill-body';
	} elsif ($normstate eq 'autocheck') {
	    $record->{text} .= "$_\n";
	    next if !/^X-Debian-Bugs(-\w+)?: This is an autoforward from (\S+)/;
	    $normstate = 'autowait';
	} elsif ($normstate eq 'autowait') {
	    $record->{text} .= "$_\n";
	    next if !/^$/;
	    $normstate = 'go-nox';
	} else {
	    die "state $normstate at line $linenum ('$_')";
	}
    }
    die "state $normstate at end" unless $normstate eq 'kill-end';

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
	my $text = $record->{text};
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
	    $text =~ s/^([\01-\07\030])/\030$1/gm;
	    print $logfh "\05\n$text\03\n";
	} elsif ($type eq 'html') {
	    print $logfh "\06\n$text\03\n";
	} elsif ($type eq 'incoming-recv') {
	    $text =~ s/^([\01-\07\030])/\030$1/gm;
	    print $logfh "\07\n$text\03\n";
	} else {
	    die "unknown type '$type'";
	}
    }

    1;
}

=back

=head1 CAVEATS

This module does none of the formatting that bugreport.cgi et al do. It's
simply a means for extracting and rewriting raw records.

=cut

1;
