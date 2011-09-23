#!/usr/bin/perl

use warnings;
use strict;

# Hack to work on bugs-search.debian.org
BEGIN{
     if ($ENV{HTTP_HOST} eq 'bugs-search.debian.org') {
	  unshift @INC, qw(/srv/bugs.debian.org/source/debian/);
	  $ENV{DEBBUGS_CONFIG_FILE}="/srv/bugs.debian.org/etc/config";
     }
}


use CGI::Simple;

# use CGI::Alert 'nobody@example.com';

use Search::Estraier;
use Debbugs::Config qw(:config);
use Debbugs::Estraier;
use Debbugs::CGI qw(htmlize_packagelinks html_escape cgi_parameters);
use HTML::Entities qw(encode_entities);

my $q = new CGI::Simple;

#my %var_defaults = (attr => 1,);

my %cgi_var = cgi_parameters(query => $q,
			     single => [qw(phrase max_results order_field order_operator),
				        qw(skip prev next),
				       ],
			     default => {phrase      => '',
					 max_results => 10,
					 skip        => 0,
					},
			    );

$cgi_var{attribute} = parse_attribute(\%cgi_var) || [];

my @results;

if (defined $cgi_var{next}) {
     $cgi_var{search} = 1;
     $cgi_var{skip} += $cgi_var{max_results};
}
elsif (defined $cgi_var{prev}) {
     $cgi_var{search} = 1;
     $cgi_var{skip} -= $cgi_var{max_results};
     $cgi_var{skip} = 0 if $cgi_var{skip} < 0;
}

my $nres;
if (defined $cgi_var{search} and length $cgi_var{phrase}) {
     # connect to a node if we need to
     my $node =  new Search::Estraier::Node (url    => $config{search_estraier}{url},
					     user   => $config{search_estraier}{user},
					     passwd => $config{search_estraier}{pass},
					     croak_on_error => 1,
					    ) or die "Unable to connect to the node";
     my $cond = new Search::Estraier::Condition;
     $cond->set_phrase($cgi_var{phrase});
     if (defined $cgi_var{order_field} and length $cgi_var{order_field} and
	 defined $cgi_var{order_operator} and length $cgi_var{order_operator}) {
	  $cond->set_order($cgi_var{order_field}.' '.$cgi_var{order_operator});
     }
     foreach my $attribute (@{$cgi_var{attribute}}) {
	  if (defined $$attribute{field} and defined $$attribute{value} and
	      defined $$attribute{operator} and length $$attribute{value}) {
	       $cond->add_attr(join(' ',map {$$attribute{$_}} qw(field operator value)));
	  }
     }
     $cond->set_skip($cgi_var{skip}) if defined $cgi_var{skip} and $cgi_var{skip} =~ /(\d+)/;
     $cond->set_max($cgi_var{max_results}) if defined $cgi_var{max_results} and $cgi_var{max_results} =~ /^\d+$/;
     print STDERR "skip: ".$cond->skip()."\n";
     print STDERR $node->cond_to_query($cond),qq(\n);
     $nres = $node->search($cond,0) or
	  die "Unable to search for condition";

}
elsif (defined $cgi_var{add_attribute} and length $cgi_var{add_attribute}) {
     push @{$cgi_var{attribute}}, {value => ''};
}
elsif (grep /^delete_attribute_\d+$/, keys %cgi_var) {
     foreach my $delete_key (sort {$b <=> $a} map {/^delete_attribute_(\d+)$/?($1):()} keys %cgi_var) {
	  splice @{$cgi_var{attribute}},$delete_key,1;
     }
}

my $url = 'http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=';

print <<END;
Content-Type: text/html


<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<HTML><HEAD><TITLE>BTS Search</TITLE>
<link rel="stylesheet" href="http://bugs.debian.org/css/bugs.css" type="text/css">
</HEAD>
<BODY>
<FORM>
<table class="forms">
<tr><td>
<p>Phrase: <input type="text" name="phrase" value="$cgi_var{phrase}" size="80" id="phrase" title="Input some words for full-text search" tabindex="1" accesskey="a" />
<input type="submit" name="search" value="search" title="Perform the search" tabindex="8" accesskey="f" />
<input type="hidden" name="skip" value="$cgi_var{skip}"></p>
END

