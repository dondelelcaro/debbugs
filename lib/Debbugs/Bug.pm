# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Bug;

=head1 NAME

Debbugs::Bug -- OO interface to bugs

=head1 SYNOPSIS

   use Debbugs::Bug;
   Debbugs::Bug->new(schema => $s,binaries => [qw(foo)],sources => [qw(bar)]);

=head1 DESCRIPTION



=cut

use Mouse;
use strictures 2;
use namespace::clean;
use v5.10; # for state

use DateTime;
use List::AllUtils qw(max first min any);

use Params::Validate qw(validate_with :types);
use Debbugs::Config qw(:config);
use Debbugs::Status qw(read_bug);
use Debbugs::Bug::Tag;
use Debbugs::Bug::Status;
use Debbugs::Collection::Package;
use Debbugs::Collection::Bug;
use Debbugs::Collection::Correspondent;

use Debbugs::OOTypes;

use Carp;

extends 'Debbugs::OOBase';

my $meta = __PACKAGE__->meta;

state $strong_severities =
   {map {($_,1)} @{$config{strong_severities}}};

has bug => (is => 'ro', isa => 'Int',
	    required => 1,
	   );

sub id {
    return $_[0]->bug;
}

has saved => (is => 'ro', isa => 'Bool',
	      default => 0,
	      writer => '_set_saved',
	     );

has status => (is => 'ro', isa => 'Debbugs::Bug::Status',
	       lazy => 1,
	       builder => '_build_status',
               handles => {date => 'date',
                           subject => 'subject',
                           message_id => 'message_id',
                           severity => 'severity',
                           archived => 'archived',
                           summary => 'summary',
                           outlook => 'outlook',
                           forwarded => 'forwarded',
                          },
	      );

sub _build_status {
    my $self = shift;
    return Debbugs::Bug::Status->new(bug=>$self->bug,
                                     $self->schema_argument,
                                    );
}

has log => (is => 'bare', isa => 'Debbugs::Log',
            lazy => 1,
            builder => '_build_log',
            handles => {_read_record => 'read_record',
                        log_records => 'read_all_records',
                       },
           );

sub _build_log {
    my $self = shift;
    return Debbugs::Log->new(bug_num => $self->id,
                             inner_file => 1,
                            );
}

has spam => (is => 'bare', isa => 'Debbugs::Log::Spam',
             lazy => 1,
             builder => '_build_spam',
             handles => ['is_spam'],
            );
sub _build_spam {
    my $self = shift;
    return Debbugs::Log::Spam->new(bug_num => $self->id);
}

has 'package_collection' => (is => 'ro',
			     isa => 'Debbugs::Collection::Package',
			     builder => '_build_package_collection',
			     lazy => 1,
			    );

sub _build_package_collection {
    my $self = shift;
    if ($self->has_schema) {
        return Debbugs::Collection::Package->new(schema => $self->schema);
    }
    if (defined $config{database}) {
        carp "No schema when building package collection";
    }
    return Debbugs::Collection::Package->new();
}

has bug_collection => (is => 'ro',
		       isa => 'Debbugs::Collection::Bug',
		       builder => '_build_bug_collection',
		      );
sub _build_bug_collection {
    my $self = shift;
    if ($self->has_schema) {
        return Debbugs::Collection::Bug->new(schema => $self->schema);
    }
    return Debbugs::Collection::Bug->new();
}

has correspondent_collection =>
    (is => 'ro',
     isa => 'Debbugs::Collection::Correspondent',
     builder => '_build_correspondent_collection',
     lazy => 1,
    );
sub _build_correspondent_collection   {
    my $self = shift;
    return Debbugs::Collection::Correspondent->new($self->schema_argument);
}

# package attributes
for my $attr (qw(packages affects sources)) {
    has $attr =>
	(is => 'rw',
	 isa => 'Debbugs::Collection::Package',
	 clearer => '_clear_'.$attr,
	 builder => '_build_'.$attr,
	 lazy => 1,
	);
}

# bugs
for my $attr (qw(blocks blocked_by mergedwith)) {
    has $attr =>
	(is => 'ro',
	 isa => 'Debbugs::Collection::Bug',
	 clearer => '_clear_'.$attr,
	 builder => '_build_'.$attr,
	 handles => {},
	 lazy => 1,
	);
}


