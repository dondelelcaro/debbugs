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
use List::AllUtils qw(max);

use Debbugs::Config qw(:config);
use Debbugs::Status qw(read_bug);
use Debbugs::Bug::Tag;
use Debbugs::Collection::Package;
use Debbugs::Collection::Bug;

use Debbugs::OOTypes;

extends 'Debbugs::OOBase';

state $strong_severities =
   {map {($_,1)} @{$config{strong_severities}}};

has bug => (is => 'ro', isa => 'Int',
	    required => 1,
	   );

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
    return Debbugs::Collection::Package->new();
}
has bug_collection => (is => 'ro',
		       isa => 'Debbugs::Collection::Bug',
		       builder => '_build_bug_collection',
		      );
sub _build_bug_collection {
    return Debbugs::Collection::Bug->new();
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
	(is => 'bare',
	 isa => 'Debbugs::Collection::Bug',
	 clearer => '_clear_'.$attr,
	 builder => '_build_'.$attr,
	 handles => {},
	 lazy => 1,
	);
}



for my $attr (qw(done severity),
	      qw(found fixed),
	      qw(pending location submitter),
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

sub strong_severity {
    my $self = shift;
    return exists $strong_severities->{$self->severity};
}

sub package {
    local $_;
    return join(', ',map {$_->name} $_[0]->packages);
}

sub _build_packages {
    return [$_[0]->package_collection->
	    get_package($_[0]->status->{package} //
			'')
	   ];
}

sub affect {
    local $_;
    return join(', ',map {$_->name} $_[0]->affects->members);
}

sub _build_affects {
    return [$_[0]->package_collection->
	    get_package($_[0]->status->{affects} //
			'')
	   ];
}
sub source {
    local $_;
    return join(', ',map {$_->name} $_[0]->sources->members);
}
sub _build_sources {
    local $_;
    my @sources = map {$_->sources} $_[0]->packages;
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

sub _build_blocks {
    my $self = shift;
    return $self->bug_collection->
	limit_or_create(sort {$a <=> $b}
			$self->_split_if_defined('blocks'));
}

sub _build_blockedby {
    my $self = shift;
    return $self->bug_collection->
	limit_or_create(sort {$a <=> $b}
			$self->_split_if_defined('blockedby'));
}

sub _build_found {
    my $self = shift;
    return $self->sources->
	versions($self->_split_if_defined('found',',\s*'));
}


sub _build_fixed {
    my $self;
    return $self->sources->
	versions($self->_split_if_defined('fixed',',\s*'));
}
sub _build_mergedwith {
    my $self = shift;
    return $self->bug_collection->
	limit_or_create(sort {$a <=> $b}
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
	versions;
    my $max_buggy = 'absent';
    for my $ver (@_) {
	if (not ref($ver)) {
	    $ver = Debbugs::Version->
		new(string => $ver,
		    package_collection => $self->package_collection,
		   );
	}
	$vertree->load($ver->source);
	my $buggy =
	    $vertree->tree->
	    buggy($ver->srcver,
		  [map {$_->srcver} $self->found],
		  [map {$_->srcver} $self->fixed]);
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
    state $remove_time = 24 * 60 * 60 * $config{removal_age};
    # 4. Have been modified more than removal_age ago
    my $moded_ago =
	$time - $self->last_modified;
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
    my $buggy = $self->buggy($self->package->
			     dist_source_versions(@distributions));
    if ('found' eq $buggy) {
	$self->_set_archiveable(0);
	$self->_set_when_archiveable(-1);
	return;
    }
    my $fixed_ago = $time - $self->when_fixed(@distributions);
    if ($fixed_ago < $remove_time) {
	$self->_set_archiveable(0);
    }
    $self->_set_when_archiveable(($remove_time - min($fixed_ago,$moded_ago)) / (24 * 60 * 60));
    if ($fixed_ago > $remove_time and
	$moded_ago > $remove_time) {
	$self->_set_archiveable(1);
	$self->_set_when_archiveable(0);
    }
    return;
}


no Mouse;
1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
