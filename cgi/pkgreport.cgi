#!/usr/bin/perl -wT

package debbugs;

use strict;
use POSIX qw(strftime tzset nice);

#require '/usr/lib/debbugs/errorlib';
require './common.pl';

require '/etc/debbugs/config';
require '/etc/debbugs/text';

use vars qw($gPackagePages $gWebDomain);

if (defined $ENV{REQUEST_METHOD} and $ENV{REQUEST_METHOD} eq 'HEAD') {
    print "Content-Type: text/html; charset=utf-8\n\n";
    exit 0;
}

nice(5);

my $userAgent = detect_user_agent();
my %param = readparse();

my $repeatmerged = ($param{'repeatmerged'} || "yes") eq "yes";
my $archive = ($param{'archive'} || "no") eq "yes";
my $include = $param{'&include'} || $param{'include'} || "";
my $exclude = $param{'&exclude'} || $param{'exclude'} || "";
my $raw_sort = ($param{'raw'} || "no") eq "yes";
my $bug_rev = ($param{'bug-rev'} || "no") eq "yes";
my $pend_rev = ($param{'pend-rev'} || "no") eq "yes";
my $sev_rev = ($param{'sev-rev'} || "no") eq "yes";
my $pend_exc = $param{'&pend-exc'} || $param{'pend-exc'} || "";
my $pend_inc = $param{'&pend-inc'} || $param{'pend-inc'} || "";
my $sev_exc = $param{'&sev-exc'} || $param{'sev-exc'} || "";
my $sev_inc = $param{'&sev-inc'} || $param{'sev-inc'} || "";
my $version = $param{'version'} || undef;
my $dist = $param{'dist'} || undef;
my $arch = $param{'arch'} || undef;
my $show_list_header = ($param{'show_list_header'} || $userAgent->{'show_list_header'} || "yes" ) eq "yes";
my $show_list_footer = ($param{'show_list_footer'} || $userAgent->{'show_list_footer'} || "yes" ) eq "yes";

my ($pkg, $src, $maint, $maintenc, $submitter, $severity, $status, $tag);

my %which = (
	'pkg' => \$pkg,
	'src' => \$src,
	'maint' => \$maint,
	'maintenc' => \$maintenc,
	'submitter' => \$submitter,
	'severity' => \$severity,
	'tag' => \$tag,
	);
my @allowedEmpty = ( 'maint' );

my $found;
foreach ( keys %which ) {
	$status = $param{'status'} || 'open' if /^severity$/;
	if (($found = $param{$_})) {
		${ $which{$_} } = $found;
		last;
	}
}
if (!$found && !$archive) {
	foreach ( @allowedEmpty ) {
		if (exists($param{$_})) {
			${ $which{$_} } = '';
			$found = 1;
			last;
		}
	}
}
if (!$found) {
	my $which;
	if (($which = $param{'which'})) {
		if (grep( /^\Q$which\E$/, @allowedEmpty)) {
			${ $which{$which} } = $param{'data'};
			$found = 1;
		} elsif (($found = $param{'data'})) {
			${ $which{$which} } = $found if (exists($which{$which}));
		}
	}
}
quitcgi("You have to choose something to select by") if (!$found);

my $Archived = $archive ? " Archived" : "";

my $this = "";

my %indexentry;
my %strings = ();

$ENV{"TZ"} = 'UTC';
tzset();

my $dtime = strftime "%a, %e %b %Y %T UTC", localtime;
my $tail_html = $debbugs::gHTMLTail;
$tail_html = $debbugs::gHTMLTail;
$tail_html =~ s/SUBSTITUTE_DTIME/$dtime/;

set_option("repeatmerged", $repeatmerged);
set_option("archive", $archive);
set_option("include", $include);
set_option("exclude", $exclude);
set_option("raw", $raw_sort);
set_option("bug-rev", $bug_rev);
set_option("pend-rev", $pend_rev);
set_option("sev-rev", $sev_rev);
set_option("pend-exc", $pend_exc);
set_option("pend-inc", $pend_inc);
set_option("sev-exc", $sev_exc);
set_option("sev-inc", $sev_inc);
set_option("version", $version);
set_option("dist", $dist);
set_option("arch", $arch);
set_option("use-bug-idx", defined($param{'use-bug-idx'}) ? $param{'use-bug-idx'} : 0);
set_option("show_list_header", $show_list_header);
set_option("show_list_footer", $show_list_footer);