for my $attr (qw(owner submitter done)) {
    has $attr,
        (is => 'ro',
         isa => 'Maybe[Debbugs::Correspondent]',
         lazy => 1,
         builder => '_build_'.$attr.'_corr',
         clearer => '_clear_'.$attr.'_corr',
         handles => {$attr.'_url' => $attr.'_url',
                     $attr.'_email' => 'email',
                     $attr.'_phrase' => 'phrase',
                    },
        );
    $meta->add_method('has_'.$attr,
		      sub {my $self = shift;
                           my $m = $meta->find_method_by_name($attr);
                           return defined $m->($self);
		       });
    $meta->add_method('_build_'.$attr.'_corr',
                      sub {my $self = shift;
                           my $m = $self->status->meta->find_method_by_name($attr);
                           my $v = $m->($self->status);
                           if (defined $v and length($v)) {
                               return $self->correspondent_collection->
                                   get_or_add_by_key($v);
                           } else {
                               return undef;
                           }
                       }
                     );
}

sub is_done {
    my $self = shift;
    return $self->has_done;
}

sub strong_severity {
    my $self = shift;
    return exists $strong_severities->{$self->severity};
}

sub short_severity {
    $_[0]->severity =~ m/^(.)/;
    return $1;
}

sub _build_packages {
    my $self = shift;
    return $self->package_collection->
	    limit($self->status->package);
}

sub is_affecting {
    my $self = shift;
    return $self->affects->count > 0;
}

sub _build_affects {
    my $self = shift;
    return $self->package_collection->
	    limit($self->status->affects);
}
sub _build_sources {
    my $self = shift;
    return $self->packages->sources->clone;
}

sub is_owned {
    my $self = shift;
    return defined $self->owner;
}

sub is_blocking {
    my $self = shift;
    return $self->blocks->count > 0;
}

sub _build_blocks {
    my $self = shift;
    return $self->bug_collection->
	limit($self->status->blocks);
}

sub is_blocked {
    my $self = shift;
    return $self->blocked_by->count > 0;
}

sub _build_blocked_by {
    my $self = shift;
    return $self->bug_collection->
	limit($self->status->blocked_by);
}

sub is_forwarded {
    length($_[0]->forwarded) > 0;
}

for my $attr (qw(fixed found)) {
    has $attr =>
	(is => 'ro',
	 isa => 'Debbugs::Collection::Version',
	 clearer => '_clear_'.$attr,
	 builder => '_build_'.$attr,
	 handles => {},
	 lazy => 1,
	);
}

sub has_found {
    my $self = shift;
    return any {1} $self->status->found;
}

sub _build_found {
    my $self = shift;
    return $self->packages->
	get_source_versions($self->status->found);
}

sub has_fixed {
    my $self = shift;
    return any {1} $self->status->fixed;
}

sub _build_fixed {
    my $self = shift;
    return $self->packages->
        get_source_versions($self->status->fixed);
}

sub is_merged {
    my $self = shift;
    return any {1} $self->status->mergedwith;
}

sub _build_mergedwith {
    my $self = shift;
    return $self->bug_collection->
	limit($self->status->mergedwith);
}

for my $attr (qw(created modified)) {
    has $attr => (is => 'rw', isa => 'Object',
		clearer => '_clear_'.$attr,
		builder => '_build_'.$attr,
		lazy => 1);
}
sub _build_created {
    return DateTime->
	from_epoch(epoch => $_[0]->status->date);
}
sub _build_modified {
    return DateTime->
	from_epoch(epoch => max($_[0]->status->log_modified,
				$_[0]->status->last_modified
			       ));
}

has tags => (is => 'ro',
             isa => 'Debbugs::Bug::Tag',
	     clearer => '_clear_tags',
	     builder => '_build_tags',
	     lazy => 1,
	    );
sub _build_tags {
    my $self = shift;
    return Debbugs::Bug::Tag->new(keywords => join(' ',$self->status->tags),
                                  bug => $self,
                                  users => $self->bug_collection->users,
                                 );
}

has pending => (is => 'ro',
                isa => 'Str',
                clearer => '_clear_pending',
                builder => '_build_pending',
                lazy => 1,
               );

sub _build_pending {
    my $self = shift;

    my $pending = 'pending';
    if (length($self->status->forwarded)) {
        $pending = 'forwarded';
    }
    if ($self->tags->tag_is_set('pending')) {
        $pending = 'pending-fixed';
    }
    if ($self->tags->tag_is_set('pending')) {
        $pending = 'fixed';
    }
    # XXX This isn't quite right
    return $pending;
}