# phrase
# attributes
# NUMEQ : is equal to the number or date
# NUMNE : is not equal to the number or date
# NUMGT : is greater than the number or date
# NUMGE : is greater than or equal to the number or date
# NUMLT : is less than the number or date
# NUMLE : is less than or equal to the number or date
# NUMBT : is between the two numbers or dates
my @num_operators = (NUMEQ => 'equal to',
		     NUMNE => 'not equal to',
		     NUMGT => 'greater than',
		     NUMGE => 'greater than or equal to',
		     NUMLT => 'less than',
		     NUMLE => 'less than or equal to',
		     NUMBT => 'between',
		    );

# STREQ : is equal to the string
# STRNE : is not equal to the string
# STRINC : includes the string
# STRBW : begins with the string
# STREW : ends with the string
# STRAND : includes all tokens in the string
# STROR : includes at least one token in the string
# STROREQ : is equal to at least one token in the string
# STRRX : matches regular expressions of the string
my @str_operators = (STREQ   => 'equal to',
		     STRNE   => 'not equal to',
		     STRINC  => 'includes',
		     STRBW   => 'begins with',
		     STREW   => 'ends with',
		     STRAND  => 'includes all tokens',
		     STROR   => 'includes at least one token',
		     STROREQ => 'is equal to at least one token',
		     STRRX   => 'matches regular expression',
		    );

my @attributes_order = ('@cdate','@title','@author',
			qw(status subject date submitter package tags severity),
		       );
my %attributes = ('@cdate'  => {name => 'Date',
				type      => 'num',
			       },
		  '@title'  => {name => 'Message subject',
				type      => 'str',
			       },
		  '@author' => {name => 'Author',
				type      => 'str',
			       },
		  status    => {name => 'Status',
				type      => 'str',
			       },
		  subject   => {name => 'Bug Title',
				type      => 'str',
			       },
		  date      => {name => 'Submission date',
				type      => 'num',
			       },
		  submitter => {name => 'Bug Submitter',
				type      => 'str',
			       },
		  package   => {name => 'Package',
				type      => 'str',
			       },
		  tags      => {name => 'Tags',
				type      => 'str',
			       },
		  severity  => {name => 'Severity',
				type      => 'str',
			       },
		 );
my $attr_num = 0;
print qq(<p>Attributes:</p>\n);
for my $attribute (@{$cgi_var{attribute}}) {
     print qq(<select name="attribute_field">\n);
     foreach my $attr (keys %attributes) {
	  my $selected = (defined $$attribute{field} and $$attribute{field} eq $attr) ? ' selected' : '';
	  print qq(<option value="$attr"$selected>$attributes{$attr}{name}</option>\n);
     }
     print qq(</select>\n);
     print qq(<select name="attribute_operator">\n);
     my $operator;
     my $name;
     my @tmp_array = (@num_operators,@str_operators);
     while (($operator,$name) = splice(@tmp_array,0,2)) {
	  my $type = $operator =~ /^NUM/ ? 'Number' : 'String';
	  my $selected = (defined $$attribute{operator} and $$attribute{operator} eq $operator) ? 'selected' : '';
	  print qq(<option value="$operator"$selected>$name ($type)</option>\n);
     }
     print qq(</select>\n);
     $$attribute{value}='' if not defined $$attribute{value};
     print qq(<input type="text" name="attribute_value" value="$$attribute{value}"><input type="submit" name="delete_attribute_$attr_num" value="Delete"><br>\n);
     $attr_num++;

}
print qq(<input type="submit" name="add_attribute" value="Add Attribute"><br>);

# order

# STRA : ascending by string
# STRD : descending by string
# NUMA : ascending by number or date
# NUMD : descending by number or date

my @order_operators = (STRA => 'ascending (string)',
		       STRD => 'descending (string)',
		       NUMA => 'ascending (number or date)',
		       NUMD => 'descending (number or date)',
		      );

