# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Bug::Tag;

=head1 NAME

Debbugs::Bug::Tag -- OO interface to bug tags

=head1 SYNOPSIS

   use Debbugs::Bug::Tag;

=head1 DESCRIPTION



=cut

use Mouse;
use strictures 2;
use namespace::clean;
use v5.10; # for state

use Debbugs::User;
use List::AllUtils qw(uniq);
use Debbugs::Config qw(:config);

state $valid_tags =
    {map {($_,1)} @{$config{tags}}};

state $short_tags =
   {%{$config{tags_single_letter}}};

extends 'Debbugs::OOBase';

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    if (@_ == 1 && !ref $_[0]) {
	my @tags = split / /,$_[0];
	my %tags;
	@tags{@tags} = (1) x @tags;
	return $class->$orig(tags => \%tags);
    } else {
	return $class->$orig(@_);
    }
};

has tags => (is => 'ro',
	     isa => 'HashRef[Str]',
	     traits => ['Hash'],
	     lazy => 1,
	     reader => '_tags',
	     builder => '_build_tags',
	     handles => {has_tags => 'count'}
	    );
has usertags => (is => 'ro',
		 isa => 'HashRef[Str]',
		 lazy => 1,
		 reader => '_usertags',
		 builder => '_build_usertags',
		);

sub _build_tags {
    return {};
}

sub _build_usertags {
    return {};
}

sub is_set {
    return ($_[0]->tag_is_set($_[1]) or
        $_[0]->usertag_is_set($_[1]));
}

sub tag_is_set {
    return exists $_[0]->_tags->{$_[1]} ? 1 : 0;
}

sub usertag_is_set {
    return exists $_[0]->_usertags->{$_[1]} ? 1 : 0;
}

sub unset_tag {
    my $self = shift;
    delete $self->_tags->{$_} foreach @_;
}

sub unset_usertag {
    my $self = shift;
    delete $self->_usertags->{$_} foreach @_;
}

sub set_tag {
    my $self = shift;
    for my $tag (@_) {
	if (not $self->valid_tag($tag)) {
	    confess("Invalid tag $tag");
	}
	$self->_tags->{$tag} = 1;
    }
    return $self;
}

sub valid_tag {
    return exists $valid_tags->{$_[1]}?1:0;
}

sub as_string {
    my $self = shift;
    return $self->join_all(' ');
}

sub join_all {
    my $self = shift;
    my $joiner = shift;
    $joiner //= ', ';
    return join($joiner,$self->all_tags);
}

sub all_tags {
    return uniq sort $_[0]->tags,$_[0]->usertags;
}

sub tags {
    return sort keys %{$_[0]->_tags}
}

sub short_tags {
    my $self = shift;
    my @r;
    for my $tag ($self->tags) {
	next unless exists $short_tags->{$tag};
	push @r,
	   {long => $tag,
	    short => $short_tags->{$tag},
	   };
    }
    if (wantarray) {
	return @r;
    } else {
       return [@r];
    }
}

sub usertags {
    return sort keys %{$_[0]->_usertags}
}

no Mouse;
1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
