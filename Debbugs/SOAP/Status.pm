package Debbugs::SOAP::Status;

# This is a hack that must be removed
require '/home/don/projects/debbugs/source/cgi/common.pl';
#use Debbugs::Status qw(getbugstatus);

sub get_status {
    my ($class, @bugs) = @_;
    @bugs = map {ref($_)?@{$_}:$_} @bugs;

    my %s;
    foreach (@bugs) {
	my $hash = getbugstatus($_);
	if (scalar(%{$hash}) > 0) {
	    $s{$_} = $hash;
	}
    }
    
    return \%s;
}

1;