my $title;
my @bugs;
if (defined $pkg) {
  $title = "package $pkg";
  if (defined $version) {
    $title .= " (version $version)";
  } elsif (defined $dist) {
    $title .= " in $dist";
    my $verdesc = getversiondesc($pkg);
    $title .= " ($verdesc)" if defined $verdesc;
  }
  my @pkgs = split /,/, $pkg;
  @bugs = @{getbugs(sub {my %d=@_;
                         foreach my $try (splitpackages($d{"pkg"})) {
                           return 1 if grep($try eq $_, @pkgs);
                         }
                         return 0;
                        }, 'package', @pkgs)};
} elsif (defined $src) {
  $title = "source $src";
  set_option('arch', 'source');
  if (defined $version) {
    $title .= " (version $version)";
  } elsif (defined $dist) {
    $title .= " in $dist";
    my $verdesc = getversiondesc($src);
    $title .= " ($verdesc)" if defined $verdesc;
  }
  my @pkgs = ();
  my @srcs = split /,/, $src;
  foreach my $try (@srcs) {
    push @pkgs, getsrcpkgs($try);
    push @pkgs, $try if ( !grep(/^\Q$try\E$/, @pkgs) );
  }
  @bugs = @{getbugs(sub {my %d=@_;
                         foreach my $try (splitpackages($d{"pkg"})) {
                           return 1 if grep($try eq $_, @pkgs);
                         }
                         return 0;
                        }, 'package', @pkgs)};
} elsif (defined $maint) {
  my %maintainers = %{getmaintainers()};
  $title = "maintainer $maint";
  $title .= " in $dist" if defined $dist;
  if ($maint eq "") {
    @bugs = @{getbugs(sub {my %d=@_;
                           foreach my $try (splitpackages($d{"pkg"})) {
                             return 1 if !getparsedaddrs($maintainers{$try});
                           }
                           return 0;
                          })};
  } else {
    my @maints = split /,/, $maint;
    my @pkgs = ();
    foreach my $try (@maints) {
      foreach my $p (keys %maintainers) {
        my @me = getparsedaddrs($maintainers{$p});
        push @pkgs, $p if grep { $_->address eq $try } @me;
      }
    }
    @bugs = @{getbugs(sub {my %d=@_;
                           foreach my $try (splitpackages($d{"pkg"})) {
                             my @me = getparsedaddrs($maintainers{$try});
                             return 1 if grep { $_->address eq $maint } @me;
                           }
                           return 0;
                          }, 'package', @pkgs)};
  }
} elsif (defined $maintenc) {
  my %maintainers = %{getmaintainers()};
  $title = "encoded maintainer $maintenc";
  $title .= " in $dist" if defined $dist;
  @bugs = @{getbugs(sub {my %d=@_; 
                         foreach my $try (splitpackages($d{"pkg"})) {
                           my @me = getparsedaddrs($maintainers{$try});
                           return 1 if grep {
                             maintencoded($_->address) eq $maintenc
                           } @me;
                         }
                         return 0;
                        })};
} elsif (defined $submitter) {
  $title = "submitter $submitter";
  $title .= " in $dist" if defined $dist;
  my @submitters = split /,/, $submitter;
  @bugs = @{getbugs(sub {my %d=@_;
                         my @se = getparsedaddrs($d{"submitter"} || "");
                         foreach my $try (@submitters) {
                           return 1 if grep { $_->address eq $try } @se;
                         }
                        }, 'submitter-email', @submitters)};
} elsif (defined($severity) && defined($status)) {
  $title = "$status $severity bugs";
  $title .= " in $dist" if defined $dist;
  my @severities = split /,/, $severity;
  my @statuses = split /,/, $status;
  @bugs = @{getbugs(sub {my %d=@_;
		       return (grep($d{"severity"} eq $_, @severities))
			 && (grep($d{"status"} eq $_, @statuses));
		     })};
} elsif (defined($severity)) {
  $title = "$severity bugs";
  $title .= " in $dist" if defined $dist;
  my @severities = split /,/, $severity;
  @bugs = @{getbugs(sub {my %d=@_;
		       return (grep($d{"severity"} eq $_, @severities));
		     }, 'severity', @severities)};
} elsif (defined($tag)) {
  $title = "bugs tagged $tag";
  $title .= " in $dist" if defined $dist;
  my @tags = split /,/, $tag;
  @bugs = @{getbugs(sub {my %d = @_;
                         my %tags = map { $_ => 1 } split ' ', $d{"tags"};
                         return grep(exists $tags{$_}, @tags);
                        })};
}

my $result = htmlizebugs(\@bugs);

print "Content-Type: text/html; charset=utf-8\n\n";

print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print "<HTML><HEAD>\n" . 
    "<TITLE>$debbugs::gProject$Archived $debbugs::gBug report logs: $title</TITLE>\n" .
    "</HEAD>\n" .
    '<BODY TEXT="#000000" BGCOLOR="#FFFFFF" LINK="#0000FF" VLINK="#800080">' .
    "\n";
