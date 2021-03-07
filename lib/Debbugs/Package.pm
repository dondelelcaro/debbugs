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

use Mouse;
use strictures 2;
use v5.10; # for state
use namespace::autoclean;

use List::AllUtils  qw(uniq pairmap);
use Debbugs::Config qw(:config);
use Debbugs::Version::Source;
use Debbugs::Version::Binary;

extends 'Debbugs::OOBase';

=head2 name

Name of the Package

=head2 qualified_name

name if binary, name prefixed with C<src:> if source

=cut

has name => (is => 'ro', isa => 'Str',
	     required => 1,
	    );

sub qualified_name {
    my $self = shift;
    return
	# src: if source, nothing if binary
	($self->_type eq 'source' ? 'src:':'') .
	$self->name;
}


=head2 type

Type of the package; either C<binary> or C<source>

=cut

has type => (is => 'bare', isa => 'Str',
	     lazy => 1,
	     builder => '_build_type',
	     clearer => '_clear_type',
	     reader => '_type',
	     writer => '_set_type',
	    );

sub _build_type {
    my $self = shift;
    if ($self->name !~ /^src:/) {
	return 'binary';
    }
}

=head2 url

url to the package

=cut

sub url {
    my $self = shift;
    return $config{web_domain}.'/'.$self->qualified_name;
}

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my %args;
    if (@_==1 and ref($_[0]) eq 'HASH') {
	%args = %{$_[0]};
    } else {
        %args = @_;
    }
    $args{name} //= '(unknown)';
    if ($args{name} =~ /src:(.+)/) {
	$args{name} = $1;
	$args{type} = 'source';
    } else {
	$args{type} = 'binary' unless
	    defined $args{type};
    }
    return $class->$orig(%args);
};

=head2 is_source

true if the package is a source package

=head2 is_binary

true if the package is a binary package

=cut

sub is_source {
    return $_[0]->_type eq 'source'
}

sub is_binary {
    return $_[0]->_type eq 'binary'
}

=head2 valid -- true if the package has any valid versions

=cut

has valid => (is => 'ro', isa => 'Bool',
	      lazy => 1,
	      builder => '_build_valid',
	      writer => '_set_valid',
	     );

sub _build_valid {
    my $self = shift;
    if ($self->valid_version_info_count> 0) {
	return 1;
    }
    return 0;
}

# this contains source name, source version, binary name, binary version, arch,
# and dist which have been selected from the database. It is used to build
# versions and anything else which are known as required.
has 'valid_version_info' =>
    (is => 'bare', isa => 'ArrayRef',
     traits => ['Array'],
     lazy => 1,
     builder => '_build_valid_version_info',
     predicate => '_has_valid_version_info',
     clearer => '_clear_valid_version_info',
     handles => {'_get_valid_version_info' => 'get',
		 'valid_version_info_grep' => 'grep',
		 '_valid_version_info' => 'elements',
                 'valid_version_info_count' => 'count',
		},
    );

sub _build_valid_version_info {
    my $self = shift;
    my $pkgs = $self->_get_valid_version_info_from_db;
    for my $invalid_version (@{$pkgs->{$self->qualified_name}->{invalid_versions}}) {
        $self->_mark_invalid_version($invalid_version,1);
    }
    return $pkgs->{$self->qualified_name}->{valid_version_info} // [];
}

