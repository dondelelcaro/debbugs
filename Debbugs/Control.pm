# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# go here too.]
# Copyright 2007,2008,2009 by Don Armstrong <don@donarmstrong.com>.

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

=item request_nn -- Name of queue file which caused this request

=item request_msgid -- Message id of message which caused this request

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
use Exporter qw(import);

BEGIN{
     $VERSION = 1.00;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (done    => [qw(set_done)],
		     submitter => [qw(set_submitter)],
		     severity => [qw(set_severity)],
		     affects => [qw(affects)],
		     summary => [qw(summary)],
		     outlook => [qw(outlook)],
		     owner   => [qw(owner)],
		     title   => [qw(set_title)],
		     forward => [qw(set_forwarded)],
		     found   => [qw(set_found set_fixed)],
		     fixed   => [qw(set_found set_fixed)],
		     package => [qw(set_package)],
		     block   => [qw(set_blocks)],
		     merge   => [qw(set_merged)],
		     tag     => [qw(set_tag)],
		     clone   => [qw(clone_bug)],
		     archive => [qw(bug_archive bug_unarchive),
				],
		     limit   => [qw(check_limit)],
		     log     => [qw(append_action_to_log),
				],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

use Debbugs::Config qw(:config);
use Debbugs::Common qw(:lock buglog :misc get_hashname sort_versions);
use Debbugs::UTF8;
use Debbugs::Status qw(bug_archiveable :read :hook writebug new_bug splitpackages split_status_fields get_bug_status);
use Debbugs::CGI qw(html_escape);
use Debbugs::Log qw(:misc :write);
use Debbugs::Recipients qw(:add);
use Debbugs::Packages qw(:versions :mapping);

use Data::Dumper qw();
use Params::Validate qw(validate_with :types);
use File::Path qw(mkpath);
use File::Copy qw(copy);
use IO::File;

use Debbugs::Text qw(:templates);

use Debbugs::Mail qw(rfc822_date send_mail_message default_headers encode_headers);
use Debbugs::MIME qw(create_mime_message);

use Mail::RFC822::Address qw();

use POSIX qw(strftime);

use Storable qw(dclone nfreeze);
use List::Util qw(first max);
use Encode qw(encode_utf8);

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
		      show_bug_info => {type => BOOLEAN,
					default => 1,
				       },
		      request_subject => {type => SCALAR,
					  default => 'Unknown Subject',
					 },
		      request_msgid    => {type => SCALAR,
					   default => '',
					  },
		      request_nn       => {type => SCALAR,
					   optional => 1,
					  },
		      request_replyto   => {type => SCALAR,
					    optional => 1,
					   },
		      locks             => {type => HASHREF,
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
      # locks is both an append_action option, and a common option;
      # it's ok for it to be in both places.
      locks     => {type => HASHREF,
		    optional => 1,
		   },
     );

our $locks = 0;


# this is just a generic stub for Debbugs::Control functions.
#
# =head2 set_foo
#
#      eval {
# 	    set_foo(bug          => $ref,
# 		    transcript   => $transcript,
# 		    ($dl > 0 ? (debug => $transcript):()),
# 		    requester    => $header{from},
# 		    request_addr => $controlrequestaddr,
# 		    message      => \@log,
#                   affected_packages => \%affected_packages,
# 		    recipients   => \%recipients,
# 		    summary      => undef,
#                  );
# 	};
# 	if ($@) {
# 	    $errors++;
# 	    print {$transcript} "Failed to set foo $ref bar: $@";
# 	}
#
# Foo frobinates
#
# =cut
#
# sub set_foo {
#     my %param = validate_with(params => \@_,
# 			      spec   => {bug => {type   => SCALAR,
# 						 regex  => qr/^\d+$/,
# 						},
# 					 # specific options here
# 					 %common_options,
# 					 %append_action_options,
# 					},
# 			     );
#     my %info =
# 	__begin_control(%param,
# 			command  => 'foo'
# 		       );
#     my ($debug,$transcript) =
# 	@info{qw(debug transcript)};
#     my @data = @{$info{data}};
#     my @bugs = @{$info{bugs}};
#
#     my $action = '';
#     for my $data (@data) {
# 	append_action_to_log(bug => $data->{bug_num},
# 			     get_lock => 0,
# 			     __return_append_to_log_options(
# 							    %param,
# 							    action => $action,
# 							   ),
# 			    )
# 	    if not exists $param{append_log} or $param{append_log};
# 	writebug($data->{bug_num},$data);
# 	print {$transcript} "$action\n";
#     }
#     __end_control(%info);
# }


=head2 set_blocks

     eval {
	    set_block(bug          => $ref,
		      transcript   => $transcript,
		      ($dl > 0 ? (debug => $transcript):()),
		      requester    => $header{from},
		      request_addr => $controlrequestaddr,
		      message      => \@log,
                      affected_packages => \%affected_packages,
		      recipients   => \%recipients,
		      block        => [],
                     );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to set blockers of $ref: $@";
	}

Alters the set of bugs that block this bug from being fixed

This requires altering both this bug (and those it's merged with) as
well as the bugs that block this bug from being fixed (and those that
it's merged with)

=over

=item block -- scalar or arrayref of blocking bugs to set, add or remove

=item add -- if true, add blocking bugs

=item remove -- if true, remove blocking bugs

=back

=cut

sub set_blocks {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 # specific options here
					 block => {type => SCALAR|ARRAYREF,
						   default => [],
						  },
					 add    => {type => BOOLEAN,
						    default => 0,
						   },
					 remove => {type => BOOLEAN,
						    default => 0,
						   },
					 %common_options,
					 %append_action_options,
					},
			     );
    if ($param{add} and $param{remove}) {
	croak "It's nonsensical to add and remove the same blocking bugs";
    }
    if (grep {$_ !~ /^\d+$/} make_list($param{block})) {
	croak "Invalid blocking bug(s):".
	    join(', ',grep {$_ !~ /^\d+$/} make_list($param{block}));
    }
    my $mode = 'set';
    if ($param{add}) {
	$mode = 'add';
    }
    elsif ($param{remove}) {
	$mode = 'remove';
    }

    my %info =
	__begin_control(%param,
			command  => 'blocks'
		       );
    my ($debug,$transcript) =
	@info{qw(debug transcript)};
    my @data = @{$info{data}};
    my @bugs = @{$info{bugs}};


    # The first bit of this code is ugly, and should be cleaned up.
    # Its purpose is to populate %removed_blockers and %add_blockers
    # with all of the bugs that should be added or removed as blockers
    # of all of the bugs which are merged with $param{bug}
    my %ok_blockers;
    my %bad_blockers;
    for my $blocker (make_list($param{block})) {
	next if $ok_blockers{$blocker} or $bad_blockers{$blocker};
	my $data = read_bug(bug=>$blocker,
			   );
	if (defined $data and not $data->{archive}) {
	    $data = split_status_fields($data);
	    $ok_blockers{$blocker} = 1;
	    my @merged_bugs;
	    push @merged_bugs, make_list($data->{mergedwith});
	    @ok_blockers{@merged_bugs} = (1) x @merged_bugs if @merged_bugs;
	}
	else {
	    $bad_blockers{$blocker} = 1;
	}
    }

    # throw an error if we are setting the blockers and there is a bad
    # blocker
    if (keys %bad_blockers and $mode eq 'set') {
	croak "Unknown blocking bug(s):".join(', ',keys %bad_blockers).
	    keys %ok_blockers?'':" and no known blocking bug(s)";
    }
    # if there are no ok blockers and we are not setting the blockers,
    # there's an error.
    if (not keys %ok_blockers and $mode ne 'set') {
	print {$transcript} "No valid blocking bug(s) given; not doing anything\n";
	if (keys %bad_blockers) {
	    croak "Unknown blocking bug(s):".join(', ',keys %bad_blockers);
	}
	__end_control(%info);
	return;
    }

    my @change_blockers = keys %ok_blockers;

    my %removed_blockers;
    my %added_blockers;
    my $action = '';
    my @blockers = map {split ' ', $_->{blockedby}} @data;
    my %blockers;
    @blockers{@blockers} = (1) x @blockers;

    # it is nonsensical for a bug to block itself (or a merged
    # partner); We currently don't allow removal because we'd possibly
    # deadlock

    my %bugs;
    @bugs{@bugs} = (1) x @bugs;
    for my $blocker (@change_blockers) {
	if ($bugs{$blocker}) {
	    croak "It is nonsensical for a bug to block itself (or a merged partner): $blocker";
	}
    }
    @blockers = keys %blockers;
    if ($param{add}) {
	%removed_blockers = ();
	for my $blocker (@change_blockers) {
	    next if exists $blockers{$blocker};
	    $blockers{$blocker} = 1;
	    $added_blockers{$blocker} = 1;
	}
    }
    elsif ($param{remove}) {
	%added_blockers = ();
	for my $blocker (@change_blockers) {
	    next if exists $removed_blockers{$blocker};
	    delete $blockers{$blocker};
	    $removed_blockers{$blocker} = 1;
	}
    }
    else {
	@removed_blockers{@blockers} = (1) x @blockers;
	%blockers = ();
	for my $blocker (@change_blockers) {
	    next if exists $blockers{$blocker};
	    $blockers{$blocker} = 1;
	    if (exists $removed_blockers{$blocker}) {
		delete $removed_blockers{$blocker};
	    }
	    else {
		$added_blockers{$blocker} = 1;
	    }
	}
    }
    for my $data (@data) {
	my $old_data = dclone($data);
	# remove blockers and/or add new ones as appropriate
	if ($data->{blockedby} eq '') {
	    print {$transcript} "$data->{bug_num} was not blocked by any bugs.\n";
	} else {
	    print {$transcript} "$data->{bug_num} was blocked by: $data->{blockedby}\n";
	}
	if ($data->{blocks} eq '') {
	    print {$transcript} "$data->{bug_num} was not blocking any bugs.\n";
	} else {
	    print {$transcript} "$data->{bug_num} was blocking: $data->{blocks}\n";
	}
	my @changed;
	push @changed, 'added blocking bug(s) of '.$data->{bug_num}.': '.english_join([keys %added_blockers]) if keys %added_blockers;
	push @changed, 'removed blocking bug(s) of '.$data->{bug_num}.': '.english_join([keys %removed_blockers]) if keys %removed_blockers;
	$action = ucfirst(join ('; ',@changed)) if @changed;
	if (not @changed) {
	    print {$transcript} "Ignoring request to alter blocking bugs of bug #$data->{bug_num} to the same blocks previously set\n";
	    next;
	}
	$data->{blockedby} = join(' ',keys %blockers);
	append_action_to_log(bug => $data->{bug_num},
			     command  => 'block',
			     old_data => $old_data,
			     new_data => $data,
			     get_lock => 0,
			     __return_append_to_log_options(
							    %param,
							    action => $action,
							   ),
			    )
	    if not exists $param{append_log} or $param{append_log};
	writebug($data->{bug_num},$data);
	print {$transcript} "$action\n";
    }
    # we do this bit below to avoid code duplication
    my %mungable_blocks;
    $mungable_blocks{remove} = \%removed_blockers if keys %removed_blockers;
    $mungable_blocks{add} = \%added_blockers if keys %added_blockers;
    my $new_locks = 0;
    for my $add_remove (keys %mungable_blocks) {
	my %munge_blockers;
	for my $blocker (keys %{$mungable_blocks{$add_remove}}) {
	    next if $munge_blockers{$blocker};
	    my ($temp_locks, @blocking_data) =
		lock_read_all_merged_bugs(bug => $blocker,
					  ($param{archived}?(location => 'archive'):()),
					  exists $param{locks}?(locks => $param{locks}):(),
					 );
	    $locks+= $temp_locks;
	    $new_locks+=$temp_locks;
	    if (not @blocking_data) {
		for (1..$new_locks) {
		    unfilelock(exists $param{locks}?$param{locks}:());
		    $locks--;
		}
		die "Unable to get file lock while trying to $add_remove blocker '$blocker'";
	    }
	    for (map {$_->{bug_num}} @blocking_data) {
		$munge_blockers{$_} = 1;
	    }
	    for my $data (@blocking_data) {
		my $old_data = dclone($data);
		my %blocks;
		my @blocks = split ' ', $data->{blocks};
		@blocks{@blocks} = (1) x @blocks;
		@blocks = ();
		for my $bug (@bugs) {
		    if ($add_remove eq 'remove') {
			next unless exists $blocks{$bug};
			delete $blocks{$bug};
		    }
		    else {
			next if exists $blocks{$bug};
			$blocks{$bug} = 1;
		    }
		    push @blocks, $bug;
		}
		$data->{blocks} = join(' ',sort keys %blocks);
		my $action = ($add_remove eq 'add'?'Added':'Removed').
		    " indication that bug $data->{bug_num} blocks ".
		    join(',',@blocks);
		append_action_to_log(bug => $data->{bug_num},
				     command => 'block',
				     old_data => $old_data,
				     new_data => $data,
				     get_lock => 0,
				     __return_append_to_log_options(%param,
								   action => $action
								   )
				    );
		writebug($data->{bug_num},$data);
	    }
	    __handle_affected_packages(%param,data=>\@blocking_data);
	    add_recipients(recipients => $param{recipients},
			   actions_taken => {blocks => 1},
			   data       => \@blocking_data,
			   debug      => $debug,
			   transcript => $transcript,
			  );

	    for (1..$new_locks) {
		unfilelock(exists $param{locks}?$param{locks}:());
		$locks--;
	    }
	}
    }
    __end_control(%info);
}



=head2 set_tag

     eval {
	    set_tag(bug          => $ref,
		    transcript   => $transcript,
		    ($dl > 0 ? (debug => $transcript):()),
		    requester    => $header{from},
		    request_addr => $controlrequestaddr,
		    message      => \@log,
                    affected_packages => \%affected_packages,
		    recipients   => \%recipients,
		    tag          => [],
                    add          => 1,
                   );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to set tag on $ref: $@";
	}


Sets, adds, or removes the specified tags on a bug

=over

=item tag -- scalar or arrayref of tags to set, add or remove

=item add -- if true, add tags

=item remove -- if true, remove tags

=item warn_on_bad_tags -- if true (the default) warn if bad tags are
passed.

=back

=cut

sub set_tag {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 # specific options here
					 tag    => {type => SCALAR|ARRAYREF,
						    default => [],
						   },
					 add      => {type => BOOLEAN,
						      default => 0,
						     },
					 remove   => {type => BOOLEAN,
						      default => 0,
						     },
					 warn_on_bad_tags => {type => BOOLEAN,
							      default => 1,
							     },
					 %common_options,
					 %append_action_options,
					},
			     );
    if ($param{add} and $param{remove}) {
	croak "It's nonsensical to add and remove the same tags";
    }

    my %info =
	__begin_control(%param,
			command  => 'tag'
		       );
    my $transcript = $info{transcript};
    my @data = @{$info{data}};
    my @tags = make_list($param{tag});
    if (not @tags and ($param{remove} or $param{add})) {
	if ($param{remove}) {
	    print {$transcript} "Requested to remove no tags; doing nothing.\n";
	}
	else {
	    print {$transcript} "Requested to add no tags; doing nothing.\n";
	}
	__end_control(%info);
	return;
    }
    # first things first, make the versions fully qualified source
    # versions
    for my $data (@data) {
	my $action = 'Did not alter tags';
	my %tag_added = ();
	my %tag_removed = ();
	my @old_tags = split /\,?\s+/, $data->{keywords};
	my %tags;
	@tags{@old_tags} = (1) x @old_tags;
	my $old_data = dclone($data);
	if (not $param{add} and not $param{remove}) {
	    $tag_removed{$_} = 1 for @old_tags;
	    %tags = ();
	}
	my @bad_tags = ();
	for my $tag (@tags) {
	    if (not $param{remove} and
		not defined first {$_ eq $tag} @{$config{tags}}) {
		push @bad_tags, $tag;
		next;
	    }
	    if ($param{add}) {
		if (not exists $tags{$tag}) {
		    $tags{$tag} = 1;
		    $tag_added{$tag} = 1;
		}
	    }
	    elsif ($param{remove}) {
		if (exists $tags{$tag}) {
		    delete $tags{$tag};
		    $tag_removed{$tag} = 1;
		}
	    }
	    else {
		if (exists $tag_removed{$tag}) {
		    delete $tag_removed{$tag};
		}
		else {
		    $tag_added{$tag} = 1;
		}
		$tags{$tag} = 1;
	    }
	}
	if (@bad_tags and $param{warn_on_bad_tags}) {
	    print {$transcript} "Unknown tag(s): ".join(', ',@bad_tags).".\n";
	    print {$transcript} "These tags are recognized: ".join(', ',@{$config{tags}}).".\n";
	}
	$data->{keywords} = join(' ',keys %tags);

	my @changed;
	push @changed, 'added tag(s) '.english_join([keys %tag_added]) if keys %tag_added;
	push @changed, 'removed tag(s) '.english_join([keys %tag_removed]) if keys %tag_removed;
	$action = ucfirst(join ('; ',@changed)) if @changed;
	if (not @changed) {
	    print {$transcript} "Ignoring request to alter tags of bug #$data->{bug_num} to the same tags previously set\n";
	    next;
	}
	$action .= '.';
	append_action_to_log(bug => $data->{bug_num},
			     get_lock => 0,
			     command  => 'tag',
			     old_data => $old_data,
			     new_data => $data,
			     __return_append_to_log_options(
							    %param,
							    action => $action,
							   ),
			    )
	    if not exists $param{append_log} or $param{append_log};
	writebug($data->{bug_num},$data);
	print {$transcript} "$action\n";
    }
    __end_control(%info);
}



