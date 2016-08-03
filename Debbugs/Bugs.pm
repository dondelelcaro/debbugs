# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# Copyright 2007 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Bugs;

=head1 NAME

Debbugs::Bugs -- Bug selection routines for debbugs

=head1 SYNOPSIS

use Debbugs::Bugs qw(get_bugs);


=head1 DESCRIPTION

This module is a replacement for all of the various methods of
selecting different types of bugs.

It implements a single function, get_bugs, which defines the master
interface for selecting bugs.

It attempts to use subsidiary functions to actually do the selection,
in the order specified in the configuration files. [Unless you're
insane, they should be in order from fastest (and often most
incomplete) to slowest (and most complete).]

=head1 BUGS

=head1 FUNCTIONS

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use Exporter qw(import);

BEGIN{
     $VERSION = 1.00;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = ();
     @EXPORT_OK = (qw(get_bugs count_bugs newest_bug bug_filter));
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

use Debbugs::Config qw(:config);
use Params::Validate qw(validate_with :types);
use IO::File;
use Debbugs::Status qw(splitpackages get_bug_status);
use Debbugs::Packages qw(getsrcpkgs getpkgsrc);
use Debbugs::Common qw(getparsedaddrs package_maintainer getmaintainers make_list);
use Fcntl qw(O_RDONLY);
use MLDBM qw(DB_File Storable);
use List::Util qw(first);
use Carp;

=head2 get_bugs

     get_bugs()

=head3 Parameters

The following parameters can either be a single scalar or a reference
to an array. The parameters are ANDed together, and the elements of
arrayrefs are a parameter are ORed. Future versions of this may allow
for limited regular expressions, and/or more complex expressions.

=over

=item package -- name of the binary package

=item src -- name of the source package

=item maint -- address of the maintainer

=item submitter -- address of the submitter

=item severity -- severity of the bug

=item status -- status of the bug

=item tag -- bug tags

=item owner -- owner of the bug

=item correspondent -- address of someone who sent mail to the log

=item affects -- bugs which affect this package

=item dist -- distribution (I don't know about this one yet)

=item bugs -- list of bugs to search within

=item function -- see description below

=back

=head3 Special options

The following options are special options used to modulate how the
searches are performed.

=over

=item archive -- whether to search archived bugs or normal bugs;
defaults to false. As a special case, if archive is 'both', but
archived and unarchived bugs are returned.

=item usertags -- set of usertags and the bugs they are applied to

=back


=head3 Subsidiary routines

All subsidiary routines get passed exactly the same set of options as
get_bugs. If for some reason they are unable to handle the options
passed (for example, they don't have the right type of index for the
type of selection) they should die as early as possible. [Using
Params::Validate and/or die when files don't exist makes this fairly
trivial.]

This function will then immediately move on to the next subroutine,
giving it the same arguments.

=head3 function

This option allows you to provide an arbitrary function which will be
given the information in the index.db file. This will be super, super
slow, so only do this if there's no other way to write the search.

You'll be given a list (which you can turn into a hash) like the
following:

 (pkg => ['a','b'], # may be a scalar (most common)
  bug => 1234,
  status => 'pending',
  submitter => 'boo@baz.com',
  severity => 'serious',
  tags => ['a','b','c'], # may be an empty arrayref
 )

The function should return 1 if the bug should be included; 0 if the
bug should not.

=cut

sub get_bugs{
     my %param = validate_with(params => \@_,
			       spec   => {package   => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  src       => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  maint     => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  submitter => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  severity  => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  status    => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  tag       => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  owner     => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  dist      => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  correspondent => {type => SCALAR|ARRAYREF,
							    optional => 1,
							   },
					  affects   => {type => SCALAR|ARRAYREF,
							optional => 1,
						       },
					  function  => {type => CODEREF,
							optional => 1,
						       },
					  bugs      => {type => SCALAR|ARRAYREF,
							optional => 1,
						       },
					  archive   => {type => BOOLEAN|SCALAR,
							default => 0,
						       },
					  usertags  => {type => HASHREF,
							optional => 1,
						       },
					 },
			      );

     # Normalize options
     my %options = %param;
     my @bugs;
     if ($options{archive} eq 'both') {
	  push @bugs, get_bugs(%options,archive=>0);
	  push @bugs, get_bugs(%options,archive=>1);
	  my %bugs;
	  @bugs{@bugs} = @bugs;
	  return keys %bugs;
     }
     # A configuration option will set an array that we'll use here instead.
     for my $routine (qw(Debbugs::Bugs::get_bugs_by_idx Debbugs::Bugs::get_bugs_flatfile)) {
	  my ($package) = $routine =~ m/^(.+)\:\:/;
	  eval "use $package;";
	  if ($@) {
	       # We output errors here because using an invalid function
	       # in the configuration file isn't something that should
	       # be done.
	       warn "use $package failed with $@";
	       next;
	  }
	  @bugs = eval "${routine}(\%options)";
	  if ($@) {

	       # We don't output errors here, because failure here
	       # via die may be a perfectly normal thing.
	       print STDERR "$@" if $DEBUG;
	       next;
	  }
	  last;
     }
     # If no one succeeded, die
     if ($@) {
	  die "$@";
     }
     return @bugs;
}

=head2 count_bugs

     count_bugs(function => sub {...})

Uses a subroutine to classify bugs into categories and return the
number of bugs which fall into those categories

=cut

sub count_bugs {
     my %param = validate_with(params => \@_,
			       spec   => {function => {type => CODEREF,
						      },
					  archive  => {type => BOOLEAN,
						       default => 0,
						      },
					 },
			      );
     my $flatfile;
     if ($param{archive}) {
	  $flatfile = IO::File->new("$config{spool_dir}/index.archive", 'r')
	       or die "Unable to open $config{spool_dir}/index.archive for reading: $!";
     }
     else {
	  $flatfile = IO::File->new("$config{spool_dir}/index.db", 'r')
	       or die "Unable to open $config{spool_dir}/index.db for reading: $!";
     }
     my %count = ();
     while(<$flatfile>) {
	  if (m/^(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+\[\s*([^]]*)\s*\]\s+(\w+)\s+(.*)$/) {
	       my @x = $param{function}->(pkg       => $1,
					  bug       => $2,
					  status    => $4,
					  submitter => $5,
					  severity  => $6,
					  tags      => $7,
					 );
	       local $_;
	       $count{$_}++ foreach @x;
	  }
     }
     close $flatfile;
     return %count;
}

=head2 newest_bug

     my $bug = newest_bug();

Returns the bug number of the newest bug, which is nextnumber-1.

=cut

sub newest_bug {
     my $nn_fh = IO::File->new("$config{spool_dir}/nextnumber",'r')
	  or die "Unable to open $config{spool_dir}nextnumber for reading: $!";
     local $/;
     my $next_number = <$nn_fh>;
     close $nn_fh;
     chomp $next_number;
     return $next_number-1;
}

=head2 bug_filter

     bug_filter

Allows filtering bugs on commonly used criteria



=cut

sub bug_filter {
     my %param = validate_with(params => \@_,
			       spec   => {bug    => {type => ARRAYREF|SCALAR,
						     optional => 1,
						    },
					  status => {type => HASHREF|ARRAYREF,
						     optional => 1,
						    },
					  seen_merged => {type => HASHREF,
							  optional => 1,
							 },
					  repeat_merged => {type => BOOLEAN,
							    default => 1,
							   },
					  include => {type => HASHREF,
						      optional => 1,
						     },
					  exclude => {type => HASHREF,
						      optional => 1,
						     },
					  min_days => {type => SCALAR,
						       optional => 1,
						      },
					  max_days => {type => SCALAR,
						       optional => 1,
						      },
					 },
			      );
     if (exists $param{repeat_merged} and
	 not $param{repeat_merged} and
	 not defined $param{seen_merged}) {
	  croak "repeat_merged false requires seen_merged to be passed";
     }
     if (not exists $param{bug} and not exists $param{status}) {
	 croak "one of bug or status must be passed";
     }

     if (not exists $param{status}) {
	  my $location = getbuglocation($param{bug}, 'summary');
	  return 0 if not defined $location or not length $location;
	  $param{status} = readbug( $param{bug}, $location );
	  return 0 if not defined $param{status};
     }

     if (exists $param{include}) {
	  return 1 if (!__bug_matches($param{include}, $param{status}));
     }
     if (exists $param{exclude}) {
	  return 1 if (__bug_matches($param{exclude}, $param{status}));
     }
     if (exists $param{repeat_merged} and not $param{repeat_merged}) {
	  my @merged = sort {$a<=>$b} $param{bug}, split(/ /, $param{status}{mergedwith});
	  return 1 if first {defined $_} @{$param{seen_merged}}{@merged};
	  @{$param{seen_merged}}{@merged} = (1) x @merged;
     }
     my $daysold = int((time - $param{status}{date}) / 86400);   # seconds to days
     if (exists $param{min_days}) {
	  return 1 unless $param{min_days} <= $daysold;
     }
     if (exists $param{max_days}) {
	  return 1 unless $param{max_days} == -1 or
	       $param{max_days} >= $daysold;
     }
     return 0;
}


=head2 get_bugs_by_idx

This routine uses the by-$index.idx indicies to try to speed up
searches.


=cut

sub get_bugs_by_idx{
     my %param = validate_with(params => \@_,
			       spec   => {package   => {type => SCALAR|ARRAYREF,
							optional => 1,
						       },
					  submitter => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  severity  => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  tag       => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  archive   => {type => BOOLEAN,
							default => 0,
						       },
					  owner     => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  src       => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  maint     => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  bugs      => {type => SCALAR|ARRAYREF,
							optional => 1,
						       },
					  correspondent => {type => SCALAR|ARRAYREF,
							    optional => 1,
							   },
					  affects => {type => SCALAR|ARRAYREF,
						      optional => 1,
						     },
					  usertags  => {type => HASHREF,
							optional => 1,
						       },
					 },
			      );
     my %bugs = ();

     # If we're given an empty maint (unmaintained packages), we can't
     # handle it, so bail out here
     for my $maint (make_list(exists $param{maint}?$param{maint}:[])) {
	  if (defined $maint and $maint eq '') {
	       die "Can't handle empty maint (unmaintained packages) in get_bugs_by_idx";
	  }
     }

     # We handle src packages, maint and maintenc by mapping to the
     # appropriate binary packages, then removing all packages which
     # don't match all queries
     my @packages = __handle_pkg_src_and_maint(map {exists $param{$_}?($_,$param{$_}):()}
					       qw(package src maint)
					      );
     if (exists $param{package} or
	 exists $param{src} or
	 exists $param{maint}) {
	  delete @param{qw(maint src)};
	  $param{package} = [@packages];
     }
     my $keys = grep {$_ !~ /^(archive|usertags|bugs)$/} keys(%param);
     die "Need at least 1 key to search by" unless $keys;
     my $arc = $param{archive} ? '-arc':'';
     my %idx;
     for my $key (grep {$_ !~ /^(archive|usertags|bugs)$/} keys %param) {
	  my $index = $key;
	  $index = 'submitter-email' if $key eq 'submitter';
	  $index = "$config{spool_dir}/by-${index}${arc}.idx";
	  tie(%idx, MLDBM => $index, O_RDONLY)
	       or die "Unable to open $index: $!";
	  my %bug_matching = ();
	  for my $search (make_list($param{$key})) {
	       for my $bug (keys %{$idx{$search}||{}}) {
		    next if $bug_matching{$bug};
		    # increment the number of searches that this bug matched
		    $bugs{$bug}++;
		    $bug_matching{$bug}=1;
	       }
	       if ($search ne lc($search)) {
		    for my $bug (keys %{$idx{lc($search)}||{}}) {
			 next if $bug_matching{$bug};
			 # increment the number of searches that this bug matched
			 $bugs{$bug}++;
			 $bug_matching{$bug}=1;
		    }
	       }
	  }
	  if ($key eq 'tag' and exists $param{usertags}) {
	       for my $bug (make_list(grep {defined $_ } @{$param{usertags}}{make_list($param{tag})})) {
		    next if $bug_matching{$bug};
		    $bugs{$bug}++;
		    $bug_matching{$bug}=1;
	       }
	  }
	  untie %idx or die 'Unable to untie %idx';
     }
     if ($param{bugs}) {
	  $keys++;
	  for my $bug (make_list($param{bugs})) {
	       $bugs{$bug}++;
	  }
     }
     # Throw out results that do not match all of the search specifications
     return map {$keys <= $bugs{$_}?($_):()} keys %bugs;
}


=head2 get_bugs_flatfile

This is the fallback search routine. It should be able to complete all
searches. [Or at least, that's the idea.]

=cut

sub get_bugs_flatfile{
     my %param = validate_with(params => \@_,
			       spec   => {package   => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  src       => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  maint     => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  submitter => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  severity  => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  status    => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  tag       => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
 					  owner     => {type => SCALAR|ARRAYREF,
 						        optional => 1,
 						       },
					  correspondent => {type => SCALAR|ARRAYREF,
							    optional => 1,
							   },
					  affects   => {type => SCALAR|ARRAYREF,
							optional => 1,
						       },
# not yet supported
# 					  dist      => {type => SCALAR|ARRAYREF,
# 						        optional => 1,
# 						       },
					  bugs      => {type => SCALAR|ARRAYREF,
							optional => 1,
						       },
					  archive   => {type => BOOLEAN,
							default => 1,
						       },
					  usertags  => {type => HASHREF,
							optional => 1,
						       },
					  function  => {type => CODEREF,
							optional => 1,
						       },
					 },
			      );
     my $flatfile;
     if ($param{archive}) {
	  $flatfile = IO::File->new("$config{spool_dir}/index.archive", 'r')
	       or die "Unable to open $config{spool_dir}/index.archive for reading: $!";
     }
     else {
	  $flatfile = IO::File->new("$config{spool_dir}/index.db", 'r')
	       or die "Unable to open $config{spool_dir}/index.db for reading: $!";
     }
     my %usertag_bugs;
     if (exists $param{tag} and exists $param{usertags}) {
	  # This complex slice makes a hash with the bugs which have the
          # usertags passed in $param{tag} set.
	  @usertag_bugs{make_list(@{$param{usertags}}{make_list($param{tag})})
			} = (1) x make_list(@{$param{usertags}}{make_list($param{tag})});
     }
     my $unmaintained_packages = 0;
     # unmaintained packages is a special case
     my @maints = make_list(exists $param{maint}?$param{maint}:[]);
     $param{maint} = [];
     for my $maint (@maints) {
	  if (defined $maint and $maint eq '' and not $unmaintained_packages) {
	       $unmaintained_packages = 1;
	       our %maintainers = %{getmaintainers()};
	       $param{function} = [(exists $param{function}?
				    (ref $param{function}?@{$param{function}}:$param{function}):()),
				   sub {my %d=@_;
					foreach my $try (make_list($d{"pkg"})) {
					     next unless length $try;
					     ($try) = $try =~ m/^(?:src:)?(.+)/;
					     return 1 if not exists $maintainers{$try};
					}
					return 0;
				   }
				  ];
	  }
	  elsif (defined $maint and $maint ne '') {
	       push @{$param{maint}},$maint;
	  }
     }
     # We handle src packages, maint and maintenc by mapping to the
     # appropriate binary packages, then removing all packages which
     # don't match all queries
     my @packages = __handle_pkg_src_and_maint(map {exists $param{$_}?($_,$param{$_}):()}
					       qw(package src maint)
					      );
     if (exists $param{package} or
	 exists $param{src} or
	 exists $param{maint}) {
	  delete @param{qw(maint src)};
	  $param{package} = [@packages] if @packages;
     }
     my $grep_bugs = 0;
     my %bugs;
     if (exists $param{bugs}) {
	  $bugs{$_} = 1 for make_list($param{bugs});
	  $grep_bugs = 1;
     }
     # These queries have to be handled by get_bugs_by_idx
     if (exists $param{owner}
	 or exists $param{correspondent}
	 or exists $param{affects}) {
	  $bugs{$_} = 1 for get_bugs_by_idx(map {exists $param{$_}?($_,$param{$_}):()}
					    qw(owner correspondent affects),
					   );
	  $grep_bugs = 1;
     }
     my @bugs;
     BUG: while (<$flatfile>) {
	  next unless m/^(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+\[\s*(.*)\s*\]\s+(\w+)\s+(.*)$/;
	  my ($pkg,$bug,$time,$status,$submitter,$severity,$tags) = ($1,$2,$3,$4,$5,$6,$7);
	  next if $grep_bugs and not exists $bugs{$bug};
	  if (exists $param{package}) {
	       my @packages = splitpackages($pkg);
	       next unless grep { my $pkg_list = $_;
				  grep {$pkg_list eq $_} make_list($param{package})
			     } @packages;
	  }
	  if (exists $param{src}) {
	       my @src_packages = map { getsrcpkgs($_)} make_list($param{src});
	       my @packages = splitpackages($pkg);
	       next unless grep { my $pkg_list = $_;
				  grep {$pkg_list eq $_} @packages
			     } @src_packages;
	  }
	  if (exists $param{submitter}) {
	       my @p_addrs = map {lc($_->address)}
		    map {getparsedaddrs($_)}
			 make_list($param{submitter});
	       my @f_addrs = map {$_->address}
		    getparsedaddrs($submitter||'');
	       next unless grep { my $f_addr = $_; 
				  grep {$f_addr eq $_} @p_addrs
			     } @f_addrs;
	  }
	  next if exists $param{severity} and not grep {$severity eq $_} make_list($param{severity});
	  next if exists $param{status} and not grep {$status eq $_} make_list($param{status});
	  if (exists $param{tag}) {
	       my $bug_ok = 0;
	       # either a normal tag, or a usertag must be set
	       $bug_ok = 1 if exists $param{usertags} and $usertag_bugs{$bug};
	       my @bug_tags = split ' ', $tags;
	       $bug_ok = 1 if grep {my $bug_tag = $_;
				    grep {$bug_tag eq $_} make_list($param{tag});
			       } @bug_tags;
	       next unless $bug_ok;
	  }
	  # We do this last, because a function may be slow...
	  if (exists $param{function}) {
	       my @bug_tags = split ' ', $tags;
	       my @packages = splitpackages($pkg);
	       my $package = (@packages > 1)?\@packages:$packages[0];
	       for my $function (make_list($param{function})) {
		    next BUG unless
			 $function->(pkg       => $package,
				     bug       => $bug,
				     status    => $status,
				     submitter => $submitter,
				     severity  => $severity,
				     tags      => \@bug_tags,
				    );
	       }
	  }
	  push @bugs, $bug;
     }
     return @bugs;
}

=head1 PRIVATE FUNCTIONS

=head2 __handle_pkg_src_and_maint

     my @packages = __handle_pkg_src_and_maint(map {exists $param{$_}?($_,$param{$_}):()}
					       qw(package src maint)
					      );

Turn package/src/maint into a list of packages

=cut

sub __handle_pkg_src_and_maint{
     my %param = validate_with(params => \@_,
			       spec   => {package   => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  src       => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					  maint     => {type => SCALAR|ARRAYREF,
						        optional => 1,
						       },
					 },
			       allow_extra => 1,
			      );

     my @packages;
     @packages = make_list($param{package}) if exists $param{package};
     my $package_keys = @packages?1:0;
     my %packages;
     @packages{@packages} = (1) x @packages;
     if (exists $param{src}) {
	  # We only want to increment the number of keys if there is
	  # something to match
	  my $key_inc = 0;
	  # in case there are binaries with the same name as the
	  # source
	  my %_temp_p = ();
	  for my $package ((map {getsrcpkgs($_)} make_list($param{src}))) {
	       $packages{$package}++ unless exists $_temp_p{$package};
	       $_temp_p{$package} = 1;
	       $key_inc=1;
	  }
	  for my $package (make_list($param{src})) {
	       $packages{"src:$package"}++ unless exists $_temp_p{"src:$package"};
	       $_temp_p{"src:$package"} = 1;
	       $key_inc=1;
	       # As a temporary hack, we will also include $param{src}
	       # in this list for packages passed which do not have a
	       # corresponding binary package
	       if (not exists getpkgsrc()->{$package}) {
		   $packages{$package}++ unless exists $_temp_p{$package};
		   $_temp_p{$package} = 1;
	       }
	  }
	  $package_keys += $key_inc;
     }
     if (exists $param{maint}) {
	  my $key_inc = 0;
	  my %_temp_p = ();
	  for my $package (package_maintainer(maintainer=>$param{maint})) {
	       $packages{$package}++ unless exists $_temp_p{$package};
	       $_temp_p{$package} = 1;
	       $key_inc = 1;
	  }
	  $package_keys += $key_inc;
     }
     return grep {$packages{$_} >= $package_keys} keys %packages;
}

my %field_match = (
    'subject' => \&__contains_field_match,
    'tags' => sub {
        my ($field, $values, $status) = @_; 
	my %values = map {$_=>1} @$values;
	foreach my $t (split /\s+/, $status->{$field}) {
            return 1 if (defined $values{$t});
        }
        return 0;
    },
    'severity' => \&__exact_field_match,
    'pending' => \&__exact_field_match,
    'package' => \&__exact_field_match,
    'originator' => \&__contains_field_match,
    'forwarded' => \&__contains_field_match,
    'owner' => \&__contains_field_match,
);

sub __bug_matches {
    my ($hash, $status) = @_;
    foreach my $key( keys( %$hash ) ) {
        my $value = $hash->{$key};
	next unless exists $field_match{$key};
	my $sub = $field_match{$key};
	if (not defined $sub) {
	    die "No defined subroutine for key: $key";
	}
	return 1 if ($sub->($key, $value, $status));
    }
    return 0;
}

sub __exact_field_match {
    my ($field, $values, $status) = @_; 
    my @values = @$values;
    my @ret = grep {$_ eq $status->{$field} } @values;
    $#ret != -1;
}

sub __contains_field_match {
    my ($field, $values, $status) = @_; 
    foreach my $data (@$values) {
        return 1 if (index($status->{$field}, $data) > -1);
    }
    return 0;
}





1;

__END__
