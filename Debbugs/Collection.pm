# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Collection;

=head1 NAME

Debbugs::Collection -- Collection base class which can generate lots of objects

=head1 SYNOPSIS


=head1 DESCRIPTION



=cut

use Mouse;
use strictures 2;
use namespace::autoclean;

extends 'Debbugs::OOBase';

has 'members' => (is => 'bare',
		  isa => 'ArrayRef',
		  traits => ['Array'],
		  default => sub {[]},
                  writer => '_set_members',
                  predicate => '_has_members',
		  handles => {_add => 'push',
			      members => 'elements',
			      count => 'count',
			      _get_member => 'get',
                              grep => 'grep',
                              apply => 'apply',
                              map => 'map',
                              sort => 'sort',
			     },
		 );

sub members_ref {
    my $self = shift;
    return [$self->members];
}

has 'member_hash' => (traits => ['Hash'],
		      is => 'bare',
                      # really a HashRef[Int], but type checking is too slow
		      isa => 'HashRef',
		      lazy => 1,
		      reader => '_member_hash',
		      builder => '_build_member_hash',
                      clearer => '_clear_member_hash',
                      predicate => '_has_member_hash',
                      writer => '_set_member_hash',
		      handles => {# _add_member_hash => 'set',
				  _member_key_exists => 'exists',
				  _get_member_hash => 'get',
				 },
		     );

# because _add_member_hash needs to be fast, we are overriding the default set
# method which is very safe but slow, because it makes copies.
sub _add_member_hash {
    my ($self,@kv) = @_;
    pairmap {
        defined($a)
            or $self->meta->
            throw_error("Hash keys passed to _add_member_hash must be defined" );
        ($b eq int($b)) or
            $self->meta->
            throw_error("Values passed to _add_member_hash must be integer");
    } @kv;
    my @return;
    while (my ($key, $value) = splice @kv, 0, 2 ) {
        push @return,
            $self->{member_hash}{$key} = $value
    }
    wantarray ? return @return: return $return[0];
}

has 'universe' => (is => 'ro',
                   isa => 'Debbugs::Collection',
                   required => 1,
                   builder => '_build_universe',
                   writer => '_set_universe',
                   predicate => 'has_universe',
                  );

sub _build_universe {
    # By default, the universe is myself
    return $_[0];
}

sub clone {
    my $self = shift;
    my $new = bless { %{$self} }, ref $self;
    if ($self->_has_members) {
        $new->_set_members([$self->members]);
    }
    if ($self->_has_member_hash) {
        $new->_set_member_hash({%{$self->_member_hash}})
    }
    return $new;
}

sub _shallow_clone {
    my $self = shift;
    return bless { %{$self} }, ref $self;
}

sub limit {
    my $self = shift;
    my $limit = $self->_shallow_clone();
    # Set the universe to whatever my universe is (potentially myself)
    # $limit->_set_universe($self->universe);
    $limit->_set_members([]);
    $limit->_clear_member_hash();
    $limit->add($self->universe->get_or_create(@_)) if @_;
    return $limit;
}

sub get_or_create {
    my $self = shift;
    return () unless @_;
    my @return;
    my @exists;
    my @need_to_add;
    for my $i (0..$#_) {
        # we assume that if it's already a blessed reference, that it's the right
        if (blessed($_[$i])) {
            $return[$i] =
                $_[$i];
        }
        elsif ($self->_member_key_exists($_[$i])) {
            push @exists,$i;
        } else {
            push @need_to_add,$i;
        }
    }
    # create and add by key
    if (@need_to_add) {
        @return[@need_to_add] =
            $self->add_by_key(@_[@need_to_add]);
    }
    if (@exists) {
        @return[@exists] =
            $self->get(@_[@exists]);
    }
    # if we've only been asked to get or create one thing, then it's expected
    # that we are returning only one thing
    if (@_ == 1) {
        return $return[0];
    }
    return @return;
}

has 'constructor_args' => (is => 'rw',
			   isa => 'ArrayRef',
			   default => sub {[]},
			  );

sub add_by_key {
    my $self = shift;
    # we'll assume that add does the right thing. around this in subclasses
    return $self->add(@_);
}

sub add {
    my $self = shift;
    my @members_added;
    for my $member (@_) {
        if (not defined $member) {
            confess("Undefined member to add");
        }
        push @members_added,$member;
	if ($self->exists($member)) {
	    next;
	}
	$self->_add($member);
	$self->_add_member_hash($self->member_key($member),
				$self->count()-1,
			       );
    }
    return @members_added;
}

sub get {
    my $self = shift;
    return $self->_get_member($self->_get_member_hash(@_));
}


sub member_key {
    return $_[1];
}

sub exists {
    my $self = shift;
    return $self->_member_key_exists($self->member_key($_[0]));
}

sub _build_member_hash {
    my $self = shift;
    my $hash = {};
    my $i = 0;
    for my $member ($self->members) {
	$hash->{$self->member_key($member)} =
	    $i++;
    }
    return $hash;
}

sub CARP_TRACE {
    my $self = shift;
    return 'Debbugs::Collection={n_members='.$self->count().'}';
}


__PACKAGE__->meta->make_immutable;
no Mouse;
1;

__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