state $common_dists = [@{$config{distributions}}];
sub _get_valid_version_info_from_db {
    my $self;
    if ((@_ % 2) == 1 and
	blessed($_[0])) {
	$self = shift;
    }
    my %args = @_;
    my @packages;
    my $s; # schema
    if (defined $self) {
	if ($self->has_schema) {
	    $s = $self->schema;
	} else {
	    $s = $args{schema};
	}
	@packages = $self->qualified_name;
    } else {
	$s = $args{schema};
	@packages = @{$args{packages}};
    }
    if (not defined $s) {
        # FIXME: Implement equivalent loader when there isn't a schema
	confess("get_info_from_db not implemented without schema");
    }
    my %src_packages;
    my %src_ver_packages;
    my %bin_packages;
    my %bin_ver_packages;
    # split packages into src/ver, bin/ver, src, and bin so we can select them
    # from the database
    local $_;
    for my $pkg (@packages) {
        if (ref($pkg)) {
            if ($pkg->[0] =~ /^src:(.+)$/) {
                for my $ver (@{$pkg}[1..$#{$pkg}]) {
                    $src_ver_packages{$1}{$ver} = 0;
                }
            } else {
                for my $ver (@{$pkg}[1..$#{$pkg}]) {
                    $bin_ver_packages{$pkg->[0]}{$ver} = 0;
                }
            }
        } elsif ($pkg =~ /^src:(.+)$/) {
            $src_packages{$1} = 0;
        } else {
            $bin_packages{$pkg} = 0;
        }
    }
    # calculate searches for packages where we want specific versions. We
    # calculate this here so add_result_to_package can stomp over
    # %src_ver_packages and %bin_ver_packages
    my @src_ver_search;
    for my $sp (keys %src_ver_packages) {
        push @src_ver_search,
            (-and => {'src_pkg.pkg' => $sp,
                      'me.ver' => [keys %{$src_ver_packages{$sp}}],
                     },
             );
    }
    my @src_packages = keys %src_packages;

    my @bin_ver_search;
    for my $sp (keys %bin_ver_packages) {
        push @bin_ver_search,
            (-and => {'bin_pkg.pkg' => $sp,
                      'me.ver' => [keys %{$bin_ver_packages{$sp}}],
                     },
             );
    }
    my @bin_packages = keys %bin_packages;
    my $packages = {};
    sub _default_pkg_info {
        return {name => $_[0],
                type => $_[1]//'source',
                valid => $_[2]//1,
                valid_version_info => [],
                invalid_versions => {},
               };
    }
    sub add_result_to_package {
	my ($pkgs,$rs,$svp,$bvp,$sp,$bp) = @_;
	while (my $pkg = $rs->next) {
	    my $n = 'src:'.$pkg->{src_pkg};
	    if (not exists $pkgs->{$n}) {
                $pkgs->{$n} =
                    _default_pkg_info($pkg->{src_pkg});
            }
            push @{$pkgs->{$n}{valid_version_info}},
               {%$pkg};
	    $n = $pkg->{bin_pkg};
            if (not exists $pkgs->{$n}) {
                $pkgs->{$n} =
                    _default_pkg_info($pkg->{bin_pkg},'binary');
            }
            push @{$pkgs->{$n}{valid_version_info}},
		   {%$pkg};
            # this is a package with a valid src_ver
            $svp->{$pkg->{src_pkg}}{$pkg->{src_ver}}++;
            $sp->{$pkg->{src_pkg}}++;
            # this is a package with a valid bin_ver
            $bvp->{$pkg->{bin_pkg}}{$pkg->{bin_ver}}++;
            $bp->{$pkg->{bin_pkg}}++;
	}
    }
    if (@src_packages) {
        my $src_rs = $s->resultset('SrcVer')->
            search({-or => [-and => {'src_pkg.pkg' => [@src_packages],
                                     -or => {'suite.codename' => $common_dists,
                                             'suite.suite_name' => $common_dists,
                                            },
                                    },
                            @src_ver_search,
                           ],
                   },
                  {join => ['src_pkg',
                           {
                            'src_associations' => 'suite'},
                           {
                            'bin_vers' => ['bin_pkg','arch']},
                            'maintainer',
                           ],
                   'select' => [qw(src_pkg.pkg),
                                qw(suite.codename),
                                qw(suite.suite_name),
                                qw(src_associations.modified),
                                qw(me.ver),
                                q(CONCAT(src_pkg.pkg,'/',me.ver)),
                                qw(bin_vers.ver bin_pkg.pkg arch.arch),
                                qw(maintainer.name),
                               ],
                   'as' => [qw(src_pkg codename suite_name),
                            qw(modified_time src_ver src_pkg_ver),
                            qw(bin_ver bin_pkg arch maintainer),
                           ],
                   result_class => 'DBIx::Class::ResultClass::HashRefInflator',
                  },
                  );
        add_result_to_package($packages,$src_rs,
                              \%src_ver_packages,
                              \%bin_ver_packages,
                              \%src_packages,
                              \%bin_packages,
                             );
    }
    if (@bin_packages) {
        my $bin_assoc_rs =
            $s->resultset('BinAssociation')->
            search({-and => {'bin_pkg.pkg' => [@bin_packages],
                             -or => {'suite.codename' => $common_dists,
                                     'suite.suite_name' => $common_dists,
                                    },
                            }},
                  {join => [{'bin' =>
                             [{'src_ver' => ['src_pkg',
                                             'maintainer',
                                            ]},
                              'bin_pkg',
                              'arch']},
                            'suite',
                           ],
                   'select' => [qw(src_pkg.pkg),
                                qw(suite.codename),
                                qw(suite.suite_name),
                                qw(me.modified),
                                qw(src_ver.ver),
                                q(CONCAT(src_pkg.pkg,'/',src_ver.ver)),
                                qw(bin.ver bin_pkg.pkg arch.arch),
                                qw(maintainer.name),
                               ],
                   'as' => [qw(src_pkg codename suite_name),
                            qw(modified_time src_ver src_pkg_ver),
                            qw(bin_ver bin_pkg arch maintainer),
                           ],
                   result_class => 'DBIx::Class::ResultClass::HashRefInflator',
                  },
                  );
        add_result_to_package($packages,$bin_assoc_rs,
                              \%src_ver_packages,
                              \%bin_ver_packages,
                              \%src_packages,
                              \%bin_packages,
                             );
    }
    if (@bin_ver_search) {
        my $bin_rs = $s->resultset('BinVer')->
            search({-or => [@bin_ver_search,
                           ],
                   },
                  {join => ['bin_pkg',
                           {
                            'bin_associations' => 'suite'},
                           {'src_ver' => ['src_pkg',
                                          'maintainer',
                                         ]},
                            'arch',
                           ],
                   'select' => [qw(src_pkg.pkg),
                                qw(suite.codename),
                                qw(suite.suite_name),
                                qw(bin_associations.modified),
                                qw(src_ver.ver),
                                q(CONCAT(src_pkg.pkg,'/',src_ver.ver)),
                                qw(me.ver bin_pkg.pkg arch.arch),
                                qw(maintainer.name),
                               ],
                   'as' => [qw(src_pkg codename suite_name),
                            qw(modified_time src_ver src_pkg_ver),
                            qw(bin_ver bin_pkg arch maintainer),
                           ],
                   result_class => 'DBIx::Class::ResultClass::HashRefInflator',
                  },
                  );
        add_result_to_package($packages,$bin_rs,
                              \%src_ver_packages,
                              \%bin_ver_packages,
                              \%src_packages,
                              \%bin_packages,
                             );
    }
    for my $sp (keys %src_ver_packages) {
        if (not exists $packages->{'src:'.$sp}) {
            $packages->{'src:'.$sp} =
                _default_pkg_info($sp,'source',0);
        }
        for my $sv (keys %{$src_ver_packages{$sp}}) {
            next if $src_ver_packages{$sp}{$sv} > 0;
            $packages->{'src:'.$sp}{invalid_versions}{$sv} = 1;
        }
    }
    for my $bp (keys %bin_ver_packages) {
        if (not exists $packages->{$bp}) {
            $packages->{$bp} =
                _default_pkg_info($bp,'binary',0);
        }
        for my $bv (keys %{$bin_ver_packages{$bp}}) {
            next if $bin_ver_packages{$bp}{$bv} > 0;
            $packages->{$bp}{invalid_versions}{$bv} = 1;
        }
    }
    for my $sp (keys %src_packages) {
        next if $src_packages{$sp} > 0;
        $packages->{'src:'.$sp} =
            _default_pkg_info($sp,'source',0);
    }
    for my $bp (keys %bin_packages) {
        next if $bin_packages{$bp} > 0;
        $packages->{$bp} =
            _default_pkg_info($bp,'binary',0);
    }
    return $packages;
}

has 'source_version_to_info' =>
    (is => 'bare', isa => 'HashRef',
     traits => ['Hash'],
     lazy => 1,
     builder => '_build_source_version_to_info',
     handles => {_get_source_version_to_info => 'get',
		},
    );

sub _build_source_version_to_info {
    my $self = shift;
    my $info = {};
    my $i = 0;
    for my $v ($self->_valid_version_info) {
	push @{$info->{$v->{src_ver}}}, $i;
	$i++;
    }
    return $info;
}

has 'binary_version_to_info' =>
    (is => 'bare', isa => 'HashRef',
     traits => ['Hash'],
     lazy => 1,
     builder => '_build_binary_version_to_info',
     handles => {_get_binary_version_to_info => 'get',
		},
    );

sub _build_binary_version_to_info {
    my $self = shift;
    my $info = {};
    my $i = 0;
    for my $v ($self->_valid_version_info) {
	push @{$info->{$v->{bin_ver}}}, $i;
	$i++;
    }
    return $info;
}

has 'dist_to_info' =>
    (is => 'bare', isa => 'HashRef',
     traits => ['Hash'],
     lazy => 1,
     builder => '_build_dist_to_info',
     handles => {_get_dist_to_info => 'get',
		},
    );
sub _build_dist_to_info {
    my $self = shift;
    my $info = {};
    my $i = 0;
    for my $v ($self->_valid_version_info) {
        next unless defined $v->{suite_name} and length($v->{suite_name});
	push @{$info->{$v->{suite_name}}}, $i;
	$i++;
    }
    return $info;
}

# this is a hashref of versions that we know are invalid
has 'invalid_versions' =>
    (is => 'bare',isa => 'HashRef[Bool]',
     lazy => 1,
     default => sub {{}},
     clearer => '_clear_invalid_versions',
     traits => ['Hash'],
     handles => {_invalid_version => 'exists',
                 _mark_invalid_version => 'set',
                },
    );

has 'binaries' => (is => 'ro',
		   isa => 'Debbugs::Collection::Package',
		   lazy => 1,
		   builder => '_build_binaries',
		   predicate => '_has_binaries',
		  );

sub _build_binaries {
    my $self = shift;
    if ($self->is_binary) {
	return $self->package_collection->limit($self->name);
    }
    # OK, walk through the valid_versions for this package
    my @binaries =
	uniq map {$_->{bin_pkg}} $self->_valid_version_info;
    return $self->package_collection->limit(@binaries);
}

has 'sources' => (is => 'ro',
		  isa => 'Debbugs::Collection::Package',
		  lazy => 1,
		  builder => '_build_sources',
		  predicate => '_has_sources',
		 );

sub _build_sources {
    my $self = shift;
    return $self->package_collection->limit($self->source_names);
}

sub source_names {
    my $self = shift;

    if ($self->is_source) {
        return $self->name
    }
    return uniq map {'src:'.$_->{src_pkg}} $self->_valid_version_info;
}

=head2 maintainers 

L<Debbugs::Collection::Correspondent> of the maintainer(s) of the current package

=cut

has maintainers => (is => 'ro',
                    isa => 'Debbugs::Collection::Correspondent',
                    lazy => 1,
                    builder => '_build_maintainers',
                    predicate => '_has_maintainers',
                   );

sub _build_maintainers {
    my $self = shift;
    my @maintainers;
    for my $v ($self->_valid_version_info) {
        next unless length($v->{suite_name}) and length($v->{maintainer});
        push @maintainers,$v->{maintainer};
    }
    @maintainers =
        uniq @maintainers;
    return $self->correspondent_collection->limit(@maintainers);
}

has 'versions' => (is => 'bare',
		   isa => 'HashRef[Debbugs::Version]',
                   traits => ['Hash'],
		   handles => {_exists_version => 'exists',
			       _get_version => 'get',
                               _set_version => 'set',
			      },
                   lazy => 1,
                   builder => '_build_versions',
		  );

sub _build_versions {
    my $self = shift;
    return {};
}

sub _add_version {
    my $self = shift;
    my @set;
    for my $v (@_) {
        push @set,
            $v->version,$v;
    }
    $self->_set_version(@set);
}

sub get_source_version_distribution {
    my $self = shift;

    my %src_pkg_vers = @_;
    for my $dist (@_) {
        my @ver_loc =
            grep {defined $_}
            $self->_get_dist_to_info($dist);
        for my $v ($self->
                   _get_valid_version_info(@ver_loc)) {
            $src_pkg_vers{$v->{src_pkg_ver}} = 1;
        }
    }
    return $self->package_collection->
        get_source_versions(keys %src_pkg_vers)->members;
}

# returns the source version(s) corresponding to the version of *this* package; the
# version passed may be binary or source, depending.
sub get_source_version {
    my $self = shift;
    if ($self->is_source) {
        return $self->get_version(@_);
    }
    my %src_pkg_vers;
    for my $ver (@_) {
        my %archs;
        if (ref $ver) {
            my @archs;
            ($ver,@archs) = @{$ver};
            @archs{@archs} = (1) x @archs;
        }
        my @ver_loc =
            @{$self->_get_binary_version_to_info($ver)//[]};
        next unless @ver_loc;
        my @vers = map {$self->
                            _get_valid_version_info($_)}
            @ver_loc;
        for my $v (@vers) {
            if (keys %archs) {
                next unless exists $archs{$v->{arch}};
            }
            $src_pkg_vers{$v->{src_pkg_ver}} = 1;
        }
    }
    return $self->package_collection->
        get_source_versions(keys %src_pkg_vers)->members;
}

sub get_version {
    my $self = shift;
    my @ret;
    for my $v (@_) {
	if ($self->_exists_version($v)) {
	    push @ret,$self->_get_version($v);
	} else {
	    push @ret,
		$self->_create_version($v);
	}
    }
    return @ret;
}

sub _create_version {
    my $self = shift;
    my @versions;
    if ($self->is_source) {
	for my $v (@_) {
	    push @versions,
		$v,
		Debbugs::Version::Source->
		    new(pkg => $self,
			version => $v,
			package_collection => $self->package_collection,
                        $self->schema_argument,
		       );
	}
    } else {
	for my $v (@_) {
	    push @versions,
		$v,
		Debbugs::Version::Binary->
		    new(pkg => $self,
			version => $v,
			package_collection => $self->package_collection,
                        $self->schema_argument,
		       );
	}
    }
    $self->_set_version(@versions);
}

=head2 package_collection

L<Debbugs::Collection::Package> to get additional packages required

=cut

# gets used to retrieve packages
has 'package_collection' => (is => 'ro',
			     isa => 'Debbugs::Collection::Package',
			     builder => '_build_package_collection',
			     lazy => 1,
			    );

sub _build_package_collection {
    my $self = shift;
    return Debbugs::Collection::Package->new($self->schema_argument)
}

=head2 correspondent_collection

L<Debbugs::Collection::Correspondent> to get additional maintainers required

=cut

has 'correspondent_collection' => (is => 'ro',
                                   isa => 'Debbugs::Collection::Correspondent',
                                   builder => '_build_correspondent_collection',
                                   lazy => 1,
                                  );

sub _build_correspondent_collection {
    my $self = shift;
    return Debbugs::Collection::Correspondent->new($self->schema_argument)
}

sub CARP_TRACE {
    my $self = shift;
    return 'Debbugs::Package={package='.$self->qualified_name.'}';
}

__PACKAGE__->meta->make_immutable;
no Mouse;

1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
