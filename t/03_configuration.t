# -*- mode: cperl;-*-

use Test::More tests => 6;

use warnings;
use strict;

BEGIN{use_ok('Debbugs::Config',qw(:globals %config));}
ok($config{sendmail} eq '/usr/lib/sendmail', 'sendmail configuration set sanely');
ok($config{spam_scan} == 0, 'spam_scan set to 0 by default');
ok($gSendmail eq '/usr/lib/sendmail','sendmail global works');
ok($gSpamScan == 0 , 'spam_scan global works');
ok(defined $gStrongList,'strong_list global works');
