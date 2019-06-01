# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Bug::Status;

=head1 NAME

Debbugs::Bug::Status -- OO interface to status files

=head1 SYNOPSIS

   use Debbugs::Bug;
   Debbugs::Bug->new(schema => $s,binaries => [qw(foo)],sources => [qw(bar)]);

=head1 DESCRIPTION



=cut

use Mouse;
use strictures 2;
use namespace::clean;
use v5.10; # for state
use Mouse::Util::TypeConstraints qw(enum);

use DateTime;
use List::AllUtils qw(max first min);

use Params::Validate qw(validate_with :types);
use Debbugs::Common qw(make_list);
use Debbugs::Config qw(:config);
use Debbugs::Status qw(get_bug_status);

use Debbugs::OOTypes;

use Carp;

extends 'Debbugs::OOBase';

my $meta = __PACKAGE__->meta;

has bug => (is => 'ro', isa => 'Int',
	   );

# status obtained from DB, filesystem, or hashref
has status_source => (is => 'ro',
		      isa => enum([qw(db filesystem hashref)]),
		      default => 'filesystem',
		      writer => '_set_status_source',
		     );

has _status => (is => 'bare',
                writer => '_set_status',
                reader => '_status',
                predicate => '_has__status',
               );

my %field_methods;

sub BUILD {
    my $self = shift;
    my $args = shift;
    if (not exists $args->{status} and exists $args->{bug}) {
	if ($self->has_schema) {
	    ($args->{status}) =
		$self->schema->resultset('BugStatus')->
		search_rs({id => [make_list($args->{bug})]},
			 {result_class => 'DBIx::Class::ResultClass::HashRefInflator'})->
			     all();
	    state $field_mapping =
	       {originator => 'submitter',
		blockedby => 'blocked_by',
		found_versions => 'found',
		fixed_versions => 'fixed',
	       };
	    for my $field (keys %{$field_mapping}) {
		$args->{status}{$field_mapping->{$field}} =
		    $args->{status}{$field} if defined $args->{status}{$field};
		delete $args->{status}{$field};
	    }
	    $self->_set_status_source('db');
	} else {
	    $args->{status} = get_bug_status(bug=>$args->{bug});
	    state $field_mapping =
	       {originator => 'submitter',
		keywords => 'tags',
		msgid => 'message_id',
		blockedby => 'blocked_by',
		found_versions => 'found',
		fixed_versions => 'fixed',
	       };
	    for my $field (keys %{$field_mapping}) {
		$args->{status}{$field_mapping->{$field}} =
		    $args->{status}{$field};
	    }
	    $self->_set_status_source('filesystem');
	}
    } elsif (exists $args->{status}) {
	$self->_set_status_source('hashref');
    }
    if (exists $args->{status}) {
	if (ref($args->{status}) ne 'HASH') {
	    croak "status must be a HASHREF (argument to __PACKAGE__)";
	}
        $self->_set_status($args->{status});
	# single value fields
	for my $field (qw(submitter date subject message_id done severity unarchived),
		       qw(owner summary outlook bug log_modified),
		       qw(last_modified archived forwarded)) {
	    next unless defined $args->{status}{$field};
	    # we're going to let status override passed values in args for now;
	    # maybe this should change
            if (not exists $field_methods{'_set_'.$field}) {
                $field_methods{'_set_'.$field} =
                    $meta->find_method_by_name('_set_'.$field);
                if (not defined $field_methods{'_set_'.$field}) {
                    croak "Unable to find field method for _set_$field";
                }
            }
            $field_methods{'_set_'.$field}->($self,$args->{status}{$field});
	}
	# multi value fields
	for my $field (qw(affects package tags blocks blocked_by mergedwith),
		       qw(found fixed)) {
	    next unless defined $args->{status}{$field};
	    my $field_method = $meta->find_method_by_name('_set_'.$field);
            if (not exists $field_methods{'_set_'.$field}) {
                $field_methods{'_set_'.$field} =
                    $meta->find_method_by_name('_set_'.$field);
                if (not defined $field_methods{'_set_'.$field}) {
                    croak "Unable to find field method for _set_$field";
                }
            }
	    my $split_field = $args->{status}{$field};
	    if (!ref($split_field)) {
		$split_field =
		    _build_split_field($args->{status}{$field},
				       $field);
	    }
            $field_methods{'_set_'.$field}->($self,
                                             $split_field);
	}
	delete $args->{status};
    }
}

