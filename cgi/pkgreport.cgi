#!/usr/bin/perl -wT
# This script is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# go here too.]
# Copyright 2004-2006 by Anthony Towns <ajt@debian.org>
# Copyright 2007 by Don Armstrong <don@donarmstrong.com>.


package debbugs;

use warnings;
use strict;
use POSIX qw(strftime nice);

use Debbugs::Config qw(:globals :text :config);
use Debbugs::User;
use Debbugs::CGI qw(version_url maint_decode);
use Debbugs::Common qw(getparsedaddrs :date make_list getmaintainers);
use Debbugs::Bugs qw(get_bugs bug_filter);
use Debbugs::Packages qw(getsrcpkgs getpkgsrc get_versions);
use Debbugs::Status qw(:status);
use Debbugs::CGI qw(:all);

use vars qw($gPackagePages $gWebDomain %gSeverityDisplay @gSeverityList);

if (defined $ENV{REQUEST_METHOD} and $ENV{REQUEST_METHOD} eq 'HEAD') {
    print "Content-Type: text/html; charset=utf-8\n\n";
    exit 0;
}

nice(5);

use CGI::Simple;
my $q = new CGI::Simple;

our %param = cgi_parameters(query => $q,
			    single => [qw(ordering archive repeatmerged),
				       qw(bug-rev pend-rev sev-rev),
				       qw(maxdays mindays version),
				       qw(data which dist),
				      ],
			    default => {ordering => 'normal',
					archive  => 0,
					repeatmerged => 1,
				       },
			   );

# map from yes|no to 1|0
for my $key (qw(repeatmerged bug-rev pend-rev sev-rev)) {
     if (exists $param{$key}){
	  if ($param{$key} =~ /^no$/i) {
	       $param{$key} = 0;
	  }
	  elsif ($param{$key}) {
	       $param{$key} = 1;
	  }
     }
}

if (lc($param{archive}) eq 'no') {
     $param{archive} = 0;
}
elsif (lc($param{archive}) eq 'yes') {
     $param{archive} = 1;
}


my $archive = ($param{'archive'} || "no") eq "yes";
my $include = $param{'&include'} || $param{'include'} || "";
my $exclude = $param{'&exclude'} || $param{'exclude'} || "";

my $users = $param{'users'} || "";

my $ordering = $param{'ordering'};
my $raw_sort = ($param{'raw'} || "no") eq "yes";
my $old_view = ($param{'oldview'} || "no") eq "yes";
my $age_sort = ($param{'age'} || "no") eq "yes";
unless (defined $ordering) {
   $ordering = "normal";
   $ordering = "oldview" if $old_view;
   $ordering = "raw" if $raw_sort;
   $ordering = 'age' if $age_sort;
}
my ($bug_order) = $ordering =~ /(age(?:rev)?)/;
$bug_order = '' if not defined $bug_order;

my $bug_rev = ($param{'bug-rev'} || "no") eq "yes";
my $pend_rev = ($param{'pend-rev'} || "no") eq "yes";
my $sev_rev = ($param{'sev-rev'} || "no") eq "yes";
my $pend_exc = $param{'&pend-exc'} || $param{'pend-exc'} || "";
my $pend_inc = $param{'&pend-inc'} || $param{'pend-inc'} || "";
my $sev_exc = $param{'&sev-exc'} || $param{'sev-exc'} || "";
my $sev_inc = $param{'&sev-inc'} || $param{'sev-inc'} || "";
my $maxdays = ($param{'maxdays'} || -1);
my $mindays = ($param{'mindays'} || 0);
my $version = $param{'version'} || undef;
my $dist = $param{'dist'} || undef;
my $arch = $param{'arch'} || undef;

{
    if (defined $param{'vt'}) {
        my $vt = $param{'vt'};
        if ($vt eq "none") { $dist = undef; $arch = undef; $version = undef; }
        if ($vt eq "bysuite") {
            $version = undef;
            $arch = undef if ($arch eq "any");
        }
        if ($vt eq "bypkg" || $vt eq "bysrc") { $dist = undef; $arch = undef; }
    }
    if (defined $param{'includesubj'}) {
        my $is = $param{'includesubj'};
        $include .= "," . join(",", map { "subj:$_" } (split /[\s,]+/, $is));
    }
    if (defined $param{'excludesubj'}) {
        my $es = $param{'excludesubj'};
        $exclude .= "," . join(",", map { "subj:$_" } (split /[\s,]+/, $es));
    }
}


our %hidden = map { $_, 1 } qw(status severity classification);
our %cats = (
    "status" => [ {
        "nam" => "Status",
        "pri" => [map { "pending=$_" }
            qw(pending forwarded pending-fixed fixed done absent)],
        "ttl" => ["Outstanding","Forwarded","Pending Upload",
                  "Fixed in NMU","Resolved","From other Branch"],
        "def" => "Unknown Pending Status",
        "ord" => [0,1,2,3,4,5,6],
    } ],
    "severity" => [ {
        "nam" => "Severity",
        "pri" => [map { "severity=$_" } @gSeverityList],
        "ttl" => [map { $gSeverityDisplay{$_} } @gSeverityList],
        "def" => "Unknown Severity",
        "ord" => [0..@gSeverityList],
    } ],
    "classification" => [ {
        "nam" => "Classification",
        "pri" => [qw(pending=pending+tag=wontfix 
                     pending=pending+tag=moreinfo
                     pending=pending+tag=patch
                     pending=pending+tag=confirmed
                     pending=pending)],
        "ttl" => ["Will Not Fix","More information needed",
                  "Patch Available","Confirmed"],
        "def" => "Unclassified",
        "ord" => [2,3,4,1,0,5],
    } ],
    "oldview" => [ qw(status severity) ],
    "normal" => [ qw(status severity classification) ],
);

