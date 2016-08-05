# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2008 by Don Armstrong <don@donarmstrong.com>.
# $Id: perl_module_header.pm 1221 2008-05-19 15:00:40Z don $

package Debbugs::Recipients;

=head1 NAME

Debbugs::Recipients -- Determine recipients of messages from the bts

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 BUGS

None known.

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use Exporter qw(import);

BEGIN{
     ($VERSION) = q$Revision: 1221 $ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (add    => [qw(add_recipients)],
		     det    => [qw(determine_recipients)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];

}

use Debbugs::Config qw(:config);
use Params::Validate qw(:types validate_with);
use Debbugs::Common qw(:misc :util);
use Debbugs::Status qw(splitpackages isstrongseverity);

use Debbugs::Packages qw(binary_to_source);

use Debbugs::Mail qw(get_addresses);

use Carp;

=head2 add_recipients

     add_recipients(data => $data,
                    recipients => \%recipients;
                   );

Given data (from read_bug or similar) (or an arrayref of data),
calculates the addresses which need to receive mail involving this
bug.

=over

=item data -- Data from read_bug or similar; can be an arrayref of data

=item recipients -- hashref of recipient data structure; pass to
subsequent calls of add_recipients or

=item debug -- optional 


=back

=cut


sub add_recipients {
     # Data structure is:
     #   maintainer email address &c -> assoc of packages -> assoc of bug#'s
     my %param = validate_with(params => \@_,
			       spec   => {data => {type => HASHREF|ARRAYREF,
						  },
					  recipients => {type => HASHREF,
							},
					  debug => {type => HANDLE|SCALARREF,
						    optional => 1,
						   },
					  transcript => {type => HANDLE|SCALARREF,
							 optional => 1,
							},
					  actions_taken => {type => HASHREF,
							    default => {},
							   },
					  unknown_packages => {type => HASHREF,
							       default => {},
							      },
					 },
			      );

     $param{transcript} = globify_scalar($param{transcript});
     $param{debug} = globify_scalar($param{debug});
     if (ref ($param{data}) eq 'ARRAY') {
	  for my $data (@{$param{data}}) {
	       add_recipients(data => $data,
			      map {exists $param{$_}?($_,$param{$_}):()}
			      qw(recipients debug transcript actions_taken unknown_packages)
			     );
	  }
	  return;
     }
     my ($addmaint);
     my $ref = $param{data}{bug_num};
     for my $p (splitpackages($param{data}{package})) {
	  $p = lc($p);
	  if (defined $config{subscription_domain}) {
	       my @source_packages = binary_to_source(binary => $p,
						      source_only => 1,
						     );
	       if (@source_packages) {
		    for my $source (@source_packages) {
			 _add_address(recipients => $param{recipients},
				      address => "$source\@".$config{subscription_domain},
				      reason => $source,
				      type  => 'bcc',
				     );
		    }
	       }
	       else {
		    _add_address(recipients => $param{recipients},
				 address => "$p\@".$config{subscription_domain},
				 reason => $p,
				 type  => 'bcc',
				);
	       }
	  }
	  if (defined $param{data}{severity} and defined $config{strong_list} and
	      isstrongseverity($param{data}{severity})) {
	       _add_address(recipients => $param{recipients},
			    address => "$config{strong_list}\@".$config{list_domain},
			    reason => $param{data}{severity},
			    type  => 'bcc',
			   );
	  }
	  my @maints = package_maintainer(binary => $p);
	  if (@maints) {
	      print {$param{debug}} "MR|".join(',',@maints)."|$p|$ref|\n";
	      _add_address(recipients => $param{recipients},
			   address => \@maints,
			   reason => $p,
			   bug_num => $param{data}{bug_num},
			   type  => 'cc',
			  );
	      print {$param{debug}} "maintainer add >$p|".join(',',@maints)."<\n";
	  }
	  else {
	       print {$param{debug}} "maintainer none >$p<\n";
	       if (not exists $param{unknown_packages}{$p}) {
		   print {$param{transcript}} "Warning: Unknown package '$p'\n";
		   $param{unknown_packages}{$p} = 1;
	       }
	       print {$param{debug}} "MR|unknown-package|$p|$ref|\n";
	       _add_address(recipients => $param{recipients},
			    address => $config{unknown_maintainer_email},
			    reason => $p,
			    bug_num => $param{data}{bug_num},
			    type  => 'cc',
			   )
		    if defined $config{unknown_maintainer_email} and
			 length $config{unknown_maintainer_email};
	  }
      }
     if (defined $config{bug_subscription_domain} and
	 length $config{bug_subscription_domain}) {
	  _add_address(recipients => $param{recipients},
		       address    => 'bugs='.$param{data}{bug_num}.'@'.
		                     $config{bug_subscription_domain},
		       reason     => "bug $param{data}{bug_num}",
		       bug_num    => $param{data}{bug_num},
		       type       => 'bcc',
		      );
     }

     if (length $param{data}{owner}) {
	  $addmaint = $param{data}{owner};
	  print {$param{debug}} "MO|$addmaint|$param{data}{package}|$ref|\n";
	  _add_address(recipients => $param{recipients},
		       address => $addmaint,
		       reason => "owner of $param{data}{bug_num}",
		       bug_num => $param{data}{bug_num},
		       type  => 'cc',
		      );
	print {$param{debug}} "owner add >$param{data}{package}|$addmaint<\n";
     }
     if (exists $param{actions_taken}) {
	  if (exists $param{actions_taken}{done} and
	      $param{actions_taken}{done} and
	      length($config{done_list}) and
	      length($config{list_domain})
	     ) {
	       _add_address(recipients => $param{recipients},
			    type       => 'cc',
			    address    => $config{done_list}.'@'.$config{list_domain},
			    bug_num    => $param{data}{bug_num},
			    reason     => "bug $param{data}{bug_num} done",
			   );
	  }
	  if (exists $param{actions_taken}{forwarded} and
	      $param{actions_taken}{forwarded} and
	      length($config{forward_list}) and
	      length($config{list_domain})
	     ) {
	       _add_address(recipients => $param{recipients},
			    type       => 'cc',
			    address    => $config{forward_list}.'@'.$config{list_domain},
			    bug_num    => $param{data}{bug_num},
			    reason     => "bug $param{data}{bug_num} forwarded",
			   );
	  }
     }
}

=head2 determine_recipients

     my @recipients = determine_recipients(recipients => \%recipients,
                                           bcc => 1,
                                          );
     my %recipients => determine_recipients(recipients => \%recipients,);

     # or a crazy example:
     send_mail_message(message => $message,
                       recipients =>
                        [make_list(
                          values %{{determine_recipients(
                                recipients => \%recipients)
                                  }})
                        ],
                      );

Using the recipient hashref, determines the set of recipients.

If you specify one of C<bcc>, C<cc>, or C<to>, you will receive only a
LIST of recipients which the main should be Bcc'ed, Cc'ed, or To'ed
respectively. By default, a LIST with keys bcc, cc, and to is returned
with ARRAYREF values corresponding to the users to whom a message
should be sent.

=over

=item address_only -- whether to only return mail addresses without reasons or realnamesq

=back

Passing more than one of bcc, cc or to is a fatal error.

=cut

sub determine_recipients {
     my %param = validate_with(params => \@_,
			       spec   => {recipients => {type => HASHREF,
							},
					  bcc        => {type => BOOLEAN,
							 default => 0,
							},
					  cc         => {type => BOOLEAN,
							 default => 0,
							},
					  to         => {type => BOOLEAN,
							 default => 0,
							},
					  address_only => {type => BOOLEAN,
							   default => 0,
							  }
					 },
			      );

     if (1 < scalar grep {$param{$_}} qw(to cc bcc)) {
	  croak "Passing more than one of to, cc, or bcc is non-sensical";
     }

     my %final_recipients;
     # start with the to recipients
     for my $addr (keys %{$param{recipients}}) {
	  my $level = 'bcc';
	  my @reasons;
	  for my $reason (keys %{$param{recipients}{$addr}}) {
	       my @bugs;
	       for my $bug (keys %{$param{recipients}{$addr}{$reason}}) {
		    push @bugs, $bug;
		    my $t_level = $param{recipients}{$addr}{$reason}{$bug};
		    if ($level eq 'to' or
			$t_level eq 'to') {
			 $level = 'to';
		    }
		    elsif ($t_level eq 'cc') {
			 $level = 'cc';
		    }
	       }
	       # RFC 2822 comments cannot contain specials and
	       # unquoted () or \; there's no reason for us to allow
	       # insane things here, though, so we restrict this even
	       # more to 20-7E ( -~)
	       $reason =~ s/\\/\\\\/g;
	       $reason =~ s/([\)\(])/\\$1/g;
	       $reason =~ s/[^\x20-\x7E]//g;
	       push @reasons, $reason . ' for {'.join(',',@bugs).'}';
	  }
	  if ($param{address_only}) {
	       push @{$final_recipients{$level}}, get_addresses($addr);
	  }
	  else {
	       push @{$final_recipients{$level}}, $addr . ' ('.join(', ',@reasons).')';
	  }
     }
     for (qw(to cc bcc)) {
	  if ($param{$_}) {
	       if (exists $final_recipients{$_}) {
		    return @{$final_recipients{$_}||[]};
	       }
	       return ();
	  }
     }
     return %final_recipients;
}


=head1 PRIVATE FUNCTIONS

=head2 _add_address

	  _add_address(recipients => $param{recipients},
		       address => $addmaint,
		       reason => $param{data}{package},
		       bug_num => $param{data}{bug_num},
		       type  => 'cc',
		      );


=cut


sub _add_address {
     my %param = validate_with(params => \@_,
			       spec => {recipients => {type => HASHREF,
						      },
					bug_num    => {type => SCALAR,
						       regex => qr/^\d*$/,
						       default => '',
						      },
					reason     => {type => SCALAR,
						       default => '',
						      },
					address    => {type => SCALAR|ARRAYREF,
						      },
					type       => {type => SCALAR,
						       default => 'cc',
						       regex   => qr/^(?:b?cc|to)$/i,
						      },
				       },
			      );
     for my $addr (make_list($param{address})) {
	  if (lc($param{type}) eq 'bcc' and
	      exists $param{recipients}{$addr}{$param{reason}}{$param{bug_num}}
	     ) {
	       next;
	  }
	  elsif (lc($param{type}) eq 'cc' and
		 exists $param{recipients}{$addr}{$param{reason}}{$param{bug_num}}
		 and $param{recipients}{$addr}{$param{reason}}{$param{bug_num}} eq 'to'
		) {
	       next;
	  }
	  $param{recipients}{$addr}{$param{reason}}{$param{bug_num}} = lc($param{type});
     }
}

1;


__END__






