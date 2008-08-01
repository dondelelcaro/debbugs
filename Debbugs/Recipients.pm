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
use base qw(Exporter);

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
					 },
			      );
     if (ref ($param{data}) eq 'ARRAY') {
	  for (@{$param{data}}) {
	       add_recipients(map {exists $param{$_}?:($_,$param{$_}):()}
			      qw(recipients debug)
			     );
	  }
     }
     my ($p, $addmaint);
     my $anymaintfound=0; my $anymaintnotfound=0;
     for my $p (splitpackages($param{data}{package})) {
	  $p = lc($p);
	  if (defined $config{subscription_domain}) {
	       my @source_packages = binarytosource($p);
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
	  if (defined(getmaintainers->{$p})) {
	       $addmaint= getmaintainers->{$p};
	       print {$transcript} "MR|$addmaint|$p|$ref|\n" if $dl>2;
	       _add_address(recipients => $param{recipients},
			    address => $addmaint,
			    reason => $p,
			    bug_num => $param{data}{bug_num},
			    type  => 'cc',
			   );
	       print "maintainer add >$p|$addmaint<\n" if $debug;
	  }
	  else { 
	       print "maintainer none >$p<\n" if $debug; 
	       print {$transcript} "Warning: Unknown package '$p'\n";
	       print {$transcript} "MR|unknown-package|$p|$ref|\n" if $dl>2;
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
		       address    => 'bug='.$param{data}{bug_num}.'@'.
		                     $config{bug_subscription_domain},
		       reason     => "bug $param{data}{bug_num}",
		       bug_num    => $param{data}{bug_num},
		       type       => 'bcc',
		      );
     }

     if (length $param{data}{owner}) {
	  $addmaint = $param{data}{owner};
	  print {$transcript} "MO|$addmaint|$param{data}{package}|$ref|\n" if $dl>2;
	  _add_address(recipients => $param{recipients},
		       address => $addmaint,
		       reason => "owner of $param{data}{bug_num}",
		       bug_num => $param{data}{bug_num},
		       type  => 'cc',
		      );
	print "owner add >$param{data}{package}|$addmaint<\n" if $debug;
     }
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
						       regex   => qr/^b?cc/i,
						      },
				       },
			      );
     for my $addr (make_list($param{address})) {
	  if (lc($param{type}) eq 'bcc' and 
	      exists $param{recipients}{$addr}{$param{reason}}{$param{bug_num}}
	     ) {
	       next;
	  }
	  $param{recipients}{$addr}{$param{reason}}{$param{bug_num}} = $param{type};
     }
}

1;


__END__






