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
my $linksub;
if ($indexon eq "pkg") {
  $tag = "package";
  %count = countbugs(sub {my %d=@_; return $d{"pkg"}});
  $note = "<p>Note that with multi-binary packages there may be other\n";
  $note .= "reports filed under the different binary package names.</p>\n";
  $linksub = sub {
                   my $pkg = shift; 
                   sprintf('<a href="%s">%s</a> ' 
                            . '(maintained by <a href="%s">%s</a>',
                           pkgurl($pkg),
                           htmlsanit($pkg),
                           mainturl($maintainers{$pkg}),
			   htmlsanit($maintainers{$pkg}));
                  };
} elsif ($indexon eq "maint") {
  $tag = "maintainer";
  %count = countbugs(sub {my %d=@_; 
                          return emailfromrfc822($maintainers{$d{"pkg"}} || "");
			 });
  $note = "<p>Note that maintainers may use different Maintainer fields for\n";
  $note .= "different packages, so there may be other reports filed under\n";
  $note .= "different addresses.</p>\n";
  $linksub = sub {
                   my $maint = shift; my $maintfull = $maint;
		   foreach my $x (values %maintainers) {
                       if (emailfromrfc822($x) eq $maint) {
			  $maintfull = $x; last;
		       }
                   }
                   sprintf('<a href="%s">%s</a>',
                           mainturl($maint),
			   htmlsanit($maintfull));
                  };
} elsif ($indexon eq "submitter") {
  $tag = "submitter";
  my %fullname = ();
  %count = countbugs(sub {my %d=@_; my $f = $d{"submitter"} || "";
                          my $em = emailfromrfc822($f);
                          $fullname{$em} = $f if (!defined $fullname{$em});
			  return $em;
			});
  $linksub = sub {
                   my $sub = shift;
                   sprintf('<a href="%s">%s</a>',
                           submitterurl($sub),
			   htmlsanit($fullname{$sub}));
                  };
  $note = "<p>Note that people may use different email accounts for\n";
  $note .= "different bugs, so there may be other reports filed under\n";
  $note .= "different addresses.</p>\n";
}

my $result = "<ul>\n";
foreach my $x (sort keys %count) {
  $result .= "<li>" . $linksub->($x) . " has $count{$x} bugs</li>\n";
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
