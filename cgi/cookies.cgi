#!/usr/bin/perl -w

use strict;
use POSIX qw(strftime);
require './common.pl';

$ENV{"HTTP_COOKIES"} = "";
my %param = readparse();

my $clear = (defined $param{"clear"} && $param{"clear"} eq "yes");
my @time_now = gmtime(time());
my $time_future = strftime("%a, %d-%b-%Y %T GMT",
			59, 59, 23, 31, 11, $time_now[5]+10);
my $time_past = strftime("%a, %d-%b-%Y %T GMT",
			59, 59, 23, 31, 11, $time_now[5]-10);

my @cookie_options = qw(repeatmerged terse reverse trim);

print "Content-Type: text/html; charset=utf-8\n";

for my $c (@cookie_options) {
    if (defined $param{$c}) {
        printf "Set-Cookie: %s=%s; expires=%s; domain=%s; path=/\n",
	     $c, $param{$c}, $time_future, "bugs.debian.org";
    } elsif ($clear) {
        printf "Set-Cookie: %s=%s; expires=%s; domain=%s; path=/\n",
	     $c, "", $time_past, "bugs.debian.org";
    }
}
print "\n";
print "<p>Cookies set!\n";
for my $c (@cookie_options) {
    if (defined $param{$c}) {
        printf "<br>Set %s=%s\n", $c, $param{$c};
    } elsif ($clear) {
        printf "<br>Cleared %s\n", $c;
    } else {
        printf "<br>Didn't touch %s (use clear=yes to clear)\n", $c;
    }
}
