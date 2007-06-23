use Lingua::ManagementSpeak;
{
	#code => sub {
	#	my $ms = Lingua::ManagementSpeak->new;
	#	
	#	my $ret = $ms->document;
	#	my $text;
	#	
	#	for (@$ret) {
	#		if ($_->{type} eq 'paragraph') {
	#			print $_->{text};
	#			last;
	#		}
	#	}
	#}
	code => sub {for(@{Lingua::ManagementSpeak->new->document}){$_->{type}eq'paragraph'&&(print($_->{text}),last);}}
}
