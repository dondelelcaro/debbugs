#!/usr/bin/perl -w

package debbugs;

use strict;
use CGI qw/:standard/;

require '/debian/home/ajt/newajbug/common.pl';
#require '/usr/lib/debbugs/common.pl';
require '/usr/lib/debbugs/errorlib';

require '/etc/debbugs/config';
require '/etc/debbugs/text';

my $pkg = param('pkg');
my $maint = defined $pkg ? undef : param('maint');
my $maintenc = (defined $pkg || defined $maint) ? undef : param('maintenc');
my $repeatmerged = (param('repeatmerged') || "yes") eq "yes";
my $archive = (param('archive') || "no") eq "yes";

$pkg = 'ALL' unless (defined($pkg) || defined($maint) || defined($maintenc));

my $Archived = $archive ? "Archived" : "";

my $this = "";

my %indexentry;
my %maintainer = &getmaintainers();
my %strings = ();

my $dtime=`date -u '+%H:%M:%S GMT %a %d %h'`;
chomp($dtime);
my $tail_html = $debbugs::gHTMLTail;
$tail_html =~ s/SUBSTITUTE_DTIME/$dtime/;

my $tag;
if (defined $pkg) {
    $tag = "package $pkg";
} elsif (defined $maint) {
    $tag = "maintainer $maint";
} else {
    $tag = "maintainer $maintenc";
}

set_option("repeatmerged", $repeatmerged);
set_option("archive", $archive);

my @bugs;
if (defined $pkg) {
    @bugs = pkgbugs($pkg);
} elsif (defined $maint) {
    @bugs = maintbugs($maint);
} else {
    @bugs = maintencbugs($maintenc);
}

my $result = htmlizebugs(@bugs);

print header;
print start_html("$debbugs::gProject $Archived $debbugs::gBug report logs: $tag");
print h1("$debbugs::gProject $Archived $debbugs::gBug report logs: $tag");

if (defined $maintainer{$pkg}) {
    print "<p>Maintainer for $pkg is <a href=\"" 
          . mainturl($maintainer{$pkg}) . "\">"
          . htmlsanit($maintainer{$pkg}) . "</a>.</p>\n";
}

if (defined $pkg) {
    print "<p>Note that with multi-binary packages there may be other\n";
    print "reports filed under the different binary package names.</p>\n";
} else {
    print "<p>Note that maintainers may use different Maintainer fields for\n";
    print "different packages, so there may be other reports filed under\n"
    print "different addresses.\n";
}

print $result;

print hr;
print "$tail_html";

print end_html;
