# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# go here too.]
# Copyright 2007,2008,2009 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Control::Service;

=head1 NAME

Debbugs::Control::Service -- Handles the modification parts of scripts/service by calling Debbugs::Control

=head1 SYNOPSIS

use Debbugs::Control::Service;


=head1 DESCRIPTION

This module contains the code to implement the grammar of control@. It
is abstracted here so that it can be called from process at submit
time.

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
     %EXPORT_TAGS = (control => [qw(control_line valid_control)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

use Debbugs::Config qw(:config);
use Debbugs::Common qw(cleanup_eval_fail);
use Debbugs::Control qw(:all);
use Debbugs::Status qw(splitpackages);
use Params::Validate qw(:types validate_with);
use List::Util qw(first);

my $bug_num_re = '-?\d+';
my %control_grammar =
    (close => qr/(?i)^close\s+\#?($bug_num_re)(?:\s+(\d.*))?$/,
     reassign => qr/(?i)^reassign\s+\#?($bug_num_re)\s+ # bug and command
		    (?:(?:((?:src:|source:)?$config{package_name_re}) # new package
			    (?:\s+((?:$config{package_name_re}\/)?
				    $config{package_version_re}))?)| # optional version
			((?:src:|source:)?$config{package_name_re} # multiple package form
			    (?:\s*\,\s*(?:src:|source:)?$config{package_name_re})+))
		    \s*$/x,
     reopen => qr/(?i)^reopen\s+\#?($bug_num_re)(?:\s+([\=\!]|(?:\S.*\S)))?$/,
     found => qr{^(?:(?i)found)\s+\#?($bug_num_re)
		 (?:\s+((?:$config{package_name_re}\/)?
			 $config{package_version_re}
			 # allow for multiple packages
			 (?:\s*,\s*(?:$config{package_name_re}\/)?
			     $config{package_version_re})*)
		 )?$}x,
     notfound => qr{^(?:(?i)notfound)\s+\#?($bug_num_re)
		    \s+((?:$config{package_name_re}\/)?
			$config{package_version_re}
			# allow for multiple packages
			(?:\s*,\s*(?:$config{package_name_re}\/)?
			    $config{package_version_re})*
		    )$}x,
     fixed => qr{^(?:(?i)fixed)\s+\#?($bug_num_re)
	     \s+((?:$config{package_name_re}\/)?
		    $config{package_version_re}
		# allow for multiple packages
		(?:\s*,\s*(?:$config{package_name_re}\/)?
		    $config{package_version_re})*)
	    \s*$}x,
     notfixed => qr{^(?:(?i)notfixed)\s+\#?($bug_num_re)
	     \s+((?:$config{package_name_re}\/)?
		    $config{package_version_re}
		# allow for multiple packages
		(?:\s*,\s*(?:$config{package_name_re}\/)?
		    $config{package_version_re})*)
	    \s*$}x,
     submitter => qr/(?i)^submitter\s+\#?($bug_num_re)\s+(\!|\S.*\S)$/,
     forwarded => qr/(?i)^forwarded\s+\#?($bug_num_re)\s+(\S.*\S)$/,
     notforwarded => qr/(?i)^notforwarded\s+\#?($bug_num_re)$/,
     severity => qr/(?i)^(?:severity|priority)\s+\#?($bug_num_re)\s+([-0-9a-z]+)$/,
     tag => qr/(?i)^tags?\s+\#?($bug_num_re)\s+(\S.*)$/,
     block => qr/(?i)^(un)?block\s+\#?($bug_num_re)\s+(?:by|with)\s+(\S.*)?$/,
     retitle => qr/(?i)^retitle\s+\#?($bug_num_re)\s+(\S.*\S)\s*$/,
     unmerge => qr/(?i)^unmerge\s+\#?($bug_num_re)$/,
     merge   => qr/(?i)^merge\s+#?($bug_num_re(\s+#?$bug_num_re)+)\s*$/,
     forcemerge => qr/(?i)^forcemerge\s+\#?($bug_num_re(?:\s+\#?$bug_num_re)+)\s*$/,
     clone => qr/(?i)^clone\s+#?($bug_num_re)\s+((?:$bug_num_re\s+)*$bug_num_re)\s*$/,
     package => qr/(?i)^package\:?\s+(\S.*\S)?\s*$/,
     limit => qr/(?i)^limit\:?\s+(\S.*\S)\s*$/,
     affects => qr/(?i)^affects?\s+\#?($bug_num_re)(?:\s+((?:[=+-])?)\s*(\S.*)?)?\s*$/,
     summary => qr/(?i)^summary\s+\#?($bug_num_re)\s*(.*)\s*$/,
     outlook => qr/(?i)^outlook\s+\#?($bug_num_re)\s*(.*)\s*$/,
     owner => qr/(?i)^owner\s+\#?($bug_num_re)\s+((?:\S.*\S)|\!)\s*$/,
     noowner => qr/(?i)^noowner\s+\#?($bug_num_re)\s*$/,
     unarchive => qr/(?i)^unarchive\s+#?($bug_num_re)$/,
     archive => qr/(?i)^archive\s+#?($bug_num_re)$/,
    );

sub valid_control {
    my ($line,$matches) = @_;
    my @matches;
    for my $ctl (keys %control_grammar) {
	if (@matches = $line =~ $control_grammar{$ctl}) {
	    @{$matches} = @matches if defined $matches and ref($matches) eq 'ARRAY';
	    return $ctl;
	}
    }
    @{$matches} = () if defined $matches and ref($matches) eq 'ARRAY';
    return undef;
}

sub control_line {
    my %param =
	validate_with(params => \@_,
		      spec => {line => {type => SCALAR,
				       },
			       clonebugs => {type => HASHREF,
					    },
			       common_control_options => {type => ARRAYREF,
							 },
			       errors => {type => SCALARREF,
					 },
			       transcript => {type => HANDLE,
					     },
			       debug => {type => SCALAR,
					 default => 0,
					},
			       ok => {type => SCALARREF,
				     },
			       limit => {type => HASHREF,
					},
			       replyto => {type => SCALAR,
					  },
			      },
		     );
    my $line = $param{line};
    my @matches;
    my $ctl = valid_control($line,\@matches);
    my $transcript = $param{transcript};
    my $debug = $param{debug};
    if (not defined $ctl) {
	${$param{errors}}++;
	print {$param{transcript}} "Unknown command or invalid options to control\n";
	return;
    }
    # in almost all cases, the first match is the bug; the exception
    # to this is block.
    my $ref = $matches[0];
    if (defined $ref) {
	$ref = $param{clonebugs}{$ref} if exists $param{clonebugs}{$ref};
    }
    ${$param{ok}}++;
    my $errors = 0;
    my $terminate_control = 0;

    if ($ctl eq 'close') {
	if (defined $matches[1]) {
	    eval {
		set_fixed(@{$param{common_control_options}},
			  bug   => $ref,
			  fixed => $matches[1],
			  add   => 1,
			 );
	    };
	    if ($@) {
		$errors++;
		print {$transcript} "Failed to add fixed version '$matches[1]' to $ref: ".cleanup_eval_fail($@,$debug)."\n";
	    }
	}
	eval {
	    set_done(@{$param{common_control_options}},
		     done      => 1,
		     bug       => $ref,
		     reopen    => 0,
		     notify_submitter => 1,
		     clear_fixed => 0,
		    );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to mark $ref as done: ".cleanup_eval_fail($@,$debug)."\n";
	}
    } elsif ($ctl eq 'reassign') {
	my @new_packages;
	if (not defined $matches[1]) {
	    push @new_packages, split /\s*\,\s*/,$matches[3];
	}
	else {
	    push @new_packages, $matches[1];
	}
	@new_packages = map {y/A-Z/a-z/; s/^(?:src|source):/src:/; $_;} @new_packages;
        my $version= $matches[2];
    	eval {
	    set_package(@{$param{common_control_options}},
			bug          => $ref,
			package      => \@new_packages,
		       );
	    # if there is a version passed, we make an internal call
	    # to set_found
	    if (defined($version) && length $version) {
		set_found(@{$param{common_control_options}},
			  bug   => $ref,
			  found => $version,
			 );
	    }
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to clear fixed versions and reopen on $ref: ".cleanup_eval_fail($@,$debug)."\n";
	}
    } elsif ($ctl eq 'reopen') {
	my $new_submitter = $matches[1];
	if (defined $new_submitter) {
	    if ($new_submitter eq '=') {
		undef $new_submitter;
	    }
	    elsif ($new_submitter eq '!') {
		$new_submitter = $param{replyto};
	    }
	}
	eval {
	    set_done(@{$param{common_control_options}},
		     bug          => $ref,
		     reopen       => 1,
		     defined $new_submitter? (submitter    => $new_submitter):(),
		    );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to reopen $ref: ".cleanup_eval_fail($@,$debug)."\n";
	}
    } elsif ($ctl eq 'found') {
	my @versions;
        if (defined $matches[1]) {
	    @versions = split /\s*,\s*/,$matches[1];
	    eval {
		set_found(@{$param{common_control_options}},
			  bug          => $ref,
			  found        => \@versions,
			  add          => 1,
			 );
	    };
	    if ($@) {
		$errors++;
		print {$transcript} "Failed to add found on $ref: ".cleanup_eval_fail($@,$debug)."\n";
	    }
	}
	else {
	    eval {
		set_fixed(@{$param{common_control_options}},
			  bug          => $ref,
			  fixed        => [],
			  reopen       => 1,
			 );
	    };
	    if ($@) {
		$errors++;
		print {$transcript} "Failed to clear fixed versions and reopen on $ref: ".cleanup_eval_fail($@,$debug)."\n";
	    }
	}
    }
    elsif ($ctl eq 'notfound') {
	my @versions;
        @versions = split /\s*,\s*/,$matches[1];
	eval {
	    set_found(@{$param{common_control_options}},
		      bug          => $ref,
		      found        => \@versions,
		      remove       => 1,
		     );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to remove found on $ref: ".cleanup_eval_fail($@,$debug)."\n";
	}
    }
    elsif ($ctl eq 'fixed') {
	my @versions;
        @versions = split /\s*,\s*/,$matches[1];
	eval {
	    set_fixed(@{$param{common_control_options}},
		      bug          => $ref,
		      fixed        => \@versions,
		      add          => 1,
		     );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to add fixed on $ref: ".cleanup_eval_fail($@,$debug)."\n";
	}
    }
    elsif ($ctl eq 'notfixed') {
	my @versions;
        @versions = split /\s*,\s*/,$matches[1];
	eval {
	    set_fixed(@{$param{common_control_options}},
		      bug          => $ref,
		      fixed        => \@versions,
		      remove       => 1,
		     );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to remove fixed on $ref: ".cleanup_eval_fail($@,$debug)."\n";
	}
    }
    elsif ($ctl eq 'submitter') {
	my $newsubmitter = $matches[1] eq '!' ? $param{replyto} : $matches[1];
        if (not Mail::RFC822::Address::valid($newsubmitter)) {
	     print {$transcript} "$newsubmitter is not a valid e-mail address; not changing submitter\n";
	     $errors++;
	}
	else {
	    eval {
		set_submitter(@{$param{common_control_options}},
			      bug       => $ref,
			      submitter => $newsubmitter,
			     );
	    };
	    if ($@) {
		$errors++;
		print {$transcript} "Failed to set submitter on $ref: ".cleanup_eval_fail($@,$debug)."\n";
	    }
        }
    } elsif ($ctl eq 'forwarded') {
	my $forward_to= $matches[1];
	eval {
	    set_forwarded(@{$param{common_control_options}},
			  bug          => $ref,
			  forwarded    => $forward_to,
                          );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to set the forwarded-to-address of $ref: ".cleanup_eval_fail($@,$debug)."\n";
	}
    } elsif ($ctl eq 'notforwarded') {
	eval {
	    set_forwarded(@{$param{common_control_options}},
			  bug          => $ref,
			  forwarded    => undef,
                          );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to clear the forwarded-to-address of $ref: ".cleanup_eval_fail($@,$debug)."\n";
	}
    } elsif ($ctl eq 'severity') {
	my $newseverity= $matches[1];
        if (exists $config{obsolete_severities}{$newseverity}) {
            print {$transcript} "Severity level \`$newseverity' is obsolete. " .
		 "Use $config{obsolete_severities}{$newseverity} instead.\n\n";
	    	$errors++;
        } elsif (not defined first {$_ eq $newseverity}
	    (@{$config{severity_list}}, $config{default_severity})) {
	     print {$transcript} "Severity level \`$newseverity' is not known.\n".
		  "Recognized are: $config{show_severities}.\n\n";
	    $errors++;
        } else {
	    eval {
		set_severity(@{$param{common_control_options}},
			     bug => $ref,
			     severity => $newseverity,
			    );
	    };
	    if ($@) {
		$errors++;
		print {$transcript} "Failed to set severity of $config{bug} $ref to $newseverity: ".cleanup_eval_fail($@,$debug)."\n";
	    }
	}
    } elsif ($ctl eq 'tag') {
	my $tags = $matches[1];
	my @tags = map {m/^([+=-])(.+)/ ? ($1,$2):($_)} split /[\s,]+/, $tags;
	# this is an array of hashrefs which contain two elements, the
	# first of which is the array of tags, the second is the
	# option to pass to set_tag (we use a hashref here to make it
	# more obvious what is happening)
	my @tag_operations;
	my @badtags;
	for my $tag (@tags) {
	    if ($tag =~ /^[=+-]$/) {
		if ($tag eq '=') {
		    @tag_operations = {tags => [],
				       option => [],
				      };
		}
		elsif ($tag eq '-') {
		    push @tag_operations,
			{tags => [],
			 option => [remove => 1],
			};
		}
		elsif ($tag eq '+') {
		    push @tag_operations,
			{tags => [],
			 option => [add => 1],
			};
		}
		next;
	    }
	    if (not defined first {$_ eq $tag} @{$config{tags}}) {
		push @badtags, $tag;
		next;
	    }
	    if (not @tag_operations) {
		@tag_operations = {tags => [],
				   option => [add => 1],
				  };
	    }
	    push @{$tag_operations[-1]{tags}},$tag;
	}
	if (@badtags) {
            print {$transcript} "Unknown tag/s: ".join(', ', @badtags).".\n".
		 "Recognized are: ".join(' ', @{$config{tags}}).".\n\n";
	    $errors++;
	}
	eval {
	    for my $operation (@tag_operations) {
		set_tag(@{$param{common_control_options}},
			bug => $ref,
			tag => [@{$operation->{tags}}],
			warn_on_bad_tags => 0, # don't warn on bad tags,
			# 'cause we do that above
			@{$operation->{option}},
		       );
	    }
	};
	if ($@) {
	    # we intentionally have two errors here if there is a bad
	    # tag and the above fails for some reason
	    $errors++;
	    print {$transcript} "Failed to alter tags of $config{bug} $ref: ".cleanup_eval_fail($@,$debug)."\n";
	}
    } elsif ($ctl eq 'block') {
	my $add_remove = defined $matches[0] && $matches[0] eq 'un';
	$ref = $matches[1];
	$ref = exists $param{clonebugs}{$ref} ? $param{clonebugs}{$ref} : $ref;
	my @blockers = map {exists $param{clonebugs}{$_}?$param{clonebugs}{$_}:$_} split /[\s,]+/, $matches[2];
	eval {
	     set_blocks(@{$param{common_control_options}},
			bug          => $ref,
			block        => \@blockers,
			$add_remove ? (remove => 1):(add => 1),
		       );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to set blocking bugs of $ref: ".cleanup_eval_fail($@,$debug)."\n";
	}
    } elsif ($ctl eq 'retitle') {
        my $newtitle= $matches[1];
	eval {
	     set_title(@{$param{common_control_options}},
		       bug          => $ref,
		       title        => $newtitle,
		      );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to set the title of $ref: ".cleanup_eval_fail($@,$debug)."\n";
	}
    } elsif ($ctl eq 'unmerge') {
	eval {
	     set_merged(@{$param{common_control_options}},
			bug          => $ref,
		       );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to unmerge $ref: ".cleanup_eval_fail($@,$debug)."\n";
	}
    } elsif ($ctl eq 'merge') {
	my @tomerge;
        ($ref,@tomerge) = map {exists $param{clonebugs}{$_}?$param{clonebugs}{$_}:$_}
	    split(/\s+#?/,$matches[0]);
	eval {
	     set_merged(@{$param{common_control_options}},
			bug          => $ref,
			merge_with   => \@tomerge,
		       );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to merge $ref: ".cleanup_eval_fail($@,$debug)."\n";
	}
    } elsif ($ctl eq 'forcemerge') {
	my @tomerge;
        ($ref,@tomerge) = map {exists $param{clonebugs}{$_}?$param{clonebugs}{$_}:$_}
	    split(/\s+#?/,$matches[0]);
	eval {
	     set_merged(@{$param{common_control_options}},
			bug          => $ref,
			merge_with   => \@tomerge,
			force        => 1,
			masterbug    => 1,
		       );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to forcibly merge $ref: ".cleanup_eval_fail($@,$debug)."\n";
	}
    } elsif ($ctl eq 'clone') {
	my @newclonedids = split /\s+/, $matches[1];

	eval {
	    my %new_clones;
	    clone_bug(@{$param{common_control_options}},
		      bug => $ref,
		      new_bugs => \@newclonedids,
		      new_clones => \%new_clones,
		     );
	    %{$param{clonebugs}} = (%{$param{clonebugs}},
				    %new_clones);
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to clone $ref: ".cleanup_eval_fail($@,$debug)."\n";
	}
    } elsif ($ctl eq 'package') {
	my @pkgs = split /\s+/, $matches[0];
	if (scalar(@pkgs) > 0) {
		$param{limit}{package} = [@pkgs];
		print {$transcript} "Limiting to bugs with field 'package' containing at least one of ".join(', ',map {qq('$_')} @pkgs)."\n";
		print {$transcript} "Limit currently set to";
		for my $limit_field (keys %{$param{limit}}) {
		    print {$transcript} " '$limit_field':".join(', ',map {qq('$_')} @{$param{limit}{$limit_field}})."\n";
		}
		print {$transcript} "\n";
	} else {
	    $param{limit}{package} = [];
	    print {$transcript} "Limit cleared.\n\n";
	}
    } elsif ($ctl eq 'limit') {
	my ($field,@options) = split /\s+/, $matches[0];
	$field = lc($field);
	if ($field =~ /^(?:clear|unset|blank)$/) {
	    %{$param{limit}} = ();
	    print {$transcript} "Limit cleared.\n\n";
	}
	elsif (exists $Debbugs::Status::fields{$field} or $field eq 'source') {
	    # %{$param{limit}} can actually contain regexes, but because they're
	    # not evaluated in Safe, DO NOT allow them through without
	    # fixing this.
	    $param{limit}{$field} = [@options];
	    print {$transcript} "Limiting to bugs with field '$field' containing at least one of ".join(', ',map {qq('$_')} @options)."\n";
	    print {$transcript} "Limit currently set to";
	    for my $limit_field (keys %{$param{limit}}) {
		print {$transcript} " '$limit_field':".join(', ',map {qq('$_')} @{$param{limit}{$limit_field}})."\n";
	    }
	    print {$transcript} "\n";
	}
	else {
	    print {$transcript} "Limit key $field not understood. Stopping processing here.\n\n";
	    $errors++;
	    # this needs to be fixed
	    syntax error for fixing it
	    last;
	}
    } elsif ($ctl eq 'affects') {
	my $add_remove = $matches[1];
	my $packages = $matches[2];
	# if there isn't a package given, assume that we should unset
	# affects; otherwise default to adding
	if (not defined $packages or
	    not length $packages) {
	    $packages = '';
	    $add_remove ||= '=';
	}
	elsif (not defined $add_remove or
	       not length $add_remove) {
	    $add_remove = '+';
	}
	eval {
	     affects(@{$param{common_control_options}},
		     bug => $ref,
		     package     => [splitpackages($packages)],
		     ($add_remove eq '+'?(add => 1):()),
		     ($add_remove eq '-'?(remove => 1):()),
		    );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to mark $ref as affecting package(s): ".cleanup_eval_fail($@,$debug)."\n";
	}

    } elsif ($ctl eq 'summary') {
	my $summary_msg = length($matches[1])?$matches[1]:undef;
	eval {
	    summary(@{$param{common_control_options}},
		    bug          => $ref,
		    summary      => $summary_msg,
		   );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to give $ref a summary: ".cleanup_eval_fail($@,$debug)."\n";
	}

    } elsif ($ctl eq 'outlook') {
	my $outlook_msg = length($matches[1])?$matches[1]:undef;
	eval {
	    outlook(@{$param{common_control_options}},
		    bug          => $ref,
		    outlook      => $outlook_msg,
		   );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to give $ref a outlook: ".cleanup_eval_fail($@,$debug)."\n";
	}

    } elsif ($ctl eq 'owner') {
	my $newowner = $matches[1];
	if ($newowner eq '!') {
	    $newowner = $param{replyto};
	}
	eval {
	    owner(@{$param{common_control_options}},
		  bug          => $ref,
		  owner        => $newowner,
		 );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to mark $ref as having an owner: ".cleanup_eval_fail($@,$debug)."\n";
	}
    } elsif ($ctl eq 'noowner') {
	eval {
	    owner(@{$param{common_control_options}},
		  bug          => $ref,
		  owner        => undef,
		 );
	};
	if ($@) {
	    $errors++;
	    print {$transcript} "Failed to mark $ref as not having an owner: ".cleanup_eval_fail($@,$debug)."\n";
	}
    } elsif ($ctl eq 'unarchive') {
	 eval {
	      bug_unarchive(@{$param{common_control_options}},
			    bug        => $ref,
			   );
	 };
	 if ($@) {
	      $errors++;
	 }
    } elsif ($ctl eq 'archive') {
	 eval {
	      bug_archive(@{$param{common_control_options}},
			  bug => $ref,
			  ignore_time => 1,
			  archive_unarchived => 0,
			 );
	 };
	 if ($@) {
	      $errors++;
	 }
    }
    if ($errors) {
	${$param{errors}}+=$errors;
    }
    return($errors,$terminate_control);
}

1;

__END__
