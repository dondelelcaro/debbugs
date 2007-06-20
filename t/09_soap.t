# -*- mode: cperl;-*-


use Test::More tests => 4;

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
use DebbugsTest qw(:configuration);
use Cwd;

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

my $port = 11342;

# We'd like to use soap.cgi here instead of testing the module
# directly, but I can't quite get it to work with
# HTTP::Server::Simple.
use_ok('Debbugs::SOAP');
use_ok('Debbugs::SOAP::Server');

our $child_pid = undef;

END{
     if (defined $child_pid) {
	  kill(15,$child_pid);
	  waitpid(-1,0);
     }
}

my $pid = fork;
die "Unable to fork child" if not defined $pid;
if ($pid) {
     $child_pid = $pid;
     # Wait for a second to let the child start
     sleep 1;
}
else {
     # UGH.
     eval q(
     use Debbugs::SOAP::Server;
     @Debbugs::SOAP::Server::ISA = qw(SOAP::Transport::HTTP::Daemon);
     Debbugs::SOAP::Server
	       ->new(LocalAddr => 'localhost', LocalPort => $port)
		    ->dispatch_to('/','Debbugs::SOAP')
			 ->handle;
     );
}

use SOAP::Lite;
my $soap = SOAP::Lite->uri('Debbugs/SOAP')->proxy('http://localhost:'.$port.'/');
#ok($soap->get_soap_version->result == 1,'Version set and got correctly');
my $bugs = $soap->get_bugs(package => 'foo')->result;
use Data::Dumper;
ok(@{$bugs} == 1 && $bugs->[0] == 1, 'get_bugs returns bug number 1') or fail(Dumper($bugs));
my $status = $soap->get_status(1)->result;
ok($status->{1}{package} eq 'foo','get_status thinks that bug 1 belongs in foo') or fail(Dumper($status));

# Test the usertags at some point