=head2 set_severity

     eval {
	    set_severity(bug          => $ref,
		         transcript   => $transcript,
		         ($dl > 0 ? (debug => $transcript):()),
		         requester    => $header{from},
		         request_addr => $controlrequestaddr,
		         message      => \@log,
                         affected_packages => \%affected_packages,
		         recipients   => \%recipients,
		         severity     => 'normal',
                        );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to set the severity of bug $ref: $@";
	}

Sets the severity of a bug. If severity is not passed, is undefined,
or has zero length, sets the severity to the default severity.

=cut

sub set_severity {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 # specific options here
					 severity => {type => SCALAR|UNDEF,
						      default => $config{default_severity},
						     },
					 %common_options,
					 %append_action_options,
					},
			     );
    if (not defined $param{severity} or
	not length $param{severity}
       ) {
	$param{severity} = $config{default_severity};
    }

    # check validity of new severity
    if (not defined first {$_ eq $param{severity}} (@{$config{severity_list}},$config{default_severity})) {
	die "Severity '$param{severity}' is not a valid severity level";
    }
    my %info =
	__begin_control(%param,
			command  => 'severity'
		       );
    my $transcript = $info{transcript};
    my @data = @{$info{data}};

    my $action = '';
    for my $data (@data) {
	if (not defined $data->{severity}) {
	    $data->{severity} = $param{severity};
	    $action = "Severity set to '$param{severity}'";
	}
	else {
	    if ($data->{severity} eq '') {
		$data->{severity} = $config{default_severity};
	    }
	    if ($data->{severity} eq $param{severity}) {
		print {$transcript} "Ignoring request to change severity of $config{bug} $data->{bug_num} to the same value.\n";
		next;
	    }
	    $action = "Severity set to '$param{severity}' from '$data->{severity}'";
	    $data->{severity} = $param{severity};
	}
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
    }
    __end_control(%info);
}


=head2 set_done

     eval {
	    set_done(bug          => $ref,
		     transcript   => $transcript,
		     ($dl > 0 ? (debug => $transcript):()),
		     requester    => $header{from},
		     request_addr => $controlrequestaddr,
		     message      => \@log,
                     affected_packages => \%affected_packages,
		     recipients   => \%recipients,
		    );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to set foo $ref bar: $@";
	}

Foo frobinates

=cut

sub set_done {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 reopen    => {type => BOOLEAN,
						       default => 0,
						      },
					 submitter => {type => SCALAR,
						       optional => 1,
						      },
					 clear_fixed => {type => BOOLEAN,
							 default => 1,
							},
					 notify_submitter => {type => BOOLEAN,
							      default => 1,
							     },
					 original_report => {type => SCALARREF,
							     optional => 1,
							    },
					 done => {type => SCALAR|UNDEF,
						  optional => 1,
						 },
					 %common_options,
					 %append_action_options,
					},
			     );

    if (exists $param{submitter} and
	not Mail::RFC822::Address::valid($param{submitter})) {
	die "New submitter address '$param{submitter}' is not a valid e-mail address";
    }
    if (exists $param{done} and defined $param{done} and $param{done} eq 1) { #special case this as using the requester address
	$param{done} = $param{requester};
    }
    if (exists $param{done} and
	(not defined $param{done} or
	 not length $param{done})) {
	delete $param{done};
	$param{reopen} = 1;
    }

    my %info =
	__begin_control(%param,
			command  => $param{reopen}?'reopen':'done',
		       );
    my $transcript = $info{transcript};
    my @data = @{$info{data}};
    my $action ='';

    if ($param{reopen}) {
	# avoid warning multiple times if there are fixed versions
	my $warn_fixed = 1;
	for my $data (@data) {
	    if (not exists $data->{done} or
		not defined $data->{done} or
		not length $data->{done}) {
		print {$transcript} "Bug $data->{bug_num} is not marked as done; doing nothing.\n";
		__end_control(%info);
		return;
	    }
	    if (@{$data->{fixed_versions}} and $warn_fixed) {
		print {$transcript} "'reopen' may be inappropriate when a bug has been closed with a version;\n";
		print {$transcript} "all fixed versions will be cleared, and you may need to re-add them.\n";
		$warn_fixed = 0;
	    }
	}
	$action = "Bug reopened";
	for my $data (@data) {
	    my $old_data = dclone($data);
	    $data->{done} = '';
	    append_action_to_log(bug => $data->{bug_num},
				 command => 'done',
				 new_data => $data,
				 old_data => $old_data,
				 get_lock => 0,
				 __return_append_to_log_options(
								%param,
								action => $action,
							       ),
				)
		if not exists $param{append_log} or $param{append_log};
	    writebug($data->{bug_num},$data);
	}
	print {$transcript} "$action\n";
	__end_control(%info);
	if (exists $param{submitter}) {
	    set_submitter(bug => $param{bug},
			  submitter => $param{submitter},
			  hash_slice(%param,
				     keys %common_options,
				     keys %append_action_options)
			 );
	}
	# clear the fixed revisions
	if ($param{clear_fixed}) {
	    set_fixed(fixed => [],
		      bug => $param{bug},
		      reopen => 0,
		      hash_slice(%param,
				 keys %common_options,
				 keys %append_action_options),
		     );
	}
    }
    else {
	my %submitter_notified;
	my $orig_report_set = 0;
	for my $data (@data) {
	    if (exists $data->{done} and
		defined $data->{done} and
		length $data->{done}) {
		print {$transcript} "Bug $data->{bug_num} is already marked as done; not doing anything.\n";
		__end_control(%info);
		return;
	    }
	}
	for my $data (@data) {
	    my $old_data = dclone($data);
	    my $hash = get_hashname($data->{bug_num});
	    my $report_fh = IO::File->new("$config{spool_dir}/db-h/$hash/$data->{bug_num}.report",'r') or
		die "Unable to open original report $config{spool_dir}/db-h/$hash/$data->{bug_num}.report for reading: $!";
	    my $orig_report;
	    {
		local $/;
		$orig_report= <$report_fh>;
	    }
	    close $report_fh;
	    if (not $orig_report_set and defined $orig_report and
		length $orig_report and
		exists $param{original_report}){
		${$param{original_report}} = $orig_report;
		$orig_report_set = 1;
	    }

	    $action = "Marked $config{bug} as done";

	    # set done to the requester
	    $data->{done} = exists $param{done}?$param{done}:$param{requester};
	    append_action_to_log(bug => $data->{bug_num},
				 command => 'done',
				 new_data => $data,
				 old_data => $old_data,
				 get_lock => 0,
				 __return_append_to_log_options(
								%param,
								action => $action,
							       ),
				)
		if not exists $param{append_log} or $param{append_log};
	    writebug($data->{bug_num},$data);
	    print {$transcript} "$action\n";
	    # get the original report
	    if ($param{notify_submitter}) {
		my $submitter_message;
		if(not exists $submitter_notified{$data->{originator}}) {
		    $submitter_message =
			create_mime_message([default_headers(queue_file => $param{request_nn},
							     data => $data,
							     msgid => $param{request_msgid},
							     msgtype => 'notifdone',
							     pr_msg  => 'they-closed',
							     headers =>
							     [To => $data->{submitter},
							      Subject => "$config{ubug}#$data->{bug_num} ".
							      "closed by $param{requester} ".(defined $param{request_subject}?"($param{request_subject})":""),
							     ],
							    )
					    ],
					    __message_body_template('mail/process_your_bug_done',
								    {data     => $data,
								     replyto  => (exists $param{request_replyto} ?
										  $param{request_replyto} :
										  $param{requester} || 'Unknown'),
								     markedby => $param{requester},
								     subject => $param{request_subject},
								     messageid => $param{request_msgid},
								     config   => \%config,
								    }),
					    [join('',make_list($param{message})),$orig_report]
					   );
		    send_mail_message(message => $submitter_message,
				      recipients => $old_data->{submitter},
				     );
		    $submitter_notified{$data->{originator}} = $submitter_message;
		}
		else {
		    $submitter_message = $submitter_notified{$data->{originator}};
		}
		append_action_to_log(bug => $data->{bug_num},
				     action => "Notification sent",
				     requester => '',
				     request_addr => $data->{originator},
				     desc => "$config{bug} acknowledged by developer.",
				     recips => [$data->{originator}],
				     message => $submitter_message,
				     get_lock => 0,
				    );
	    }
	}
	__end_control(%info);
	if (exists $param{fixed}) {
	    set_fixed(fixed => $param{fixed},
		      bug => $param{bug},
		      reopen => 0,
		      hash_slice(%param,
				 keys %common_options,
				 keys %append_action_options
				),
		     );
	}
    }
}


