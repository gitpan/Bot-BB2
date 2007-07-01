use B::Deparse;

{
	code => sub {
		my ($self, $said, @args) = @_;

		my $deparser = sub {
            my $code = join ' ', @args;
			my $sub = eval "no strict; no warnings; sub{ $code }";
			if( $@ ) { print "Error: $@\n"; return }

			my $dp = B::Deparse->new("-p");
			my $ret = $dp->coderef2text($sub);

			$ret =~ s/{//;
			$ret =~ s/package (?:\w+(?:::)?)+;//;
			$ret =~ s/ no warnings;//;
			$ret =~ s/\s+/ /g;
			$ret =~ s/\s*\}\s*$//;

			print $ret . "\n";
		};

		wheel_execute(sub { $deparser->(@args) }, sub { print @_ });
	}
}