=head2 buggy

     $bug->buggy('debbugs/2.6.0-1','debbugs/2.6.0-2');
     $bug->buggy(Debbugs::Version->new('debbugs/2.6.0-1'),
                 Debbugs::Version->new('debbugs/2.6.0-2'),
                );

Returns the output of Debbugs::Versions::buggy for a particular
package, version and found/fixed set. Automatically turns found, fixed
and version into source/version strings.

=cut

sub buggy {
    my $self = shift;
    my $vertree =
	$self->package_collection->
	universe->versiontree;
    my $max_buggy = 'absent';
    for my $ver (@_) {
	if (not ref($ver)) {
            my @ver_opts = (version => $ver,
                            package => $self->status->package,
                            package_collection => $self->package_collection,
                            $self->schema_arg
                           );
            if ($ver =~ m{/}) {
                $ver = Debbugs::Version::Source->(@ver_opts);
            } else {
                $ver = Debbugs::Version::Binary->(@ver_opts);
            }
	}
	$vertree->load($ver->source);
	my $buggy =
	    $vertree->buggy($ver,
                            [$self->found],
                            [$self->fixed]);
	if ($buggy eq 'found') {
	    return 'found'
	}
	if ($buggy eq 'fixed') {
	    $max_buggy = 'fixed';
	}
    }
    return $max_buggy;
}

has archiveable =>
    (is => 'ro', isa => 'Bool',
     writer => '_set_archiveable',
     builder => '_build_archiveable',
     clearer => '_clear_archiveable',
     lazy => 1,
    );
has when_archiveable =>
    (is => 'ro', isa => 'Num',
     writer => '_set_when_archiveable',
     builder => '_build_when_archiveable',
     clearer => '_clear_when_archiveable',
     lazy => 1,
    );

sub _build_archiveable {
    my $self = shift;
    $self->_populate_archiveable(0);
    return $self->archiveable;
}
sub _build_when_archiveable {
    my $self = shift;
    $self->_populate_archiveable(1);
    return $self->when_archiveable;
}

