#!/usr/bin/perl -w

package debbugs;

use strict;
use CGI qw/:standard/;

require '/usr/lib/debbugs/errorlib';
require '/usr/lib/debbugs/common.pl';

require '/etc/debbugs/config';
require '/etc/debbugs/text';

my $pkg = param('pkg');
my $archive = (param('archive') || 'no') eq 'yes';
my $arc = 'yes';

$pkg = 'ALL' unless defined( $pkg );
$arc = 'no' unless $archive;

my $repeatmerged = (param('repeatmerged') || 'yes') eq 'yes';
my $this = "";

my %indexentry;
my %maintainer = ();
my %strings = ();

my %displayshowpending = ('pending','outstanding',
                       'done','resolved',
                       'forwarded','forwarded to upstream software authors');

my $dtime=`date -u '+%H:%M:%S GMT %a %d %h'`;
chomp($dtime);
my $tail_html = $debbugs::gHTMLTail;
$tail_html =~ s/SUBSTITUTE_DTIME/$dtime/;


print header;
if( $archive )
{ 	print start_html("$debbugs::gProject Archived $debbugs::gBug report logs: package $pkg");
	print h1("$debbugs::gProject Archived $debbugs::gBug report logs: package $pkg");
} else
{ 	print start_html("$debbugs::gProject $debbugs::gBug report logs: package $pkg");
	print h1("$debbugs::gProject $debbugs::gBug report logs: package $pkg");
}

#if (defined $maintainer{$pkg}) {
#	print "<p>Maintainer for $pkg is <a href=\"" 
#              . mainturl($maintainer{$pkg}) . "\">"
#              . htmlsanit($maintainer{$pkg}) . "</a>.</p>\n";
#}

print "<p>Note that with multi-binary packages there may be other reports\n";
print "filed under the different binary package names.</p>\n";

if ( $pkg ne 'ALL' )
{ 	%strings = pkgbugs($pkg, $archive);
	foreach my $bug ( keys %strings ) 
	{ $this .= "  <LI><A href=\"" . bugurl($bug, "archive=$archive") . "\">". $strings{ $bug } ."</A>\n"; }
} else 
{	%strings = pkgbugsindex( $archive );
	my @bugs = ();
	foreach my $bug ( keys %strings ) { push @bugs, $bug; }
	@bugs = sort { $a cmp $b } @bugs;
	foreach my $bug ( @bugs )
	{ $this .= "   <LI><A HREF=\"http://cgi.debian.org/cgi-bin/pkgreport.cgi?pkg=". $bug ."&archive=$arc\">". $bug . "\n"; }
}

if ( length( $this ) )
{	print "<UL>\n";
		print $this;
	print "</UL>\n";
} else
{ print "No archived reports found\n"; }

print hr;
print "$tail_html";

print end_html;