print qq(<p>Order by: <select name="order_field">\n);
print qq(<option value="">Default</option>);
foreach my $attr (keys %attributes) {
     my $selected = (defined $cgi_var{order_field} and $cgi_var{order_field} eq $attr) ? ' selected' : '';
     print qq(<option value="$attr"$selected>$attributes{$attr}{name}</option>\n);
}
print qq(</select>\n);
print qq(<select name="order_operator">\n);
my $operator;
my $name;
my @tmp_array = (@order_operators);
while (($operator,$name) = splice(@tmp_array,0,2)) {
     my $selected = (defined $cgi_var{order_field} and $cgi_var{order_operator} eq $operator) ? ' selected' : '';
     print qq(<option value="$operator"$selected>$name</option>\n);
}
print qq(</select></p>\n);

# max results

print qq(<p>Max results: <select name="max_results">\n);
for my $max_results (qw(10 25 50 100 150 200)) {
     my $selected = (defined $cgi_var{max_results} and $cgi_var{max_results} eq $max_results) ? ' selected' : '';
     print qq(<option value="$max_results"$selected>$max_results</option>\n);
}
print qq(</select></p>\n);

print qq(</tr></table>\n);



if (defined $nres) {
     print "<h2> Results</h2>\n";
     my $hits = $nres->hits();
     print "<p>Hits: ".$hits;
     if (($cgi_var{skip} > 0)) {
	  print q(<input type="submit" name="prev" value="Prev">);
     }
     if ($hits > ($cgi_var{skip}+$cgi_var{max_results})) {
	  print q(<input type="submit" name="next" value="Next">);
     }
     print "</p>\n";
     print qq(<ul class="msgreceived">\n);
     for my $rdoc (map {$nres->get_doc($_)} 0.. ($nres->doc_num-1)) {
	  my ($bugnum,$msgnum) = split m#/#,$rdoc->attr('@uri');
	  my %attr = map {($_,$rdoc->attr($_))} $rdoc->attr_names;
	  # initialize any missing variables
	  for my $var ('@title','@author','@cdate','package','severity') {
	       $attr{$var} = '' if not defined $attr{$var};
	  }
	  my $showseverity;
	  $showseverity = "Severity: <em>$attr{severity}</em>;\n";
	  print <<END;
<li><a href="$url${bugnum}#${msgnum}">#${bugnum}: $attr{'@title'}</a> @{[htmlize_packagelinks($attr{package})]}<br>
$showseverity<br>
Sent by: @{[encode_entities($attr{'@author'})]} at $attr{'@cdate'}<br>
END
	  # Deal with the snippet
	  # make the things that match bits of the phrase bold, the rest normal.
	  my $snippet_mod = html_escape($attr{snippet});
	  $snippet_mod =~ s/\n\n/&nbsp;&nbsp;. . .&nbsp;&nbsp;/g;
	  for my $phrase_bits (split /\s+/,$cgi_var{phrase}) {
	       $snippet_mod =~ s{\n(\Q$phrase_bits\E)(?:\s+\Q$phrase_bits\E\n)}{'<b>'.$1.'</b>'}gei;
	  }
	  print "<p>$snippet_mod</p>\n";
     }
     print "</ul>\n<p>";
     if (($cgi_var{skip} > 0)) {
	  print q(<input type="submit" name="prev" value="Prev">);
     }
     if ($hits > ($cgi_var{skip}+$cgi_var{max_results})) {
	  print q(<input type="submit" name="next" value="Next">);
     }
     print "</p>\n";

}

print "</form>\n";

# This CGI should make an abstract method of displaying information
# about specific bugs and their messages; the information should be
# fairly similar to the way that pkgreport.cgi works, with the
# addition of snippit information and links to ajavapureapi/overview-summary.html specific message
# within the bug.

# For now we'll brute force the display, but methods to display a bug
# or a particular bug message should be made common between the two
# setups


sub parse_attribute {
     my ($cgi_var) = @_;

     my @attributes = ();
     if (ref $$cgi_var{attribute_operator}) {
	  for my $elem (0 ... $#{$$cgi_var{attribute_operator}}) {
	       push @attributes,{map {($_,$$cgi_var{"attribute_$_"}[$elem]);} qw(value field operator)};
	  }
     }
     elsif (defined $$cgi_var{attribute_operator}) {
	  push @attributes,{map {($_,$$cgi_var{"attribute_$_"});} qw(value field operator)};
     }
     return \@attributes;
}
