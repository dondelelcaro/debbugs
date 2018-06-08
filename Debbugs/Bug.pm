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
use List::AllUtils qw(max first min);

use Params::Validate qw(validate_with :types);
use Debbugs::Config qw(:config);
use Debbugs::Status qw(read_bug);
use Debbugs::Bug::Tag;
use Debbugs::Collection::Package;
use Debbugs::Collection::Bug;
use Debbugs::Collection::Correspondent;

use Debbugs::OOTypes;

use Carp;

extends 'Debbugs::OOBase';

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

has status => (is => 'ro', isa => 'HashRef',
	       lazy => 1,
	       builder => '_build_status',
	      );

sub _build_status {
    my $self = shift;
    $self->reset;
    my $status = read_bug(bug=>$self->bug) or
	confess("Unable to read bug ".$self->bug);
    return $status;
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
    carp "No schema when building package collection";
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
     builder => '_build_package_collection',
     lazy => 1,
    );
sub _build_correspondent_collection   {
    my $self = shift;
    if ($self->has_schema) {
        return Debbugs::Collection::Correspondent->new(schema => $self->schema);
    }
    return Debbugs::Collection::Correspondent->new();
}

sub reset {
    my $self = shift;
    $self->_clear_done();
    $self->_clear_severity();
    $self->_clear_packages();
    $self->_clear_sources();
    $self->_clear_affects();
    $self->_clear_blocks();
    $self->_clear_blockedby();
    $self->_clear_found();
    $self->_clear_fixed();
    $self->_clear_mergedwith();
    $self->_clear_pending();
    $self->_clear_location();
    $self->_clear_archived();
    $self->_clear_archiveable();
    $self->_clear_when_archiveable();
    $self->_clear_submitter();
    $self->_clear_created();
    $self->_clear_modified();
    $self->_set_saved(1);
}

sub _clear_saved_if_changed {
    my ($self,$new,$old) = @_;
    if (@_ > 2) {
	if ($new ne $old) {
	    $self->_set_saved(0);
	}
    }
}

# package attributes
for my $attr (qw(packages affects sources)) {
    has $attr =>
	(is => 'rw',
	 isa => 'Debbugs::Collection::Package',
	 clearer => '_clear_'.$attr,
	 builder => '_build_'.$attr,
	 trigger => \&_clear_saved_if_changed,
	 lazy => 1,
	);
}

# bugs
for my $attr (qw(blocks blockedby mergedwith)) {
    has $attr =>
	(is => 'ro',
	 isa => 'Debbugs::Collection::Bug',
	 clearer => '_clear_'.$attr,
	 builder => '_build_'.$attr,
	 handles => {},
	 lazy => 1,
	);
}


for my $attr (qw(owner submitter)) {
    has $attr.'_corr' =>
        (is => 'ro',
         isa => 'Debbugs::Correspondent',
         lazy => 1,
         builder => '_build_'.$attr.'_corr',
         clearer => '_clear_'.$attr.'_corr',
         handles => {$attr.'_url' => $attr.'_url',
                     $attr.'_email' => 'email',
                     $attr.'_phrase' => 'phrase',
                    },
        );
}

sub _build_owner_corr {
    my $self = shift;
    return $self->correspondent_collection->get_or_create($self->owner);
}

sub _build_submitter_corr {
    my $self = shift;
    return $self->correspondent_collection->get_or_create($self->submitter);
}

for my $attr (qw(done severity),
	      qw(forwarded),
	      qw(pending location submitter),
	      qw(owner subject),
	     ) {
    has $attr =>
	(is => 'rw',
	 isa => 'Str',
	 clearer => '_clear_'.$attr,
	 builder => '_build_'.$attr,
	 trigger => \&_clear_saved_if_changed,
	 lazy => 1,
	);
}

sub is_done {
    return length $_[0]->done?1:0;
}
sub _build_done {
    return $_[0]->status->{done} // '';
}

sub _build_severity {
    return $_[0]->status->{severity} // $config{default_severity};
}

sub _build_subject {
    return $_[0]->status->{subject} // '(No subject)';
}

sub strong_severity {
    my $self = shift;
    return exists $strong_severities->{$self->severity};
}

sub short_severity {
    $_[0]->severity =~ m/^(.)/;
    return $1;
}

sub package {
    my $self = shift;
    return join(', ',$self->packages->apply(sub{$_->name}));
}

