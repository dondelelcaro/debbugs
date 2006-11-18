#!/usr/bin/perl -wT

package debbugs;

use strict;
use POSIX qw(strftime nice);

require './common.pl';

use Debbugs::Config qw(:globals :text);
use Debbugs::User;
use Debbugs::CGI qw(version_url);

use vars qw($gPackagePages $gWebDomain %gSeverityDisplay @gSeverityList);

if (defined $ENV{REQUEST_METHOD} and $ENV{REQUEST_METHOD} eq 'HEAD') {
    print "Content-Type: text/html; charset=utf-8\n\n";
    exit 0;
}

nice(5);

my $userAgent = detect_user_agent();
my %param = readparse();

my $repeatmerged = ($param{'repeatmerged'} || "yes") eq "yes";
my $archive = ($param{'archive'} || "no") eq "yes";
my $include = $param{'&include'} || $param{'include'} || "";
my $exclude = $param{'&exclude'} || $param{'exclude'} || "";

my $users = $param{'users'} || "";

my $ordering = $param{'ordering'};
my $raw_sort = ($param{'raw'} || "no") eq "yes";
my $old_view = ($param{'oldview'} || "no") eq "yes";
unless (defined $ordering) {
   $ordering = "normal";
   $ordering = "oldview" if $old_view;
   $ordering = "raw" if $raw_sort;
}

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
my $show_list_header = ($param{'show_list_header'} || $userAgent->{'show_list_header'} || "yes" ) eq "yes";
my $show_list_footer = ($param{'show_list_footer'} || $userAgent->{'show_list_footer'} || "yes" ) eq "yes";

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


