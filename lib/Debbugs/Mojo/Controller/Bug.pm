package Debbugs::Mojo::Controller::Bug;

use Mojo::Base 'Mojolicious::Controller';

use Debbugs::Bug;

sub show {
    my $c = shift;
    my $id = $c->stash('bug');
    my $bug = Debbugs::Bug->new(bug => $id,
				schema => $c->db
			       );
    return $c->reply->not_found if not $bug->exists;
    $c->respond_to(json => {json => $bug->structure},
		   any => sub {$c->render(template => 'cgi/bugreport',
					  handler => 'tx',
					  bug => $bug)},
		  );

}

1;
