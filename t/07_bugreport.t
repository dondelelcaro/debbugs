# -*- mode: cperl;-*-


use Test::More tests => 16;

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

# now test the output of some control commands
my @control_commands =
     (
      reassign_foo => {command => 'reassign',
		       value   => 'bar',
		       regex => qr{<strong>bug reassigned from package &#39;<a href="pkgreport\.cgi\?package=foo">foo</a>&#39; to &#39;<a href="pkgreport\.cgi\?package=bar">bar</a>},
		      },
      forwarded_foo      => {command => 'forwarded',
			     value   => 'https://foo.invalid/bugs?id=1',
			     regex   => qr{<strong>Set bug forwarded-to-address to &#39;<a href="https://foo\.invalid/bugs\?id=1">https://foo\.invalid/bugs\?id=1</a>&#39;\.},
			    },
      forwarded_foo_2    => {command => 'forwarded',
			     value   => 'https://foo.example/bugs?id=1',
			     regex   => qr{<strong>Changed bug forwarded-to-address to &#39;<a href="https://foo\.example/bugs\?id=1">https://foo\.example/bugs\?id=1</a>&#39; from &#39;<a href="https://foo\.invalid/bugs\?id=1">https://foo\.invalid/bugs\?id=1</a>&#39;\.},
			    },
      clone        => {command => 'clone',
		       value   => '-1',
		       regex   => qr{<strong>Bug <a href="bugreport.cgi\?bug=1">1</a> cloned as bug <a href="bugreport.cgi\?bug=2">2</a>},
		      },
     );

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
  # Now test that the output has changed accordingly
  $mech->get_ok('http://localhost:'.$port.'/?bug=1',
		'Page received ok');
  like($mech->content(), $control_command->{regex},
       'Page matches regex');
}

# Other tests for bugs in the page should be added here eventually

