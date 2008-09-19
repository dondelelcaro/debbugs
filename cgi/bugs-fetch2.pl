#!/usr/bin/perl

require './common.pl';

require '/etc/debbugs/config';

%map= ($gMirrors);

my %in = readparse();

if ($in{'type'} eq 'ref') {
    $_= $in{'ref'};
    s/^\s+//; s/^\#//; s/^\s+//; s/^0*//; s/\s+$//;

    if (m/\D/ || !m/\d/) {
        print <<END;
Content-Type: text/html

<html><head><title>Bug number not numeric</title>
</head><body>
<h1>Invalid input to specific bug fetch form</h1>

You must type a number, being the bug reference number.
There should be no nondigits in your entry.
</html>
END
        exit(0);
    }
    $suburl= "bugreport.cgi?bug=$_";
} elsif ($in{'type'} eq 'package') {
    $_= $in{'package'};
    s/^\s+//; s/\s+$//; y/A-Z/a-z/;
    if (m/^[^0-9a-z]/ || m/[^-+.0-9a-z]/) {
        print <<END;
Content-Type: text/html

<html><head><title>Package name contains invalid characters</title>
</head><body>
<h1>Invalid input to package buglist fetch form</h1>

You must type a package name.  Package names start with a letter
or digit and contain only letters, digits and the characters
- + . (hyphen, plus, full stop).
</html>
END
        exit(0);
    }
    $suburl= "pkgreport.cgi?pkg=$_";
} else {
    print <<END;
Content-Type: text/plain

Please use the real DBC_WHO form. (invalid type value)
END
    exit(0);
}

$base= $gCGIDomain;

$newurl= "http://$base/$suburl";
print <<END;
Status: 301 Redirect
Location: $newurl

The bug report data you are looking for ($suburl)
is available <A href="$newurl">here</A>.

(If this link does not work then the bug or package does not exist in
the tracking system any more, or does not yet, or never did.)
END

exit(0);
