
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

use Params::Validate qw(validate_with :types);

BEGIN{
     $VERSION = 1.00;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (configuration => [qw(dirsize create_debbugs_configuration send_message)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(qw(configuration));
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
1;
END
			    "$spool_dir/nextnumber" => qq(1\n),
			    "$config_dir/Maintainers" => qq(foo Blah Bleargh <bar\@baz.com>\n),
			    "$config_dir/Maintainers.override" => qq(),
			    "$config_dir/indices/sources" => <<END,
foo main foo
END
			    "$config_dir/pseudo-packages.description" => '',
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
     map {system('mkdir','-p',"$spool_dir/$_"); }
	  map {('db-h/'.$_,'archive/'.$_)}
	       map { sprintf "%02d",$_ % 100} 0..99;
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
					  run_processall =>{type => BOOLEAN,
							    default => 1,
							   },
					 }
			      );
     $ENV{LOCAL_PART} = $param{to};
     my $receive = new IO::File ('|scripts/receive.in') or die "Unable to start receive.in: $!";

     print {$receive} create_mime_message($param{headers},
					  $param{body}) or die "Unable to to print to receive.in";
     close($receive) or die "Unable to close receive.in";
     $? == 0 or die "receive.in failed";
     # now we should run processall to see if the message gets processed
     if ($param{run_processall}) {
	  system('scripts/processall.in') == 0 or die "processall.in failed";
     }
}

{
     package DebbugsTest::HTTPServer;
     use base qw(HTTP::Server::Simple::CGI);

     our $child_pid = undef;
     our $webserver = undef;
     our $server_handler = undef;

     END {
	  if (defined $child_pid) {
	       # stop the child
	       kill(15,$child_pid);
	       waitpid(-1,0);
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


1;

__END__



