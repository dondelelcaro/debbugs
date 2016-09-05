# -*- mode: cperl;-*-

use Test::More;

use warnings;
use strict;

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
	     body => <<EOF) or fail('Unable to send message');
Package: foo
Severity: normal

This is a silly bug
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


# set the summary to "This is the summary of the silly bug"

send_message(to => 'control@bugs.something',
	     headers => [To   => 'control@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => 'Munging a bug',
			],
	     body => <<EOF) or fail('sending message to 1@bugs.someting failed');
summary 1 0
thanks

This is the summary of the silly bug

This is not the summary of the silly bug
EOF

# now we need to check to make sure that the control message actually did anything
# This is an eval because $ENV{DEBBUGS_CONFIG_FILE} isn't set at BEGIN{} time
eval "use Debbugs::Status qw(read_bug writebug);";
my $status = read_bug(bug=>1);
is($status->{summary},"This is the summary of the silly bug",'bug 1 has right summary');

send_message(to => '1@bugs.something',
	     headers => [To   => '1@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => 'Munging a bug',
			],
	     body => <<EOF) or fail('sending message to 1@bugs.someting failed');
Control: summary -1 0

This is a new summary.

This is not the summary of the silly bug
EOF

$status = read_bug(bug=>1);
is($status->{summary},"This is a new summary.",'Control: summary setting works');


done_testing();
