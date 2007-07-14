# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version at your option.
# See the file README and COPYING for more information.
# Copyright 2007 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::SOAP;

=head1 NAME

Debbugs::SOAP --

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 BUGS

None known.

=cut

use warnings;
use strict;
use vars qw($DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter SOAP::Server::Parameters);

BEGIN{
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags();
     $EXPORT_TAGS{all} = [@EXPORT_OK];

}


use IO::File;
use Debbugs::Status qw(get_bug_status);
use Debbugs::Common qw(make_list getbuglocation getbugcomponent);
use Storable qw(nstore retrieve);


our $CURRENT_VERSION = 1;
our %DEBBUGS_SOAP_COOKIES;


=head2 get_usertag

     my %ut = get_usertag('don@donarmstrong.com','this-bug-sucks','eat-this-bug');

Returns a hashref of bugs which have the specified usertags for the
user set.

=cut

use Debbugs::User qw(read_usertags);

sub get_usertag {
     my $VERSION = __populate_version(pop);
     my ($self,$email, @tags) = @_;
     my %ut = ();
     read_usertags(\%ut, $email);
     my %tags;
     @tags{@tags} = (1) x @tags;
     if (keys %tags > 0) {
	  for my $tag (keys %ut) {
	       delete $ut{$tag} unless exists $tags{$tag};
	  }
     }
     return \%ut;
}


use Debbugs::Status;

=head2 get_status 

     my @statuses = get_status(@bugs);

Returns an arrayref of hashrefs which output the status for specific
sets of bugs.

See L<Debbugs::Status::get_bug_status> for details.

=cut

sub get_status {
     my $VERSION = __populate_version(pop);
     my ($self,@bugs) = @_;
     @bugs = make_list(@bugs);

     my %status;
     for my $bug (@bugs) {
	  my $bug_status = get_bug_status(bug => $bug);
	  if (defined $bug_status and keys %{$bug_status} > 0) {
	       $status{$bug}  = $bug_status;
	  }
     }
#     __prepare_response($self);
     return \%status;
}

=head2 get_bugs

     my @bugs = get_bugs(...);
     my @bugs = get_bugs([...]);

Returns a list of bugs. In the second case, allows the variable
parameters to be specified as an array reference in case your favorite
language's SOAP implementation is craptacular.

See L<Debbugs::Bugs::get_bugs> for details on what C<...> actually
means.

=cut

use Debbugs::Bugs qw();

sub get_bugs{
     my $VERSION = __populate_version(pop);
     my ($self,@params) = @_;
     # Because some soap implementations suck and can't handle
     # variable numbers of arguments we allow get_bugs([]);
     if (@params == 1 and ref($params[0]) eq 'ARRAY') {
	  @params = @{$params[0]};
     }
     my %params;
     # Because some clients can't handle passing arrayrefs, we allow
     # options to be specified multiple times
     while (my ($key,$value) = splice @params,0,2) {
	  push @{$params{$key}}, make_list($value);
     }
     # However, for singly specified options, we want to pull them
     # back out
     for my $key (keys %params) {
	  if (@{$params{$key}} == 1) {
	       ($params{$key}) = @{$params{$key}}
	  }
     }
     my @bugs;
     @bugs = Debbugs::Bugs::get_bugs(%params);
     return \@bugs;
}

=head2 newest_bugs

     my @bugs = newest_bugs(5);

Returns a list of the newest bugs. [Note that all bugs are *not*
guaranteed to exist, but they should in the most common cases.]

=cut

sub newest_bugs{
     my $VERSION = __populate_version(pop);
     my ($self,$num) = @_;
     my $newest_bug = Debbugs::bugs::newest_bug();
     return [($newest_bug - $num + 1) .. $newest_bug];

}

=head2 get_bug_log

     my $bug_log = get_bug_log($bug);
     my $bug_log = get_bug_log($bug,$msg_num);

Retuns a parsed set of the bug log; this is an array of hashes with
the following

 [{html => '',
   header => '',
   body    => '',
   attachments => [],
   msg_num     => 5,
  },
  {html => '',
   header => '',
   body    => '',
   attachments => [],
  },
 ]


Currently $msg_num is completely ignored.

=cut

use Debbugs::Log qw();
use Debbugs::MIME qw(parse);

sub get_bug_log{
     my $VERSION = __populate_version(pop);
     my ($self,$bug,$msg_num) = @_;

     my $location = getbuglocation($bug,'log');
     my $bug_log = getbugcomponent($bug,'log',$location);

     my $log_fh = IO::File->new($bug_log, 'r') or
	  die "Unable to open bug log $bug_log for reading: $!";

     my $log = Debbugs::Log->new($log_fh) or
	  die "Debbugs::Log was unable to be initialized";

     my %seen_msg_ids;
     my $current_msg=0;
     my $status = {};
     my @messages;
     while (my $record = $log->read_record()) {
	  $current_msg++;
	  #next if defined $msg_num and ($current_msg ne $msg_num);
	  next unless $record->{type} eq 'incoming-recv';
	  my ($msg_id) = $record->{text} =~ /^Message-Id:\s+<(.+)>/im;
	  next if defined $msg_id and exists $seen_msg_ids{$msg_id};
	  $seen_msg_ids{$msg_id} = 1 if defined $msg_id;
	  next if defined $msg_id and $msg_id =~ /handler\..+\.ack(?:info)?\@/;
	  my $message = parse($record->{text});
	  my ($header,$body) = map {join("\n",make_list($_))}
	       @{$message}{qw(header body)};
	  push @messages,{header => $header,
			  body   => $body,
			  attachments => [],
			  msg_num => $current_msg,
			 };
     }
     return \@messages;
}


=head1 VERSION COMPATIBILITY

The functionality provided by the SOAP interface will change over time.

To the greatest extent possible, we will attempt to provide backwards
compatibility with previous versions; however, in order to have
backwards compatibility, you need to specify the version with which
you are compatible.

=cut

sub __populate_version{
     my ($request) = @_;
     return $request->{___debbugs_soap_version};
}

1;


__END__






