# -*- mode: cperl;-*-

use Test::More tests => 35;

use warnings;
use strict;

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


# now send a message to the bug

send_message(to => '1@bugs.something',
	     headers => [To   => '1@bugs.something',
			 From => 'foo@bugs.something',
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
			 From => 'foo@bugs.something',
			 Subject => 'Munging a bug',
			],
	     body => <<EOF) or fail 'message to control@bugs.something failed';
severity 1 wishlist
retitle 1 new title
thanks
EOF

$SD_SIZE =
   num_messages_sent($SD_SIZE,1,
		     $sendmail_dir,
		     'control@bugs.something messages appear to have been sent out properly');
# now we need to check to make sure the control message was processed without errors
ok(system('sh','-c','find '.$sendmail_dir.q( -type f | xargs grep -q "Subject: Processed: Munging a bug")) == 0,
   'control@bugs.something message was parsed without errors');
# now we need to check to make sure that the control message actually did anything
# This is an eval because $ENV{DEBBUGS_CONFIG_FILE} isn't set at BEGIN{} time
eval "use Debbugs::Status qw(read_bug writebug);";
my $status = read_bug(bug=>1);
ok($status->{subject} eq 'new title','bug 1 retitled');
ok($status->{severity} eq 'wishlist','bug 1 wishlisted');

# now we're going to go through and methododically test all of the control commands.
my @control_commands =
     (
      clone        => {command => 'clone',
		       value   => '1 -1',
		       status_key => 'package',
		       status_value => 'foo',
		       bug          => '2',
		      },
      merge        => {command => 'merge',
		       value   => '1 2',
		       status_key => 'mergedwith',
		       status_value => '2',
		      },
      unmerge      => {command => 'unmerge',
		       value   => '1',
		       status_key => 'mergedwith',
		       status_value => '',
		      },
     );

test_control_commands(@control_commands);

send_message(to => 'control@bugs.something',
	     headers => [To   => 'control@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => "Munging a bug with lots of stuff",
			],
	     body => <<'EOF') or fail 'message to control@bugs.something failed';
debug 10
clone 2 -1 -2 -3 -4 -5 -6
retitle 2 foo
owner 2 bar@baz.com
submitter 2 fleb@bleh.com
tag 2 unreproducible moreinfo
severity 2 grave
block -1 by 2
block 2 by -2
summary 2 4
affects 2 bleargh
forwarded 2 http://example.com/2
close 2
tag -3 wontfix
fixed -4 1.2-3
found -4 1.2-1
found -5 1.2-5
fixed -5 1.2-6
thanks
EOF
	;
	$SD_SIZE =
	    num_messages_sent($SD_SIZE,1,
			      $sendmail_dir,
			      'control@bugs.something messages appear to have been sent out properly');


test_control_commands(forcemerge   => {command => 'forcemerge',
				       value   => '1 2',
				       status_key => 'mergedwith',
				       status_value => '2',
				      },
		      unmerge      => {command => 'unmerge',
				       value   => '1',
				       status_key => 'mergedwith',
				       status_value => '',
				      },
		      forcemerge   => {command => 'forcemerge',
				       value   => '1 2 5',
				       status_key => 'mergedwith',
				       status_value => '2 5',
				      },
		      forcemerge   => {command => 'forcemerge',
				       value   => '1 2 6',
				       status_key => 'mergedwith',
				       status_value => '2 5 6',
				      },
		      merge        => {command => 'merge',
				       value   => '7 8',
				       status_key => 'mergedwith',
				       status_value => '8',
				       bug => '7',
				      },
		     );


sub test_control_commands{
    my @commands = @_;

    while (my ($command,$control_command) = splice(@commands,0,2)) {
	# just check to see that control doesn't explode
	$control_command->{value} = " $control_command->{value}" if length $control_command->{value}
	    and $control_command->{value} !~ /^\s/;
	send_message(to => 'control@bugs.something',
		     headers => [To   => 'control@bugs.something',
				 From => 'foo@bugs.something',
				 Subject => "Munging a bug with $command",
				],
		     body => <<EOF) or fail 'message to control@bugs.something failed';
debug 10
$control_command->{command} $control_command->{value}
thanks
EOF
	;
	$SD_SIZE =
	    num_messages_sent($SD_SIZE,1,
			      $sendmail_dir,
			      'control@bugs.something messages appear to have been sent out properly');
	# now we need to check to make sure the control message was processed without errors
	ok(system('sh','-c','find '.$sendmail_dir.q( -type f | xargs grep -q "Subject: Processed: Munging a bug with $command")) == 0,
	   'control@bugs.something'. "$command message was parsed without errors");
	# now we need to check to make sure that the control message actually did anything
	my $status;
	$status = read_bug(exists $control_command->{bug}?(bug => $control_command->{bug}):(bug=>1),
			   exists $control_command->{location}?(location => $control_command->{location}):(),
			  );
	is_deeply($status->{$control_command->{status_key}},
		  $control_command->{status_value},
		  "bug " .
		  (exists $control_command->{bug}?$control_command->{bug}:1).
		  " $command"
		 )
	    or fail(Dumper($status));
    }
}
