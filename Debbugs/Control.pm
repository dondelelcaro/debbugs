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


=head1 GENERAL FUNCTIONS

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

BEGIN{
     $VERSION = 1.00;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (affects => [qw(affects)],
		     summary => [qw(summary)],
		     owner   => [qw(owner)],
		     archive => [qw(bug_archive bug_unarchive),
				],
		     log     => [qw(append_action_to_log),
				],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

use Debbugs::Config qw(:config);
use Debbugs::Common qw(:lock buglog :misc get_hashname);
use Debbugs::Status qw(bug_archiveable :read :hook writebug splitpackages);
use Debbugs::CGI qw(html_escape);
use Debbugs::Log qw(:misc);
use Debbugs::Recipients qw(:add);

use Params::Validate qw(validate_with :types);
use File::Path qw(mkpath);
use IO::File;

use Debbugs::Text qw(:templates);

use Debbugs::Mail qw(rfc822_date);

use POSIX qw(strftime);

use Carp;

# These are a set of options which are common to all of these functions

my %common_options = (debug       => {type => SCALARREF|HANDLE,
				      optional => 1,
				     },
		      transcript  => {type => SCALARREF|HANDLE,
				      optional => 1,
				     },
		      affected_bugs => {type => HASHREF,
					optional => 1,
				       },
		      affected_packages => {type => HASHREF,
					    optional => 1,
					   },
		      recipients    => {type => HASHREF,
					default => {},
				       },
		      limit         => {type => HASHREF,
					default => {},
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


# this is just a generic stub for Debbugs::Control functions.
#
# =head2 foo
#
#      eval {
# 	    foo(bug          => $ref,
# 		transcript   => $transcript,
# 		($dl > 0 ? (debug => $transcript):()),
# 		requester    => $header{from},
# 		request_addr => $controlrequestaddr,
# 		message      => \@log,
#               affected_packages => \%affected_packages,
# 		recipients   => \%recipients,
# 		summary      => undef,
#              );
# 	};
# 	if ($@) {
# 	    $errors++;
# 	    print {$transcript} "Failed to foo $ref bar: $@";
# 	}
#
# Foo frobinates
#
# =cut
#
# sub foo {
#     my %param = validate_with(params => \@_,
# 			      spec   => {bug => {type   => SCALAR,
# 						 regex  => qr/^\d+$/,
# 						},
# 					 # specific options here
# 					 %common_options,
# 					 %append_action_options,
# 					},
# 			     );
#     our $locks = 0;
#     $locks = 0;
#     local $SIG{__DIE__} = sub {
# 	if ($locks) {
# 	    for (1..$locks) { unfilelock(); }
# 	    $locks = 0;
# 	}
#     };
#     my ($debug,$transcript) = __handle_debug_transcript(%param);
#     my (@data);
#     ($locks, @data) = lock_read_all_merged_bugs($param{bug});
#     __handle_affected_packages(data => \@data,%param);
#     print {$transcript} __bug_info(@data);
#     add_recipients(data => \@data,
# 		     recipients => $param{recipients}
#  		     debug      => $debug,
#  		     transcript => $transcript,
# 		    );
#     for my $data (@data) {
# 	 append_action_to_log(bug => $data->{bug_num},
# 			      get_lock => 0,
# 			      __return_append_to_log_options(
# 							     %param,
# 							     action => $action,
# 							    ),
# 			     )
# 	       if not exists $param{append_log} or $param{append_log};
# 	  writebug($data->{bug_num},$data);
# 	  print {$transcript} "$action\n";
# 	  add_recipients(data => $data,
# 			 recipients => $param{recipients},
#  		         debug      => $debug,
#  		         transcript => $transcript,
# 			);
#      }
#      if ($locks) {
# 	  for (1..$locks) { unfilelock(); }
#      }
#
# }

=head2 affects

     eval {
	    affects(bug          => $ref,
		    transcript   => $transcript,
		    ($dl > 0 ? (debug => $transcript):()),
		    requester    => $header{from},
		    request_addr => $controlrequestaddr,
		    message      => \@log,
                    affected_packages => \%affected_packages,
		    recipients   => \%recipients,
		    packages     => undef,
                    add          => 1,
                    remove       => 0,
                   );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to mark $ref as affecting $packages: $@";
	}

This marks a bug as affecting packages which the bug is not actually
in. This should only be used in cases where fixing the bug instantly
resolves the problem in the other packages.

By default, the packages are set to the list of packages passed.
However, if you pass add => 1 or remove => 1, the list of packages
passed are added or removed from the affects list, respectively.

=cut

sub affects {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 # specific options here
					 packages => {type => SCALAR|ARRAYREF,
						      default => [],
						     },
					 add      => {type => BOOLEAN,
						      default => 0,
						     },
					 remove   => {type => BOOLEAN,
						      default => 0,
						     },
					 %common_options,
					 %append_action_options,
					},
			     );
    if ($param{add} and $param{remove}) {
	 croak "Asking to both add and remove affects is nonsensical";
    }
    our $locks = 0;
    $locks = 0;
    local $SIG{__DIE__} = sub {
	if ($locks) {
	    for (1..$locks) { unfilelock(); }
	    $locks = 0;
	}
    };
    my ($debug,$transcript) = __handle_debug_transcript(%param);
    my (@data);
    ($locks, @data) = lock_read_all_merged_bugs($param{bug});
    __handle_affected_packages(data => \@data,%param);
    print {$transcript} __bug_info(@data);
    add_recipients(data => \@data,
		   recipients => $param{recipients},
		   debug      => $debug,
		   transcript => $transcript,
		  );
    my $action = 'Did not alter affected packages';
    for my $data (@data) {
	 print {$debug} "Going to change affects\n";
	 my @packages = splitpackages($data->{affects});
	 my %packages;
	 @packages{@packages} = (1) x @packages;
	 if ($param{add}) {
	      my @added = ();
	      for my $package (make_list($param{packages})) {
		   if (not $packages{$package}) {
			$packages{$package} = 1;
			push @added,$package;
		   }
	      }
	      if (@added) {
		   $action = "Added indication that $data->{bug_num} affects ".
			english_join(', ',' and ',@added);
	      }
	 }
	 elsif ($param{remove}) {
	      my @removed = ();
	      for my $package (make_list($param{packages})) {
		   if ($packages{$package}) {
			delete $packages{$package};
			push @removed,$package;
		   }
	      }
	      $action = "Removed indication that $data->{bug_num} affects " .
		   english_join(', ',' and ',@removed);
	 }
	 else {
	      %packages = ();
	      for my $package (make_list($param{packages})) {
		   $packages{$package} = 1;
	      }
	      $action = "Noted that $data->{bug_num} affects ".
		   english_join(', ',' and ', keys %packages);
	 }
	 $data->{affects} = join(',',keys %packages);
	 append_action_to_log(bug => $data->{bug_num},
			      get_lock => 0,
			      __return_append_to_log_options(
							     %param,
							     action => $action,
							    ),
			     )
	       if not exists $param{append_log} or $param{append_log};
	  writebug($data->{bug_num},$data);
	  print {$transcript} "$action\n";
	  add_recipients(data => $data,
			 recipients => $param{recipients},
			 debug      => $debug,
			 transcript => $transcript,
			);
     }
     if ($locks) {
	  for (1..$locks) { unfilelock(); }
     }

}


=head1 SUMMARY FUNCTIONS

=head2 summary

     eval {
	    summary(bug          => $ref,
		    transcript   => $transcript,
		    ($dl > 0 ? (debug => $transcript):()),
		    requester    => $header{from},
		    request_addr => $controlrequestaddr,
		    message      => \@log,
                    affected_packages => \%affected_packages,
		    recipients   => \%recipients,
		    summary      => undef,
                   );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to mark $ref with summary foo: $@";
	}

Handles all setting of summary fields

If summary is undef, unsets the summary

If summary is 0, sets the summary to the first paragraph contained in
the message passed.

If summary is numeric, sets the summary to the message specified.


=cut


sub summary {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 # specific options here
					 summary => {type => SCALAR|UNDEF,
						     default => 0,
						    },
					 %common_options,
					 %append_action_options,
					},
			     );
    croak "summary must be numeric or undef" if
	 defined $param{summary} and not $param{summary} =~ /^\d+$/;
    our $locks = 0;
    $locks = 0;
    local $SIG{__DIE__} = sub {
	if ($locks) {
	    for (1..$locks) { unfilelock(); }
	    $locks = 0;
	}
    };
    my ($debug,$transcript) = __handle_debug_transcript(%param);
    my (@data);
    ($locks, @data) = lock_read_all_merged_bugs($param{bug});
    __handle_affected_packages(data => \@data,%param);
    print {$transcript} __bug_info(@data);
    add_recipients(data => \@data,
		   recipients => $param{recipients},
		   debug      => $debug,
		   transcript => $transcript,
		  );
    # figure out the log that we're going to use
    my $summary = '';
    my $summary_msg = '';
    my $action = '';
    if (not defined $param{summary}) {
	 # do nothing
	 print {$debug} "Removing summary fields";
	 $action = 'Removed summary';
    }
    else {
	 my $log = [];
	 my @records = Debbugs::Log::read_log_records(bug_num => $param{bug});
	 if ($param{summary} == 0) {
	      $log = $param{log};
	      $summary_msg = @records + 1;
	 }
	 else {
	      if (($param{summary} - 1 ) > $#records) {
		   die "Message number '$param{summary}' exceeds the maximum message '$#records'";
	      }
	      my $record = $records[($param{summary} - 1 )];
	      if ($record->{type} !~ /incoming-recv|recips/) {
		   die "Message number '$param{summary}' is a invalid message type '$record->{type}'";
	      }
	      $summary_msg = $param{summary};
	      $log = [$record->{text}];
	 }
	 my $p_o = Debbugs::MIME::parse(join('',@{$log}));
	 my $body = $p_o->{body};
	 my $in_pseudoheaders = 0;
	 my $paragraph = '';
	 # walk through body until we get non-blank lines
	 for my $line (@{$body}) {
	      if ($line =~ /^\s*$/) {
		   if (length $paragraph) {
			last;
		   }
		   $in_pseudoheaders = 0;
		   next;
	      }
	      # skip a paragraph if it looks like it's control or
	      # pseudo-headers
	      if ($line =~ m{^\s*(?:(?:Package|Source|Version)\:| #pseudo headers
				 (?:package|(?:no|)owner|severity|tag|summary| #control
				      reopen|close|(?:not|)(?:fixed|found)|clone|
				      (?:force|)merge|user(?:category|tag|)
				 )
			    )\s+\S}x) {
		   if (not length $paragraph) {
			print {$debug} "Found control/pseudo-headers and skiping them\n";
			$in_pseudoheaders = 1;
			next;
		   }
	      }
	      next if $in_pseudoheaders;
	      $paragraph .= $line;
	 }
	 print {$debug} "Summary is going to be '$paragraph'\n";
	 $summary = $paragraph;
	 $summary =~ s/[\n\r]//g;
	 if (not length $summary) {
	      die "Unable to find summary message to use";
	 }
    }
    for my $data (@data) {
	 print {$debug} "Going to change summary";
	 if (length $summary) {
	      if (length $data->{summary}) {
		   $action = "Summary replaced with message bug $param{bug} message $summary_msg";
	      }
	      else {
		   $action = "Summary recorded from message bug $param{bug} message $summary_msg";
	      }
	 }
	 $data->{summary} = $summary;
	 append_action_to_log(bug => $data->{bug_num},
			      get_lock => 0,
			      __return_append_to_log_options(
							     %param,
							     action => $action,
							    ),
			     )
	       if not exists $param{append_log} or $param{append_log};
	  writebug($data->{bug_num},$data);
	  print {$transcript} "$action\n";
	  add_recipients(data => $data,
			 recipients => $param{recipients},
			 debug      => $debug,
			 transcript => $transcript,
			);
     }
     if ($locks) {
	  for (1..$locks) { unfilelock(); }
     }

}




