
package DebbugsTest;

=head1 NAME

DebbugsTest

=head1 SYNOPSIS

use DebbugsTest


=head1 DESCRIPTION

This module contains various testing routines used to test debbugs in
a "pseudo install"

=head1 FUNCTIONS

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

use IO::File;
use File::Temp qw(tempdir);
use Cwd qw(getcwd);
use Debbugs::MIME qw(create_mime_message);
use File::Basename qw(dirname basename);
use IPC::Open3;
use IO::Handle;
use Test::More;

use Params::Validate qw(validate_with :types);

BEGIN{
     $VERSION = 1.00;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (configuration => [qw(dirsize create_debbugs_configuration send_message)],
		     mail          => [qw(num_messages_sent)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(qw(configuration mail));
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

# First, we're going to send mesages to receive.
# To do so, we'll first send a message to submit,
# then send messages to the newly created bugnumber.



sub create_debbugs_configuration {
     my %param = validate_with(params => \@_,
			       spec   => {debug => {type => BOOLEAN,
						    default => 0,
						   },
					  cleanup => {type => BOOLEAN,
						      optional => 1,
						     },
					 },
			      );
     $param{cleanup} = $param{debug}?0:1 if not exists $param{cleanup};
     my $sendmail_dir = tempdir(CLEANUP => $param{cleanup});
     my $spool_dir = tempdir(CLEANUP => $param{cleanup});
     my $config_dir = tempdir(CLEANUP => $param{cleanup});


     $ENV{DEBBUGS_CONFIG_FILE}  ="$config_dir/debbugs_config";
     $ENV{PERL5LIB} = getcwd();
     $ENV{SENDMAIL_TESTDIR} = $sendmail_dir;
     my $sendmail_tester = getcwd().'/t/sendmail_tester';
     unless (-x $sendmail_tester) {
	  die q(t/sendmail_tester doesn't exist or isn't executable. You may be in the wrong directory.);
     }
     my %files_to_create = ("$config_dir/debbugs_config" => <<END,
\$gSendmail='$sendmail_tester';
\$gSpoolDir='$spool_dir';
\$gLibPath='@{[getcwd()]}/scripts';
\$gTemplateDir='@{[getcwd()]}/templates';
\$gWebDir='@{[getcwd()]}/html';
\$gWebHost='localhost';
1;
END
			    "$spool_dir/nextnumber" => qq(1\n),
			    "$config_dir/Maintainers" => qq(foo Blah Bleargh <foo\@baz.com>\nbar Bar Bleargh <bar\@baz.com>\n),
			    "$config_dir/Maintainers.override" => qq(),
			    "$config_dir/Source_maintainers" => qq(foo Blah Bleargh <foo\@baz.com>\nbar Bar Bleargh <bar\@baz.com>\n),
			    "$config_dir/indices/sources" => <<END,
foo main foo
END
			    "$config_dir/pseudo-packages.description" => '',
			    "$config_dir/pseudo-packages.maintainers" => '',
			   );
     while (my ($file,$contents) = each %files_to_create) {
	  system('mkdir','-p',dirname($file));
	  my $fh = IO::File->new($file,'w') or
	       die "Unable to create $file: $!";
	  print {$fh} $contents or die "Unable to write $contents to $file: $!";
	  close $fh or die "Unable to close $file: $!";
     }

     system('touch',"$spool_dir/index.db.realtime");
     system('ln','-s','index.db.realtime',
	    "$spool_dir/index.db");
     system('touch',"$spool_dir/index.archive.realtime");
     system('ln','-s','index.archive.realtime',
	    "$spool_dir/index.archive");

     # create the spool files and sub directories
     for my $dir (0..99) {
         for my $archive (qw(db-h archive)) {
             system('mkdir','-p',"$spool_dir/$archive/".sprintf('%02d',$dir));
         }
     }
     system('mkdir','-p',"$spool_dir/incoming");
     system('mkdir','-p',"$spool_dir/lock");

     return (spool_dir => $spool_dir,
	     sendmail_dir => $sendmail_dir,
	     config_dir => $config_dir,
	    );
}

sub dirsize{
     my ($dir) = @_;
     opendir(DIR,$dir);
     my @content = grep {!/^\.\.?$/} readdir(DIR);
     closedir(DIR);
     return scalar @content;
}


# We're going to use create mime message to create these messages, and
# then just send them to receive.
# First, check that submit@ works

sub send_message{
     my %param = validate_with(params => \@_,
			       spec   => {to => {type => SCALAR,
						 default => 'submit@bugs.something',
						},
					  headers => {type => ARRAYREF,
						     },
					  body    => {type => SCALAR,
						     },
					  attachments => {type => ARRAYREF,
							  default => [],
							 },
					  run_processall =>{type => BOOLEAN,
							    default => 1,
							   },
					 }
			      );
     $ENV{LOCAL_PART} = $param{to};
     my ($rfd,$wfd);
     my $output='';
     my $pipe_handler = $SIG{PIPE};
     $SIG{PIPE} = 'IGNORE';
     $SIG{CHLD} = 'DEFAULT';
     my $pid = open3($wfd,$rfd,$rfd,'scripts/receive')
	  or die "Unable to start receive: $!";
     print {$wfd} create_mime_message($param{headers},
				      $param{body},
				      $param{attachments}) or
					  die "Unable to to print to receive";
     close($wfd) or die "Unable to close receive";
     $SIG{PIPE} = $pipe_handler;
     my $err = $? >> 8;
     my $childpid = waitpid($pid,0);
     if ($childpid != -1) {
	  $err = $? >> 8;
	  print STDERR "receive pid: $pid doesn't match childpid: $childpid\n" if $childpid != $pid;
     }
     if ($err != 0 ) {
	  my $rfh =  IO::Handle->new_from_fd($rfd,'r') or die "Unable to create filehandle: $!";
	  $rfh->blocking(0);
	  my $rv;
	  while ($rv = $rfh->sysread($output,1000,length($output))) {}
	  if (not defined $rv) {
	       print STDERR "Reading from STDOUT/STDERR would have blocked.";
	  }
	  print STDERR $output,qq(\n);
	  die "receive failed with exit status $err";
     }
     # now we should run processall to see if the message gets processed
     if ($param{run_processall}) {
	  system('scripts/processall') == 0 or die "processall failed";
     }
}

{
     package DebbugsTest::HTTPServer;
     use base qw(HTTP::Server::Simple::CGI HTTP::Server::Simple::CGI::Environment);

     our $child_pid = undef;
     our $webserver = undef;
     our $server_handler = undef;

     END {
	  if (defined $child_pid) {
	       # stop the child
	       my $temp_exit = $?;
	       kill(15,$child_pid);
	       waitpid(-1,0);
	       $? = $temp_exit;
	  }
     }

     sub fork_and_create_webserver {
	  my ($handler,$port) = @_;
	  $port ||= 8080;
	  if (defined $child_pid) {
	       die "We appear to have already forked once";
	  }
	  $server_handler = $handler;
	  my $pid = fork;
	  return 0 if not defined $pid;
	  if ($pid) {
	       $child_pid = $pid;
	       # Wait here for a second to let the child start up
	       sleep 1;
	       return $pid;
	  }
	  else {
	       $webserver = DebbugsTest::HTTPServer->new($port);
	       $webserver->run;
	  }

     }

     sub handle_request {
	  if (defined $server_handler) {
	       $server_handler->(@_);
	  }
	  else {
	       warn "No handler defined\n";
	       print "No handler defined\n";
	  }
     }
}

=head2 num_messages_sent

     $SD_SIZE = num_messages_sent($SD_SIZE,2,$sendmail_dir,'2 messages have been sent properly');

Tests to make sure that at least a certain number of messages have
been sent since the last time this command was run. Usefull to test to
make sure that mail has been sent.

=cut

sub num_messages_sent {
    my ($prev_size,$num_messages,$sendmail_dir,$test_name) = @_;
    my $cur_size = dirsize($sendmail_dir);
    ## print STDERR "sendmail: $sendmail_dir, want: $num_messages,
    ## size: $cur_size, prev_size: $prev_size\n";
    ok($cur_size-$prev_size >= $num_messages, $test_name);
    return $cur_size;
}


1;

__END__



