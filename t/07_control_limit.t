# -*- mode: cperl; -*-

use Test::More tests => 8;

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

my $SD_SIZE = dirsize($sendmail_dir);
send_message(to => 'control@bugs.something',
	     headers => [To   => 'control@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => "Munging a bug with limit_package_bar",
			],
	     body => <<EOF) or fail 'message to control@bugs.something failed';
debug 10
limit package bar
severity 1 wishlist
thanks
EOF

$SD_SIZE =
    num_messages_sent($SD_SIZE,1,
			   $sendmail_dir,
		      'control@bugs.something messages appear to have been sent out properly');

# make sure this fails
ok(system('sh','-c','find '.$sendmail_dir.q( -type f | xargs grep -q "Subject: Processed (with 1 error): Munging a bug with limit_package_bar")) == 0,
   'control@bugs.something'. "limit message failed with 1 error");

send_message(to => 'control@bugs.something',
	     headers => [To   => 'control@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => "Munging a bug with limit_package_foo",
			],
	     body => <<EOF) or fail 'message to control@bugs.something failed';
debug 10
limit package foo
severity 1 wishlist
thanks
EOF

$SD_SIZE =
    num_messages_sent($SD_SIZE,1,
			   $sendmail_dir,
		      'control@bugs.something messages appear to have been sent out properly');

# make sure this fails
ok(system('sh','-c','find '.$sendmail_dir.q( -type f | xargs grep -q "Subject: Processed: Munging a bug with limit_package_foo")) == 0,
   'control@bugs.something'. "limit message succeeded with no errors");

send_message(to=>'submit@bugs.something',
	     headers => [To   => 'submit@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => 'Submiting a bug',
			],
	     body => <<EOF) or fail('Unable to send message');
Package: foo, bar
Severity: normal

This is a silly bug
EOF
$SD_SIZE = dirsize($sendmail_dir);


send_message(to => 'control@bugs.something',
	     headers => [To   => 'control@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => "Munging a bug with limit_package_bar",
			],
	     body => <<EOF) or fail 'message to control@bugs.something failed';
debug 10
limit package baz
severity 2 wishlist
thanks
EOF

$SD_SIZE =
    num_messages_sent($SD_SIZE,1,
			   $sendmail_dir,
		      'control@bugs.something messages appear to have been sent out properly');

# make sure this fails
ok(system('sh','-c','find '.$sendmail_dir.q( -type f | xargs grep -q "Subject: Processed (with 1 error): Munging a bug with limit_package_bar")) == 0,
   'control@bugs.something'. "limit message failed with 1 error");

send_message(to => 'control@bugs.something',
	     headers => [To   => 'control@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => "Munging a bug with limit_package_foo",
			],
	     body => <<EOF) or fail 'message to control@bugs.something failed';
debug 10
limit package foo
severity 2 wishlist
thanks
EOF

$SD_SIZE =
    num_messages_sent($SD_SIZE,1,
			   $sendmail_dir,
		      'control@bugs.something messages appear to have been sent out properly');

# make sure this fails
ok(system('sh','-c','find '.$sendmail_dir.q( -type f | xargs grep -q "Subject: Processed: Munging a bug with limit_package_foo")) == 0,
   'control@bugs.something'. "limit message succeeded with no errors");