print "<H1>" . "$debbugs::gProject$Archived $debbugs::gBug report logs: $title" .
      "</H1>\n";

my $showresult = 1;

if (defined $pkg || defined $src) {
    my $showpkg = (defined $pkg) ? $pkg : "source package $src";
    my %maintainers = %{getmaintainers()};
    my $maint = $pkg ? $maintainers{$pkg} : $maintainers{$src} ? $maintainers{$src} : undef;
    if (defined $maint) {
        print '<p>';
        print htmlmaintlinks(sub { $_[0] == 1 ? "Maintainer for $showpkg is "
                                              : "Maintainers for $showpkg are "
                                 },
                             $maint);
        print ".</p>\n";
    } else {
        print "<p>No maintainer for $showpkg. Please do not report new bugs against this package.</p>\n";
    }
    if (defined $maint or @bugs) {
	my %pkgsrc = %{getpkgsrc()};
	my $srcforpkg;
	if (defined $pkg) {
	    $srcforpkg = $pkgsrc{$pkg};
	    defined $srcforpkg or $srcforpkg = $pkg;
	}
	my @pkgs = getsrcpkgs($pkg ? $srcforpkg : $src);
	undef $srcforpkg unless @pkgs;
	@pkgs = grep( !/^\Q$pkg\E$/, @pkgs ) if ( $pkg );
	if ( @pkgs ) {
	    @pkgs = sort @pkgs;
	    if ($pkg) {
		    print "You may want to refer to the following packages that are part of the same source:<br>\n";
	    } else {
		    print "You may want to refer to the following individual bug pages:<br>\n";
	    }
	    push @pkgs, $src if ( $src && !grep(/^\Q$src\E$/, @pkgs) );
	    print join( ", ", map( "<A href=\"" . pkgurl($_) . "\">$_</A>", @pkgs ) );
	    print ".\n";
	}
	my @references;
	my $pseudodesc = getpseudodesc();
	if ($pkg and defined($pseudodesc) and exists($pseudodesc->{$pkg})) {
	    push @references, "to the <a href=\"http://${debbugs::gWebDomain}/pseudo-packages${debbugs::gHTMLSuffix}\">list of other pseudo-packages</a>";
	} else {
	    if ($pkg and defined $debbugs::gPackagePages) {
		push @references, sprintf "to the <a href=\"%s\">%s package page</a>", urlsanit("http://${debbugs::gPackagePages}/$pkg"), htmlsanit("$pkg");
	    }
	    if (defined $debbugs::gSubscriptionDomain) {
		my $ptslink = $pkg ? $srcforpkg : $src;
		push @references, "to the <a href=\"http://$debbugs::gSubscriptionDomain/$ptslink\">Package Tracking System</a>";
	    }
	    # Only output this if the source listing is non-trivial.
	    if ($pkg and $srcforpkg and (@pkgs or $pkg ne $srcforpkg)) {
		push @references, sprintf "to the source package <a href=\"%s\">%s</a>'s bug page", srcurl($srcforpkg), htmlsanit($srcforpkg);
	    }
	}
	if ($pkg) {
	    set_option("archive", !$archive);
	    push @references, sprintf "to the <a href=\"%s\">%s reports for %s</a>", pkgurl($pkg), ($archive ? "active" : "archived"), htmlsanit($pkg);
	    set_option("archive", $archive);
	}
	if (@references) {
	    $references[$#references] = "or $references[$#references]" if @references > 1;
	    print "<p>You might like to refer ", join(", ", @references), ".</p>\n";
	}
	print "<p>If you find a bug not listed here, please\n";
	printf "<a href=\"%s\">report it</a>.</p>\n",
	       urlsanit("http://${debbugs::gWebDomain}/Reporting${debbugs::gHTMLSuffix}");
    } else {
	print "<p>There is no record of the " .
	      (defined($pkg) ? htmlsanit($pkg) . " package"
			     : htmlsanit($src) . " source package") .
	      ", and no bugs have been filed against it.</p>";
	$showresult = 0;
    }
} elsif (defined $maint || defined $maintenc) {
    print "<p>Note that maintainers may use different Maintainer fields for\n";
    print "different packages, so there may be other reports filed under\n";
    print "different addresses.\n";
} elsif (defined $submitter) {
    print "<p>Note that people may use different email accounts for\n";
    print "different bugs, so there may be other reports filed under\n";
    print "different addresses.\n";
}

print $result if $showresult;

print "<hr>\n";
print "$tail_html";

print "</body></html>\n";
