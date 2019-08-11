package Debbugs::Mojo::Plugin::Xslate;

use Mojo::Base 'Mojolicious::Plugin';

use Debbugs::Text qw(:all);

sub register {
    my ($self,$app) = @_;

    my $xslate = sub {
	my ($renderer,$c,$output,$options) = @_;
	my $template = $c->stash->{template_name} ||
	    $renderer->template_name($options);
	my %params = (%{$c->stash},c => $c);
	$$output =
	    fill_in_template(template => $template,
			     variables => \%params,
			    );
    };
    $app->renderer->add_handler(tx => $xslate);
    return $self;
}


1;

