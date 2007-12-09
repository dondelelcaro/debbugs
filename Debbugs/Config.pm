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
				 qw($gPackageVersionRe),
				 qw($gSummaryList $gMirrorList $gMailer $gBug),
				 qw($gBugs $gRemoveAge $gSaveOldBugs $gDefaultSeverity),
				 qw($gShowSeverities $gBounceFroms $gConfigDir $gSpoolDir),
				 qw($gIncomingDir $gWebDir $gDocDir $gMaintainerFile),
				 qw($gMaintainerFileOverride $gPseudoMaintFile $gPseudoDescFile $gPackageSource),
				 qw($gVersionPackagesDir $gVersionIndex $gBinarySourceMap $gSourceBinaryMap),
				 qw($gVersionTimeIndex),
				 qw($gSendmail $gLibPath $gSpamScan @gExcludeFromControl),
				 qw(%gSeverityDisplay @gTags @gSeverityList @gStrongSeverities),
				 qw(%gSearchEstraier),
				 qw(%gDistributionAliases),
				 qw(@gPostProcessall @gRemovalDefaultDistributionTags @gRemovalDistributionTags @gRemovalArchitectures),
				 qw(@gRemovalStrongSeverityDefaultDistributionTags),
				 qw(@gDefaultArchitectures),
				 qw($gTemplateDir),
				],
		     text     => [qw($gBadEmailPrefix $gHTMLTail $gHTMLExpireNote),
				 ],
		     config   => [qw(%config)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(qw(globals text config));
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

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
     if (${[stat($ENV{DEBBUGS_CONFIG_FILE})]}[4] = $<) {
	  $ENV{DEBBUGS_CONFIG_FILE} =~ /(.+)/;
	  $ENV{DEBBUGS_CONFIG_FILE} = $1;
     }
     else {
	  die "Environmental variable DEBBUGS_CONFIG_FILE set, and $ENV{DEBBUGS_CONFIG_FILE} is not owned by the user running this script.";
     }
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

set_default(\%config,'web_domain',$config{web_host}.'/'.$config{web_host_bug_dir});

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

=back

=cut

set_default(\%config,'unknown_maintainer_email',$config{maintainer_email});

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

=back

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

=head2 Misc Options

=over

=cut

set_default(\%config,'mailer','exim');
set_default(\%config,'bug','bug');
set_default(\%config,'bugs','bugs');

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

=item removal_distribution_tags

Tags which specifiy distributions to check

Default: @{$config{distributions}}

=cut

set_default(\%config,'removal_distribution_tags',
	    [@{$config{distributions}}]);

=item removal_default_distribution_tags

For removal/archival purposes, all bugs are assumed to have these tags
set.

Default: qw(unstable testing);

=cut

set_default(\%config,'removal_default_distribution_tags',
	    [qw(unstable testing)]
	   );

=item removal_strong_severity_default_distribution_tags

For removal/archival purposes, all bugs with strong severity are
assumed to have these tags set.

Default: qw(unstable testing stable);

=cut

set_default(\%config,'removal_strong_severity_default_distribution_tags',
	    [qw(unstable testing stable)]
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




set_default(\%config,'default_severity','normal');
set_default(\%config,'show_severities','critical, grave, normal, minor, wishlist');
set_default(\%config,'strong_severities',[qw(critical grave)]);
set_default(\%config,'severity_list',[qw(critical grave normal wishlist)]);
set_default(\%config,'severity_display',{critical => "Critical $config{bugs}",
					 grave    => "Grave $config{bugs}",
					 normal   => "Normal $config{bugs}",
					 wishlist => "Wishlist $config{bugs}",
					});

set_default(\%config,'tags',[qw(patch wontfix moreinfo unreproducible fixed),
			     @{$config{distributions}}
			    ]);

set_default(\%config,'bounce_froms','^mailer|^da?emon|^post.*mast|^root|^wpuser|^mmdf|^smt.*|'.
	    '^mrgate|^vmmail|^mail.*system|^uucp|-maiser-|^mal\@|'.
	    '^mail.*agent|^tcpmail|^bitmail|^mailman');

set_default(\%config,'config_dir',dirname(exists $ENV{DEBBUGS_CONFIG_FILE}?$ENV{DEBBUGS_CONFIG_FILE}:'/etc/debbugs/config'));
set_default(\%config,'spool_dir','/var/lib/debbugs/spool');
set_default(\%config,'incoming_dir','incoming');
set_default(\%config,'web_dir','/var/lib/debbugs/www');
set_default(\%config,'doc_dir','/var/lib/debbugs/www/txt');
set_default(\%config,'lib_path','/usr/lib/debbugs');


=item template_dir

directory of templates; defaults to /usr/share/debbugs/templates.

=cut

set_default(\%config,'template_dir','/usr/share/debbugs/templates');


set_default(\%config,'maintainer_file',$config{config_dir}.'/Maintainers');
set_default(\%config,'maintainer_file_override',$config{config_dir}.'/Maintainers.override');
set_default(\%config,'pseudo_maint_file',$config{config_dir}.'/pseudo-packages.maint');
set_default(\%config,'pseudo_desc_file',$config{config_dir}.'/pseudo-packages.description');
set_default(\%config,'package_source',$config{config_dir}.'/indices/sources');


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

=item spam_scan

Whether or not spamscan is being used; defaults to 0 (not being used

=cut

set_default(\%config,'spam_scan',0);


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
	  for my $variable (@{$EXPORT_TAGS{globals}}) {
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
     $hash_name =~ s/(HTML|CGI)/ucfirst(lc($1))/ge;
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
