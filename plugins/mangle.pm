use Net::Dict;
{
	code => sub {
		my( $self, $said, @args ) = @_;
		my $dict = Net::Dict->new("dict.org");
		
		my $out;
		for( map { split /\s+/ } @args )
		{
			my $words = $dict->define( $_, 'moby-thes' );
			$words = $words->[0]->[1];
			$words =~ s/^.*\n//;
			my @words = split /\s*,\s*/, $words;
			if( @words )
			{
				$out .= " " . $words[rand@words];
			}
			else
			{
				$out .= " $_";
			}
		}
		print $out;

	},
}
