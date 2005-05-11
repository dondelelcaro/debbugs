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

my $indexon = $param{'indexon'} || 'pkg';
if ($indexon !~ m/^(pkg|src|maint|submitter|tag)$/) {
    quitcgi("You have to choose something to index on");
}

my $repeatmerged = ($param{'repeatmerged'} || "yes") eq "yes";
my $archive = ($param{'archive'} || "no") eq "yes";
my $sortby = $param{'sortby'} || 'alpha';
if ($sortby !~ m/^(alpha|count)$/) {
    quitcgi("Don't know how to sort like that");
}

#my $include = $param{'include'} || "";
#my $exclude = $param{'exclude'} || "";

my $Archived = $archive ? " Archived" : "";

my %maintainers = %{&getmaintainers()};
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
my %htmldescrip = ();
my %sortkey = ();
if ($indexon eq "pkg") {
  $tag = "package";
  %count = countbugs(sub {my %d=@_; return splitpackages($d{"pkg"})});
  $note = "<p>Note that with multi-binary packages there may be other\n";
  $note .= "reports filed under the different binary package names.</p>\n";
  foreach my $pkg (keys %count) {
    $sortkey{$pkg} = lc $pkg;
    $htmldescrip{$pkg} = sprintf('<a href="%s">%s</a> (%s)',
                           pkgurl($pkg),
                           htmlsanit($pkg),
                           htmlmaintlinks(sub { $_[0] == 1 ? 'maintainer: '
                                                           : 'maintainers: ' },
                                          $maintainers{$pkg}));
  }
} elsif ($indexon eq "src") {
  $tag = "source package";
  my $pkgsrc = getpkgsrc();
  %count = countbugs(sub {my %d=@_;
                          return map {
                            $pkgsrc->{$_} || $_
                          } splitpackages($d{"pkg"});
                         });
  $note = "";
  foreach my $src (keys %count) {
    $sortkey{$src} = lc $src;
    $htmldescrip{$src} = sprintf('<a href="%s">%s</a> (%s)',
                           srcurl($src),
                           htmlsanit($src),
                           htmlmaintlinks(sub { $_[0] == 1 ? 'maintainer: '
                                                           : 'maintainers: ' },
                                          $maintainers{$src}));
  }
} elsif ($indexon eq "maint") {
  $tag = "maintainer";
  my %email2maint = ();
  %count = countbugs(sub {my %d=@_;
                          return map {
                            my @me = getparsedaddrs($maintainers{$_});
                            foreach my $addr (@me) {
                              $email2maint{$addr->address} = $addr->format
                                unless exists $email2maint{$addr->address};
                            }
                            map { $_->address } @me;
                          } splitpackages($d{"pkg"});
                         });
  $note = "<p>Note that maintainers may use different Maintainer fields for\n";
  $note .= "different packages, so there may be other reports filed under\n";
  $note .= "different addresses.</p>\n";
  foreach my $maint (keys %count) {
    $sortkey{$maint} = lc $email2maint{$maint} || "(unknown)";
    $htmldescrip{$maint} = htmlmaintlinks('', $email2maint{$maint});
  }
} elsif ($indexon eq "submitter") {
  $tag = "submitter";
  my %fullname = ();
  %count = countbugs(sub {my %d=@_;
                          my @se = getparsedaddrs($d{"submitter"} || "");
                          foreach my $addr (@se) {
                            $fullname{$addr->address} = $addr->format
                              unless exists $fullname{$addr->address};
                          }
                          map { $_->address } @se;
                         });
  foreach my $sub (keys %count) {
    $sortkey{$sub} = lc $fullname{$sub};
    $htmldescrip{$sub} = sprintf('<a href="%s">%s</a>',
                           submitterurl($sub),
			   htmlsanit($fullname{$sub}));
  }
  $note = "<p>Note that people may use different email accounts for\n";
  $note .= "different bugs, so there may be other reports filed under\n";
  $note .= "different addresses.</p>\n";
} elsif ($indexon eq "tag") {
  $tag = "tag";
  %count = countbugs(sub {my %d=@_; return split ' ', $d{tags}; });
  $note = "";
  foreach my $keyword (keys %count) {
    $sortkey{$keyword} = lc $keyword;
    $htmldescrip{$keyword} = sprintf('<a href="%s">%s</a>',
                               tagurl($keyword),
                               htmlsanit($keyword));
  }
}

my $result = "<ul>\n";
my @orderedentries;
if ($sortby eq "count") {
  @orderedentries = sort { $count{$a} <=> $count{$b} } keys %count;
} else { # sortby alpha
  @orderedentries = sort { $sortkey{$a} cmp $sortkey{$b} } keys %count;
}
foreach my $x (@orderedentries) {
  $result .= "<li>" . $htmldescrip{$x} . " has $count{$x} " .
            ($count{$x} == 1 ? "bug" : "bugs") . "</li>\n";
}
$result .= "</ul>\n";

print "Content-Type: text/html\n\n";

print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print "<HTML><HEAD>\n" . 
    "<TITLE>$debbugs::gProject$Archived $debbugs::gBug reports by $tag</TITLE>\n" .
    "</HEAD>\n" .
    '<BODY TEXT="#000000" BGCOLOR="#FFFFFF" LINK="#0000FF" VLINK="#800080">' .
    "\n";
print "<H1>" . "$debbugs::gProject$Archived $debbugs::gBug report logs by $tag" .
      "</H1>\n";

print $note;
print $result;

print "<hr>\n";
print "$tail_html";

print "</body></html>\n";
