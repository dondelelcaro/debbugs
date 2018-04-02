# -*- mode: cperl;-*-

use Test::More;

use warnings;
use strict;

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


# create 4 bugs
for (1..4) {
    send_message(to=>'submit@bugs.something',
		 headers => [To   => 'submit@bugs.something',
			     From => 'foo@bugs.something',
			     Subject => 'Submitting a bug '.$_,
			    ],
		 run_processall => 0,
		 body => <<EOF) or fail('Unable to send message');
Package: foo
Severity: normal

This is a silly bug $_
EOF

}
send_message(to => 'control@bugs.something',
	     headers => [To   => 'control@bugs.something',
			 From => 'foo@bugs.something',
			 Subject => "Munging bugs with blocks",
			],
	     body => <<'EOF') or fail 'message to control@bugs.something failed';
block 1 by 2
block 3 by 1
block 4 by 1
thanks
EOF


## create the database
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
   'Submitting a bug 1',
   "Correct bug title");
$tests_run++;

my @blocking_bugs =
    map {$_->{blocks}}
    $s->resultset('Bug')->search({id => 1})->single->
    bug_blocks_bugs(undef,
		   {columns => [qw(blocks)],
		    result_class=>'DBIx::Class::ResultClass::HashRefInflator',
		   })->all;
$tests_run++;
is_deeply([sort @blocking_bugs],
	  [3,4],"Blocking bugs of 1 inserted correctly");

done_testing($tests_run);
