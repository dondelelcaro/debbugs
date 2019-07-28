package Debbugs::Mojo::Controller;

use Mojo::Base 'Mojolicious::Controller';


sub bug {
    my $c = shift;
    my $bug = $c->stash('bug');
    return $c->render(text => 'Bug '.$bug);
}

1;
