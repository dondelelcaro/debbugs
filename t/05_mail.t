# -*- mode: cperl;-*-
# $Id: 05_mail.t,v 1.1 2005/08/17 21:46:17 don Exp $

use Test::More tests => 2;

use warnings;
use strict;

use utf8;

use UNIVERSAL;

use Debbugs::MIME qw(decode_rfc1522);
use Encode qw(encode_utf8);

use_ok('Debbugs::Mail');

# encode_headers testing

my $test_str = <<'END';
To: Döñ Ärḿßtrøñĝ <don@donarmstrong.com>
Subject: testing

blah blah blah
END

# 1: test decode
ok(decode_rfc1522(Debbugs::Mail::encode_headers($test_str)) eq encode_utf8($test_str));

# XXX Figure out a good way to test the send message bit of
# Debbugs::Mail
