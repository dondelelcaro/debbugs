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


use warnings;
use strict;

use POSIX qw(strftime nice);

use Debbugs::Config qw(:globals :text :config);

use Debbugs::User;

use Debbugs::Common qw(getparsedaddrs make_list getmaintainers getpseudodesc);

use Debbugs::Bugs qw(get_bugs bug_filter newest_bug);
use Debbugs::Packages qw(getsrcpkgs getpkgsrc get_versions);

use Debbugs::CGI qw(:all);

if (defined $ENV{REMOTE_ADDR} and $ENV{REMOTE_ADDR} =~ /^(?:218\.175\.56\.14|64\.126\
.93\.93|72\.17\.168\.57|208\.138\.29\.104|66\.63\.250\.28|71\.70\.91\.207|121\.14\.75\.|121\.14\.96\.|219\.129\.83\.13|58\.254\.39\.23)/) {
    sleep(5);
    print "Content-Type: text/html\n\nGo away.";
    exit 0;
}

use Debbugs::CGI::Pkgreport qw(:all);

use Debbugs::Text qw(:templates);

use CGI::Simple;
my $q = new CGI::Simple;

if ($q->request_method() eq 'HEAD') {
     print $q->header(-type => "text/html",
		      -charset => 'utf-8',
		     );
     exit 0;
}

my $default_params = {ordering => 'normal',
		      archive  => 0,
		      repeatmerged => 0,
		      include      => [],
		      exclude      => [],
		     };

our %param = cgi_parameters(query => $q,
			    single => [qw(ordering archive repeatmerged),
				       qw(bug-rev pend-rev sev-rev),
				       qw(maxdays mindays version),
				       qw(data which dist newest),
				      ],
			    default => $default_params,
			   );

my ($form_options,$param) = ({},undef);
($form_options,$param)= form_options_and_normal_param(\%param)
     if $param{form_options};

%param = %{$param} if defined $param;

if (exists $param{form_options} and defined $param{form_options}) {
     delete $param{form_options};
     delete $param{submit} if exists $param{submit};
     for my $default (keys %{$default_params}) {
	  if (exists $param{$default} and
	      not ref($default_params->{$default}) and
	      $default_params->{$default} eq $param{$default}
	     ) {
	       delete $param{$default};
	  }
     }
     for my $incexc (qw(include exclude)) {
	  next unless exists $param{$incexc};
	  $param{$incexc} = [grep /\S\:\S/, make_list($param{$incexc})];
     }
     print $q->redirect(munge_url('pkgreport.cgi?',%param));
     exit 0;
}

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
$param{ordering} = $ordering;

our ($bug_order) = $ordering =~ /(age(?:rev)?)/;
$bug_order = '' if not defined $bug_order;

my $bug_rev = ($param{'bug-rev'} || "no") eq "yes";
my $pend_rev = ($param{'pend-rev'} || "no") eq "yes";
my $sev_rev = ($param{'sev-rev'} || "no") eq "yes";

my @inc_exc_mapping = ({name   => 'pending',
			incexc => 'include',
			key    => 'pend-inc',
		       },
		       {name   => 'pending',
			incexc => 'exclude',
			key    => 'pend-exc',
		       },
		       {name   => 'severity',
			incexc => 'include',
			key    => 'sev-inc',
		       },
		       {name   => 'severity',
			incexc => 'exclude',
			key    => 'sev-exc',
		       },
		       {name   => 'subject',
			incexc => 'include',
			key    => 'includesubj',
		       },
		       {name   => 'subject',
			incexc => 'exclude',
			key    => 'excludesubj',
		       },
		      );
for my $incexcmap (@inc_exc_mapping) {
     push @{$param{$incexcmap->{incexc}}}, map {"$incexcmap->{name}:$_"}
	  map{split /\s*,\s*/} make_list($param{$incexcmap->{key}})
	       if exists $param{$incexcmap->{key}};
     delete $param{$incexcmap->{key}};
}


my $maxdays = ($param{'maxdays'} || -1);
my $mindays = ($param{'mindays'} || 0);
my $version = $param{'version'} || undef;
# XXX Once the options/selection is rewritten, this should go away
my $dist = $param{dist} || undef;

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


