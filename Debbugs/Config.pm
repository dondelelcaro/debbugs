# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# Copyright 2007 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Config;

=head1 NAME

Debbugs::Config -- Configuration information for debbugs

=head1 SYNOPSIS

 use Debbugs::Config;

# to get the compatiblity interface

 use Debbugs::Config qw(:globals);

=head1 DESCRIPTION

This module provides configuration variables for all of debbugs.

=head1 CONFIGURATION FILES

The default configuration file location is /etc/debbugs/config; this
configuration file location can be set by modifying the
DEBBUGS_CONFIG_FILE env variable to point at a different location.

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT $USING_GLOBALS %config);
use base qw(Exporter);

BEGIN {
     # set the version for version checking
     $VERSION     = 1.00;
     $DEBUG = 0 unless defined $DEBUG;
     $USING_GLOBALS = 0;

     @EXPORT = ();
     %EXPORT_TAGS = (globals => [qw($gEmailDomain $gListDomain $gWebHost $gWebHostBugDir),
				 qw($gWebDomain $gHTMLSuffix $gCGIDomain $gMirrors),
				 qw($gPackagePages $gSubscriptionDomain $gProject $gProjectTitle),
				 qw($gMaintainer $gMaintainerWebpage $gMaintainerEmail $gUnknownMaintainerEmail),
				 qw($gSubmitList $gMaintList $gQuietList $gForwardList),
				 qw($gDoneList $gRequestList $gSubmitterList $gControlList),
				 qw($gStrongList),
				 qw($gBugSubscriptionDomain),
				 qw($gPackageVersionRe),
				 qw($gSummaryList $gMirrorList $gMailer $gBug),
				 qw($gBugs $gRemoveAge $gSaveOldBugs $gDefaultSeverity),
				 qw($gShowSeverities $gBounceFroms $gConfigDir $gSpoolDir),
				 qw($gIncomingDir $gWebDir $gDocDir $gMaintainerFile),
				 qw($gMaintainerFileOverride $gPseudoMaintFile $gPseudoDescFile $gPackageSource),
				 qw($gVersionPackagesDir $gVersionIndex $gBinarySourceMap $gSourceBinaryMap),
				 qw($gVersionTimeIndex),
				 qw($gSimpleVersioning),
				 qw($gCVETracker),
				 qw($gSendmail @gSendmailArguments $gLibPath $gSpamScan @gExcludeFromControl),
				 qw(%gSeverityDisplay @gTags @gSeverityList @gStrongSeverities),
				 qw(%gTagsSingleLetter),
				 qw(%gSearchEstraier),
				 qw(%gDistributionAliases),
				 qw(%gObsoleteSeverities),
				 qw(@gPostProcessall @gRemovalDefaultDistributionTags @gRemovalDistributionTags @gRemovalArchitectures),
				 qw(@gRemovalStrongSeverityDefaultDistributionTags),
				 qw(@gAffectsDistributionTags),
				 qw(@gDefaultArchitectures),
				 qw($gMachineName),
				 qw($gTemplateDir),
				 qw($gDefaultPackage),
				 qw($gSpamMaxThreads $gSpamSpamsPerThread $gSpamKeepRunning $gSpamScan $gSpamCrossassassinDb),
				],
		     text     => [qw($gBadEmailPrefix $gHTMLTail $gHTMLExpireNote),
				 ],
                     cgi => [qw($gLibravatarUri $gLibravatarCacheDir $gLibravatarUriOptions @gLibravatarBlacklist)],
		     config   => [qw(%config)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];
     $ENV{HOME} = '' if not defined $ENV{HOME};
}

use Sys::Hostname;
use File::Basename qw(dirname);
use IO::File;
use Safe;

=head1 CONFIGURATION VARIABLES

=head2 General Configuration

=over

=cut

# read in the files;
%config = ();
# untaint $ENV{DEBBUGS_CONFIG_FILE} if it's owned by us
# This enables us to test things that are -T.
if (exists $ENV{DEBBUGS_CONFIG_FILE}) {
# This causes all sorts of problems for mirrors of debbugs; disable
# it.
#     if (${[stat($ENV{DEBBUGS_CONFIG_FILE})]}[4] == $<) {
	  $ENV{DEBBUGS_CONFIG_FILE} =~ /(.+)/;
	  $ENV{DEBBUGS_CONFIG_FILE} = $1;
#      }
#      else {
# 	  die "Environmental variable DEBBUGS_CONFIG_FILE set, and $ENV{DEBBUGS_CONFIG_FILE} is not owned by the user running this script.";
#      }
}
read_config(exists $ENV{DEBBUGS_CONFIG_FILE}?$ENV{DEBBUGS_CONFIG_FILE}:'/etc/debbugs/config');

=item email_domain $gEmailDomain

The email domain of the bts

=cut

set_default(\%config,'email_domain','bugs.something');

=item list_domain $gListDomain

The list domain of the bts, defaults to the email domain

=cut

set_default(\%config,'list_domain',$config{email_domain});

=item web_host $gWebHost

The web host of the bts; defaults to the email domain

=cut

set_default(\%config,'web_host',$config{email_domain});

=item web_host_bug_dir $gWebHostDir

The directory of the web host on which bugs are kept, defaults to C<''>

=cut

set_default(\%config,'web_host_bug_dir','');

=item web_domain $gWebDomain

Full path of the web domain where bugs are kept, defaults to the
concatenation of L</web_host> and L</web_host_bug_dir>

=cut

set_default(\%config,'web_domain',$config{web_host}.($config{web_host}=~m{/$}?'':'/').$config{web_host_bug_dir});

=item html_suffix $gHTMLSuffix

Suffix of html pages, defaults to .html

=cut

set_default(\%config,'html_suffix','.html');

=item cgi_domain $gCGIDomain

Full path of the web domain where cgi scripts are kept. Defaults to
the concatentation of L</web_host> and cgi.

=cut

set_default(\%config,'cgi_domain',$config{web_domain}.($config{web_domain}=~m{/$}?'':'/').'cgi');

=item mirrors @gMirrors

List of mirrors [What these mirrors are used for, no one knows.]

=cut


set_default(\%config,'mirrors',[]);

=item package_pages  $gPackagePages

Domain where the package pages are kept; links should work in a
package_pages/foopackage manner. Defaults to undef, which means that
package links will not be made.

=cut


set_default(\%config,'package_pages',undef);

=item package_pages  $gUsertagPackageDomain

Domain where where usertags of packages belong; defaults to $gPackagePages

=cut

set_default(\%config,'usertag_package_domain',$config{package_pages});


=item subscription_domain $gSubscriptionDomain

Domain where subscriptions to package lists happen

=cut

set_default(\%config,'subscription_domain',undef);


=item cve_tracker $gCVETracker

URI to CVE security tracker; in bugreport.cgi, CVE-2001-0002 becomes
linked to http://$config{cve_tracker}CVE-2001-002

Default: security-tracker.debian.org/tracker/

=cut

set_default(\%config,'cve_tracker','security-tracker.debian.org/tracker/');


=back

=cut


=head2 Project Identification

=over

=item project $gProject

Name of the project

Default: 'Something'

=cut

set_default(\%config,'project','Something');

=item project_title $gProjectTitle

Name of this install of Debbugs, defaults to "L</project> Debbugs Install"

Default: "$config{project} Debbugs Install"

=cut

set_default(\%config,'project_title',"$config{project} Debbugs Install");

=item maintainer $gMaintainer

Name of the maintainer of this debbugs install

Default: 'Local DebBugs Owner's

=cut

set_default(\%config,'maintainer','Local DebBugs Owner');

=item maintainer_webpage $gMaintainerWebpage

Webpage of the maintainer of this install of debbugs

Default: "$config{web_domain}/~owner"

=cut

set_default(\%config,'maintainer_webpage',"$config{web_domain}/~owner");

=item maintainer_email $gMaintainerEmail

Email address of the maintainer of this Debbugs install

Default: 'root@'.$config{email_domain}

=cut

set_default(\%config,'maintainer_email','root@'.$config{email_domain});

=item unknown_maintainer_email

Email address where packages with an unknown maintainer will be sent

Default: $config{maintainer_email}

=cut

set_default(\%config,'unknown_maintainer_email',$config{maintainer_email});

=item machine_name

The name of the machine that this instance of debbugs is running on
(currently used for debbuging purposes and web page output.)

Default: Sys::Hostname::hostname()

=back

=cut

set_default(\%config,'machine_name',Sys::Hostname::hostname());

=head2 BTS Mailing Lists


=over

=item submit_list

=item maint_list

=item forward_list

=item done_list

=item request_list

=item submitter_list

=item control_list

=item summary_list

=item mirror_list

=item strong_list

=cut

set_default(\%config,   'submit_list',   'bug-submit-list');
set_default(\%config,    'maint_list',    'bug-maint-list');
set_default(\%config,    'quiet_list',    'bug-quiet-list');
set_default(\%config,  'forward_list',  'bug-forward-list');
set_default(\%config,     'done_list',     'bug-done-list');
set_default(\%config,  'request_list',  'bug-request-list');
set_default(\%config,'submitter_list','bug-submitter-list');
set_default(\%config,  'control_list',  'bug-control-list');
set_default(\%config,  'summary_list',  'bug-summary-list');
set_default(\%config,   'mirror_list',   'bug-mirror-list');
set_default(\%config,   'strong_list',   'bug-strong-list');

=item bug_subscription_domain

Domain of list for messages regarding a single bug; prefixed with
bug=${bugnum}@ when bugs are actually sent out. Set to undef or '' to
disable sending messages to the bug subscription list.

Default: list_domain

=back

=cut

set_default(\%config,'bug_subscription_domain',$config{list_domain});



=head2 Misc Options

=over

=item mailer

Name of the mailer to use

Default: exim

=cut

set_default(\%config,'mailer','exim');


=item bug

Default: bug

=item ubug

Default: ucfirst($config{bug});

=item bugs

Default: bugs

=item ubugs

Default: ucfirst($config{ubugs});

=cut

set_default(\%config,'bug','bug');
set_default(\%config,'ubug',ucfirst($config{bug}));
set_default(\%config,'bugs','bugs');
set_default(\%config,'ubugs',ucfirst($config{bugs}));

=item remove_age

Age at which bugs are archived/removed

Default: 28

=cut

set_default(\%config,'remove_age',28);

=item save_old_bugs

Whether old bugs are saved or deleted

Default: 1

=cut

set_default(\%config,'save_old_bugs',1);

=item distribution_aliases

Map of distribution aliases to the distribution name

Default:
         {experimental => 'experimental',
	  unstable     => 'unstable',
	  testing      => 'testing',
	  stable       => 'stable',
	  oldstable    => 'oldstable',
	  sid          => 'unstable',
	  lenny        => 'testing',
	  etch         => 'stable',
	  sarge        => 'oldstable',
	 }

=cut

set_default(\%config,'distribution_aliases',
	    {experimental => 'experimental',
	     unstable     => 'unstable',
	     testing      => 'testing',
	     stable       => 'stable',
	     oldstable    => 'oldstable',
	     sid          => 'unstable',
	     lenny        => 'testing',
	     etch         => 'stable',
	     sarge        => 'oldstable',
	    },
	   );



=item distributions

List of valid distributions

Default: The values of the distribution aliases map.

=cut

my %_distributions_default;
@_distributions_default{values %{$config{distribution_aliases}}} = values %{$config{distribution_aliases}};
set_default(\%config,'distributions',[keys %_distributions_default]);


=item default_architectures

List of default architectures to use when architecture(s) are not
specified

Default: i386 amd64 arm ppc sparc alpha

=cut

set_default(\%config,'default_architectures',
	    [qw(i386 amd64 arm powerpc sparc alpha)]
	   );

=item affects_distribution_tags

List of tags which restrict the buggy state to a set of distributions.

The set of distributions that are buggy is the intersection of the set
of distributions that would be buggy without reference to these tags
and the set of these tags that are distributions which are set on a
bug.

Setting this to [] will remove this feature.

Default: @{$config{distributions}}

=cut

set_default(\%config,'affects_distribution_tags',
	    [@{$config{distributions}}],
	   );

=item removal_unremovable_tags

Bugs which have these tags set cannot be archived

Default: []

=cut

set_default(\%config,'removal_unremovable_tags',
	    [],
	   );

=item removal_distribution_tags

Tags which specifiy distributions to check

Default: @{$config{distributions}}

=cut

set_default(\%config,'removal_distribution_tags',
	    [@{$config{distributions}}]);

=item removal_default_distribution_tags

For removal/archival purposes, all bugs are assumed to have these tags
set.

Default: qw(experimental unstable testing);

=cut

set_default(\%config,'removal_default_distribution_tags',
	    [qw(experimental unstable testing)]
	   );

=item removal_strong_severity_default_distribution_tags

For removal/archival purposes, all bugs with strong severity are
assumed to have these tags set.

Default: qw(experimental unstable testing stable);

=cut

set_default(\%config,'removal_strong_severity_default_distribution_tags',
	    [qw(experimental unstable testing stable)]
	   );


=item removal_architectures

For removal/archival purposes, these architectures are consulted if
there is more than one architecture applicable. If the bug is in a
package not in any of these architectures, the architecture actually
checked is undefined.

Default: value of default_architectures

=cut

set_default(\%config,'removal_architectures',
	    $config{default_architectures},
	   );


=item package_name_re

The regex which will match a package name

Default: '[a-z0-9][a-z0-9\.+-]+'

=cut

set_default(\%config,'package_name_re',
	    '[a-z0-9][a-z0-9\.+-]+');

=item package_version_re

The regex which will match a package version

Default: '[A-Za-z0-9:+\.-]+'

=cut


set_default(\%config,'package_version_re',
	    '[A-Za-z0-9:+\.~-]+');


=item default_package

This is the name of the default package. If set, bugs assigned to
packages without a maintainer and bugs missing a Package: psuedoheader
will be assigned to this package instead.

Defaults to unset, which is the traditional debbugs behavoir

=cut

set_default(\%config,'default_package',
	    undef
	   );


=item control_internal_requester

This address is used by Debbugs::Control as the request address which
sent a control request for faked log messages.

Default:"Debbugs Internal Request <$config{maintainer_email}>"

=cut

set_default(\%config,'control_internal_requester',
	    "Debbugs Internal Request <$config{maintainer_email}>",
	   );

=item control_internal_request_addr

This address is used by Debbugs::Control as the address to which a
faked log message request was sent.

Default: "internal_control\@$config{email_domain}";

=cut

set_default(\%config,'control_internal_request_addr',
	    'internal_control@'.$config{email_domain},
	   );


=item exclude_from_control

Addresses which are not allowed to send messages to control

=cut

set_default(\%config,'exclude_from_control',[]);



=item default_severity

The default severity of bugs which have no severity set

Default: normal

=cut

set_default(\%config,'default_severity','normal');

=item severity_display

A hashref of severities and the informative text which describes them.

Default:

 {critical => "Critical $config{bugs}",
  grave    => "Grave $config{bugs}",
  normal   => "Normal $config{bugs}",
  wishlist => "Wishlist $config{bugs}",
 }

=cut

set_default(\%config,'severity_display',{critical => "Critical $config{bugs}",
					 grave    => "Grave $config{bugs}",
					 serious  => "Serious $config{bugs}",
					 important=> "Important $config{bugs}",
					 normal   => "Normal $config{bugs}",
					 minor    => "Minor $config{bugs}",
					 wishlist => "Wishlist $config{bugs}",
					});

=item show_severities

A scalar list of the severities to show

Defaults to the concatenation of the keys of the severity_display
hashlist with ', ' above.

=cut

set_default(\%config,'show_severities',join(', ',keys %{$config{severity_display}}));

=item strong_severities

An arrayref of the serious severities which shoud be emphasized

Default: [qw(critical grave)]

=cut

set_default(\%config,'strong_severities',[qw(critical grave)]);

=item severity_list

An arrayref of a list of the severities

Defaults to the keys of the severity display hashref

=cut

set_default(\%config,'severity_list',[keys %{$config{severity_display}}]);

=item obsolete_severities

A hashref of obsolete severities with the replacing severity

Default: {}

=cut

set_default(\%config,'obsolete_severities',{});

=item tags

An arrayref of the tags used

Default: [qw(patch wontfix moreinfo unreproducible fixed)] and also
includes the distributions.

=cut

set_default(\%config,'tags',[qw(patch wontfix moreinfo unreproducible fixed),
			     @{$config{distributions}}
			    ]);

set_default(\%config,'tags_single_letter',
	    {patch => '+',
	     wontfix => '',
	     moreinfo => 'M',
	     unreproducible => 'R',
	     fixed   => 'F',
	    }
	   );

set_default(\%config,'bounce_froms','^mailer|^da?emon|^post.*mast|^root|^wpuser|^mmdf|^smt.*|'.
	    '^mrgate|^vmmail|^mail.*system|^uucp|-maiser-|^mal\@|'.
	    '^mail.*agent|^tcpmail|^bitmail|^mailman');

set_default(\%config,'config_dir',dirname(exists $ENV{DEBBUGS_CONFIG_FILE}?$ENV{DEBBUGS_CONFIG_FILE}:'/etc/debbugs/config'));
set_default(\%config,'spool_dir','/var/lib/debbugs/spool');

=item usertag_dir

Directory which contains the usertags

Default: $config{spool_dir}/user

=cut

set_default(\%config,'usertag_dir',$config{spool_dir}.'/user');
set_default(\%config,'incoming_dir','incoming');

=item web_dir $gWebDir

Directory where base html files are kept. Should normally be the same
as the web server's document root.

Default: /var/lib/debbugs/www

=cut

set_default(\%config,'web_dir','/var/lib/debbugs/www');
set_default(\%config,'doc_dir','/var/lib/debbugs/www/txt');
set_default(\%config,'lib_path','/usr/lib/debbugs');


=item template_dir

directory of templates; defaults to /usr/share/debbugs/templates.

=cut

set_default(\%config,'template_dir','/usr/share/debbugs/templates');


set_default(\%config,'maintainer_file',$config{config_dir}.'/Maintainers');
set_default(\%config,'maintainer_file_override',$config{config_dir}.'/Maintainers.override');
set_default(\%config,'source_maintainer_file',$config{config_dir}.'/Source_maintainers');
set_default(\%config,'source_maintainer_file_override',undef);
set_default(\%config,'pseudo_maint_file',$config{config_dir}.'/pseudo-packages.maintainers');
set_default(\%config,'pseudo_desc_file',$config{config_dir}.'/pseudo-packages.description');
set_default(\%config,'package_source',$config{config_dir}.'/indices/sources');


=item simple_versioning

If true this causes debbugs to ignore version information and just
look at whether a bug is done or not done. Primarily of interest for
debbugs installs which don't track versions. defaults to false.

=cut

set_default(\%config,'simple_versioning',0);


=item version_packages_dir

Location where the version package information is kept; defaults to
spool_dir/../versions/pkg

=cut

set_default(\%config,'version_packages_dir',$config{spool_dir}.'/../versions/pkg');

=item version_time_index

Location of the version/time index file. Defaults to
spool_dir/../versions/idx/versions_time.idx if spool_dir/../versions
exists; otherwise defaults to undef.

=cut


set_default(\%config,'version_time_index', -d $config{spool_dir}.'/../versions' ? $config{spool_dir}.'/../versions/indices/versions_time.idx' : undef);

=item version_index

Location of the version index file. Defaults to
spool_dir/../versions/indices/versions.idx if spool_dir/../versions
exists; otherwise defaults to undef.

=cut

set_default(\%config,'version_index',-d $config{spool_dir}.'/../versions' ? $config{spool_dir}.'/../versions/indices/versions.idx' : undef);

=item binary_source_map

Location of the binary -> source map. Defaults to
spool_dir/../versions/indices/bin2src.idx if spool_dir/../versions
exists; otherwise defaults to undef.

=cut

set_default(\%config,'binary_source_map',-d $config{spool_dir}.'/../versions' ? $config{spool_dir}.'/../versions/indices/binsrc.idx' : undef);

=item source_binary_map

Location of the source -> binary map. Defaults to
spool_dir/../versions/indices/src2bin.idx if spool_dir/../versions
exists; otherwise defaults to undef.

=cut

set_default(\%config,'source_binary_map',-d $config{spool_dir}.'/../versions' ? $config{spool_dir}.'/../versions/indices/srcbin.idx' : undef);



set_default(\%config,'post_processall',[]);

=item sendmail

Sets the sendmail binary to execute; defaults to /usr/lib/sendmail

=cut

set_default(\%config,'sendmail','/usr/lib/sendmail');

=item sendmail_arguments

Default arguments to pass to sendmail. Defaults to C<qw(-oem -oi)>.

=cut

set_default(\%config,'sendmail_arguments',[qw(-oem -oi)]);

=item spam_scan

Whether or not spamscan is being used; defaults to 0 (not being used

=cut

set_default(\%config,'spam_scan',0);

=item spam_crossassassin_db

Location of the crosassassin database, defaults to
spool_dir/../CrossAssassinDb

=cut

set_default(\%config,'spam_crossassassin_db',$config{spool_dir}.'/../CrossAssassinDb');

=item spam_max_cross

Maximum number of cross-posted messages

=cut

set_default(\%config,'spam_max_cross',6);


=item spam_spams_per_thread

Number of spams for each thread (on average). Defaults to 200

=cut

set_default(\%config,'spam_spams_per_thread',200);

=item spam_max_threads

Maximum number of threads to start. Defaults to 20

=cut

set_default(\%config,'spam_max_threads',20);

=item spam_keep_running

Maximum number of seconds to run without restarting. Defaults to 3600.

=cut

set_default(\%config,'spam_keep_running',3600);

=item spam_mailbox

Location to store spam messages; is run through strftime to allow for
%d,%m,%Y, et al. Defaults to 'spool_dir/../mail/spam/assassinated.%Y-%m-%d'

=cut

set_default(\%config,'spam_mailbox',$config{spool_dir}.'/../mail/spam/assassinated.%Y-%m-%d');

=item spam_crossassassin_mailbox

Location to store crossassassinated messages; is run through strftime
to allow for %d,%m,%Y, et al. Defaults to
'spool_dir/../mail/spam/crossassassinated.%Y-%m-%d'

=cut

set_default(\%config,'spam_crossassassin_mailbox',$config{spool_dir}.'/../mail/spam/crossassassinated.%Y-%m-%d');

=item spam_local_tests_only

Whether only local tests are run, defaults to 0

=cut

set_default(\%config,'spam_local_tests_only',0);

=item spam_user_prefs

User preferences for spamassassin, defaults to $ENV{HOME}/.spamassassin/user_prefs

=cut

set_default(\%config,'spam_user_prefs',"$ENV{HOME}/.spamassassin/user_prefs");

=item spam_rules_dir

Site rules directory for spamassassin, defaults to
'/usr/share/spamassassin'

=cut

set_default(\%config,'spam_rules_dir','/usr/share/spamassassin');

=back

=head2 CGI Options

=over

=item libravatar_uri $gLibravatarUri

URI to a libravatar configuration. If empty or undefined, libravatar
support will be disabled. Defaults to
libravatar.cgi, our internal federated libravatar system.

=cut

set_default(\%config,'libravatar_uri','http://'.$config{cgi_domain}.'/libravatar.cgi?email=');

=item libravatar_uri_options $gLibravatarUriOptions

Options to append to the md5_hex of the e-mail. This sets the default
avatar used when an avatar isn't available. Currently defaults to
'?d=retro', which causes a bitmap-looking avatar to be displayed for
unknown e-mails.

Other options which make sense include ?d=404, ?d=wavatar, etc. See
the API of libravatar for details.

=cut

set_default(\%config,'libravatar_uri_options','');

=item libravatar_default_image

Default image to serve for libravatar if there is no avatar for an
e-mail address. By default, this is a 1x1 png. [This will also be the
image served if someone specifies avatar=no.]

Default: $config{web_dir}/1x1.png

=cut

set_default(\%config,'libravatar_default_image',$config{web_dir}.'/1x1.png');

=item libravatar_cache_dir

Directory where cached libravatar images are stored

Default: $config{web_dir}/libravatar/

=cut

set_default(\%config,'libravatar_cache_dir',$config{web_dir}.'/libravatar/');

=item libravatar_blacklist

Array of regular expressions to match against emails, domains, or
images to only show the default image

Default: empty array

=cut

set_default(\%config,'libravatar_blacklist',[]);

=back

=head2 Text Fields

The following are the only text fields in general use in the scripts;
a few additional text fields are defined in text.in, but are only used
in db2html and a few other specialty scripts.

Earlier versions of debbugs defined these values in /etc/debbugs/text,
but now they are required to be in the configuration file. [Eventually
the longer ones will move out into a fully fledged template system.]

=cut

=over

=item bad_email_prefix

This prefixes the text of all lines in a bad e-mail message ack.

=cut

set_default(\%config,'bad_email_prefix','');


=item text_instructions

This gives more information about bad e-mails to receive.in

=cut

set_default(\%config,'text_instructions',$config{bad_email_prefix});

=item html_tail

This shows up at the end of (most) html pages

In many pages this has been replaced by the html/tail template.

=cut

set_default(\%config,'html_tail',<<END);
 <ADDRESS>$config{maintainer} &lt;<A HREF=\"mailto:$config{maintainer_email}\">$config{maintainer_email}</A>&gt;.
 Last modified:
 <!--timestamp-->
 SUBSTITUTE_DTIME
 <!--timestamp-->
 <P>
 <A HREF=\"http://$config{web_domain}/\">Debian $config{bug} tracking system</A><BR>
 Copyright (C) 1999 Darren O. Benham,
 1997,2003 nCipher Corporation Ltd,
 1994-97 Ian Jackson.
 </P>
 </ADDRESS>
END


=item html_expire_note

This message explains what happens to archive/remove-able bugs

=cut

set_default(\%config,'html_expire_note',
	    "(Closed $config{bugs} are archived $config{remove_age} days after the last related message is received.)");

=back

=cut


sub read_config{
     my ($conf_file) = @_;
     if (not -e $conf_file) {
	 print STDERR "configuration file '$conf_file' doesn't exist; skipping it\n" if $DEBUG;
	 return;
     }
     # first, figure out what type of file we're reading in.
     my $fh = new IO::File $conf_file,'r'
	  or die "Unable to open configuration file $conf_file for reading: $!";
     # A new version configuration file must have a comment as its first line
     my $first_line = <$fh>;
     my ($version) = defined $first_line?$first_line =~ /VERSION:\s*(\d+)/i:undef;
     if (defined $version) {
	  if ($version == 1) {
	       # Do something here;
	       die "Version 1 configuration files not implemented yet";
	  }
	  else {
	       die "Version $version configuration files are not supported";
	  }
     }
     else {
	  # Ugh. Old configuration file
	  # What we do here is we create a new Safe compartment
          # so fucked up crap in the config file doesn't sink us.
	  my $cpt = new Safe or die "Unable to create safe compartment";
	  # perldoc Opcode; for details
	  $cpt->permit('require',':filesys_read','entereval','caller','pack','unpack','dofile');
	  $cpt->reval(qq(require '$conf_file';));
	  die "Error in configuration file: $@" if $@;
	  # Now what we do is check out the contents of %EXPORT_TAGS to see exactly which variables
	  # we want to glob in from the configuration file
	  for my $variable (map {$_ =~ /^(?:config|all)$/ ? () : @{$EXPORT_TAGS{$_}}} keys %EXPORT_TAGS) {
	       my ($hash_name,$glob_name,$glob_type) = __convert_name($variable);
	       my $var_glob = $cpt->varglob($glob_name);
	       my $value; #= $cpt->reval("return $variable");
	       # print STDERR "$variable $value",qq(\n);
	       if (defined $var_glob) {{
	       	    no strict 'refs';
	       	    if ($glob_type eq '%') {
	       		 $value = {%{*{$var_glob}}} if defined *{$var_glob}{HASH};
		    }
		    elsif ($glob_type eq '@') {
	       		 $value = [@{*{$var_glob}}] if defined *{$var_glob}{ARRAY};
	       	    }
	       	    else {
	       		 $value = ${*{$var_glob}};
	       	    }
		    # We punt here, because we can't tell if the value was
                    # defined intentionally, or if it was just left alone;
                    # this tries to set sane defaults.
		    set_default(\%config,$hash_name,$value) if defined $value;
	       }}
	  }
     }
}

sub __convert_name{
     my ($variable) = @_;
     my $hash_name = $variable;
     $hash_name =~ s/^([\$\%\@])g//;
     my $glob_type = $1;
     my $glob_name = 'g'.$hash_name;
     $hash_name =~ s/(HTML|CGI|CVE)/ucfirst(lc($1))/ge;
     $hash_name =~ s/^([A-Z]+)/lc($1)/e;
     $hash_name =~ s/([A-Z]+)/'_'.lc($1)/ge;
     return $hash_name unless wantarray;
     return ($hash_name,$glob_name,$glob_type);
}

# set_default

# sets the configuration hash to the default value if it's not set,
# otherwise doesn't do anything
# If $USING_GLOBALS, then sets an appropriate global.

sub set_default{
     my ($config,$option,$value) = @_;
     my $varname;
     if ($USING_GLOBALS) {
	  # fix up the variable name
	  $varname = 'g'.join('',map {ucfirst $_} split /_/, $option);
	  # Fix stupid HTML names
	  $varname =~ s/(Html|Cgi)/uc($1)/ge;
     }
     # update the configuration value
     if (not $USING_GLOBALS and not exists $config->{$option}) {
	  $config->{$option} = $value;
     }
     elsif ($USING_GLOBALS) {{
	  no strict 'refs';
	  # Need to check if a value has already been set in a global
	  if (defined *{"Debbugs::Config::${varname}"}) {
	       $config->{$option} = *{"Debbugs::Config::${varname}"};
	  }
	  else {
	       $config->{$option} = $value;
	  }
     }}
     if ($USING_GLOBALS) {{
	  no strict 'refs';
	  *{"Debbugs::Config::${varname}"} = $config->{$option};
     }}
}


### import magick

# All we care about here is whether we've been called with the globals or text option;
# if so, then we need to export some symbols back up.
# In any event, we call exporter.

sub import {
     if (grep /^:(?:text|globals)$/, @_) {
	  $USING_GLOBALS=1;
	  for my $variable (map {@$_} @EXPORT_TAGS{map{(/^:(text|globals)$/?($1):())} @_}) {
	       my $tmp = $variable;
	       no strict 'refs';
	       # Yes, I don't care if these are only used once
	       no warnings 'once';
	       # No, it doesn't bother me that I'm assigning an undefined value to a typeglob
	       no warnings 'misc';
	       my ($hash_name,$glob_name,$glob_type) = __convert_name($variable);
	       $tmp =~ s/^[\%\$\@]//;
	       *{"Debbugs::Config::${tmp}"} = ref($config{$hash_name})?$config{$hash_name}:\$config{$hash_name};
	  }
     }
     Debbugs::Config->export_to_level(1,@_);
}


1;
