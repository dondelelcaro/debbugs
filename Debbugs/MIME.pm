# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# go here too.]
# Copyright 2006 by Don Armstrong <don@donarmstrong.com>.


package Debbugs::MIME;

=head1 NAME

Debbugs::MIME -- Mime handling routines for debbugs

=head1 SYNOPSIS

 use Debbugs::MIME qw(parse decode_rfc1522);

=head1 DESCRIPTION


=head1 BUGS

None known.

=cut

use warnings;
use strict;

use base qw(Exporter);
use vars qw($DEBUG $VERSION @EXPORT_OK %EXPORT_TAGS @EXPORT);

BEGIN {
    $VERSION = 1.00;
    $DEBUG = 0 unless defined $DEBUG;

    @EXPORT = ();

    %EXPORT_TAGS = (mime => [qw(parse create_mime_message getmailbody)],
		    rfc1522 => [qw(decode_rfc1522 encode_rfc1522)],
		    utf8 => [qw(convert_to_utf8)],
		   );
    @EXPORT_OK=();
    Exporter::export_ok_tags(keys %EXPORT_TAGS);
    $EXPORT_TAGS{all} = [@EXPORT_OK];
}

use File::Path;
use File::Temp qw();
use MIME::Parser;

use POSIX qw(strftime);
use List::MoreUtils qw(apply);

# for decode_rfc1522
use MIME::WordDecoder qw();
use Encode qw(decode encode encode_utf8 decode_utf8 is_utf8);
use Text::Iconv;

# for encode_rfc1522
use MIME::Words qw();