if (not grep {exists $param{$_}} keys %package_search_keys and exists $param{users}) {
     $param{usertag} = [make_list($param{users})];
}

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
     for my $usertag (make_list($param{usertag})) {
	  my %select_ut = ();
	  my ($u, $t) = split /:/, $usertag, 2;
	  Debbugs::User::read_usertags(\%select_ut, $u);
	  unless (defined $t && $t ne "") {
	       $t = join(",", keys(%select_ut));
	  }
	  add_user($u);
	  push @{$param{tag}}, split /,/, $t;
     }
}

quitcgi("You have to choose something to select by") unless grep {exists $param{$_}} keys %package_search_keys;


my $Archived = $param{archive} ? " Archived" : "";

my $this = munge_url('pkgreport.cgi?',
		      %param,
		     );

my %indexentry;
my %strings = ();

my $dtime = strftime "%a, %e %b %Y %T UTC", gmtime;
my $tail_html = $gHTMLTail;
$tail_html = $gHTMLTail;
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

my $form_option_variables = {};
$form_option_variables->{search_key_order} = [@package_search_key_order];

# Set the title sanely and clean up parameters
my @title;
my @temp = @package_search_key_order;
while (my ($key,$value) = splice @temp, 0, 2) {
     next unless exists $param{$key};
     my @entries = ();
     $param{$key} = [map {split /\s*,\s*/} make_list($param{$key})];
     for my $entry (make_list($param{$key})) {
	  my $extra = '';
	  if (exists $param{dist} and ($key eq 'package' or $key eq 'src')) {
	       my %versions = get_versions(package => $entry,
					   (exists $param{dist}?(dist => $param{dist}):()),
					   (exists $param{arch}?(arch => $param{arch}):(arch => $config{default_architectures})),
					   ($key eq 'src'?(arch => q(source)):()),
					   no_source_arch => 1,
					   return_archs => 1,
					  );
	       my $verdesc;
	       if (keys %versions > 1) {
		    $verdesc = 'versions '. join(', ',
				    map { $_ .' ['.join(', ',
						    sort @{$versions{$_}}
						   ).']';
				   } keys %versions);
	       }
	       else {
		    $verdesc = 'version '.join(', ',
					       keys %versions
					      );
	       }
	       $extra= " ($verdesc)" if keys %versions;
	  }
	  push @entries, $entry.$extra;
     }
     push @title,$value.' '.join(' or ', @entries);
}
my $title = $gBugs.' '.join(' and ', map {/ or /?"($_)":$_} @title);
@title = ();

# we have to special case the maint="" search, unfortunatly.
if (defined $param{maint} and $param{maint} eq "" or ref($param{maint}) and not @{$param{maint}}) {
     my %maintainers = %{getmaintainers()};
     @bugs = get_bugs(function =>
		      sub {my %d=@_;
			   foreach my $try (splitpackages($d{"pkg"})) {
				return 1 if not exists $maintainers{$try};
			   }
			   return 0;
		      }
		     );
     $title = $gBugs.' in packages with no maintainer';
}
elsif (defined $param{newest}) {
     my $newest_bug = newest_bug();
     @bugs = ($newest_bug - $param{newest} + 1) .. $newest_bug;
     $title = @bugs.' newest '.$gBugs;
}
else {
     #yeah for magick!
     @bugs = get_bugs((map {exists $param{$_}?($_,$param{$_}):()}
		       keys %package_search_keys, 'archive'),
		      usertags => \%ut,
		     );
}

if (defined $param{version}) {
     $title .= " at version $param{version}";
}
elsif (defined $param{dist}) {
     $title .= " in $param{dist}";
}

$title = html_escape($title);

my @names; my @prior; my @order;
determine_ordering(cats => \%cats,
		   param => \%param,
		   ordering => \$ordering,
		   names => \@names,
		   prior => \@prior,
		   title => \@title,
		   order => \@order,
		  );

# strip out duplicate bugs
my %bugs;
@bugs{@bugs} = @bugs;
@bugs = keys %bugs;

