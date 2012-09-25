#!/usr/bin/perl -wT

use warnings;
use strict;
use POSIX qw(strftime nice);

use Debbugs::Config qw(:globals :text :config);
use CGI::Simple;
use Debbugs::CGI qw(:util :url :html);
use Debbugs::Common qw(getmaintainers getparsedaddrs);
use Debbugs::Bugs qw(count_bugs);
use Debbugs::Status qw(:status);
use Debbugs::Packages qw(getpkgsrc);
use Debbugs::Text qw(:templates);

nice(5);

my $q = new CGI::Simple;
my %param = cgi_parameters(query   => $q,
			   single  => [qw(indexon repeatmerged archive sortby),
				       qw(skip max_results first),
				      ],
			   default => {indexon      => 'pkg',
				       repeatmerged => 'yes',
				       archive      => 'no',
				       sortby       => 'alpha',
				       skip         => 0,
				       max_results  => 100,
				      },
			  );

if (defined $param{first}) {
     # rip out all non-words from first
     $param{first} =~ s/\W//g;
}
if (defined $param{next}) {
     $param{skip}+=$param{max_results};
}
elsif (defined $param{prev}) {
     $param{skip}-=$param{max_results};
     $param{skip} = 0 if $param{skip} < 0;
}

my $indexon = $param{indexon};
if ($param{indexon} !~ m/^(pkg|src|maint|submitter|tag)$/) {
    quitcgi("You have to choose something to index on");
}

my $repeatmerged = $param{repeatmerged} eq 'yes';
my $archive = $param{archive} eq "yes";
my $sortby = $param{sortby};
if ($sortby !~ m/^(alpha|count)$/) {
    quitcgi("Don't know how to sort like that");
}

my $Archived = $archive ? " Archived" : "";

my %maintainers = %{&getmaintainers()};
my %strings = ();

my $dtime = strftime "%a, %e %b %Y %T UTC", gmtime;

my %count;
my $tag;
my $note;
my %htmldescrip = ();
my %sortkey = ();
if ($indexon eq "pkg") {
  $tag = "package";
  %count = count_bugs(function => sub {my %d=@_; return splitpackages($d{"pkg"})});
  if (defined $param{first}) {
       %count = map {
	    if (/^\Q$param{first}\E/) {
		 ($_,$count{$_});
	    }
	    else {
		 ();
	    } 
       } keys %count;
  }
  $note = "<p>Note that with multi-binary packages there may be other\n";
  $note .= "reports filed under the different binary package names.</p>\n";
  foreach my $pkg (keys %count) {
    $sortkey{$pkg} = lc $pkg;
    $htmldescrip{$pkg} = sprintf('<a href="%s">%s</a> (%s)',
                           package_links(package => $pkg, links_only=>1),
                           html_escape($pkg),
                           htmlize_maintlinks(sub { $_[0] == 1 ? 'maintainer: '
                                                           : 'maintainers: ' },
                                          $maintainers{$pkg}));
  }
} elsif ($indexon eq "src") {
  $tag = "source package";
  my $pkgsrc = getpkgsrc();
  if (defined $param{first}) {
       %count = map {
	    if (/^\Q$param{first}\E/) {
		 ($_,$count{$_});
	    }
	    else {
		 ();
	    } 
       } keys %count;
  }
  %count = count_bugs(function => sub {my %d=@_;
                          return map {
                            $pkgsrc->{$_} || $_
                          } splitpackages($d{"pkg"});
                         });
  $note = "";
  foreach my $src (keys %count) {
    $sortkey{$src} = lc $src;
    $htmldescrip{$src} = sprintf('<a href="%s">%s</a> (%s)',
                           package_links(src => $src, links_only=>1),
                           html_escape($src),
                           htmlize_maintlinks(sub { $_[0] == 1 ? 'maintainer: '
                                                           : 'maintainers: ' },
                                          $maintainers{$src}));
  }
} elsif ($indexon eq "maint") {
  $tag = "maintainer";
  my %email2maint = ();
  %count = count_bugs(function => sub {my %d=@_;
                          return map {
                            my @me = getparsedaddrs($maintainers{$_});
                            foreach my $addr (@me) {
                              $email2maint{$addr->address} = $addr->format
                                unless exists $email2maint{$addr->address};
                            }
                            map { $_->address } @me;
                          } splitpackages($d{"pkg"});
                         });
  if (defined $param{first}) {
       %count = map {
	    if (/^\Q$param{first}\E/) {
		 ($_,$count{$_});
	    }
	    else {
		 ();
	    } 
       } keys %count;
  }
  $note = "<p>Note that maintainers may use different Maintainer fields for\n";
  $note .= "different packages, so there may be other reports filed under\n";
  $note .= "different addresses.</p>\n";
  foreach my $maint (keys %count) {
    $sortkey{$maint} = lc $email2maint{$maint} || "(unknown)";
    $htmldescrip{$maint} = htmlize_maintlinks('', $email2maint{$maint});
  }
} elsif ($indexon eq "submitter") {
  $tag = "submitter";
  my %fullname = ();
  %count = count_bugs(function => sub {my %d=@_;
                          my @se = getparsedaddrs($d{"submitter"} || "");
                          foreach my $addr (@se) {
                            $fullname{$addr->address} = $addr->format
                              unless exists $fullname{$addr->address};
                          }
                          map { $_->address } @se;
                         });
  if (defined $param{first}) {
       %count = map {
	    if (/^\Q$param{first}\E/) {
		 ($_,$count{$_});
	    }
	    else {
		 ();
	    } 
       } keys %count;
  }
  foreach my $sub (keys %count) {
    $sortkey{$sub} = lc $fullname{$sub};
    $htmldescrip{$sub} = sprintf('<a href="%s">%s</a>',
                           submitterurl($sub),
			   html_escape($fullname{$sub}));
  }
  $note = "<p>Note that people may use different email accounts for\n";
  $note .= "different bugs, so there may be other reports filed under\n";
  $note .= "different addresses.</p>\n";
} elsif ($indexon eq "tag") {
  $tag = "tag";
  %count = count_bugs(function => sub {my %d=@_; return split ' ', $d{tags}; });
  if (defined $param{first}) {
       %count = map {
	    if (/^\Q$param{first}\E/) {
		 ($_,$count{$_});
	    }
	    else {
		 ();
	    } 
       } keys %count;
  }
  $note = "";
  foreach my $keyword (keys %count) {
    $sortkey{$keyword} = lc $keyword;
    $htmldescrip{$keyword} = sprintf('<a href="%s">%s</a>',
                               tagurl($keyword),
                               html_escape($keyword));
  }
}

