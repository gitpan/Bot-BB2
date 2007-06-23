use Lingua::EN::Squeeze;

my $squeezer = Lingua::EN::Squeeze->new;

{
	code => sub {
		my( $self, $said, @args ) = @_;
		my $arg = "@args";

		print $squeezer->SqueezeText( lc $arg );
	}
}