=head2 set_submitter

     eval {
	    set_submitter(bug          => $ref,
		          transcript   => $transcript,
		          ($dl > 0 ? (debug => $transcript):()),
		          requester    => $header{from},
		          request_addr => $controlrequestaddr,
		          message      => \@log,
                          affected_packages => \%affected_packages,
		          recipients   => \%recipients,
		          submitter    => $new_submitter,
                          notify_submitter => 1,
                          );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to set the forwarded-to-address of $ref: $@";
	}

Sets the submitter of a bug. If notify_submitter is true (the
default), notifies the old submitter of a bug on changes

=cut

sub set_submitter {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 # specific options here
					 submitter => {type => SCALAR,
						      },
					 notify_submitter => {type => BOOLEAN,
							      default => 1,
							     },
					 %common_options,
					 %append_action_options,
					},
			     );
    if (not Mail::RFC822::Address::valid($param{submitter})) {
	die "New submitter address $param{submitter} is not a valid e-mail address";
    }
    my %info =
	__begin_control(%param,
			command  => 'submitter'
		       );
    my ($debug,$transcript) =
	@info{qw(debug transcript)};
    my @data = @{$info{data}};
    my $action = '';
    # here we only concern ourselves with the first of the merged bugs
    for my $data ($data[0]) {
	my $notify_old_submitter = 0;
	my $old_data = dclone($data);
	print {$debug} "Going to change bug submitter\n";
	if (((not defined $param{submitter} or not length $param{submitter}) and
	      (not defined $data->{originator} or not length $data->{originator})) or
	     (defined $param{submitter} and defined $data->{originator} and
	      $param{submitter} eq $data->{originator})) {
	    print {$transcript} "Ignoring request to change the submitter of bug#$data->{bug_num} to the same value\n";
	    next;
	}
	else {
	    if (defined $data->{originator} and length($data->{originator})) {
		$action= "Changed $config{bug} submitter to '$param{submitter}' from '$data->{originator}'.";
		$notify_old_submitter = 1;
	    }
	    else {
		$action= "Set $config{bug} submitter to '$param{submitter}'.";
	    }
	    $data->{originator} = $param{submitter};
	}
        append_action_to_log(bug => $data->{bug_num},
			     command => 'submitter',
			     new_data => $data,
			     old_data => $old_data,
			     get_lock => 0,
			     __return_append_to_log_options(
							    %param,
							    action => $action,
							   ),
			    )
	    if not exists $param{append_log} or $param{append_log};
	writebug($data->{bug_num},$data);
	print {$transcript} "$action\n";
	# notify old submitter
	if ($notify_old_submitter and $param{notify_submitter}) {
	    send_mail_message(message =>
			      create_mime_message([default_headers(queue_file => $param{request_nn},
								   data => $data,
								   msgid => $param{request_msgid},
								   msgtype => 'ack',
								   pr_msg  => 'submitter-changed',
								   headers =>
								   [To => $old_data->{submitter},
								    Subject => "$config{ubug}#$data->{bug_num} submitter addressed changed ($param{request_subject})",
								   ],
								  )
						  ],
						  __message_body_template('mail/submitter_changed',
									  {old_data => $old_data,
									   data     => $data,
									   replyto  => exists $param{header}{'reply-to'} ? $param{request_replyto} : $param{requester} || 'Unknown',
									   config   => \%config,
									  })
						 ),
			      recipients => $old_data->{submitter},
			     );
	}
    }
    __end_control(%info);
}



=head2 set_forwarded

     eval {
	    set_forwarded(bug          => $ref,
		          transcript   => $transcript,
		          ($dl > 0 ? (debug => $transcript):()),
		          requester    => $header{from},
		          request_addr => $controlrequestaddr,
		          message      => \@log,
                          affected_packages => \%affected_packages,
		          recipients   => \%recipients,
		          forwarded    => $forward_to,
                          );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to set the forwarded-to-address of $ref: $@";
	}

Sets the location to which a bug is forwarded. Given an undef
forwarded, unsets forwarded.


=cut

sub set_forwarded {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 # specific options here
					 forwarded => {type => SCALAR|UNDEF,
						      },
					 %common_options,
					 %append_action_options,
					},
			     );
    if (defined $param{forwarded} and $param{forwarded} =~ /[^[:print:]]/) {
	die "Non-printable characters are not allowed in the forwarded field";
    }
    $param{forwarded} = undef if defined $param{forwarded} and not length $param{forwarded};
    my %info =
	__begin_control(%param,
			command  => 'forwarded'
		       );
    my ($debug,$transcript) =
	@info{qw(debug transcript)};
    my @data = @{$info{data}};
    my $action = '';
    for my $data (@data) {
	my $old_data = dclone($data);
	print {$debug} "Going to change bug forwarded\n";
	if (__all_undef_or_equal($param{forwarded},$data->{forwarded}) or
	    (not defined $param{forwarded} and
	     defined $data->{forwarded} and not length $data->{forwarded})) {
	    print {$transcript} "Ignoring request to change the forwarded-to-address of bug#$data->{bug_num} to the same value\n";
	    next;
	}
	else {
	    if (not defined $param{forwarded}) {
		$action= "Unset $config{bug} forwarded-to-address";
	    }
	    elsif (defined $data->{forwarded} and length($data->{forwarded})) {
		$action= "Changed $config{bug} forwarded-to-address to '$param{forwarded}' from '$data->{forwarded}'.";
	    }
	    else {
		$action= "Set $config{bug} forwarded-to-address to '$param{forwarded}'.";
	    }
	    $data->{forwarded} = $param{forwarded};
	}
        append_action_to_log(bug => $data->{bug_num},
			     command => 'forwarded',
			     new_data => $data,
			     old_data => $old_data,
			     get_lock => 0,
			     __return_append_to_log_options(
							    %param,
							    action => $action,
							   ),
			    )
	    if not exists $param{append_log} or $param{append_log};
	writebug($data->{bug_num},$data);
	print {$transcript} "$action\n";
    }
    __end_control(%info);
}




=head2 set_title

     eval {
	    set_title(bug          => $ref,
		      transcript   => $transcript,
		      ($dl > 0 ? (debug => $transcript):()),
		      requester    => $header{from},
		      request_addr => $controlrequestaddr,
		      message      => \@log,
                      affected_packages => \%affected_packages,
		      recipients   => \%recipients,
		      title        => $new_title,
                      );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to set the title of $ref: $@";
	}

Sets the title of a specific bug


=cut

sub set_title {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 # specific options here
					 title => {type => SCALAR,
						  },
					 %common_options,
					 %append_action_options,
					},
			     );
    if ($param{title} =~ /[^[:print:]]/) {
	die "Non-printable characters are not allowed in bug titles";
    }

    my %info = __begin_control(%param,
			       command  => 'title',
			      );
    my ($debug,$transcript) =
	@info{qw(debug transcript)};
    my @data = @{$info{data}};
    my $action = '';
    for my $data (@data) {
	my $old_data = dclone($data);
	print {$debug} "Going to change bug title\n";
	if (defined $data->{subject} and length($data->{subject}) and
	    $data->{subject} eq $param{title}) {
	    print {$transcript} "Ignoring request to change the title of bug#$data->{bug_num} to the same title\n";
	    next;
	}
	else {
	    if (defined $data->{subject} and length($data->{subject})) {
		$action= "Changed $config{bug} title to '$param{title}' from '$data->{subject}'.";
	    } else {
		$action= "Set $config{bug} title to '$param{title}'.";
	    }
	    $data->{subject} = $param{title};
	}
        append_action_to_log(bug => $data->{bug_num},
			     command => 'title',
			     new_data => $data,
			     old_data => $old_data,
			     get_lock => 0,
			     __return_append_to_log_options(
							    %param,
							    action => $action,
							   ),
			    )
	    if not exists $param{append_log} or $param{append_log};
	writebug($data->{bug_num},$data);
	print {$transcript} "$action\n";
    }
    __end_control(%info);
}


=head2 set_package

     eval {
	    set_package(bug          => $ref,
		        transcript   => $transcript,
		        ($dl > 0 ? (debug => $transcript):()),
		        requester    => $header{from},
		        request_addr => $controlrequestaddr,
		        message      => \@log,
                        affected_packages => \%affected_packages,
		        recipients   => \%recipients,
		        package      => $new_package,
                        is_source    => 0,
                       );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to assign or reassign $ref to a package: $@";
	}

Indicates that a bug is in a particular package. If is_source is true,
indicates that the package is a source package. [Internally, this
causes src: to be prepended to the package name.]

The default for is_source is 0. As a special case, if the package
starts with 'src:', it is assumed to be a source package and is_source
is overridden.

The package option must match the package_name_re regex.

=cut

sub set_package {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 # specific options here
					 package => {type => SCALAR|ARRAYREF,
						    },
					 is_source => {type => BOOLEAN,
						       default => 0,
						      },
					 %common_options,
					 %append_action_options,
					},
			     );
    my @new_packages = map {splitpackages($_)} make_list($param{package});
    if (grep {$_ !~ /^(?:src:|)$config{package_name_re}$/} @new_packages) {
	croak "Invalid package name '".
	    join(',',grep {$_ !~ /^(?:src:|)$config{package_name_re}$/} @new_packages).
		"'";
    }
    my %info = __begin_control(%param,
			       command  => 'package',
			      );
    my ($debug,$transcript) =
	@info{qw(debug transcript)};
    my @data = @{$info{data}};
    # clean up the new package
    my $new_package =
	join(',',
	     map {my $temp = $_;
		  ($temp =~ s/^src:// or
		   $param{is_source}) ? 'src:'.$temp:$temp;
	      } @new_packages);

    my $action = '';
    my $package_reassigned = 0;
    for my $data (@data) {
	my $old_data = dclone($data);
	print {$debug} "Going to change assigned package\n";
	if (defined $data->{package} and length($data->{package}) and
	    $data->{package} eq $new_package) {
	    print {$transcript} "Ignoring request to reassign bug #$data->{bug_num} to the same package\n";
	    next;
	}
	else {
	    if (defined $data->{package} and length($data->{package})) {
		$package_reassigned = 1;
		$action= "$config{bug} reassigned from package '$data->{package}'".
		    " to '$new_package'.";
	    } else {
		$action= "$config{bug} assigned to package '$new_package'.";
	    }
	    $data->{package} = $new_package;
	}
        append_action_to_log(bug => $data->{bug_num},
			     command => 'package',
			     new_data => $data,
			     old_data => $old_data,
			     get_lock => 0,
			     __return_append_to_log_options(
							    %param,
							    action => $action,
							   ),
			    )
	    if not exists $param{append_log} or $param{append_log};
	writebug($data->{bug_num},$data);
	print {$transcript} "$action\n";
    }
    __end_control(%info);
    # Only clear the fixed/found versions if the package has been
    # reassigned
    if ($package_reassigned) {
	my @params_for_found_fixed = 
	    map {exists $param{$_}?($_,$param{$_}):()}
		('bug',
		 keys %common_options,
		 keys %append_action_options,
		);
	set_found(found => [],
		  @params_for_found_fixed,
		 );
	set_fixed(fixed => [],
		  @params_for_found_fixed,
		 );
    }
}

=head2 set_found

     eval {
	    set_found(bug          => $ref,
		      transcript   => $transcript,
		      ($dl > 0 ? (debug => $transcript):()),
		      requester    => $header{from},
		      request_addr => $controlrequestaddr,
		      message      => \@log,
                      affected_packages => \%affected_packages,
		      recipients   => \%recipients,
		      found        => [],
                      add          => 1,
                     );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to set found on $ref: $@";
	}


Sets, adds, or removes the specified found versions of a package

If the version list is empty, and the bug is currently not "done",
causes the done field to be cleared.

If any of the versions added to found are greater than any version in
which the bug is fixed (or when the bug is found and there are no
fixed versions) the done field is cleared.

=cut

