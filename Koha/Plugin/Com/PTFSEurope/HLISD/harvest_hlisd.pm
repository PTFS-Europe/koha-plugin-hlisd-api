#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright (C) 2022 PTFS Europe
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use Getopt::Long    qw( GetOptions );
use POSIX;

use Koha::Script;
use Koha::Patrons;
use Koha::Plugin::Com::PTFSEurope::HLISD;

# Command line option values
my $get_help   = 0;
my $debug      = 0;
my $mode;

my $options = GetOptions(
    'h|help'       => \$get_help,
    'mode|m=s'     => \$mode,
    'debug'        => \$debug
);

if ($get_help) {
    get_help();
    exit 1;
}

die "A mode needs to be specified with the -m or --mode option ('library' or 'patron')" unless $mode;
die "Invalid mode supplied ('library' or 'patron' is expected)" unless $mode eq 'patron' || $mode eq 'library';

Koha::Plugin::Com::PTFSEurope::HLISD->new()->harvest_hlisd(
    {
        debug   => $debug,
        mode    => $mode
    }
);

sub get_help {
    print <<"HELP";
$0: Run a HLISD harvest

Parameters:
    --help or -h                         get help
    --debug                              print additional debugging info during run
    --mode or -m                         specificies mode: 'patron' or 'library'

Usage example:
./misc/cronjobs/harvest_hlisd.pl --mode patron --debug

HELP
}
