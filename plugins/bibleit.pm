use Storable;
my $ref = retrieve "bible.storable" or die $!;

{
	code => sub {
		my( $self, $said, @args ) = @_;

		print $ref->[ rand @$ref ];
	}
}
