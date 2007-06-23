use WWW::TV::Episode;
use WWW::TV::Series;

{
	code => sub {
		my $series = WWW::TV::Series->new(name => $_[2]);
		print $series->summary;
	}
}