my @select_key = (qw(submitter maint pkg package src usertag),
		  qw(status tag maintenc owner severity)
		 );

if (exists $param{which} and exists $param{data}) {
     $param{$param{which}} = [exists $param{$param{which}}?(make_list($param{$param{which}})):(),
			      make_list($param{data}),
			     ];
     delete $param{which};
     delete $param{data};
}

if (defined $param{maintenc}) {
     $param{maint} = maint_decode($param{maintenc});
     delete $param{maintenc}
}


if (not grep {exists $param{$_}} @select_key and exists $param{users}) {
     $param{usertag} = [make_list($param{users})];
}

quitcgi("You have to choose something to select by") unless grep {exists $param{$_}} @select_key;

if (exists $param{pkg}) {
     $param{package} = $param{pkg};
     delete $param{pkg};
}

our %bugusertags;
our %ut;
for my $user (map {split /[\s*,\s*]+/} make_list($param{users}||[])) {
    next unless length($user);
    add_user($user);
}

if (defined $param{usertag}) {
    my %select_ut = ();
    my ($u, $t) = split /:/, $param{usertag}, 2;
    Debbugs::User::read_usertags(\%select_ut, $u);
    unless (defined $t && $t ne "") {
        $t = join(",", keys(%select_ut));
    }

    add_user($u);
    push @{$param{tag}}, split /,/, $t;
}

my $Archived = $archive ? " Archived" : "";

our $this = munge_url('pkgreport.cgi?',
		      %param,
		     );

my %indexentry;
my %strings = ();

my $dtime = strftime "%a, %e %b %Y %T UTC", gmtime;
my $tail_html = $debbugs::gHTMLTail;
$tail_html = $debbugs::gHTMLTail;
$tail_html =~ s/SUBSTITUTE_DTIME/$dtime/;

our %seen_users;
sub add_user {
    my $ut = \%ut;
    my $u = shift;

    return if $seen_users{$u};
    $seen_users{$u} = 1;

    my $user = Debbugs::User::get_user($u);

    my %vis = map { $_, 1 } @{$user->{"visible_cats"}};
    for my $c (keys %{$user->{"categories"}}) {
        $cats{$c} = $user->{"categories"}->{$c};
	$hidden{$c} = 1 unless defined $vis{$c};
    }

    for my $t (keys %{$user->{"tags"}}) {
        $ut->{$t} = [] unless defined $ut->{$t};
        push @{$ut->{$t}}, @{$user->{"tags"}->{$t}};
    }

    %bugusertags = ();
    for my $t (keys %{$ut}) {
        for my $b (@{$ut->{$t}}) {
            $bugusertags{$b} = [] unless defined $bugusertags{$b};
            push @{$bugusertags{$b}}, $t;
        }
    }
#    set_option("bugusertags", \%bugusertags);
}

my @bugs;

# addusers for source and binary packages being searched for
my $pkgsrc = getpkgsrc();
my $srcpkg = getsrcpkgs();
for my $package (# For binary packages, add the binary package
		 # and corresponding source package
		 make_list($param{package}||[]),
		 (map {defined $pkgsrc->{$_}?($pkgsrc->{$_}):()}
		  make_list($param{package}||[]),
		 ),
		 # For source packages, add the source package
		 # and corresponding binary packages
		 make_list($param{src}||[]),
		 (map {defined $srcpkg->{$_}?($srcpkg->{$_}):()}
		  make_list($param{src}||[]),
		 ),
		) {
     next unless defined $package;
     add_user($package.'@'.$config{usertag_package_domain})
	  if defined $config{usertag_package_domain};
}


# walk through the keys and make the right get_bugs query.

my @search_key_order = (package   => 'in package',
			tag       => 'tagged',
			severity  => 'with severity',
			src       => 'in source package',
			maint     => 'in packages maintained by',
			submitter => 'submitted by',
			owner     => 'owned by',
			status    => 'with status',
		       );
my %search_keys = @search_key_order;

# Set the title sanely and clean up parameters
my @title;
while (my ($key,$value) = splice @search_key_order, 0, 2) {
     next unless exists $param{$key};
     my @entries = ();
     $param{$key} = [map {split /\s*,\s*/} make_list($param{$key})];
     for my $entry (make_list($param{$key})) {
	  my $extra = '';
	  if (exists $param{dist} and ($key eq 'package' or $key eq 'src')) {
	       my @versions = get_versions(package => $entry,
					   (exists $param{dist}?(dist => $param{dist}):()),
					   (exists $param{arch}?(arch => $param{arch}):()),
					   ($key eq 'src'?(arch => q(source)):()),
					  );
	       my $verdesc = join(', ',@versions);
	       $verdesc = 'version'.(@versions>1?'s ':' ').$verdesc;
	       $extra= " ($verdesc)" if @versions;
	  }
	  push @entries, $entry.$extra;
     }
     push @title,$value.' '.join(' or ', @entries);
}
my $title = join(' and ', map {/ or /?"($_)":$_} @title);
@title = ();

