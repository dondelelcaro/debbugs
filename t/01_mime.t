# -*- mode: cperl;-*-
# $Id: 01_mime.t,v 1.1 2005/08/17 21:46:17 don Exp $

use Test::More tests => 4;

use warnings;
use strict;

use utf8;
use Encode;

use_ok('Debbugs::MIME');

# encode_headers testing

my $test_str = <<'END';
Döñ Ärḿßtrøñĝ <don@donarmstrong.com>
END


# 1: test decode
ok(Debbugs::MIME::decode_rfc1522(q(=?iso-8859-1?Q?D=F6n_Armstr=F3ng?= <don@donarmstrong.com>)) eq
  encode_utf8(q(Dön Armstróng <don@donarmstrong.com>)),"decode_rfc1522 decodes and converts to UTF8 properly");


# 2: test encode
ok(Debbugs::MIME::decode_rfc1522(Debbugs::MIME::encode_rfc1522($test_str)) eq $test_str,
  "encode_rfc1522 encodes strings that decode_rfc1522 can decode");

# Make sure that create_mime_message has encoded headers and doesn't enclude any 8-bit characters

$test_str = Encode::encode("UTF-8",$test_str);
ok(Debbugs::MIME::create_mime_message([Subject => $test_str,
				       From    => $test_str,
				      ],
				      $test_str,
				      [],
				     ) !~ m{([\xF0-\xFF]+)},
   "create_mime_message properly encodes 8bit messages."
  );

# XXX figure out how to test parse
