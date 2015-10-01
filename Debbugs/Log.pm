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
		    read  => [qw(read_log_records record_text record_regex),
			     ],
		    misc  => [qw(escape_log),
			     ],
		   );
    @EXPORT_OK = ();
    Exporter::export_ok_tags(qw(write read misc));
    $EXPORT_TAGS{all} = [@EXPORT_OK];
}

use Carp;

use Debbugs::Common qw(getbuglocation getbugcomponent make_list);
use Params::Validate qw(:types validate_with);
use Encode qw(encode encode_utf8 is_utf8);
use IO::InnerFile;

=head1 NAME

Debbugs::Log - an interface to debbugs .log files

=head1 DESCRIPTION

The Debbugs::Log module provides a convenient way for scripts to read and
write the .log files used by debbugs to store the complete textual records
of all bug transactions.

Debbugs::Log does not decode utf8 into perl's internal encoding or
encode into utf8 from perl's internal encoding. For html records and
all recips, this should probably be done. For other records, this should
not be needed.

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

      my $log = Debbugs::Log->new($logfh);
      my $log = Debbugs::Log->new(bug_num => $nnn);
      my $log = Debbugs::Log->new(logfh => $logfh);

Parameters

=over

=item bug_num -- bug number

=item logfh -- log filehandle

=item log_name -- name of log

=back

One of the above options must be passed.

=cut

