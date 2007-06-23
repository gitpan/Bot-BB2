use strict;
use Test::More tests => 3;

use_ok $_ for map { "Bot::$_" } qw(BB2 BB2::ConfigParser BB2::TiedPluginHandle);
