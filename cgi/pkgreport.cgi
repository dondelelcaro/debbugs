#!/usr/bin/perl -wT

package debbugs;

use strict;
use POSIX qw(strftime tzset nice);

#require '/usr/lib/debbugs/errorlib';
require './common.pl';

require '/etc/debbugs/config';
require '/etc/debbugs/text';

nice(5);

my %param = readparse();

my ($pkg, $src, $maint, $maintenc, $submitter, $severity, $status);

if (defined ($pkg = $param{'pkg'})) {
} elsif (defined ($src = $param{'src'})) {
} elsif (defined ($maint = $param{'maint'})) {
} elsif (defined ($maintenc = $param{'maintenc'})) {
} elsif (defined ($submitter= $param{'submitter'})) { 
} elsif (defined ($severity = $param{'severity'})) { 
	$status = $param{'status'} || 'open';
} else {
	quit("You have to choose something to select by");
}

my $repeatmerged = ($param{'repeatmerged'} || "yes") eq "yes";
my $archive = ($param{'archive'} || "no") eq "yes";
my $include = $param{'include'} || "";
my $exclude = $param{'exclude'} || "";
my $raw_sort = ($param{'raw'} || "no") eq "yes";
my $bug_rev = ($param{'bug-rev'} || "no") eq "yes";
my $pend_rev = ($param{'pend-rev'} || "no") eq "yes";
my $sev_rev = ($param{'sev-rev'} || "no") eq "yes";
my $pend_exc = $param{'&pend-exc'} || $param{'pend-exc'} || "";
my $pend_inc = $param{'&pend-inc'} || $param{'pend-inc'} || "";
my $sev_exc = $param{'&sev-exc'} || $param{'sev-exc'} || "";
my $sev_inc = $param{'&sev-inc'} || $param{'sev-inc'} || "";

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
set_option("include", { map {if (m/^(.*):(.*)$/) { ($1,$2) } else { ($_,1) }} (split /[\s,]+/, $include) })
	if ($include);
set_option("exclude", { map {if (m/^(.*):(.*)$/) { ($1,$2) } else { ($_,1) }} (split /[\s,]+/, $exclude) })
	if ($exclude);
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
  @bugs = @{getbugs(sub {my %d=@_; return $pkg eq $d{"pkg"}}, 'package', @pkgs)};
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
} elsif (defined $severity) {
  $tag = "$status $severity bugs";
  @bugs = @{getbugs(sub {my %d=@_;
		       return ($d{"severity"} eq $severity) 
			 && ($d{"status"} eq $status);
		     })};
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

if (defined $pkg || defined $src) {
    my %maintainers = %{getmaintainers()};
    my $maint = $pkg ? $maintainers{$pkg} : $maintainers{$src} ? $maintainers{$src} : undef;
    if (defined $maint) {
        print "<p>Maintainer for " . ( defined($pkg) ? $pkg : "source package $src" ) . " is <a href=\"" 
              . mainturl($maint) . "\">"
              . htmlsanit($maint) . "</a>.</p>\n";
    }
    my %pkgsrc = %{getpkgsrc()};
    my @pkgs = getsrcpkgs($pkg ? $pkgsrc{ $pkg } : $src);
    @pkgs = grep( !/^\Q$pkg\E$/, @pkgs ) if ( $pkg );
    if ( @pkgs ) {
	@pkgs = sort @pkgs;
	if ($pkg) {
		print "You may want to refer to the following packages that are part of the same source:<br>\n";
	} else {
		print "You may want to refer to the following packages' individual bug pages:<br>\n";
	}
	print join( ", ", map( "<A href=\"" . pkgurl($_) . "\">$_</A>", @pkgs ) );
	print "\n";
    }
    if ($pkg) {
	my $stupidperl = ${debbugs::gPackagePages};
	printf "<p>You might like to refer to the <a href=\"%s\">%s package page</a>, or to the source package <a href=\"%s\">%s</a>'s bug page.</p>\n", urlsanit("http://${debbugs::gPackagePages}/$pkg"), htmlsanit("$pkg"), urlsanit(srcurl($pkg)), $pkgsrc{$pkg};
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

print $result;

print "<hr>\n";
print "$tail_html";

print "</body></html>\n";
