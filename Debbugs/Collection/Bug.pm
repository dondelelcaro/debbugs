# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Collection::Bug;

=head1 NAME

Debbugs::Collection::Bug -- Bug generation factory

=head1 SYNOPSIS


=head1 DESCRIPTION



=cut

use Mouse;
use strictures 2;
use namespace::autoclean;
use Debbugs::Common qw(make_list hash_slice);
use Debbugs::OOTypes;
use Debbugs::Status qw(get_bug_statuses);

extends 'Debbugs::Collection';

has '+members' => (isa => 'ArrayRef[Bug]');
has 'package_collection' => (is => 'rw',
                          isa => 'Debbugs::Collection::Package',
                          default => sub {Debbugs::Collection::Package->new()}
                         );

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;

    my %args;
    if (@_==1 and ref($_[0]) eq 'HASH') {
        %args = %{$_[0]};
    } else {
        %args = @_;
    }
    $args{members} //= [];
    if (exists $args{bugs}) {
        push @{$args{members}},
            _member_constructor(bugs => $args{bugs},
                                hash_slice(%args,qw(schema constructor_args)),
                               );
        delete $args{bugs};
    }
    return $class->$orig(%args);
};

sub _member_constructor {
    # handle being called $self->_member_constructor;
    if ((@_ % 2) == 1) {
        shift;
    }
    my %args = @_;
    my @return;
    if (exists $args{schema}) {
        my $statuses = get_bug_statuses(bug => [make_list($args{bugs})],
                                        schema => $args{schema},
                                       );
        while (my ($bug, $status) = each %{$statuses}) {
            push @return,
                Debbugs::Bug->new(bug=>$bug,
                                  status=>$status,
                                  schema=>$args{schema},
                                  @{$args{constructor_args}//[]},
                                 );
        }
    } else {
        for my $bug (make_list($args{bugs})) {
            push @return,
                Debbugs::Bug->new(bug => $bug,
                                  @{$args{constructor_args}//[]},
                                 );
        }
    }
    return @return;
}

around add_by_key => sub {
    my $orig = shift;
    my $self = shift;
    my @members =
        _member_constructor(bugs => [@_],
                            $self->has_schema?(schema => $self->schema):(),
                            constructor_args => $self->constructor_args,
                           );
    return $self->$orig(@members);
};

sub member_key {
    return $_[1]->bug;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