has saved => (is => 'ro', isa => 'Bool',
	      default => 0,
	      writer => '_set_set_saved',
	     );

sub __field_or_def {
    my ($self,$field,$default) = @_;
    if ($self->_has__status) {
        my $s = $self->_status()->{$field};
        return $s if defined $s;
    }
    return $default;
}

=head2 Status Fields

=cut

=head3 Single-value Fields

=over

=item submitter (single)

=cut

has submitter =>
    (is => 'ro',
     isa => 'Str',
     builder =>
     sub {
         my $self = shift;
         $self->__field_or_def('submitter',
                               $config{maintainer_email});
      },
     writer => '_set_submitter',
    );

=item date (single)

=cut

has date =>
    (is => 'ro',
     isa => 'Str',
     builder =>
     sub {
         my $self = shift;
         $self->__field_or_def('date',
                               time);
      },
     lazy => 1,
     writer => '_set_date',
    );

=item last_modified (single)

=cut

has last_modified =>
    (is => 'ro',
     isa => 'Str',
     builder =>
     sub {
         my $self = shift;
         $self->__field_or_def('last_modified',
                               time);
      },
     lazy => 1,
     writer => '_set_last_modified',
    );

=item log_modified (single)

=cut

has log_modified =>
    (is => 'ro',
     isa => 'Str',
     builder =>
     sub {
         my $self = shift;
         $self->__field_or_def('log_modified',
                                time);
      },
     lazy => 1,
     writer => '_set_log_modified',
    );


=item subject

=cut

has subject =>
    (is => 'ro',
     isa => 'Str',
     builder =>
     sub {
         my $self = shift;
         $self->__field_or_def('subject',
                               'No subject');
     },
     writer => '_set_subject',
    );

=item message_id

=cut

has message_id =>
    (is => 'ro',
     isa => 'Str',
     lazy => 1,
     builder =>
     sub {
	 my $self = shift;
         $self->__field_or_def('message_id',
                               'nomessageid.'.$self->date.'_'.
                               md5_hex($self->subject.$self->submitter).
                               '@'.$config{email_domain},
                              );
     },
     writer => '_set_message_id',
    );


=item done

=item severity

=cut

has severity =>
    (is => 'ro',
     isa => 'Str',
     builder =>
     sub {
         my $self = shift;
         $self->__field_or_def('severity',
                               $config{default_severity});
     },
     writer => '_set_severity',
    );

=item unarchived

Unix epoch the bug was last unarchived. Zero if the bug has never been
unarchived.

=cut

has unarchived =>
    (is => 'ro',
     isa => 'Int',
     builder =>
     sub {
         my $self = shift;
         $self->__field_or_def('unarchived',
                               0);
     },
     writer => '_set_unarchived',
    );

=item archived

True if the bug is archived, false otherwise.

=cut

has archived =>
    (is => 'ro',
     isa => 'Int',
     builder =>
     sub {
         my $self = shift;
         $self->__field_or_def('archived',
                               0);
     },
     writer => '_set_archived',
    );

=item owner

=item summary

=item outlook

=item done

=item forwarded

=cut

for my $field (qw(owner unarchived summary outlook done forwarded)) {
    has $field =>
	(is => 'ro',
	 isa => 'Str',
         builder =>
         sub {
             my $self = shift;
             $self->__field_or_def($field,
                                   '');
         },
	 writer => '_set_'.$field,
	);
    my $field_method = $meta->find_method_by_name($field);
    die "No field method for $field" unless defined $field_method;
    $meta->add_method('has_'.$field =>
		      sub {my $self = shift;
			   return length($field_method->($self));
		       });
}

=back

=head3 Multi-value Fields

=over

=item affects

=item package

=item tags

=cut

for my $field (qw(affects package tags)) {
    has '_'.$field =>
	(is => 'ro',
	 traits => [qw(Array)],
	 isa => 'ArrayRef[Str]',
         builder =>
         sub {
             my $self = shift;
             if ($self->_has__status) {
                 my $s = $self->_status()->{$field};
                 if (!ref($s)) {
                     $s = _build_split_field($s,
                                             $field);
                 }
                 return $s;
             }
             return [];
         },
	 writer => '_set_'.$field,
	 handles => {$field => 'elements',
		    },
	 lazy => 1,
	);
    my $field_method = $meta->find_method_by_name($field);
    if (defined $field_method) {
	$meta->add_method($field.'_ref'=>
			  sub {my $self = shift;
			       return [$field_method->($self)]
			   });
    }
}

