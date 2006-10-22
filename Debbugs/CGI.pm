
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
use Debbugs::Common qw();
use Params::Validate qw(validate_with :types);
use Debbugs::Config qw(:config);
use Mail::Address;
use POSIX qw(ceil);

my %URL_PARAMS = ();


BEGIN{
     ($VERSION) = q$Revision: 1.3 $ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (url    => [qw(bug_url bug_links bug_linklist maybelink),
				qw(set_url_params pkg_url version_url),
			       ],
		     html   => [qw(html_escape htmlize_bugs htmlize_packagelinks),
				qw(maybelink htmlize_addresslinks),
			       ],
		     util   => [qw(getparsedaddrs)]
		     #status => [qw(getbugstatus)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(qw(url html util));
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
     my $url = Debbugs::URI->new('bugreport.cgi?');
     $url->query_form(bug=>$ref,%params);
     return $url->as_string;
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
     my $url = Debbugs::URI->new('pkgreport.cgi?');
     $url->query_form(%params);
     return $url->as_string;
}

=head2 version_url

     version_url($package,$found,$fixed)

Creates a link to the version cgi script

=cut

sub version_url{
     my ($package,$found,$fixed) = @_;
     my $url = Debbugs::URI->new('version.cgi?');
     $url->query_form(package => $package,
		      found   => $found,
		      fixed   => $fixed,
		     );
     return $url->as_string;
}

=head2 html_escape

     html_escape($string)

Escapes html entities by calling HTML::Entities::encode_entities;

=cut

sub html_escape{
     my ($string) = @_;

     return HTML::Entities::encode_entities($string)
}

my %common_bugusertags;

# =head2 get_bug_status
# 
#      my $status = getbugstatus($bug_num)
# 
#      my $status = getbugstatus($bug_num,$bug_index)
# 
# 
# =cut
# 
# sub get_bug_status {
#     my ($bugnum,$bugidx) = @_;
# 
#     my %status;
# 
#     if (defined $bugidx and exists $bugidx->{$bugnum}) {
# 	%status = %{ $bugidx->{$bugnum} };
# 	$status{pending} = $status{ status };
# 	$status{id} = $bugnum;
# 	return \%status;
#     }
# 
#     my $location = getbuglocation($bugnum, 'summary');
#     return {} if not length $location;
#     %status = %{ readbug( $bugnum, $location ) };
#     $status{id} = $bugnum;
# 
# 
#     if (defined $common_bugusertags{$bugnum}) {
#         $status{keywords} = "" unless defined $status{keywords};
#         $status{keywords} .= " " unless $status{keywords} eq "";
#         $status{keywords} .= join(" ", @{$common_bugusertags{$bugnum}});
#     }
#     $status{tags} = $status{keywords};
#     my %tags = map { $_ => 1 } split ' ', $status{tags};
# 
#     $status{"package"} =~ s/\s*$//;
#     $status{"package"} = 'unknown' if ($status{"package"} eq '');
#     $status{"severity"} = 'normal' if ($status{"severity"} eq '');
# 
#     $status{"pending"} = 'pending';
#     $status{"pending"} = 'forwarded'	    if (length($status{"forwarded"}));
#     $status{"pending"} = 'pending-fixed'    if ($tags{pending});
#     $status{"pending"} = 'fixed'	    if ($tags{fixed});
# 
#     my @versions;
#     if (defined $common_version) {
#         @versions = ($common_version);
#     } elsif (defined $common_dist) {
#         @versions = getversions($status{package}, $common_dist, $common_arch);
#     }
# 
#     # TODO: This should probably be handled further out for efficiency and
#     # for more ease of distinguishing between pkg= and src= queries.
#     my @sourceversions = makesourceversions($status{package}, $common_arch,
#                                             @versions);
# 
#     if (@sourceversions) {
#         # Resolve bugginess states (we might be looking at multiple
#         # architectures, say). Found wins, then fixed, then absent.
#         my $maxbuggy = 'absent';
#         for my $version (@sourceversions) {
#             my $buggy = buggyversion($bugnum, $version, \%status);
#             if ($buggy eq 'found') {
#                 $maxbuggy = 'found';
#                 last;
#             } elsif ($buggy eq 'fixed' and $maxbuggy ne 'found') {
#                 $maxbuggy = 'fixed';
#             }
#         }
#         if ($maxbuggy eq 'absent') {
#             $status{"pending"} = 'absent';
#         } elsif ($maxbuggy eq 'fixed') {
#             $status{"pending"} = 'done';
#         }
#     }
#     
#     if (length($status{done}) and
#             (not @sourceversions or not @{$status{fixed_versions}})) {
#         $status{"pending"} = 'done';
#     }
# 
#     return \%status;
# }


#     htmlize_bugs(bugs=>[@bugs]);
=head2 htmlize_bugs

     htmlize_bugs({bug=>1,status=>\%status,extravars=>\%extra},{bug=>...}});

