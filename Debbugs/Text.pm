# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# Copyright 2007 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Text;

use warnings;
use strict;

=head1 NAME

Debbugs::Text -- General routines for text templates

=head1 SYNOPSIS

use Debbugs::Text qw(:templates);
print fill_in_template(template => 'cgi/foo');

=head1 DESCRIPTION

This module is a replacement for parts of common.pl; subroutines in
common.pl will be gradually phased out and replaced with equivalent
(or better) functionality here.

=head1 BUGS

None known.

=cut


use vars qw($DEBUG $VERSION @EXPORT_OK %EXPORT_TAGS @EXPORT @ISA);
use base qw(Exporter);

BEGIN {
     $VERSION = 1.00;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (templates => [qw(fill_in_template)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(qw(templates));
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

use Safe;
use Text::Template;

use Storable qw(dclone);

use Debbugs::Config qw(:config);

use Params::Validate qw(:types validate_with);
use Carp;
use IO::File;
use Data::Dumper;

=head2 fill_in_template

     print fill_in_template(template => 'template_name',
                            variables => \%variables,
                            language  => '..'
                           );

Reads a template from disk (if it hasn't already been read in) and
fills the template in.

=cut

our %tt_templates;
our %filled_templates;
our $safe;
our $language;
sub fill_in_template{
     my %param = validate_with(params => \@_,
			       spec   => {template => SCALAR|HANDLE|SCALARREF,
					  variables => {type => HASHREF,
						        default => {},
						       },
					  language  => {type => SCALAR,
							default => 'en_US',
						       },
					  output    => {type => HANDLE,
							optional => 1,
						       },
					  safe      => {type => OBJECT,
							optional => 1,
						       },
					 },
			      );
     return _fill_in_template(@param{qw(template variables language safe output)});
}


sub include {
     my $template = shift;
     $filled_templates{$template}++;
     print STDERR "include template $template language $language safe $safe\n" if $DEBUG;
     # Die if we're in a template loop
     die "Template loop with $template" if $filled_templates{$template} > 10;
     my $filled_tmpl;
     eval {
	  $filled_tmpl = Debbugs::Text::_fill_in_template($template,
							  {},
							  $language,
							  $safe,
							  undef,
							  1
							 );
     };
     if ($@) {
	  print STDERR "failed to fill template $template: $@";
     }
     print STDERR "failed to fill template $template\n" if $filled_tmpl eq '' and $DEBUG;
     print STDERR "template $template '$filled_tmpl'\n" if $DEBUG;
     $filled_templates{$template}--;
     return $filled_tmpl;
};

sub _fill_in_template{
     my %param;
     @param{qw(template variables language safe output nosafe)} = @_;
     print STDERR "_fill template $param{template} language $param{language} safe $param{safe}\n"
	  if $DEBUG;

     # Get the text
     my $tt_type = '';
     my $tt_source;
     if (ref($param{template}) eq 'GLOB' or
	 ref(\$param{template}) eq 'GLOB') {
	  $tt_type = 'FILE_HANDLE';
	  $tt_source = $param{template};
     }
     elsif (ref($param{template}) eq 'SCALAR') {
	  $tt_type = 'STRING';
	  $tt_source = ${$param{template}};
     }
     else {
	  $tt_type = 'FILE';
	  $tt_source = _locate_text($param{template},$param{language});
     }
     if (not defined $tt_source) {
	  die "Unable to find template $param{template} with language $param{language}";
     }

     if (defined $param{safe}) {
	  $safe = $param{safe};
     }
     else {
	  print STDERR "Created new safe\n" if $DEBUG;
	  $safe = Safe->new() or die "Unable to create safe compartment";
	  $safe->deny_only();
	  my @modules = ('Text::Template' => undef,
			 # This doesn't work yet; have to figure it out
			 #'Debbugs::Config' => [qw(:globals :config)],
			);
	  while (my ($module,$param) = splice (@modules,0,2)) {
	       print STDERR "Eval $module\n" if $DEBUG;
	       my $code = '';
	       if (not defined $param) {
		    $code = "use $module;";
	       }
	       else {
		    $code = "use $module ".(join(',',map {"q($_)"} @{$param})).';';
	       }
	       $safe->reval($code);
	       print STDERR "Error while attempting to eval '$code': $@" if $@;
	  }
	  $safe->permit_only(':base_core',':base_io',':base_mem',':base_loop',
			     qw(padsv padav padhv padany),
			     qw(rv2gv refgen srefgen ref),
			    );
	  $safe->share('$language','%tt_templates','$safe','$variables','%filled_templates');
	  $safe->share('*STDERR');
	  $safe->share('&_fill_in_template');
	  $safe->share('%config');
	  $safe->share('&include');
	  my $root = $safe->root();
	  # load variables into the safe
	  for my $key (keys %{$param{variables}||{}}) {
	       print STDERR "Loading $key\n" if $DEBUG;
	       if (ref($param{variables}{$key})) {
		    no strict 'refs';
		    print STDERR $safe->root().'::'.$key,qq(\n) if $DEBUG;
		    *{"${root}::$key"} = $param{variables}{$key};
	       }
	       else {
		    no strict 'refs';
		    ${"${root}::$key"} = $param{variables}{$key};
	       }
	  }
     }
     #$safe->deny_only();
     # perldoc Opcode; for details
     $language = $param{language};
     my $tt;
     if ($tt_type eq 'FILE' and
	 defined $tt_templates{$tt_source} and
	 (stat $tt_source)[9] > $tt_templates{$tt_source}{mtime}
	) {
	  $tt = $tt_templates{$tt_source}{template};
     }
     else {
	  if ($tt_type eq 'FILE') {
	       $tt_templates{$tt_source}{mtime} =
		    (stat $tt_source)[9];
	  }
	  $tt = Text::Template->new(TYPE => $tt_type,
				    SOURCE => $tt_source,
				   );
	  if ($tt_type eq 'FILE') {
	       $tt_templates{$tt_source}{template} = $tt;
	  }
     }
     if (not defined $tt) {
	  die "Unable to create Text::Template for $tt_type:$tt_source";
     }
     my $ret = $tt->fill_in(#(defined $param{nosafe} and $param{nosafe})?():(HASH=>$param{variables}),
			    (defined $param{nosafe} and $param{nosafe})?():(SAFE=>$safe),
			    #SAFE => $safe,
			    (defined $param{nosafe} and $param{nosafe})?(PACKAGE => 'main'):(),
			    defined $param{output}?(OUTPUT=>$param{output}):(),
			   );
     if (not defined $ret) {
	  print STDERR $Text::Template::ERROR;
	  return '';
     }
     if ($DEBUG) {
	  no strict 'refs';
	  no warnings 'uninitialized';
	  my $temp = $param{nosafe}?'main':$safe->{Root};
	  print STDERR "Variables for $param{template}\n";
	  print STDERR "Safe $temp\n";
	  print STDERR map {"$_:${$_}\n"} keys %{"${temp}::"};
	  print STDERR ${"${temp}::search_value"},qq(\n);
     }

     return $ret;
}

sub _locate_text{
     my ($template,$language) = @_;
     $template =~ s/\.tmpl$//g;
     # if a language doesn't exist, use the en_US template
     if (not -e $config{template_dir}.'/'.$language.'/'.$template.'.tmpl') {
	  $language = 'en_US';
     }
     my $loc = $config{template_dir}.'/'.$language.'/'.$template.'.tmpl';
     if (not -e $loc) {
	  print STDERR "Unable to locate template $loc\n";
	  return undef;
     }
     return $loc;
}

1;
