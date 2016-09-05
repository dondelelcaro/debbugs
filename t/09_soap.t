# -*- mode: cperl;-*-


use Test::More tests => 4;

use warnings;
use strict;

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


# test the soap server

my $port = 11343;

# We'd like to use soap.cgi here instead of testing the module
# directly, but I can't quite get it to work with
# HTTP::Server::Simple.
use_ok('Debbugs::SOAP');
use_ok('Debbugs::SOAP::Server');

our $child_pid = undef;

END{
     if (defined $child_pid) {
	  my $temp_exit = $?;
	  kill(15,$child_pid);
	  waitpid(-1,0);
	  $? = $temp_exit;
     }
}

my $pid = fork;
die "Unable to fork child" if not defined $pid;
if ($pid) {
     $child_pid = $pid;
     # Wait for two seconds to let the child start
     sleep 2;
}
else {
     # UGH.
     eval q(
     use Debbugs::SOAP::Server;
     @Debbugs::SOAP::Server::ISA = qw(SOAP::Transport::HTTP::Daemon);
     our $warnings = '';
     eval {
       # Ignore stupid warning because elements (hashes) can't start with
       # numbers
       local $SIG{__WARN__} = sub {$warnings .= $_[0] unless $_[0] =~ /Cannot encode unnamed element/};
       Debbugs::SOAP::Server
	       ->new(LocalAddr => 'localhost', LocalPort => $port)
		    ->dispatch_to('/','Debbugs::SOAP')
			 ->handle;
      };
      die $@ if $@;
      warn $warnings if length $warnings;

     );
}

use SOAP::Lite;
my $soap = SOAP::Lite->uri('Debbugs/SOAP')->proxy('http://localhost:'.$port.'/');
#ok($soap->get_soap_version->result == 1,'Version set and got correctly');
my $bugs_result = $soap->get_bugs(package => 'foo');
my $bugs = $bugs_result->result;
use Data::Dumper;
#print STDERR Dumper($bugs_result);
ok(@{$bugs} == 1 && $bugs->[0] == 1, 'get_bugs returns bug number 1') or fail(Dumper($bugs));
my $status_result = $soap->get_status(1);
#print STDERR Dumper($status_result);
my $status = $status_result->result;
ok($status->{1}{package} eq 'foo','get_status thinks that bug 1 belongs in foo') or fail(Dumper($status));

# Test the usertags at some point
