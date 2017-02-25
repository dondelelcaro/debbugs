# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2016 by Don Armstrong <don@donarmstrong.com>.
use utf8;
package Debbugs::DB::ResultSet::Maintainer;

=head1 NAME

Debbugs::DB::ResultSet::Maintainer - Package maintainer result set operations

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Debbugs::DB::Util qw(select_one);



sub get_maintainers {
    my ($self,@maints) = @_;
    my %maints;
    for my $m ($self->result_source->schema->resultset('Maintainer')->
	       search(undef,
		     {result_class => 'DBIx::Class::ResultClass::HashRefInflator',
		      columns => [qw[id name] ]
		     })->all()) {
	$maints{$m->{name}} = $m->{id};
    }
    my @maint_names = grep {not exists $maints{$_}} @maints;
    my @maint_ids = $self->result_source->schema->
	txn_do(sub {
		   my @ids;
		   for my $name (@_) {
		       push @ids,
			   $self->result_source->schema->
			   resultset('Maintainer')->get_maintainer_id($name);
		   }
		   return @ids;
	       },@maint_names);
    @maints{@maint_names} = @maint_ids;
    return \%maints;
}

sub get_maintainer_id {
    my ($self,$maint) = @_;
    my $rs =
	$self->
	search({name => $maint},
	      {result_class => 'DBIx::Class::ResultClass::HashRefInflator',
	      }
	      )->first();
    if (defined $rs) {
	return $rs->{id};
    }
    my $ci =
	$self->result_source->schema->resultset('Correspondent')->
	get_correspondent_id($maint);
    return $self->result_source->schema->storage->
	dbh_do(sub {
		   my ($s,$dbh,$maint,$ci) = @_;
		   return select_one($dbh,<<'SQL',$maint,$ci,$maint);
WITH ins AS (
INSERT INTO maintainer (name,correspondent) VALUES (?,?)
ON CONFLICT (name) DO NOTHING RETURNING id
)
SELECT id FROM ins
UNION ALL
SELECT id FROM maintainer WHERE name = ?
LIMIT 1;
SQL
	       },
	       $maint,$ci
	      );
}

1;

__END__
