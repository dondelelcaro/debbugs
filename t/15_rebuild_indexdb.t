# -*- mode: cperl;-*-

use Test::More tests => 9;

use warnings;
use strict;

use utf8;

# Here, we're going to shoot messages through a set of things that can
# happen.

# First, we're going to send mesages to receive.
# To do so, we'll first send a message to submit,
# then send messages to the newly created bugnumber.

use IO::File;
use File::Temp qw(tempdir);
use Cwd qw(getcwd);
use Debbugs::MIME qw(create_mime_message);
use File::Basename qw(dirname basename);
# The test functions are placed here to make things easier
use lib qw(t/lib);
use DebbugsTest qw(:all);
use Data::Dumper;
use Encode qw(decode encode decode_utf8 encode_utf8);

# HTTP::Server:::Simple defines a SIG{CHLD} handler that breaks system; undef it here.
$SIG{CHLD} = sub {};
my %config = create_debbugs_configuration();


my $sendmail_dir = $config{sendmail_dir};
my $spool_dir = $config{spool_dir};
my $config_dir = $config{config_dir};



# We're going to use create mime message to create these messages, and
# then just send them to receive.

send_message(to=>'submit@bugs.something',
	     headers => [To   => 'submit@bugs.something',
			 From => 'föoﬀ@bugs.something',
			 Subject => 'Submiting a bug',
			],
	     body => <<EOF,attachments => [{Type=>"text/plain",Charset=>"utf-8",Data=>encode_utf8(<<EOF2)}]) or fail('Unable to send message');
Package: foo
Severity: normal

This is a silly bug
EOF
This is the silly bug's test ütﬀ8 attachment.
EOF2



# now we check to see that we have a bug, and nextnumber has been incremented
ok(-e "$spool_dir/db-h/01/1.log",'log file created');
ok(-e "$spool_dir/db-h/01/1.summary",'sumary file created');
ok(-e "$spool_dir/db-h/01/1.status",'status file created');
ok(-e "$spool_dir/db-h/01/1.report",'report file created');
ok(system('sh','-c','[ $(grep "attachment." '.$spool_dir.'/db-h/01/1.log|grep -v "ütﬀ8"|wc -l) -eq 0 ]') == 0,
   'Everything attachment is escaped properly');

# next, we check to see that (at least) the proper messages have been
# sent out. 1) ack to submitter 2) mail to maintainer

# This keeps track of the previous size of the sendmail directory
my $SD_SIZE = 0;
$SD_SIZE =
    num_messages_sent($SD_SIZE,2,
		      $sendmail_dir,
		      'submit messages appear to have been sent out properly',
		     );


# now send a message to the bug

send_message(to => '1@bugs.something',
	     headers => [To   => '1@bugs.something',
			 From => 'föoﬀ@bugs.something',
			 Subject => 'Sending a message to a bug',
			],
	     body => <<EOF) or fail('sending message to 1@bugs.someting failed');
Package: foo
Severity: normal

This is a silly bug
EOF

$SD_SIZE =
    num_messages_sent($SD_SIZE,2,
		      $sendmail_dir,
		      '1@bugs.something messages appear to have been sent out properly');

# just check to see that control doesn't explode
send_message(to => 'control@bugs.something',
	     headers => [To   => 'control@bugs.something',
			 From => 'föoﬀ@bugs.something',
			 Subject => 'Munging a bug',
			],
	     body => <<EOF) or fail 'message to control@bugs.something failed';
severity 1 wishlist
retitle 1 ütﬀ8 title encoding test
thanks
EOF

$SD_SIZE =
   num_messages_sent($SD_SIZE,1,
		     $sendmail_dir,
		     'control@bugs.something messages appear to have been sent out properly');
# now we need to check to make sure the control message was processed without errors
# now we need to check to make sure that the control message actually did anything
# This is an eval because $ENV{DEBBUGS_CONFIG_FILE} isn't set at BEGIN{} time
eval "use Debbugs::Status qw(read_bug writebug);";
ok(system('bin/debbugs-rebuild-index.db')==0,'debbugs-rebuild-index seems to work');