# we have to special case the maint="" search, unfortunatly.
if (defined $param{maint} and $param{maint} eq "") {
     my %maintainers = %{getmaintainers()};
     @bugs = get_bugs(function =>
		      sub {my %d=@_;
			   foreach my $try (splitpackages($d{"pkg"})) {
				return 1 if !getparsedaddrs($maintainers{$try});
			   }
			   return 0;
		      }
		     );
     $title = 'in packages with no maintainer';
}
else {
     #yeah for magick!
     @bugs = get_bugs((map {exists $param{$_}?($_,$param{$_}):()}
		       keys %search_keys, 'archive'),
		      usertags => \%ut,
		     );
}

if (defined $param{version}) {
     $title .= " at version $version";
}
elsif (defined $param{dist}) {
     $title .= " in $dist";
}

$title = html_escape($title);

my @names; my @prior; my @order;
determine_ordering();

# strip out duplicate bugs
my %bugs;
@bugs{@bugs} = @bugs;
@bugs = keys %bugs;

my $result = pkg_htmlizebugs(\@bugs);

print "Content-Type: text/html; charset=utf-8\n\n";

print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print "<HTML><HEAD>\n" . 
    "<TITLE>$title -- $gProject$Archived $gBug report logs</TITLE>\n" .
    qq(<link rel="stylesheet" href="$gWebHostBugDir/css/bugs.css" type="text/css">) .
    "</HEAD>\n" .
    '<BODY onload="pagemain();">' .
    "\n";
print "<H1>" . "$gProject$Archived $gBug report logs: $gBugs $title" .
      "</H1>\n";

my $showresult = 1;

my $pkg = $param{package} if defined $param{package};
my $src = $param{src} if defined $param{src};

my $pseudodesc = getpseudodesc();
if (defined $pseudodesc and defined $pkg and exists $pseudodesc->{$pkg}) {
     delete $param{dist};
}

# output infomration about the packages

for my $package (make_list($param{package}||[])) {
     output_package_info('binary',$package);
}
for my $package (make_list($param{src}||[])) {
     output_package_info('source',$package);
}

