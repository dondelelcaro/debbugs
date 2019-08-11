package Debbugs::Mojo::Controller::Config;

use Mojo::Base 'Mojolicious::Controller';

use Debbugs::Config qw(config);

my %whitelist;

for (qw(tags distribution_aliases distributions),
     qw(tags_single_letter severity_list strong_severities),
     qw(severity_display project project_title),
     qw(web_domain email_domain),
    ) {
    $whitelist{$_} = 1;
}
sub show {
    my $c = shift;
    my $item = $c->stash('item');
    return $c->reply->not_found unless $whitelist{$item};
    my $m = config()->meta->find_method_by_name($item);
    return $c->reply->not_found unless defined $m;
    my $r = $m->(config());
    return $c->render(json => $r);
}

1;
