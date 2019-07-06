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

# This must happen before anything is used, otherwise Debbugs::Config will be
# set to wrong values.
my %config = create_debbugs_configuration();

my $tests = 0;
use_ok('Debbugs::Bug');
$tests++;
use_ok('Debbugs::Collection::Bug');
$tests++;

# create 4 bugs
for (1..4) {
    submit_bug(subject => 'Submitting a bug '.$_,
	       pseudoheaders => {Severity => 'normal',
				 Tags => 'wontfix moreinfo',
				},
	      );
}
run_processall();

my $bc = Debbugs::Collection::Bug->new(bugs => [1..4]);

my $bug;
ok($bug = $bc->get(1),
   "Created a bug correctly"
  );
$tests++;

ok(!$bug->archiveable,
   "Newly created bugs are not archiveable"
  );
$tests++;

is($bug->submitter->email,'foo@bugs.something',
   "Submitter works"
  );
$tests++;

ok($bug->tags->tag_is_set('wontfix'),
   "Wontfix tag set"
  );
$tests++;

is($bug->tags->as_string(),
   'moreinfo wontfix',
   "as_string works"
  );
$tests++;

### run some tests with the database creation

## create the database
my $pgsql = create_postgresql_database();
update_postgresql_database($pgsql);

use_ok('Debbugs::DB');
$tests++;
my $s;
ok($s = Debbugs::DB->connect($pgsql->dsn),
   "Able to connect to database");
$tests++;

$bc = Debbugs::Collection::Bug->new(bugs => [1..4],
                                 schema => $s);
ok($bug = $bc->get(1),
   "Created a bug correctly with DB"
  );
$tests++;

done_testing($tests);

