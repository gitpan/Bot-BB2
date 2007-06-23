package Bot::BB2;
use POE;
use POE::Session;
use POE::Component::IRC::State;
use POE::Component::IRC::Plugin::Connector;
use POE::Wheel::Run;
use POE::Filter::Reference;
use Text::ParseWords qw/shellwords/;
use Scalar::Util qw/weaken/;
use Symbol qw/gensym/;
use IPC::Shareable;
use BSD::Resource;
use Symbol qw/delete_package/;
use DB_File;
use Text::Glob qw/match_glob/;
use Time::HiRes qw/gettimeofday/;
use Text::Wrap qw/wrap/;
use Log::Log4perl qw/get_logger/;
use File::Spec::Functions 'catdir';
use strict;

use Bot::BB2::TiedPluginHandle;
use Bot::BB2::CommandParser;

use Data::Dumper;

my $DAEMON_PORT = 12501;

$SIG{__WARN__} = sub { warn "$$: @_" };
$SIG{__DIE__} = sub { die "$$: @_" };

my @BOTLIST;

{
    my $started;
    sub init_logger
    {
        return if $started;
        Log::Log4perl::init_and_watch( 'logger.conf', 20 );
        $started = 1;
    }
}

sub new
{
    init_logger();
	my $class = shift;
	my( $confs, $plugins ) = @_;

	my $self = bless {}, $class;
	

	for my $options ( @$confs )
	{
		my $nick = $options->{nick} || $options->{botname};
		die "Error, no defined nickname for bot $options->{botname}" unless defined $nick;
		my $username = $options->{username} || $nick;
		my $server = $options->{server};
		die "Error, no defined server for bot $options->{botname}" unless defined $server;
		my $port = $options->{port} || 6667;

		my %opts = (
			nick    => $nick,
			server  => $server,
			ircname => $username || $nick,
			port    => $port,
		);
		
		warn "Attempting to create poco-irc: ", Dumper \%opts;

		my $irc = POE::Component::IRC::State->spawn(
			%opts,
#      Debug => 1,
		);

		$self->{irc_objs}->{$irc->session_id} = { 
			irc => $irc, 
			irc_opts => \%opts,
			conf => $options,
		};

		my $channels = $options->{channel};

		$self->join_channels( $irc, ref $channels ? @$channels : $channels );
		$self->ignore( $_ ) for ref $options->{ignore} ? @{ $options->{ignore} } : $options->{ignore};
	}


	$self->{plugin_conf} = $plugins;
	$self->{_daemon_port} = $DAEMON_PORT;

	$self->{session} = POE::Session->create(
		object_states => [
			$self => [ qw/_start _default
				irc_001 irc_public irc_msg irc_notice
				command_stdout command_stderr command_close command_error
				daemon_socket_connect daemon_socket_fail daemon_socket_read daemon_socket_error
			/ ]
		]
	);


	push @BOTLIST, $self;   #Keep a list of all the bots that are running
	weaken( $BOTLIST[-1] ); #but weaken it so we don't screw with garbage collecting
	                        
	$SIG{CHLD}='IGNORE';
	#Set the CPU rlimit to INFINITY. This is mostly pointless but serves to load the
	#auto/setrlimit.al file for BSD::Resource, since we can't do it after we chroot
	#inside safe execute.
	setrlimit(RLIMIT_CPU,-1,-1);

	return $self;
}

#####################################################################
#POE Session Events
sub _start
{
	my( $self, $kernel, $sender ) = @_[OBJECT,KERNEL,SENDER];
	my $logger = get_logger();

	$logger->info( "_START" );

	for( values %{ $self->{irc_objs} } )
	{
		my $irc = $_->{irc};

		$irc->yield( register => 'all' );
		$irc->yield( connect => {} );

		my $connector = POE::Component::IRC::Plugin::Connector->new;
		push @{$self->{irc_connectors}}, $connector;
		$irc->plugin_add( Connector => $connector );
	}

	$logger->info( "Preparing to load plugins" );
	$self->load_plugins;	
	$logger->info( "Finished loading plugins" );

	$self->_load_daemons 
}

