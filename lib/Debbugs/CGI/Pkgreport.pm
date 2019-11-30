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
use Exporter qw(import);

use IO::Scalar;
use Params::Validate qw(validate_with :types);

use Debbugs::Collection::Bug;

use Carp;
use List::AllUtils qw(apply);

use Debbugs::Config qw(:config :globals);
use Debbugs::CGI qw(:url :html :util);
use Debbugs::Common qw(:misc :util :date);
use Debbugs::Status qw(:status);
use Debbugs::Bugs qw(bug_filter);
use Debbugs::Packages qw(:mapping);

use Debbugs::Text qw(:templates);
use Encode qw(decode_utf8);

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
					 schema => {type => OBJECT,
						    optional => 1,
						   },
					},
			      );

     my $output_scalar = '';
     my $output = globify_scalar(\$output_scalar);

     my $package = $param{package};

     my $srcforpkg = $package;
     if ($param{binary}) {
	 $srcforpkg =
	     binary_to_source(source_only => 1,
			      scalar_only => 1,
			      binary => $package,
			      hash_slice(%param,qw(schema)),
			     );
     }

     my $showpkg = html_escape($package);
     my @maint = package_maintainer($param{binary}?'binary':'source',
				    $package,
				    hash_slice(%param,qw(schema)),
				   );
     if (@maint) {
	  print {$output} '<p>';
	  print {$output} (@maint > 1? "Maintainer for $showpkg is "
			   : "Maintainers for $showpkg are ") .
				package_links(maintainer => \@maint);
	  print {$output} ".</p>\n";
     }
     else {
	  print {$output} "<p>There is no maintainer for $showpkg. ".
	       "This means that this package no longer exists (or never existed). ".
		   "Please do not report new bugs against this package. </p>\n";
     }
     my @pkgs = source_to_binary(source => $srcforpkg,
				 hash_slice(%param,qw(schema)),
				 binary_only => 1,
				 # if there are distributions, only bother to
				 # show packages which are currently in a
				 # distribution.
				 @{$config{distributions}//[]} ?
				 (dist => [@{$config{distributions}}]) : (),
				) if defined $srcforpkg;
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
	  push @references, "to the <a href=\"$config{web_domain}/pseudo-packages$config{html_suffix}\">".
	       "list of other pseudo-packages</a>";
     }
     else {
	  if ($package and defined $config{package_pages} and length $config{package_pages}) {
	       push @references, sprintf "to the <a href=\"%s\">%s package page</a>",
		    html_escape("$config{package_pages}/$package"), html_escape("$package");
	  }
	  if (defined $config{package_tracking_domain} and
	      length $config{package_tracking_domain}) {
	       my $ptslink = $param{binary} ? $srcforpkg : $package;
	       # the pts only wants the source, and doesn't care about src: (#566089)
	       $ptslink =~ s/^src://;
	       push @references, q(to the <a href=").html_escape("$config{package_tracking_domain}/$ptslink").q(">Package Tracking System</a>);
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
     if (@maint) {
	  print {$output} "<p>If you find a bug not listed here, please\n";
	  printf {$output} "<a href=\"%s\">report it</a>.</p>\n",
	       html_escape("$config{web_domain}/Reporting$config{html_suffix}");
     }
     return decode_utf8($output_scalar);
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
			       spec   => {bug => {type => OBJECT,
						  isa => 'Debbugs::Bug',
						 },
					 },
			      );

     return fill_in_template(template => 'cgi/short_bug_status',
			     variables => {bug => $param{bug},
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
			       spec   => {bugs => {type => OBJECT,
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
					  schema   => {type => OBJECT,
						       optional => 1,
						      },
					 }
			      );
     my $bugs = $param{bugs};
     my %count;
     my $header = '';
     my $footer = "<h2 class=\"outstanding\">Summary</h2>\n";

     if ($bugs->count == 0) {
	  return "<HR><H2>No reports found!</H2></HR>\n";
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

     my $sorter = sub {$_[0]->id <=> $_[1]->id};
     if ($param{bug_rev}) {
	 $sorter = sub {$_[1]->id <=> $_[0]->id}
     }
     elsif ($param{bug_order} eq 'age') {
	 $sorter = sub {$_[0]->modified->epoch <=> $_[1]->modified->epoch};
     }
     elsif ($param{bug_order} eq 'agerev') {
	 $sorter = sub {$_[1]->modified->epoch <=> $_[0]->modified->epoch};
     }
     my @status;
     for my $bug ($bugs->sort($sorter)) {
	 next if
	     $bug->filter(repeat_merged => $param{repeatmerged},
			  seen_merged => \%seenmerged,
			  (keys %include ? (include => \%include):()),
			  (keys %exclude ? (exclude => \%exclude):()),
			 );

	 my $html = "<li>";	#<a href=\"%s\">#%d: %s</a>\n<br>",
	 $html .= short_bug_status_html(bug => $bug,
				       ) . "\n";
	 push @status, [ $bug, $html ];
     }
     # parse bug order indexes into subroutines
     my @order_subs =
	 map {
	     my $a = $_;
	     [map {parse_order_statement_to_subroutine($_)} @{$a}];
	 } @{$param{prior}};
     for my $entry (@status) {
	  my $key = "";
	  for my $i (0..$#order_subs) {
	       my $v = get_bug_order_index($order_subs[$i], $entry->[0]);
	       $count{"g_${i}_${v}"}++;
	       $key .= "_$v";
	  }
	  $section{$key} .= $entry->[1];
	  $count{"_$key"}++;
     }

     my $result = "";
     if ($param{ordering} eq "raw") {
	  $result .= "<UL class=\"bugs\">\n" . join("", map( { $_->[ 1 ] } @status ) ) . "</UL>\n";
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

sub parse_order_statement_to_subroutine {
    my ($statement) = @_;
    if (not defined $statement or not length $statement) {
	return sub {return 1};
    }
    croak "invalid statement '$statement'" unless
	$statement =~ /^(?:(package|tag|pending|severity) # field
			   = # equals
			   ([^=|\&,\+]+(?:,[^=|\&,+])*) #value
			   (\+|,|$) # joiner or end
		       )+ # one or more of these statements
		      /x;
    my @sub_bits;
    while ($statement =~ /(?<joiner>^|,|\+) # joiner
			  (?<field>package|tag|pending|severity) # field
			   = # equals
			   (?<value>[^=|\&,\+]+(?:,[^=|\&,\+])*) #value
			 /xg) {
	my $field = $+{field};
	my $value = $+{value};
	my $joiner = $+{joiner} // '';
	my @vals = apply {quotemeta($_)} split /,/,$value;
	if (length $joiner) {
	    if ($joiner eq '+') {
		push @sub_bits, ' and ';
	    }
	    else {
		push @sub_bits, ' or ';
	    }
	}
	my @vals_bits;
	for my $val (@vals) {
	    if ($field =~ /package|severity/o) {
		push @vals_bits, '$_[0]->status->'.$field.
		    ' eq q('.$val.')';
	    } elsif ($field eq 'tag') {
		push @vals_bits, '$_[0]->tags->is_set('.
		    'q('.$val.'))';
	    } elsif ($field eq 'pending') {
		push @vals_bits, '$_[0]->'.$field.
		    ' eq q('.$val.')';
	    }
	}
	push @sub_bits ,' ('.join(' or ',@vals_bits).') ';
    }
    # return a subroutine reference which determines whether an order statement
    # matches this bug
    my $sub = 'sub { return ('.join ("\n",@sub_bits).');};';
    my $subref = eval $sub;
    if ($@) {
	croak "Unable to generate subroutine: $@; $sub";
    }
    return $subref;
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
    my ($order,$bug) = @_;
    my $pos = 0;
    for my $el (@{$order}) {
	if ($el->($bug)) {
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