=head1 OWNER FUNCTIONS

=head2 owner

     eval {
	    owner(bug          => $ref,
		  transcript   => $transcript,
		  ($dl > 0 ? (debug => $transcript):()),
		  requester    => $header{from},
		  request_addr => $controlrequestaddr,
		  message      => \@log,
		  recipients   => \%recipients,
		  owner        => undef,
		 );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to mark $ref as having an owner: $@";
	}

Handles all setting of the owner field; given an owner of undef or of
no length, indicates that a bug is not owned by anyone.

=cut

sub owner {
     my %param = validate_with(params => \@_,
			       spec   => {bug => {type   => SCALAR,
						  regex  => qr/^\d+$/,
						 },
					  owner => {type => SCALAR|UNDEF,
						   },
					  %common_options,
					  %append_action_options,
					 },
			      );
     our $locks = 0;
     $locks = 0;
     local $SIG{__DIE__} = sub {
	  if ($locks) {
	       for (1..$locks) { unfilelock(); }
	       $locks = 0;
	  }
     };
     my ($debug,$transcript) = __handle_debug_transcript(%param);
     my (@data);
     ($locks, @data) = lock_read_all_merged_bugs($param{bug});
     __handle_affected_packages(data => \@data,%param);
     print {$transcript} __bug_info(@data);
     @data and defined $data[0] or die "No bug found for $param{bug}";
     add_recipients(data => \@data,
		    recipients => $param{recipients},
		    debug      => $debug,
		    transcript => $transcript,
		   );
     my $action = '';
     for my $data (@data) {
	  print {$debug} "Going to change owner to '".(defined $param{owner}?$param{owner}:'(going to unset it)')."'\n";
	  print {$debug} "Owner is currently '$data->{owner}' for bug $data->{bug_num}\n";
	  if (not defined $param{owner} or not length $param{owner}) {
	       $param{owner} = '';
	       $action = "Removed annotation that $config{bug} was owned by " .
		    "$data->{owner}.";
	  }
	  else {
	       if (length $data->{owner}) {
		    $action = "Owner changed from $data->{owner} to $param{owner}.";
	       }
	       else {
		    $action = "Owner recorded as $param{owner}."
	       }
	  }
	  $data->{owner} = $param{owner};
	  append_action_to_log(bug => $data->{bug_num},
			       get_lock => 0,
	       __return_append_to_log_options(
					      %param,
					      action => $action,
					     ),
			      )
	       if not exists $param{append_log} or $param{append_log};
	  writebug($data->{bug_num},$data);
	  print {$transcript} "$action\n";
	  add_recipients(data => $data,
			 recipients => $param{recipients},
			 debug      => $debug,
			 transcript => $transcript,
			);
     }
     if ($locks) {
	  for (1..$locks) { unfilelock(); }
     }
}


