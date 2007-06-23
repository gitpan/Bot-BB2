#line 1
package Module::Install::PRIVATE::Bot::BB2;
use strict;
use base 'Module::Install::Base';
use FindBin qw($Bin);
use File::Spec ();
use File::Copy::Recursive qw(rcopy);

our $VERSION = '0.02';

sub to_bb2_in_blib
{
    my ($self, $from, $to) = @_;

    printf "*** %s\n", __PACKAGE__;

    # Go to the dir Makefile.PL is in
    chdir $Bin;

    my @path = split '-', $self->name;
    # Copy F<plugins> to F<blib/lib/Bot/BB2/plugins>

    my $blibdir = File::Spec->catdir(qw(blib lib) => @path => $to);
    rcopy($from => $blibdir);

    printf "*** %s finished\n", __PACKAGE__;

    undef;
}

1;

__END__

#line 55