sub new
{
    my $this = shift;
    my %param;
    if (@_ == 1) {
	 ($param{logfh}) = @_;
	 $param{inner_file} = 0;
    }
    else {
	 %param = validate_with(params => \@_,
				spec   => {bug_num => {type => SCALAR,
						       optional => 1,
						      },
					   logfh   => {type => HANDLE,
						       optional => 1,
						      },
					   log_name => {type => SCALAR,
							optional => 1,
                                   },
                           inner_file => {type => BOOLEAN,
                                          default => 0,
                                         },
					  }
			       );
    }
    if (grep({exists $param{$_} and defined $param{$_}} qw(bug_num logfh log_name)) ne 1) {
	 croak "Exactly one of bug_num, logfh, or log_name must be passed and must be defined";
    }

    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

    if (exists $param{logfh}) {
	 $self->{logfh} = $param{logfh}
    }
    elsif (exists $param{log_name}) {
	 $self->{logfh} = IO::File->new($param{log_name},'r') or
	      die "Unable to open bug log $param{log_name} for reading: $!";
    }
    elsif (exists $param{bug_num}) {
	 my $location = getbuglocation($param{bug_num},'log');
	 my $bug_log = getbugcomponent($param{bug_num},'log',$location);
	 $self->{logfh} = IO::File->new($bug_log, 'r') or
	      die "Unable to open bug log $bug_log for reading: $!";
    }

    $self->{state} = 'kill-init';
    $self->{linenum} = 0;
    $self->{inner_file} = $param{inner_file};
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
            $record->{start} = $logfh->tell;
            $record->{stop} = $logfh->tell;
            $record->{inner_file} = $this->{inner_file};
	    } elsif ($this->{state} eq 'kill-end') {
            if ($this->{inner_file}) {
                $record->{fh} = IO::InnerFile->new($logfh,$record->{start},$record->{stop} - $record->{start})
            }
		return $record;
	    }

	    next;
	}
    $record->{stop} = $logfh->tell;
	$_ = $line;
	if ($this->{state} eq 'incoming-recv') {
	    my $pl = $_;
	    unless (/^Received: \(at \S+\) by \S+;/) {
		die "bad line '$pl' in state incoming-recv";
	    }
	    $this->{state} = 'go';
	    $record->{text} .= "$_\n" unless $this->{inner_file};
	} elsif ($this->{state} eq 'html') {
	    $record->{text} .= "$_\n"  unless $this->{inner_file};
	} elsif ($this->{state} eq 'go') {
	    s/^\030//;
	    $record->{text} .= "$_\n"  unless $this->{inner_file};
	} elsif ($this->{state} eq 'go-nox') {
	    $record->{text} .= "$_\n"  unless $this->{inner_file};
	} elsif ($this->{state} eq 'recips') {
	    if (/^-t$/) {
		undef $record->{recips};
	    } else {
		# preserve trailing null fields, e.g. #2298
		$record->{recips} = [split /\04/, $_, -1];
	    }
	    $this->{state} = 'kill-body';
        $record->{start} = $logfh->tell+2;
        $record->{stop} = $logfh->tell+2;
        $record->{inner_file} = $this->{inner_file};
	} elsif ($this->{state} eq 'autocheck') {
	    $record->{text} .= "$_\n" unless $this->{inner_file};
	    next if !/^X-Debian-Bugs(-\w+)?: This is an autoforward from (\S+)/;
	    $this->{state} = 'autowait';
	} elsif ($this->{state} eq 'autowait') {
	    $record->{text} .= "$_\n" unless $this->{inner_file};
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

Uses exactly the same options as Debbugs::Log::new

=cut

sub read_log_records
{
    my %param;
    if (@_ == 1) {
	 ($param{logfh}) = @_;
    }
    else {
	 %param = validate_with(params => \@_,
				spec   => {bug_num => {type => SCALAR,
						       optional => 1,
						      },
					   logfh   => {type => HANDLE,
						       optional => 1,
						      },
					   log_name => {type => SCALAR,
							optional => 1,
						       },
                           inner_file => {type => BOOLEAN,
                                          default => 0,
                                         },
					  }
			       );
    }
    if (grep({exists $param{$_} and defined $param{$_}} qw(bug_num logfh log_name)) ne 1) {
	 croak "Exactly one of bug_num, logfh, or log_name must be passed and must be defined";
    }

    my @records;
    my $reader = Debbugs::Log->new(%param);
    while (defined(my $record = $reader->read_record())) {
	push @records, $record;
    }
    return @records;
}

=item write_log_records

Takes a filehandle and a list of records as input, and prints the .log
format representation of those records to that filehandle.

=back

=cut

sub write_log_records
{
    my %param = validate_with(params => \@_,
			      spec   => {bug_num => {type => SCALAR,
						     optional => 1,
						    },
					 logfh   => {type => HANDLE,
						     optional => 1,
						    },
					 log_name => {type => SCALAR,
						      optional => 1,
						     },
					 records => {type => HASHREF|ARRAYREF,
						    },
					},
			     );
    if (grep({exists $param{$_} and defined $param{$_}} qw(bug_num logfh log_name)) ne 1) {
	 croak "Exactly one of bug_num, logfh, or log_name must be passed and must be defined";
    }
    my $logfh;
    if (exists $param{logfh}) {
	 $logfh = $param{logfh}
    }
    elsif (exists $param{log_name}) {
	 $logfh = IO::File->new(">>$param{log_name}") or
	      die "Unable to open bug log $param{log_name} for writing: $!";
    }
    elsif (exists $param{bug_num}) {
	 my $location = getbuglocation($param{bug_num},'log');
	 my $bug_log = getbugcomponent($param{bug_num},'log',$location);
	 $logfh = IO::File->new($bug_log, 'r') or
	      die "Unable to open bug log $bug_log for reading: $!";
    }
    my @records = make_list($param{records});

    for my $record (@records) {
	my $type = $record->{type};
	croak "record type '$type' with no text field" unless defined $record->{text};
	# I am not sure if we really want to croak here; but this is
	# almost certainly a bug if is_utf8 is on.
        my $text = $record->{text};
        if (is_utf8($text)) {
            carp('Record text was in the wrong encoding (perl internal instead of utf8 octets)');
            $text = encode_utf8($text)
        }
	($text) = escape_log($text);
	if ($type eq 'autocheck') {
	    print {$logfh} "\01\n$text\03\n" or
		die "Unable to write to logfile: $!";
	} elsif ($type eq 'recips') {
	    print {$logfh} "\02\n";
	    my $recips = $record->{recips};
	    if (defined $recips) {
		croak "recips not undef or array"
		    unless ref($recips) eq 'ARRAY';
                my $wrong_encoding = 0;
                my @recips =
                    map { if (is_utf8($_)) {
                        $wrong_encoding=1;
                        encode_utf8($_);
                    } else {
                        $_;
                    }} @$recips;
                carp('Recipients was in the wrong encoding (perl internal instead of utf8 octets') if $wrong_encoding;
		print {$logfh} join("\04", @$recips) . "\n" or
		    die "Unable to write to logfile: $!";
	    } else {
		print {$logfh} "-t\n" or
		    die "Unable to write to logfile: $!";
	    }
	    #$text =~ s/^([\01-\07\030])/\030$1/gm;
	    print {$logfh} "\05\n$text\03\n" or
		die "Unable to write to logfile: $!";
	} elsif ($type eq 'html') {
	    print {$logfh} "\06\n$text\03\n" or
		die "Unable to write to logfile: $!";
	} elsif ($type eq 'incoming-recv') {
	    #$text =~ s/^([\01-\07\030])/\030$1/gm;
	    print {$logfh} "\07\n$text\03\n" or
		die "Unable to write to logfile: $!";
	} else {
	    croak "unknown record type type '$type'";
	}
    }

    1;
}

=head2 escape_log

     print {$log} escape_log(@log)

Applies the log escape regex to the passed logfile.

=cut

sub escape_log {
	my @log = @_;
	return map {s/^([\01-\07\030])/\030$1/gm; $_ } @log;
}


sub record_text {
    my ($record) = @_;
    if ($record->{inner_file}) {
        local $/;
        my $text;
        my $t = $record->{fh};
        $text = <$t>;
        $record->{fh}->seek(0,0);
        return $text;
    } else {
        return $record->{text};
    }
}

sub record_regex {
    my ($record,$regex) = @_;
    if ($record->{inner_file}) {
        my @result;
        my $fh = $record->{fh};
        while (<$fh>) {
            if (@result = $_ =~ m/$regex/) {
                $record->{fh}->seek(0,0);
                return @result;
            }
        }
        $record->{fh}->seek(0,0);
        return ();
    } else {
        my @result = $record->{text} =~ m/$regex/;
        return @result;
        return $record->{text};
    }
}


=head1 CAVEATS

This module does none of the formatting that bugreport.cgi et al do. It's
simply a means for extracting and rewriting raw records.

=cut

1;
