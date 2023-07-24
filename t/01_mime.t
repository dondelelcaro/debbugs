# -*- mode: cperl;-*-
# $Id: 01_mime.t,v 1.1 2005/08/17 21:46:17 don Exp $

use Test::More tests => 7;

use warnings;
use strict;

use Encode;

use_ok('Debbugs::MIME');

# encode_headers testing

my $test_str = decode_utf8(<<'END');
Döñ Ärḿßtrøñĝ <don@donarmstrong.com>
END

my $test_str2 = decode_utf8(<<'END');
 Döñ Ärḿßtrøñĝ <don@donarmstrong.com>
END

my $test_str3 =decode_utf8(<<'END');
foo@bar.com (J fö"ø)
END

# 1: test decode
ok(Debbugs::MIME::decode_rfc1522(q(=?iso-8859-1?Q?D=F6n_Armstr=F3ng?= <don@donarmstrong.com>)) eq
  decode_utf8(q(Dön Armstróng <don@donarmstrong.com>)),"decode_rfc1522 decodes and converts to UTF8 properly");


# 2: test encode
ok(Debbugs::MIME::decode_rfc1522(Debbugs::MIME::encode_rfc1522(encode_utf8($test_str))) eq $test_str,
  "encode_rfc1522 encodes strings that decode_rfc1522 can decode");
ok(Debbugs::MIME::decode_rfc1522(Debbugs::MIME::encode_rfc1522(encode_utf8($test_str2))) eq $test_str2,
  "encode_rfc1522 encodes strings that decode_rfc1522 can decode");
ok(Debbugs::MIME::decode_rfc1522(Debbugs::MIME::encode_rfc1522(encode_utf8($test_str3))) eq $test_str3,
  "encode_rfc1522 properly handles parenthesis and \"");
ok(Debbugs::MIME::handle_escaped_commas(q(),q(From: =?UTF-8?Q?Armstrong=2C?= Don <don@donarmstrong.com>)) eq q("Armstrong, Don" <don@donarmstrong.com>),
  "handle_escaped_commas properly handles commas in RFC1522 encoded strings");

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
