# -*- mode: cperl;-*-

use Test::More;

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
use HTTP::Status qw(RC_NOT_MODIFIED);
# The test functions are placed here to make things easier
use lib qw(t/lib);
use DebbugsTest qw(:all);

our $tests_run = 0;

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

my $pgsql = create_postgresql_database();
update_postgresql_database($pgsql);

BEGIN{
    use_ok('Debbugs::DB')
}
$tests_run++;

my $s;

ok($s = Debbugs::DB->connect($pgsql->dsn),
   "Able to connect to database");
$tests_run++;

ok($s->resultset('Bug')->search({id => 1})->single->subject eq
   'Submitting a bug',
   "Correct bug title");
$tests_run++;

done_testing($tests_run);