my %hidden = map { $_, 1 } qw(status severity classification);
my %cats = (
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

my ($pkg, $src, $maint, $maintenc, $submitter, $severity, $status, $tag, $usertag);

my %which = (
        'pkg' => \$pkg,
        'src' => \$src,
        'maint' => \$maint,
        'maintenc' => \$maintenc,
        'submitter' => \$submitter,
        'severity' => \$severity,
        'tag' => \$tag,
	'usertag' => \$usertag,
        );
my @allowedEmpty = ( 'maint' );

my $found;
foreach ( keys %which ) {
        $status = $param{'status'} || 'open' if /^severity$/;
        if (($found = $param{$_})) {
                ${ $which{$_} } = $found;
                last;
        }
}
if (!$found && !$archive) {
        foreach ( @allowedEmpty ) {
                if (exists($param{$_})) {
                        ${ $which{$_} } = '';
                        $found = 1;
                        last;
                }
        }
}
if (!$found) {
        my $which;
        if (($which = $param{'which'})) {
                if (grep( /^\Q$which\E$/, @allowedEmpty)) {
                        ${ $which{$which} } = $param{'data'};
                        $found = 1;
                } elsif (($found = $param{'data'})) {
                        ${ $which{$which} } = $found if (exists($which{$which}));
                }
        }
}
quitcgi("You have to choose something to select by") if (!$found);

my %bugusertags;
my %ut;
for my $user (split /[\s*,]+/, $users) {
    next unless ($user =~ m/..../);
    add_user($user);
}

if (defined $usertag) {
    my %select_ut = ();
    my ($u, $t) = split /:/, $usertag, 2;
    Debbugs::User::read_usertags(\%select_ut, $u);
    unless (defined $t && $t ne "") {
        $t = join(",", keys(%select_ut));
    }

    add_user($u);
    $tag = $t;
}

my $Archived = $archive ? " Archived" : "";

my $this = "";

my %indexentry;
my %strings = ();

my $dtime = strftime "%a, %e %b %Y %T UTC", gmtime;
my $tail_html = $debbugs::gHTMLTail;
$tail_html = $debbugs::gHTMLTail;
$tail_html =~ s/SUBSTITUTE_DTIME/$dtime/;

set_option("repeatmerged", $repeatmerged);
set_option("archive", $archive);
set_option("include", $include);
set_option("exclude", $exclude);
set_option("pend-exc", $pend_exc);
set_option("pend-inc", $pend_inc);
set_option("sev-exc", $sev_exc);
set_option("sev-inc", $sev_inc);
set_option("maxdays", $maxdays);
set_option("mindays", $mindays);
set_option("version", $version);
set_option("dist", $dist);
set_option("arch", $arch);
set_option("use-bug-idx", defined($param{'use-bug-idx'}) ? $param{'use-bug-idx'} : 0);
set_option("show_list_header", $show_list_header);
set_option("show_list_footer", $show_list_footer);

sub add_user {
    my $ut = \%ut;
    my $u = shift;

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
    set_option("bugusertags", \%bugusertags);
}

my $title;
my @bugs;
if (defined $pkg) {
  $title = "package $pkg";
  add_user("$pkg\@packages.debian.org");
  if (defined $version) {
    $title .= " (version $version)";
  } elsif (defined $dist) {
    $title .= " in $dist";
    my $verdesc = getversiondesc($pkg);
    $title .= " ($verdesc)" if defined $verdesc;
  }
  my @pkgs = split /,/, $pkg;
  @bugs = @{getbugs(sub {my %d=@_;
                         foreach my $try (splitpackages($d{"pkg"})) {
                           return 1 if grep($try eq $_, @pkgs);
                         }
                         return 0;
                        }, 'package', @pkgs)};
} elsif (defined $src) {
  add_user("$src\@packages.debian.org");
  $title = "source $src";
  set_option('arch', 'source');
  if (defined $version) {
    $title .= " (version $version)";
  } elsif (defined $dist) {
    $title .= " in $dist";
    my $verdesc = getversiondesc($src);
    $title .= " ($verdesc)" if defined $verdesc;
  }
  my @pkgs = ();
  my @srcs = split /,/, $src;
  foreach my $try (@srcs) {
    push @pkgs, getsrcpkgs($try);
    push @pkgs, $try if ( !grep(/^\Q$try\E$/, @pkgs) );
  }
  @bugs = @{getbugs(sub {my %d=@_;
                         foreach my $try (splitpackages($d{"pkg"})) {
                           return 1 if grep($try eq $_, @pkgs);
                         }
                         return 0;
                        }, 'package', @pkgs)};
} elsif (defined $maint) {
  my %maintainers = %{getmaintainers()};
  add_user($maint);
  $title = "maintainer $maint";
  $title .= " in $dist" if defined $dist;
  if ($maint eq "") {
    @bugs = @{getbugs(sub {my %d=@_;
                           foreach my $try (splitpackages($d{"pkg"})) {
                             return 1 if !getparsedaddrs($maintainers{$try});
                           }
                           return 0;
                          })};
  } else {
    my @maints = split /,/, $maint;
    my @pkgs = ();
    foreach my $try (@maints) {
      foreach my $p (keys %maintainers) {
        my @me = getparsedaddrs($maintainers{$p});
        push @pkgs, $p if grep { $_->address eq $try } @me;
      }
    }
    @bugs = @{getbugs(sub {my %d=@_;
                           foreach my $try (splitpackages($d{"pkg"})) {
                             my @me = getparsedaddrs($maintainers{$try});
                             return 1 if grep { $_->address eq $maint } @me;
                           }
                           return 0;
                          }, 'package', @pkgs)};
  }
} elsif (defined $maintenc) {
  my %maintainers = %{getmaintainers()};
  $title = "encoded maintainer $maintenc";
  $title .= " in $dist" if defined $dist;
  @bugs = @{getbugs(sub {my %d=@_; 
                         foreach my $try (splitpackages($d{"pkg"})) {
                           my @me = getparsedaddrs($maintainers{$try});
                           return 1 if grep {
                             maintencoded($_->address) eq $maintenc
                           } @me;
                         }
                         return 0;
                        })};
} elsif (defined $submitter) {
  add_user($submitter);
  $title = "submitter $submitter";
  $title .= " in $dist" if defined $dist;
  my @submitters = split /,/, $submitter;
  @bugs = @{getbugs(sub {my %d=@_;
                         my @se = getparsedaddrs($d{"submitter"} || "");
                         foreach my $try (@submitters) {
                           return 1 if grep { $_->address eq $try } @se;
                         }
                        }, 'submitter-email', @submitters)};
} elsif (defined($severity) && defined($status)) {
  $title = "$status $severity bugs";
  $title .= " in $dist" if defined $dist;
  my @severities = split /,/, $severity;
  my @statuses = split /,/, $status;
  @bugs = @{getbugs(sub {my %d=@_;
                       return (grep($d{"severity"} eq $_, @severities))
                         && (grep($d{"status"} eq $_, @statuses));
                     })};
} elsif (defined($severity)) {
  $title = "$severity bugs";
  $title .= " in $dist" if defined $dist;
  my @severities = split /,/, $severity;
  @bugs = @{getbugs(sub {my %d=@_;
                       return (grep($d{"severity"} eq $_, @severities));
                     }, 'severity', @severities)};
} elsif (defined($tag)) {
  $title = "bugs tagged $tag";
  $title .= " in $dist" if defined $dist;
  my @tags = split /,/, $tag;
  my %bugs = ();
  for my $t (@tags) {
      for my $b (@{$ut{$t}}) {
          $bugs{$b} = 1;
       }
  }
  @bugs = @{getbugs(sub {my %d = @_;
			 return 1 if $bugs{$d{"bug"}};
                         my %tags = map { $_ => 1 } split ' ', $d{"tags"};
                         return grep(exists $tags{$_}, @tags);
                        })};
}
$title = htmlsanit($title);

my @names; my @prior; my @title; my @order;
determine_ordering();

# strip out duplicate bugs
my %bugs;
@bugs{@bugs} = @bugs;
@bugs = keys %bugs;

my $result = pkg_htmlizebugs(\@bugs);

print "Content-Type: text/html; charset=utf-8\n\n";

print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print "<HTML><HEAD>\n" . 
    "<TITLE>$gProject$Archived $gBug report logs: $title</TITLE>\n" .
    qq(<link rel="stylesheet" href="$gWebHostBugDir/css/bugs.css" type="text/css">) .
    "</HEAD>\n" .
    '<BODY onload="pagemain();">' .
    "\n";
print "<H1>" . "$gProject$Archived $gBug report logs: $title" .
      "</H1>\n";

my $showresult = 1;

if (defined $pkg || defined $src) {
    my $showpkg = htmlsanit((defined $pkg) ? $pkg : "source package $src");
    my %maintainers = %{getmaintainers()};
    my $maint = $pkg ? $maintainers{$pkg} : $maintainers{$src} ? $maintainers{$src} : undef;
    if (defined $maint) {
        print '<p>';
        print htmlmaintlinks(sub { $_[0] == 1 ? "Maintainer for $showpkg is "
                                              : "Maintainers for $showpkg are "
                                 },
                             $maint);
        print ".</p>\n";
    } else {
        print "<p>No maintainer for $showpkg. Please do not report new bugs against this package.</p>\n";
    }
    if (defined $maint or @bugs) {
        my %pkgsrc = %{getpkgsrc()};
        my $srcforpkg;
        if (defined $pkg) {
            $srcforpkg = $pkgsrc{$pkg};
            defined $srcforpkg or $srcforpkg = $pkg;
        }
        my @pkgs = getsrcpkgs($pkg ? $srcforpkg : $src);
        undef $srcforpkg unless @pkgs;
        @pkgs = grep( !/^\Q$pkg\E$/, @pkgs ) if ( $pkg );
        if ( @pkgs ) {
            @pkgs = sort @pkgs;
            if ($pkg) {
                    print "<p>You may want to refer to the following packages that are part of the same source:\n";
            } else {
                    print "<p>You may want to refer to the following individual bug pages:\n";
            }
            push @pkgs, $src if ( $src && !grep(/^\Q$src\E$/, @pkgs) );
            print join( ", ", map( "<A href=\"" . pkgurl($_) . "\">$_</A>", @pkgs ) );
            print ".\n";
        }
        my @references;
        my $pseudodesc = getpseudodesc();
        if ($pkg and defined($pseudodesc) and exists($pseudodesc->{$pkg})) {
            push @references, "to the <a href=\"http://${debbugs::gWebDomain}/pseudo-packages${debbugs::gHTMLSuffix}\">list of other pseudo-packages</a>";
        } else {
            if ($pkg and defined $gPackagePages) {
                push @references, sprintf "to the <a href=\"%s\">%s package page</a>", urlsanit("http://${debbugs::gPackagePages}/$pkg"), htmlsanit("$pkg");
            }
            if (defined $gSubscriptionDomain) {
                my $ptslink = $pkg ? $srcforpkg : $src;
                push @references, "to the <a href=\"http://$gSubscriptionDomain/$ptslink\">Package Tracking System</a>";
            }
            # Only output this if the source listing is non-trivial.
            if ($pkg and $srcforpkg and (@pkgs or $pkg ne $srcforpkg)) {
                push @references, sprintf "to the source package <a href=\"%s\">%s</a>'s bug page", srcurl($srcforpkg), htmlsanit($srcforpkg);
            }
        }
        if (@references) {
            $references[$#references] = "or $references[$#references]" if @references > 1;
            print "<p>You might like to refer ", join(", ", @references), ".</p>\n";
        }
	if (defined $maint || defined $maintenc) {
	     print "<p>If you find a bug not listed here, please\n";
	     printf "<a href=\"%s\">report it</a>.</p>\n",
		  urlsanit("http://${debbugs::gWebDomain}/Reporting${debbugs::gHTMLSuffix}");
	}
    } else {
        print "<p>There is no record of the " .
              (defined($pkg) ? htmlsanit($pkg) . " package"
                             : htmlsanit($src) . " source package") .
              ", and no bugs have been filed against it.</p>";
        $showresult = 0;
    }
} elsif (defined $maint || defined $maintenc) {
    print "<p>Note that maintainers may use different Maintainer fields for\n";
    print "different packages, so there may be other reports filed under\n";
    print "different addresses.\n";
} elsif (defined $submitter) {
    print "<p>Note that people may use different email accounts for\n";
    print "different bugs, so there may be other reports filed under\n";
    print "different addresses.\n";
}

set_option("archive", !$archive);
printf "<p>See the <a href=\"%s\">%s reports</a></p>",
     urlsanit('pkgreport.cgi?'.join(';',
				    (map {$_ eq 'archive'?():("$_=$param{$_}")
				     } keys %param
				    ),
				    ('archive='.($archive?"no":"yes"))
				   )
	     ), ($archive ? "active" : "archived");
set_option("archive", $archive);

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
    my $v = htmlsanit($version) || "";
    my $pkgsane = htmlsanit($pkg);
    print "<tr><td></td>";
    print "    <td><input id=\"b_1_3\" name=vt value=bypkg type=radio onchange=\"enable(1);\" $checked_ver>$pkgsane version <input id=\"b_1_3_1\" name=version value=\"$v\"></td></tr>\n";
} elsif (defined $src) {
    my $v = htmlsanit($version) || "";
    my $srcsane = htmlsanit($src);
    print "<tr><td></td>";
    print "    <td><input name=vt value=bysrc type=radio onchange=\"enable(1);\" $checked_ver>$srcsane version <input id=\"b_1_3_1\" name=version value=\"$v\"></td></tr>\n";
}
print "<tr><td>&nbsp;</td></tr>\n";

my $includetags = htmlsanit(join(" ", grep { !m/^subj:/i } split /[\s,]+/, $include));
my $excludetags = htmlsanit(join(" ", grep { !m/^subj:/i } split /[\s,]+/, $exclude));
my $includesubj = htmlsanit(join(" ", map { s/^subj://i; $_ } grep { m/^subj:/i } split /[\s,]+/, $include));
my $excludesubj = htmlsanit(join(" ", map { s/^subj://i; $_ } grep { m/^subj:/i } split /[\s,]+/, $exclude));
my $vismindays = ($mindays == 0 ? "" : $mindays);
my $vismaxdays = ($maxdays == -1 ? "" : $maxdays);

my $sel_rmy = ($repeatmerged ? " selected" : "");
my $sel_rmn = ($repeatmerged ? "" : " selected");
my $sel_ordraw = ($ordering eq "raw" ? " selected" : "");
my $sel_ordold = ($ordering eq "oldview" ? " selected" : "");
my $sel_ordnor = ($ordering eq "normal" ? " selected" : "");

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
        local $_;
        s{/}{ } foreach @found;
        $showversions .= join ', ', map htmlsanit($_), @found;
    }
    if (@{$status{fixed_versions}}) {
        $showversions .= '; ' if length $showversions;
        $showversions .= '<strong>fixed</strong>: ';
        my @fixed = @{$status{fixed_versions}};
        local $_;
        s{/}{ } foreach @fixed;
        $showversions .= join ', ', map htmlsanit($_), @fixed;
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
    $result .= ";\nOwned by: " . htmlsanit($status{owner})
               if length $status{owner};
    $result .= ";\nTags: <strong>" 
                 . htmlsanit(join(", ", sort(split(/\s+/, $status{tags}))))
                 . "</strong>"
                       if (length($status{tags}));

    $result .= buglinklist(";\nMerged with ", ", ",
        split(/ /,$status{mergedwith}));
    $result .= buglinklist(";\nBlocked by ", ", ",
        split(/ /,$status{blockedby}));
    $result .= buglinklist(";\nBlocks ", ", ",
        split(/ /,$status{blocks}));

    my $days = 0;
    if (length($status{done})) {
        $result .= "<br><strong>Done:</strong> " . htmlsanit($status{done});
# Disabled until archiving actually works again
#        $days = ceil($gRemoveAge - -M buglog($status{id}));
#         if ($days >= 0) {
#             $result .= ";\n<strong>Will be archived" . ( $days == 0 ? " today" : $days == 1 ? " in $days day" : " in $days days" ) . "</strong>";
#         } else {
#             $result .= ";\n<strong>Archived</strong>";
#         }
    }

    unless (length($status{done})) {
        if (length($status{forwarded})) {
            $result .= ";\n<strong>Forwarded</strong> to "
                       . join(', ',
			      map {maybelink($_)}
			      split /[,\s]+/,$status{forwarded}
			     );
        }
        my $daysold = int((time - $status{date}) / 86400);   # seconds to days
        if ($daysold >= 7) {
            my $font = "";
            my $efont = "";
            $font = "em" if ($daysold > 30);
            $font = "strong" if ($daysold > 60);
            $efont = "</$font>" if ($font);
            $font = "<$font>" if ($font);

            my $yearsold = int($daysold / 365);
            $daysold -= $yearsold * 365;

            $result .= ";\n $font";
            my @age;
            push @age, "1 year" if ($yearsold == 1);
            push @age, "$yearsold years" if ($yearsold > 1);
            push @age, "1 day" if ($daysold == 1);
            push @age, "$daysold days" if ($daysold > 1);
            $result .= join(" and ", @age);
            $result .= " old$efont";
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
        my %status = %{getbugstatus($bug)};
        next unless %status;
        next if bugfilter($bug, %status);

        my $html = sprintf "<li><a href=\"%s\">#%d: %s</a>\n<br>",
            bugurl($bug), $bug, htmlsanit($status{subject});
        $html .= pkg_htmlindexentrystatus(\%status) . "\n";

        my $key = "";
	for my $i (0..$#prior) {
	    my $v = get_bug_order_index($prior[$i], \%status);
            $count{"g_${i}_${v}"}++;
	    $key .= "_$v";
	}
        $section{$key} .= $html;
        $count{"_$key"}++;

        push @status, [ $bug, \%status, $html ];
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
		    push @keys_in_order, "${k}_${k2}";
		}
	    }
	}
        for ( my $i = 0; $i <= $#keys_in_order; $i++ ) {
            my $order = $keys_in_order[ $i ];
            next unless defined $section{$order};
	    my @ttl = split /_/, $order; shift @ttl;
	    my $title = $title[0]->[$ttl[0]] . " bugs";
	    if ($#ttl > 0) {
		$title .= " -- ";
		$title .= join("; ", grep {($_ || "") ne ""}
			map { $title[$_]->[$ttl[$_]] } 1..$#ttl);
	    }
	    $title = htmlsanit($title);

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
                    '<a class="submitter" href="' . pkgurl($_) . '">' .
                    $openstrong . htmlsanit($_) . $closestrong . '</a>'
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
    my %suiteaka = ("stable", "sarge", "testing", "etch", "unstable", "sid");
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
    return pkg_etc_url($pkg, "pkg", 0) if defined($pkg);
    return pkg_etc_url($src, "src", 0) if defined($src);
    return pkg_etc_url($maint, "maint", 0) if defined($maint);
    return pkg_etc_url($submitter, "submitter", 0) if defined($submitter);
    return pkg_etc_url($severity, "severity", 0) if defined($severity);
    return pkg_etc_url($tag, "tag", 0) if defined($tag);
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

    if (defined $param{"pri0"}) {
        my @c = ();
        my $i = 0;
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
            $h->{"ord"} = [ split /,/, $param{"ord$i"} ]
                if (defined $param{"ord$i"}); 
            $h->{"ttl"} = [ split /,/, $param{"ttl$i"} ]
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
 
    my $i = 0;
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
	if (($#t+1) < $#{$prior[-1]}) {
	     push @t, map { toenglish($prior[-1]->[$_]) } ($#t+1)..($#{$prior[-1]});
	}
	push @t, $c->{"def"} || "";
        push @title, [@t];
    }
}
