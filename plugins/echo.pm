{
	code => sub {
		my( $self, $said, @arguments ) = @_;

		warn "warn:@arguments\n";
		print "@arguments";
	},
};
