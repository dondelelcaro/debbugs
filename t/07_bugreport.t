# -*- mode: cperl;-*-
# $Id: 05_mail.t,v 1.1 2005/08/17 21:46:17 don Exp $

use Test::More tests => 2;

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
use Data::Dumper;

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
			 Subject => 'Submiting a bug',
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
     print qx(perl -I. -T cgi/bugreport.cgi);
};

my $port = 11342;

ok(DebbugsTest::HTTPServer::fork_and_create_webserver($bugreport_cgi_handler,$port),
   'forked HTTP::Server::Simple successfully');


my $mech = Test::WWW::Mechanize->new();

$mech->get_ok('http://localhost:'.$port.'/?bug=1');
