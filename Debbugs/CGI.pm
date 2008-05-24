# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# go here too.]
# Copyright 2007 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::CGI;

=head1 NAME

Debbugs::CGI -- General routines for the cgi scripts

=head1 SYNOPSIS

use Debbugs::CGI qw(:url :html);

html_escape(bug_url($ref,mbox=>'yes',mboxstatus=>'yes'));

=head1 DESCRIPTION

This module is a replacement for parts of common.pl; subroutines in
common.pl will be gradually phased out and replaced with equivalent
(or better) functionality here.

=head1 BUGS

None known.

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);
use Debbugs::URI;
use HTML::Entities;
use Debbugs::Common qw(getparsedaddrs make_list);
use Params::Validate qw(validate_with :types);
use Debbugs::Config qw(:config);
use Debbugs::Status qw(splitpackages isstrongseverity);
use Mail::Address;
use POSIX qw(ceil);
use Storable qw(dclone);

use Carp;

use Debbugs::Text qw(fill_in_template);

our %URL_PARAMS = ();


BEGIN{
     ($VERSION) = q$Revision: 1.3 $ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (url    => [qw(bug_url bug_links bug_linklist maybelink),
				qw(set_url_params pkg_url version_url),
				qw(submitterurl mainturl munge_url),
				qw(package_links bug_links),
			       ],
		     html   => [qw(html_escape htmlize_bugs htmlize_packagelinks),
				qw(maybelink htmlize_addresslinks htmlize_maintlinks),
			       ],
		     util   => [qw(cgi_parameters quitcgi),
			       ],
		     misc   => [qw(maint_decode)],
		     #status => [qw(getbugstatus)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(qw(url html util misc));
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}



=head2 set_url_params

     set_url_params($uri);


Sets the url params which will be used to generate urls.

=cut

sub set_url_params{
     if (@_ > 1) {
	  %URL_PARAMS = @_;
     }
     else {
	  my $url = Debbugs::URI->new($_[0]||'');
	  %URL_PARAMS = %{$url->query_form_hash};
     }
}


=head2 bug_url

     bug_url($ref,mbox=>'yes',mboxstat=>'yes');

Constructs urls which point to a specific

XXX use Params::Validate

=cut

sub bug_url{
     my $ref = shift;
     my %params;
     if (@_ % 2) {
	  shift;
	  %params = (%URL_PARAMS,@_);
     }
     else {
	  %params = @_;
     }
     return munge_url('bugreport.cgi?',%params,bug=>$ref);
}

sub pkg_url{
     my %params;
     if (@_ % 2) {
	  shift;
	  %params = (%URL_PARAMS,@_);
     }
     else {
	  %params = @_;
     }
     return munge_url('pkgreport.cgi?',%params);
}

=head2 munge_url

     my $url = munge_url($url,%params_to_munge);

Munges a url, replacing parameters with %params_to_munge as appropriate.

=cut

sub munge_url {
     my $url = shift;
     my %params = @_;
     my $new_url = Debbugs::URI->new($url);
     my @old_param = $new_url->query_form();
     my @new_param;
     while (my ($key,$value) = splice @old_param,0,2) {
	  push @new_param,($key,$value) unless exists $params{$key};
     }
     $new_url->query_form(@new_param,%params);
     return $new_url->as_string;
}


=head2 version_url

     version_url(package => $package,found => $found,fixed => $fixed)

Creates a link to the version cgi script

=over

=item package -- source package whose graph to display

=item found -- arrayref of found versions

=item fixed -- arrayref of fixed versions

=item width -- optional width of graph

=item height -- optional height of graph

=item info -- display html info surrounding graph; defaults to 1 if
width and height are not passed.

=item collapse -- whether to collapse the graph; defaults to 1 if
width and height are passed.

=back

=cut

sub version_url{
     my %params = validate_with(params => \@_,
				spec   => {package => {type => SCALAR,
						      },
					   found   => {type => ARRAYREF,
						       default => [],
						      },
					   fixed   => {type => ARRAYREF,
						       default => [],
						      },
					   width   => {type => SCALAR,
						       optional => 1,
						      },
					   height  => {type => SCALAR,
						       optional => 1,
						      },
					   absolute => {type => BOOLEAN,
							default => 0,
						       },
					   collapse => {type => BOOLEAN,
							default => 1,
						       },
					   info     => {type => BOOLEAN,
							optional => 1,
						       },
					  }
			       );
     if (not defined $params{width} and not defined $params{height}) {
	  $params{info} = 1 if not exists $params{info};
     }
     my $url = Debbugs::URI->new('version.cgi?');
     $url->query_form(%params);
     return $url->as_string;
}

=head2 html_escape

     html_escape($string)

Escapes html entities by calling HTML::Entities::encode_entities;

=cut

sub html_escape{
     my ($string) = @_;

     return HTML::Entities::encode_entities($string,q(<>&"'));
}

=head2 cgi_parameters

     cgi_parameters

Returns all of the cgi_parameters from a CGI script using CGI::Simple

=cut

sub cgi_parameters {
     my %options = validate_with(params => \@_,
				 spec   => {query   => {type => OBJECT,
						        can  => 'param',
						       },
					    single  => {type => ARRAYREF,
							default => [],
						       },
					    default => {type => HASHREF,
							default => {},
						       },
					   },
				);
     my $q = $options{query};
     my %single;
     @single{@{$options{single}}} = (1) x @{$options{single}};
     my %param;
     for my $paramname ($q->param) {
	  if ($single{$paramname}) {
	       $param{$paramname} = $q->param($paramname);
	  }
	  else {
	       $param{$paramname} = [$q->param($paramname)];
	  }
     }
     for my $default (keys %{$options{default}}) {
	  if (not exists $param{$default}) {
	       # We'll clone the reference here to avoid surprises later.
	       $param{$default} = ref($options{default}{$default})?
		    dclone($options{default}{$default}):$options{default}{$default};
	  }
     }
     return %param;
}


sub quitcgi {
    my $msg = shift;
    print "Content-Type: text/html\n\n";
    print fill_in_template(template=>'cgi/quit',
			   variables => {msg => $msg}
			  );
    exit 0;
}


=head HTML

=head2 htmlize_packagelinks

     htmlize_packagelinks

Given a scalar containing a list of packages separated by something
that L<Debbugs::CGI/splitpackages> can separate, returns a
formatted set of links to packages.

=cut

sub htmlize_packagelinks {
    my ($pkgs) = @_;
    return '' unless defined $pkgs and $pkgs ne '';
    my @pkglist = splitpackages($pkgs);

    carp "htmlize_packagelinks is deprecated";

    return 'Package' . (@pkglist > 1 ? 's' : '') . ': ' .
           join(', ',
                package_links(package =>\@pkglist,
			      class   => 'submitter'
			     )
           );
}

=head2 package_links

     join(', ', package_links(packages => \@packages))

Given a list of packages, return a list of html which links to the package

=over

=item package -- arrayref or scalar of package(s)

=item submitter -- arrayref or scalar of submitter(s)

=item source -- arrayref or scalar of source(s)

=item maintainer -- arrayref or scalar of maintainer(s)

=item links_only -- return only links, not htmlized links, defaults to
returning htmlized links.

=item class -- class of the a href, defaults to ''

=back

=cut

sub package_links {
     my %param = validate_with(params => \@_,
			       spec   => {package => {type => SCALAR|ARRAYREF,
						      optional => 1,
						     },
					  source  => {type => SCALAR|ARRAYREF,
						      optional => 1,
						     },
					  maintainer => {type => SCALAR|ARRAYREF,
							 optional => 1,
							},
					  submitter => {type => SCALAR|ARRAYREF,
							optional => 1,
						       },
					  owner     => {type => SCALAR|ARRAYREF,
							optional => 1,
						       },
					  links_only => {type => BOOLEAN,
							 default => 0,
							},
					  class => {type => SCALAR,
						    default => '',
						   },
					  separator => {type => SCALAR,
							default => ', ',
						       },
					 },
			      );
     my @links = ();
     push @links, map {(pkg_url(source => $_),$_)
		  } make_list($param{source}) if exists $param{source};
     push @links, map {my $addr = getparsedaddrs($_);
		       $addr = defined $addr?$addr->address:'';
		       (pkg_url(maint => $addr),$_)
		  } make_list($param{maintainer}) if exists $param{maintainer};
     push @links, map {my $addr = getparsedaddrs($_);
		       $addr = defined $addr?$addr->address:'';
		       (pkg_url(owner => $addr),$_)
		  } make_list($param{owner}) if exists $param{owner};
     push @links, map {my $addr = getparsedaddrs($_);
		       $addr = defined $addr?$addr->address:'';
		       (pkg_url(submitter => $addr),$_)
		  } make_list($param{submitter}) if exists $param{submitter};
     push @links, map {(pkg_url(pkg => $_),
			html_escape($_))
		  } make_list($param{package}) if exists $param{package};
     my @return = ();
     my ($link,$link_name);
     my $class = '';
     if (length $param{class}) {
	  $class = q( class=").html_escape($param{class}).q(");
     }
     while (($link,$link_name) = splice(@links,0,2)) {
	  if ($param{links_only}) {
	       push @return,$link
	  }
	  else {
	       push @return,
		    qq(<a$class href=").
			 html_escape($link).q(">).
			      html_escape($link_name).q(</a>);
	  }
     }
     if (wantarray) {
	  return @return;
     }
     else {
	  return join($param{separator},@return);
     }
}

=head2 bug_links

     join(', ', bug_links(bug => \@packages))

Given a list of bugs, return a list of html which links to the bugs

=over

=item bug -- arrayref or scalar of bug(s)

=item links_only -- return only links, not htmlized links, defaults to
returning htmlized links.

=item class -- class of the a href, defaults to ''

=back

=cut

sub bug_links {
     my %param = validate_with(params => \@_,
			       spec   => {bug => {type => SCALAR|ARRAYREF,
						  optional => 1,
						 },
					  links_only => {type => BOOLEAN,
							 default => 0,
							},
					  class => {type => SCALAR,
						    default => '',
						   },
					 },
			      );
     my @links;
     push @links, map {(bug_url($_),$_)
		  } make_list($param{bug}) if exists $param{bug};
     my @return;
     my ($link,$link_name);
     my $class = '';
     if (length $param{class}) {
	  $class = q( class=").html_escape($param{class}).q(");
     }
     while (($link,$link_name) = splice(@links,0,2)) {
	  if ($param{links_only}) {
	       push @return,$link
	  }
	  else {
	       push @return,
		    qq(<a$class href=").
			 html_escape($link).q(">).
			      html_escape($link_name).q(</a>);
	  }
     }
     return @return;
}



=head2 maybelink

     maybelink($in);
     maybelink('http://foobarbaz,http://bleh',qr/[, ]+/);
     maybelink('http://foobarbaz,http://bleh',qr/[, ]+/,', ');


In the first form, links the link if it looks like a link. In the
second form, first splits based on the regex, then reassembles the
link, linking things that look like links. In the third form, rejoins
the split links with commas and spaces.

=cut

sub maybelink {
    my ($links,$regex,$join) = @_;
    $join = ' ' if not defined $join;
    my @return;
    my @segments;
    if (defined $regex) {
	 @segments = split $regex, $links;
    }
    else {
	 @segments = ($links);
    }
    for my $in (@segments) {
	 if ($in =~ /^[a-zA-Z0-9+.-]+:/) { # RFC 1738 scheme
	      push @return, qq{<a href="$in">} . html_escape($in) . '</a>';
	 } else {
	      push @return, html_escape($in);
	 }
    }
    return @return?join($join,@return):'';
}


=head2 htmlize_addresslinks

     htmlize_addresslinks($prefixfunc,$urlfunc,$addresses,$class);


Generate a comma-separated list of HTML links to each address given in
$addresses, which should be a comma-separated list of RFC822
addresses. $urlfunc should be a reference to a function like mainturl
or submitterurl which returns the URL for each individual address.


=cut

sub htmlize_addresslinks {
     my ($prefixfunc, $urlfunc, $addresses,$class) = @_;
     carp "htmlize_addresslinks is deprecated";

     $class = defined $class?qq(class="$class" ):'';
     if (defined $addresses and $addresses ne '') {
	  my @addrs = getparsedaddrs($addresses);
	  my $prefix = (ref $prefixfunc) ?
	       $prefixfunc->(scalar @addrs):$prefixfunc;
	  return $prefix .
	       join(', ', map
		    { sprintf qq(<a ${class}).
			   'href="%s">%s</a>',
				$urlfunc->($_->address),
				     html_escape($_->format) ||
					  '(unknown)'
				     } @addrs
		   );
     }
     else {
	  my $prefix = (ref $prefixfunc) ?
	       $prefixfunc->(1) : $prefixfunc;
	  return sprintf '%s<a '.$class.'href="%s">(unknown)</a>',
	       $prefix, $urlfunc->('');
     }
}

sub emailfromrfc822{
     my $addr = getparsedaddrs($_[0] || "");
     $addr = defined $addr?$addr->address:'';
     return $addr;
}

sub mainturl { pkg_url(maint => emailfromrfc822($_[0])); }
sub submitterurl { pkg_url(submitter => emailfromrfc822($_[0])); }
sub htmlize_maintlinks {
    my ($prefixfunc, $maints) = @_;
    carp "htmlize_maintlinks is deprecated";
    return htmlize_addresslinks($prefixfunc, \&mainturl, $maints);
}


our $_maintainer;
our $_maintainer_rev;

=head2 bug_linklist

     bug_linklist($separator,$class,@bugs)

Creates a set of links to C<@bugs> separated by C<$separator> with
link class C<$class>.

XXX Use L<Params::Validate>; we want to be able to support query
arguments here too; we should be able to combine bug_links and this
function into one. [Hell, bug_url should be one function with this one
too.]

=cut


sub bug_linklist{
     my ($sep,$class,@bugs) = @_;
     return join($sep,bug_links(bug=>\@bugs,class=>$class));
}


=head1 misc

=cut

=head2 maint_decode

     maint_decode

Decodes the funky maintainer encoding.

Don't ask me what in the world it does.

=cut

sub maint_decode {
     my @input = @_;
     return () unless @input;
     my @output;
     for my $input (@input) {
	  my $decoded = $input;
	  $decoded =~ s/-([^_]+)/-$1_-/g;
	  $decoded =~ s/_/-20_/g;
	  $decoded =~ s/^,(.*),(.*),([^,]+)$/$1-40_$2-20_-28_$3-29_/;
	  $decoded =~ s/^([^,]+),(.*),(.*),/$1-20_-3c_$2-40_$3-3e_/;
	  $decoded =~ s/\./-2e_/g;
	  $decoded =~ s/-([0-9a-f]{2})_/pack('H*',$1)/ge;
	  push @output,$decoded;
     }
     wantarray ? @output : $output[0];
}


1;


__END__






