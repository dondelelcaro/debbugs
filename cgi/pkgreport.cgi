#!/usr/bin/perl -w

package debbugs;

use strict;
use CGI qw/:standard/;

require '/debian/home/ajt/newajbug/common.pl';
#require '/usr/lib/debbugs/common.pl';
#require '/usr/lib/debbugs/errorlib';

require '/etc/debbugs/config';
require '/etc/debbugs/text';

my $pkg = param('pkg');
my $maint = defined $pkg ? undef : param('maint');
my $maintenc = (defined $pkg || defined $maint) ? undef : param('maintenc');
my $submitter = (defined $pkg || defined $maint || defined $maintenc) ? undef : param('submitter');
my $repeatmerged = (param('repeatmerged') || "yes") eq "yes";
my $archive = (param('archive') || "no") eq "yes";

$pkg = 'ALL' unless (defined($pkg) || defined($maint) || defined($maintenc)) || defined($submitter);

my $Archived = $archive ? "Archived" : "";

my $this = "";

my %indexentry;
my %maintainer = &getmaintainers();
my %strings = ();

my $dtime=`date -u '+%H:%M:%S GMT %a %d %h'`;
chomp($dtime);
my $tail_html = $debbugs::gHTMLTail;
$tail_html = $debbugs::gHTMLTail;
$tail_html =~ s/SUBSTITUTE_DTIME/$dtime/;

my $tag;
if (defined $pkg) {
    $tag = "package $pkg";
} elsif (defined $maint) {
    $tag = "maintainer $maint";
} elsif (defined $maintenc) {
    $tag = "encoded maintainer $maintenc";
} else {
    $tag = "submitter $submitter";
}

set_option("repeatmerged", $repeatmerged);
set_option("archive", $archive);

my @bugs;
if (defined $pkg) {
    @bugs = pkgbugs($pkg);
} elsif (defined $maint) {
    @bugs = maintbugs($maint);
} elsif (defined $maintenc) {
    @bugs = maintencbugs($maintenc);
} else {
    @bugs = submitterbugs($submitter);
}

my $result = htmlizebugs(@bugs);

print header;
print start_html(
        -TEXT => "#000000",
        -BGCOLOR=>"#FFFFFF",
        -LINK => "#0000FF",
        -VLINK => "#800080",
        -title => "$debbugs::gProject $Archived $debbugs::gBug report logs: $tag");

print h1("$debbugs::gProject $Archived $debbugs::gBug report logs: $tag");

if (defined $pkg) {
    if (defined $maintainer{$pkg}) {
        print "<p>Maintainer for $pkg is <a href=\"" 
              . mainturl($maintainer{$pkg}) . "\">"
              . htmlsanit($maintainer{$pkg}) . "</a>.</p>\n";
    }
    print "<p>Note that with multi-binary packages there may be other\n";
    print "reports filed under the different binary package names.</p>\n";
    print "\n";
    printf "<p>This package probably has a general <a href=\"%s\">information page</a></p>\n", "http://packages.debian.org/$pkg";
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

print hr;
print "$tail_html";

print end_html;