sub set_found {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 # specific options here
					 found    => {type => SCALAR|ARRAYREF,
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
	croak "It's nonsensical to add and remove the same versions";
    }

    my %info =
	__begin_control(%param,
			command  => 'found'
		       );
    my ($debug,$transcript) =
	@info{qw(debug transcript)};
    my @data = @{$info{data}};
    my %versions;
    for my $version (make_list($param{found})) {
	next unless defined $version;
	$versions{$version} =
	    [make_source_versions(package => [splitpackages($data[0]{package})],
				  warnings => $transcript,
				  debug    => $debug,
				  guess_source => 0,
				  versions     => $version,
				 )
	    ];
	# This is really ugly, but it's what we have to do
	if (not @{$versions{$version}}) {
	    print {$transcript} "Unable to make a source version for version '$version'\n";
	}
    }
    if (not keys %versions and ($param{remove} or $param{add})) {
	if ($param{remove}) {
	    print {$transcript} "Requested to remove no versions; doing nothing.\n";
	}
	else {
	    print {$transcript} "Requested to add no versions; doing nothing.\n";
	}
	__end_control(%info);
	return;
    }
    # first things first, make the versions fully qualified source
    # versions
    for my $data (@data) {
	# The 'done' field gets a bit weird with version tracking,
	# because a bug may be closed by multiple people in different
	# branches. Until we have something more flexible, we set it
	# every time a bug is fixed, and clear it when a bug is found
	# in a version greater than any version in which the bug is
	# fixed or when a bug is found and there is no fixed version
	my $action = 'Did not alter found versions';
	my %found_added = ();
	my %found_removed = ();
	my %fixed_removed = ();
	my $reopened = 0;
	my $old_data = dclone($data);
	if (not $param{add} and not $param{remove}) {
	    $found_removed{$_} = 1 for @{$data->{found_versions}};
	    $data->{found_versions} = [];
	}
	my %found_versions;
	@found_versions{@{$data->{found_versions}}} = (1) x @{$data->{found_versions}};
	my %fixed_versions;
	@fixed_versions{@{$data->{fixed_versions}}} = (1) x @{$data->{fixed_versions}};
	for my $version (keys %versions) {
	    if ($param{add}) {
		my @svers = @{$versions{$version}};
		if (not @svers) {
		    @svers = $version;
		}
		elsif (not grep {$version eq $_} @svers) {
                    # The $version was not equal to one of the source
                    # versions, so it's probably unqualified (or just
                    # wrong). Delete it, and use the source versions
                    # instead.
		    if (exists $found_versions{$version}) {
			delete $found_versions{$version};
			$found_removed{$version} = 1;
		    }
		}
		for my $sver (@svers) {
		    if (not exists $found_versions{$sver}) {
			$found_versions{$sver} = 1;
			$found_added{$sver} = 1;
		    }
		    # if the found we are adding matches any fixed
		    # versions, remove them
		    my @temp = grep m{(^|/)\Q$sver\E$}, keys %fixed_versions;
		    delete $fixed_versions{$_} for @temp;
		    $fixed_removed{$_} = 1 for @temp;
		}

		# We only care about reopening the bug if the bug is
		# not done
		if (defined $data->{done} and length $data->{done}) {
		    my @svers_order = sort_versions(map {m{([^/]+)$}; $1;}
						    @svers);
		    # determine if we need to reopen
		    my @fixed_order = sort_versions(map {m{([^/]+)$}; $1;}
						    keys %fixed_versions);
		    if (not @fixed_order or
			(Debbugs::Versions::Dpkg::vercmp($svers_order[-1],$fixed_order[-1]) >= 0)) {
			$reopened = 1;
			$data->{done} = '';
		    }
		}
	    }
	    elsif ($param{remove}) {
		# in the case of removal, we only concern ourself with
		# the version passed, not the source version it maps
		# to
		my @temp = grep m{(?:^|/)\Q$version\E$}, keys %found_versions;
		delete $found_versions{$_} for @temp;
		$found_removed{$_} = 1 for @temp;
	    }
	    else {
		# set the keys to exactly these values
		my @svers = @{$versions{$version}};
		if (not @svers) {
		    @svers = $version;
		}
		for my $sver (@svers) {
		    if (not exists $found_versions{$sver}) {
			$found_versions{$sver} = 1;
			if (exists $found_removed{$sver}) {
			    delete $found_removed{$sver};
			}
			else {
			    $found_added{$sver} = 1;
			}
		    }
		}
	    }
	}

	$data->{found_versions} = [keys %found_versions];
	$data->{fixed_versions} = [keys %fixed_versions];

	my @changed;
	push @changed, 'marked as found in versions '.english_join([keys %found_added]) if keys %found_added;
	push @changed, 'no longer marked as found in versions '.english_join([keys %found_removed]) if keys %found_removed;
#	push @changed, 'marked as fixed in versions '.english_join([keys %fixed_addded]) if keys %fixed_added;
	push @changed, 'no longer marked as fixed in versions '.english_join([keys %fixed_removed]) if keys %fixed_removed;
	$action = ucfirst(join ('; ',@changed)) if @changed;
	if ($reopened) {
	    $action .= " and reopened"
	}
	if (not $reopened and not @changed) {
	    print {$transcript} "Ignoring request to alter found versions of bug #$data->{bug_num} to the same values previously set\n";
	    next;
	}
	$action .= '.';
	append_action_to_log(bug => $data->{bug_num},
			     get_lock => 0,
			     command  => 'found',
			     old_data => $old_data,
			     new_data => $data,
			     __return_append_to_log_options(
							    %param,
							    action => $action,
							   ),
			    )
	    if not exists $param{append_log} or $param{append_log};
	writebug($data->{bug_num},$data);
	print {$transcript} "$action\n";
    }
    __end_control(%info);
}

=head2 set_fixed

     eval {
	    set_fixed(bug          => $ref,
		      transcript   => $transcript,
		      ($dl > 0 ? (debug => $transcript):()),
		      requester    => $header{from},
		      request_addr => $controlrequestaddr,
		      message      => \@log,
                      affected_packages => \%affected_packages,
		      recipients   => \%recipients,
		      fixed        => [],
                      add          => 1,
                      reopen       => 0,
                     );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to set fixed on $ref: $@";
	}


Sets, adds, or removes the specified fixed versions of a package

If the fixed versions are empty (or end up being empty after this
call) or the greatest fixed version is less than the greatest found
version and the reopen option is true, the bug is reopened.

This function is also called by the reopen function, which causes all
of the fixed versions to be cleared.

=cut

sub set_fixed {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 # specific options here
					 fixed    => {type => SCALAR|ARRAYREF,
						      default => [],
						     },
					 add      => {type => BOOLEAN,
						      default => 0,
						     },
					 remove   => {type => BOOLEAN,
						      default => 0,
						     },
					 reopen   => {type => BOOLEAN,
						      default => 0,
						     },
					 %common_options,
					 %append_action_options,
					},
			     );
    if ($param{add} and $param{remove}) {
	croak "It's nonsensical to add and remove the same versions";
    }
    my %info =
	__begin_control(%param,
			command  => 'fixed'
		       );
    my ($debug,$transcript) =
	@info{qw(debug transcript)};
    my @data = @{$info{data}};
    my %versions;
    for my $version (make_list($param{fixed})) {
	next unless defined $version;
	$versions{$version} =
	    [make_source_versions(package => [splitpackages($data[0]{package})],
				  warnings => $transcript,
				  debug    => $debug,
				  guess_source => 0,
				  versions     => $version,
				 )
	    ];
	# This is really ugly, but it's what we have to do
	if (not @{$versions{$version}}) {
	    print {$transcript} "Unable to make a source version for version '$version'\n";
	}
    }
    if (not keys %versions and ($param{remove} or $param{add})) {
	if ($param{remove}) {
	    print {$transcript} "Requested to remove no versions; doing nothing.\n";
	}
	else {
	    print {$transcript} "Requested to add no versions; doing nothing.\n";
	}
	__end_control(%info);
	return;
    }
    # first things first, make the versions fully qualified source
    # versions
    for my $data (@data) {
	my $old_data = dclone($data);
	# The 'done' field gets a bit weird with version tracking,
	# because a bug may be closed by multiple people in different
	# branches. Until we have something more flexible, we set it
	# every time a bug is fixed, and clear it when a bug is found
	# in a version greater than any version in which the bug is
	# fixed or when a bug is found and there is no fixed version
	my $action = 'Did not alter fixed versions';
	my %found_added = ();
	my %found_removed = ();
	my %fixed_added = ();
	my %fixed_removed = ();
	my $reopened = 0;
	if (not $param{add} and not $param{remove}) {
	    $fixed_removed{$_} = 1 for @{$data->{fixed_versions}};
	    $data->{fixed_versions} = [];
	}
	my %found_versions;
	@found_versions{@{$data->{found_versions}||[]}} = (1) x @{$data->{found_versions}||[]};
	my %fixed_versions;
	@fixed_versions{@{$data->{fixed_versions}||[]}} = (1) x @{$data->{fixed_versions}||[]};
	for my $version (keys %versions) {
	    if ($param{add}) {
		my @svers = @{$versions{$version}};
		if (not @svers) {
		    @svers = $version;
		}
		else {
		    if (exists $fixed_versions{$version}) {
			$fixed_removed{$version} = 1;
			delete $fixed_versions{$version};
		    }
		}
		for my $sver (@svers) {
		    if (not exists $fixed_versions{$sver}) {
			$fixed_versions{$sver} = 1;
			$fixed_added{$sver} = 1;
		    }
		}
	    }
	    elsif ($param{remove}) {
		# in the case of removal, we only concern ourself with
		# the version passed, not the source version it maps
		# to
		my @temp = grep m{(?:^|\/)\Q$version\E$}, keys %fixed_versions;
		delete $fixed_versions{$_} for @temp;
		$fixed_removed{$_} = 1 for @temp;
	    }
	    else {
		# set the keys to exactly these values
		my @svers = @{$versions{$version}};
		if (not @svers) {
		    @svers = $version;
		}
		for my $sver (@svers) {
		    if (not exists $fixed_versions{$sver}) {
			$fixed_versions{$sver} = 1;
			if (exists $fixed_removed{$sver}) {
			    delete $fixed_removed{$sver};
			}
			else {
			    $fixed_added{$sver} = 1;
			}
		    }
		}
	    }
	}

	$data->{found_versions} = [keys %found_versions];
	$data->{fixed_versions} = [keys %fixed_versions];

	# If we're supposed to consider reopening, reopen if the
	# fixed versions are empty or the greatest found version
	# is greater than the greatest fixed version
	if ($param{reopen} and defined $data->{done}
	    and length $data->{done}) {
	    my @svers_order = sort {Debbugs::Versions::Dpkg::vercmp($a,$b);}
		map {m{([^/]+)$}; $1;} @{$data->{found_versions}};
	    # determine if we need to reopen
	    my @fixed_order = sort {Debbugs::Versions::Dpkg::vercmp($a,$b);}
		    map {m{([^/]+)$}; $1;} @{$data->{fixed_versions}};
	    if (not @fixed_order or
		(Debbugs::Versions::Dpkg::vercmp($svers_order[-1],$fixed_order[-1]) >= 0)) {
		$reopened = 1;
		$data->{done} = '';
	    }
	}

	my @changed;
	push @changed, 'marked as found in versions '.english_join([keys %found_added]) if keys %found_added;
	push @changed, 'no longer marked as found in versions '.english_join([keys %found_removed]) if keys %found_removed;
	push @changed, 'marked as fixed in versions '.english_join([keys %fixed_added]) if keys %fixed_added;
	push @changed, 'no longer marked as fixed in versions '.english_join([keys %fixed_removed]) if keys %fixed_removed;
	$action = ucfirst(join ('; ',@changed)) if @changed;
	if ($reopened) {
	    $action .= " and reopened"
	}
	if (not $reopened and not @changed) {
	    print {$transcript} "Ignoring request to alter fixed versions of bug #$data->{bug_num} to the same values previously set\n";
	    next;
	}
	$action .= '.';
	append_action_to_log(bug => $data->{bug_num},
			     command  => 'fixed',
			     new_data => $data,
			     old_data => $old_data,
			     get_lock => 0,
			     __return_append_to_log_options(
							    %param,
							    action => $action,
							   ),
			    )
	    if not exists $param{append_log} or $param{append_log};
	writebug($data->{bug_num},$data);
	print {$transcript} "$action\n";
    }
    __end_control(%info);
}


=head2 set_merged

     eval {
	    set_merged(bug          => $ref,
		       transcript   => $transcript,
		       ($dl > 0 ? (debug => $transcript):()),
		       requester    => $header{from},
		       request_addr => $controlrequestaddr,
		       message      => \@log,
                       affected_packages => \%affected_packages,
		       recipients   => \%recipients,
		       merge_with   => 12345,
                       add          => 1,
                       force        => 1,
                       allow_reassign => 1,
                       reassign_same_source_only => 1,
                      );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to set merged on $ref: $@";
	}


Sets, adds, or removes the specified merged bugs of a bug

By default, requires

=cut

