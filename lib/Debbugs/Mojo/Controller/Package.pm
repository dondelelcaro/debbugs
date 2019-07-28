package Debbugs::Mojo::Controller::Package;

use Mojo::Base 'Mojolicious::Controller';


sub show {
    my $c = shift;
    my $bug = $c->stash('bug');
    return $c->render(text => 'Bug '.$bug);
}

1;
