# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# be listed here too.]
# Copyright 2008 by Don Armstrong <don@donarmstrong.com>.


package Debbugs::CGI::Pkgreport;

=head1 NAME

Debbugs::CGI::Pkgreport -- specific routines for the pkgreport cgi script

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 BUGS

None known.

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

use IO::Scalar;
use Params::Validate qw(validate_with :types);

use Debbugs::Config qw(:config :globals);
use Debbugs::CGI qw(:url :html :util);
use Debbugs::Common qw(:misc :util :date);
use Debbugs::Status qw(:status);
use Debbugs::Bugs qw(bug_filter);
use Debbugs::Packages qw(:mapping);

use Debbugs::Text qw(:templates);
use Encode qw(encode_utf8);

use POSIX qw(strftime);


BEGIN{
     ($VERSION) = q$Revision: 494 $ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (html => [qw(short_bug_status_html pkg_htmlizebugs),
			     ],
		     misc => [qw(generate_package_info),
			      qw(determine_ordering),
			     ],
		    );
     @EXPORT_OK = (qw());
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

=head2 generate_package_info

     generate_package_info($srcorbin,$package)

Generates the informational bits for a package and returns it

=cut

sub generate_package_info{
     my %param = validate_with(params => \@_,
			       spec  => {binary => {type => BOOLEAN,
						    default => 1,
						   },
					 package => {type => SCALAR,#|ARRAYREF,
						    },
					 options => {type => HASHREF,
						    },
					 bugs    => {type => ARRAYREF,
						    },
					},
			      );

     my $output_scalar = '';
     my $output = globify_scalar(\$output_scalar);

     my $package = $param{package};

     my %pkgsrc = %{getpkgsrc()};
     my $srcforpkg = $package;
     if ($param{binary} and exists $pkgsrc{$package}
	 and defined $pkgsrc{$package}) {
	  $srcforpkg = $pkgsrc{$package};
     }

     my $showpkg = html_escape($package);
     my $maintainers = getmaintainers();
     my $maint = $maintainers->{$srcforpkg};
     if (defined $maint) {
	  print {$output} '<p>';
	  print {$output} (($maint =~ /,/)? "Maintainer for $showpkg is "
			   : "Maintainers for $showpkg are ") .
				package_links(maint => $maint);
	  print {$output} ".</p>\n";
     }
     else {
	  print {$output} "<p>There is no maintainer for $showpkg. ".
	       "This means that this package no longer exists (or never existed). ".
		   "Please do not report new bugs against this package. </p>\n";
     }
     my @pkgs = getsrcpkgs($srcforpkg);
     @pkgs = grep( !/^\Q$package\E$/, @pkgs );
     if ( @pkgs ) {
	  @pkgs = sort @pkgs;
	  if ($param{binary}) {
	       print {$output} "<p>You may want to refer to the following packages that are part of the same source:\n";
	  }
	  else {
	       print {$output} "<p>You may want to refer to the following individual bug pages:\n";
	  }
	  #push @pkgs, $src if ( $src && !grep(/^\Q$src\E$/, @pkgs) );
	  print {$output} scalar package_links(package=>[@pkgs]);
	  print {$output} ".\n";
     }
     my @references;
     my $pseudodesc = getpseudodesc();
     if ($package and defined($pseudodesc) and exists($pseudodesc->{$package})) {
	  push @references, "to the <a href=\"http://$config{web_domain}/pseudo-packages$config{html_suffix}\">".
	       "list of other pseudo-packages</a>";
     }
     elsif (not defined $maint and not @{$param{bugs}}) {
	# don't bother printing out this information, because it's
	# already present above.
     	#  print {$output} "<p>There is no record of the " . html_escape($package) .
     	#       ($param{binary} ? " package" : " source package") .
     	# 	    ", and no bugs have been filed against it.</p>";
     }
     else {
	  if ($package and defined $config{package_pages} and length $config{package_pages}) {
	       push @references, sprintf "to the <a href=\"%s\">%s package page</a>",
		    html_escape("http://$config{package_pages}/$package"), html_escape("$package");
	  }
	  if (defined $config{subscription_domain} and
	      length $config{subscription_domain}) {
	       my $ptslink = $param{binary} ? $srcforpkg : $package;
	       # the pts only wants the source, and doesn't care about src: (#566089)
	       $ptslink =~ s/^src://;
	       push @references, q(to the <a href="http://).html_escape("$config{subscription_domain}/$ptslink").q(">Package Tracking System</a>);
	  }
	  # Only output this if the source listing is non-trivial.
	  if ($param{binary} and $srcforpkg) {
	       push @references,
		    "to the source package ".
			 package_links(src=>$srcforpkg,
				       options => $param{options}) .
			      "'s bug page";
	  }
     }
     if (@references) {
	  $references[$#references] = "or $references[$#references]" if @references > 1;
	  print {$output} "<p>You might like to refer ", join(", ", @references), ".</p>\n";
     }
     if (defined $maint) {
	  print {$output} "<p>If you find a bug not listed here, please\n";
	  printf {$output} "<a href=\"%s\">report it</a>.</p>\n",
	       html_escape("http://$config{web_domain}/Reporting$config{html_suffix}");
     }
     return encode_utf8($output_scalar);
}


=head2 short_bug_status_html

     print short_bug_status_html(status => read_bug(bug => 5),
                                 options => \%param,
                                );

=over

=item status -- status hashref as returned by read_bug

=item options -- hashref of options to pass to package_links (defaults
to an empty hashref)

=item bug_options -- hashref of options to pass to bug_links (default
to an empty hashref)

=item snippet -- optional snippet of information about the bug to
display below


=back



=cut

sub short_bug_status_html {
     my %param = validate_with(params => \@_,
			       spec   => {status => {type => HASHREF,
						    },
					  options => {type => HASHREF,
						      default => {},
						     },
					  bug_options => {type => HASHREF,
							  default => {},
							 },
					  snippet => {type => SCALAR,
						      default => '',
						     },
					 },
			      );

     my %status = %{$param{status}};

     $status{tags_array} = [sort(split(/\s+/, $status{tags}))];
     $status{date_text} = strftime('%a, %e %b %Y %T UTC', gmtime($status{date}));
     $status{mergedwith_array} = [split(/ /,$status{mergedwith})];

     my @blockedby= split(/ /, $status{blockedby});
     $status{blockedby_array} = [];
     if (@blockedby && $status{"pending"} ne 'fixed' && ! length($status{done})) {
	  for my $b (@blockedby) {
	       my %s = %{get_bug_status($b)};
	       next if (defined $s{pending} and $s{pending} eq 'fixed') or (defined $s{done} and length $s{done});
	       push @{$status{blockedby_array}},{bug_num => $b, subject => $s{subject}, status => \%s};
	  }
     }

     my @blocks= split(/ /, $status{blocks});
     $status{blocks_array} = [];
     if (@blocks && $status{"pending"} ne 'fixed' && ! length($status{done})) {
	  for my $b (@blocks) {
	       my %s = %{get_bug_status($b)};
	       next if (defined $s{pending} and $s{pending} eq 'fixed') or (defined $s{done} and length $s{done});
	       push @{$status{blocks_array}}, {bug_num => $b, subject => $s{subject}, status => \%s};
	  }
     }
     my $days = bug_archiveable(bug => $status{id},
				status => \%status,
				days_until => 1,
			       );
     $status{archive_days} = $days;
     return fill_in_template(template => 'cgi/short_bug_status',
			     variables => {status => \%status,
					   isstrongseverity => \&Debbugs::Status::isstrongseverity,
					   html_escape   => \&Debbugs::CGI::html_escape,
					   looks_like_number => \&Scalar::Util::looks_like_number,
					  },
			     hole_var  => {'&package_links' => \&Debbugs::CGI::package_links,
					   '&bug_links'     => \&Debbugs::CGI::bug_links,
					   '&version_url'   => \&Debbugs::CGI::version_url,
					   '&secs_to_english' => \&Debbugs::Common::secs_to_english,
					   '&strftime'      => \&POSIX::strftime,
					   '&maybelink'     => \&Debbugs::CGI::maybelink,
					  },
			    );
}


sub pkg_htmlizebugs {
     my %param = validate_with(params => \@_,
			       spec   => {bugs => {type => ARRAYREF,
						  },
					  names => {type => ARRAYREF,
						   },
					  title => {type => ARRAYREF,
						   },
					  prior => {type => ARRAYREF,
						   },
					  order => {type => ARRAYREF,
						   },
					  ordering => {type => SCALAR,
						      },
					  bugusertags => {type => HASHREF,
							  default => {},
							 },
					  bug_rev => {type => BOOLEAN,
						      default => 0,
						     },
					  bug_order => {type => SCALAR,
						       },
					  repeatmerged => {type => BOOLEAN,
							   default => 1,
							  },
					  include => {type => ARRAYREF,
						      default => [],
						     },
					  exclude => {type => ARRAYREF,
						      default => [],
						     },
					  this     => {type => SCALAR,
						       default => '',
						      },
					  options  => {type => HASHREF,
						       default => {},
						      },
					  dist     => {type => SCALAR,
						       optional => 1,
						      },
					 }
			      );
     my @bugs = @{$param{bugs}};

     my @status = ();
     my %count;
     my $header = '';
     my $footer = "<h2 class=\"outstanding\">Summary</h2>\n";

     if (@bugs == 0) {
	  return "<HR><H2>No reports found!</H2></HR>\n";
     }

     if ( $param{bug_rev} ) {
	  @bugs = sort {$b<=>$a} @bugs;
     }
     else {
	  @bugs = sort {$a<=>$b} @bugs;
     }
     my %seenmerged;

     my %common = (
		   'show_list_header' => 1,
		   'show_list_footer' => 1,
		  );

     my %section = ();
     # Make the include/exclude map
     my %include;
     my %exclude;
     for my $include (make_list($param{include})) {
	  next unless defined $include;
	  my ($key,$value) = split /\s*:\s*/,$include,2;
	  unless (defined $value) {
	       $key = 'tags';
	       $value = $include;
	  }
	  push @{$include{$key}}, split /\s*,\s*/, $value;
     }
     for my $exclude (make_list($param{exclude})) {
	  next unless defined $exclude;
	  my ($key,$value) = split /\s*:\s*/,$exclude,2;
	  unless (defined $value) {
	       $key = 'tags';
	       $value = $exclude;
	  }
	  push @{$exclude{$key}}, split /\s*,\s*/, $value;
     }

     foreach my $bug (@bugs) {
	  my %status = %{get_bug_status(bug=>$bug,
					(exists $param{dist}?(dist => $param{dist}):()),
					bugusertags => $param{bugusertags},
					(exists $param{version}?(version => $param{version}):()),
					(exists $param{arch}?(arch => $param{arch}):(arch => $config{default_architectures})),
				       )};
	  next unless %status;
	  next if bug_filter(bug => $bug,
			     status => \%status,
			     repeat_merged => $param{repeatmerged},
			     seen_merged => \%seenmerged,
			     (keys %include ? (include => \%include):()),
			     (keys %exclude ? (exclude => \%exclude):()),
			    );

	  my $html = "<li>"; #<a href=\"%s\">#%d: %s</a>\n<br>",
	       #bug_url($bug), $bug, html_escape($status{subject});
	  $html .= short_bug_status_html(status  => \%status,
					 options => $param{options},
					) . "\n";
	  push @status, [ $bug, \%status, $html ];
     }
     if ($param{bug_order} eq 'age') {
	  # MWHAHAHAHA
	  @status = sort {$a->[1]{log_modified} <=> $b->[1]{log_modified}} @status;
     }
     elsif ($param{bug_order} eq 'agerev') {
	  @status = sort {$b->[1]{log_modified} <=> $a->[1]{log_modified}} @status;
     }
     for my $entry (@status) {
	  my $key = "";
	  for my $i (0..$#{$param{prior}}) {
	       my $v = get_bug_order_index($param{prior}[$i], $entry->[1]);
	       $count{"g_${i}_${v}"}++;
	       $key .= "_$v";
	  }
	  $section{$key} .= $entry->[2];
	  $count{"_$key"}++;
     }

     my $result = "";
     if ($param{ordering} eq "raw") {
	  $result .= "<UL class=\"bugs\">\n" . join("", map( { $_->[ 2 ] } @status ) ) . "</UL>\n";
     }
     else {
	  $header .= "<div class=\"msgreceived\">\n<ul>\n";
	  my @keys_in_order = ("");
	  for my $o (@{$param{order}}) {
	       push @keys_in_order, "X";
	       while ((my $k = shift @keys_in_order) ne "X") {
		    for my $k2 (@{$o}) {
			 $k2+=0;
			 push @keys_in_order, "${k}_${k2}";
		    }
	       }
	  }
	  for my $order (@keys_in_order) {
	       next unless defined $section{$order};
	       my @ttl = split /_/, $order;
	       shift @ttl;
	       my $title = $param{title}[0]->[$ttl[0]] . " bugs";
	       if ($#ttl > 0) {
		    $title .= " -- ";
		    $title .= join("; ", grep {($_ || "") ne ""}
				   map { $param{title}[$_]->[$ttl[$_]] } 1..$#ttl);
	       }
	       $title = html_escape($title);

	       my $count = $count{"_$order"};
	       my $bugs = $count == 1 ? "bug" : "bugs";

	       $header .= "<li><a href=\"#$order\">$title</a> ($count $bugs)</li>\n";
	       if ($common{show_list_header}) {
		    my $count = $count{"_$order"};
		    my $bugs = $count == 1 ? "bug" : "bugs";
		    $result .= "<H2 CLASS=\"outstanding\"><a name=\"$order\"></a>$title ($count $bugs)</H2>\n";
	       }
	       else {
		    $result .= "<H2 CLASS=\"outstanding\">$title</H2>\n";
	       }
	       $result .= "<div class=\"msgreceived\">\n<UL class=\"bugs\">\n";
	       $result .= "\n\n\n\n";
	       $result .= $section{$order};
	       $result .= "\n\n\n\n";
	       $result .= "</UL>\n</div>\n";
	  } 
	  $header .= "</ul></div>\n";

	  $footer .= "<div class=\"msgreceived\">\n<ul>\n";
	  for my $i (0..$#{$param{prior}}) {
	       my $local_result = '';
	       foreach my $key ( @{$param{order}[$i]} ) {
		    my $count = $count{"g_${i}_$key"};
		    next if !$count or !$param{title}[$i]->[$key];
		    $local_result .= "<li>$count $param{title}[$i]->[$key]</li>\n";
	       }
	       if ( $local_result ) {
		    $footer .= "<li>$param{names}[$i]<ul>\n$local_result</ul></li>\n";
	       }
	  }
	  $footer .= "</ul>\n</div>\n";
     }

     $result = $header . $result if ( $common{show_list_header} );
     $result .= $footer if ( $common{show_list_footer} );
     return $result;
}

sub parse_order_statement_into_boolean {
    my ($statement,$status,$tags) = @_;

    if (not defined $tags) {
        $tags = {map { $_, 1 } split / /, $status->{"tags"}
                }
            if defined $status->{"tags"};

    }
    # replace all + with &&
    $statement =~ s/\+/&&/g;
    # replace all , with ||
    $statement =~ s/,/||/g;
    $statement =~ s{([^\&\|\=]+) # field
                    =
                    ([^\&\|\=]+) # value
              }{
                  my $ok = 0;
                  if ($1 eq 'tag') {
                      $ok = 1 if defined $tags->{$2};
                  } else {
                      $ok = 1 if defined $status->{$1} and
                          $status->{$1} eq $2;
                  }
                  $ok;
              }exg;
    # check that the parsed statement is just valid boolean statements
    if ($statement =~ /^([01\(\)\&\|]+)$/) {
        return eval "$1";
    } else {
        # this is an invalid boolean statement
        return 0;
    }
}

sub get_bug_order_index {
     my $order = shift;
     my $status = shift;
     my $pos = 0;
     my $tags = {map { $_, 1 } split / /, $status->{"tags"}
                }
         if defined $status->{"tags"};
     for my $el (@${order}) {
         if (not length $el or
             parse_order_statement_into_boolean($el,$status,$tags)
            ) {
             return $pos;
         }
         $pos++;
     }
     return $pos;
}

# sets: my @names; my @prior; my @title; my @order;

sub determine_ordering {
     my %param = validate_with(params => \@_,
			      spec => {cats => {type => HASHREF,
					       },
				       param => {type => HASHREF,
						},
				       ordering => {type => SCALARREF,
						   },
				       names    => {type => ARRAYREF,
						   },
				       pend_rev => {type => BOOLEAN,
						    default => 0,
						   },
				       sev_rev  => {type => BOOLEAN,
						    default => 0,
						   },
				       prior    => {type => ARRAYREF,
						   },
				       title    => {type => ARRAYREF,
						   },
				       order    => {type => ARRAYREF,
						   },
				      },
			     );
     $param{cats}{status}[0]{ord} = [ reverse @{$param{cats}{status}[0]{ord}} ]
	  if ($param{pend_rev});
     $param{cats}{severity}[0]{ord} = [ reverse @{$param{cats}{severity}[0]{ord}} ]
	  if ($param{sev_rev});

     my $i;
     if (defined $param{param}{"pri0"}) {
	  my @c = ();
	  $i = 0;
	  while (defined $param{param}{"pri$i"}) {
	       my $h = {};

	       my ($pri) = make_list($param{param}{"pri$i"});
	       if ($pri =~ m/^([^:]*):(.*)$/) {
		    $h->{"nam"} = $1; # overridden later if necesary
		    $h->{"pri"} = [ map { "$1=$_" } (split /,/, $2) ];
	       }
	       else {
		    $h->{"pri"} = [ split /,/, $pri ];
	       }

	       ($h->{"nam"}) = make_list($param{param}{"nam$i"})
		    if (defined $param{param}{"nam$i"});
	       $h->{"ord"} = [ map {split /\s*,\s*/} make_list($param{param}{"ord$i"}) ]
		    if (defined $param{param}{"ord$i"});
	       $h->{"ttl"} = [ map {split /\s*,\s*/} make_list($param{param}{"ttl$i"}) ]
		    if (defined $param{param}{"ttl$i"});

	       push @c, $h;
	       $i++;
	  }
	  $param{cats}{"_"} = [@c];
	  ${$param{ordering}} = "_";
     }

     ${$param{ordering}} = "normal" unless defined $param{cats}{${$param{ordering}}};

     sub get_ordering {
	  my @res;
	  my $cats = shift;
	  my $o = shift;
	  for my $c (@{$cats->{$o}}) {
	       if (ref($c) eq "HASH") {
		    push @res, $c;
	       }
	       else {
		    push @res, get_ordering($cats, $c);
	       }
	  }
	  return @res;
     }
     my @cats = get_ordering($param{cats}, ${$param{ordering}});

     sub toenglish {
	  my $expr = shift;
	  $expr =~ s/[+]/ and /g;
	  $expr =~ s/[a-z]+=//g;
	  return $expr;
     }
 
     $i = 0;
     for my $c (@cats) {
	  $i++;
	  push @{$param{prior}}, $c->{"pri"};
	  push @{$param{names}}, ($c->{"nam"} || "Bug attribute #" . $i);
	  if (defined $c->{"ord"}) {
	       push @{$param{order}}, $c->{"ord"};
	  }
	  else {
	       push @{$param{order}}, [ 0..$#{$param{prior}[-1]} ];
	  }
	  my @t = @{ $c->{"ttl"} } if defined $c->{ttl};
	  if (@t < $#{$param{prior}[-1]}) {
	       push @t, map { toenglish($param{prior}[-1][$_]) } @t..($#{$param{prior}[-1]});
	  }
	  push @t, $c->{"def"} || "";
	  push @{$param{title}}, [@t];
     }
}




1;


__END__






