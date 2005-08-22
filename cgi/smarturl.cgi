#!/usr/bin/perl -wT

package debbugs;

use strict;

#require '/usr/lib/debbugs/errorlib';
require './common.pl';

require '/etc/debbugs/config';
require '/etc/debbugs/text';

use vars qw($gPackagePages $gWebDomain);

if (defined $ENV{REQUEST_METHOD} and $ENV{REQUEST_METHOD} eq 'HEAD') {
    print "Content-Type: text/html; charset=utf-8\n\n";
    exit 0;
}

my $path = $ENV{PATH_INFO};

if ($path =~ m,^/(\d+)(/(\d+)(/.*)?)?$,) {
    my $bug = $1;
    my $msg = $3;
    my $rest = $4;

    my @args = ("bug=$bug");
    push @args, "msg=$msg" if (defined $msg);
    if ($rest eq "") {
        1;
    } elsif ($rest eq "/mbox") {
        push @args, "mbox=yes";
    } elsif ($rest =~ m,^/att/(\d+)(/[^/]+)?$,) {
	push @args, "att=$1";
	push @args, "filename=$2" if (defined $2);
    } else {
	bad_url();
    }

    { $ENV{"PATH"}="/bin"; exec "./bugreport.cgi", "leeturls=yes", @args; }

    print "Content-Type: text/html; charset=utf-8\n\n";
    print "<p>Couldn't execute bugreport.cgi!!";
    exit(0);
} else {
    my $suite;
    my $arch;
    if ($path =~ m,^/suite/([^/]*)(/.*)$,) {
        $suite = $1; $path = $2;
    } elsif ($path =~ m,^/arch/([^/]*)(/.*)$,) {
        $arch = $1; $path = $2;
    } elsif ($path =~ m,^/suite-arch/([^/]*)/([^/]*)(/.*)$,) {
        $suite = $1; $arch = $2; $path = $3;
    }

    my $type;
    my $what;
    my $selection;
    if ($path =~ m,^/(package|source|maint|submitter|severity|tag|user-tag)/([^/]+)(/(.*))?$,) {
        $type = $1; $what = $2; $selection = $4 || "";
	if ($selection ne "") {
	    unless ($type =~ m,^(package|source|user-tag)$,) {
	        bad_url();
	    }
	}
	my @what = split /,/, $what;
	my @selection = split /,/, $selection;
	my $typearg = $type;
	$typearg = "pkg" if ($type eq "package");
	$typearg = "src" if ($type eq "source");

	my @args = ();
	push @args, $typearg . "=" . join(",", @what);
	push @args, "version=" . join(",", @selection)
		if ($type eq "package" and $#selection >= 0);
	push @args, "utag=" . join(",", @selection)
		if ($type eq "user-tag" and $#selection >= 0);
        push @args, "arch=" . $arch if (defined $arch);
        push @args, "suite=" . $suite if (defined $suite);

        { $ENV{"PATH"}="/bin"; exec "./pkgreport.cgi", "leeturls=yes", @args }

        print "Content-Type: text/html; charset=utf-8\n\n";
        print "<p>Couldn't execute pkgreport.cgi!!";
        exit(0);
    } else {
        bad_url();
    }
}

sub bad_url {
    print "Content-Type: text/html; charset=utf-8\n\n";
    print "<p>Bad URL :(\n";
    exit(0);
}
