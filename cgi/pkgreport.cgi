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

my ($pkg, $maint, $maintenc, $submitter, $severity, $status);

if (defined ($pkg = $param{'pkg'})) {
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

my $Archived = $archive ? "Archived" : "";

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

my $tag;
my @bugs;
if (defined $pkg) {
  $tag = "package $pkg";
  @bugs = @{getbugs(sub {my %d=@_; return $pkg eq $d{"pkg"}}, 'package', $pkg)};
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
  @bugs = @{getbugs(sub {my %d=@_; my $me; 
		       ($me = $maintainers{$d{"pkg"}}||"") =~ s/\s*\(.*\)\s*//;
		       $me = $1 if ($me =~ m/<(.*)>/);
		       return $me eq $maint;
		     }, 'package', @pkgs)};
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
print "<HTML><HEAD><TITLE>\n" . 
    "$debbugs::gProject $Archived $debbugs::gBug report logs: $tag\n" .
    "</TITLE></HEAD>\n" .
    '<BODY TEXT="#000000" BGCOLOR="#FFFFFF" LINK="#0000FF" VLINK="#800080">' .
    "\n";
print "<H1>" . "$debbugs::gProject $Archived $debbugs::gBug report logs: $tag" .
      "</H1>\n";

if (defined $pkg) {
    my %maintainers = %{getmaintainers()};
    if (defined $maintainers{$pkg}) {
        print "<p>Maintainer for $pkg is <a href=\"" 
              . mainturl($maintainers{$pkg}) . "\">"
              . htmlsanit($maintainers{$pkg}) . "</a>.</p>\n";
    }
    print "<p>Note that with multi-binary packages there may be other\n";
    print "reports filed under the different binary package names.</p>\n";
    print "\n";
my $stupidperl = ${debbugs::gPackagePages};
    printf "<p>You might like to refer to the <a href=\"%s\">%s package page</a></p>\n", urlsanit("http://${debbugs::gPackagePages}/$pkg"), htmlsanit("$pkg");
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
