package Bot::BB2::CommandParser;
use Parse::RecDescent;
#$::RD_TRACE=1;

my $grammar = do { local $/; <DATA> };
my $parser = Parse::RecDescent->new( $grammar );

sub parse
{
	my( $class, $line ) = @_;
	$parser->parse_line( $line );
}

sub parse_metachar_first
{
	my( $class, $line ) = @_;
	$parser->line2( $line );
}

sub parse_subcommands
{
	my( $class, $line ) = @_;

	my @parsed_line;

	#The preceding space ensures the [^\\] can always match.
	while( " $line" =~ /(?<=[^\\])(\\\\)*(\$)/ )
	{
		my $new_string = substr( $line, $-[2]-1 );
		my $old_str = substr( $line, 0, $-[2]-1 );
		push @parsed_line, $old_str;

		my $subc = $parser->subcommand( \$new_string );
		$line = $new_string;

		push @parsed_line, $subc;
	}
	push @parsed_line, $line;

	return \@parsed_line;
}

1

__DATA__
parse_line: line 
	{ $item[1] }
line: command line2(s?)
	{ [ $item[1], map @$_, @{$item[2]} ] }
line2: pipe_line | redirect
	{ [ $item[1], $item[2] ] }
pipe_line: pipe ( line | command )
	{ [ $item[1], @{$item[2]} ] }
command: function argument(s?)
	{ { command => $item[1], args => $item[2] } }
function: /\w+/ 
	{ $item[1] }
argument: greedy_args | subcommand | word
	{ $item[1] }
greedy_args: ':' /.+/
	{ $item[2] }
word: /[^|>) ]+/
	{ $item[1] }
pipe: '|'
	{ $item[1] }
redirect: '>' /\S+/
	{ [ $item[1], $item[2] ] }
subcommand: '$(' line ')'
	{ $item[2] }
