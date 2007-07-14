# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# go here too.]
# Copyright 2007 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Control;

=head1 NAME

Debbugs::Control -- Routines for modifying the state of bugs

=head1 SYNOPSIS

use Debbugs::Control;


=head1 DESCRIPTION

This module is an abstraction of a lot of functions which originally
were only present in service.in, but as time has gone on needed to be
called from elsewhere.

All of the public functions take the following options:

=over

=item debug -- scalar reference to which debbuging information is
appended

=item transcript -- scalar reference to which transcript information
is appended

=item affected_bugs -- hashref which is updated with bugs affected by
this function


=back

Functions which should (probably) append to the .log file take the
following options:

=over

=item requester -- Email address of the individual who requested the change

=item request_addr -- Address to which the request was sent

=item location -- Optional location; currently ignored but may be
supported in the future for updating archived bugs upon archival

=item message -- The original message which caused the action to be taken

=item append_log -- Whether or not to append information to the log.

=back

B<append_log> (for most functions) is a special option. When set to
false, no appending to the log is done at all. When it is not present,
the above information is faked, and appended to the log file. When it
is true, the above options must be present, and their values are used.


=head1 FUNCTIONS

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

BEGIN{
     $VERSION = 1.00;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (archive => [qw(bug_archive bug_unarchive),
				],
		     log     => [qw(append_action_to_log),
				],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(qw(archive log));
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

use Debbugs::Config qw(:config);
use Debbugs::Common qw(:lock buglog make_list get_hashname);
use Debbugs::Status qw(bug_archiveable :read :hook);
use Debbugs::CGI qw(html_escape);
use Debbugs::Log qw(:misc);

use Params::Validate qw(validate_with :types);
use File::Path qw(mkpath);
use IO::File;

use POSIX qw(strftime);

# These are a set of options which are common to all of these functions 

my %common_options = (debug       => {type => SCALARREF,
				      optional => 1,
				     },
		      transcript  => {type => SCALARREF,
				      optional => 1,
				     },
		      affected_bugs => {type => HASHREF,
					optional => 1,
				       },
		     );


my %append_action_options =
     (action => {type => SCALAR,
		 optional => 1,
		},
      requester => {type => SCALAR,
		    optional => 1,
		   },
      request_addr => {type => SCALAR,
		       optional => 1,
		      },
      location => {type => SCALAR,
		   optional => 1,
		  },
      message  => {type => SCALAR|ARRAYREF,
		   optional => 1,
		  },
      append_log => {type => BOOLEAN,
		     optional => 1,
		     depends => [qw(requester request_addr),
				 qw(message),
				],
		    },
     );


=head2 bug_archive

     my $error = '';
     eval {
        bug_archive(bug => $bug_num,
                    debug => \$debug,
                    transcript => \$transcript,
                   );
     };
     if ($@) {
        $errors++;
        transcript("Unable to archive $bug_num\n");
        warn $@;
     }
     transcript($transcript);


This routine archives a bug

=cut

sub bug_archive {
     my %param = validate_with(params => \@_,
			       spec   => {bug => {type   => SCALAR,
						  regex  => qr/^\d+$/,
						 },
					  check_archiveable => {type => BOOLEAN,
								default => 1,
							       },
					  ignore_time => {type => BOOLEAN,
							  default => 0,
							 },
					  %common_options,
					  %append_action_options,
					 },
			      );
     our $locks = 0;
     local $SIG{__DIE__} = sub {
	  if ($locks) {
	       for (1..$locks) { unfilelock(); }
	       $locks = 0;
	  }
     };
     my $action = "$config{bug} archived.";
     my ($debug,$transcript) = __handle_debug_transcript(%param);
     if ($param{check_archiveable} and
	 not bug_archiveable(bug=>$param{bug},
			     ignore_time => $param{ignore_time},
			    )) {
	  print {$transcript} "Bug $param{bug} cannot be archived\n";
	  die "Bug $param{bug} cannot be archived";
     }
     print {$debug} "$param{bug} considering\n";
     my ($data);
     ($locks, $data) = lockreadbugmerge($param{bug});
     print {$debug} "$param{bug} read $locks\n";
     defined $data or die "No bug found for $param{bug}";
     print {$debug} "$param{bug} read ok (done $data->{done})\n";
     print {$debug} "$param{bug} read done\n";
     my @bugs = ($param{bug});
     # my %bugs;
     # @bugs{@bugs} = (1) x @bugs;
     if (length($data->{mergedwith})) {
	  push(@bugs,split / /,$data->{mergedwith});
     }
     print {$debug} "$param{bug} bugs ".join(' ',@bugs)."\n";
     for my $bug (@bugs) {
	  my $newdata;
	  print {$debug} "$param{bug} $bug check\n";
	  if ($bug != $param{bug}) {
	       print {$debug} "$param{bug} $bug reading\n";
	       $newdata = lockreadbug($bug) || die "huh $bug ?";
	       print {$debug} "$param{bug} $bug read ok\n";
	       $locks++;
	  } else {
	       $newdata = $data;
	  }
	  print {$debug} "$param{bug} $bug read/not\n";
	  my $expectmerge= join(' ',grep($_ != $bug, sort { $a <=> $b } @bugs));
	  $newdata->{mergedwith} eq $expectmerge ||
	       die "$param{bug} differs from $bug: ($newdata->{mergedwith}) vs. ($expectmerge) (".join(' ',@bugs).")";
	  print {$debug} "$param{bug} $bug merge-ok\n";
	  if ($param{check_archiveable}) {
	       die "Bug $bug cannot be archived (but $param{bug} can?)"
		    unless bug_archiveable(bug=>$bug,
					   ignore_time => $param{ignore_time},
					  );
	  }
     }
     # If we get here, we can archive/remove this bug
     print {$debug} "$param{bug} removing\n";
     for my $bug (@bugs) {
	  #print "$param{bug} removing $bug\n" if $debug;
	  my $dir = get_hashname($bug);
	  # First indicate that this bug is being archived
	  append_action_to_log(bug => $bug,
			       get_lock => 0,
			       __return_append_to_log_options(
				 (map {exists $param{$_}?($_,$param{$_}):()}
				  keys %append_action_options,
				 ),
				 action => $action,
				)
			      )
	       if not exists $param{append_log} or $param{append_log};
	  my @files_to_remove = map {s#db-h/$dir/##; $_} glob("db-h/$dir/$bug.*");
	  if ($config{save_old_bugs}) {
	       mkpath("archive/$dir");
	       foreach my $file (@files_to_remove) {
		    link( "db-h/$dir/$file", "archive/$dir/$file" ) || copy( "db-h/$dir/$file", "archive/$dir/$file" );
	       }

	       print {$transcript} "archived $bug to archive/$dir (from $param{bug})\n";
	  }
	  unlink(map {"db-h/$dir/$_"} @files_to_remove);
	  print {$transcript} "deleted $bug (from $param{bug})\n";
     }
     bughook_archive(@bugs);
     if (exists $param{bugs_affected}) {
	  @{$param{bugs_affected}}{@bugs} = (1) x @bugs;
     }
     print {$debug} "$param{bug} unlocking $locks\n";
     if ($locks) {
	  for (1..$locks) { unfilelock(); }
     }
     print {$debug} "$param{bug} unlocking done\n";
}

=head2 bug_unarchive

     my $error = '';
     eval {
        bug_unarchive(bug => $bug_num,
                      debug => \$debug,
                      transcript => \$transcript,
                     );
     };
     if ($@) {
        $errors++;
        transcript("Unable to archive bug: $bug_num");
     }
     transcript($transcript);

This routine unarchives a bug

=cut

sub bug_unarchive {
     my %param = validate_with(params => \@_,
			       spec   => {bug => {type   => SCALAR,
						  regex  => qr/^\d+/,
						 },
					  %common_options,
					  %append_action_options,
					 },
			      );
     my $action = "$config{bug} unarchived.";
     my ($debug,$transcript) = __handle_debug_transcript(%param);
     print {$debug} "$param{bug} considering\n";
     my ($locks, $data) = lockreadbugmerge($param{bug},'archive');
     print {$debug} "$param{bug} read $locks\n";
     if (not defined $data) {
	  print {$transcript} "No bug found for $param{bug}\n";
	  die "No bug found for $param{bug}";
     }
     print {$debug} "$param{bug} read ok (done $data->{done})\n";
     print {$debug} "$param{bug} read done\n";
     my @bugs = ($param{bug});
     # my %bugs;
     # @bugs{@bugs} = (1) x @bugs;
     if (length($data->{mergedwith})) {
	  push(@bugs,split / /,$data->{mergedwith});
     }
     print {$debug} "$param{bug} bugs ".join(' ',@bugs)."\n";
     for my $bug (@bugs) {
	  my $newdata;
	  print {$debug} "$param{bug} $bug check\n";
	  if ($bug != $param{bug}) {
	       print {$debug} "$param{bug} $bug reading\n";
	       $newdata = lockreadbug($bug,'archive') or die "huh $bug ?";
	       print {$debug} "$param{bug} $bug read ok\n";
	       $locks++;
	  } else {
	       $newdata = $data;
	  }
	  print {$debug} "$param{bug} $bug read/not\n";
	  my $expectmerge= join(' ',grep($_ != $bug, sort { $a <=> $b } @bugs));
	  if ($newdata->{mergedwith} ne $expectmerge ) {
	       print {$transcript} "$param{bug} differs from $bug: ($newdata->{mergedwith}) vs. ($expectmerge) (@bugs)";
	       die "$param{bug} differs from $bug: ($newdata->{mergedwith}) vs. ($expectmerge) (@bugs)";
	  }
	  print {$debug} "$param{bug} $bug merge-ok\n";
     }
     # If we get here, we can archive/remove this bug
     print {$debug} "$param{bug} removing\n";
     my @files_to_remove;
     for my $bug (@bugs) {
	  print {$debug} "$param{bug} removing $bug\n";
	  my $dir = get_hashname($bug);
	  my @files_to_copy = map {s#archive/$dir/##; $_} glob("archive/$dir/$bug.*");
	  mkpath("archive/$dir");
	  foreach my $file (@files_to_copy) {
	       # die'ing here sucks
	       link( "archive/$dir/$file", "db-h/$dir/$file" ) or
		    copy( "archive/$dir/$file", "db-h/$dir/$file" ) or
			 die "Unable to copy archive/$dir/$file to db-h/$dir/$file";
	  }
	  push @files_to_remove, map {"archive/$dir/$_"} @files_to_copy;
	  print {$transcript} "Unarchived $config{bug} $bug\n";
     }
     unlink(@files_to_remove) or die "Unable to unlink bugs";
     # Indicate that this bug has been archived previously
     for my $bug (@bugs) {
	  my $newdata = readbug($bug);
	  if (not defined $newdata) {
	       print {$transcript} "$config{bug} $bug disappeared!\n";
	       die "Bug $bug disappeared!";
	  }
	  $newdata->{unarchived} = time;
	  append_action_to_log(bug => $bug,
			       get_lock => 0,
			       __return_append_to_log_options(
				 (map {exists $param{$_}?($_,$param{$_}):()}
				  keys %append_action_options,
				 ),
				 action => $action,
				)
			      )
	       if not exists $param{append_log} or $param{append_log};
	  writebug($bug,$newdata);
     }
     print {$debug} "$param{bug} unlocking $locks\n";
     if ($locks) {
	  for (1..$locks) { unfilelock(); };
     }
     if (exists $param{bugs_affected}) {
	  @{$param{bugs_affected}}{@bugs} = (1) x @bugs;
     }
     print {$debug} "$param{bug} unlocking done\n";
}

=head2 append_action_to_log

     append_action_to_log

This should probably be moved to Debbugs::Log; have to think that out
some more.

=cut

sub append_action_to_log{
     my %param = validate_with(params => \@_,
			       spec   => {bug => {type   => SCALAR,
						  regex  => qr/^\d+/,
						 },
					  action => {type => SCALAR,
						    },
					  requester => {type => SCALAR,
						       },
					  request_addr => {type => SCALAR,
							  },
					  location => {type => SCALAR,
						       optional => 1,
						      },
					  message  => {type => SCALAR|ARRAYREF,
						      },
					  get_lock   => {type => BOOLEAN,
							 default => 1,
							},
					 }
			      );
     # Fix this to use $param{location}
     my $log_location = buglog($param{bug});
     die "Unable to find .log for $param{bug}"
	  if not defined $log_location;
     if ($param{get_lock}) {
	  filelock("lock/$param{bug}");
     }
     my $log = IO::File->new(">>$log_location") or
	  die "Unable to open $log_location for appending: $!";
     print {$log} "\6\n".
	  "<!-- time:".time." -->\n".
          "<strong>".html_escape($param{action})."</strong>\n".
          "Request was from <code>".html_escape($param{requester})."</code>\n".
          "to <code>".html_escape($param{request_addr})."</code>. \n".
	  "\3\n".
	  "\7\n",escape_log(make_list($param{message})),"\n\3\n"
	       or die "Unable to append to $log_location: $!";
     close $log or die "Unable to close $log_location: $!";
     if ($param{get_lock}) {
	  unlockfile();
     }


}


=head1 PRIVATE FUNCTIONS

=head2 __handle_debug_transcript

     my ($debug,$transcript) = __handle_debug_transcript(%param);

Returns a debug and transcript IO::Scalar filehandle


=cut

sub __handle_debug_transcript{
     my %param = validate_with(params => \@_,
			       spec   => {%common_options},
			       allow_extra => 1,
			      );
     my $fake_scalar;
     my $debug = IO::Scalar->new(exists $param{debug}?$param{debug}:\$fake_scalar);
     my $transcript = IO::Scalar->new(exists $param{transcript}?$param{transcript}:\$fake_scalar);
     return ($debug,$transcript);

}

sub __return_append_to_log_options{
     my %param = @_;
     my $action = 'Unknown action';
     if (not exists $param{requester}) {
	  $param{requester} = $config{control_internal_requester};
     }
     if (not exists $param{request_addr}) {
	  $param{request_addr} = $config{control_internal_request_addr};
     }
     if (not exists $param{message}) {
	  $action = $param{action} if exists $param{action};
	  my $date = strftime "%a, %d %h %Y %T +0000", gmtime;
	  $param{message} = <<END;
Received: (at fakecontrol) by fakecontrolmessage;
To: $param{request_addr}
From: $param{requester}
Subject: Internal Control
Message-Id: $action
Date: $date
User-Agent: Fakemail v42.6.9

# A New Hope
# A log time ago, in a galaxy far, far away
# something happened.
#
# Magically this resulted in the following
# action being taken, but this fake control
# message doesn't tell you why it happened
#
# The action:
# $action
thanks
# This fakemail brought to you by your local debbugs
# administrator
END
     }
     return (action => $action,
	     %param);
}


1;

__END__