my $result = "<ul>\n";
my @orderedentries;
if ($sortby eq "count") {
  @orderedentries = sort { $count{$a} <=> $count{$b} } keys %count;
} else { # sortby alpha
  @orderedentries = sort { $sortkey{$a} cmp $sortkey{$b} } keys %count;
}
my $skip = $param{skip};
my $max_results = $param{max_results};
foreach my $x (@orderedentries) {
     if (not defined $param{first}) {
	  $skip-- and next if $skip > 0;
	  last if --$max_results < 0;
     }
  $result .= "<li>" . $htmldescrip{$x} . " has $count{$x} " .
            ($count{$x} == 1 ? "bug" : "bugs") . "</li>\n";
}
$result .= "</ul>\n";

print "Content-Type: text/html\n\n";

print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print "<HTML><HEAD>\n" . 
    "<TITLE>$gProject$Archived $gBug reports by $tag</TITLE>\n" .
    qq(<LINK REL="stylesheet" HREF="$gWebHostBugDir/css/bugs.css" TYPE="text/css">) .
    "</HEAD>\n" .
    '<BODY TEXT="#000000" BGCOLOR="#FFFFFF" LINK="#0000FF" VLINK="#800080">' .
    "\n";
print "<H1>" . "$gProject$Archived $gBug report logs by $tag" .
      "</H1>\n";

print $note;
print <<END;
<form>
<input type="hidden" name="skip" value="$param{skip}">
<input type="hidden" name="max_results" value="$param{max_results}">
<input type="hidden" name="indexon" value="$param{indexon}">
<input type="hidden" name="repeatmerged" value="$param{repeatmerged}">
<input type="hidden" name="archive" value="$param{archive}">
<input type="hidden" name="sortby" value="$param{sortby}">
END
if (defined $param{first}) {
     print qq(<input type="hidden" name="first" value="$param{first}">\n);
}
else {
     print q(<p>);
     if ($param{skip} > 0) {
	  print q(<input type="submit" name="prev" value="Prev">);
     }
     if (keys %count > ($param{skip} + $param{max_results})) {
	  print q(<input type="submit" name="next" value="Next">);
     }
     print qq(</p>\n);
}
print $result;

print "<hr>\n";
print fill_in_template(template=>'html/html_tail',
                       hole_var => {'&strftime' => \&POSIX::strftime,
                                   },
                      );
print "</body></html>\n";
