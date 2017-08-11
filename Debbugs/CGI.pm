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
use Exporter qw(import);

use Debbugs::URI;
use HTML::Entities;
use Debbugs::Common qw(getparsedaddrs make_list);
use Params::Validate qw(validate_with :types);

use Debbugs::Config qw(:config);
use Debbugs::Status qw(splitpackages isstrongseverity);
use Debbugs::User qw();

use Mail::Address;
use POSIX qw(ceil);
use Storable qw(dclone);

use List::AllUtils qw(max);
use File::stat;
use Digest::MD5 qw(md5_hex);
use Carp;

use Debbugs::Text qw(fill_in_template);

our %URL_PARAMS = ();


BEGIN{
     ($VERSION) = q$Revision: 1.3 $ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (url    => [qw(bug_links bug_linklist maybelink),
				qw(set_url_params version_url),
				qw(submitterurl mainturl munge_url),
				qw(package_links bug_links),
			       ],
		     html   => [qw(html_escape htmlize_bugs htmlize_packagelinks),
				qw(maybelink htmlize_addresslinks htmlize_maintlinks),
			       ],
		     util   => [qw(cgi_parameters quitcgi),
			       ],
		     forms  => [qw(option_form form_options_and_normal_param)],
		     usertags => [qw(add_user)],
		     misc   => [qw(maint_decode)],
		     package_search => [qw(@package_search_key_order %package_search_keys)],
		     cache => [qw(calculate_etag etag_does_not_match)],
		     #status => [qw(getbugstatus)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
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
     $new_url->query_form(@new_param,
			  map {($_,$params{$_})}
			  sort keys %params);
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
				spec   => {package => {type => SCALAR|ARRAYREF,
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
    my ($msg, $status) = @_;
    $status //= '500 Internal Server Error';
    print "Status: $status\n";
    print "Content-Type: text/html\n\n";
    print fill_in_template(template=>'cgi/quit',
			   variables => {msg => $msg}
			  );
    exit 0;
}


=head1 HTML

=head2 htmlize_packagelinks

     htmlize_packagelinks

Given a scalar containing a list of packages separated by something
that L<Debbugs::CGI/splitpackages> can separate, returns a
formatted set of links to packages in html.

=cut

sub htmlize_packagelinks {
    my ($pkgs) = @_;
    return '' unless defined $pkgs and $pkgs ne '';
    my @pkglist = splitpackages($pkgs);

    carp "htmlize_packagelinks is deprecated, use package_links instead";

    return 'Package' . (@pkglist > 1 ? 's' : '') . ': ' .
           package_links(package =>\@pkglist,
			 class   => 'submitter'
			);
}

=head2 package_links

     join(', ', package_links(packages => \@packages))

Given a list of packages, return a list of html which links to the package

=over

=item package -- arrayref or scalar of package(s)

=item submitter -- arrayref or scalar of submitter(s)

=item src -- arrayref or scalar of source(s)

=item maintainer -- arrayref or scalar of maintainer(s)

=item links_only -- return only links, not htmlized links, defaults to
returning htmlized links.

=item class -- class of the a href, defaults to ''

=back

=cut

our @package_search_key_order = (package   => 'in package',
				 tag       => 'tagged',
				 severity  => 'with severity',
				 src       => 'in source package',
				 maint     => 'in packages maintained by',
				 submitter => 'submitted by',
				 owner     => 'owned by',
				 status    => 'with status',
				 affects   => 'which affect package',
				 correspondent => 'with mail from',
				 newest        => 'newest bugs',
				 bugs          => 'in bug',
				);
our %package_search_keys = @package_search_key_order;


sub package_links {
     my %param = validate_with(params => \@_,
			       spec   => {(map { ($_,{type => SCALAR|ARRAYREF,
						      optional => 1,
						     });
					    } keys %package_search_keys,
					  ),
					  links_only => {type => BOOLEAN,
							 default => 0,
							},
					  class => {type => SCALAR,
						    default => '',
						   },
					  separator => {type => SCALAR,
							default => ', ',
						       },
					  options => {type => HASHREF,
						      default => {},
						     },
					 },
			       normalize_keys =>
			       sub {
				    my ($key) = @_;
				    my %map = (source => 'src',
					       maintainer => 'maint',
					       pkg        => 'package',
					      );
				    return $map{$key} if exists $map{$key};
				    return $key;
			       }
			      );
     my %options = %{$param{options}};
     for ((keys %package_search_keys,qw(msg att))) {
	  delete $options{$_} if exists $options{$_};
     }
     my @links = ();
     for my $type (qw(src package)) {
	  push @links, map {my $t_type = $type;
			    if ($_ =~ s/^src://) {
				$t_type = 'src';
			    }
			    (munge_url('pkgreport.cgi?',
				       %options,
				       $t_type => $_,
				      ),
			     ($t_type eq 'src'?'src:':'').$_);
		       } make_list($param{$type}) if exists $param{$type};
     }
     for my $type (qw(maint owner submitter correspondent)) {
	  push @links, map {my $addr = getparsedaddrs($_);
			    $addr = defined $addr?$addr->address:'';
			    (munge_url('pkgreport.cgi?',
				       %options,
				       $type => $addr,
				      ),
			     $_);
		       } make_list($param{$type}) if exists $param{$type};
     }
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
					  separator => {type => SCALAR,
							default => ', ',
						       },
					  options => {type => HASHREF,
						      default => {},
						     },
					 },
			      );
     my %options = %{$param{options}};

     for (qw(bug)) {
	  delete $options{$_} if exists $options{$_};
     }
     my @links;
     push @links, map {(munge_url('bugreport.cgi?',
				  %options,
				  bug => $_,
				 ),
			$_);
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
     if (wantarray) {
	  return @return;
     }
     else {
	  return join($param{separator},@return);
     }
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
    if (not defined $regex and not defined $join) {
	 $links =~ s{(.*?)((?:(?:ftp|http|https)://[\S~-]+?/?)?)([\)\'\:\.\,]?(?:\s|\.<|$))}
		    {html_escape($1).(length $2?q(<a href=").html_escape($2).q(">).html_escape($2).q(</a>):'').html_escape($3)}geimo;
	 return $links;
    }
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

sub mainturl { package_links(maint => $_[0], links_only => 1); }
sub submitterurl { package_links(submitter => $_[0], links_only => 1); }
sub htmlize_maintlinks {
    my ($prefixfunc, $maints) = @_;
    carp "htmlize_maintlinks is deprecated";
    return htmlize_addresslinks($prefixfunc, \&mainturl, $maints);
}

=head2 bug_linklist

     bug_linklist($separator,$class,@bugs)

Creates a set of links to C<@bugs> separated by C<$separator> with
link class C<$class>.

XXX Use L<Params::Validate>; we want to be able to support query
arguments here too; we should be able to combine bug_links and this
function into one.

=cut


sub bug_linklist{
     my ($sep,$class,@bugs) = @_;
     carp "bug_linklist is deprecated; use bug_links instead";
     return scalar bug_links(bug=>\@bugs,class=>$class,separator=>$sep);
}


sub add_user {
     my ($user,$usertags,$bug_usertags,$seen_users,$cats,$hidden) = @_;
     $seen_users = {} if not defined $seen_users;
     $bug_usertags = {} if not defined $bug_usertags;
     $usertags = {} if not defined $usertags;
     $cats = {} if not defined $cats;
     $hidden = {} if not defined $hidden;
     return if exists $seen_users->{$user};
     $seen_users->{$user} = 1;

     my $u = Debbugs::User::get_user($user);

     my %vis = map { $_, 1 } @{$u->{"visible_cats"}};
     for my $c (keys %{$u->{"categories"}}) {
	  $cats->{$c} = $u->{"categories"}->{$c};
	  $hidden->{$c} = 1 unless defined $vis{$c};
     }
     for my $t (keys %{$u->{"tags"}}) {
	  $usertags->{$t} = [] unless defined $usertags->{$t};
	  push @{$usertags->{$t}}, @{$u->{"tags"}->{$t}};
     }

     %{$bug_usertags} = ();
     for my $t (keys %{$usertags}) {
	  for my $b (@{$usertags->{$t}}) {
	       $bug_usertags->{$b} = [] unless defined $bug_usertags->{$b};
	       push @{$bug_usertags->{$b}}, $t;
	  }
     }
}



=head1 Forms

=cut

=head2 form_options_and_normal_param

     my ($form_option,$param) = form_options_and_normal_param(\%param)
           if $param{form_options};
     my $form_option = form_options_and_normal_param(\%param)
           if $param{form_options};

Translates from special form_options to a set of parameters which can
be used to run the current page.

The idea behind this is to allow complex forms to relatively easily
cause options that the existing cgi scripts understand to be set.

Currently there are two commands which are understood:
combine, and concatenate.

=head3 combine

Combine works by entering key,value pairs into the parameters using
the key field option input field, and the value field option input
field.

For example, you would have

 <input type="hidden" name="_fo_combine_key_fo_searchkey_value_fo_searchvalue" value="1">

which would combine the _fo_searchkey and _fo_searchvalue input fields, so

 <input type="text" name="_fo_searchkey" value="foo">
 <input type="text" name="_fo_searchvalue" value="bar">

would yield foo=>'bar' in %param.

=head3 concatenate

Concatenate concatenates values into a single entry in a parameter

For example, you would have

 <input type="hidden" name="_fo_concatentate_into_foo_with_:_fo_blah_fo_bleargh" value="1">

which would combine the _fo_searchkey and _fo_searchvalue input fields, so

 <input type="text" name="_fo_blah" value="bar">
 <input type="text" name="_fo_bleargh" value="baz">

would yield foo=>'bar:baz' in %param.


=cut

my $form_option_leader = '_fo_';
sub form_options_and_normal_param{
     my ($orig_param) = @_;
     # all form_option parameters start with _fo_
     my ($param,$form_option) = ({},{});
     for my $key (keys %{$orig_param}) {
	  if ($key =~ /^\Q$form_option_leader\E/) {
	       $form_option->{$key} = $orig_param->{$key};
	  }
	  else {
	       $param->{$key} = $orig_param->{$key};
	  }
     }
     # at this point, we check for commands
 COMMAND: for my $key (keys %{$form_option}) {
	  $key =~ s/^\Q$form_option_leader\E//;
	  if (my ($key_name,$value_name) = 
	      $key =~ /combine_key(\Q$form_option_leader\E.+)
	      _value(\Q$form_option_leader\E.+)$/x
	     ) {
	       next unless defined $form_option->{$key_name};
	       next unless defined $form_option->{$value_name};
	       my @keys = make_list($form_option->{$key_name});
	       my @values = make_list($form_option->{$value_name});
	       for my $i (0 .. $#keys) {
		    last if $i > $#values;
		    next if not defined $keys[$i];
		    next if not defined $values[$i];
		    __add_to_param($param,
				   $keys[$i],
				   $values[$i],
				  );
	       }
	  }
	  elsif (my ($field,$concatenate_key,$fields) = 
		 $key =~ /concatenate_into_(.+?)((?:_with_[^_])?)
			  ((?:\Q$form_option_leader\E.+?)+)
			  $/x
		) {
	       if (length $concatenate_key) {
		    $concatenate_key =~ s/_with_//;
	       }
	       else {
		    $concatenate_key = ':';
	       }
	       my @fields = $fields =~ m/(\Q$form_option_leader\E.+?)(?:(?=\Q$form_option_leader\E)|$)/g;
	       my %field_list;
	       my $max_num = 0;
	       for my $f (@fields) {
		    next COMMAND unless defined $form_option->{$f};
		    $field_list{$f} = [make_list($form_option->{$f})];
		    $max_num = max($max_num,$#{$field_list{$f}});
	       }
	       for my $i (0 .. $max_num) {
		    next unless @fields == grep {$i <= $#{$field_list{$_}} and
						      defined $field_list{$_}[$i]} @fields;
		    __add_to_param($param,
				   $field,
				   join($concatenate_key,
					map {$field_list{$_}[$i]} @fields
				       )
				  );
	       }
	  }
     }
     return wantarray?($form_option,$param):$form_option;
}

=head2 option_form

     print option_form(template=>'pkgreport_options',
		       param   => \%param,
		       form_options => $form_options,
		      )



=cut

sub option_form{
     my %param = validate_with(params => \@_,
			       spec   => {template => {type => SCALAR,
						      },
					  variables => {type => HASHREF,
							default => {},
						       },
					  language => {type => SCALAR,
						       optional => 1,
						      },
					  param => {type => HASHREF,
						    default => {},
						   },
					  form_options => {type => HASHREF,
							   default => {},
							  },
					 },
			      );

     # First, we need to see if we need to add particular types of
     # parameters
     my $variables = dclone($param{variables});
     $variables->{param} = dclone($param{param});
     for my $key (keys %{$param{form_option}}) {
	  # strip out leader; shouldn't be anything here without one,
	  # but skip stupid things anyway
	  next unless $key =~ s/^\Q$form_option_leader\E//;
	  if ($key =~ /^add_(.+)$/) {
	       # this causes a specific parameter to be added
	       __add_to_param($variables->{param},
			      $1,
			      ''
			     );
	  }
	  elsif ($key =~ /^delete_(.+?)(?:_(\d+))?$/) {
	       next unless exists $variables->{param}{$1};
	       if (ref $variables->{param}{$1} eq 'ARRAY' and
		   defined $2 and
		   defined $variables->{param}{$1}[$2]
		  ) {
		    splice @{$variables->{param}{$1}},$2,1;
	       }
	       else {
		    delete $variables->{param}{$1};
	       }
	  }
	  # we'll add extra comands here once I figure out what they
	  # should be
     }
     # add in a few utility routines
     $variables->{output_select_options} = sub {
	  my ($options,$value) = @_;
	  my @options = @{$options};
	  my $output = '';
	  while (my ($o_value,$name) = splice @options,0,2) {
	       my $selected = '';
	       if (defined $value and $o_value eq $value) {
		    $selected = ' selected';
	       }
	       $output .= q(<option value=").html_escape($o_value).qq("$selected>).
		   html_escape($name).qq(</option>\n);
	  }
	  return $output;
     };
     $variables->{make_list} = sub { make_list(@_);
     };
     # now at this point, we're ready to create the template
     return Debbugs::Text::fill_in_template(template=>$param{template},
					    (exists $param{language}?(language=>$param{language}):()),
					    variables => $variables,
					    hole_var  => {'&html_escape' => \&html_escape,
							 },
					   );
}

sub __add_to_param{
     my ($param,$key,@values) = @_;

     if (exists $param->{$key} and not
	 ref $param->{$key}) {
	  @{$param->{$key}} = [$param->{$key},
			       @values
			      ];
     }
     else {
	  push @{$param->{$key}}, @values;
     }
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

=head1 cache

=head2 calculate_etags

    calculate_etags(files => [qw(list of files)],additional_data => [qw(any additional data)]);

=cut

sub calculate_etags {
    my %param =
	validate_with(params => \@_,
		      spec => {files => {type => ARRAYREF,
					 default => [],
					},
			       additional_data => {type => ARRAYREF,
						   default => [],
						  },
			      },
		     );
    my @additional_data = @{$param{additional_data}};
    for my $file (@{$param{files}}) {
	my $st = stat($file) or warn "Unable to stat $file: $!";
	push @additional_data,$st->mtime;
	push @additional_data,$st->size;
    }
    return(md5_hex(join('',sort @additional_data)));
}

=head2 etag_does_not_match

     etag_does_not_match(cgi=>$q,files=>[qw(list of files)],
         additional_data=>[qw(any additional data)])


Checks to see if the CGI request contains an etag which matches the calculated
etag.

If there wasn't an etag given, or the etag given doesn't match, return the etag.

If the etag does match, return 0.

=cut

sub etag_does_not_match {
    my %param =
	validate_with(params => \@_,
		      spec => {files => {type => ARRAYREF,
					 default => [],
					},
			       additional_data => {type => ARRAYREF,
						   default => [],
						  },
			       cgi => {type => OBJECT},
			      },
		     );
    my $submitted_etag =
	$param{cgi}->http('if-none-match');
    my $etag =
	calculate_etags(files=>$param{files},
			additional_data=>$param{additional_data});
    if (not defined $submitted_etag or
	length($submitted_etag) != 32
	or $etag ne $submitted_etag
       ) {
	return $etag;
    }
    if ($etag eq $submitted_etag) {
	return 0;
    }
}


1;


__END__






