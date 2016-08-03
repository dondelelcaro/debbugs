# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# go here too.]
# Copyright 2006 by Don Armstrong <don@donarmstrong.com>.


package Debbugs::MIME;

=encoding utf8

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

use Exporter qw(import);
use vars qw($DEBUG $VERSION @EXPORT_OK %EXPORT_TAGS @EXPORT);

BEGIN {
    $VERSION = 1.00;
    $DEBUG = 0 unless defined $DEBUG;

    @EXPORT = ();

    %EXPORT_TAGS = (mime => [qw(parse create_mime_message getmailbody)],
		    rfc1522 => [qw(decode_rfc1522 encode_rfc1522)],
		   );
    @EXPORT_OK=();
    Exporter::export_ok_tags(keys %EXPORT_TAGS);
    $EXPORT_TAGS{all} = [@EXPORT_OK];
}

use File::Path qw(remove_tree);
use File::Temp qw(tempdir);
use MIME::Parser;

use POSIX qw(strftime);
use List::MoreUtils qw(apply);

# for convert_to_utf8
use Debbugs::UTF8 qw(convert_to_utf8);

# for decode_rfc1522 and encode_rfc1522
use Encode qw(decode encode encode_utf8 decode_utf8 is_utf8);
use MIME::Words qw();

sub getmailbody
{
    my $entity = shift;
    my $type = $entity->effective_type;
    if ($type eq 'text/plain' or
	    ($type =~ m#text/?# and $type ne 'text/html') or
	    $type eq 'application/pgp') {
	return $entity;
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
    my $tempdir = tempdir(CLEANUP => 1);
    $parser->output_under($tempdir);
    my $entity = eval { $parser->parse_data($_[0]) };

    if ($entity and $entity->head->tags) {
	@headerlines = @{$entity->head->header};
	chomp @headerlines;

        my $entity_body = getmailbody($entity);
	my $entity_body_handle;
        my $charset;
        if (defined $entity_body) {
            $entity_body_handle = $entity_body->bodyhandle();
            $charset = $entity_body->head()->mime_attr('content-type.charset');
        }
	@bodylines = $entity_body_handle ? $entity_body_handle->as_lines() : ();
        @bodylines = map {convert_to_utf8($_,$charset)} @bodylines;
	chomp @bodylines;
    } else {
	# Legacy pre-MIME code, kept around in case MIME::Parser fails.
	my @msg = split /\n/, $_[0];
	my $i;

        # assume us-ascii unless charset is set; probably bad, but we
        # really shouldn't get to this point anyway
        my $charset = 'us-ascii';
	for ($i = 0; $i <= $#msg; ++$i) {
	    $_ = $msg[$i];
	    last unless length;
	    while ($msg[$i + 1] =~ /^\s/) {
		++$i;
		$_ .= "\n" . $msg[$i];
	    }
            if (/charset=\"([^\"]+)\"/) {
                $charset = $1;
            }
	    push @headerlines, $_;
	}
	@bodylines = map {convert_to_utf8($_,$charset)} @msg[$i .. $#msg];
    }

    remove_tree($tempdir,{verbose => 0, safe => 1});

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
	 my %headers = apply {defined $_ ? lc($_) : ''} @{$headers};
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
				   (map{encode_rfc1522(encode_utf8(defined $_ ? $_:''))} @{$headers}),
				   Data    => encode_utf8($body),
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




=head2 decode_rfc1522

    decode_rfc1522('=?iso-8859-1?Q?D=F6n_Armstr=F3ng?= <don@donarmstrong.com>')

Turn RFC-1522 names into the UTF-8 equivalent.

=cut

sub decode_rfc1522 {
    my ($string) = @_;

    # this is craptacular, but leading space is hacked off by unmime.
    # Save it.
    my $leading_space = '';
    $leading_space = $1 if $string =~ s/^(\ +)//;
    # we must do this to switch off the utf8 flag before calling decode_mimewords
    $string = encode_utf8($string);
    my @mime_words = MIME::Words::decode_mimewords($string);
    my $tmp = $leading_space .
        join('',
             (map {
                 if (@{$_} > 1) {
                     convert_to_utf8(${$_}[0],${$_}[1]);
                 } else {
                     decode_utf8(${$_}[0]);
                 }
             } @mime_words)
            );
    return $tmp;
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

     # convert to octets if we are given a string in perl's internal
     # encoding
     $rawstr= encode_utf8($rawstr) if is_utf8($rawstr);
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
