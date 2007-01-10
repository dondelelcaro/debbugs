# -*- mode: cperl;-*-
# $Id: 05_mail.t,v 1.1 2005/08/17 21:46:17 don Exp $

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


my $sendmail_dir = tempdir(CLEANUP => $ENV{DEBUG}?0:1);
my $spool_dir = tempdir(CLEANUP => $ENV{DEBUG}?0:1);
my $config_dir = tempdir(CLEANUP => $ENV{DEBUG}?0:1);

END{
     if ($ENV{DEBUG}) {
	  print STDERR "\nspool_dir:   $spool_dir\n";
	  print STDERR "config_dir:   $config_dir\n";
	  print STDERR "sendmail_dir: $sendmail_dir\n";
     }
}

$ENV{SENDMAIL_TESTDIR} = $sendmail_dir;
my $sendmail_tester = getcwd().'/t/sendmail_tester';

unless (-x $sendmail_tester) {
     BAIL_OUT(q(t/sendmail_tester doesn't exist or isn't executable. You may be in the wrong directory.));
}

my %files_to_create = ("$config_dir/debbugs_config" => <<END,
\$gSendmail='$sendmail_tester';
\$gSpoolDir='$spool_dir';
END
		       "$spool_dir/nextnumber" => qq(1\n),
		       "$config_dir/Maintainers" => qq(foo Blah Bleargh <bar\@baz.com>),
		       );
while (my ($file,$contents) = each %files_to_create) {
     my $fh = new IO::File $file,'w' or
	  BAIL_OUT("Unable to create $file: $!");
     print {$fh} $contents;
     close $fh;
}

system('touch',"$spool_dir/index.db.realtime");
system('ln','-s','index.db.realtime',
       "$spool_dir/index.db");
system('touch',"$spool_dir/index.archive.realtime");
system('ln','-s','index.archive.realtime',
       "$spool_dir/index.archive");


$ENV{DEBBUGS_CONFIG_FILE}  ="$config_dir/debbugs_config";

# create the spool files and sub directories
map {system('mkdir','-p',"$spool_dir/$_"); }
     map {('db-h/'.$_,'archive/'.$_)}
     map { sprintf "%02d",$_ % 100} 0..99;
system('mkdir','-p',"$spool_dir/incoming");


# We're going to use create mime message to create these messages, and
# then just send them to receive.

# First, check that submit@ works

$ENV{LOCAL_PART} = 'submit@bugs.something';
my $receive = new IO::File ('|scripts/receive.in') or BAIL_OUT("Unable to start receive.in: $!");

print {$receive} create_mime_message([To   => 'submit@bugs.something',
				      From => 'foo@bugs.something',
				      Subject => 'Submiting a bug',
				     ],
				     <<EOF);
Package: foo
Severity: normal

This is a silly bug
EOF

close($receive);
ok($?==0,'receive took the mail');
# now we should run processall to see if the message gets processed
ok(system('scripts/processall.in') == 0,'processall ran');

# now we check to see that we have a bug, and nextnumber has been incremented
ok(-e "$spool_dir/db-h/01/1.log",'log file created');
ok(-e "$spool_dir/db-h/01/1.summary",'sumary file created');
ok(-e "$spool_dir/db-h/01/1.status",'status file created');
ok(-e "$spool_dir/db-h/01/1.report",'report file created');

# next, we check to see that (at least) the proper messages have been
# sent out. 1) ack to submitter 2) mail to maintainer

sub dirsize{
     my ($dir) = @_;
     opendir(DIR,$dir);
     my @content = grep {!/^\.\.?$/} readdir(DIR);
     closedir(DIR);
     return scalar @content;
}

# This keeps track of the previous size of the sendmail directory
my $SD_SIZE_PREV = 0;
my $SD_SIZE_NOW = dirsize($sendmail_dir);
ok($SD_SIZE_NOW-$SD_SIZE_PREV >= 2,'submit messages appear to have been sent out properly');
$SD_SIZE_PREV=$SD_SIZE_NOW;

# now send a message to the bug

$ENV{LOCAL_PART} = '1@bugs.something';
$receive = new IO::File ('|scripts/receive.in') or
     BAIL_OUT("Unable to start receive.in: $!");

print {$receive} create_mime_message([To   => '1@bugs.something',
				      From => 'foo@bugs.something',
				      Subject => 'Sending a message to a bug',
				     ],
				     <<EOF);
Package: foo
Severity: normal

This is a silly bug
EOF

close($receive);
ok($?==0,'receive took the mail');
# now we should run processall to see if the message gets processed
ok(system('scripts/processall.in') == 0,'processall ran');
$SD_SIZE_NOW = dirsize($sendmail_dir);
ok($SD_SIZE_NOW-$SD_SIZE_PREV >= 2,'1@bugs.something messages appear to have been sent out properly');
$SD_SIZE_PREV=$SD_SIZE_NOW;

# just check to see that control doesn't explode
$ENV{LOCAL_PART} = 'control@bugs.something';
$receive = new IO::File ('|scripts/receive.in') or
     BAIL_OUT("Unable to start receive.in: $!");

print {$receive} create_mime_message([To   => 'control@bugs.something',
				      From => 'foo@bugs.something',
				      Subject => 'Munging a bug',
				     ],
				     <<EOF);
severity 1 wishlist
thanks
EOF

close($receive);
ok($?==0,'receive took the mail');
# now we should run processall to see if the message gets processed
ok(system('scripts/processall.in') == 0,'processall ran');
$SD_SIZE_NOW = dirsize($sendmail_dir);
ok($SD_SIZE_NOW-$SD_SIZE_PREV >= 2,'1@bugs.something messages appear to have been sent out properly');
$SD_SIZE_PREV=$SD_SIZE_NOW;



