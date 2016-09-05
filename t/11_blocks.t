# -*- mode: cperl;-*-

use Test::More tests => 20;

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
use Test::WWW::Mechanize;

# HTTP::Server:::Simple defines a SIG{CHLD} handler that breaks system; undef it here.
$SIG{CHLD} = sub {};
my %config = create_debbugs_configuration();


my $sendmail_dir = $config{sendmail_dir};
my $spool_dir = $config{spool_dir};
my $config_dir = $config{config_dir};



# We're going to use create mime message to create these messages, and
# then just send them to receive.

for my $bug (1..11) {
    send_message(to=>'submit@bugs.something',
		 headers => [To   => 'submit@bugs.something',
			     From => 'foo@bugs.something',
			     Subject => 'Submiting a bug '.$bug,
			    ],
		 body => <<EOF) or fail('Unable to send message');
Package: foo
Severity: normal

This is a silly bug $bug
EOF
}

# next, we check to see that (at least) the proper messages have been
# sent out. 1) ack to submitter 2) mail to maintainer

# This keeps track of the previous size of the sendmail directory
my $SD_SIZE = 0;
$SD_SIZE =
    num_messages_sent($SD_SIZE,10,
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
block 10 with 2
thanks
EOF

# now we need to check to make sure the control message was processed without errors
ok(system('sh','-c','find '.$sendmail_dir.q( -type f | xargs grep -q "Subject: Processed: Munging a bug")) == 0,
   'control@bugs.something message was parsed without errors');
eval "use Debbugs::Status qw(read_bug writebug);";
my $status = read_bug(bug=>10);
ok($status->{blockedby} eq '2','bug 10 is blocked by 2 (and only 2)');
$status = read_bug(bug=>2);
ok($status->{blocks} eq '10','bug 2 blocks 10 (and only 10)');

send_message(to => 'control@bugs.something',
	     headers => [To   => 'control@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => 'Munging a bug',
			],
	     body => <<EOF) or fail 'message to control@bugs.something failed';
merge 3 4
block 10 by 3
thanks
EOF
ok(system('sh','-c','find '.$sendmail_dir.q( -type f | xargs grep -q "Subject: Processed: Munging a bug")) == 0,
   'control@bugs.something message was parsed without errors');
$status = read_bug(bug=>10);
ok(is_deeply([sort split /\ /,$status->{blockedby}],[qw(2 3 4)]),'bug 10 is blocked by exactly 2, 3, and 4');
send_message(to => 'control@bugs.something',
	     headers => [To   => 'control@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => 'Munging a bug',
			],
	     body => <<EOF) or fail 'message to control@bugs.something failed';
unblock 10 with 2
thanks
EOF

ok(system('sh','-c','find '.$sendmail_dir.q( -type f | xargs grep -q "Subject: Processed: Munging a bug")) == 0,
   'control@bugs.something message was parsed without errors');

$status = read_bug(bug=>10);
ok(is_deeply([sort split /\ /,$status->{blockedby}],[qw(3 4)]),'bug 10 is blocked by exactly 3 and 4');
$status = read_bug(bug=>3);
ok($status->{blocks} eq '10','bug 3 blocks exactly 10');

send_message(to => 'control@bugs.something',
	     headers => [To   => 'control@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => 'Munging a bug',
			],
	     body => <<EOF) or fail 'message to control@bugs.something failed';
block 3 with 5
thanks
EOF
ok(system('sh','-c','find '.$sendmail_dir.q( -type f | xargs grep -q "Subject: Processed: Munging a bug")) == 0,
   'control@bugs.something message was parsed without errors');


$status = read_bug(bug=>3);
ok($status->{blockedby} eq '5','bug 3 is blocked by exactly 5');

# Check how this blocked bug is presented on the web interface

# start up an HTTP::Server::Simple
my $bugreport_cgi_handler = sub {
     # I do not understand why this is necessary.
     $ENV{DEBBUGS_CONFIG_FILE} = "$config{config_dir}/debbugs_config";
     my $content = qx(perl -I. -T cgi/bugreport.cgi);
     $content =~ s/^\s*Content-Type:[^\n]+\n*//si;
     print $content;
};

my $port = 11342;

ok(DebbugsTest::HTTPServer::fork_and_create_webserver($bugreport_cgi_handler,$port),
   'forked HTTP::Server::Simple successfully');

my $mech = Test::WWW::Mechanize->new();

$mech->get_ok('http://localhost:'.$port.'/?bug=10',
	      'Page received ok');

ok($mech->content() =~ qr//i,
   'Title of bug is \'Submitting a bug\'');

ok($mech->content() =~ qr/Added blocking bug\(s\) of <a[^>]+10[^>]+>10<\/a>: <a[^>]+2[^>]+>2<\/a>/i,
   '\'Added blocking bug(s) of x: y\' received markup');

$mech->get_ok('http://localhost:'.$port.'/?bug=2',
	      'Page received ok');

ok($mech->content() =~ qr/Added indication that bug <a[^>]+2[^>]+>2<\/a> blocks <a[^>]+10[^>]+>10<\/a>/i,
   '\'indication that bug x blocks y\' received markup');
