#!/usr/bin/perl -wT

package debbugs;

use strict;
use POSIX qw(strftime tzset nice);

require '/debian/home/ajt/newajbug/common.pl';
#require '/usr/lib/debbugs/common.pl';
#require '/usr/lib/debbugs/errorlib';

require '/etc/debbugs/config';
require '/etc/debbugs/text';

nice(5);

sub readparse {
        my ($in, $key, $val, %ret);
        if (defined $ENV{"QUERY_STRING"} && $ENV{"QUERY_STRING"} ne "") {
                $in=$ENV{QUERY_STRING};
        } elsif(defined $ENV{"REQUEST_METHOD"}
                && $ENV{"REQUEST_METHOD"} eq "POST")
        {
                read(STDIN,$in,$ENV{CONTENT_LENGTH});
        } else {
                return;
        }
        foreach (split(/&/,$in)) {
                s/\+/ /g;
                ($key, $val) = split(/=/,$_,2);
                $key=~s/%(..)/pack("c",hex($1))/ge;
                $val=~s/%(..)/pack("c",hex($1))/ge;
                $ret{$key}=$val;
        }
        return %ret;
}

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

my $Archived = $archive ? "Archived" : "";

my $this = "";

my %indexentry;
my %maintainer = &getmaintainers();
my %strings = ();

$ENV{"TZ"} = 'UTC';
tzset();

my $dtime = strftime "%a, %e %b %Y %T UTC", localtime;
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
} elsif (defined $submitter) {
    $tag = "submitter $submitter";
} elsif (defined $severity) {
    $tag = "$status $severity bugs";
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
} elsif (defined $submitter) {
    @bugs = submitterbugs($submitter);
} elsif (defined $severity) {
    @bugs = severitybugs($status, $severity);
}

my $result = htmlizebugs(@bugs);

print "Content-Type: text/html\n\n";

print "<HTML><HEAD><TITLE>\n" . 
    "$debbugs::gProject $Archived $debbugs::gBug report logs: $tag\n" .
    "</TITLE></HEAD>\n" .
    '<BODY TEXT="#000000" BGCOLOR="#FFFFFF" LINK="#0000FF" VLINK="#800080">' .
    "\n";
print "<H1>" . "$debbugs::gProject $Archived $debbugs::gBug report logs: $tag" .
      "</H1>\n";

if (defined $pkg) {
    if (defined $maintainer{$pkg}) {
        print "<p>Maintainer for $pkg is <a href=\"" 
              . mainturl($maintainer{$pkg}) . "\">"
              . htmlsanit($maintainer{$pkg}) . "</a>.</p>\n";
    }
    print "<p>Note that with multi-binary packages there may be other\n";
    print "reports filed under the different binary package names.</p>\n";
    print "\n";
    printf "<p>You might like to refer to the <a href=\"%s\">%s package page</a></p>\n", "http://packages.debian.org/$pkg", "$pkg";
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
