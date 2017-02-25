# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.
use utf8;
package Debbugs::DB::ResultSet::Correspondent;

=head1 NAME

Debbugs::DB::ResultSet::Correspondent - Correspondent table actions

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Debbugs::DB::Util qw(select_one);

use Debbugs::Common qw(getparsedaddrs);
use Debbugs::DB::Util qw(select_one);

sub get_correspondent_id {
    my ($self,$addr) = @_;
    my $full_name;
    if ($addr =~ /</) {
	$addr = getparsedaddrs($addr);
	$full_name = $addr->phrase();
	$full_name =~ s/^\"|\"$//g;
	$full_name =~ s/^\s+|\s+$//g;
	$addr = $addr->address();
    }
    my $rs =
	$self->
	search({addr => $addr},
	      {result_class => 'DBIx::Class::ResultClass::HashRefInflator',
	      }
	      )->first();
    if (defined $rs) {
	return $rs->{id};
    }
    return $self->result_source->schema->storage->
	dbh_do(sub {
		   my ($s,$dbh,$addr,$full_name) = @_;
		   my $ci = select_one($dbh,<<'SQL',$addr,$addr);
WITH ins AS (
INSERT INTO correspondent (addr) VALUES (?)
 ON CONFLICT (addr) DO NOTHING RETURNING id
)
SELECT id FROM ins
UNION ALL
SELECT id FROM correspondent WHERE addr = ?
LIMIT 1;
SQL
		   select_one($dbh,<<'SQL',$ci,$full_name,$ci,$full_name);
WITH ins AS (
INSERT INTO correspondent_full_name (correspondent,full_name)
   VALUES (?,?) ON CONFLICT (correspondent,full_name) DO NOTHING RETURNING id
)
SELECT id FROM ins
UNION ALL
SELECT id FROM correspondent_full_name WHERE correspondent=? AND full_name = ?
LIMIT 1;
SQL
		   return $ci;
},
	       $addr,
	       $full_name
	      );

}



1;

__END__
