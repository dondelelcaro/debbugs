use utf8;
package Debbugs::DB;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-07-17 10:25:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wiMg1t5hFUhnyufL3yT5fQ

# This version must be incremented any time the schema changes so that
# DBIx::Class::DeploymentHandler can do its work
our $VERSION=12;

__PACKAGE__->load_components('+Debbugs::DB::Util');

# You can replace this text with custom code or comments, and it will be preserved on regeneration

# override connect to handle just passing a bare service
sub connect {
    my ($self,@rem) = @_;
    if ($rem[0] !~ /:/) {
	$rem[0] = 'dbi:Pg:service='.$rem[0];
    }
    $self->clone->connection(@rem);
}

1;