sub getmailbody
{
    my $entity = shift;
    my $type = $entity->effective_type;
    if ($type eq 'text/plain' or
	    ($type =~ m#text/?# and $type ne 'text/html') or
	    $type eq 'application/pgp') {
	return $entity->bodyhandle;
    } elsif ($type eq 'multipart/alternative') {
	# RFC 2046 says we should use the last part we recognize.
	for my $part (reverse $entity->parts) {
	    my $ret = getmailbody($part);
	    return $ret if $ret;
	}
    } else {
	# For other multipart types, we just pretend they're
	# multipart/mixed and run through in order.
	for my $part ($entity->parts) {
	    my $ret = getmailbody($part);
	    return $ret if $ret;
	}
    }
    return undef;
}

sub parse
{
    # header and decoded body respectively
    my (@headerlines, @bodylines);

    my $parser = MIME::Parser->new();
    my $tempdir = File::Temp::tempdir();
    $parser->output_under($tempdir);
    my $entity = eval { $parser->parse_data($_[0]) };

    if ($entity and $entity->head->tags) {
	@headerlines = @{$entity->head->header};
	chomp @headerlines;

	my $entity_body = getmailbody($entity);
	@bodylines = $entity_body ? $entity_body->as_lines() : ();
	chomp @bodylines;
    } else {
	# Legacy pre-MIME code, kept around in case MIME::Parser fails.
	my @msg = split /\n/, $_[0];
	my $i;

	for ($i = 0; $i <= $#msg; ++$i) {
	    $_ = $msg[$i];
	    last unless length;
	    while ($msg[$i + 1] =~ /^\s/) {
		++$i;
		$_ .= "\n" . $msg[$i];
	    }
	    push @headerlines, $_;
	}

	@bodylines = @msg[$i .. $#msg];
    }

    rmtree $tempdir, 0, 1;

    # Remove blank lines.
    shift @bodylines while @bodylines and $bodylines[0] !~ /\S/;

    # Strip off RFC2440-style PGP clearsigning.
    if (@bodylines and $bodylines[0] =~ /^-----BEGIN PGP SIGNED/) {
	shift @bodylines while @bodylines and
	    length $bodylines[0] and
		# we currently don't strip \r; handle this for the
		# time being, though eventually it should be stripped
		# too, I think. [See #565981]
		$bodylines[0] ne "\r";
	shift @bodylines while @bodylines and $bodylines[0] !~ /\S/;
	for my $findsig (0 .. $#bodylines) {
	    if ($bodylines[$findsig] =~ /^-----BEGIN PGP SIGNATURE/) {
		$#bodylines = $findsig - 1;
		last;
	    }
	}
	map { s/^- // } @bodylines;
    }

    return { header => [@headerlines], body => [@bodylines]};
}

=head2 create_mime_message

     create_mime_message([To=>'don@debian.org'],$body,[$attach1, $attach2],$include_date);

Creates a MIME encoded message with headers given by the first
argument, and a message given by the second.

Optional attachments can be specified in the third arrayref argument.

Whether to include the date in the header is the final argument; it
defaults to true, setting the Date header if one is not already
present.

Headers are passed directly to MIME::Entity::build, the message is the
first attachment.

Each of the elements of the attachment arrayref is attached as an
rfc822 message if it is a scalar or an arrayref; otherwise if it is a
hashref, the contents are passed as an argument to
MIME::Entity::attach

=cut

sub create_mime_message{
     my ($headers,$body,$attachments,$include_date) = @_;
     $attachments = [] if not defined $attachments;
     $include_date = 1 if not defined $include_date;

     die "The first argument to create_mime_message must be an arrayref" unless ref($headers) eq 'ARRAY';
     die "The third argument to create_mime_message must be an arrayref" unless ref($attachments) eq 'ARRAY';

     if ($include_date) {
	 my %headers = apply {lc($_)} @{$headers};
	 if (not exists $headers{date}) {
	     push @{$headers},
		 ('Date',
		  strftime("%a, %d %b %Y %H:%M:%S +0000",gmtime)
		 );
	 }
     }

     # Build the message
     # MIME::Entity is stupid, and doesn't rfc1522 encode its headers, so we do it for it.
     my $msg = MIME::Entity->build('Content-Type' => 'text/plain; charset=utf-8',
				   'Encoding'     => 'quoted-printable',
				   (map{encode_rfc1522($_)} @{$headers}),
				   Data    => $body
				  );

     # Attach the attachments
     for my $attachment (@{$attachments}) {
	  if (ref($attachment) eq 'HASH') {
	       $msg->attach(%{$attachment});
	  }
	  else {
	       # This is *craptacular*, but because various MTAs
	       # (sendmail and exim4, at least) appear to eat From
	       # lines in message/rfc822 attachments, we need eat
	       # the entire From line ourselves so the MTA doesn't
	       # leave \n detrius around.
	       if (ref($attachment) eq 'ARRAY' and $attachment->[1] =~ /^From /) {
		    # make a copy so that we don't screw up anything
		    # that is expecting this arrayref to stay constant
		    $attachment = [@{$attachment}];
		    # remove the from line
		    splice @$attachment, 1, 1;
	       }
	       elsif (not ref($attachment)) {
		    # It's a scalar; remove the from line
		    $attachment =~ s/^(Received:[^\n]+\n)(From [^\n]+\n)/$1/s;
	       }
	       $msg->attach(Type => 'message/rfc822',
			    Data => $attachment,
			    Encoding => '7bit',
			   );
	  }
     }
     return $msg->as_string;
}


# Bug #61342 et al.

sub convert_to_utf8 {
     my ($data, $charset) = @_;
     # raw data just gets returned (that's the charset WordDecorder
     # uses when it doesn't know what to do)
     return $data if not defined $data;
     return $data if $charset eq 'raw' or is_utf8($data,1);
     my $result;
     eval {
	 my $converter = Text::Iconv->new($charset,"utf-8") or
	     die "Unable to create converter for charset '$charset'";
	 $result = decode_utf8($converter->convert($data));
	 die "Error while converting" if not defined $converter->retval() or not defined $result;
     };
     if ($@) {
	  warn "Unable to decode charset; '$charset' and '$data': $@";
	  return $data;
     }
     return $result;
}


=head2 decode_rfc1522

    decode_rfc1522('=?iso-8859-1?Q?D=F6n_Armstr=F3ng?= <don@donarmstrong.com>')

Turn RFC-1522 names into the UTF-8 equivalent.

=cut

BEGIN {
    # Set up the default RFC1522 decoder, which turns all charsets that
    # are supported into the appropriate UTF-8 charset.
    MIME::WordDecoder->default(new MIME::WordDecoder(
	['*' => \&convert_to_utf8,
	]));
}

sub decode_rfc1522 {
    my ($string) = @_;

    # this is craptacular, but leading space is hacked off by unmime.
    # Save it.
    my $leading_space = '';
    $leading_space = $1 if $string =~ s/^(\s+)//;
    # unmime calls the default MIME::WordDecoder handler set up at
    # initialization time.
    return $leading_space . MIME::WordDecoder::unmime($string);
}

=head2 encode_rfc1522

     encode_rfc1522('Dön Armströng <don@donarmstrong.com>')

Encodes headers according to the RFC1522 standard by calling
MIME::Words::encode_mimeword on distinct words as appropriate.

=cut

# We cannot use MIME::Words::encode_mimewords because that function
# does not handle spaces properly at all.

sub encode_rfc1522 {
     my ($rawstr) = @_;

     # handle being passed undef properly
     return undef if not defined $rawstr;
     if (is_utf8($rawstr)) {
	 $rawstr= encode_utf8($rawstr);
     }
     # We process words in reverse so we can preserve spacing between
     # encoded words. This regex splits on word|nonword boundaries and
     # nonword|nonword boundaries. We also consider parenthesis and "
     # to be nonwords to avoid escaping them in comments in violation
     # of RFC1522
     my @words = reverse split /(?:(?<=[\s\n\)\(\"])|(?=[\s\n\)\(\"]))/m, $rawstr;

     my $previous_word_encoded = 0;
     my $string = '';
     for my $word (@words) {
	  if ($word !~ m#[\x00-\x1F\x7F-\xFF]#o and $word ne ' ') {
	       $string = $word.$string;
	       $previous_word_encoded=0;
	  }
	  elsif ($word =~ /^[\s\n]$/) {
	       $string = $word.$string;
	       $previous_word_encoded = 0 if $word eq "\n";
	  }
	  else {
	       my $encoded = MIME::Words::encode_mimeword($word, 'q', 'UTF-8');
	       # RFC 1522 mandates that segments be at most 76 characters
	       # long. If that's the case, we split the word up into 10
	       # character pieces and encode it. We must use the Encode
	       # magic here to avoid breaking on bit boundaries here.
	       if (length $encoded > 75) {
		    # Turn utf8 into the internal perl representation
		    # so . is a character, not a byte.
		    my $tempstr = is_utf8($word)?$word:decode_utf8($word,Encode::FB_DEFAULT);
		    my @encoded;
		    # Strip it into 10 character long segments, and encode
		    # the segments
		    # XXX It's possible that these segments are > 76 characters
		    while ($tempstr =~ s/(.{1,10})$//) {
			 # turn the character back into the utf8 representation.
			 my $tempword = encode_utf8($1);
			 # It may actually be better to eventually use
			 # the base64 encoding here, but I'm not sure
			 # if that's as widely supported as quoted
			 # printable.
			 unshift @encoded, MIME::Words::encode_mimeword($tempword,'q','UTF-8');
		    }
		    $encoded = join(" ",@encoded);
		    # If the previous word was encoded, we must
		    # include a trailing _ that gets encoded as a
		    # space.
		    $encoded =~ s/\?\=$/_\?\=/ if $previous_word_encoded;
		    $string = $encoded.$string;
	       }
	       else {
		    # If the previous word was encoded, we must
		    # include a trailing _ that gets encoded as a
		    # space.
		    $encoded =~ s/\?\=$/_\?\=/ if $previous_word_encoded;
		    $string = $encoded.$string;
	       }
	       $previous_word_encoded = 1;
	  }
     }
     return $string;
}

1;
