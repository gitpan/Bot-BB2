use RottenTomatoes;
{
	code => sub {
		my( $self, $said, @args ) = @_;

		my $title = "@args";
		my( $rating, $blurb ) = RottenTomatoes->rating_and_blurb( $title );

		print "$rating -- $blurb";
	}
}
