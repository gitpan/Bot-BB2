{
	code => sub {
		my( $self, $said, @args ) = @_;

		if( @args == 1 )
		{
			print scalar reverse $args[0];
		}
		else
		{
			print reverse @args;
		}
	}
}
