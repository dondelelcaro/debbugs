#!/usr/bin/perl

use warnings;
use strict;

# Sanitize environent for taint
BEGIN{
    delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
}


use POSIX qw(strftime);
use MIME::Parser;
use MIME::Decoder;
use IO::Scalar;
use IO::File;

# if we're running out of git, we want to use the git base directory as the
# first INC directory. If you're not running out of git, don't do that.
use File::Basename qw(dirname);
use Cwd qw(abs_path);
our $debbugs_dir;
BEGIN {
    $debbugs_dir =
	abs_path(dirname(abs_path(__FILE__)) . '/../');
    # clear the taint; we'll assume that the absolute path to __FILE__ is the
    # right path if there's a .git directory there
    ($debbugs_dir) = $debbugs_dir =~ /([[:print:]]+)/;
    if (defined $debbugs_dir and
	-d $debbugs_dir . '/.git/') {
    } else {
	undef $debbugs_dir;
    }
    # if the first directory in @INC is not an absolute directory, assume that
    # someone has overridden us via -I.
    if ($INC[0] !~ /^\//) {
	undef $debbugs_dir;
    }
    if (defined $debbugs_dir) {
	unshift @INC, $debbugs_dir.'/lib/';
    }
}

use Debbugs::Config qw(:globals :text :config);

# for read_log_records
use Debbugs::Log qw(:read);
use Debbugs::Log::Spam;
use Debbugs::CGI qw(:url :html :util :cache :usertags);
use Debbugs::CGI::Bugreport qw(:all);
use Debbugs::Common qw(buglog getmaintainers make_list bug_status package_maintainer);
use Debbugs::Packages qw(binary_to_source);
use Debbugs::DB;
use Debbugs::Status qw(splitpackages split_status_fields get_bug_status isstrongseverity);
use Debbugs::Bug;

use Scalar::Util qw(looks_like_number);

use Debbugs::Text qw(:templates);
use URI::Escape qw(uri_escape_utf8);
use List::AllUtils qw(max);

my $s;
my @schema_arg = ();
if (defined $config{database}) {
    $s = Debbugs::DB->connect($config{database}) or
        die "Unable to connect to DB";
    @schema_arg = ('schema',$s);
}

use CGI::Simple;
my $q = CGI::Simple->new();
# STDOUT should be using the utf8 io layer
binmode(STDOUT,':raw:encoding(UTF-8)');

my %param = cgi_parameters(query => $q,
			   single => [qw(bug msg att boring terse),
				      qw(reverse mbox mime trim),
				      qw(mboxstat mboxmaint archive),
				      qw(repeatmerged avatars),
				     ],
			   default => {# msg       => '',
				       boring    => 'no',
				       terse     => 'no',
				       reverse   => 'no',
				       mbox      => 'no',
				       mime      => 'no',
				       mboxstat  => 'no',
				       mboxmaint => 'no',
				       archive   => 'no',
				       repeatmerged => 'yes',
                                       avatars   => 'yes',
				      },
			  );
# This is craptacular.

my $ref = $param{bug} or quitcgi("No bug number", '400 Bad Request');
$ref =~ /(\d+)/ or quitcgi("Invalid bug number", '400 Bad Request');
$ref = $1;
my $short = "#$ref";
my ($msg) = $param{msg} =~ /^(\d+)$/ if exists $param{msg};
my ($att) = $param{att} =~ /^(\d+)$/ if exists $param{att};
my $boring = $param{'boring'} eq 'yes';
my $terse = $param{'terse'} eq 'yes';
my $reverse = $param{'reverse'} eq 'yes';
my $mbox = $param{'mbox'} eq 'yes';
my $mime = $param{'mime'} eq 'yes';
my $avatars = $param{avatars} eq 'yes';

my $trim_headers = ($param{trim} || ((defined $msg and $msg)?'no':'yes')) eq 'yes';

my $mbox_status_message = $param{mboxstat} eq 'yes';
my $mbox_maint = $param{mboxmaint} eq 'yes';
$mbox = 1 if $mbox_status_message or $mbox_maint;

# Not used by this script directly, but fetch these so that pkgurl() and
# friends can propagate them correctly.
my $archive = $param{'archive'} eq 'yes';
my $repeatmerged = $param{'repeatmerged'} eq 'yes';

my %bugusertags;
my %ut;
my %seen_users;

my $buglog = buglog($ref);
my $bug_status = bug_status($ref);
if (not defined $buglog or not defined $bug_status) {
    no_such_bug($q,$ref);
}

sub no_such_bug {
    my ($q,$ref) = @_;
    print $q->header(-status => 404,
		     -content_type => "text/html",
		     -charset => 'utf-8',
		     -cache_control => 'public, max-age=600',
		    );
    print fill_in_template(template=>'cgi/no_such_bug',
			   variables => {modify_time => strftime('%a, %e %b %Y %T UTC', gmtime),
					 bug_num     => $ref,
					},
			  );
    exit 0;
}

