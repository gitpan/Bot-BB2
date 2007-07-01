use strict;
use JavaScript::SpiderMonkey;
use JSON qw/objToJson/;

my $pretty = sub {
	my $ch = shift;
	
	#return '\n' if $ch eq "\n";
	return '' if $ch eq "\n";
	return '\t' if $ch eq "\t";
	return '\0' if ord $ch == 0;
	return sprintf '\x%02x', ord $ch if ord $ch < 256;
	return sprintf '\x{%x}', ord $ch;
};

my $evaler = sub {
warn "JS EVALER ACTIVATE\n";
	my $js = JavaScript::SpiderMonkey->new;
	$js->init;
	$js->function_set(write => sub { print "@_\n"; });
	$js->function_set(print => sub { print "@_\n"; });
	
	my $ret = $js->eval(shift);
	
	if ($@) {
		print "Error: $@\n";
	} else {
		if (ref $ret) {
			print objToJson($ret);
		} elsif ($ret =~ /[^\x20-\x7e]/) {
			$ret =~ s/\\/\\\\/g;
			$ret =~ s/"/\"/g;
			$ret =~ s/([^\x20-\x7e])/$pretty->($1)/eg;
			print qq{"$ret"};
		} else {
			print "$ret\n";
		}
	}
};

{
	code => sub {
		my ($self, $said, @args) = @_;
		my $code = join ' ', @args;

		warn "JSEVAL: $code\n";
		
		wheel_execute(sub { $evaler->($code) }, 
			sub {
				my ($out, $err) = @_;
#        if( $err ) {
#          print "ERROR: ", substr($err, 0, 250);
#        }
#        else {
					print substr($out,0,250);
#        }
			}
		);
	}
}
