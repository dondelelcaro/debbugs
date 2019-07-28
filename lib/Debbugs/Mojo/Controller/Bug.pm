package Debbugs::Mojo::Controller::Bug;

use Mojo::Base 'Mojolicious::Controller';

use Debbugs::Bug;

sub show {
    my $c = shift;
    my $id = $c->stash('bug');
    my $bug = Debbugs::Bug->new(bug => $id,
				schema => $c->db
			       );
    
    return $c->render(text => 'Bug '.$bug->id);
}

1;