## calculate etag for this bugreport.cgi call
my $etag;
## identify the files that we need to look at; if someone just wants the mbox,
## they don't need to see anything but the buglog; otherwise, track what is
## necessary for the usertags and things to calculate status.

my @dependent_files = ($buglog);
my $need_status = 0;
if (not (($mbox and not $mbox_status_message) or
	 (defined $att and defined $msg))) {
    $need_status = 1;
    push @dependent_files,
	$bug_status,
	defined $config{version_index} ? $config{version_index}:(),
	defined $config{binary_source_map} ? $config{binary_source_map}:();
}

## Identify the users required
for my $user (map {split /[\s*,\s*]+/} make_list($param{users}||[])) {
    next unless length($user);
    push @dependent_files,Debbugs::User::usertag_file_from_email($user);
}
if (defined $param{usertag}) {
    for my $usertag (make_list($param{usertag})) {
	my ($user, $tag) = split /:/, $usertag, 2;
	push @dependent_files,Debbugs::User::usertag_file_from_email($user);
    }
}
$etag =
    etag_does_not_match(cgi => $q,
			additional_data => [grep {defined $_ ? $_ :()}
					    values %param
					   ],
			files => [@dependent_files,
				 ],
		       );
if (not $etag) {
    print $q->header(-status => 304,
		     -cache_control => 'public, max-age=600',
		     -etag => $etag,
		     -charset => 'utf-8',
		     -content_type => 'text/html',
		    );
    print "304: Not modified\n";
    exit 0;
}

## if they're just asking for the head, stop here.
if ($q->request_method() eq 'HEAD' and not defined($att) and not $mbox) {
    print $q->header(-status => 200,
		     -cache_control => 'public, max-age=600',
		     -etag => $etag,
		     -charset => 'utf-8',
		     -content_type => 'text/html',
		    );
     exit 0;
}

for my $user (map {split /[\s*,\s*]+/} make_list($param{users}||[])) {
    next unless length($user);
    add_user($user,\%ut,\%bugusertags,\%seen_users);
}

if (defined $param{usertag}) {
     for my $usertag (make_list($param{usertag})) {
	  my %select_ut = ();
	  my ($u, $t) = split /:/, $usertag, 2;
	  Debbugs::User::read_usertags(\%select_ut, $u);
	  unless (defined $t && $t ne "") {
	       $t = join(",", keys(%select_ut));
	  }
	  add_user($u,\%ut,\%bugusertags,\%seen_users);
	  push @{$param{tag}}, split /,/, $t;
     }
}

my $bug = Debbugs::Bug->new(bug => $ref,
                            @schema_arg,
                           );

my %status;
if ($need_status) {
    %status = %{split_status_fields(get_bug_status(bug=>$ref,
						   bugusertags => \%bugusertags,
                                                   @schema_arg,
						  ))}
}

my @records;
eval{
    @records = $bug->log_records();
};
if ($@) {
     quitcgi("Bad bug log for $gBug $ref. Unable to read records: $@");
}