sub set_merged {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 # specific options here
					 merge_with => {type => ARRAYREF|SCALAR,
							optional => 1,
						       },
					 remove   => {type => BOOLEAN,
						      default => 0,
						     },
					 force    => {type => BOOLEAN,
						      default => 0,
						     },
					 masterbug => {type => BOOLEAN,
						       default => 0,
						      },
					 allow_reassign => {type => BOOLEAN,
							    default => 0,
							   },
					 reassign_different_sources => {type => BOOLEAN,
									default => 1,
								       },
					 %common_options,
					 %append_action_options,
					},
			     );
    my @merging = exists $param{merge_with} ? make_list($param{merge_with}):();
    my %merging;
    @merging{@merging} = (1) x @merging;
    if (grep {$_ !~ /^\d+$/} @merging) {
	croak "Requested to merge with a non-numeric bug: ".join(',',map {qq('$_');} @merging);
    }
    $param{locks} = {} if not exists $param{locks};
    my %info =
	__begin_control(%param,
			command  => 'merge'
		       );
    my ($debug,$transcript) =
	@info{qw(debug transcript)};
    if (not @merging and exists $param{merge_with}) {
	print {$transcript} "Requested to merge with no additional bugs; not doing anything\n";
	__end_control(%info);
	return;
    }
    my @data = @{$info{data}};
    my %data;
    my %merged_bugs;
    for my $data (@data) {
	$data{$data->{bug_num}} = $data;
	my @merged_bugs = split / /, $data->{mergedwith};
	@merged_bugs{@merged_bugs} = (1) x @merged_bugs;
    }
    # handle unmerging
    my $new_locks = 0;
    if (not exists $param{merge_with}) {
	delete $merged_bugs{$param{bug}};
	if (not keys %merged_bugs) {
	    print {$transcript} "Ignoring request to unmerge a bug which is not merged with any others.\n";
	    __end_control(%info);
	    return;
	}
	my $action = "Disconnected #$param{bug} from all other report(s).";
	for my $data (@data) {
	    my $old_data = dclone($data);
	    if ($data->{bug_num} == $param{bug}) {
		$data->{mergedwith} = '';
	    }
	    else {
		$data->{mergedwith} = join(' ',sort grep {$_ != $data->{bug_num}}
					    keys %merged_bugs);
	    }
	    append_action_to_log(bug => $data->{bug_num},
				 command  => 'merge',
				 new_data => $data,
				 old_data => $old_data,
				 get_lock => 0,
				 __return_append_to_log_options(%param,
								action => $action,
							       ),
				)
		if not exists $param{append_log} or $param{append_log};
	    writebug($data->{bug_num},$data);
	}
	print {$transcript} "$action\n";
	__end_control(%info);
	return;
    }
    # lock and load all of the bugs we need
    my ($data,$n_locks) =
	__lock_and_load_merged_bugs(bugs_to_load => [keys %merging],
				    data => \@data,
				    locks => $param{locks},
				    debug => $debug,
				   );
    $new_locks += $n_locks;
    %data = %{$data};
    @data = values %data;
    if (not check_limit(data => [@data],
			  exists $param{limit}?(limit => $param{limit}):(),
			  transcript => $transcript,
			 )) {
	die "limit failed for bugs: ".join(', ',map {$_->{bug_num}} @data);
    }
    for my $data (@data) {
	$data{$data->{bug_num}} = $data;
	$merged_bugs{$data->{bug_num}} = 1;
	my @merged_bugs = split / /, $data->{mergedwith};
	@merged_bugs{@merged_bugs} = (1) x @merged_bugs;
	if (exists $param{affected_bugs}) {
	    $param{affected_bugs}{$data->{bug_num}} = 1;
	}
    }
    __handle_affected_packages(%param,data => [@data]);
    my %bug_info_shown; # which bugs have had information shown
    $bug_info_shown{$param{bug}} = 1;
    add_recipients(data => [@data],
		   recipients => $param{recipients},
		   (exists $param{command}?(actions_taken => {$param{command} => 1}):()),
		   debug      => $debug,
		   (__internal_request()?(transcript => $transcript):()),
		  );

    # Figure out what the ideal state is for the bug, 
    my ($merge_status,$bugs_to_merge) =
	__calculate_merge_status(\@data,\%data,$param{bug});
    # find out if we actually have any bugs to merge
    if (not $bugs_to_merge) {
	print {$transcript} "Requested to merge with no additional bugs; not doing anything\n";
	for (1..$new_locks) {
	    unfilelock($param{locks});
	    $locks--;
	}
	__end_control(%info);
	return;
    }
    # see what changes need to be made to merge the bugs
    # check to make sure that the set of changes we need to make is allowed
    my ($disallowed_changes,$changes) = 
	__calculate_merge_changes(\@data,$merge_status,\%param);
    # at this point, stop if there are disallowed changes, otherwise
    # make the allowed changes, and then reread the bugs in question
    # to get the new data, then recaculate the merges; repeat
    # reloading and recalculating until we try too many times or there
    # are no changes to make.

    my $attempts = 0;
    # we will allow at most 4 times through this; more than 1
    # shouldn't really happen.
    my %bug_changed;
    while ($attempts < 4 and (@{$disallowed_changes} or keys %{$changes})) {
	if ($attempts > 1) {
	    print {$transcript} "Unable to complete merge on previous attempt; trying again (retry: $attempts)\n";
	}
	if (@{$disallowed_changes}) {
	    # figure out the problems
	    print {$transcript} "Unable to merge bugs because:\n";
	    for my $change (@{$disallowed_changes}) {
		print {$transcript} "$change->{field} of #$change->{bug} is '$change->{text_orig_value}' not '$change->{text_value}'\n";
	    }
	    if ($attempts > 0) {
		croak "Some bugs were altered while attempting to merge";
	    }
	    else {
		croak "Did not alter merged bugs";
	    }
	}
	my @bugs_to_change = keys %{$changes};
	for my $change_bug (@bugs_to_change) {
	    next unless exists $changes->{$change_bug};
	    $bug_changed{$change_bug}++;
	    print {$transcript} __bug_info($data{$change_bug}) if
		$param{show_bug_info} and not __internal_request(1);
	    $bug_info_shown{$change_bug} = 1;
	    __allow_relocking($param{locks},[keys %data]);
	    for my $change (@{$changes->{$change_bug}}) {
		if ($change->{field} eq 'blockedby' or $change->{field} eq 'blocks') {
		    my %target_blockedby;
		    @target_blockedby{@{$change->{func_value}}} = (1) x @{$change->{func_value}};
		    my %unhandled_targets = %target_blockedby;
		    for my $key (split / /,$change->{orig_value}) {
			delete $unhandled_targets{$key};
			next if exists $target_blockedby{$key};
			set_blocks(bug    => $change->{field} eq 'blocks' ? $key : $change->{bug},
				   block  => $change->{field} eq 'blocks' ? $change->{bug} : $key,
				   remove => 1,
				   hash_slice(%param,
					      keys %common_options,
					      keys %append_action_options),
				  );
		    }
		    for my $key (keys %unhandled_targets) {
			set_blocks(bug    => $change->{field} eq 'blocks' ? $key : $change->{bug},
				   block  => $change->{field} eq 'blocks' ? $change->{bug} : $key,
				   add   => 1,
				   hash_slice(%param,
					      keys %common_options,
					      keys %append_action_options),
				  );
		    }
		}
		else {
		    $change->{function}->(bug => $change->{bug},
					  $change->{key}, $change->{func_value},
					  exists $change->{options}?@{$change->{options}}:(),
					  hash_slice(%param,
						     keys %common_options,
						     keys %append_action_options),
					 );
		}
	    }
	    __disallow_relocking($param{locks});
	    my ($data,$n_locks) =
		__lock_and_load_merged_bugs(bugs_to_load => [keys %merging],
					    data => \@data,
					    locks => $param{locks},
					    debug => $debug,
					    reload_all => 1,
					   );
	    $new_locks += $n_locks;
	    $locks += $n_locks;
	    %data = %{$data};
	    @data = values %data;
	    ($merge_status,$bugs_to_merge) =
		__calculate_merge_status(\@data,\%data,$param{bug},$merge_status);
	    ($disallowed_changes,$changes) = 
		__calculate_merge_changes(\@data,$merge_status,\%param);
	    $attempts = max(values %bug_changed);
	}
    }
    if ($param{show_bug_info} and not __internal_request(1)) {
     	for my $data (sort {$a->{bug_num} <=> $b->{bug_num}} @data) {
     	    next if $bug_info_shown{$data->{bug_num}};
	    print {$transcript} __bug_info($data);
	}
    }
    if (keys %{$changes} or @{$disallowed_changes}) {
	print {$transcript} "After four attempts, the following changes were unable to be made:\n";
	for (1..$new_locks) {
	    unfilelock($param{locks});
	    $locks--;
	}
	__end_control(%info);
	for my $change ((map {@{$_}} values %{$changes}), @{$disallowed_changes}) {
	    print {$transcript} "$change->{field} of #$change->{bug} is '$change->{text_orig_value}' not '$change->{text_value}'\n";
	}
	die "Unable to modify bugs so they could be merged";
	return;
    }

    # finally, we can merge the bugs
    my $action = "Merged ".join(' ',sort keys %merged_bugs);
    for my $data (@data) {
	my $old_data = dclone($data);
	$data->{mergedwith} = join(' ',sort grep {$_ != $data->{bug_num}}
				    keys %merged_bugs);
	append_action_to_log(bug => $data->{bug_num},
			     command  => 'merge',
			     new_data => $data,
			     old_data => $old_data,
			     get_lock => 0,
			     __return_append_to_log_options(%param,
							    action => $action,
							   ),
			    )
	    if not exists $param{append_log} or $param{append_log};
	writebug($data->{bug_num},$data);
    }
    print {$transcript} "$action\n";
    # unlock the extra locks that we got earlier
    for (1..$new_locks) {
	unfilelock($param{locks});
	$locks--;
    }
    __end_control(%info);
}

sub __allow_relocking{
    my ($locks,$bugs) = @_;

    my @locks = (@{$bugs},'merge');
    for my $lock (@locks) {
	my @lockfiles = grep {m{/\Q$lock\E$}} keys %{$locks->{locks}};
	next unless @lockfiles;
	$locks->{relockable}{$lockfiles[0]} = 0;
    }
}

sub __disallow_relocking{
    my ($locks) = @_;
    delete $locks->{relockable};
}

sub __lock_and_load_merged_bugs{
    my %param =
	validate_with(params => \@_,
		      spec =>
		      {bugs_to_load => {type => ARRAYREF,
					default => sub {[]},
				       },
		       data         => {type => HASHREF|ARRAYREF,
				       },
		       locks        => {type => HASHREF,
				        default => sub {{};},
				       },
		       reload_all => {type => BOOLEAN,
				      default => 0,
				     },
		       debug           => {type => HANDLE,
					  },
		      },
		     );
    my %data;
    my $new_locks = 0;
    if (ref($param{data}) eq 'ARRAY') {
	for my $data (@{$param{data}}) {
	    $data{$data->{bug_num}} = dclone($data);
	}
    }
    else {
	%data = %{dclone($param{data})};
    }
    my @bugs_to_load = @{$param{bugs_to_load}};
    if ($param{reload_all}) {
	push @bugs_to_load, keys %data;
    }
    my %temp;
    @temp{@bugs_to_load} = (1) x @bugs_to_load;
    @bugs_to_load = keys %temp;
    my %loaded_this_time;
    my $bug_to_load;
    while ($bug_to_load = shift @bugs_to_load) {
	if (not $param{reload_all}) {
	    next if exists $data{$bug_to_load};
	}
	else {
	    next if $loaded_this_time{$bug_to_load};
	}
	my $lock_bug = 1;
	if ($param{reload_all}) {
	    if (exists $data{$bug_to_load}) {
		$lock_bug = 0;
	    }
	}
	my $data =
	    read_bug(bug => $bug_to_load,
		     lock => $lock_bug,
		     locks => $param{locks},
		    ) or
			die "Unable to load bug $bug_to_load";
	print {$param{debug}} "read bug $bug_to_load\n";
	$data{$data->{bug_num}} = $data;
	$new_locks += $lock_bug;
	$loaded_this_time{$data->{bug_num}} = 1;
	push @bugs_to_load,
	    grep {not exists $data{$_}}
		split / /,$data->{mergedwith};
    }
    return (\%data,$new_locks);
}


