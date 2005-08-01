package Debbugs::MIME;

use strict;

use base qw(Exporter);
use vars qw($VERSION @EXPORT_OK);

BEGIN {
    $VERSION = 1.00;

    @EXPORT_OK = qw(parse decode_rfc1522 encode_rfc1522 convert_to_utf8);
}

use File::Path;
use MIME::Parser;

# for decode_rfc1522
use MIME::WordDecoder qw();
use Encode qw(decode encode is_utf8);

# for encode_rfc1522
use MIME::Words qw();

sub getmailbody ($);
sub getmailbody ($)
{
    my $entity = shift;
    my $type = $entity->effective_type;
    if ($type eq 'text/plain' or
	    ($type =~ m#text/# and $type ne 'text/html') or
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

sub parse ($)
{
    # header and decoded body respectively
    my (@headerlines, @bodylines);

    my $parser = new MIME::Parser;
    mkdir "mime.tmp.$$", 0777;
    $parser->output_under("mime.tmp.$$");
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

    rmtree "mime.tmp.$$", 0, 1;

    # Remove blank lines.
    shift @bodylines while @bodylines and $bodylines[0] !~ /\S/;

    # Strip off RFC2440-style PGP clearsigning.
    if (@bodylines and $bodylines[0] =~ /^-----BEGIN PGP SIGNED/) {
	shift @bodylines while @bodylines and length $bodylines[0];
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

# Bug #61342 et al.

sub convert_to_utf8 {
     my ($data, $charset) = @_;
     # raw data just gets returned (that's the charset WordDecorder
     # uses when it doesn't know what to do)
     return $data if $charset eq 'raw' or is_utf8($data,1);
     my $result;
     eval {
	  # this encode/decode madness is to make sure that the data
	  # really is valid utf8 and that the is_utf8 flag is off.
	  $result = encode("utf8",decode($charset,$data))
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

sub decode_rfc1522 ($)
{
    my ($string) = @_;

    # unmime calls the default MIME::WordDecoder handler set up at
    # initialization time.
    return MIME::WordDecoder::unmime($string);
}

=head2 encode_rfc1522

     encode_rfc1522('Dön Armströng <don@donarmstrong.com>')

Encodes headers according to the RFC1522 standard by calling
MIME::Words::encode_mimeword on distinct words as appropriate.

=cut

# We cannot use MIME::Words::encode_mimewords because that function
# does not handle spaces properly at all.

sub encode_rfc1522 ($) {
     my ($rawstr) = @_;

     # We process words in reverse so we can preserve spacing between
     # encoded words. This regex splits on word|nonword boundaries and
     # nonword|nonword boundaries.
     my @words = reverse split /(?:(?<=[\s\n])|(?=[\s\n]))/m, $rawstr;

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
		    my $tempstr = decode_utf8($word,Encode::FB_DEFAULT);
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
