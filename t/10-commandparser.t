use Bot::BB2::CommandParser;
use Test::More qw/no_plan/;
my $cp = 'Bot::BB2::CommandParser';

is_deeply( $cp->parse("echo foo"), [ { command => 'echo', args => [ 'foo' ] } ] );
is_deeply( $cp->parse("echo"), [ { command => 'echo', args => [] } ] );
is_deeply( $cp->parse("echo foo | echo bar"), [ { command => 'echo', args => ['foo']} , '|', { command => 'echo', args => ['bar'] } ] );
is_deeply( $cp->parse('echo foo | test $(subc arg1 arg2)' ), [ { command => 'echo', args => ['foo'] }, '|', { command => 'test', args => [ [ { command => 'subc', args => [qw/arg1 arg2/] } ] ] } ] ); 

is_deeply( $cp->parse_subcommands('this is some text with $(the subcommand) in it and then occasionally I add $( subcommand 2) some times'),
[
	'this is some text with ',
		[
	{
		'args' => [
			'subcommand'
			],
		'command' => 'the'
	}
	],
		' in it and then occasionally I add ',
		[
	{
		'args' => [
			'2'
			],
		'command' => 'subcommand'
	}
	],
		' some times'
] );

is_deeply( $cp->parse_subcommands('this is some text with \\\\$(the subcommand) in it and then occasionally I add $( subcommand 2) some times'),
[
	'this is some text with \\\\',
		[
	{
		'args' => [
			'subcommand'
			],
		'command' => 'the'
	}
	],
		' in it and then occasionally I add ',
		[
	{
		'args' => [
			'2'
			],
		'command' => 'subcommand'
	}
	],
	' some times'
] );

