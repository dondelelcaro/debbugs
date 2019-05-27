# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Version;

=head1 NAME

Debbugs::Version -- OO interface to Version

=head1 SYNOPSIS

   use Debbugs::Version;
   Debbugs::Version->new(schema => $s,binaries => [qw(foo)],sources => [qw(bar)]);

=head1 DESCRIPTION



=cut

use Mouse;
use v5.10;
use strictures 2;
use namespace::autoclean;

use Debbugs::Config qw(:config);
use Debbugs::Collection::Package;
use Debbugs::OOTypes;
use Carp;

extends 'Debbugs::OOBase';

state $strong_severities =
   {map {($_,1)} @{$config{strong_severities}}};

has version => (is => 'ro', isa => 'Str',
		required => 1,
		builder => '_build_version',
		predicate => '_has_version',
	       );

sub type {
    confess("Subclass must define type");
}

has package => (is => 'bare',
                isa => 'Debbugs::Package',
                lazy => 1,
                builder => '_build_package',
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
    carp("No schema") unless exists $args{schema};
    if (exists $args{package} and
        not blessed($args{package})) {
        # OK, need a package Collection
        my $pkgc = $args{package_collection} //
            Debbugs::Collection::Package->
                new(exists $args{schema}?(schema => $args{schema}):());
        $args{package} =
            $pkgc->universe->get_or_add_by_key($args{package});
    }
    return $class->$orig(%args);
};


sub _build_package {
    my $self = shift;
    return Debbugs::Package->new(package => '(unknown)',
                                 type => $self->type,
                                 valid => 0,
                                 package_collection => $self->package_collection,
                                 $self->has_schema?(schema => $self->schema):(),
                                );
}


has valid => (is => 'ro',
	      isa => 'Bool',
	      default => 0,
	      reader => 'is_valid',
	     );

has 'package_collection' => (is => 'ro',
			     isa => 'Debbugs::Collection::Package',
			     builder => '_build_package_collection',
			     lazy => 1,
			    );
sub _build_package_collection {
    my $self = shift;
    return Debbugs::Collection::Package->new($self->schema_arg)
}


__PACKAGE__->meta->make_immutable;
no Mouse;
1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
