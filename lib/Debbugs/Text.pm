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
use Exporter qw(import);

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

use Text::Xslate qw(html_builder);

use Storable qw(dclone);

use Debbugs::Config qw(:config);

use Params::Validate qw(:types validate_with);
use Carp;
use IO::File;
use Data::Dumper;

### for %text_xslate_functions
use POSIX;
use Debbugs::CGI qw(html_escape);
use Scalar::Util;
use Debbugs::Common qw(make_list);
use Debbugs::Status;

our %tt_templates;
our %filled_templates;
our $language;


sub __output_select_options {
    my ($options,$value) = @_;
    my @options = @{$options};
    my $output = '';
    while (@options) {
	my ($o_value) = shift @options;
	if (ref($o_value)) {
	    for (@{$o_value}) {
		unshift @options,
		    ($_,$_);
	    }
	    next;
	}
	my $name = shift @options;
	my $selected = '';
	if (defined $value and $o_value eq $value) {
	    $selected = ' selected';
	}
	$output .= q(<option value=").html_escape($o_value).qq("$selected>).
	    html_escape($name).qq(</option>\n);
    }
    return $output;
}

sub __text_xslate_functions {
    return
	{gm_strftime => sub {POSIX::strftime($_[0],gmtime)},
	 package_links => html_builder(\&Debbugs::CGI::package_links),
	 bug_links => html_builder(\&Debbugs::CGI::bug_links),
	 looks_like_number => \&Scalar::Util::looks_like_number,
	 isstrongseverity => \&Debbugs::Status::isstrongseverity,
	 secs_to_english => \&Debbugs::Common::secs_to_english,
	 maybelink => \&Debbugs::CGI::maybelink,
	 # add in a few utility routines
	 duplicate_array =>  sub {
	     my @r = map {($_,$_)} make_list(@{$_[0]});
	     return @r;
	 },
	 output_select_options => html_builder(\&__output_select_options),
	 make_list => \&make_list,
	};
}
sub __text_xslate_functions_text {
    return
       {bugurl =>
	sub{
	    return "$_[0]: ".
		$config{cgi_domain}.'/'.
		Debbugs::CGI::bug_links(bug=>$_[0],
					links_only => 1,
				       );
	},
       };
}



### this function removes leading spaces from line-start code strings and spaces
### before <:- and spaces after -:>
sub __html_template_prefilter {
    my $text = shift;
    $text =~ s/^\s+:/:/mg;
    $text =~ s/((?:^:[^\n]*\n)?)\s*(<:-)/$1$2/mg;
    $text =~ s/(-:>)\s+(^:|)/$1.(length($2)?"\n$2":'')/emg;
    return $text;
}


=head2 fill_in_template

     print fill_in_template(template => 'template_name',
                            variables => \%variables,
                            language  => '..'
                           );

Reads a template from disk (if it hasn't already been read in) andf
ills the template in.

=cut

sub fill_in_template{
     my %param = validate_with(params => \@_,
			       spec   => {template => SCALAR,
					  variables => {type => HASHREF,
						        default => {},
						       },
					  language  => {type => SCALAR,
							default => 'en_US',
						       },
					  output    => {type => HANDLE,
							optional => 1,
						       },
					  hole_var  => {type => HASHREF,
							optional => 1,
						       },
					  output_type => {type => SCALAR,
							  default => 'html',
							 },
					 },
			      );
     # Get the text
     my $output_type = $param{output_type};
     my $language = $param{language};
     my $template = $param{template};
     $template .= '.tx' unless $template =~ /\.tx$/;
     my $tt;
     if (not exists $tt_templates{$output_type}{$language} or
	 not defined $tt_templates{$output_type}{$language}
	) {
	 $tt_templates{$output_type}{$language} =
	     Text::Xslate->new(# cache in template_cache or temp directory
			       cache_dir => $config{template_cache} //
			       File::Temp::tempdir(CLEANUP => 1),
			       # default to the language, but fallback to en_US
			       path => [$config{template_dir}.'/'.$language.'/',
					$config{template_dir}.'/en_US/',
				       ],
			       suffix => '.tx',
			       ## use html or text specific functions
			       function =>
			       ($output_type eq 'html' ? __text_xslate_functions() :
				__text_xslate_functions_text()),
			       syntax => 'Kolon',
			       module => ['Text::Xslate::Bridge::Star',
					  'Debbugs::Text::XslateBridge',
					 ],
			       type   => $output_type,
			       ## use the html-specific pre_process_handler
			       $output_type eq 'html'?
			       (pre_process_handler => \&__html_template_prefilter):(),
			      )
		 or die "Unable to create Text::Xslate";
     }
     $tt = $tt_templates{$output_type}{$language};
     my $ret =
	 $tt->render($template,
		    {time => time,
		     %{$param{variables}//{}},
		     config  => \%config,
		    });
     if (exists $param{output}) {
	 print {$param{output}} $ret;
	 return '';
     }
     return $ret;
}

1;
