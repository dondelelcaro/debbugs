package Debbugs::MIME;

use strict;

use File::Path;
use MIME::Parser;
use Exporter ();
use vars qw($VERSION @ISA @EXPORT_OK);

BEGIN {
    $VERSION = 1.00;

    @ISA = qw(Exporter);
    @EXPORT_OK = qw(parse);
}

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

1;
