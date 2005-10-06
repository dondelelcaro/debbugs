#!/usr/bin/perl -wT

package debbugs;

use strict;
use POSIX qw(strftime tzset nice);

#require '/usr/lib/debbugs/errorlib';
require './common.pl';

require '/etc/debbugs/config';
require '/etc/debbugs/text';

use Debbugs::User;

use vars qw($gPackagePages $gWebDomain);

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
my $raw_sort = ($param{'raw'} || "no") eq "yes";
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

my $users = $param{'users'} || "";
my %bugusertags;
my %ut;
for my $user (split /\s*,\s*/, $users) {
    Debbugs::User::read_usertags(\%ut, $user);
}
for my $t (keys %ut) {
    for my $b (@{$ut{$t}}) {
        $bugusertags{$b} = [] unless defined $bugusertags{$b};
        push @{$bugusertags{$b}}, $t;
    }
}

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
    if (defined $param{'ordering'}) {
        my $o = $param{'ordering'};
        if ($o eq "raw") { $raw_sort = 1; $bug_rev = 0; }
        if ($o eq "normal") { $raw_sort = 0; $bug_rev = 0; }
        if ($o eq "reverse") { $raw_sort = 0; $bug_rev = 1; }
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


my ($pkg, $src, $maint, $maintenc, $submitter, $severity, $status, $tag);

my %which = (
        'pkg' => \$pkg,
        'src' => \$src,
        'maint' => \$maint,
        'maintenc' => \$maintenc,
        'submitter' => \$submitter,
        'severity' => \$severity,
        'tag' => \$tag,
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

my $Archived = $archive ? " Archived" : "";

my $this = "";

my %indexentry;
my %strings = ();

$ENV{"TZ"} = 'UTC';
tzset();

my $dtime = strftime "%a, %e %b %Y %T UTC", localtime;
my $tail_html = $debbugs::gHTMLTail;
$tail_html = $debbugs::gHTMLTail;
$tail_html =~ s/SUBSTITUTE_DTIME/$dtime/;

set_option("repeatmerged", $repeatmerged);
set_option("archive", $archive);
set_option("include", $include);
set_option("exclude", $exclude);
set_option("raw", $raw_sort);
set_option("bug-rev", $bug_rev);
set_option("pend-rev", $pend_rev);
set_option("sev-rev", $sev_rev);
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
set_option("bugusertags", \%bugusertags);

my $title;
my @bugs;
if (defined $pkg) {
  $title = "package $pkg";
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

my $result = pkg_htmlizebugs(\@bugs);

print "Content-Type: text/html; charset=utf-8\n\n";

print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print "<HTML><HEAD>\n" . 
    "<TITLE>$debbugs::gProject$Archived $debbugs::gBug report logs: $title</TITLE>\n" .
    '<link rel="stylesheet" href="/css/bugs.css" type="text/css">' .
    "</HEAD>\n" .
    '<BODY onload="toggle(1);enable(1);">' .
    "\n";
print "<H1>" . "$debbugs::gProject$Archived $debbugs::gBug report logs: $title" .
      "</H1>\n";

my $showresult = 1;

if (defined $pkg || defined $src) {
    my $showpkg = (defined $pkg) ? $pkg : "source package $src";
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
            if ($pkg and defined $debbugs::gPackagePages) {
                push @references, sprintf "to the <a href=\"%s\">%s package page</a>", urlsanit("http://${debbugs::gPackagePages}/$pkg"), htmlsanit("$pkg");
            }
            if (defined $debbugs::gSubscriptionDomain) {
                my $ptslink = $pkg ? $srcforpkg : $src;
                push @references, "to the <a href=\"http://$debbugs::gSubscriptionDomain/$ptslink\">Package Tracking System</a>";
            }
            # Only output this if the source listing is non-trivial.
            if ($pkg and $srcforpkg and (@pkgs or $pkg ne $srcforpkg)) {
                push @references, sprintf "to the source package <a href=\"%s\">%s</a>'s bug page", srcurl($srcforpkg), htmlsanit($srcforpkg);
            }
        }
        if ($pkg) {
            set_option("archive", !$archive);
            push @references, sprintf "to the <a href=\"%s\">%s reports for %s</a>", pkgurl($pkg), ($archive ? "active" : "archived"), htmlsanit($pkg);
            set_option("archive", $archive);
        }
        if (@references) {
            $references[$#references] = "or $references[$#references]" if @references > 1;
            print "<p>You might like to refer ", join(", ", @references), ".</p>\n";
        }
        print "<p>If you find a bug not listed here, please\n";
        printf "<a href=\"%s\">report it</a>.</p>\n",
               urlsanit("http://${debbugs::gWebDomain}/Reporting${debbugs::gHTMLSuffix}");
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

print $result if $showresult;

print pkg_javascript();
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
    my $v = $version || "";
    print "<tr><td></td>";
    print "    <td><input id=\"b_1_3\" name=vt value=bypkg type=radio onchange=\"enable(1);\" $checked_ver>$pkg version <input id=\"b_1_3_1\" name=version value=\"$v\"></td></tr>\n";
} elsif (defined $src) {
    my $v = $version || "";
    print "<tr><td></td>";
    print "    <td><input name=vt value=bysrc type=radio onchange=\"enable(1);\" $checked_ver>$src version <input id=\"b_1_3_1\" name=version value=\"$v\"></td></tr>\n";
}

my $sel_rmy = ($repeatmerged ? " selected" : "");
my $sel_rmn = ($repeatmerged ? "" : " selected");
my $sel_ordraw = ($raw_sort ? " selected" : "");
my $sel_ordnor = (!$raw_sort && !$bug_rev ? " selected" : "");
my $sel_ordrev = (!$raw_sort && $bug_rev ? " selected" : "");
my $includetags = join(" ", grep { !m/^subj:/i } split /[\s,]+/, $include);
my $excludetags = join(" ", grep { !m/^subj:/i } split /[\s,]+/, $exclude);
my $includesubj = join(" ", map { s/^subj://i; $_ } grep { m/^subj:/i } split /[\s,]+/, $include);
my $excludesubj = join(" ", map { s/^subj://i; $_ } grep { m/^subj:/i } split /[\s,]+/, $exclude);
my $vismindays = ($mindays == 0 ? "" : $mindays);
my $vismaxdays = ($maxdays == -1 ? "" : $maxdays);

print <<EOF;
<tr><td>Display merged bugs</td><td>
<select name=repeatmerged>
<option value=yes$sel_rmy>separately</option>
<option value=no$sel_rmn>combined</option>
</select>
</td></tr>
<tr><td>Order bugs by</td><td>
<select name=ordering>
<option value=raw$sel_ordraw>bug number</option>
<option value=normal$sel_ordnor>section, oldest first</option>
<option value=reverse$sel_ordrev>section, newest first</option>
</select>
</td></tr>
<tr><td>Only include bugs tagged with </td><td><input name=include value="$includetags"> or that have <input name=includesubj value="$includesubj"> in their subject</td></tr>
<tr><td>Exclude bugs tagged with </td><td><input name=exclude value="$excludetags"> or that have <input name=excludesubj value="$excludesubj"> in their subject</td></tr>
<tr><td>Only show bugs older than</td><td><input name=mindays value="$vismindays" size=5> days, and younger than <input name=maxdays value="$vismaxdays" size=5> days</td></tr>
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
    $result .= " ($showversions)" if length $showversions;
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

    my @merged= split(/ /,$status{mergedwith});
    my $mseparator= ";\nMerged with ";
    for my $m (@merged) {
        $result .= $mseparator."<A class=\"submitter\" href=\"" . bugurl($m) . "\">#$m</A>";
        $mseparator= ", ";
    }

    my $days = 0;
    if (length($status{done})) {
        $result .= "<br><strong>Done:</strong> " . htmlsanit($status{done});
        $days = ceil($debbugs::gRemoveAge - -M buglog($status{id}));
        if ($days >= 0) {
            $result .= ";\n<strong>Will be archived" . ( $days == 0 ? " today" : $days == 1 ? " in $days day" : " in $days days" ) . "</strong>";
        } else {
            $result .= ";\n<strong>Archived</strong>";
        }
    }

    unless (length($status{done})) {
        if (length($status{forwarded})) {
            $result .= ";\n<strong>Forwarded</strong> to "
                       . maybelink($status{forwarded});
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
    my $anydone = 0;

    my @status = ();
    my %count;
    my $header = '';
    my $footer = "<h2 class=\"outstanding\">Summary</h2>\n";

    my @dummy = ($debbugs::gRemoveAge, @debbugs::gSeverityList, @debbugs::gSeverityDisplay);  #, $debbugs::gHTMLExpireNote);

    if (@bugs == 0) {
        return "<HR><H2>No reports found!</H2></HR>\n";
    }

    if ( $bug_rev ) {
        @bugs = sort {$b<=>$a} @bugs;
    } else {
        @bugs = sort {$a<=>$b} @bugs;
    }
    my %seenmerged;

    my @common_grouping = ( 'severity', 'pending' );
    my %common_grouping_order = (
        'pending' => [ qw( pending forwarded pending-fixed fixed done absent ) ],
        'severity' => \@debbugs::gSeverityList,
    );
    my %common_grouping_display = (
        'pending' => 'Status',
        'severity' => 'Severity',
    );
    my %common_headers = (
        'pending' => {
            "pending"       => "outstanding",
            "pending-fixed" => "pending upload",
            "fixed"         => "fixed in NMU",
            "done"          => "resolved",
            "forwarded"     => "forwarded to upstream software authors",
            "absent"        => "not applicable to this version",
        },
        'severity' => \%debbugs::gSeverityDisplay,
    );
    my %common_reverse = ( 'pending' => $pend_rev, 'severity' => $sev_rev );
    my %common = (
        'show_list_header' => 1,
        'show_list_footer' => 1,
    );
    my $common_raw_sort = $raw_sort;

    my %section = ();

    foreach my $bug (@bugs) {
        my %status = %{getbugstatus($bug)};
        next unless %status;
        next if bugfilter($bug, %status);

        my $html = sprintf "<li><a href=\"%s\">#%d: %s</a>\n<br>",
            bugurl($bug), $bug, htmlsanit($status{subject});
        $html .= pkg_htmlindexentrystatus(\%status) . "\n";
        my $key = join( '_', map( {$status{$_}} @common_grouping ) );
        $section{$key} .= $html;
        $count{"_$key"}++;
        foreach my $grouping ( @common_grouping ) {
            $count{"${grouping}_$status{$grouping}"}++;
        }
        $anydone = 1 if $status{pending} eq 'done';
        push @status, [ $bug, \%status, $html ];
    }

    my $result = "";
    if ($common_raw_sort) {
        $result .= "<UL class=\"bugs\">\n" . join("", map( { $_->[ 2 ] } @status ) ) . "</UL>\n";
    } else {
        my (@order, @headers);
        for( my $i = 0; $i < @common_grouping; $i++ ) {
            my $grouping_name = $common_grouping[ $i ];
            my @items = @{ $common_grouping_order{ $grouping_name } };
            @items = reverse( @items ) if ( $common_reverse{ $grouping_name } );
            my @neworder = ();
            my @newheaders = ();
            if ( @order ) {
                foreach my $grouping ( @items ) {
                    push @neworder, map( { "${_}_$grouping" } @order );
                    push @newheaders, map( { "$_ - $common_headers{$grouping_name}{$grouping}" } @headers );
                }
                @order = @neworder;
                @headers = @newheaders;
            } else {
                push @order, @items;
                push @headers, map( { $common_headers{$common_grouping[$i]}{$_} } @items );
            }
        }
        $header .= "<ul>\n<div class=\"msgreceived\">";
        for ( my $i = 0; $i < @order; $i++ ) {
            my $order = $order[ $i ];
            next unless defined $section{$order};
            my $count = $count{"_$order"};
            my $bugs = $count == 1 ? "bug" : "bugs";
            $header .= "<li><a href=\"#$order\">$headers[$i]</a> ($count $bugs)</li>\n";
        }
        $header .= "</ul></div>\n";
        for ( my $i = 0; $i < @order; $i++ ) {
            my $order = $order[ $i ];
            next unless defined $section{$order};
            if ($common{show_list_header}) {
                my $count = $count{"_$order"};
                my $bugs = $count == 1 ? "bug" : "bugs";
                $result .= "<H2 CLASS=\"outstanding\"><a name=\"$order\"></a>$headers[$i] ($count $bugs)</H2>\n";
            } else {
                $result .= "<H2 CLASS=\"outstanding\">$headers[$i]</H2>\n";
            }
            $result .= "<div class=\"msgreceived\">\n<UL class=\"bugs\">\n";
            $result .= $section{$order};
            $result .= "</UL>\n</div>\n";
        } 
        $footer .= "<ul>\n<div class=\"msgreceived\">";
        foreach my $grouping ( @common_grouping ) {
            my $local_result = '';
            foreach my $key ( @{$common_grouping_order{ $grouping }} ) {
                my $count = $count{"${grouping}_$key"};
                next if !$count;
                $local_result .= "<li>$count $common_headers{$grouping}{$key}</li>\n";
            }
            if ( $local_result ) {
                $footer .= "<li>$common_grouping_display{$grouping}<ul>\n$local_result</ul></li>\n";
            }
        }
        $footer .= "</div></ul>\n";
    }

    $result = $header . $result if ( $common{show_list_header} );
    #$result .= "<hr><p>" . $debbugs::gHTMLExpireNote if $debbugs::gRemoveAge and $anydone;
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
    my ($prefixfunc, $urlfunc, $addresses) = @_;
    if (defined $addresses and $addresses ne '') {
        my @addrs = getparsedaddrs($addresses);
        my $prefix = (ref $prefixfunc) ? $prefixfunc->(scalar @addrs)
                                       : $prefixfunc;
        return $prefix .
               join ', ', map { sprintf '<a class="submitter" href="%s">%s</a>',
                                        $urlfunc->($_->address),
                                        htmlsanit($_->format) || '(unknown)'
                              } @addrs;
    } else {
        my $prefix = (ref $prefixfunc) ? $prefixfunc->(1) : $prefixfunc;
        return sprintf '%s<a class="submitter" href="%s">(unknown)</a>', $prefix, $urlfunc->('');
    }
}

sub pkg_javascript {
    return <<EOF ;
<script type="text/javascript">
<!--

function toggle(i) {
        var a = document.getElementById("a_" + i);
        if (a.style.display == "none") {
                a.style.display = "";
        } else {
                a.style.display = "none";
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
