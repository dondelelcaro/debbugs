# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Correspondent;

=head1 NAME

Debbugs::Correspondent -- OO interface to bugs

=head1 SYNOPSIS

   use Debbugs::Correspondent;
   Debbugs::Correspondent->new(schema => $s,binaries => [qw(foo)],sources => [qw(bar)]);

=head1 DESCRIPTION



=cut

use Mouse;
use strictures 2;
use namespace::clean;
use v5.10; # for state

use Mail::Address;
use Debbugs::OOTypes;
use Debbugs::Config qw(:config);

use Carp;

extends 'Debbugs::OOBase';

has name => (is => 'ro', isa => 'Str',
	     required => 1,
	     writer => '_set_name',
	    );

has _mail_address => (is => 'bare', isa => 'Mail::Address',
		      lazy => 1,
		      handles => [qw(address phrase comment)],
		      builder => '_build_mail_address',
		     );

sub _build_mail_address {
    my @addr = Mail::Address->parse($_[0]->name) or
	confess("unable to parse mail address");
    if (@addr > 1) {
	warn("Multiple addresses to Debbugs::Correspondent");
    }
    return $addr[0];
}

sub email {
    my $email = $_[0]->address;
    warn "No email" unless defined $email;
    return $email;
}

sub url {
    my $self = shift;
    return $config{web_domain}.'/correspondent:'.$self->email;
}

sub maintainer_url {
    my $self = shift;
    return $config{web_domain}.'/maintainer:'.$self->email;
}

sub owner_url {
    my $self = shift;
    return $config{web_domain}.'/owner:'.$self->email;
}

sub submitter_url {
    my $self = shift;
    return $config{web_domain}.'/submitter:'.$self->email;
}

sub CARP_TRACE {
    my $self = shift;
    return 'Debbugs::Correspondent={name='.$self->name.'}';
}


__PACKAGE__->meta->make_immutable;

no Mouse;
1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
