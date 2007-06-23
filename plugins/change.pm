use Finance::Quote;
{
    code => sub {
        my ($amount, $from, $to) = @_[2,3,5];

        $from = uc $from;
        $to   = uc $to;

        my $res = Finance::Quote->new->currency($from, $to);

        unless ($res) {
            print "Sorry, either $from or $to is not a valid currency symbol";
        } else {
            my $total = $res * $amount;
            print "$amount $from is $total $to";
        }
    }
}
