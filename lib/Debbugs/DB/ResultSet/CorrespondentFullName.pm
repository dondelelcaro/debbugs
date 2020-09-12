# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.
use utf8;
package Debbugs::DB::ResultSet::CorrespondentFullName;

=head1 NAME

Debbugs::DB::ResultSet::CorrespondentFullName - Correspondent table actions

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Debbugs::DB::Util qw(select_one);

use Debbugs::Common qw(getparsedaddrs);
use Debbugs::DB::Util qw(select_one);
use Scalar::Util qw(blessed);

sub upsert_correspondent_id {
    my ($self,$addr) = @_;
    my $full_addr;
    if (blessed($addr)) {
	$full_addr = $addr->format();
    } else {
	$full_addr = $addr;
	undef $addr;
    }
    my $rs = $self->
	search({full_addr => $addr,
	       },
	      {result_class => 'DBIx::Class::ResultClass::HashRefInflator',
	      }
	      )->first();
    if (defined $rs) {
	return $rs->{correspondent};
    }
    if (not defined $addr) {
	$addr = getparsedaddrs($full_addr);
    }
    my $email = $addr->address();
    my $name = $addr->phrase();
    if (defined $name) {
	$name =~ s/^\"|\"$//g;
	$name =~ s/^\s+|\s+$//g;
    } else {
       $name = '';
    }
    my $ci = $self->result_source->schema->
	select_one(<<'SQL',$addr,$addr);
WITH ins AS (
INSERT INTO correspondent (addr) VALUES (?)
 ON CONFLICT (addr) DO NOTHING RETURNING id
)
SELECT id FROM ins
UNION ALL
SELECT id FROM correspondent WHERE addr = ?
LIMIT 1;
SQL
    $self->result_source->schema->
	select_one(<<'SQL',$ci,$full_addr,$name);
WITH ins AS (
INSERT INTO correspondent_full_name (correspondent,full_addr,name)
   VALUES (?,?,?) ON CONFLICT (correspondent,full_addr) DO UPDATE SET last_seen=NOW() RETURNING correspondent
)
SELECT 1 FROM ins
UNION ALL
SELECT 1;
SQL
    return $ci;
}



1;

__END__
