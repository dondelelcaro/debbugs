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
use Unicode::MapUTF8 qw(to_utf8 utf8_supported_charset);

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
     $charset =~ s/^(UTF)\-(\d+)/$1$2/i;
     # XXX HACK UNTIL #320406 IS FIXED
     return $data if $charset =~ /BIG5/i;
     return $data unless utf8_supported_charset($charset);
     return to_utf8({
		     -string  => $data,
		     -charset => $charset,
		    });
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
    my ($string) = @_;

    return MIME::Words::encode_mimewords($string, Charset => 'UTF-8');
}

1;
