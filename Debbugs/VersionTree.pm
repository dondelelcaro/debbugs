# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::VersionTree;

=head1 NAME

Debbugs::VersionTree -- OO interface to Debbugs::Versions

=head1 SYNOPSIS

   use Debbugs::VersionTree;
   my $vt = Debbugs::VersionTree->new();

=head1 DESCRIPTION



=cut

use Mouse;
use v5.10;
use strictures 2;
use namespace::autoclean;

use Debbugs::Config qw(:config);
use Debbugs::Versions;
use Carp;

extends 'Debbugs::OOBase';

has _versions => (is => 'bare',
		  isa => 'Debbugs::Versions',
		  default => sub {Debbugs::Versions->new(\&Debbugs::Versions::Dpkg::vercmp)},
		  handles => {_isancestor => 'isancestor',
			      _load => 'load',
			      _buggy => 'buggy',
			      _allstates => 'allstates',
			     },
		 );

has loaded_src_pkg => (is => 'bare',
		     isa => 'HashRef[Bool]',
		     default => sub {{}},
		     traits => ['Hash'],
		     handles => {src_pkg_loaded => 'exists',
				 _set_src_pkg_loaded => 'set',
				},
		    );

sub _srcify_version {
    my @return;
    for my $v (@_) {
	if (ref($_)) {
	    push @return,
		$v->source_version->src_pkg_ver;
	} else {
	    push @return,
		$v;
	}
    }
    return @_ > 1?@return:$return[0];
}

sub isancestor {
    my ($self,$ancestor,$descendant) = @_;
    return $self->_isancestor(_srcify_version($ancestor),
			      _srcify_version($descendant),
			     );
}

sub buggy {
    my $self = shift;
    my ($version,$found,$fixed) = @_;
    ($version) = _srcify_version($version);
    $found = [_srcify_version(@{$found})];
    $fixed = [_srcify_version(@{$fixed})];
    return $self->_buggy($version,$found,$fixed);
}

sub allstates {
    my $self = shift;
    my $found = shift;
    my $fixed = shift;
    my $interested = shift;
    return $self->_allstates([_srcify_version(@{$found})],
			     [_srcify_version(@{$fixed})],
			     [_srcify_version(@{$interested})],
			    );
}

sub load {
    my $self = shift;
    for my $src_pkg (@_) {
	my $is_valid = 0;
	if (ref($src_pkg)) {
	    $is_valid = $src_pkg->valid;
	    $src_pkg = $src_pkg->name;
	}
	next if $self->src_pkg_loaded($src_pkg);
	my $srchash = substr $src_pkg, 0, 1;
	my $version_fh;
	open($version_fh,'<',"$config{version_packages_dir}/$srchash/$src_pkg");
	if (not defined $version_fh) {
	    carp "No version file for package $src_pkg" if $is_valid;
	    next;
	}
	$self->_load($version_fh);
	$self->_set_src_pkg_loaded($src_pkg,1);
    }
}

__PACKAGE__->meta->make_immutable;
no Mouse;
1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
