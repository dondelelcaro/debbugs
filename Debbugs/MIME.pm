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

sub encode_rfc1522 ($)
{
#    my ($string) = @_;
#
#    return MIME::Words::encode_mimewords($string, Charset => 'UTF-8');

# This function was stolen brazenly from a patched version of
# MIME::Words (fix for http://rt.cpan.org/NoAuth/Bug.html?id=13027)
#
# The patch has been modified slightly to only encode things that
# should be encoded, and not eat up every single character.

    my ($rawstr) = @_;
    my $charset  = 'UTF-8';
    my $encoding = 'q';

    my $NONPRINT = "\\x00-\\x1F\\x7F-\\xFF"; 

    my $result = "";
    my $current = $rawstr;

    while ($current ne "") {
      if ($current =~ s/^(([^$NONPRINT]|\s)+)//) {
	# safe chars (w/spaces) are handled as-is
	$result .= $1;
	next;
      } elsif ($current =~ s/^(([$NONPRINT]|\s)+)//) {
	# unsafe chars (w/spaces) are encoded
	my $unsafe_chars = $1;
      CHUNK75:
	while ($unsafe_chars ne "") {

	  my $full_len = length($unsafe_chars);
	  my $len = 1;
	  my $prev_encoded = "";

	  while ($len <= $full_len) {
	    # we try to encode next beginning of unsafe string
	    my $possible = substr $unsafe_chars, 0, $len;
	    my $encoded = MIME::Words::encode_mimeword($possible, $encoding, $charset);

	    if (length($encoded) < 75) {
	      # if it could be encoded in specified maximum length, try
	      # bigger beginning...
	      $prev_encoded = $encoded;
	    } else {
	      #
	      # ...otherwise, add encoded chunk which still fits, and
	      # restart with rest of unsafe string
	      $result .= $prev_encoded;
	      $prev_encoded = "";
	      substr $unsafe_chars, 0, $len - 1, "";
	      next CHUNK75;
	    }

	    # if we have reached the end of the string, add final
	    # encoded chunk
	    if ($len == $full_len) {
	      $result .= $encoded;
	      last CHUNK75;
	    }

	    $len++;
	  }
	}
      }
    }
    return $result;
}

1;