my $log='';
my $msg_num = 0;
my $skip_next = 0;
if (defined($msg) and ($msg-1) <= $#records) {
     @records = ($records[$msg-1]);
     $msg_num = $msg - 1;
}
my @log;
if ( $mbox ) {
     binmode(STDOUT,":raw");
     my $date = strftime "%a %b %d %T %Y", localtime;
     my $multiple_messages = @records > 1;
     if ($multiple_messages) {
	 print $q->header(-type => "application/mbox",
			  -cache_control => 'public, max-age=600',
			  -etag => $etag,
			  content_disposition => qq(attachment; filename="bug_${ref}.mbox"),
			 );
     }
     else {
	  $msg_num++;
	  print $q->header(-type => "message/rfc822",
			   -cache_control => 'public, max-age=86400',
			   -etag => $etag,
			   content_disposition => qq(attachment; filename="bug_${ref}_message_${msg_num}.eml"),
			  );
     }
     if ($mbox_status_message and $multiple_messages) {
	  my $status_message='';
	  my @status_fields = (retitle   => 'subject',
			       package   => 'package',
			       submitter => 'originator',
			       severity  => 'severity',
			       tag       => 'tags',
			       owner     => 'owner',
			       blocks    => 'blocks',
			       forward   => 'forward',
			      );
	  my ($key,$value);
	  while (($key,$value) = splice(@status_fields,0,2)) {
	       if (defined $status{$value} and length $status{$value}) {
		    $status_message .= qq($key $ref $status{$value}\n);
	       }
	  }
	  print STDOUT qq(From unknown $date\n),
	       create_mime_message([From       => "$gBug#$ref <$ref\@$gEmailDomain>",
				    To         => "$gBug#$ref <$ref\@$gEmailDomain>",
				    Subject    => "Status: $status{subject}",
				    "Reply-To" => "$gBug#$ref <$ref\@$gEmailDomain>",
				   ],
				   <<END,);
$status_message
thanks


END
     }
     my $message_number=0;
     my %seen_message_ids;
     for my $record (@records) {
	  next if $record->{type} !~ /^(?:recips|incoming-recv)$/;
	  my $wanted_type = $mbox_maint?'recips':'incoming-recv';
	  # we want to include control messages anyway
	  my $record_wanted_anyway = 0;
	  my ($msg_id) = record_regex($record,qr/^Message-Id:\s+<(.+)>/im);
	  next if defined $msg_id and exists $seen_message_ids{$msg_id};
	  next if not defined $msg and defined $msg_id and $msg_id =~/handler\..+\.ack(?:info|done)?\@/;
	  $record_wanted_anyway = 1 if record_regex($record,qr/^Received: \(at control\)/);
	  next if not $boring and not $record->{type} eq $wanted_type and not $record_wanted_anyway and @records > 1;
	  $seen_message_ids{$msg_id} = 1 if defined $msg_id;
          # skip spam messages if we're outputting more than one message
          next if $multiple_messages and $bug->is_spam($msg_id);
      my @lines;
      if ($record->{inner_file}) {
          push @lines, scalar $record->{fh}->getline;
          push @lines, scalar $record->{fh}->getline;
          chomp $lines[0];
          chomp $lines[1];
      } else {
          @lines = split( "\n", $record->{text}, -1 );
      }
	  if ( $lines[ 1 ] =~ m/^From / ) {
          @lines = reverse @lines;
	  }
	  if ( !( $lines[ 0 ] =~ m/^From / ) ) {
	       unshift @lines, "From unknown $date";
       }
      print $lines[0]."\n";
	  print map { s/^(>*From )/>$1/ if $multiple_messages;
                      $_."\n" } @lines[ 1 .. $#lines ];
      if ($record->{inner_file}) {
          my $fh = $record->{fh};
          local $/;
          while (<$fh>) {
              s/^(>*From )/>$1/gm if $multiple_messages;
              print $_;
          }
      }
     }
     exit 0;
}

else {
     if (defined $att and defined $msg and @records) {
	 binmode(STDOUT,":raw");
	 $msg_num++;
	 ## allow this to be cached for a week
	 print "Status: 200 OK\n";
	 print "Cache-Control: public, max-age=604800\n";
	 print "Etag: $etag\n";
	  print handle_email_message($records[0],
				     ref => $ref,
				     msg_num => $msg_num,
				     att => $att,
				     msg => $msg,
				     trim_headers => $trim_headers,
				    );
	  exit 0;
     }
     my %seen_msg_ids;
     for my $record (@records) {
	  $msg_num++;
	  if ($skip_next) {
	       $skip_next = 0;
	       next;
	  }
	  $skip_next = 1 if $record->{type} eq 'html' and not $boring;
	  push @log, handle_record($record,$ref,$msg_num,
                                   \%seen_msg_ids,
                                   trim_headers => $trim_headers,
                                   avatars => $avatars,
				   terse => $terse,
                                   # if we're only looking at one record, allow
                                   # spam to be output
                                   spam  => (@records > 1)?$bug:undef,
                                  );
     }
}

@log = reverse @log if $reverse;
$log = join("\n",@log);


# All of the below should be turned into a template

my $indexentry;
my $showseverity;

unless (%status) {
    no_such_bug($q,$ref);
}

my @packages = make_list($status{package});


print $q->header(-type => "text/html",
		 -charset => 'utf-8',
		 -cache_control => 'public, max-age=300',
		 -etag => $etag,
		);

print fill_in_template(template => 'cgi/bugreport',
		       variables => {bug => $bug,
				     log           => $log,
				     msg           => $msg,
				     isstrongseverity => \&Debbugs::Status::isstrongseverity,
				     html_escape   => \&Debbugs::CGI::html_escape,
                                     uri_escape    => \&URI::Escape::uri_escape_utf8,
				     looks_like_number => \&Scalar::Util::looks_like_number,
				     make_list        => \&Debbugs::Common::make_list,
				    },
		       hole_var  => {'&package_links' => \&Debbugs::CGI::package_links,
				     '&bug_links'     => \&Debbugs::CGI::bug_links,
				     '&version_url'   => \&Debbugs::CGI::version_url,
				     '&strftime'      => \&POSIX::strftime,
				     '&maybelink'     => \&Debbugs::CGI::maybelink,
				    },
		      );

__END__

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