=item found

=item fixed

=cut

sub __hashref_field {
    my ($self,$field) = @_;

    if ($self->_has__status) {
        my $s = $self->_status()->{$field};
        if (!ref($s)) {
            $s = _build_split_field($s,
                                    $field);
        }
        return $s;
    }
    return [];
}

for my $field (qw(found fixed)) {
    has '_'.$field =>
	(is => 'ro',
	 traits => ['Hash'],
	 isa => 'HashRef[Str]',
         builder =>
         sub {
             my $self = shift;
             if ($self->_has__status) {
                 my $s = $self->_status()->{$field};
                 if (!ref($s)) {
                     $s = _build_split_field($s,
                                             $field);
                 }
                 if (ref($s) ne 'HASH') {
                     $s = {map {$_,'1'} @{$s}};
                 }
                 return $s;
             }
             return {};
         },
	 default => sub {return {}},
	 writer => '_set_'.$field,
	 handles => {$field => 'keys',
		    },
	 lazy => 1,
	);
    my $field_method = $meta->find_method_by_name($field);
    if (defined $field_method) {
	$meta->add_method('_'.$field.'_ref'=>
			  sub {my $self = shift;
			       return [$field_method->($self)]
			   });
    }
}


for (qw(found fixed)) {
    around '_set_'.$_ => sub {
	my $orig = shift;
	my $self = shift;
	if (defined ref($_[0]) and
	    ref($_[0]) eq 'ARRAY'
	   ) {
	    @_ = {map {$_,'1'} @{$_[0]}};
	} elsif (@_ > 1) {
	    @_ = {map {$_,'1'} @_};
	}
	$self->$orig(@_);
    };
}



=item mergedwith

=item blocks

=item blocked_by

=cut

for my $field (qw(blocks blocked_by mergedwith)) {
    has '_'.$field =>
	(is => 'ro',
	 traits => ['Hash'],
	 isa => 'HashRef[Int]',
         builder =>
         sub {
             my $self = shift;
             if ($self->_has__status) {
                 my $s = $self->_status()->{$field};
                 if (!ref($s)) {
                     $s = _build_split_field($s,
                                             $field);
                 }
                 if (ref($s) ne 'HASH') {
                     $s = {map {$_,'1'} @{$s}};
                 }
                 return $s;
             }
             return {};
         },
	 writer => '_set_'.$field,
	 lazy => 1,
	);
    my $internal_field_method = $meta->find_method_by_name('_'.$field);
    die "No field method for _$field" unless defined $internal_field_method;
    $meta->add_method($field =>
		      sub {my $self = shift;
			   return sort {$a <=> $b}
			       keys %{$internal_field_method->($self)};
		       });
    my $field_method = $meta->find_method_by_name($field);
    die "No field method for _$field" unless defined $field_method;
    $meta->add_method('_'.$field.'_ref'=>
		      sub {my $self = shift;
			   return [$field_method->($self)]
		       });
}

for (qw(blocks blocked_by mergedwith)) {
    around '_set_'.$_ => sub {
	my $orig = shift;
	my $self = shift;
	if (defined ref($_[0]) and
	    ref($_[0]) eq 'ARRAY'
	   ) {
	    $_[0] = {map {$_,'1'} @{$_[0]}};
	} elsif (@_ > 1) {
	    @_ = {map {$_,'1'} @{$_[0]}};
	}
	$self->$orig(@_);
    };
}

=back

=cut

sub _build_split_field {
    sub sort_and_unique {
	my @v;
	my %u;
	my $all_numeric = 1;
	for my $v (@_) {
	    if ($all_numeric and $v =~ /\D/) {
		$all_numeric = 0;
	    }
	    next if exists $u{$v};
	    $u{$v} = 1;
	    push @v, $v;
	}
	if ($all_numeric) {
	    return sort {$a <=> $b} @v;
	} else {
	    return sort @v;
	}
    }
    sub split_ditch_empty {
	return grep {length $_} map {split ' '} @_;

    }
    my ($val,$field) = @_;
    $val //= '';

    if ($field =~ /^(package|affects|source)$/) {
	return [grep {length $_} map lc, split /[\s,()?]+/, $val];
    } else {
	return [sort_and_unique(split_ditch_empty($val))];
    }
}


__PACKAGE__->meta->make_immutable;

no Mouse;
no Mouse::Util::TypeConstraints;
1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
