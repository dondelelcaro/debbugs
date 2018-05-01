# This module is part of debbugs, and
# is released under the terms of the GPL version 3, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Package;

=head1 NAME

Debbugs::Package -- OO interface to packages

=head1 SYNOPSIS

   use Debbugs::Package;
   Debbugs::Package->new(schema => $s,binaries => [qw(foo)],sources => [qw(bar)]);

=head1 DESCRIPTION



=cut

use warnings;
use strict;

use Mouse;

use Debbugs::Version;

extends 'Debbugs::OOBase';

has name => (is => 'ro', isa => 'Str',
	     lazy => 1,
	     required => 1,
	     builder => '_build_name',
	    );

has type => (is => 'ro', isa => 'Str',
	     lazy => 1,
	     builder => '_build_type',
	     clearer => '_clear_type',
	    );

has valid => (is => 'ro', isa => 'Bool',
	      lazy => 1,
	      builder => '_build_valid',
	      writer => '_set_valid',
	     );

has 'sources' => (is => 'ro',isa => 'Array');
has 'dists' => (is => 'ro',isa => 'Array');

has 'versions' => (is => 'ro',isa => 'Array');

# gets used to retrieve packages
has 'package_collection' => (is => 'ro',
			     isa => 'Debbugs::Collection::Package',
			     builder => '_build_package_collection',
			     lazy => 1,
			    );

sub _build_package_collection {
    return Debbugs::Collection::Package->new();
}

sub populate {
    my $self = shift;

    my @binaries = $self->binaries;
    my @sources = $self->sources;
    my $s = $self->schema;
    carp "No schema" unless $self->schema;

    my $src_rs = $s->resultset('SrcVer')->
	search({'src_pkg.pkg'=>[$self->sources],
		-or => {'suite.codename' => [make_list($param{dist})],
			'suite.suite_name' => [make_list($param{dist})],
		       }
	       },
	      {join => ['src_pkg',
		       {
			src_associations=>'suite'},
		       ],
	       '+select' => [qw(src_pkg.pkg),
			     qw(suite.codename),
			     qw(src_associations.modified),
			     q(CONCAT(src_pkg.pkg,'/',me.ver))],
	       '+as' => ['src_pkg_name','codename',
			 'modified_time',
			 qw(src_pkg_ver)],
	       result_class => 'DBIx::Class::ResultClass::HashRefInflator',
	       order_by => {-desc => 'me.ver'},
	      },
	      );
    
}

sub packages {
    my $self = shift;
    $self->populate() unless $self->initialized;
}

sub versions {
    my $self = shift;
    $self->populate() unless $self->initialized;
}


package Debbugs::Package::Version;

use base qw(Class::Accessor);
__PACKAGE__->mk_ro_accessors(qw(schema ));

sub version {
}

sub type {

}

sub 

package Debbugs::Package::Package;

package Debbugs::Package::Maintainer;


1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
