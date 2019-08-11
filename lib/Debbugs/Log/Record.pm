# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2019 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Log::Record;

=head1 NAME

Debbugs::Log::Record -- OO interface to bug log records

=head1 SYNOPSIS

   use Debbugs::Log::Record;

=head1 DESCRIPTION



=cut

use Mouse;
use strictures 2;
use namespace::clean;
use v5.10; # for state


has type => (is => 'rw',
	     isa => 'Str',
	     default => 'incoming-recv',
	    );

has start => (is => 'rw',
	      isa => 'Int',
	     );

has stop => (is => 'rw',
	     isa => 'Int',
	    );

has recipients => (is => 'rw',
		   isa => 'ArrayRef[Str]',
		   default => sub {[]}
		  );

has text => (is => 'ro',
	     isa => 'Str',
	     writer => '_text',
	     default => '',
	    );

sub add_text{
    my $self = shift;
    $self->_text($self->text().join('',@_));
}

has log_fh => (is => 'rw',
	       isa => 'FileHandle',
	      );
has fh => (is => 'rw',
	   lazy => 1,
	   builder =>
	   sub {my $self = shift;
		return
		    IO::InnerFile->new($self->log_fh,
				       $self->start,
				       $self->stop - $self->start,
				      );
	    },
	  );

__PACKAGE__->meta->make_immutable;

no Mouse;
no Mouse::Util::TypeConstraints;
1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
