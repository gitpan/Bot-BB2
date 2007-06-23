use strict;
{
	code => sub {
		my( $self, $said ) = @_;

		print "Heap-: ", heap();
		print "Heap_value: ", ++(heap()->{test});
	},
}