sub __calculate_merge_status{
    my ($data_a,$data_h,$master_bug,$merge_status) = @_;
    my %merge_status = %{$merge_status // {}};
    my %merged_bugs;
    my $bugs_to_merge = 0;
    for my $data (@{$data_a}) {
	# check to see if this bug is unmerged in the set
	if (not length $data->{mergedwith} or
	    grep {not exists $merged_bugs{$_}} split / /,$data->{mergedwith}) {
	    $merged_bugs{$data->{bug_num}} = 1;
	    $bugs_to_merge = 1;
	}
	# the master_bug is the bug that every other bug is made to
	# look like. However, if merge is set, tags, fixed and found
	# are merged.
	if ($data->{bug_num} == $master_bug) {
	    for (qw(package forwarded severity blocks blockedby done owner summary outlook affects)) {
		$merge_status{$_} = $data->{$_}
	    }
	}
 	if (defined $merge_status) {
 	    next unless $data->{bug_num} == $master_bug;
 	}
	$merge_status{tag} = {} if not exists $merge_status{tag};
	for my $tag (split /\s+/, $data->{keywords}) {
	    $merge_status{tag}{$tag} = 1;
	}
	$merge_status{keywords} = join(' ',sort keys %{$merge_status{tag}});
	for (qw(fixed found)) {
	    @{$merge_status{"${_}_versions"}}{@{$data->{"${_}_versions"}}} = (1) x @{$data->{"${_}_versions"}};
	}
    }
    # if there is a non-source qualified version with a corresponding
    # source qualified version, we only want to merge the source
    # qualified version(s)
    for (qw(fixed found)) {
	my @unqualified_versions = grep {m{/}?0:1} keys %{$merge_status{"${_}_versions"}};
	for my $unqualified_version (@unqualified_versions) {
	    if (grep {m{/\Q$unqualified_version\E}} keys %{$merge_status{"${_}_versions"}}) {
		delete $merge_status{"${_}_versions"}{$unqualified_version};
	    }
	}
    }
    return (\%merge_status,$bugs_to_merge);
}



sub __calculate_merge_changes{
    my ($datas,$merge_status,$param) = @_;
    my %changes;
    my @disallowed_changes;
    for my $data (@{$datas}) {
	# things that can be forced
	#
	# * func is the function to set the new value
	#
	# * key is the key of the function to set the value,

	# * modify_value is a function which is called to modify the new
	# value so that the function will accept it

        # * options is an ARRAYREF of options to pass to the function

	# * allowed is a BOOLEAN which controls whether this setting
	# is allowed to be different by default.
	my %force_functions =
	    (forwarded => {func => \&set_forwarded,
			   key  => 'forwarded',
			   options => [],
			  },
	     severity  => {func => \&set_severity,
			   key  => 'severity',
			   options => [],
			  },
	     blocks    => {func => \&set_blocks,
			   modify_value => sub {defined $_[0]?[split ' ',$_[0]]:[]},
			   key  => 'block',
			   options => [],
			  },
	     blockedby => {func => \&set_blocks,
			   modify_value => sub {defined $_[0]?[split ' ',$_[0]]:[]},
			   key  => 'block',
			   options => [],
			  },
	     done      => {func => \&set_done,
			   key  => 'done',
			   options => [],
			  },
	     owner     => {func => \&owner,
			   key  => 'owner',
			   options => [],
			  },
	     summary   => {func => \&summary,
			   key  => 'summary',
			   options => [],
			  },
	     outlook   => {func => \&outlook,
			   key  => 'outlook',
			   options => [],
			  },
	     affects   => {func => \&affects,
			   key  => 'package',
			   options => [],
			  },
	     package   => {func => \&set_package,
			   key  => 'package',
			   options => [],
			  },
	     keywords   => {func => \&set_tag,
			    key  => 'tag',
			    modify_value => sub {defined $_[0]?[sort split /\s+/,$_[0]]:[]},
			    allowed => 1,
			   },
	     fixed_versions => {func => \&set_fixed,
				key => 'fixed',
				modify_value => sub {(defined $_[0] and ref($_[0]) eq 'HASH')?[sort keys %{$_[0]}]:$_[0]},
				allowed => 1,
			       },
	     found_versions => {func => \&set_found,
				key   => 'found',
				modify_value => sub {(defined $_[0] and ref($_[0]) eq 'HASH')?[sort keys %{$_[0]}]:$_[0]},
				allowed => 1,
			       },
	    );
	for my $field (qw(forwarded severity blocks blockedby done owner summary outlook affects package fixed_versions found_versions keywords)) {
	    # if the ideal bug already has the field set properly, we
	    # continue on.
	    if ($field eq 'keywords'){
		next if join(' ',sort split /\s+/,$data->{keywords}) eq
		    join(' ',sort keys %{$merge_status->{tag}});
	    }
	    elsif ($field =~ /^(?:fixed|found)_versions$/) {
		next if join(' ', sort @{$data->{$field}}) eq
		    join(' ',sort keys %{$merge_status->{$field}});
	    }
	    elsif ($field eq 'done') {
		# for done, we only care if the bug is done or not
		# done, not the value it's set to.
		if (defined $merge_status->{$field} and length $merge_status->{$field} and
		    defined $data->{$field}         and length $data->{$field}) {
		    next;
		}
		elsif ((not defined $merge_status->{$field} or not length $merge_status->{$field}) and
		       (not defined $data->{$field}         or not length $data->{$field})
		      ) {
		    next;
		}
	    }
	    elsif ($merge_status->{$field} eq $data->{$field}) {
		next;
	    }
	    my $change =
		{field => $field,
		 bug => $data->{bug_num},
		 orig_value => $data->{$field},
		 func_value   =>
		 (exists $force_functions{$field}{modify_value} ?
		  $force_functions{$field}{modify_value}->($merge_status->{$field}):
		  $merge_status->{$field}),
		 value    => $merge_status->{$field},
		 function => $force_functions{$field}{func},
		 key      => $force_functions{$field}{key},
		 options  => $force_functions{$field}{options},
		 allowed  => exists $force_functions{$field}{allowed} ? $force_functions{$field}{allowed} : 0,
		};
	    $change->{text_value} = ref($change->{func_value}) eq 'ARRAY'?join(' ',@{$change->{func_value}}):$change->{func_value};
	    $change->{text_orig_value} = ref($change->{orig_value}) eq 'ARRAY'?join(' ',@{$change->{orig_value}}):$change->{orig_value};
	    if ($param->{force} or $change->{allowed}) {
		if ($field ne 'package' or $change->{allowed}) {
		    push @{$changes{$data->{bug_num}}},$change;
		    next;
		}
		if ($param->{allow_reassign}) {
		    if ($param->{reassign_different_sources}) {
			push @{$changes{$data->{bug_num}}},$change;
			next;
		    }
		    # allow reassigning if binary_to_source returns at
		    # least one of the same source packages
		    my @merge_status_source =
			binary_to_source(package => $merge_status->{package},
					 source_only => 1,
					);
		    my @other_bug_source =
			binary_to_source(package => $data->{package},
					 source_only => 1,
					);
		    my %merge_status_sources;
		    @merge_status_sources{@merge_status_source} =
			(1) x @merge_status_source;
		    if (grep {$merge_status_sources{$_}} @other_bug_source) {
			push @{$changes{$data->{bug_num}}},$change;
			next;
		    }
		}
	    }
	    push @disallowed_changes,$change;
	}
	# blocks and blocked by are weird; we have to go through and
	# set blocks to the other half of the merged bugs
    }
    return (\@disallowed_changes,\%changes);
}

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
					 package => {type => SCALAR|ARRAYREF|UNDEF,
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
    if (not defined $param{package}) {
	$param{package} = [];
    }
    my %info =
	__begin_control(%param,
			command  => 'affects'
		       );
    my ($debug,$transcript) =
	@info{qw(debug transcript)};
    my @data = @{$info{data}};
    my $action = '';
    for my $data (@data) {
	$action = '';
	 print {$debug} "Going to change affects\n";
	 my @packages = splitpackages($data->{affects});
	 my %packages;
	 @packages{@packages} = (1) x @packages;
	 if ($param{add}) {
	      my @added = ();
	      for my $package (make_list($param{package})) {
		  next unless defined $package and length $package;
		  if (not $packages{$package}) {
		      $packages{$package} = 1;
		      push @added,$package;
		  }
	      }
	      if (@added) {
		   $action = "Added indication that $data->{bug_num} affects ".
			english_join(\@added);
	      }
	 }
	 elsif ($param{remove}) {
	      my @removed = ();
	      for my $package (make_list($param{package})) {
		   if ($packages{$package}) {
		       next unless defined $package and length $package;
			delete $packages{$package};
			push @removed,$package;
		   }
	      }
	      $action = "Removed indication that $data->{bug_num} affects " .
		   english_join(\@removed);
	 }
	 else {
	      my %added_packages = ();
	      my %removed_packages = %packages;
	      %packages = ();
	      for my $package (make_list($param{package})) {
		   next unless defined $package and length $package;
		   $packages{$package} = 1;
		   delete $removed_packages{$package};
		   $added_packages{$package} = 1;
	      }
	      if (keys %removed_packages) {
		  $action = "Removed indication that $data->{bug_num} affects ".
		      english_join([keys %removed_packages]);
		  $action .= "\n" if keys %added_packages;
	      }
	      if (keys %added_packages) {
		  $action .= "Added indication that $data->{bug_num} affects " .
		   english_join([keys %added_packages]);
	      }
	 }
	if (not length $action) {
	    print {$transcript} "Ignoring request to set affects of bug $data->{bug_num} to the same value previously set\n";
	    next;
	}
	 my $old_data = dclone($data);
	 $data->{affects} = join(',',keys %packages);
	 append_action_to_log(bug => $data->{bug_num},
			      get_lock => 0,
			      command => 'affects',
			      new_data => $data,
			      old_data => $old_data,
			      __return_append_to_log_options(
							     %param,
							     action => $action,
							    ),
			     )
	       if not exists $param{append_log} or $param{append_log};
	  writebug($data->{bug_num},$data);
	  print {$transcript} "$action\n";
     }
    __end_control(%info);
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

If summary is 0 or -1, sets the summary to the first paragraph contained in
the message passed.

If summary is a positive integer, sets the summary to the message specified.

Otherwise, sets summary to the value passed.

=cut


sub summary {
    # outlook and summary are exactly the same, basically
    return _summary('summary',@_);
}

=head1 OUTLOOK FUNCTIONS

=head2 outlook

     eval {
	    outlook(bug          => $ref,
		    transcript   => $transcript,
		    ($dl > 0 ? (debug => $transcript):()),
		    requester    => $header{from},
		    request_addr => $controlrequestaddr,
		    message      => \@log,
                    affected_packages => \%affected_packages,
		    recipients   => \%recipients,
		    outlook      => undef,
                   );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to mark $ref with outlook foo: $@";
	}

Handles all setting of outlook fields

If outlook is undef, unsets the outlook

If outlook is 0, sets the outlook to the first paragraph contained in
the message passed.

If outlook is a positive integer, sets the outlook to the message specified.

Otherwise, sets outlook to the value passed.

=cut


sub outlook {
    return _summary('outlook',@_);
}

sub _summary {
    my ($cmd,@params) = @_;
    my %param = validate_with(params => \@params,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 # specific options here
					 $cmd , {type => SCALAR|UNDEF,
						 default => 0,
						},
					 %common_options,
					 %append_action_options,
					},
			     );
    my %info =
	__begin_control(%param,
			command  => $cmd,
		       );
    my ($debug,$transcript) =
	@info{qw(debug transcript)};
    my @data = @{$info{data}};
    # figure out the log that we're going to use
    my $summary = '';
    my $summary_msg = '';
    my $action = '';
    if (not defined $param{$cmd}) {
	 # do nothing
	 print {$debug} "Removing $cmd fields\n";
	 $action = "Removed $cmd";
    }
    elsif ($param{$cmd} =~ /^-?\d+$/) {
	 my $log = [];
	 my @records = Debbugs::Log::read_log_records(bug_num => $param{bug});
	 if ($param{$cmd} == 0 or $param{$cmd} == -1) {
	      $log = $param{message};
	      $summary_msg = @records + 1;
	 }
	 else {
	      if (($param{$cmd} - 1 ) > $#records) {
		   die "Message number '$param{$cmd}' exceeds the maximum message '$#records'";
	      }
	      my $record = $records[($param{$cmd} - 1 )];
	      if ($record->{type} !~ /incoming-recv|recips/) {
		   die "Message number '$param{$cmd}' is a invalid message type '$record->{type}'";
	      }
	      $summary_msg = $param{$cmd};
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
			if ($paragraph =~ m/^(?:.+\n\>)+.+\n/x) {
			     $paragraph = '';
			     next;
			}
			last;
		   }
		   $in_pseudoheaders = 0;
		   next;
	      }
	      # skip a paragraph if it looks like it's control or
	      # pseudo-headers
	      if ($line =~ m{^\s*(?:Package|Source|Version|User|Tag|Severity|Control)\:\s+\S}xi or #pseudo headers
		  $line =~ m{^(?:package:?|(?:no|)owner|severity|tags?|summary| #control
				 \#|reopen|close|(?:not|)(?:fixed|found)|clone|
				 debug|(?:not|)forwarded|priority|
				 (?:un|)block|limit|(?:un|)archive|
				 reassign|retitle|affects|wrongpackage
				 (?:un|force|)merge|user(?:category|tags?|)
			     )\s+\S}xis) {
		   if (not length $paragraph) {
			print {$debug} "Found control/pseudo-headers and skiping them\n";
			$in_pseudoheaders = 1;
			next;
		   }
	      }
	      next if $in_pseudoheaders;
	      $paragraph .= $line ." \n";
	 }
	 print {$debug} ucfirst($cmd)." is going to be '$paragraph'\n";
	 $summary = $paragraph;
	 $summary =~ s/[\n\r]/ /g;
	 if (not length $summary) {
	      die "Unable to find $cmd message to use";
	 }
	 # trim off a trailing spaces
	 $summary =~ s/\ *$//;
    }
    else {
	$summary = $param{$cmd};
    }
    for my $data (@data) {
	 print {$debug} "Going to change $cmd\n";
	 if (((not defined $summary or not length $summary) and
	      (not defined $data->{$cmd} or not length $data->{$cmd})) or
	     $summary eq $data->{$cmd}) {
	     print {$transcript} "Ignoring request to change the $cmd of bug $param{bug} to the same value\n";
	     next;
	 }
	 if (length $summary) {
	      if (length $data->{$cmd}) {
		   $action = ucfirst($cmd)." replaced with message bug $param{bug} message $summary_msg";
	      }
	      else {
		   $action = ucfirst($cmd)." recorded from message bug $param{bug} message $summary_msg";
	      }
	 }
	 my $old_data = dclone($data);
	 $data->{$cmd} = $summary;
	 append_action_to_log(bug => $data->{bug_num},
			      command => $cmd,
			      old_data => $old_data,
			      new_data => $data,
			      get_lock => 0,
			      __return_append_to_log_options(
							     %param,
							     action => $action,
							    ),
			     )
	       if not exists $param{append_log} or $param{append_log};
	  writebug($data->{bug_num},$data);
	  print {$transcript} "$action\n";
     }
    __end_control(%info);
}



