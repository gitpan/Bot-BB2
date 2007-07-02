use strict;
use inc::Module::Install;

name 'Bot-BB2';

author 'BUU';
abstract 'ALL ABOARD THE BUUTRAIN';

license 'perl';
version '0.05';

no_index directory => $_ for qw(deps ext plugins daemons);

# logger.conf
requires 'Log::Dispatch' => 0;

# lib/

## BB2/Bot.pm
requires 'POE' => 0;
requires 'POE::Session' => 0;
requires 'POE::Component::IRC::State' => 0;
requires 'POE::Component::IRC::Plugin::Connector' => 0;
requires 'POE::Wheel::Run' => 0;
requires 'POE::Filter::Reference' => 0;
requires 'Text::ParseWords' => 0;
requires 'Scalar::Util' => 0;
requires 'Symbol' => 0;
requires 'IPC::Shareable' => 0;
requires 'BSD::Resource' => 0;
requires 'Symbol' => 0;
requires 'DB_File' => 0;
requires 'Time::HiRes' => 0;
requires 'Text::Wrap' => 0;
requires 'strict' => 0;
requires 'Log::Log4perl' => 0;
requires 'File::Copy::Recursive' => 0;
requires 'Text::Glob' => 0;

## BB2/ConfigParser.pm
requires 'Config::General' => 0;

## BB2/CommandParser.pm
requires 'Parse::RecDescent' => 0;

## BB2/TiedPluginHandle.pm
requires 'Data::Dumper' => 0;

# plugins/
recommends (
    # acronym.pm
    'WWW::Mechanize' => 0,

    # change.pm
    'Finance::Quote' => 0,

    # eval.pm
    'POE::Wheel::Run' => 0,
    'Data::Dumper' => 0,

    # imdb.pm
    #'IMDB' => 0, # shipped with this distro
    'Storable' => 0,

    # jseval.pm
    'POE::Session' => 0,
    'POE::Wheel::Run' => 0,

    #jeval.pm
    'Jplugin' => 0,

    # managementspeak.pm
    'Lingua::ManagementSpeak' => 0,

    # mangle.pm
    'Net::Dict' => 0,
);

# t/
build_requires 'Test::More' => 0; # 5.007003

# copy plugins/ to blib/
to_bb2_in_blib plugins   => 'Plugin';
to_bb2_in_blib daemons   => 'Daemon';
to_bb2_in_blib conf_tmpl => 'Conf';

install_script glob "script/*";

tests 't/*.t';

auto_install;
WriteAll;
