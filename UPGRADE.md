# Debbugs upgrade notes #

## From 2.4.2 to 2.6 ##

Debbugs configuration file now sets default values for all configuration file
options, so if you're upgrading from earlier versions, you do not need to
specify values for the new configuration files.

### Templates ###

Debbugs now uses Text::Template for templates, and any of the existing templates
can be overridden by creating a new directory and setting `$gTemplateDir` to the
new directory.

## From 2.4.1 to 2.4.2 ##

The file format used to store the status of a bug (package, severity, etc.)
has changed; it is now in an RFC822-like format in order to be more
extensible, and is written to .summary files rather than the old .status
files. Before accepting any mail with the new version of debbugs, you must
run the 'debbugs-upgradestatus' program over your bug spool. The old .status
files will be left intact, and will continue to be written in sync with the
.summary files for compatibility with external tools.

There is a new standalone spam-scanning script called spamscan, which uses
the SpamAssassin modules. To use it, set the `$gSpamScan` variable in
`/etc/debbugs/config` to a true value and `$gSpamMailbox` to an mbox file to
which detected spam should be appended, add /usr/lib/debbugs/spamscan to
your crontab as per the example, and optionally set `$gSpamRulesDir` and
`$gSpamLocalTestsOnly` as desired.

## From 2.4 to 2.4.1 ##

Add the following variables to the /etc/debbugs/config file:

`$gHTMLSuffix = ".html";`

The use of `$gCGIDomain` has been cleaned up; formerly, it needed to begin
with "http://", which was confusingly inconsistent with all the other domain
variables. If you worked around this in your configuration, you will need to
recheck it.

## From 2.3 to 2.4 ##

Add the following variables to the /etc/debbugs/config file:

```perl
$gWebHost = "localhost";				# e.g. www.debian.org
$gWebHostBugDir = "Bugs";				# e.g. Bugs
# For now, don't change this one manually!
$gWebDomain = "$gWebHost/$gWebHostBugDir";
$gCGIDomain = "$gWebDomain/Bugs/cgi";			# e.g. cgi.debian.org
$gPackagePages = "packages.debian.org";                 # e.g. packages.debian.org
$gSubscriptionDomain = "packages.something";		# e.g. packages.qa.debian.org
$gMaintainerFileOverride = "$gConfigDir/Maintainers.override";
$gUnknownMaintainerEmail = "$gMaintainerEmail";
$gPackageSource = "$gConfigDir/indices/sources";
```

`$gWebDomain` will probably exist already; change it as shown above.

`$gSubscriptionDomain` is optional.

`$gMaintainerFileOverride is the name of a file used to manually override the
Maintainers file (which is often automatically generated).

`$gUnknownMaintainerEmail` is the address to mail when a bug report arrives
for a package with no maintainer in `$gMaintainerFile` or
`$gMaintainerFileOverride`.

`$gPackageSource` is a file containing three tab-separated columns: package
name, component (e.g. main, contrib, non-free), and the corresponding source
package name.

Add the following variable to the `/etc/debbugs/text` file:

```
############################################################################
# Description of the tags
############################################################################
`$gHTMLTagDesc = "
<dt><code>patch</code>
  <dd>A patch or some other easy procedure for fixing the `$gBug is included in
  the `$gBug logs. If there\'s a patch, but it doesn\'t resolve the `$gBug
  adequately or causes some other problems, this tag should not be used.

<dt><code>wontfix</code>
  <dd>This `$gBug won\'t be fixed. Possibly because this is a choice between two
  arbitrary ways of doing things and the maintainer and submitter prefer
  different ways of doing things, possibly because changing the behaviour
  will cause other, worse, problems for others, or possibly for other
  reasons.

<dt><code>moreinfo</code>
  <dd>This `$gBug can\'t be addressed until more information is provided by the
  submitter. The `$gBug will be closed if the submitter doesn\'t provide ore
  information in a reasonable (few months) timeframe. This is for `$gBugs like
  \"It doesn\'t work\". What doesn\'t work?

<dt><code>unreproducible</code>
  <dd>This `$gBug can\'t be reproduced on the maintainer\'s system.  Assistance
  from third parties is needed in diagnosing the cause of the problem.

<dt><code>fixed</code>
  <dd>This `$gBug is fixed or worked around, but there\'s still an issue that
  needs to be resolved. (This will eventually replace the \"fixed\" severity)

<dt><code>stable</code>
  <dd>This `$gBug affects the stable distribution in particular.  This is only
  intended to be used for ease in identifying release critical `$gBugs that
  affect the stable distribution.  It\'ll be replaced eventually with
  something a little more flexible, probably.
";
```

The bug database is now stored in a hashed directory format (db-h).  You
will need to migrate your database to this new format.  The
`/usr/sbin/debbugs-dbhash` program is provided to help you perform this
migration.

## From 2.2 to 2.3 ##

There are three new scripts that have to be installed in CGI and the front
page (or any other search you have set up) needs to be changed to use these
scripts.  They are:
	* bugreport.cgi
	* common.pl
	* pkgreport.cgi

Add the following variables to the /etc/debbugs/config file:
(the /usr/share/doc/debbugs/examples/config file can be used as a
reference)

```perl
`$gSummaryList = "summary.list";         #debian-bugs-report@lists
`$gSaveOldBugs = 1;
```

Make sure you do not have a double ,, as shown here if you're using the
default severities.  Also, 'fixed' was added to the default severities:
-                                       'normal',"Normal `$gBugs",,
+                                       'normal',"Normal `$gBugs",
+				                        'fixed',"NMU Fixed $gBugs",
 
These have been added to the /etc/debbugs/text file:
```
+############################################################################
+#  Here is a blurb to point people to ftp archive of directions.  It is
+#  used by the receive script when bouncing a badly formatted email
+#
+# $gTextInstructions = "$gBadEmailPrefix
+# $gBadEmailPrefix Instructions are available from ftp.debian.org in /debian
+# $gBadEmailPrefix and at all Debian mirror sites, in the files:
+# $gBadEmailPrefix  doc/bug-reporting.txt
+# $gBadEmailPrefix  doc/bug-log-access.txt
+# $gBadEmailPrefix  doc/bug-maint-info.txt
+# $gBadEmailPrefix";
+############################################################################
+$gTextInstructions = "$gBadEmailPrefix";
+
+
```

`$gHTMLStart = "<BODY TEXT=#0F0F0F>";	#this is used by HTML generation to create the "uniform look"`
 
The following code was added to /etc/debbugs/text if you use the new fixed
severity
```
 	<DT><CODE>wishlist</CODE>
-	<DD>for any feature request, and also for any $gBugs that are very difficult
-	to fix due to major design considerations.";
+	<DD>for any feature request, and also for any $gBugs that are very 
+	difficult to fix due to major design considerations.";
+
+	<DT><CODE>fixed</CODE>
+	<DD>fixed in the current version in the unstable archive but the fix has
+	not been fixed by the person responsible.
```
 In All such entries in /etc/debbugs/text, if you replace <BODY> with
 `$gHTMLStart`, all html pages will have the same look (as specified in
 `$gHTMLStart`):

 `$gSummaryIndex = "<HTML><HEAD><TITLE>$gProject $gBug report logs - summary index</TITLE>`
 `$gPackageLog = "<HTML><HEAD><TITLE>$gProject $gBug report logs - index by package</TITLE>`
