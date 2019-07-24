# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Collection::Correspondent;

=head1 NAME

Debbugs::Collection::Correspondent -- Bug generation factory

=head1 SYNOPSIS


=head1 DESCRIPTION



=cut

use Mouse;
use strictures 2;
use namespace::autoclean;
use Debbugs::Common qw(make_list hash_slice);
use Debbugs::OOTypes;
use Debbugs::Status qw(get_bug_statuses);

use Debbugs::Correspondent;

extends 'Debbugs::Collection';

has '+members' => (isa => 'ArrayRef[Debbugs::Correspondent]');

sub BUILD {
    my $self = shift;
    my $args = shift;
    if (exists $args->{correspondent}) {
        $self->
            add($self->_member_constructor(correspondent =>
                                           $args->{correspondent}));
    }
}


sub _member_constructor {
    # handle being called $self->_member_constructor;
    my $self = shift;
    my %args = @_;
    my @return;
    for my $corr (make_list($args{correspondent})) {
	push @return,
	    Debbugs::Correspondent->new(name => $corr,
					$self->schema_argument,
				       );
    }
    return @return;
}

around add_by_key => sub {
    my $orig = shift;
    my $self = shift;
    my @members =
        $self->_member_constructor(correspondent => [@_],
				   $self->schema_argument,
				  );
    return $self->$orig(@members);
};

sub member_key {
    return $_[1]->name;
}


__PACKAGE__->meta->make_immutable;

1;

__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
