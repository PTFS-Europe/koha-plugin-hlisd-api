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
my $type;

my $options = GetOptions(
    'h|help'       => \$get_help,
    'type|t=s'     => \$type,
    'debug'        => \$debug
);

if ($get_help) {
    get_help();
    exit 1;
}

Koha::Plugin::Com::PTFSEurope::HLISD->new(
    {
        debug => $debug,
        type => $type
    }
)->harvest_hlisd();

sub get_help {
    print <<"HELP";
$0: Run a HLISD harvest

Parameters:
    --help or -h                         get help
    --debug                              print additional debugging info during run
    --type or -t                         specificies type: 'patron' or 'library'

Usage example:
./misc/cronjobs/harvest_hlisd.pl --type patron --debug

HELP
}