Turns a list of bugs into an html snippit of the bugs.

=cut

sub htmlize_bugs{
     my @bugs = @_;
     my @html;

     for my $bug (@bugs) {
	  my $html = sprintf "<li><a href=\"%s\">#%d: %s</a>\n<br>",
	       bug_url($bug->{bug}), $bug->{bug}, html_escape($bug->{status}{subject});
	  $html .= htmlize_bugstatus($bug->{status}) . "\n";
     }
     return @html;
}


sub htmlize_bugstatus {
     my %status = %{$_[0]};

     my $result = "";

     my $showseverity;
     if  ($status{severity} eq $config{default_severity}) {
	  $showseverity = '';
     } elsif (isstrongseverity($status{severity})) {
	  $showseverity = "Severity: <em class=\"severity\">$status{severity}</em>;\n";
     } else {
	  $showseverity = "Severity: <em>$status{severity}</em>;\n";
     }

     $result .= htmlize_packagelinks($status{"package"}, 1);

     my $showversions = '';
     if (@{$status{found_versions}}) {
	  my @found = @{$status{found_versions}};
	  local $_;
	  s{/}{ } foreach @found;
	  $showversions .= join ', ', map html_escape($_), @found;
     }
     if (@{$status{fixed_versions}}) {
	  $showversions .= '; ' if length $showversions;
	  $showversions .= '<strong>fixed</strong>: ';
	  my @fixed = @{$status{fixed_versions}};
	  $showversions .= join ', ', map {s#/##; html_escape($_)} @fixed;
     }
     $result .= " ($showversions)" if length $showversions;
     $result .= ";\n";

     $result .= $showseverity;
     $result .= htmlize_addresslinks("Reported by: ", \&submitterurl,
                                $status{originator});
     $result .= ";\nOwned by: " . html_escape($status{owner})
	  if length $status{owner};
     $result .= ";\nTags: <strong>" 
	  . html_escape(join(", ", sort(split(/\s+/, $status{tags}))))
	       . "</strong>"
		    if (length($status{tags}));

     $result .= ";\nMerged with ".
	  bug_linklist(', ',
		       'submitter',
		       split(/ /,$status{mergedwith}))
	       if length $status{mergedwith};
     $result .= ";\nBlocked by ".
	  bug_linklist(", ",
		       'submitter',
		       split(/ /,$status{blockedby}))
	       if length $status{blockedby};
     $result .= ";\nBlocks ".
	  bug_linklist(", ",
		       'submitter',
		       split(/ /,$status{blocks})
		      )
	       if length $status{blocks};

     my $days = 0;
     if (length($status{done})) {
	  $result .= "<br><strong>Done:</strong> " . html_escape($status{done});
	  $days = ceil($debbugs::gRemoveAge - -M buglog($status{id}));
	  if ($days >= 0) {
	       $result .= ";\n<strong>Will be archived" . ( $days == 0 ? " today" : $days == 1 ? " in $days day" : " in $days days" ) . "</strong>";
	  } else {
	       $result .= ";\n<strong>Archived</strong>";
	  }
     }
     else {
	  if (length($status{forwarded})) {
	       $result .= ";\n<strong>Forwarded</strong> to "
		    . maybelink($status{forwarded});
	  }
	  my $daysold = int((time - $status{date}) / 86400);   # seconds to days
	  if ($daysold >= 7) {
	       my $font = "";
	       my $efont = "";
	       $font = "em" if ($daysold > 30);
	       $font = "strong" if ($daysold > 60);
	       $efont = "</$font>" if ($font);
	       $font = "<$font>" if ($font);

	       my $yearsold = int($daysold / 365);
	       $daysold -= $yearsold * 365;

	       $result .= ";\n $font";
	       my @age;
	       push @age, "1 year" if ($yearsold == 1);
	       push @age, "$yearsold years" if ($yearsold > 1);
	       push @age, "1 day" if ($daysold == 1);
	       push @age, "$daysold days" if ($daysold > 1);
	       $result .= join(" and ", @age);
	       $result .= " old$efont";
        }
    }

    $result .= ".";

    return $result;
}

# Split a package string from the status file into a list of package names.
sub splitpackages {
    my $pkgs = shift;
    return unless defined $pkgs;
    return map lc, split /[ \t?,()]+/, $pkgs;
}


=head2 htmlize_packagelinks

     htmlize_packagelinks

Given a scalar containing a list of packages separated by something
that L<Debbugs::CGI/splitpackages> can separate, returns a
formatted set of links to packages.

=cut

sub htmlize_packagelinks {
    my ($pkgs,$strong) = @_;
    return unless defined $pkgs and $pkgs ne '';
    my @pkglist = splitpackages($pkgs);

    $strong = 0;
    my $openstrong  = $strong ? '<strong>' : '';
    my $closestrong = $strong ? '</strong>' : '';

    return 'Package' . (@pkglist > 1 ? 's' : '') . ': ' .
           join(', ',
                map {
                    '<a class="submitter" href="' . pkg_url(pkg=>$_||'') . '">' .
                    $openstrong . html_escape($_) . $closestrong . '</a>'
                } @pkglist
           );
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
     $class = defined $class?qq(class="$class" ):'';
     if (defined $addresses and $addresses ne '') {
	  my @addrs = getparsedaddrs($addresses);
	  my $prefix = (ref $prefixfunc) ?
	       $prefixfunc->(scalar @addrs):$prefixfunc;
	  return $prefix .
	       join ', ', map
		    { sprintf qq(<a ${class}).
			   'href="%s">%s</a>',
				$urlfunc->($_->address),
				     html_escape($_->format) ||
					  '(unknown)'
				     } @addrs;
     }
     else {
	  my $prefix = (ref $prefixfunc) ?
	       $prefixfunc->(1) : $prefixfunc;
	  return sprintf '%s<a '.$class.'href="%s">(unknown)</a>',
	       $prefix, $urlfunc->('');
     }
}



my %_parsedaddrs;
sub getparsedaddrs {
    my $addr = shift;
    return () unless defined $addr;
    return @{$_parsedaddrs{$addr}} if exists $_parsedaddrs{$addr};
    @{$_parsedaddrs{$addr}} = Mail::Address->parse($addr);
    return @{$_parsedaddrs{$addr}};
}


=head2 bug_links

     bug_links($one_bug);
     bug_links($starting_bug,$stoping_bugs,);

Creates a set of links to bugs, starting with bug number
$starting_bug, and finishing with $stoping_bug; if only one bug is
passed, makes a link to only a single bug.

The content of the link is the bug number.

XXX Use L<Params::Validate>; we want to be able to support query
arguments here too.

=cut

sub bug_links{
     my ($start,$stop,$query_arguments) = @_;
     $stop = $stop || $start;
     $query_arguments ||= '';
     my @output;
     for my $bug ($start..$stop) {
	  push @output,'<a href="'.bug_url($bug,'').qq(">$bug</a>);
     }
     return join(', ',@output);
}

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
     if (length $class) {
	  $class = qq(class="$class" );
     }
     return join($sep,map{qq(<a ${class}href=").
			       bug_url($_).qq(">#$_</a>)
			  } @bugs);
}




1;


__END__