=head2 clone_bug

     eval {
	    clone_bug(bug          => $ref,
		      transcript   => $transcript,
		      ($dl > 0 ? (debug => $transcript):()),
		      requester    => $header{from},
		      request_addr => $controlrequestaddr,
		      message      => \@log,
                      affected_packages => \%affected_packages,
		      recipients   => \%recipients,
		     );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to clone bug $ref bar: $@";
	}

Clones the given bug.

We currently don't support cloning merged bugs, but this could be
handled by internally unmerging, cloning, then remerging the bugs.

=cut

sub clone_bug {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+$/,
						},
					 new_bugs => {type => ARRAYREF,
						     },
					 new_clones => {type => HASHREF,
							default => {},
						       },
					 %common_options,
					 %append_action_options,
					},
			     );
    my %info =
	__begin_control(%param,
			command  => 'clone'
		       );
    my $transcript = $info{transcript};
    my @data = @{$info{data}};

    my $action = '';
    for my $data (@data) {
	if (length($data->{mergedwith})) {
	    die "Bug is marked as being merged with others. Use an existing clone.\n";
	}
    }
    if (@data != 1) {
	die "Not exactly one bug‽ This shouldn't happen.";
    }
    my $data = $data[0];
    my %clones;
    for my $newclone_id (@{$param{new_bugs}}) {
	my $new_bug_num = new_bug(copy => $data->{bug_num});
	$param{new_clones}{$newclone_id} = $new_bug_num;
	$clones{$newclone_id} = $new_bug_num;
    }
    my @new_bugs = sort values %clones;
    my @collapsed_ids;
    for my $new_bug (@new_bugs) {
	# no collapsed ids or the higher collapsed id is not one less
	# than the next highest new bug
	if (not @collapsed_ids or 
	    $collapsed_ids[-1][1]+1 != $new_bug) {
	    push @collapsed_ids,[$new_bug,$new_bug];
	}
	else {
	    $collapsed_ids[-1][1] = $new_bug;
	}
    }
    my @collapsed;
    for my $ci (@collapsed_ids) {
	if ($ci->[0] == $ci->[1]) {
	    push @collapsed,$ci->[0];
	}
	else {
	    push @collapsed,$ci->[0].'-'.$ci->[1]
	}
    }
    my $collapsed_str = english_join(\@collapsed);
    $action = "Bug $data->{bug_num} cloned as bug".(@new_bugs > 1?'s':'').' '.$collapsed_str;
    for my $new_bug (@new_bugs) {
	append_action_to_log(bug => $new_bug,
			     get_lock => 1,
			     __return_append_to_log_options(
							    %param,
							    action => $action,
							   ),
			    )
	    if not exists $param{append_log} or $param{append_log};
    }
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
    __end_control(%info);
    # bugs that this bug is blocking are also blocked by the new clone(s)
    for my $bug (split ' ', $data->{blocks}) {
	for my $new_bug (@new_bugs) {
	    set_blocks(bug => $bug,
		       block => $new_bug,
		       add => 1,
		       hash_slice(%param,
				  keys %common_options,
				  keys %append_action_options),
		      );
	}
    }
    # bugs that are blocking this bug are also blocking the new clone(s)
    for my $bug (split ' ', $data->{blockedby}) {
	for my $new_bug (@new_bugs) {
	    set_blocks(bug => $new_bug,
		       block => $bug,
		       add => 1,
		       hash_slice(%param,
				  keys %common_options,
				  keys %append_action_options),
		      );
	}
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
     my %info =
	 __begin_control(%param,
			 command  => 'owner',
			);
     my ($debug,$transcript) =
	@info{qw(debug transcript)};
     my @data = @{$info{data}};
     my $action = '';
     for my $data (@data) {
	  print {$debug} "Going to change owner to '".(defined $param{owner}?$param{owner}:'(going to unset it)')."'\n";
	  print {$debug} "Owner is currently '$data->{owner}' for bug $data->{bug_num}\n";
	  if (not defined $param{owner} or not length $param{owner}) {
	      if (not defined $data->{owner} or not length $data->{owner}) {
		  print {$transcript} "Ignoring request to unset the owner of bug #$data->{bug_num} which was not set\n";
		  next;
	      }
	      $param{owner} = '';
	      $action = "Removed annotation that $config{bug} was owned by " .
		  "$data->{owner}.";
	  }
	  else {
	      if ($data->{owner} eq $param{owner}) {
		  print {$transcript} "Ignoring request to set the owner of bug #$data->{bug_num} to the same value\n";
		  next;
	      }
	      if (length $data->{owner}) {
		  $action = "Owner changed from $data->{owner} to $param{owner}.";
	      }
	      else {
		  $action = "Owner recorded as $param{owner}."
	      }
	  }
	  my $old_data = dclone($data);
	  $data->{owner} = $param{owner};
	  append_action_to_log(bug => $data->{bug_num},
			       command => 'owner',
			       new_data => $data,
			       old_data => $old_data,
			       get_lock => 0,
	       __return_append_to_log_options(
					      %param,
					      action => $action,
					     ),
			      )
	       if not exists $param{append_log} or $param{append_log};
	  writebug($data->{bug_num},$data);
	  print {$transcript} "$action\n";
     }
     __end_control(%info);
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
     my %info = __begin_control(%param,
				command => 'archive',
				);
     my ($debug,$transcript) = @info{qw(debug transcript)};
     my @data = @{$info{data}};
     my @bugs = @{$info{bugs}};
     my $action = "$config{bug} archived.";
     if ($param{check_archiveable} and
	 not bug_archiveable(bug=>$param{bug},
			     ignore_time => $param{ignore_time},
			    )) {
	  print {$transcript} "Bug $param{bug} cannot be archived\n";
	  die "Bug $param{bug} cannot be archived";
     }
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
			       command => 'archive',
			       # we didn't actually change the data
			       # when we archived, so we don't pass
			       # a real new_data or old_data
			       new_data => {},
			       old_data => {},
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
		   link("$config{spool_dir}/db-h/$dir/$file", "$config{spool_dir}/archive/$dir/$file") or
		       copy("$config{spool_dir}/db-h/$dir/$file", "$config{spool_dir}/archive/$dir/$file") or
			   # we need to bail out here if things have
			   # gone horribly wrong to avoid removing a
			   # bug altogether
			   die "Unable to link or copy $config{spool_dir}/db-h/$dir/$file to $config{spool_dir}/archive/$dir/$file; $!";
	       }

	       print {$transcript} "archived $bug to archive/$dir (from $param{bug})\n";
	  }
	  unlink(map {"$config{spool_dir}/db-h/$dir/$_"} @files_to_remove);
	  print {$debug} "deleted $bug (from $param{bug})\n";
     }
     bughook_archive(@bugs);
     __end_control(%info);
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

     my %info = __begin_control(%param,
				archived=>1,
				command=>'unarchive');
     my ($debug,$transcript) =
	 @info{qw(debug transcript)};
     my @bugs = @{$info{bugs}};
     my $action = "$config{bug} unarchived.";
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
	  my $old_data = dclone($newdata);
	  if (not defined $newdata) {
	       print {$transcript} "$config{bug} $bug disappeared!\n";
	       die "Bug $bug disappeared!";
	  }
	  $newdata->{unarchived} = time;
	  append_action_to_log(bug => $bug,
			       get_lock => 0,
			       command => 'unarchive',
			       new_data => $newdata,
			       old_data => $old_data,
			       __return_append_to_log_options(
				 %param,
				 action => $action,
				)
			      )
	       if not exists $param{append_log} or $param{append_log};
	  writebug($bug,$newdata);
     }
     __end_control(%info);
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
					  new_data => {type => HASHREF,
						       optional => 1,
						      },
					  old_data => {type => HASHREF,
						       optional => 1,
						      },
					  command  => {type => SCALAR,
						       optional => 1,
						      },
					  action => {type => SCALAR,
						    },
					  requester => {type => SCALAR,
							default => '',
						       },
					  request_addr => {type => SCALAR,
							   default => '',
							  },
					  location => {type => SCALAR,
						       optional => 1,
						      },
					  message  => {type => SCALAR|ARRAYREF,
						       default => '',
						      },
					  recips   => {type => SCALAR|ARRAYREF,
						       optional => 1
						      },
					  desc       => {type => SCALAR,
							 default => '',
							},
					  get_lock   => {type => BOOLEAN,
							 default => 1,
							},
					  locks      => {type => HASHREF,
							 optional => 1,
							},
					  # we don't use
					  # append_action_options here
					  # because some of these
					  # options aren't actually
					  # optional, even though the
					  # original function doesn't
					  # require them
					 },
			      );
     # Fix this to use $param{location}
     my $log_location = buglog($param{bug});
     die "Unable to find .log for $param{bug}"
	  if not defined $log_location;
     if ($param{get_lock}) {
	  filelock("lock/$param{bug}",exists $param{locks}?$param{locks}:());
	  $locks++;
     }
     my @records;
     my $logfh = IO::File->new(">>$log_location") or
	 die "Unable to open $log_location for appending: $!";
     # determine difference between old and new
     my $data_diff = '';
     if (exists $param{old_data} and exists $param{new_data}) {
	 my $old_data = dclone($param{old_data});
	 my $new_data = dclone($param{new_data});
	 for my $key (keys %{$old_data}) {
	     if (not exists $Debbugs::Status::fields{$key}) {
		 delete $old_data->{$key};
		 next;
	     }
	     next unless exists $new_data->{$key};
	     next unless defined $new_data->{$key};
	     if (not defined $old_data->{$key}) {
		 delete $old_data->{$key};
		 next;
	     }
	     if (ref($new_data->{$key}) and
		 ref($old_data->{$key}) and
		 ref($new_data->{$key}) eq ref($old_data->{$key})) {
		local $Storable::canonical = 1;
		if (nfreeze($new_data->{$key}) eq nfreeze($old_data->{$key})) {
		    delete $new_data->{$key};
		    delete $old_data->{$key};
		}
	     }
	     elsif ($new_data->{$key} eq $old_data->{$key}) {
		 delete $new_data->{$key};
		 delete $old_data->{$key};
	     }
	 }
	 for my $key (keys %{$new_data}) {
	     if (not exists $Debbugs::Status::fields{$key}) {
		 delete $new_data->{$key};
		 next;
	     }
	     next unless exists $old_data->{$key};
	     next unless defined $old_data->{$key};
	     if (not defined $new_data->{$key} or
		 not exists $Debbugs::Status::fields{$key}) {
		 delete $new_data->{$key};
		 next;
	     }
	     if (ref($new_data->{$key}) and
		 ref($old_data->{$key}) and
		 ref($new_data->{$key}) eq ref($old_data->{$key})) {
		local $Storable::canonical = 1;
		if (nfreeze($new_data->{$key}) eq nfreeze($old_data->{$key})) {
		    delete $new_data->{$key};
		    delete $old_data->{$key};
		}
	     }
	     elsif ($new_data->{$key} eq $old_data->{$key}) {
		 delete $new_data->{$key};
		 delete $old_data->{$key};
	     }
	 }
	 $data_diff .= "<!-- new_data:\n";
	 my %nd;
	 for my $key (keys %{$new_data}) {
	     if (not exists $Debbugs::Status::fields{$key}) {
		 warn "No such field $key";
		 next;
	     }
	     $nd{$key} = $new_data->{$key};
	     # $data_diff .= html_escape("$Debbugs::Status::fields{$key}: $new_data->{$key}")."\n";
	 }
	 $data_diff .= html_escape(Data::Dumper->Dump([encode_utf8_structure(\%nd)],[qw(new_data)]));
	 $data_diff .= "-->\n";
	 $data_diff .= "<!-- old_data:\n";
	 my %od;
	 for my $key (keys %{$old_data}) {
	     if (not exists $Debbugs::Status::fields{$key}) {
		 warn "No such field $key";
		 next;
	     }
	     $od{$key} = $old_data->{$key};
	     # $data_diff .= html_escape("$Debbugs::Status::fields{$key}: $old_data->{$key}")."\n";
	 }
	 $data_diff .= html_escape(Data::Dumper->Dump([encode_utf8_structure(\%od)],[qw(old_data)]));
	 $data_diff .= "-->\n";
     }
     my $msg = join('',
		    (exists $param{command} ?
		     "<!-- command:".html_escape(encode_utf8_safely($param{command}))." -->\n":""
		    ),
		    (length $param{requester} ?
		     "<!-- requester: ".html_escape(encode_utf8_safely($param{requester}))." -->\n":""
		    ),
		    (length $param{request_addr} ?
		     "<!-- request_addr: ".html_escape(encode_utf8_safely($param{request_addr}))." -->\n":""
		    ),
		    "<!-- time:".time()." -->\n",
		    $data_diff,
		    "<strong>".html_escape(encode_utf8_safely($param{action}))."</strong>\n");
     if (length $param{requester}) {
          $msg .= "Request was from <code>".html_escape(encode_utf8_safely($param{requester}))."</code>\n";
     }
     if (length $param{request_addr}) {
          $msg .= "to <code>".html_escape(encode_utf8_safely($param{request_addr}))."</code>";
     }
     if (length $param{desc}) {
	  $msg .= ":<br>\n".encode_utf8_safely($param{desc})."\n";
     }
     else {
	  $msg .= ".\n";
     }
     push @records, {type => 'html',
		     text => $msg,
		    };
     $msg = '';
     if ((ref($param{message}) and @{$param{message}}) or length($param{message})) {
	 push @records, {type => exists $param{recips}?'recips':'incoming-recv',
			 exists $param{recips}?(recips => [map {encode_utf8_safely($_)} make_list($param{recips})]):(),
			 text => join('',make_list($param{message})),
			};
     }
     write_log_records(logfh=>$logfh,
		       records => \@records,
		      );
     close $logfh or die "Unable to close $log_location: $!";
     if ($param{get_lock}) {
	  unfilelock(exists $param{locks}?$param{locks}:());
	  $locks--;
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
	  next unless exists $data->{package} and defined $data->{package};
	  my @packages = split /\s*,\s*/,$data->{package};
	  @{$param{affected_packages}}{@packages} = (1) x @packages;
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
	 next unless defined $data and exists $data->{bug_num};
	  $return .= "Bug #".($data->{bug_num}||'').
	      ((defined $data->{done} and length $data->{done})?
		" {Done: $data->{done}}":''
	       ).
	       " [".($data->{package}||'(no package)'). "] ".
		    ($data->{subject}||'(no subject)')."\n";
     }
     return $return;
}