=head1 ARCHIVE FUNCTIONS


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

=over

=item bug -- bug number

=item check_archiveable -- check wether a bug is archiveable before
archiving; defaults to 1

=item archive_unarchived -- whether to archive bugs which have not
previously been archived; defaults to 1. [Set to 0 when used from
control@]

=item ignore_time -- whether to ignore time constraints when archiving
a bug; defaults to 0.

=back

=cut

sub bug_archive {
     my %param = validate_with(params => \@_,
			       spec   => {bug => {type   => SCALAR,
						  regex  => qr/^\d+$/,
						 },
					  check_archiveable => {type => BOOLEAN,
								default => 1,
							       },
					  archive_unarchived => {type => BOOLEAN,
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
     $locks = 0;
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
     my (@data);
     ($locks, @data) = lock_read_all_merged_bugs($param{bug});
     __handle_affected_packages(data => \@data,%param);
     print {$transcript} __bug_info(@data);
     print {$debug} "$param{bug} read $locks\n";
     @data and defined $data[0] or die "No bug found for $param{bug}";
     print {$debug} "$param{bug} read done\n";

     if (not $param{archive_unarchived} and
	 not exists $data[0]{unarchived}
	) {
	  print {$transcript} "$param{bug} has not been archived previously\n";
	  die "$param{bug} has not been archived previously";
     }
     add_recipients(recipients => $param{recipients},
		    data => \@data,
		    debug      => $debug,
		    transcript => $transcript,
		   );
     my @bugs = map {$_->{bug_num}} @data;
     print {$debug} "$param{bug} bugs ".join(' ',@bugs)."\n";
     for my $bug (@bugs) {
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
				 %param,
				 action => $action,
				)
			      )
	       if not exists $param{append_log} or $param{append_log};
	  my @files_to_remove = map {s#$config{spool_dir}/db-h/$dir/##; $_} glob("$config{spool_dir}/db-h/$dir/$bug.*");
	  if ($config{save_old_bugs}) {
	       mkpath("$config{spool_dir}/archive/$dir");
	       foreach my $file (@files_to_remove) {
		    link( "$config{spool_dir}/db-h/$dir/$file", "$config{spool_dir}/archive/$dir/$file" ) or
			 copy( "$config{spool_dir}/db-h/$dir/$file", "$config{spool_dir}/archive/$dir/$file" );
	       }

	       print {$transcript} "archived $bug to archive/$dir (from $param{bug})\n";
	  }
	  unlink(map {"$config{spool_dir}/db-h/$dir/$_"} @files_to_remove);
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
     our $locks = 0;
     local $SIG{__DIE__} = sub {
	  if ($locks) {
	       for (1..$locks) { unfilelock(); }
	       $locks = 0;
	  }
     };
     my $action = "$config{bug} unarchived.";
     my ($debug,$transcript) = __handle_debug_transcript(%param);
     print {$debug} "$param{bug} considering\n";
     my @data = ();
     ($locks, @data) = lock_read_all_merged_bugs($param{bug},'archive');
     __handle_affected_packages(data => \@data,%param);
     print {$transcript} __bug_info(@data);
     print {$debug} "$param{bug} read $locks\n";
     if (not @data or not defined $data[0]) {
	 print {$transcript} "No bug found for $param{bug}\n";
	 die "No bug found for $param{bug}";
     }
     print {$debug} "$param{bug} read done\n";
     my @bugs = map {$_->{bug_num}} @data;
     print {$debug} "$param{bug} bugs ".join(' ',@bugs)."\n";
     print {$debug} "$param{bug} unarchiving\n";
     my @files_to_remove;
     for my $bug (@bugs) {
	  print {$debug} "$param{bug} removing $bug\n";
	  my $dir = get_hashname($bug);
	  my @files_to_copy = map {s#$config{spool_dir}/archive/$dir/##; $_} glob("$config{spool_dir}/archive/$dir/$bug.*");
	  mkpath("archive/$dir");
	  foreach my $file (@files_to_copy) {
	       # die'ing here sucks
	       link( "$config{spool_dir}/archive/$dir/$file", "$config{spool_dir}/db-h/$dir/$file" ) or
		    copy( "$config{spool_dir}/archive/$dir/$file", "$config{spool_dir}/db-h/$dir/$file" ) or
			 die "Unable to copy $config{spool_dir}/archive/$dir/$file to $config{spool_dir}/db-h/$dir/$file";
	  }
	  push @files_to_remove, map {"$config{spool_dir}/archive/$dir/$_"} @files_to_copy;
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
				 %param,
				 action => $action,
				)
			      )
	       if not exists $param{append_log} or $param{append_log};
	  writebug($bug,$newdata);
	  add_recipients(recipients => $param{recipients},
			 data       => $newdata,
			 debug      => $debug,
			 transcript => $transcript,
			);
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

=head2 __handle_affected_packages

     __handle_affected_packages(affected_packages => {},
                                data => [@data],
                               )



=cut

sub __handle_affected_packages{
     my %param = validate_with(params => \@_,
			       spec   => {%common_options,
					  data => {type => ARRAYREF|HASHREF
						  },
					 },
			       allow_extra => 1,
			      );
     for my $data (make_list($param{data})) {
	  $param{affected_packages}{$data->{package}} = 1;
     }
}

=head2 __handle_debug_transcript

     my ($debug,$transcript) = __handle_debug_transcript(%param);

Returns a debug and transcript filehandle


=cut

sub __handle_debug_transcript{
     my %param = validate_with(params => \@_,
			       spec   => {%common_options},
			       allow_extra => 1,
			      );
     my $debug = globify_scalar(exists $param{debug}?$param{debug}:undef);
     my $transcript = globify_scalar(exists $param{transcript}?$param{transcript}:undef);
     return ($debug,$transcript);
}

=head2 __bug_info

     __bug_info($data)

Produces a small bit of bug information to kick out to the transcript

=cut

sub __bug_info{
     my $return = '';
     for my $data (@_) {
	  $return .= "Bug ".($data->{bug_num}||'').
	       " [".($data->{package}||''). "] ".
		    ($data->{subject}||'')."\n";
     }
     return $return;
}


sub __return_append_to_log_options{
     my %param = @_;
     my $action = $param{action} if exists $param{action};
     if (not exists $param{requester}) {
	  $param{requester} = $config{control_internal_requester};
     }
     if (not exists $param{request_addr}) {
	  $param{request_addr} = $config{control_internal_request_addr};
     }
     if (not exists $param{message}) {
	  my $date = rfc822_date();
	  $param{message} = fill_in_template(template  => 'mail/fake_control_message',
					     variables => {request_addr => $param{request_addr},
							   requester    => $param{requester},
							   date         => $date,
							   action       => $action
							  },
					    );
     }
     if (not defined $action) {
	  carp "Undefined action!";
	  $action = "unknown action";
     }
     return (action => $action,
	     (map {exists $append_action_options{$_}?($_,$param{$_}):()}
	      keys %param),
	    );
}


1;

__END__
