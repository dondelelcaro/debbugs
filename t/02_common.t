# -*- mode: cperl;-*-

use Test::More tests => 3;
use Encode qw(decode_utf8);

use_ok('Debbugs::Common');
use_ok('Debbugs::UTF8');
is_deeply(Debbugs::UTF8::encode_utf8_structure(
          {a => decode_utf8('föö'),
	   b => [map {decode_utf8($_)} qw(blëh bl♥h)],
	  }),
	  {a => 'föö',
	   b => [qw(blëh bl♥h)],
	  },
	 );
