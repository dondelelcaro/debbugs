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
use Debbugs::SOAP::Server;
use Exporter qw(import);
use base qw(SOAP::Server::Parameters);

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
use Debbugs::UTF8;
use Debbugs::Packages;

use Storable qw(nstore retrieve dclone);
use Scalar::Util qw(looks_like_number);


our $CURRENT_VERSION = 2;

=head2 get_usertag

     my %ut = get_usertag('don@donarmstrong.com','this-bug-sucks','eat-this-bug');
     my %ut = get_usertag('don@donarmstrong.com');

Returns a hashref of bugs which have the specified usertags for the
user set.

In the second case, returns all of the usertags for the user passed.

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
     return encode_utf8_structure(\%ut);
}


use Debbugs::Status;

=head2 get_status 

     my @statuses = get_status(@bugs);
     my @statuses = get_status([bug => 304234,
                                dist => 'unstable',
                               ],
                               [bug => 304233,
                                dist => 'unstable',
                               ],
                              )

Returns an arrayref of hashrefs which output the status for specific
sets of bugs.

In the first case, no options are passed to
L<Debbugs::Status::get_bug_status> besides the bug number; in the
second the bug, dist, arch, bugusertags, sourceversions, and version
parameters are passed if they are present.

As a special case for suboptimal SOAP implementations, if only one
argument is passed to get_status and it is an arrayref which either is
empty, has a number as the first element, or contains an arrayref as
the first element, the outer arrayref is dereferenced, and processed
as in the examples above.

See L<Debbugs::Status::get_bug_status> for details.

=cut

sub get_status {
     my $VERSION = __populate_version(pop);
     my ($self,@bugs) = @_;

     if (@bugs == 1 and
	 ref($bugs[0]) and
	 (@{$bugs[0]} == 0 or
	  ref($bugs[0][0]) or
	  looks_like_number($bugs[0][0])
	 )
	) {
	      @bugs = @{$bugs[0]};
     }
     my %status;
     for my $bug (@bugs) {
	  my $bug_status;
	  if (ref($bug)) {
	       my %param = __collapse_params(@{$bug});
	       next unless defined $param{bug};
	       $bug = $param{bug};
	       $bug_status = get_bug_status(map {(exists $param{$_})?($_,$param{$_}):()}
					    qw(bug dist arch bugusertags sourceversions version indicatesource)
					   );
	  }
	  else {
	       $bug_status = get_bug_status(bug => $bug);
	  }
	  if (defined $bug_status and keys %{$bug_status} > 0) {
	       $status{$bug}  = $bug_status;
	  }
     }
#     __prepare_response($self);
     return encode_utf8_structure(\%status);
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
     my %params = __collapse_params(@params);
     my @bugs;
     @bugs = Debbugs::Bugs::get_bugs(%params);
     return encode_utf8_structure(\@bugs);
}

=head2 newest_bugs

     my @bugs = newest_bugs(5);

Returns a list of the newest bugs. [Note that all bugs are *not*
guaranteed to exist, but they should in the most common cases.]

=cut

sub newest_bugs{
     my $VERSION = __populate_version(pop);
     my ($self,$num) = @_;
     my $newest_bug = Debbugs::Bugs::newest_bug();
     return encode_utf8_structure([($newest_bug - $num + 1) .. $newest_bug]);

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

     my $log = Debbugs::Log->new(bug_num => $bug) or
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
     return encode_utf8_structure(\@messages);
}

=head2 binary_to_source

     binary_to_source($binary_name,$binary_version,$binary_architecture)

Returns a reference to the source package name and version pair
corresponding to a given binary package name, version, and
architecture. If undef is passed as the architecture, returns a list
of references to all possible pairs of source package names and
versions for all architectures, with any duplicates removed.

As of comaptibility version 2, this has changed to use the more
powerful binary_to_source routine, which allows returning source only,
concatenated scalars, and other useful features.

See the documentation of L<Debbugs::Packages::binary_to_source> for
details.

=cut

sub binary_to_source{
     my $VERSION = __populate_version(pop);
     my ($self,@params) = @_;

     if ($VERSION <= 1) {
	 return encode_utf8_structure([Debbugs::Packages::binary_to_source(binary => $params[0],
						     (@params > 1)?(version => $params[1]):(),
						     (@params > 2)?(arch    => $params[2]):(),
						    )]);
     }
     else {
	 return encode_utf8_structure([Debbugs::Packages::binary_to_source(@params)]);
     }
}

=head2 source_to_binary

     source_to_binary($source_name,$source_version);

Returns a reference to an array of references to binary package name,
version, and architecture corresponding to a given source package name
and version. In the case that the given name and version cannot be
found, the unversioned package to source map is consulted, and the
architecture is not returned.

(This function corresponds to L<Debbugs::Packages::sourcetobinary>)

=cut

sub source_to_binary {
     my $VERSION = __populate_version(pop);
     my ($self,@params) = @_;

     return encode_utf8_structure([Debbugs::Packages::sourcetobinary(@params)]);
}

=head2 get_versions

     get_version(package=>'foopkg',
                 dist => 'unstable',
                 arch => 'i386',
                );

Returns a list of the versions of package in the distributions and
architectures listed. This routine only returns unique values.

=over

=item package -- package to return list of versions

=item dist -- distribution (unstable, stable, testing); can be an
arrayref

=item arch -- architecture (i386, source, ...); can be an arrayref

=item time -- returns a version=>time hash at which the newest package
matching this version was uploaded

=item source -- returns source/version instead of just versions

=item no_source_arch -- discards the source architecture when arch is
not passed. [Used for finding the versions of binary packages only.]
Defaults to 0, which does not discard the source architecture. (This
may change in the future, so if you care, please code accordingly.)

=item return_archs -- returns a version=>[archs] hash indicating which
architectures are at which versions.

=back

This function corresponds to L<Debbugs::Packages::get_versions>

=cut

sub get_versions{
     my $VERSION = __populate_version(pop);
     my ($self,@params) = @_;

     return encode_utf8_structure(scalar Debbugs::Packages::get_versions(@params));
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

sub __collapse_params{
     my @params = @_;

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
     return %params;
}


1;


__END__






