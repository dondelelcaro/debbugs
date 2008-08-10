# -*- mode: cperl;-*-
# $Id: 05_mail.t,v 1.1 2005/08/17 21:46:17 don Exp $

use Test::More tests => 96;

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
my %config;
eval {
     %config = create_debbugs_configuration(debug => exists $ENV{DEBUG}?$ENV{DEBUG}:0);
};
if ($@) {
     BAIL_OUT($@);
}

my $sendmail_dir = $config{sendmail_dir};
my $spool_dir = $config{spool_dir};
my $config_dir = $config{config_dir};

END{
     if ($ENV{DEBUG}) {
	  diag("spool_dir:   $spool_dir\n");
	  diag("config_dir:   $config_dir\n");
	  diag("sendmail_dir: $sendmail_dir\n");
     }
}

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
my $SD_SIZE_PREV = 0;
my $SD_SIZE_NOW = dirsize($sendmail_dir);
ok($SD_SIZE_NOW-$SD_SIZE_PREV >= 2,'submit messages appear to have been sent out properly');
$SD_SIZE_PREV=$SD_SIZE_NOW;

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

$SD_SIZE_NOW = dirsize($sendmail_dir);
ok($SD_SIZE_NOW-$SD_SIZE_PREV >= 2,'1@bugs.something messages appear to have been sent out properly');
$SD_SIZE_PREV=$SD_SIZE_NOW;

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

$SD_SIZE_NOW = dirsize($sendmail_dir);
ok($SD_SIZE_NOW-$SD_SIZE_PREV >= 1,'control@bugs.something messages appear to have been sent out properly');
$SD_SIZE_PREV=$SD_SIZE_NOW;
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
     (severity_wishlist => {command => 'severity',
			    value   => 'wishlist',
			    status_key => 'severity',
			    status_value => 'wishlist',
			   },
      reassign_bar => {command => 'reassign',
		       value   => 'bar',
		       status_key => 'package',
		       status_value => 'bar',
		      },
      reassign_foo => {command => 'reassign',
		       value   => 'foo',
		       status_key => 'package',
		       status_value => 'foo',
		      },
      'found_1.0'        => {command => 'found',
			     value   => '1.0',
			     status_key => 'found_versions',
			     status_value => ['1.0'],
			    },
      'notfound_1.0'     => {command => 'notfound',
			     value   => '1.0',
			     status_key => 'found_versions',
			     status_value => [],
			    },
      'found_1.0~5+1b2'  => {command => 'found',
			     value   => '1.0~5+1b2',
			     status_key => 'found_versions',
			     status_value => ['1.0~5+1b2'],
			    },
      'notfound_1.0~5+1b2' => {command => 'notfound',
			       value   => '1.0~5+1b2',
			       status_key => 'found_versions',
			       status_value => [],
			      },
      'fixed_1.1'        => {command => 'fixed',
			     value   => '1.1',
			     status_key => 'fixed_versions',
			     status_value => ['1.1'],
			    },
      'notfixed_1.1'     => {command => 'notfixed',
			     value   => '1.1',
			     status_key => 'fixed_versions',
			     status_value => [],
			    },
      'found_1.0~5+1b2'  => {command => 'found',
			     value   => '1.0~5+1b2',
			     status_key => 'found_versions',
			     status_value => ['1.0~5+1b2'],
			    },
      'fixed_1.2'        => {command => 'fixed',
			     value   => '1.2',
			     status_key => 'fixed_versions',
			     status_value => ['1.2'],
			    },
      close              => {command => 'close',
			     value   => '',
			     status_key => 'done',
			     status_value => 'foo@bugs.something',
			    },
      'found_1.3'        => {command => 'found',
			     value   => '1.3',
			     status_key => 'done',
			     status_value => '',
			    },
      submitter_foo      => {command => 'submitter',
			     value   => 'foo@bar.com',
			     status_key => 'originator',
			     status_value => 'foo@bar.com',
			    },

      forwarded_foo      => {command => 'forwarded',
			     value   => 'foo@bar.com',
			     status_key => 'forwarded',
			     status_value => 'foo@bar.com',
			    },
      owner_foo          => {command => 'owner',
			     value   => 'foo@bar.com',
			     status_key => 'owner',
			     status_value => 'foo@bar.com',
			    },
      noowner      => {command => 'noowner',
		       value   => '',
		       status_key => 'owner',
		       status_value => '',
		      },
      clone        => {command => 'clone',
		       value   => '-1',
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
		       value   => '',
		       status_key => 'mergedwith',
		       status_value => '',
		      },
      forcemerge   => {command => 'forcemerge',
		       value   => '2',
		       status_key => 'mergedwith',
		       status_value => '2',
		      },
      summary      => {command => 'summary',
		       value   => '5',
		       status_key => 'summary',
		       status_value => 'This is a silly bug',
		      },
      nosummary    => {command => 'summary',
		       value   => '',
		       status_key => 'summary',
		       status_value => '',
		      },
      affects      => {command => 'affects',
		       value   => 'foo',
		       status_key => 'affects',
		       status_value => 'foo',
		      },
      noaffects    => {command => 'affects',
		       value   => '',
		       status_key => 'affects',
		       status_value => '',
		      },
      close        => {command => 'close',
		       value   => '',
		       status_key => 'done',
		       status_value => 'foo@bugs.something',
		      },
      archive      => {command => 'archive',
		       value   => '',
		       status_key => 'owner',
		       status_value => '',
		       location => 'archive',
		      },
      unarchive    => {command => 'unarchive',
		       value   => '',
		       status_key => 'owner',
		       status_value => '',
		      },
     );

# In order for the archive/unarchive to work, we have to munge the summary file slightly
$status = read_bug(bug => 1);
$status->{unarchived} = time;
writebug(1,$status);
while (my ($command,$control_command) = splice(@control_commands,0,2)) {
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
$control_command->{command} 1$control_command->{value}
thanks
EOF
				  ;
     $SD_SIZE_NOW = dirsize($sendmail_dir);
     ok($SD_SIZE_NOW-$SD_SIZE_PREV >= 1,'control@bugs.something messages appear to have been sent out properly');
     $SD_SIZE_PREV=$SD_SIZE_NOW;
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

# verify that archive/unarchive can then be modified afterwards

send_message(to => 'control@bugs.something',
	     headers => [To   => 'control@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => "Munging a bug with unarchivearchive",
			],
	     body => <<'EOF') or fail 'message to control@bugs.something failed';
debug 10
archive 1
unarchive 1
submitter 1 bar@baz.com
thanks
EOF
				  ;
$SD_SIZE_NOW = dirsize($sendmail_dir);
ok($SD_SIZE_NOW-$SD_SIZE_PREV >= 1,'control@bugs.something messages appear to have been sent out properly');
$SD_SIZE_PREV=$SD_SIZE_NOW;
# now we need to check to make sure the control message was processed without errors
ok(system('sh','-c','find '.$sendmail_dir.q( -type f | xargs grep -q "Subject: Processed: Munging a bug with unarchivearchive")) == 0,
   'control@bugs.something'. "unarchive/archive message was parsed without errors");