sub output_package_info{
    my ($srcorbin,$package) = @_;
    my $showpkg = html_escape($package);
    my $maintainers = getmaintainers();
    my $maint = $maintainers->{$package};
    if (defined $maint) {
	 print '<p>';
	 print htmlize_maintlinks(sub { $_[0] == 1 ? "Maintainer for $showpkg is "
					 : "Maintainers for $showpkg are "
				    },
			      $maint);
	 print ".</p>\n";
    } else {
	 print "<p>No maintainer for $showpkg. Please do not report new bugs against this package.</p>\n";
    }
    my %pkgsrc = %{getpkgsrc()};
    my $srcforpkg = $package;
    if ($srcorbin eq 'binary') {
	 $srcforpkg = $pkgsrc{$package};
	 defined $srcforpkg or $srcforpkg = $package;
    }
    my @pkgs = getsrcpkgs($srcforpkg);
    @pkgs = grep( !/^\Q$package\E$/, @pkgs );
    if ( @pkgs ) {
	 @pkgs = sort @pkgs;
	 if ($srcorbin eq 'binary') {
	      print "<p>You may want to refer to the following packages that are part of the same source:\n";
	 } else {
	      print "<p>You may want to refer to the following individual bug pages:\n";
	 }
	 #push @pkgs, $src if ( $src && !grep(/^\Q$src\E$/, @pkgs) );
	 print join( ", ", map( "<A href=\"" . html_escape(munge_url($this,package=>$_)) . "\">$_</A>", @pkgs ) );
	 print ".\n";
    }
    my @references;
    my $pseudodesc = getpseudodesc();
    if ($package and defined($pseudodesc) and exists($pseudodesc->{$package})) {
	 push @references, "to the <a href=\"http://${debbugs::gWebDomain}/pseudo-packages${debbugs::gHTMLSuffix}\">".
	      "list of other pseudo-packages</a>";
    } else {
	 if ($package and defined $gPackagePages) {
	      push @references, sprintf "to the <a href=\"%s\">%s package page</a>",
		   html_escape("http://${debbugs::gPackagePages}/$package"), html_escape("$package");
	 }
	 if (defined $gSubscriptionDomain) {
	      my $ptslink = $package ? $srcforpkg : $src;
	      push @references, "to the <a href=\"http://$gSubscriptionDomain/$ptslink\">Package Tracking System</a>";
	 }
	 # Only output this if the source listing is non-trivial.
	 if ($srcorbin eq 'binary' and $srcforpkg) {
	      push @references, sprintf "to the source package <a href=\"%s\">%s</a>'s bug page", html_escape(munge_url($this,src=>$srcforpkg,package=>[])), html_escape($srcforpkg);
	 }
    }
    if (@references) {
	 $references[$#references] = "or $references[$#references]" if @references > 1;
	 print "<p>You might like to refer ", join(", ", @references), ".</p>\n";
    }
    if (defined $param{maint} || defined $param{maintenc}) {
	 print "<p>If you find a bug not listed here, please\n";
	 printf "<a href=\"%s\">report it</a>.</p>\n",
	      html_escape("http://${debbugs::gWebDomain}/Reporting${debbugs::gHTMLSuffix}");
    }
    if (not $maint and not @bugs) {
	 print "<p>There is no record of the " .
	      ($srcorbin eq 'binary' ? html_escape($package) . " package"
	       : html_escape($src) . " source package").
		    ", and no bugs have been filed against it.</p>";
	 $showresult = 0;
    }
}

if (exists $param{maint} or exists $param{maintenc}) {
    print "<p>Note that maintainers may use different Maintainer fields for\n";
    print "different packages, so there may be other reports filed under\n";
    print "different addresses.\n";
}
if (exists $param{submitter}) {
    print "<p>Note that people may use different email accounts for\n";
    print "different bugs, so there may be other reports filed under\n";
    print "different addresses.\n";
}

my $archive_links;
my @archive_links;
my %archive_values = (both => 'archived and unarchived',
		      0    => 'not archived',
		      1    => 'archived',
		     );
while (my ($key,$value) = each %archive_values) {
     next if $key eq lc($param{archive});
     push @archive_links, qq(<a href=").
	  html_escape(pkg_url((
		       map {
			    $_ eq 'archive'?():($_,$param{$_})
		       } keys %param),
			    archive => $key
			   )).qq(">$value reports </a>);
}
print '<p>See the '.join (' or ',@archive_links)."</p>\n";

print $result if $showresult;

print pkg_javascript() . "\n";
print "<h2 class=\"outstanding\"><a class=\"options\" href=\"javascript:toggle(1)\">Options</a></h2>\n";
print "<div id=\"a_1\">\n";
printf "<form action=\"%s\" method=POST>\n", myurl();

print "<table class=\"forms\">\n";

my ($checked_any, $checked_sui, $checked_ver) = ("", "", "");
if (defined $dist) {
  $checked_sui = "CHECKED";
} elsif (defined $version) {
  $checked_ver = "CHECKED";
} else {
  $checked_any = "CHECKED";
}

print "<tr><td>Show bugs applicable to</td>\n";
print "    <td><input id=\"b_1_1\" name=vt value=none type=radio onchange=\"enable(1);\" $checked_any>anything</td></tr>\n";
print "<tr><td></td>";
print "    <td><input id=\"b_1_2\" name=vt value=bysuite type=radio onchange=\"enable(1);\" $checked_sui>" . pkg_htmlselectsuite(1,2,1) . " for " . pkg_htmlselectarch(1,2,2) . "</td></tr>\n";

if (defined $pkg) {
    my $v = html_escape($version) || "";
    my $pkgsane = html_escape($pkg);
    print "<tr><td></td>";
    print "    <td><input id=\"b_1_3\" name=vt value=bypkg type=radio onchange=\"enable(1);\" $checked_ver>$pkgsane version <input id=\"b_1_3_1\" name=version value=\"$v\"></td></tr>\n";
} elsif (defined $src) {
    my $v = html_escape($version) || "";
    my $srcsane = html_escape($src);
    print "<tr><td></td>";
    print "    <td><input name=vt value=bysrc type=radio onchange=\"enable(1);\" $checked_ver>$srcsane version <input id=\"b_1_3_1\" name=version value=\"$v\"></td></tr>\n";
}
print "<tr><td>&nbsp;</td></tr>\n";

my $includetags = html_escape(join(" ", grep { !m/^subj:/i } map {split /[\s,]+/} ref($include)?@{$include}:$include));
my $excludetags = html_escape(join(" ", grep { !m/^subj:/i } map {split /[\s,]+/} ref($exclude)?@{$exclude}:$exclude));
my $includesubj = html_escape(join(" ", map { s/^subj://i; $_ } grep { m/^subj:/i } map {split /[\s,]+/} ref($include)?@{$include}:$include));
my $excludesubj = html_escape(join(" ", map { s/^subj://i; $_ } grep { m/^subj:/i } map {split /[\s,]+/} ref($exclude)?@{$exclude}:$exclude));
my $vismindays = ($mindays == 0 ? "" : $mindays);
my $vismaxdays = ($maxdays == -1 ? "" : $maxdays);

my $sel_rmy = ($param{repeatmerged} ? " selected" : "");
my $sel_rmn = ($param{repeatmerged} ? "" : " selected");
my $sel_ordraw = ($ordering eq "raw" ? " selected" : "");
my $sel_ordold = ($ordering eq "oldview" ? " selected" : "");
my $sel_ordnor = ($ordering eq "normal" ? " selected" : "");
my $sel_ordage = ($ordering eq "age" ? " selected" : "");

my $chk_bugrev = ($bug_rev ? " checked" : "");
my $chk_pendrev = ($pend_rev ? " checked" : "");
my $chk_sevrev = ($sev_rev ? " checked" : "");

print <<EOF;
<tr><td>Only include bugs tagged with </td><td><input name=include value="$includetags"> or that have <input name=includesubj value="$includesubj"> in their subject</td></tr>
<tr><td>Exclude bugs tagged with </td><td><input name=exclude value="$excludetags"> or that have <input name=excludesubj value="$excludesubj"> in their subject</td></tr>
<tr><td>Only show bugs older than</td><td><input name=mindays value="$vismindays" size=5> days, and younger than <input name=maxdays value="$vismaxdays" size=5> days</td></tr>

<tr><td>&nbsp;</td></tr>

</td></tr>
<tr><td>Merged bugs should be</td><td>
<select name=repeatmerged>
<option value=yes$sel_rmy>displayed separately</option>
<option value=no$sel_rmn>combined</option>
</select>
<tr><td>Categorise bugs by</td><td>
<select name=ordering>
<option value=raw$sel_ordraw>bug number only</option>
<option value=old$sel_ordold>status and severity</option>
<option value=normal$sel_ordnor>status, severity and classification</option>
<option value=age$sel_ordage>status, severity, classification, and age</option>
EOF

{
my $any = 0;
my $o = $param{"ordering"} || "";
for my $n (keys %cats) {
    next if ($n eq "normal" || $n eq "oldview");
    next if defined $hidden{$n};
    unless ($any) {
        $any = 1;
	print "<option disabled>------</option>\n";
    }
    my @names = map { ref($_) eq "HASH" ? $_->{"nam"} : $_ } @{$cats{$n}};
    my $name;
    if (@names == 1) { $name = $names[0]; }
    else { $name = " and " . pop(@names); $name = join(", ", @names) . $name; }

    printf "<option value=\"%s\"%s>%s</option>\n",
        $n, ($o eq $n ? " selected" : ""), $name;
}
}

print "</select></td></tr>\n";

printf "<tr><td>Order bugs by</td><td>%s</td></tr>\n",
    pkg_htmlselectyesno("pend-rev", "outstanding bugs first", "done bugs first", $pend_rev);
printf "<tr><td></td><td>%s</td></tr>\n",
    pkg_htmlselectyesno("sev-rev", "highest severity first", "lowest severity first", $sev_rev);
printf "<tr><td></td><td>%s</td></tr>\n",
    pkg_htmlselectyesno("bug-rev", "oldest bugs first", "newest bugs first", $bug_rev);

print <<EOF;
<tr><td>&nbsp;</td></tr>
<tr><td colspan=2><input value="Reload page" type="submit"> with new settings</td></tr>
EOF

print "</table></form></div>\n";

print "<hr>\n";
print "<p>$tail_html";

print "</body></html>\n";

sub pkg_htmlindexentrystatus {
    my $s = shift;
    my %status = %{$s};

    my $result = "";

    my $showseverity;
    if  ($status{severity} eq 'normal') {
        $showseverity = '';
    } elsif (isstrongseverity($status{severity})) {
        $showseverity = "Severity: <em class=\"severity\">$status{severity}</em>;\n";
    } else {
        $showseverity = "Severity: <em>$status{severity}</em>;\n";
    }

    $result .= pkg_htmlpackagelinks($status{"package"}, 1);

    my $showversions = '';
    if (@{$status{found_versions}}) {
        my @found = @{$status{found_versions}};
        $showversions .= join ', ', map {s{/}{ }; html_escape($_)} @found;
    }
    if (@{$status{fixed_versions}}) {
        $showversions .= '; ' if length $showversions;
        $showversions .= '<strong>fixed</strong>: ';
        my @fixed = @{$status{fixed_versions}};
        $showversions .= join ', ', map {s{/}{ }; html_escape($_)} @fixed;
    }
    $result .= ' (<a href="'.
	 version_url($status{package},
		     $status{found_versions},
		     $status{fixed_versions},
		    ).qq{">$showversions</a>)} if length $showversions;
    $result .= ";\n";

    $result .= $showseverity;
    $result .= pkg_htmladdresslinks("Reported by: ", \&submitterurl,
                                $status{originator});
    $result .= ";\nOwned by: " . html_escape($status{owner})
               if length $status{owner};
    $result .= ";\nTags: <strong>" 
                 . html_escape(join(", ", sort(split(/\s+/, $status{tags}))))
                 . "</strong>"
                       if (length($status{tags}));

    $result .= buglinklist(";\nMerged with ", ", ",
        split(/ /,$status{mergedwith}));
    $result .= buglinklist(";\nBlocked by ", ", ",
        split(/ /,$status{blockedby}));
    $result .= buglinklist(";\nBlocks ", ", ",
        split(/ /,$status{blocks}));

    if (length($status{done})) {
        $result .= "<br><strong>Done:</strong> " . html_escape($status{done});
        my $days = bug_archiveable(bug => $status{id},
				   status => \%status,
				   days_until => 1,
				  );
        if ($days >= 0 and defined $status{location} and $status{location} ne 'archive') {
            $result .= ";\n<strong>Can be archived" . ( $days == 0 ? " today" : $days == 1 ? " in $days day" : " in $days days" ) . "</strong>";
        }
	elsif (defined $status{location} and $status{location} eq 'archived') {
	     $result .= ";\n<strong>Archived.</strong>";
	}
    }

    unless (length($status{done})) {
        if (length($status{forwarded})) {
            $result .= ";\n<strong>Forwarded</strong> to "
                       . join(', ',
			      map {maybelink($_)}
			      split /[,\s]+/,$status{forwarded}
			     );
        }
	# Check the age of the logfile
	my ($days_last,$eng_last) = secs_to_english(time - $status{log_modified});
        my ($days,$eng) = secs_to_english(time - $status{date});
	
        if ($days >= 7) {
            my $font = "";
            my $efont = "";
            $font = "em" if ($days > 30);
            $font = "strong" if ($days > 60);
            $efont = "</$font>" if ($font);
            $font = "<$font>" if ($font);

            $result .= ";\n ${font}$eng old$efont";
        }
	if ($days_last > 7) {
	    my $font = "";
            my $efont = "";
            $font = "em" if ($days_last > 30);
            $font = "strong" if ($days_last > 60);
            $efont = "</$font>" if ($font);
            $font = "<$font>" if ($font);

            $result .= ";\n ${font}Modified $eng_last ago$efont";
	}
    }

    $result .= ".";

    return $result;
}


sub pkg_htmlizebugs {
    $b = $_[0];
    my @bugs = @$b;

    my @status = ();
    my %count;
    my $header = '';
    my $footer = "<h2 class=\"outstanding\">Summary</h2>\n";

    my @dummy = ($gRemoveAge); #, @gSeverityList, @gSeverityDisplay);  #, $gHTMLExpireNote);

    if (@bugs == 0) {
        return "<HR><H2>No reports found!</H2></HR>\n";
    }

    if ( $bug_rev ) {
        @bugs = sort {$b<=>$a} @bugs;
    } else {
        @bugs = sort {$a<=>$b} @bugs;
    }
    my %seenmerged;

    my %common = (
        'show_list_header' => 1,
        'show_list_footer' => 1,
    );

    my %section = ();

    foreach my $bug (@bugs) {
        my %status = %{get_bug_status(bug=>$bug,
				      (exists $param{dist}?(dist => $param{dist}):()),
				      bugusertags => \%bugusertags,
				      (exists $param{version}?(version => $param{version}):()),
				      (exists $param{arch}?(arch => $param{arch}):()),
				     )};
        next unless %status;
        next if bug_filter(bug => $bug,
			   status => \%status,
			   (exists $param{repeatmerged}?(repeat_merged => $param{repeatmerged}):()),
			   seen_merged => \%seenmerged,
			  );

	my $html = sprintf "<li><a href=\"%s\">#%d: %s</a>\n<br>",
            bug_url($bug), $bug, html_escape($status{subject});
        $html .= pkg_htmlindexentrystatus(\%status) . "\n";
	push @status, [ $bug, \%status, $html ];
    }
    if ($bug_order eq 'age') {
	 # MWHAHAHAHA
	 @status = sort {$a->[1]{log_modified} <=> $b->[1]{log_modified}} @status;
    }
    elsif ($bug_order eq 'agerev') {
	 @status = sort {$b->[1]{log_modified} <=> $a->[1]{log_modified}} @status;
    }
    for my $entry (@status) {
        my $key = "";
	for my $i (0..$#prior) {
	    my $v = get_bug_order_index($prior[$i], $entry->[1]);
            $count{"g_${i}_${v}"}++;
	    $key .= "_$v";
	}
        $section{$key} .= $entry->[2];
        $count{"_$key"}++;
    }

    my $result = "";
    if ($ordering eq "raw") {
        $result .= "<UL class=\"bugs\">\n" . join("", map( { $_->[ 2 ] } @status ) ) . "</UL>\n";
    } else {
        $header .= "<ul>\n<div class=\"msgreceived\">\n";
	my @keys_in_order = ("");
	for my $o (@order) {
	    push @keys_in_order, "X";
	    while ((my $k = shift @keys_in_order) ne "X") {
	        for my $k2 (@{$o}) {
		    $k2+=0;
		    push @keys_in_order, "${k}_${k2}";
		}
	    }
	}
        for my $order (@keys_in_order) {
            next unless defined $section{$order};
	    my @ttl = split /_/, $order; shift @ttl;
	    my $title = $title[0]->[$ttl[0]] . " bugs";
	    if ($#ttl > 0) {
		$title .= " -- ";
		$title .= join("; ", grep {($_ || "") ne ""}
			map { $title[$_]->[$ttl[$_]] } 1..$#ttl);
	    }
	    $title = html_escape($title);

            my $count = $count{"_$order"};
            my $bugs = $count == 1 ? "bug" : "bugs";

            $header .= "<li><a href=\"#$order\">$title</a> ($count $bugs)</li>\n";
            if ($common{show_list_header}) {
                my $count = $count{"_$order"};
                my $bugs = $count == 1 ? "bug" : "bugs";
                $result .= "<H2 CLASS=\"outstanding\"><a name=\"$order\"></a>$title ($count $bugs)</H2>\n";
            } else {
                $result .= "<H2 CLASS=\"outstanding\">$title</H2>\n";
            }
            $result .= "<div class=\"msgreceived\">\n<UL class=\"bugs\">\n";
	    $result .= "\n\n\n\n";
            $result .= $section{$order};
	    $result .= "\n\n\n\n";
            $result .= "</UL>\n</div>\n";
        } 
        $header .= "</ul></div>\n";

        $footer .= "<ul>\n<div class=\"msgreceived\">";
        for my $i (0..$#prior) {
            my $local_result = '';
            foreach my $key ( @{$order[$i]} ) {
                my $count = $count{"g_${i}_$key"};
                next if !$count or !$title[$i]->[$key];
                $local_result .= "<li>$count $title[$i]->[$key]</li>\n";
            }
            if ( $local_result ) {
                $footer .= "<li>$names[$i]<ul>\n$local_result</ul></li>\n";
            }
        }
        $footer .= "</div></ul>\n";
    }

    $result = $header . $result if ( $common{show_list_header} );
    $result .= $footer if ( $common{show_list_footer} );
    return $result;
}

sub pkg_htmlpackagelinks {
    my $pkgs = shift;
    return unless defined $pkgs and $pkgs ne '';
    my $strong = shift;
    my @pkglist = splitpackages($pkgs);

    $strong = 0;
    my $openstrong  = $strong ? '<strong>' : '';
    my $closestrong = $strong ? '</strong>' : '';

    return 'Package' . (@pkglist > 1 ? 's' : '') . ': ' .
           join(', ',
                map {
                    '<a class="submitter" href="' . munge_url($this,src=>[],package=>$_) . '">' .
                    $openstrong . html_escape($_) . $closestrong . '</a>'
                } @pkglist
           );
}

sub pkg_htmladdresslinks {
     htmlize_addresslinks(@_,'submitter');
}

sub pkg_javascript {
    return <<EOF ;
<script type="text/javascript">
<!--
function pagemain() {
	toggle(1);
//	toggle(2);
	enable(1);
}

function setCookie(name, value, expires, path, domain, secure) {
  var curCookie = name + "=" + escape(value) +
      ((expires) ? "; expires=" + expires.toGMTString() : "") +
      ((path) ? "; path=" + path : "") +
      ((domain) ? "; domain=" + domain : "") +
      ((secure) ? "; secure" : "");
  document.cookie = curCookie;
}

function save_cat_cookies() {
  var cat = document.categories.categorisation.value;
  var exp = new Date();
  exp.setTime(exp.getTime() + 10 * 365 * 24 * 60 * 60 * 1000);
  var oldexp = new Date();
  oldexp.setTime(oldexp.getTime() - 1 * 365 * 24 * 60 * 60 * 1000);
  var lev;
  var done = 0;

  var u = document.getElementById("users");
  if (u != null) { u = u.value; }
  if (u == "") { u = null; }
  if (u != null) {
      setCookie("cat" + cat + "_users", u, exp, "/");
  } else {
      setCookie("cat" + cat + "_users", "", oldexp, "/");
  }

  var bits = new Array("nam", "pri", "ttl", "ord");
  for (var i = 0; i < 4; i++) {
      for (var j = 0; j < bits.length; j++) {
          var e = document.getElementById(bits[j] + i);
	  if (e) e = e.value;
	  if (e == null) { e = ""; }
	  if (j == 0 && e == "") { done = 1; }
	  if (done || e == "") {
              setCookie("cat" + cat + "_" + bits[j] + i, "", oldexp, "/");
	  } else {
              setCookie("cat" + cat + "_" + bits[j] + i, e, exp, "/");
	  }
      }
  }
}

function toggle(i) {
        var a = document.getElementById("a_" + i);
        if (a) {
             if (a.style.display == "none") {
                     a.style.display = "";
             } else {
                     a.style.display = "none";
             }
        }
}

function enable(x) {
    for (var i = 1; ; i++) {
        var a = document.getElementById("b_" + x + "_" + i);
        if (a == null) break;
        var ischecked = a.checked;
        for (var j = 1; ; j++) {
            var b = document.getElementById("b_" + x + "_"+ i + "_" + j);
            if (b == null) break;
            if (ischecked) {
                b.disabled = false;
            } else {
                b.disabled = true;
            }
        }
    }
}
-->
</script>
EOF
}

sub pkg_htmlselectyesno {
    my ($name, $n, $y, $default) = @_;
    return sprintf('<select name="%s"><option value=no%s>%s</option><option value=yes%s>%s</option></select>', $name, ($default ? "" : " selected"), $n, ($default ? " selected" : ""), $y);
}

sub pkg_htmlselectsuite {
    my $id = sprintf "b_%d_%d_%d", $_[0], $_[1], $_[2];
    my @suites = ("stable", "testing", "unstable", "experimental");
    my %suiteaka = ("stable", "etch", "testing", "lenny", "unstable", "sid");
    my $defaultsuite = "unstable";

    my $result = sprintf '<select name=dist id="%s">', $id;
    for my $s (@suites) {
        $result .= sprintf '<option value="%s"%s>%s%s</option>',
                $s, ($defaultsuite eq $s ? " selected" : ""),
                $s, (defined $suiteaka{$s} ? " (" . $suiteaka{$s} . ")" : "");
    }
    $result .= '</select>';
    return $result;
}

sub pkg_htmlselectarch {
    my $id = sprintf "b_%d_%d_%d", $_[0], $_[1], $_[2];
    my @arches = qw(alpha amd64 arm hppa i386 ia64 m68k mips mipsel powerpc s390 sparc);

    my $result = sprintf '<select name=arch id="%s">', $id;
    $result .= '<option value="any">any architecture</option>';
    for my $a (@arches) {
        $result .= sprintf '<option value="%s">%s</option>', $a, $a;
    }
    $result .= '</select>';
    return $result;
}

sub myurl {
     return html_escape(pkg_url(map {exists $param{$_}?($_,$param{$_}):()}
			     qw(archive repeatmerged mindays maxdays),
			     qw(version dist arch pkg src tag maint submitter)
			    )
		    );
}

sub make_order_list {
    my $vfull = shift;
    my @x = ();

    if ($vfull =~ m/^([^:]+):(.*)$/) {
        my $v = $1;
        for my $vv (split /,/, $2) {
	    push @x, "$v=$vv";
	}
    } else {
	for my $v (split /,/, $vfull) {
            next unless $v =~ m/.=./;
            push @x, $v;
        }
    }
    push @x, "";  # catch all
    return @x;
}

sub get_bug_order_index {
    my $order = shift;
    my $status = shift;
    my $pos = -1;

    my %tags = ();
    %tags = map { $_, 1 } split / /, $status->{"tags"}
        if defined $status->{"tags"};

    for my $el (@${order}) {
	$pos++;
        my $match = 1;
        for my $item (split /[+]/, $el) {
    	    my ($f, $v) = split /=/, $item, 2;
	    next unless (defined $f and defined $v);
	    my $isokay = 0;
	    $isokay = 1 if (defined $status->{$f} and $v eq $status->{$f});
	    $isokay = 1 if ($f eq "tag" && defined $tags{$v});
	    unless ($isokay) {
	        $match = 0;
	        last;
	    }
        }
        if ($match) {
            return $pos;
            last;
        }
    }
    return $pos + 1;
}

sub buglinklist {
    my ($prefix, $infix, @els) = @_;
    return '' if not @els;
    return $prefix . bug_linklist($infix,'submitter',@els);
}


# sets: my @names; my @prior; my @title; my @order;

sub determine_ordering {
    $cats{status}[0]{ord} = [ reverse @{$cats{status}[0]{ord}} ]
        if ($pend_rev);
    $cats{severity}[0]{ord} = [ reverse @{$cats{severity}[0]{ord}} ]
        if ($sev_rev);

    my $i;
    if (defined $param{"pri0"}) {
        my @c = ();
        $i = 0;
        while (defined $param{"pri$i"}) {
            my $h = {};

            my $pri = $param{"pri$i"};
            if ($pri =~ m/^([^:]*):(.*)$/) {
              $h->{"nam"} = $1;  # overridden later if necesary
              $h->{"pri"} = [ map { "$1=$_" } (split /,/, $2) ];
            } else {
              $h->{"pri"} = [ split /,/, $pri ];
            }

	    $h->{"nam"} = $param{"nam$i"}
                if (defined $param{"nam$i"}); 
            $h->{"ord"} = [ split /\s*,\s*/, $param{"ord$i"} ]
                if (defined $param{"ord$i"}); 
            $h->{"ttl"} = [ split /\s*,\s*/, $param{"ttl$i"} ]
                if (defined $param{"ttl$i"}); 

            push @c, $h;
	    $i++;
        }
        $cats{"_"} = [@c];
        $ordering = "_";
    }

    $ordering = "normal" unless defined $cats{$ordering};

    sub get_ordering {
        my @res;
	my $cats = shift;
        my $o = shift;
        for my $c (@{$cats->{$o}}) {
            if (ref($c) eq "HASH") {
                push @res, $c;
            } else {
                push @res, get_ordering($cats, $c);
            }
        }
        return @res;
    }
    my @cats = get_ordering(\%cats, $ordering);

    sub toenglish {
        my $expr = shift;
        $expr =~ s/[+]/ and /g;
        $expr =~ s/[a-z]+=//g;
        return $expr;
    }
 
    $i = 0;
    for my $c (@cats) {
	$i++;
        push @prior, $c->{"pri"};
	push @names, ($c->{"nam"} || "Bug attribute #" . $i);
        if (defined $c->{"ord"}) {
            push @order, $c->{"ord"};
        } else {
            push @order, [ 0..$#{$prior[-1]} ];
        }
        my @t = @{ $c->{"ttl"} } if defined $c->{ttl};
	if (@t < $#{$prior[-1]}) {
	     push @t, map { toenglish($prior[-1][$_]) } @t..($#{$prior[-1]});
	}
	push @t, $c->{"def"} || "";
        push @title, [@t];
    }
}