sub _build_packages {
    my $self = shift;
    my @packages;
    if (length($self->status->{package}//'')) {
	@packages = split /,/,$self->status->{package}//'';
    }
    return $self->package_collection->
	    limit(@packages);
}

sub is_affecting {
    my $self = shift;
    return $self->affects->count > 0;
}

sub affect {
    local $_;
    return join(', ',map {$_->name} $_[0]->affects->members);
}

sub _build_affects {
    my @packages;
    if (length($_[0]->status->{affects}//'')) {
	@packages = split /,/,$_[0]->status->{affects}//'';
    }
    return $_[0]->package_collection->
	    limit(@packages);
}
sub source {
    local $_;
    return join(', ',map {$_->name} $_[0]->sources->members);
}
sub _build_sources {
    local $_;
    my @sources = map {$_->sources} $_[0]->packages->members;
    return @sources;
}

sub is_owned {
    my $self = shift;
    return length($self->owner) > 0;
}
sub _build_owner {
    my $self = shift;
    return $self->status->{owner} // '';
}


sub _split_if_defined {
    my ($self,$field,$split) = @_;
    $split //= ' ';
    my $e = $self->status->{$field};
    my @f;
    if (defined $e and
	length $e) {
	return split /$split/,$e;
    }
    return ();
}

sub is_blocking {
    my $self = shift;
    return $self->blocks->count > 0;
}

sub _build_blocks {
    my $self = shift;
    return $self->bug_collection->
	limit(sort {$a <=> $b}
	      $self->_split_if_defined('blocks'));
}

sub is_blocked {
    my $self = shift;
    return $self->blockedby->count > 0;
}

sub _build_blockedby {
    my $self = shift;
    return $self->bug_collection->
	limit(sort {$a <=> $b}
	      $self->_split_if_defined('blockedby'));
}

sub is_forwarded {
    length($_[0]->forwarded) > 0;
}

sub _build_forwarded {
    my $self = shift;
    return $self->status->{forwarded} // '';
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
    return $self->found->count > 0;
}

sub _build_found {
    my $self = shift;
    return $self->packages->
	get_source_versions(@{$self->status->{found_versions} // []});
}

sub has_fixed {
    my $self = shift;
    return $self->fixed->count > 0;
}

sub _build_fixed {
    my $self = shift;
    return $self->packages->
        get_source_versions(@{$self->status->{fixed_versions} // []});
}

sub is_merged {
    my $self = shift;
    return $self->mergedwith->count > 0;
}

sub _build_mergedwith {
    my $self = shift;
    return $self->bug_collection->
	limit(sort {$a <=> $b}
	      $self->_split_if_defined('mergedwith'));
}
sub _build_pending {
    return $_[0]->status->{pending} // '';
}
sub _build_submitter {
    return $_[0]->status->{originator} // '';
}

for my $attr (qw(created modified)) {
    has $attr => (is => 'rw', isa => 'Object',
		clearer => '_clear_'.$attr,
		builder => '_build_'.$attr,
		lazy => 1);
}
sub _build_created {
    return DateTime->
	from_epoch(epoch => $_[0]->status->{date} // time);
}
sub _build_modified {
    return DateTime->
	from_epoch(epoch => max($_[0]->status->{log_modified},
				$_[0]->status->{last_modified}
			       ));
}
sub _build_location {
    return $_[0]->status->{location};
}
has archived => (is => 'ro', isa => 'Bool',
		 clearer => '_clear_archived',
		 builder => '_build_archived',
		 lazy => 1);
sub _build_archived {
    return $_[0]->location eq 'archived'?1:0;
}

has tags => (is => 'ro', isa => 'Object',
	     clearer => '_clear_tags',
	     builder => '_build_tags',
	     lazy => 1,
	    );
sub _build_tags {
    return Debbugs::Bug::Tag->new($_[0]->status->{keywords});
}

=item buggy

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
	    $ver = Debbugs::Version->
		new(version => $ver,
                    package => $self,
		    package_collection => $self->package_collection,
		   );
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
    state $remove_time = 24 * 60 * 60 * ($config{removal_age} // 30);
    # 4. Have been modified more than removal_age ago
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
	my @merged = sort {$a<=>$b} $self->bug, map {$_->bug} $self->mergedwith->members;
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

sub url {
    my $self = shift;
    return $config{web_domain}.'/'.$self->id;
}

sub related_packages_and_versions {
    my $self = shift;
    my @packages;
    if (length($self->status->{package}//'')) {
	@packages = split /,/,$self->status->{package}//'';
    }
    my @versions =
        (@{$self->status->{found_versions}//[]},
         @{$self->status->{fixed_versions}//[]});
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
        push @return,
            [$pkg,@unqualified_versions];
    }
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
