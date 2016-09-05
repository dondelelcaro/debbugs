# -*- mode: cperl;-*-


use Test::More tests => 3;

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

my %config = create_debbugs_configuration();


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
my $pkgreport_cgi_handler = sub {
     # I do not understand why this is necessary.
     $ENV{DEBBUGS_CONFIG_FILE} = "$config{config_dir}/debbugs_config";
     # We cd here because pkgreport uses require ./common.pl
     my $content = qx(cd cgi; perl -I.. -T pkgreport.cgi);
     # Strip off the Content-Type: stuff
     $content =~ s/^\s*Content-Type:[^\n]+\n*//si;
     print $content;
};

my $port = 11342;

ok(DebbugsTest::HTTPServer::fork_and_create_webserver($pkgreport_cgi_handler,$port),
   'forked HTTP::Server::Simple successfully');


my $mech = Test::WWW::Mechanize->new(autocheck => 1);

$mech->get_ok('http://localhost:'.$port.'/?pkg=foo');

# I'd like to use $mech->title_ok(), but I'm not sure why it doesn't
# work.
ok($mech->content()=~ qr/package foo/i,
   'Package title seems ok',
  );

# Test more stuff here