sub _populate_archiveable {
    my $self = shift;
    my ($need_time) = @_;
    $need_time //= 0;
    # Bugs can be archived if they are
    # 1. Closed
    if (not $self->done) {
	$self->_set_archiveable(0);
	$self->_set_when_archiveable(-1);
	return;
    }
    # 2. Have no unremovable tags set
    if (@{$config{removal_unremovable_tags}}) {
	state $unrem_tags =
	   {map {($_=>1)} @{$config{removal_unremovable_tags}}};
	for my $tag ($self->tags) {
	    if ($unrem_tags->{$tag}) {
		$self->_set_archiveable(0);
		$self->_set_when_archiveable(-1);
		return;
	    }
	}
    }
    my $time = time;
    state $remove_time = 24 * 60 * 60 * ($config{remove_age} // 30);
    # 4. Have been modified more than remove_age ago
    my $moded_ago =
	$time - $self->modified->epoch;
    # if we don't need to know when we can archive, we can stop here if it's
    # been modified too recently
    if ($moded_ago < $remove_time) {
	$self->_set_archiveable(0);
	return unless $need_time;
    }
    my @distributions =
	@{$config{removal_default_distribution_tags}};
    if ($self->strong_severity) {
	@distributions =
	    @{$config{removal_strong_severity_default_distribution_tags}};
    }
    # 3. Have a maximum buggy of fixed
    my $buggy = $self->buggy($self->packages->
			     get_source_versions_distributions(@distributions));
    if ('found' eq $buggy) {
	$self->_set_archiveable(0);
	$self->_set_when_archiveable(-1);
	return;
    }
    my $fixed_ago = $moded_ago;
    # $fixed_ago = $time - $self->when_fixed(@distributions);
    # if ($fixed_ago < $remove_time) {
    #     $self->_set_archiveable(0);
    # }
    $self->_set_when_archiveable(($remove_time - min($fixed_ago,$moded_ago)) / (24 * 60 * 60));
    if ($fixed_ago > $remove_time and
	$moded_ago > $remove_time) {
	$self->_set_archiveable(1);
	$self->_set_when_archiveable(0);
    }
    return;
}

sub filter {
    my $self = shift;
    my %param = validate_with(params => \@_,
			      spec   => {seen_merged => {type => HASHREF,
							 default => sub {return {}},
							},
					 repeat_merged => {type => BOOLEAN,
							   default => 1,
							  },
					 include => {type => HASHREF,
						     optional => 1,
						    },
					 exclude => {type => HASHREF,
						     optional => 1,
						    },
					 min_days => {type => SCALAR,
						      optional => 1,
						     },
					 max_days => {type => SCALAR,
						      optional => 1,
						     },
					 },
			     );
    if (exists $param{include}) {
	return 1 if not $self->matches($param{include});
    }
    if (exists $param{exclude}) {
	return 1 if $self->matches($param{exclude});
    }
    if (exists $param{repeat_merged} and not $param{repeat_merged}) {
	my @merged = sort {$a<=>$b} $self->bug, $self->status->mergedwith;
	return 1 if first {sub {defined $_}}
            @{$param{seen_merged}}{@merged};
	@{$param{seen_merged}}{@merged} = (1) x @merged;
    }
    if (exists $param{min_days}) {
	return 1 unless $param{min_days} <=
	    (DateTime->now() - $self->created)->days();
    }
    if (exists $param{max_days}) {
	return 1 unless $param{max_days} >=
	    (DateTime->now() - $self->created)->days();
    }
    return 0;

}

sub __exact_match {
    my ($field, $values) = @_;
    my @ret = first {sub {$_ eq $field}} @{$values};
    return @ret != 0;
}

sub __contains_match {
    my ($field, $values) = @_;
    foreach my $value (@{$values}) {
        return 1 if (index($field, $value) > -1);
    }
    return 0;
}

state $field_match =
   {subject => sub {__contains_match($_[0]->subject,@_)},
    tags => sub {
	for my $value (@{$_[1]}) {
	    if ($_[0]->tags->is_set($value)) {
		return 1;
	    }
	}
	return 0;
	},
    severity => sub {__exact_match($_[0]->severity,@_)},
    pending => sub {__exact_match($_[0]->pending,@_)},
    originator => sub {__exact_match($_[0]->submitter,@_)},
    submitter => sub {__exact_match($_[0]->submitter,@_)},
    forwarded => sub {__exact_match($_[0]->forwarded,@_)},
    owner => sub {__exact_match($_[0]->owner,@_)},
   };

sub matches {
    my ($self,$hash) = @_;
    for my $key (keys %{$hash}) {
	my $sub = $field_match->{$key};
	if (not defined $sub) {
	    carp "No subroutine for key: $key";
	    next;
	}
	return 1 if $sub->($self,$hash->{$key});
    }
    return 0;
}

sub email {
    my $self = shift;
    return $self->id.'@'.$config{email_domain};
}

sub subscribe_email {
    my $self = shift;
    return $self->id.'-subscribe@'.$config{email_domain};
}

sub url {
    my $self = shift;
    return $config{web_domain}.'/'.$self->id;
}

sub mbox_url {
    my $self = shift;
    return $config{web_domain}.'/mbox:'.$self->id;
}

sub mbox_status_url {
    my $self = shift;
    return $self->mbox_url.'?mboxstatus=yes';
}

sub mbox_maint_url {
    my $self = shift;
    $self->mbox_url.'?mboxmaint=yes';
}

sub version_url {
    my $self = shift;
    my $url = Debbugs::URI->new('version.cgi?');
    $url->query_form(package => $self->status->package(),
                       found => [$self->status->found],
                       fixed => [$self->status->fixed],
                     @_,
                    );
    return $url->as_string;
}

sub related_packages_and_versions {
    my $self = shift;
    my @packages = $self->status->package;
    my @versions = ($self->status->found,
                    $self->status->fixed);
    my @unqualified_versions;
    my @return;
    for my $ver (@versions) {
        if ($ver =~ m{(<src>.+)/(<ver>.+)}) { # It's a src_pkg_ver
            push @return, ['src:'.$+{src}, $+{ver}];
        } else {
           push @unqualified_versions,$ver;
        }
    }
    for my $pkg (@packages) {
        if (@unqualified_versions) {
            push @return,
                [$pkg,@unqualified_versions];
        } else {
           push @return,$pkg;
        }
    }
    push @return,$self->status->affects;
    return @return;
}

sub CARP_TRACE {
    my $self = shift;
    return 'Debbugs::Bug={bug='.$self->bug.'}';
}

__PACKAGE__->meta->make_immutable;

no Mouse;
1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