=head2 __internal_request

     __internal_request()
     __internal_request($level)

Returns true if the caller of the function calling __internal_request
belongs to __PACKAGE__

This allows us to be magical, and don't bother to print bug info if
the second caller is from this package, amongst other things.

An optional level is allowed, which increments the number of levels to
check by the given value. [This is basically for use by internal
functions like __begin_control which are always called by
C<__PACKAGE__>.

=cut

sub __internal_request{
    my ($l) = @_;
    $l = 0 if not defined $l;
    if (defined((caller(1+$l))[0]) and (caller(1+$l))[0] eq __PACKAGE__) {
	return 1;
    }
    return 0;
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
	  $param{message} =
              encode_headers(fill_in_template(template  => 'mail/fake_control_message',
                                              variables => {request_addr => $param{request_addr},
                                                            requester    => $param{requester},
                                                            date         => $date,
                                                            action       => $action
                                                           },
                                             ));
     }
     if (not defined $action) {
	  carp "Undefined action!";
	  $action = "unknown action";
     }
     return (action => $action,
	     hash_slice(%param,keys %append_action_options),
	    );
}

=head2 __begin_control

     my %info = __begin_control(%param,
				archived=>1,
				command=>'unarchive');
     my ($debug,$transcript) = @info{qw(debug transcript)};
     my @data = @{$info{data}};
     my @bugs = @{$info{bugs}};


Starts the process of modifying a bug; handles all of the generic
things that almost every control request needs

Returns a hash containing

=over

=item new_locks -- number of new locks taken out by this call

=item debug -- the debug file handle

=item transcript -- the transcript file handle

=item data -- an arrayref containing the data of the bugs
corresponding to this request

=item bugs -- an arrayref containing the bug numbers of the bugs
corresponding to this request

=back

=cut

our $lockhash;

sub __begin_control {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type   => SCALAR,
						 regex  => qr/^\d+/,
						},
					 archived => {type => BOOLEAN,
						      default => 0,
						     },
					 command  => {type => SCALAR,
						      optional => 1,
						     },
					 %common_options,
					},
			      allow_extra => 1,
			     );
    my $new_locks;
    my ($debug,$transcript) = __handle_debug_transcript(@_);
    print {$debug} "considering bug $param{bug} for ".(exists $param{command}?$param{command}:scalar caller())."\n";
#    print {$debug} Data::Dumper->Dump([[caller(1)],\%param],[qw(caller param)])."\n";
    $lockhash = $param{locks} if exists $param{locks};
    my @data = ();
    my $old_die = $SIG{__DIE__};
    $SIG{__DIE__} = *sig_die{CODE};

    ($new_locks, @data) =
	lock_read_all_merged_bugs(bug => $param{bug},
				  $param{archived}?(location => 'archive'):(),
				  exists $param{locks} ? (locks => $param{locks}):(),
				 );
    $locks += $new_locks;
    if (not @data) {
	die "Unable to read any bugs successfully.";
    }
    if (not $param{archived}) {
	for my $data (@data) {
	    if ($data->{archived}) {
		die "Not altering archived bugs; see unarchive.";
	    }
	}
    }
    if (not check_limit(data => \@data,
			  exists $param{limit}?(limit => $param{limit}):(),
			  transcript => $transcript,
			 )) {
	die "limit failed for bugs: ".join(', ',map {$_->{bug_num}} @data);
    }

    __handle_affected_packages(%param,data => \@data);
    print {$transcript} __bug_info(@data) if $param{show_bug_info} and not __internal_request(1);
    print {$debug} "$param{bug} read $locks locks\n";
    if (not @data or not defined $data[0]) {
	print {$transcript} "No bug found for $param{bug}\n";
	die "No bug found for $param{bug}";
    }

    add_recipients(data => \@data,
		   recipients => $param{recipients},
		   (exists $param{command}?(actions_taken => {$param{command} => 1}):()),
		   debug      => $debug,
		   (__internal_request()?(transcript => $transcript):()),
		  );

    print {$debug} "$param{bug} read done\n";
    my @bugs = map {(defined $_ and exists $_->{bug_num} and defined $_->{bug_num})?$_->{bug_num}:()} @data;
    print {$debug} "$param{bug} bugs ".join(' ',@bugs)."\n";
    return (data       => \@data,
	    bugs       => \@bugs,
	    old_die    => $old_die,
	    new_locks  => $new_locks,
	    debug      => $debug,
	    transcript => $transcript,
	    param      => \%param,
	    exists $param{locks}?(locks => $param{locks}):(),
	   );
}

=head2 __end_control

     __end_control(%info);

Handles tearing down from a control request

=cut

sub __end_control {
    my %info = @_;
    if (exists $info{new_locks} and $info{new_locks} > 0) {
	print {$info{debug}} "For bug $info{param}{bug} unlocking $locks locks\n";
	for (1..$info{new_locks}) {
	    unfilelock(exists $info{locks}?$info{locks}:());
	    $locks--;
	}
    }
    $SIG{__DIE__} = $info{old_die};
    if (exists $info{param}{affected_bugs}) {
	@{$info{param}{affected_bugs}}{@{$info{bugs}}} = (1) x @{$info{bugs}};
    }
    add_recipients(recipients => $info{param}{recipients},
		   (exists $info{param}{command}?(actions_taken => {$info{param}{command} , 1}):()),
		   data       => $info{data},
		   debug      => $info{debug},
		   transcript => $info{transcript},
		  );
    __handle_affected_packages(%{$info{param}},data=>$info{data});
}


=head2 check_limit

     check_limit(data => \@data, limit => $param{limit});


Checks to make sure that bugs match any limits; each entry of @data
much satisfy the limit.

Returns true if there are no entries in data, or there are no keys in
limit; returns false (0) if there are any entries which do not match.

The limit hashref elements can contain an arrayref of scalars to
match; regexes are also acccepted. At least one of the entries in each
element needs to match the corresponding field in all data for the
limit to succeed.

=cut


sub check_limit{
    my %param = validate_with(params => \@_,
			      spec   => {data  => {type => ARRAYREF|HASHREF,
						  },
					 limit => {type => HASHREF|UNDEF,
						  },
					 transcript  => {type => SCALARREF|HANDLE,
							 optional => 1,
							},
					},
			     );
    my @data = make_list($param{data});
    if (not @data or
	not defined $param{limit} or
	not keys %{$param{limit}}) {
	return 1;
    }
    my $transcript = globify_scalar(exists $param{transcript}?$param{transcript}:undef);
    my $going_to_fail = 0;
    for my $data (@data) {
	$data = split_status_fields(get_bug_status(bug => $data->{bug_num},
						   status => dclone($data),
						  ));
	for my $field (keys %{$param{limit}}) {
	    next unless exists $param{limit}{$field};
	    my $match = 0;
	    my @data_fields = make_list($data->{$field});
LIMIT:	    for my $limit (make_list($param{limit}{$field})) {
		if (not ref $limit) {
		    for my $data_field (@data_fields) {
			if ($data_field eq $limit) {
			    $match = 1;
			    last LIMIT;
			}
		    }
		}
		elsif (ref($limit) eq 'Regexp') {
		    for my $data_field (@data_fields) {
			if ($data_field =~ $limit) {
			    $match = 1;
			    last LIMIT;
			}
		    }
		}
		else {
		    warn "Unknown type of reference: '".ref($limit)."' in key '$field'";
		}
	    }
	    if (not $match) {
		$going_to_fail = 1;
		print {$transcript} qq($field: ').join(', ',map{qq("$_")} make_list($data->{$field})).
		    "' does not match at least one of ".
		    join(', ',map {ref($_)?'(regex)':qq("$_")} make_list($param{limit}{$field}))."\n";
	    }
	}
    }
    return $going_to_fail?0:1;
}


=head2 die

     sig_die "foo"

We override die to specially handle unlocking files in the cases where
we are called via eval. [If we're not called via eval, it doesn't
matter.]

=cut

sub sig_die{
    if ($^S) { # in eval
	if ($locks) {
	    for (1..$locks) { unfilelock(defined $lockhash?$lockhash:()); }
	    $locks = 0;
	}
    }
}


# =head2 __message_body_template
#
#      message_body_template('mail/ack',{ref=>'foo'});
#
# Creates a message body using a template
#
# =cut

sub __message_body_template{
     my ($template,$extra_var) = @_;
     $extra_var ||={};
     my $hole_var = {'&bugurl' =>
		     sub{"$_[0]: ".
			     'http://'.$config{cgi_domain}.'/'.
				 Debbugs::CGI::bug_links(bug => $_[0],
							 links_only => 1,
							);
		     }
		    };

     my $body = fill_in_template(template => $template,
				 variables => {config => \%config,
					       %{$extra_var},
					      },
				 hole_var => $hole_var,
				);
     return fill_in_template(template => 'mail/message_body',
			     variables => {config => \%config,
					   %{$extra_var},
					   body => $body,
					  },
			     hole_var => $hole_var,
			    );
}

sub __all_undef_or_equal {
    my @values = @_;
    return 1 if @values == 1 or @values == 0;
    my $not_def = grep {not defined $_} @values;
    if ($not_def == @values) {
	return 1;
    }
    if ($not_def > 0 and $not_def != @values) {
	return 0;
    }
    my $first_val = shift @values;
    for my $val (@values) {
	if ($first_val ne $val) {
	    return 0;
	}
    }
    return 1;
}


1;

__END__
