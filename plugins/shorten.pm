use WWW::Shorten 'Metamark';

{
    code => sub {
        my $short = makeashorterlink($_[2]);
        print($short ? $short : "Couldn't shorten URI.");
    },
}