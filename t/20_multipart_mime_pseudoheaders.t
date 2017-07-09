# -*- mode: cperl;-*-

use Test::More;

use warnings;
use strict;
use utf8;

# The test functions are placed here to make things easier
use lib qw(t/lib);
use DebbugsTest qw(:all);
use Data::Dumper;

my %config =
    create_debbugs_configuration();

my $sendmail_dir = $config{sendmail_dir};
my $spool_dir = $config{spool_dir};

# We're going to use create mime message to create these messages, and
# then just send them to receive.

send_message(to=>'submit@bugs.something',
	     headers => [To   => 'submit@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => 'Submiting a bug',
			],
	     body => <<EOF,
Package: foo
Severity: normal

This is a silly bug
EOF
	     attachments => [<<EOF]) or fail('Unable to send message');
This is a silly attachment to make sure that pseudoheaders work
EOF
# now we check to see that we have a bug, and nextnumber has been incremented
ok(-e "$spool_dir/db-h/01/1.log",'log file created');
ok(-e "$spool_dir/db-h/01/1.summary",'sumary file created');
ok(-e "$spool_dir/db-h/01/1.status",'status file created');
ok(-e "$spool_dir/db-h/01/1.report",'report file created');

# next, we check to see that (at least) the proper messages have been
# sent out. 1) ack to submitter 2) mail to maintainer

# This keeps track of the previous size of the sendmail directory
my $SD_SIZE = 0;
$SD_SIZE =
    num_messages_sent($SD_SIZE,2,
		      $sendmail_dir,
		      'submit messages appear to have been sent out properly',
		     );

send_message(to=>'1-done@bugs.something',
	     headers => [To   => '1-done@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => 'Closing a bug with pseudoheaders',
			],
	     body => <<EOF,
Source: foo
Version: 1


I've closed this silly bug; using an UTF-8 non-breaking space to test that
https://bugs.debian.org/817128 was fixed too.
EOF
	     attachments => [<<EOF,
This is one silly attachment to make sure that pseudoheaders work
EOF
			     <<EOF]) or fail('Unable to send message');
And this is another, just in case.
EOF

# now we need to check to make sure that the control message actually did anything
# This is an eval because $ENV{DEBBUGS_CONFIG_FILE} isn't set at BEGIN{} time
eval "use Debbugs::Status qw(read_bug writebug);";
my $status = read_bug(bug=>1);
is($status->{done},'foo@bugs.something','bug 1 was closed properly');
is_deeply($status->{fixed_versions},["1"],'bug 1 was fixed in the proper version');

done_testing();
