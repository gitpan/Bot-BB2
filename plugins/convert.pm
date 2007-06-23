{
	code => sub {
		my ($a, $f) = $_[2] =~ /^([\d.^-]+)(\S+)$/i;
		my $t = $_[4];

		for( $f, $t )
		{
			s{/h\s*$}{ per hour};
		}

		warn "units -- $f $t\n";
		open my $fh, '-|', 'units', '--', $f, $t or warn "CONVERT ERROR: $!";
		my @res = <$fh>;
		chomp @res;

		my $res = $res[0];
		$res =~ s{^\s*(?:\*|/)\s*}{};
		$res =~ s{\s*$}{};
		print (($res * $a) . $t);
	}
}
