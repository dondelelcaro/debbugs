#!/usr/bin/perl -wT

package debbugs;

use strict;
use POSIX qw(strftime tzset nice);

#require '/usr/lib/debbugs/errorlib';
#require '/usr/lib/debbugs/common.pl';
require '/debian/home/ajt/newajbug/common.pl';

require '/etc/debbugs/config';
require '/etc/debbugs/text';

nice(5);

my %param = readparse();

my $indexon = $param{'indexon'} || 'pkg';
if ($indexon !~ m/^(pkg|maint|submitter)/) {
    quit("You have to choose something to index on");
}

my $repeatmerged = ($param{'repeatmerged'} || "yes") eq "yes";
my $archive = ($param{'archive'} || "no") eq "yes";
#my $include = $param{'include'} || "";
#my $exclude = $param{'exclude'} || "";

my $Archived = $archive ? "Archived" : "";

my %maintainers = &getmaintainers();
my %strings = ();

$ENV{"TZ"} = 'UTC';
tzset();

my $dtime = strftime "%a, %e %b %Y %T UTC", localtime;
my $tail_html = $debbugs::gHTMLTail;
$tail_html = $debbugs::gHTMLTail;
$tail_html =~ s/SUBSTITUTE_DTIME/$dtime/;

set_option("repeatmerged", $repeatmerged);
set_option("archive", $archive);
#set_option("include", { map {($_,1)} (split /[\s,]+/, $include) })
#	if ($include);
#set_option("exclude", { map {($_,1)} (split /[\s,]+/, $exclude) })
#	if ($exclude);

my %count;
my $tag;
my $note;
if ($indexon eq "pkg") {
  $tag = "package";
  %count = countbugs(sub {my %d=@_; return $d{"pkg"}});
  $note = "<p>Note that with multi-binary packages there may be other\n";
  $note .= "reports filed under the different binary package names.</p>\n";
} elsif ($indexon eq "maint") {
  $tag = "maintainer";
  %count = countbugs(sub {my %d=@_; my $me; 
			   $me = $maintainers{$d{"pkg"}} || "";
			   $me =~ s/\s*\(.*\)\s*//;
			   $me = $1 if ($me =~ m/<(.*)>/);
			   return $me;
			 });
  $note = "<p>Note that maintainers may use different Maintainer fields for\n";
  $note .= "different packages, so there may be other reports filed under\n";
  $note .= "different addresses.</p>\n";
} elsif ($indexon eq "submitter") {
  $tag = "submitter";
  %count = countbugs(sub {my %d=@_; my $se; 
			  ($se = $d{"submitter"} || "") =~ s/\s*\(.*\)\s*//;
			  $se = $1 if ($se =~ m/<(.*)>/);
			  return $se;
			});
  $note = "<p>Note that people may use different email accounts for\n";
  $note .= "different bugs, so there may be other reports filed under\n";
  $note .= "different addresses.</p>\n";
}

my $result = "<ul>\n";
foreach my $x (sort keys %count) {
  $result .= sprintf('<li><a href="pkgreport.cgi?%s=%s%s">%s</a> %d bugs</li>',
		     $indexon, $x, ($archive ? "&archive=yes" : ""), $x,
                     $count{$x});
  $result .= "\n";
}
$result .= "</ul>\n";

print "Content-Type: text/html\n\n";

print "<HTML><HEAD><TITLE>\n" . 
    "$debbugs::gProject $Archived $debbugs::gBug reports by $tag\n" .
    "</TITLE></HEAD>\n" .
    '<BODY TEXT="#000000" BGCOLOR="#FFFFFF" LINK="#0000FF" VLINK="#800080">' .
    "\n";
print "<H1>" . "$debbugs::gProject $Archived $debbugs::gBug report logs: $tag" .
      "</H1>\n";

print $note;
print $result;

print "<hr>\n";
print "$tail_html";

print "</body></html>\n";