my $result = pkg_htmlizebugs(bugs => \@bugs,
			     names => \@names,
			     title => \@title,
			     order => \@order,
			     prior => \@prior,
			     ordering => $ordering,
			     bugusertags => \%bugusertags,
			     bug_rev => $bug_rev,
			     bug_order => $bug_order,
			     repeatmerged => $param{repeatmerged},
			     include => $include,
			     exclude => $exclude,
			     this => $this,
			     options => \%param,
			     (exists $param{dist})?(dist    => $param{dist}):(),
			    );

print "Content-Type: text/html; charset=utf-8\n\n";

print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print "<HTML><HEAD>\n" . 
    "<TITLE>$title -- $gProject$Archived $gBug report logs</TITLE>\n" .
    qq(<link rel="stylesheet" href="$gWebHostBugDir/css/bugs.css" type="text/css">) .
    "</HEAD>\n" .
    '<BODY onload="pagemain();">' .
    "\n";
print "<H1>" . "$gProject$Archived $gBug report logs: $title" .
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
     print generate_package_info(binary => 1,
				 package => $package,
				 options => \%param,
				 bugs    => \@bugs,
				);
}
for my $package (make_list($param{src}||[])) {
     print generate_package_info(binary => 0,
				 package => $package,
				 options => \%param,
				 bugs    => \@bugs,
				);
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

# my $archive_links;
# my @archive_links;
# my %archive_values = (both => 'archived and unarchived',
# 		      0    => 'not archived',
# 		      1    => 'archived',
# 		     );
# while (my ($key,$value) = each %archive_values) {
#      next if $key eq lc($param{archive});
#      push @archive_links, qq(<a href=").
# 	  html_escape(pkg_url((
# 		       map {
# 			    $_ eq 'archive'?():($_,$param{$_})
# 		       } keys %param),
# 			    archive => $key
# 			   )).qq(">$value reports </a>);
# }
# print '<p>See the '.join (' or ',@archive_links)."</p>\n";

print $result;

print pkg_javascript() . "\n";

print qq(<h2 class="outstanding"><!--<a class="options" href="javascript:toggle(1)">-->Options<!--</a>--></h2>\n);

print option_form(template => 'cgi/pkgreport_options',
		  param    => \%param,
		  form_options => $form_options,
		  variables => $form_option_variables,
		 );

# print "<h2 class=\"outstanding\"><a class=\"options\" href=\"javascript:toggle(1)\">Options</a></h2>\n";
# print "<div id=\"a_1\">\n";
# printf "<form action=\"%s\" method=POST>\n", myurl();
# 
# print "<table class=\"forms\">\n";
# 
# my ($checked_any, $checked_sui, $checked_ver) = ("", "", "");
# if (defined $dist) {
#   $checked_sui = "CHECKED";
# } elsif (defined $version) {
#   $checked_ver = "CHECKED";
# } else {
#   $checked_any = "CHECKED";
# }
# 
# print "<tr><td>Show bugs applicable to</td>\n";
# print "    <td><input id=\"b_1_1\" name=vt value=none type=radio onchange=\"enable(1);\" $checked_any>anything</td></tr>\n";
# print "<tr><td></td>";
# print "    <td><input id=\"b_1_2\" name=vt value=bysuite type=radio onchange=\"enable(1);\" $checked_sui>" . pkg_htmlselectsuite(1,2,1) . " for " . pkg_htmlselectarch(1,2,2) . "</td></tr>\n";
# 
# if (defined $pkg) {
#     my $v = html_escape($version) || "";
#     my $pkgsane = html_escape($pkg->[0]);
#     print "<tr><td></td>";
#     print "    <td><input id=\"b_1_3\" name=vt value=bypkg type=radio onchange=\"enable(1);\" $checked_ver>$pkgsane version <input id=\"b_1_3_1\" name=version value=\"$v\"></td></tr>\n";
# } elsif (defined $src) {
#     my $v = html_escape($version) || "";
#     my $srcsane = html_escape($src->[0]);
#     print "<tr><td></td>";
#     print "    <td><input name=vt value=bysrc type=radio onchange=\"enable(1);\" $checked_ver>$srcsane version <input id=\"b_1_3_1\" name=version value=\"$v\"></td></tr>\n";
# }
# print "<tr><td>&nbsp;</td></tr>\n";
# 
# my $includetags = html_escape(join(" ", grep { !m/^subj:/i } map {split /[\s,]+/} ref($include)?@{$include}:$include));
# my $excludetags = html_escape(join(" ", grep { !m/^subj:/i } map {split /[\s,]+/} ref($exclude)?@{$exclude}:$exclude));
# my $includesubj = html_escape(join(" ", map { s/^subj://i; $_ } grep { m/^subj:/i } map {split /[\s,]+/} ref($include)?@{$include}:$include));
# my $excludesubj = html_escape(join(" ", map { s/^subj://i; $_ } grep { m/^subj:/i } map {split /[\s,]+/} ref($exclude)?@{$exclude}:$exclude));
# my $vismindays = ($mindays == 0 ? "" : $mindays);
# my $vismaxdays = ($maxdays == -1 ? "" : $maxdays);
# 
# my $sel_rmy = ($param{repeatmerged} ? " selected" : "");
# my $sel_rmn = ($param{repeatmerged} ? "" : " selected");
# my $sel_ordraw = ($ordering eq "raw" ? " selected" : "");
# my $sel_ordold = ($ordering eq "oldview" ? " selected" : "");
# my $sel_ordnor = ($ordering eq "normal" ? " selected" : "");
# my $sel_ordage = ($ordering eq "age" ? " selected" : "");
# 
# my $chk_bugrev = ($bug_rev ? " checked" : "");
# my $chk_pendrev = ($pend_rev ? " checked" : "");
# my $chk_sevrev = ($sev_rev ? " checked" : "");
# 
# print <<EOF;
# <tr><td>Only include bugs tagged with </td><td><input name=include value="$includetags"> or that have <input name=includesubj value="$includesubj"> in their subject</td></tr>
# <tr><td>Exclude bugs tagged with </td><td><input name=exclude value="$excludetags"> or that have <input name=excludesubj value="$excludesubj"> in their subject</td></tr>
# <tr><td>Only show bugs older than</td><td><input name=mindays value="$vismindays" size=5> days, and younger than <input name=maxdays value="$vismaxdays" size=5> days</td></tr>
# 
# <tr><td>&nbsp;</td></tr>
# 
# <tr><td>Merged bugs should be</td><td>
# <select name=repeatmerged>
# <option value=yes$sel_rmy>displayed separately</option>
# <option value=no$sel_rmn>combined</option>
# </select>
# <tr><td>Categorise bugs by</td><td>
# <select name=ordering>
# <option value=raw$sel_ordraw>bug number only</option>
# <option value=old$sel_ordold>status and severity</option>
# <option value=normal$sel_ordnor>status, severity and classification</option>
# <option value=age$sel_ordage>status, severity, classification, and age</option>
# EOF
# 
# {
# my $any = 0;
# my $o = $param{"ordering"} || "";
# for my $n (keys %cats) {
#     next if ($n eq "normal" || $n eq "oldview");
#     next if defined $hidden{$n};
#     unless ($any) {
#         $any = 1;
# 	print "<option disabled>------</option>\n";
#     }
#     my @names = map { ref($_) eq "HASH" ? $_->{"nam"} : $_ } @{$cats{$n}};
#     my $name;
#     if (@names == 1) { $name = $names[0]; }
#     else { $name = " and " . pop(@names); $name = join(", ", @names) . $name; }
# 
#     printf "<option value=\"%s\"%s>%s</option>\n",
#         $n, ($o eq $n ? " selected" : ""), $name;
# }
# }
# 
# print "</select></td></tr>\n";
# 
# printf "<tr><td>Order bugs by</td><td>%s</td></tr>\n",
#     pkg_htmlselectyesno("pend-rev", "outstanding bugs first", "done bugs first", $pend_rev);
# printf "<tr><td></td><td>%s</td></tr>\n",
#     pkg_htmlselectyesno("sev-rev", "highest severity first", "lowest severity first", $sev_rev);
# printf "<tr><td></td><td>%s</td></tr>\n",
#     pkg_htmlselectyesno("bug-rev", "oldest bugs first", "newest bugs first", $bug_rev);
# 
# print <<EOF;
# <tr><td>&nbsp;</td></tr>
# <tr><td colspan=2><input value="Reload page" type="submit"> with new settings</td></tr>
# EOF
# 
# print "</table></form></div>\n";

print "<hr>\n";
print "<p>$tail_html";

print "</body></html>\n";

