#!/usr/bin/perl -wT

package debbugs;

use strict;
use POSIX qw(strftime tzset nice);

#require '/usr/lib/debbugs/errorlib';
require './common.pl';

require '/etc/debbugs/config';
require '/etc/debbugs/text';

use vars qw($gPackagePages $gWebDomain);

if ($ENV{REQUEST_METHOD} eq 'HEAD') {
    print "Content-Type: text/html\n\n";
    exit 0;
}

nice(5);

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

my ($pkg, $src, $maint, $maintenc, $submitter, $severity, $status);

my %which = (
	'pkg' => \$pkg,
	'src' => \$src,
	'maint' => \$maint,
	'maintenc' => \$maintenc,
	'submitter' => \$submitter,
	'severity' => \$severity,
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
quit("You have to choose something to select by") if (!$found);

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

my $tag;
my @bugs;
if (defined $pkg) {
  $tag = "package $pkg";
  @bugs = @{getbugs(sub {my %d=@_; return $pkg eq $d{"pkg"}}, 'package', $pkg)};
} elsif (defined $src) {
  $tag = "source $src";
  my @pkgs = getsrcpkgs($src);
  push @pkgs, $src if ( !grep(/^\Q$src\E$/, @pkgs) );
  @bugs = @{getbugs(sub {my %d=@_; return grep($d{"pkg"} eq $_, @pkgs)}, 'package', @pkgs)};
} elsif (defined $maint) {
  my %maintainers = %{getmaintainers()};
  $tag = "maintainer $maint";
  my @pkgs = ();
  foreach my $p (keys %maintainers) {
    my $me = $maintainers{$p};
    $me =~ s/\s*\(.*\)\s*//;
    $me = $1 if ($me =~ m/<(.*)>/);
    push @pkgs, $p if ($me eq $maint);
  }
  if ($maint eq "") {
    @bugs = @{getbugs(sub {my %d=@_; my $me; 
		       ($me = $maintainers{$d{"pkg"}}||"") =~ s/\s*\(.*\)\s*//;
		       $me = $1 if ($me =~ m/<(.*)>/);
		       return $me eq $maint;
		     })};
  } else {
    @bugs = @{getbugs(sub {my %d=@_; my $me; 
		       ($me = $maintainers{$d{"pkg"}}||"") =~ s/\s*\(.*\)\s*//;
		       $me = $1 if ($me =~ m/<(.*)>/);
		       return $me eq $maint;
		     }, 'package', @pkgs)};
  }
} elsif (defined $maintenc) {
  my %maintainers = %{getmaintainers()};
  $tag = "encoded maintainer $maintenc";
  @bugs = @{getbugs(sub {my %d=@_; 
		       return maintencoded($maintainers{$d{"pkg"}} || "") 
			 eq $maintenc
		       })};
} elsif (defined $submitter) {
  $tag = "submitter $submitter";
  @bugs = @{getbugs(sub {my %d=@_; my $se; 
		       ($se = $d{"submitter"} || "") =~ s/\s*\(.*\)\s*//;
		       $se = $1 if ($se =~ m/<(.*)>/);
		       return $se eq $submitter;
		     }, 'submitter-email', $submitter)};
} elsif (defined($severity) && defined($status)) {
  $tag = "$status $severity bugs";
  @bugs = @{getbugs(sub {my %d=@_;
		       return ($d{"severity"} eq $severity) 
			 && ($d{"status"} eq $status);
		     })};
} elsif (defined($severity)) {
  $tag = "$severity bugs";
  @bugs = @{getbugs(sub {my %d=@_;
		       return ($d{"severity"} eq $severity);
		     }, 'severity', $severity)};
}

my $result = htmlizebugs(\@bugs);

print "Content-Type: text/html\n\n";

print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print "<HTML><HEAD>\n" . 
    "<TITLE>$debbugs::gProject$Archived $debbugs::gBug report logs: $tag</TITLE>\n" .
    "</HEAD>\n" .
    '<BODY TEXT="#000000" BGCOLOR="#FFFFFF" LINK="#0000FF" VLINK="#800080">' .
    "\n";
print "<H1>" . "$debbugs::gProject$Archived $debbugs::gBug report logs: $tag" .
      "</H1>\n";

my $showresult = 1;

if (defined $pkg || defined $src) {
    my %maintainers = %{getmaintainers()};
    my $maint = $pkg ? $maintainers{$pkg} : $maintainers{$src} ? $maintainers{$src} : undef;
    if (defined $maint) {
        print "<p>Maintainer for " . ( defined($pkg) ? $pkg : "source package $src" ) . " is <a href=\"" 
              . mainturl($maint) . "\">"
              . htmlsanit($maint) . "</a>.</p>\n";
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
	if ($pkg) {
	    my @references;
	    my $pseudodesc = getpseudodesc();
	    if (defined($pseudodesc) and exists($pseudodesc->{$pkg})) {
		push @references, "to the <a href=\"http://${debbugs::gWebDomain}/pseudo-packages${debbugs::gHTMLSuffix}\">list of other pseudo-packages</a>";
	    } else {
		push @references, sprintf "to the <a href=\"%s\">%s package page</a>", urlsanit("http://${debbugs::gPackagePages}/$pkg"), htmlsanit("$pkg");
	    }
	    if ($srcforpkg) {
		if (defined $debbugs::gSubscriptionDomain) {
		    push @references, "to the <a href=\"http://$debbugs::gSubscriptionDomain/$srcforpkg\">Package Tracking System</a>";
		}
		# Only output this if the source listing is non-trivial.
		if (@pkgs or $pkg ne $srcforpkg) {
		    push @references, sprintf "to the source package <a href=\"%s\">%s</a>'s bug page", srcurl($srcforpkg), htmlsanit($srcforpkg);
		}
	    }
	    if (@references) {
		$references[$#references] = "or $references[$#references]" if @references > 1;
		print "<p>You might like to refer ", join(", ", @references), ".</p>\n";
	    }
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