sub _default
{
	my( $self, $event, @args ) = @_[OBJECT,ARG0..$#_];
}

sub irc_001
{
	my( $self, $sender ) = @_[OBJECT, SENDER];

	$self->{connected} = 1;

	if( @{ $self->{join_queue}->{$sender->ID} } )
	{
		for( @{ $self->{join_queue}->{$sender->ID} } )
		{
			warn "Handling queued channel $_\n";
			$_[KERNEL]->post( $sender->ID, join => $_ );
		}
	}
}

sub irc_public
{
	my( $self, $nick_mask, $channels, $message ) = @_[OBJECT,ARG0,ARG1,ARG2];

	my $said = $self->_convert_to_said( $_[SENDER]->ID, $nick_mask, $channels, $message );
	$self->said( $said );
}

sub irc_msg
{
	my( $self, $nick_mask, $message ) = @_[OBJECT,ARG0,ARG2];

	my $said = $self->_convert_to_said( $_[SENDER]->ID, $nick_mask, ['privmsg'], $message );
	$self->said( $said );
}

#TODO How to differentiate between being noticed as a channel and specifically?
#Probably the ARG1 ..
sub irc_notice
{
	my( $self, $nick_mask, $message ) = @_[OBJECT,ARG0,ARG2];

	my $said = $self->_convert_to_said( $_[SENDER]->ID, $nick_mask, [undef], $message );
	$said->{channel} = 'privmsg';
	$self->said( $said );
}


sub command_stdout
{
	my( $self, $data, $wheel_id ) = @_[OBJECT,ARG0,ARG1];
	my $logger = get_logger();
 
 	$logger->debug( "command_stdout: $data" );
	$logger->debug( Dumper $data );

	if( $data->{command_queue} )
	{
		for( @{ $data->{command_queue} } )
		{
			my $cmd = shift @$_;

			if( $self->can($cmd) )
			{
				$self->$cmd(@$_);
			}
		}
	}

	push @{$self->{wheels}->{$wheel_id}->{output}}, $data;

	$logger->debug( "command_stdout: stdout=$data->{stdout}" );
}

sub command_stderr
{
	my( $self, $data, $wheel_id ) = @_[OBJECT,ARG0,ARG1];

	get_logger()->warn( "command_stderr: data=$data" );
}

sub command_close
{
	my( $self, $wheel_id ) = @_[OBJECT,ARG0];
	my $logger = get_logger();

	my $wheel_struct = delete $self->{wheels}->{$wheel_id};

	$logger->info( "command_close: wheel_output=$wheel_struct->{output}" );

	my $said = $wheel_struct->{said};

	for( @{ $wheel_struct->{output} } )
	{
		if( $_->{type} eq 'privmsg' )
		{
			$said->{nick} = $_->{privmsg_target};
			$said->{channel} = 'privmsg';
			$said->{body} = $_->{stdout};
			$self->say($said);
		}
		else
		{
			$self->reply( $said, $_->{stdout} );
		}
	}
}

sub command_error
{
	my(@messages) = @_[ARG0..ARG4];

	get_logger()->warn( "command_error: @messages" );
}

sub daemon_socket_connect
{
	my( $self, $socket ) = @_[OBJECT,ARG0];
	my $logger = get_logger();
	$logger->info( "Got daemon socket_connection, $socket" );

	my $wheel = POE::Wheel::ReadWrite->new(
		Handle => $socket,
		Driver => POE::Driver::SysRW->new,
		Filter => POE::Filter::Reference->new,
		InputEvent => 'daemon_socket_read',
		ErrorEvent => 'daemon_socket_error',
	);

	$self->{daemon_wheels}->{$wheel->ID} = $wheel;
	$logger->info( "Created wheel: $wheel" );
}

sub daemon_socket_fail
{
	my( $self, $error ) = @_[OBJECT,ARG0];

	get_logger()->warn( "daemon_socket_fail: error=$error" ); 
}

sub daemon_socket_read
{
	my( $self, $inputs, $id ) = @_[OBJECT,ARG0,ARG1];
	my $logger = get_logger();

	$logger->debug( "daemon_socket_read: Got input: ", Dumper $inputs );

	for my $input ( @$inputs )
	{
		if( not ref $input eq 'HASH' ) { $logger->warn( "Error, Daemon protocol requires hash refs. Got: $input." ); return }

		if( $input->{type} eq 'register' )
		{
			$logger->info( "Registering event type:$input->{event} from daemon $input->{name}" );
			push @{ $self->{daemon_events}{ $input->{event} } }, {
				id => $id,
				name => $input->{name},
			};
		}

		elsif( $input->{type} eq 'unregister' )
		{
			@{ $self->{daemon_events}{ $input->{event_type} } } =
			grep $_->{id} != $id, @{ $self->{daemon_events}{ $input->{event_type} } }
			#Uh, sorry?
		}

		elsif( $input->{type} eq 'output' )
		{
			$logger->info( "Got daemon output" );
 			$logger->debug( "Said: ", Dumper $input->{said} );
			my $said = $input->{said};

			if( $input->{output_parsing} ) # and $said->{commands_to_parse} )
			{
				my $commands = Bot::BB2::CommandParser->parse_metachar_first( $said->{commands_to_parse} );
				$commands ||= [];
				
#        my $said_body = $said->{body};
#        $said->{body} = $said->{commands_to_parse};
				my $body_commands = Bot::BB2::CommandParser->parse_subcommands( $said->{body} );
				my $cmd = { command => 'echo', args => $body_commands };
				$said->{addressed} = 1; #Make sure echo always works. Lame.

				$logger->debug( "DAEMON_OUTPUT: execute_parsed: " );
				$logger->debug( Dumper [$cmd,@{$commands}] );

				$self->execute_parsed( $said, [$cmd,@$commands] );
			}
			else
			{
				my $commands = Bot::BB2::CommandParser->parse_metachar_first( $said->{commands_to_parse} );
				$commands ||= [];
				my $cmd = { command => 'echo', args => [$said->{body}] };
				$said->{addressed} = 1; #Make sure echo always works. Lame.

				$self->execute_parsed( $said, [$cmd,@$commands] );
			}
		}
	}
}

sub daemon_socket_error
{
	my( $self, $operation, $errnum, $errstr, $id ) = @_[OBJECT,ARG0..ARG3];

	get_logger()->warn( "daemon_socket_error: $operation, $errnum:$errstr from wheel $id" );
	delete $self->{daemon_wheels}->{$id};
}

#####################################################################
#Private Methods
sub safe_execute
{
	my( $code ) = @_;

	opendir my $dh, "/proc/self/fd" or die $!;
	while(my $fd = readdir($dh)) { next unless $dh > 2; POSIX::close($dh) }

	my $nobody_uid = getpwnam("nobody");
	die "Error, can't find a uid for 'nobody'. Replace with someone who exists" unless $nobody_uid;

	chdir("./jail") or die $!;

	if( $< == 0 )
	{
		chroot(".") or die $!;
	}
	else
	{
#    warn "Not root, won't try to chroot";
	}
	$<=$>=$nobody_uid;
	POSIX::setgid($nobody_uid); #We just assume the uid is the same as the gid. Hot.
	
	my $kilo = 1024;
	my $meg = $kilo * $kilo;

	setrlimit(RLIMIT_CPU, 10,10);
	setrlimit(RLIMIT_DATA, 40*$meg, 40*$meg );
	setrlimit(RLIMIT_STACK, 40*$meg, 40*$meg );
	setrlimit(RLIMIT_NPROC, 1,1);
	setrlimit(RLIMIT_NOFILE, 0,0);
	setrlimit(RLIMIT_OFILE, 0,0);
	setrlimit(RLIMIT_OPEN_MAX,0,0);
	setrlimit(RLIMIT_LOCKS, 0,0);
	setrlimit(RLIMIT_AS,40*$meg,40*$meg);
	setrlimit(RLIMIT_VMEM,40*$meg, 40*$meg);
	setrlimit(RLIMIT_MEMLOCK,100,100);
	#setrlimit(RLIMIT_MSGQUEUE,100,100);

	die "Failed to drop root: $<" if $< == 0;
	close STDIN;

	local $@;

	for( qw/IO::Socket::INET/ )
	{
		delete_package( $_ );
	}

	local @INC;
#  delete $self->{ irc }->{ $_ } #This is bad!
#    for qw/socket dcc wheelmap localaddr/;

    {
			#no ops qw(:base_thread :sys_db :subprocess :others);
			$code->();
    }
}

sub _convert_to_said
{
	my( $self, $poco_irc, $nick_mask, $channels, $message ) = @_;
	if( @_ < 4 )
	{
		return { body => $_[1] };
	}

	return unless ref $channels;
	return unless length $message;

	my( $nick, $mask ) = split /!/, $nick_mask, 2;
	
	my $said = {
		nick => $nick,
		fullnick => $nick_mask,
		channel => ref $channels eq 'ARRAY' ? $channels->[0] : $channels, #In theory we can receive a 
		                                                                  #message on multiple channels, 
		raw_body => $message,                                             #I hope it never happens.
		body => $message,
		poco_irc => $poco_irc,
	};

	my $nick = $self->map_to_irc_opts( $poco_irc )->{nick};

	if( $said->{body} =~ s/^\s*(\Q$nick\E)\s*[:,.>-]?\s*//i ) #Remove our nick if it is the first thing..
	                                                          # Should actually use 
																														# POE::Component::IRC::Common::l_irc on both the first
																														# word and the nickname, but this is BB2, so /i will
																														# do for simplicity's sake.
	                                                          # BTW, that is so not *our* nick. -- Aankhen
	{
		$said->{addressed} = $1;
	}

#	warn "Created \$said: ", Dumper $said;

	return $said;
}

sub ignored
{
	my( $self, $nick ) = @_;

	if( $self->{ignore_list}->{ $nick } ) {
		return 1;
	}
}

sub said
{
	my( $self, $said ) = @_;
	my $logger = get_logger();
	my $conf = $self->map_to_irc_conf( $said->{poco_irc} );

	if( $self->ignored( $said->{nick} ) )
	{
		return;
	}


	if( $conf->{address_only} and not $said->{addressed} )
	{
		return;
	}

	$logger->debug( "said, body: '$said->{body}'" );
	
	$self->parse_and_execute( $said );
}

sub _load_daemons
{
	my( $self ) = @_;
	my $logger = get_logger();

	$logger->info( "Preparing to launch daemons" );
	$self->_launch_bb2_daemon_service;

    my @daemons = $self->pm_files('daemon');

    for (@daemons)
    {
        my ($daemon_dir, $file) = $_ =~ m[(.*)/(.+)];
		$logger->info( "Launching daemon: $_" );
		$self->_launch_daemon( $daemon_dir, $file );
	}
	$logger->info( "Finished launching daemons" );
}

sub _launch_bb2_daemon_service
{
	my( $self ) = @_;
	my $logger = get_logger();
	$logger->info( "Preparing to launch daemon_listener" );
	
	$self->{daemon_socket_factory} = POE::Wheel::SocketFactory->new(
		BindAddress => '127.0.0.1',
		BindPort => $self->{_daemon_port},
		Reuse => 'yes',
		SuccessEvent => 'daemon_socket_connect',
		FailureEvent => 'daemon_socket_fail',
	) or $logger->error( "Failed to create socket_factory: $@ $!" );

	$logger->info( "Created daemon_listener on $self->{_daemon_port}" );


	my $session = POE::Session->create( 
		inline_states => { 
			_start => sub { 
				for( values %{ $self->{irc_objs} } )
				{
					$_->{irc}->yield( register => 'all' );
				}
			},
			_default => sub {
				my( $event, $args_ref ) = @_[ARG0,ARG1];
				my @args = @$args_ref;
				my $said = $self->_convert_to_said( $_[SENDER]->ID, @args ); 

				return if $self->ignored( $said->{nick} );

				if( $self->{daemon_events}->{$event} )
				{
					for( @{ $self->{daemon_events}->{$event} } )
					{
						my $wheel = $self->{ daemon_wheels }->{ $_->{id} };
						next unless $wheel;
						$logger->debug( "Found wheel $_->{id} to dispatch to" );

						$logger->debug( "Event: $event" );
						$logger->debug( "Args: [@args]" );
						$logger->debug( "Said: ", Dumper $said );
						my $rec = { type => 'event', event => $event, said => $said, args => \@args };

						$wheel->put( [$rec] );
					}
				}
			},
		}
	);
}

sub _launch_daemon
{
	my( $self, $dir, $filename ) = @_;
	my $logger = get_logger();
	$logger->info( "Attempting to launch daemon: $filename" );
 
	if(my $pid = fork )
	{
		$self->{daemons}->{$filename} = {
			pid => $pid,
			filename => $filename,
			dir => $dir,
		};
		$logger->debug( "Forked daemon as: $pid" );
 		return;
	}
	elsif( not defined $pid )
	{
		$logger->error( "Could not fork for daemon $filename: $!" );
		return;
	}
	else
	{
    warn "Execing $dir/$filename, $self->{_daemon_port}\n";
    $ENV{_BB2_DAEMON_PORT} = $self->{_daemon_port};
    $ENV{PERL5LIB} .= join ':', @INC; #Make sure we pick up any dirs specified in the invocation
    exec $^X, "$dir/$filename"
			or die "Error, could not exec: $!,$@";
		exit;
	}
}

sub is_allowed_command
{
	return 1;
}

sub load_plugins
{
	my( $self ) = @_;
	my $logger = get_logger();
	my @plugins = $self->pm_files('plugin');
	$logger->info( "Preparing to load_plugins" );

    unless (@plugins) {
        $logger->warn( "NO PLUGINS TO LOAD. This will probably make the bot useless" );
        return;
    }

	local %INC = %INC; #Ensure that if plugins are reloaded, they reload dependent modules.

	unless (-d 'heaps') {
		mkdir 'heaps' or die "Couldn't make 'heaps' directory: $!";
	}

	for( glob"heaps/*.db" ) { unlink $_ }

	for my $plugin (@plugins) 
	{
		$logger->info( "Attempting to load $plugin" );
		my $plugin_struct = do $plugin;
		if( $@ )
		{
			$logger->warn( "Error loading $plugin: $@" );
			next;
		}
		else
		{
			$plugin =~ s/\.pm$//;
			$plugin =~ m{([^/]+)$};
			$plugin = $1;

			$self->{plugins}->{$plugin} = $plugin_struct;
			$self->{heap_keys}->{$plugin} = substr(3,rand).$$.gettimeofday.({}+0);

			$logger->info( "Loaded $plugin: $plugin_struct, key: $self->{heap_keys}->{$plugin}" );
		}
	}

	$logger->info( "Finished loading plugins" );
}

sub pm_files
{
    my ($self, $type, $e) = @_;
    my $ext = $e || '.pm';

	my @dir = map { catdir($_ => "Bot/BB2/" . ucfirst $type) } @INC; # plugins in @INC
	push @dir, "${type}s" if -d "${type}s";        # plugins in cwd

	my @file = map { glob "$_/*$ext" } @dir;

	# Filter out garbage
	my @plugin = grep { /\Q$ext\E$/ } @file;

	return @plugin;
}

sub reload_plugins
{
	my( $self ) = @_;
	my $logger = get_logger();
	$logger->info( "Preparing to reload plugins" );
	delete $self->{plugins};
	delete $self->{heap_keys};

	$self->load_plugins;
	$logger->info( "Finished reloading plugins" );
}

sub plugins_available
{
	my( $self ) = @_;

	return keys %{ $self->{plugins} };
}

sub lookup_coderef
{
	my( $self, $name ) = @_;

	#This prevents autovivication errors.
	if( exists $self->{plugins}->{$name} )
	{
		return $self->{plugins}->{$name}->{code};
	}
	else
	{
		return;
	}
}

sub command_conf
{
	my( $self, $said, $command ) = @_;
	my $plugin_conf = $self->{plugin_conf};
	my $conf = $self->map_to_irc_conf( $said->{poco_irc} );

	my $opts = {};
	for( @$plugin_conf )
	{
		my $glob = $_->[1];
		if( match_glob( $glob, $conf->{server} ) )
		{
			for( @{ $_->[2] } )
			{
				if( match_glob( $_->[1], $said->{channel} ) )
				{
					for( @{ $_->[2] } )
					{
						if( match_glob( $_->[1], $command ) ) 
						{
							my $new_opts = $_->[2];
							$opts = { %$opts, %$new_opts };
						}
					}
				}
			}
		}
	}

	return $opts;
}

sub is_permitted
{
	my( $self, $said, $command ) = @_;
	my $irc = $self->map_to_irc_obj( $said->{poco_irc} );
	my $opts = $self->command_conf( $said, $command );

	my $perm = 1;

	if(exists $opts->{access})
	{
		my $level = $opts->{access};

		if( $level eq 'root' )
		{
			$perm = 0 unless $said->{fullnick} =~ m[buu\@71.6.194.243];
		}

		elsif( $level eq 'op' )
		{
			$perm = 0 unless $said->{fullnick} =~ m[buu\@71.6.194.243]
				or $irc->is_channel_operator( $said->{channel}, $said->{nick} );
		}
	}

	if(exists $opts->{addressed})
	{
		$perm = 0 unless $said->{addressed};
	}

	return $perm;
}

sub wheel_execute 
{
	my ($code, $callback) = @_;

	my ($stdout, $stderr);

	warn "wheel_execute(@_)";
	my $session = POE::Session->create(
		inline_states => {
			_start => sub {
				my ($heap) = @_[HEAP];
				warn "SUB WHEEL--START\n";

				my $subref = sub { 
					untie *STDOUT;
					
					safe_execute($code);

					exit;
				};

				$heap->{wheel} = POE::Wheel::Run->new(
					Program => $subref,

					StdoutEvent => 'stdout',
					StderrEvent => 'stderr',
					CloseEvent => 'closed',

					StdioFilter => POE::Filter::Line->new,
				);

				$_[KERNEL]->sig_child($heap->{wheel}->PID, "sigchild");
				$_[KERNEL]->delay_set( timeout => 9 );
				warn "SUB WHEEL--END OF START";
			},

			timeout => sub {
				my ($heap) = @_[HEAP];

				kill 9, $heap->{wheel}->PID;
				$stderr = 'Error, killing eval due to timeout';
			},

			stdout => sub {
				my ($output) = @_[ARG0];
				warn "SUB WHEEL--STDOUT\n";
				warn "-- $output\n";
				chomp $output;
				$stdout .= $output;
			},

			stderr => sub {
				my ($output) = @_[ARG0];
				warn "SUB WHEEL--STDERR\n";
				warn "-- $output\n";
				chomp $output;
				$stderr .= $output;
			},

			closed => sub {
				warn "SUB WHEEL--CLOSED\n";
				warn "\t$stdout -- $stderr\n";
				$callback->($stdout, $stderr);
				$_[KERNEL]->stop;
			},
		},
	);

	POE::Kernel->run;

	warn "AFTER THE END OF WHEEL EXECUTE\n";
};

sub plugin_coderef_wrapper
{
	my( $self, $coderef, $plugin_name, @args ) = @_;
	srand( $$ ^ time + {} );
	POE::Kernel->stop; #Just in case.

	my $heap_key = $self->{heap_keys}->{$plugin_name};
	my $heap;
	tie %$heap, "DB_File", "heaps/$heap_key.db";
	warn "Heapkey: $heap_key\n";
	warn "Heap: ", tied %$heap,"\n";
	warn "Args: @args\n";
	my $output_ref = {};
	my $fh = Symbol::gensym();
	tie *$fh, 'Bot::BB2::TiedPluginHandle', $output_ref;
	select $fh;

	local *output = sub { $output_ref->{stdout} .= join $", @_ };
	local *heap = sub { $heap };
	local *safe_execute = \&safe_execute;
	local *self_cmd = sub {
		my( $cmd_name, @args ) = @_;

		push @{ $output_ref->{command_queue} }, [ $cmd_name, @args];
	};

	$coderef->(@args);

	untie %$heap;

	$output_ref->{plugin_name} = $plugin_name;

	return $output_ref;
}

sub command_line_execute
{
	my( $self, $said, $commands, $incoming_pipe_data ) = @_;
	my $logger = get_logger();
	my $irc = $self->map_to_irc_obj( $said->{poco_irc} );
	$logger->info( "Command_line_execute" );
	$logger->debug( Dumper $commands );

	my $last_output = { stdout => $incoming_pipe_data };
	for( @$commands )
	{
		if( ref $_ eq 'HASH' )
		{
			unless( $self->is_permitted( $said, $_->{command} ) )
			{
				warn "Error, not permitted to do $_->{command}\n";
				return {};
			}
			
			my $coderef = $self->lookup_coderef( $_->{command} );
			warn "CODEREF: $coderef\n";
			$logger->debug( "REF: @{$_->{args}}" );
			return unless $coderef;
			
			for( @{ $_->{args} } )
			{
				$logger->debug( "ARGS: ");
				$logger->debug( Dumper $_ );
				if( ref $_ )
				{
					$_ = command_line_execute( $self, $said, $_ )->{stdout};
				}
			}

			$last_output = $self->plugin_coderef_wrapper( 
				$coderef,
				$_->{command},
				#Args to $coderef!
				$self,
				$said,
				$last_output->{stdout} ? $last_output->{stdout} : (),
				@{ $_->{args} } 
			);
		}
		#Handle redirects
		#Note that we return here since a redirect ends the command chain.
		elsif( ref $_ eq 'ARRAY' and $_->[0] eq '>' )
		{
			
			warn "$self->is_channel_member( $said->{channel}, $_->[1] )";
			if( $irc->is_channel_member( $said->{channel}, $_->[1] ) )
			{
				$last_output->{type} = 'privmsg';
				$last_output->{privmsg_target} = $_->[1];
				return $last_output;
			}
			else
			{
				return {};
			}
		}

		elsif( $_ eq '|' )
		{

		}
		warn "LAST_OUTPUT:\n";
		warn Dumper $last_output;
	}
	
	return $last_output;
}

sub handle_commandline
{
	my( $self, $said, $commands, $incoming_piped_input ) = @_;
	my $logger = get_logger();
	$logger->info( "handle_commandline" );

	my $output = $self->command_line_execute( $said, $commands, $incoming_piped_input );

	my $filter = POE::Filter::Reference->new;
	warn "Trying to output the frozen output, as it were\n";
	warn Dumper $output;
  print STDOUT @{ $filter->put( [ $output ] ) };
	warn "After outputting the frozen output\n";
}

sub parse_and_execute
{
	my( $self, $said ) = @_;
	my $line = $said->{body};

	warn "parse_and_execute: $line\n";
	my $commands = Bot::BB2::CommandParser->parse( $line );

	unless( $commands )
	{
		warn "Error, could not parse $line\n";
		return;
	}

	for( @$commands ) 
	{
		next unless ref $_; 
		if( ref $_ eq 'HASH' and not $self->lookup_coderef( $_->{command} ) )
		{
			return;
		}
	} #TODO check for subcommands.

	$self->execute_parsed( $said, $commands );
}

sub execute_parsed
{
	my( $self, $said, $commands, $incoming_piped_data ) = @_;
	my $logger = get_logger();

	$logger->info("execute_parsed");

	my $wheel = POE::Wheel::Run->new( 
		Program => \&handle_commandline,
		ProgramArgs => [ $self, $said, $commands, $incoming_piped_data ],

		StdoutEvent => 'command_stdout',
		StderrEvent => 'command_stderr',
		CloseEvent => 'command_close',
		StdoutFilter => POE::Filter::Reference->new,
	);

	$logger->debug("Created wheel: ". $wheel->ID);
	$self->{wheels}->{$wheel->ID} = { wheel => $wheel, said => $said };
}

sub yield
{
	my( $self, @args ) = @_;

	$poe_kernel->post( $self->{session}->ID => @args );
}

#####################################################################
#Public Methods

sub map_to_irc_conf
{
	my( $self, $poco_irc ) = @_;
	$self->_map_to_irc_store( $poco_irc )->{conf};
}

sub map_to_irc_opts
{
	my( $self, $poco_irc ) = @_;
	$self->_map_to_irc_store( $poco_irc )->{irc_opts};
}

sub map_to_irc_obj
{
	my( $self, $poco_irc ) = @_;
	$self->_map_to_irc_store( $poco_irc )->{irc};

}

sub _map_to_irc_store
{
	my( $self, $poco_irc ) = @_;

	if( ref( $poco_irc ) =~ /Session/ )
	{
		return $self->_map_to_irc_store( $poco_irc->ID );
	}


	elsif( ref $poco_irc and $poco_irc->isa('POE::Component::IRC') )
	{
		return $self->_map_to_irc_store( $poco_irc->session_id );
	}

	elsif( exists $self->{irc_objs}->{$poco_irc} )
	{
		return $self->{irc_objs}->{$poco_irc};
	}

	else
	{
		for( values %{ $self->{irc_objs} } )
		{
			if( $_->{irc_opts}->{server} eq $poco_irc )
			{
				return $_;
			}
		}
	}

	return {};
}

sub join_channels
{
	my( $self, $poco_irc, @channels ) = @_;
	return if not $poco_irc;

	warn "Attempting to join @channels\n";
	$poco_irc = $self->map_to_irc_obj( $poco_irc );

	if( $self->{connected} )
	{
		$poco_irc->yield( join => $_ ) for @channels;
	}
	else
	{
		warn "Queuing channels for later joining\n";
		push @{ $self->{join_queue}->{$poco_irc->session_id} }, @channels;
	}
}

sub part_channels
{
	my( $self, $poco_irc, @channels ) = @_;
	$poco_irc = $self->map_to_irc_obj( $poco_irc );

	$poco_irc->yield( part => $_ ) for @channels;
}

sub ignore
{
	my( $self, $nick ) = @_;
	$self->{ignore_list}->{$nick} = 1;
}

sub say
{
	my( $self, $message ) = @_;
	my $body = $message->{body};

	my $target = $message->{channel} eq 'privmsg' ? $message->{nick} : $message->{channel};
	my $irc = $self->map_to_irc_obj( $message->{poco_irc} );
	
	local $Text::Wrap::columns = 250;
	local $Text::Wrap::unexpand = 0;
	my $lines = wrap("","", $body);

	for( split /\n/, $lines )
	{
		if( $target ne 'privmsg' and $message->{nick} )
		{
			$_ = "$message->{nick}: $_";
		}
		$irc->yield( privmsg => $target => $_ );
	}
}

sub reply
{
	my( $self, $said, @resp ) = @_;

	$self->say( { %$said, body => "@resp" } );
}

sub quit
{
	exit;
}

sub restart
{
	exec $0;
	warn "Failed to exec: $!,$@,etc\n";
	exit;
}

#Maybe..
sub running_daemons
{
	my( $self ) = @_;

	return keys %{ $self->{daemons} }
}


sub reload_daemon
{
	my( $self, $daemon ) = @_;

	return unless exists $self->{daemons}->{$daemon};

	my $info = delete $self->{daemons}->{$daemon}; 

	$self->kill_daemon( $daemon );
	$self->_launch_daemon( $info->{dir}, $info->{filename} )
}

1;
