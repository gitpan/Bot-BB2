use POE::Session;
use POE::Wheel::Run;
use Data::Dumper qw/Dumper/;
use strict;

{
	code => sub {
		my( $self, $said, @args ) = @_;
		#$poe_kernel->stop();

		warn "PLUGIN-EVAL: @args\n";

		my $stdout;
		my $stderr;

		my $input_subref = sub { 
			my $code = "no strict; no warnings; ";
			$code .= "@args";
			my $ret = eval $code;

			if( ref $ret )
			{
				local $Data::Dumper::Terse = 1;
				local $Data::Dumper::Quotekeys = 0;
				local $Data::Dumper::Indent = 0;

				my $out = Dumper( $ret );
				print "$out\n";
			}
			else
			{
				print "$ret\n"; 
			}
			if( $@ ) { print "ERROR: $@\n" }
		};

		my $output_subref = sub {
			my( $stderr, $stdout ) = @_;
			
	#    print "OUTPUT-- $stdout $stderr\n";
			print +(substr $stdout,0,240)." ".(substr $stderr,0,250);
		};

		wheel_execute( $input_subref, $output_subref );

		warn "after declared session";



	}
};
