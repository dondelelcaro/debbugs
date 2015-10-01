# -*- mode: cperl;-*-


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
use Test::WWW::Mechanize;
# The test functions are placed here to make things easier
use lib qw(t/lib);
use DebbugsTest qw(:all);

my %config;
eval {
     %config = create_debbugs_configuration(debug => exists $ENV{DEBUG}?$ENV{DEBUG}:0);
};
if ($@) {
     BAIL_OUT($@);
}

# Output some debugging information if there's an error
END{
     if ($ENV{DEBUG}) {
	  foreach my $key (keys %config) {
	       diag("$key: $config{$key}\n");
	  }
     }
}

# create a bug
send_message(to=>'submit@bugs.something',
	     headers => [To   => 'submit@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => 'Submitting a bug',
			],
	     body => <<EOF) or fail('Unable to send message');
Package: foo
Severity: normal

This is a silly bug
EOF


# test bugreport.cgi

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

$mech->get_ok('http://localhost:'.$port.'/?bug=1',
	      'Page received ok');
ok($mech->content() =~ qr/\<title\>\#1.+Submitting a bug/i,
   'Title of bug is submitting a bug');

$mech->get_ok('http://localhost:'.$port.'/?bug=1;mbox=yes',
              'Page received ok');
ok($mech->content() =~ qr/Subject: Submitting a bug/i,
   'Subject of bug maibox is right');
ok($mech->content() =~ qr/^From /m,
   'Starts with a From appropriately');

$mech->get_ok('http://localhost:'.$port.'/?bug=1;mboxmaint=yes',
              'Page received ok');
print STDERR $mech->content();
ok($mech->content() !~ qr/[\x01\x02\x03\x05\x06\x07]/i,
   'No unescaped states');



# Other tests for bugs in the page should be added here eventually

