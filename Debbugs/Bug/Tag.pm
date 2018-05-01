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

use Debbugs::Config qw(:config);

state $valid_tags =
    {map {($_,1)} @{$config{tags}}};

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

has tags => (is => 'ro', isa => 'HashRef[Str]',
	     default => sub {{}},
	    );
has usertags => (is => 'ro',isa => 'HashRef[Str]',
		 default => sub {{}},
		);

sub tag_is_set {
    return exists $_[0]->tags->{$_[1]} ? 1 : 0;
}

sub unset_tag {
    my $self = shift;
    delete $self->tags->{$_} foreach @_;
}

sub set_tag {
    my $self = shift;
    for my $tag (@_) {
	if (not $self->valid_tag($tag)) {
	    confess("Invalid tag $tag");
	}
	$self->tags->{$tag} = 1;
    }
    return $self;
}

sub valid_tag {
    return exists $valid_tags->{$_[1]}?1:0;
}

sub as_string {
    return join(' ',sort keys %{$_[0]->tags})
}

no Mouse;
1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
