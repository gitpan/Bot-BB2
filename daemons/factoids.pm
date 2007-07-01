use Bot::BB2::DaemonUtils;
use strict;
use Data::Dumper;
use DBI;

my $copula = join '|', qw/is are was isn't were being am/, "to be", "will be", "has been", "have been", "shall be";
$copula = qr/$copula/i;

register( irc_public => \&msg, irc_privmsg => \&msg );
enable_output_parsing();
run();


sub msg
{
	my( $event ) = @_;
	my $said = $event->{said};
	my $body = $said->{body};

	warn "FACTOID: triggering on $body\n";

	#TODO Replaced with properly factored out parsing routine. HLAGH
	($body, my @remainder) = split /([>|])/, $body, 2;
	s/^\s+//, s/\s+$// for $body;

	return unless $said->{addressed};

	### Show Revisions
	if( $body =~ /^revisions (.+)/i )
	{
		my $subj = $1;
		my $revs = query_revisions( normalize( $subj ) );

		if( $said->{channel} eq 'privmsg' ) { $#$revs = 4 if $#$revs > 4; }

		my $reply;
		for( @$revs )
		{
			$reply .= " r$_->{id}: $_->{nick} | [$_->{subject} $_->{copula} $_->{predicate}]";
		}

		reply( $said, $reply );
	}

	elsif( $body =~ /^forget (.+)/i )
	{
		my $fact = query_factoid( $1 );
		if( $fact and %$fact ) 
		{
			$fact->{predicate} = '';
			insert_factoid( $fact, $said->{nick} );
			reply( $said, "I forgot $fact->{subject}" );
		}
		else
		{
			if( $said->{addressed} ) { reply( $said, "Sorry, I don't know anything matching $1" ); }
		}
	}

	### Revert to a revision
	elsif( $body =~ /^revert r(\d+)/i )
	{
		my $r_id = $1;
		my $rev = get_revision( $r_id );
		reply($said, "Reverting factoid $r_id:$rev->{subject}");
		insert_factoid( $rev, $said->{nick} );
	}

	### Store factoid
	elsif( $body =~ /(.+)\s+($copula)\s+(.+)/ )
	{
		my( $subj, $cop, $pred ) = ($1,$2,$3);
		warn "Matched copula: subj=[$subj], cop=[$cop], pred=[$pred]\n";
		return unless length normalize($subj) and normalize($subj) =~ /\w/;

		#Remove leading address marker
		$subj =~ s/^\S+:\s*//;

		my $factoid = query_factoid( $subj );
		if( $factoid and %$factoid )
		{
			$factoid->{predicate} .= " $pred";
			insert_factoid( $factoid, $said->{nick} );
		}
		else
		{
			warn "insert_factoid( { subject => $subj, copula => $cop, predicate => $pred }, $said->{nick} )";
			insert_factoid( { subject => $subj, copula => $cop, predicate => $pred }, $said->{nick} );
		}

		if( $said->{addressed} )
		{
			reply( $said, "Stored $subj" );
		}
	}

	elsif( $body =~ /^\s*literal (.+)/ )
	{
		my $subj = $1;
		my $factoid = query_factoid( $subj );

		if( $factoid and %$factoid )
		{
			my $reply;
			$reply .= "$factoid->{subject} $factoid->{copula} $factoid->{predicate}";

			if( length $factoid->{predicate} and $factoid->{predicate} =~ /\S/ )
			{
				disable_output_parsing();
				reply_with_remainder( $said, $reply, @remainder );
				enable_output_parsing();
			}

		}
	}
	### Retrieve factoid
	else
	{
		#Remove leading address marker
		$body =~ s/^\S+:\s*//;
		my $factoid = query_factoid( $body );
		if( $factoid and %$factoid )
		{
			#TODO {action}
			my $reply;
			my $alt_sep = "=OR=";
			if( $factoid->{predicate} =~ /$alt_sep/ )
			{
				my @alts = split /$alt_sep/, $factoid->{predicate};
				$factoid->{predicate} = $alts[rand@alts];
			}
			$reply .= "$factoid->{subject} $factoid->{copula} " if not $factoid->{predicate} =~ s/^\s*{reply}//;
			$reply .= $factoid->{predicate};
			warn "Found factoid, sending: $reply";
			if( length $factoid->{predicate} and $factoid->{predicate} =~ /\S/ )
			{
				reply_with_remainder( $said, $reply, @remainder );
			}
		}
	}

}

sub normalize 
{
	my $frag = shift;
	$frag = lc $frag;
	$frag =~ s/[^\w ]+//g;
	return $frag;
}

sub dbh
{
	DBI->connect_cached( "dbi:SQLite:dbname=factoids.db", "", "" );
}

sub query_factoid
{
	my( $subject ) = @_;

	my $row = dbh()->selectrow_arrayref( "
		SELECT subject,copula,predicate 
		FROM factoids 
		WHERE normalized_subject = ?
		ORDER BY factoid_id DESC
		LIMIT 1",
		undef, normalize($subject)
	);

	if( $row and @$row )
	{
		return {
			subject => $row->[0],
			copula => $row->[1],
			predicate => $row->[2],
		};
	}
	else
	{
		return;
	}
}

sub query_revisions
{
	my( $subject ) = @_;
	
	my $sth = dbh()->prepare( "SELECT subject,copula,predicate,nick,time,factoid_id
		FROM factoids WHERE normalized_subject = ?" );
	$sth->execute( $subject );
	
	my $revs;
	while( my $ar = $sth->fetchrow_arrayref )
	{
		push @$revs, {
			subject => $ar->[0],
			copula => $ar->[1],
			predicate => $ar->[2],
			nick => $ar->[3],
			time => $ar->[4],
			id => $ar->[5],
		};
	}

	return $revs;
}

sub get_revision
{
	my( $r_id ) = @_;

	my $row = dbh()->selectrow_arrayref( "SELECT subject,copula,predicate FROM factoids WHERE factoid_id = ?", undef, $r_id );

	return { subject => $row->[0], copula => $row->[1], predicate => $row->[2] };
}

sub insert_factoid
{
	my( $fact, $nick ) = @_;

	warn "ATTEMPTING TO INSERT :", Dumper($fact);

	dbh()->do("INSERT INTO factoids (normalized_subject, subject,copula,predicate,nick,time) VALUES (?,?,?,?,?,?)", undef,
		normalize( $fact->{subject} ),
		@{$fact}{qw/subject copula predicate/},
		$nick,
		time(),
	);
}
