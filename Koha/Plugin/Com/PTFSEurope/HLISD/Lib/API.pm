package Koha::Plugin::Com::PTFSEurope::HLISD::Lib::API;

# Copyright PTFS Europe 2024
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request;
use JSON qw( encode_json decode_json );
use CGI;
use URI;

use Koha::Logger;
use C4::Context;

use Koha::Plugin::Com::PTFSEurope::HLISD;

=head1 NAME

ReprintsDesk - Client interface to ReprintsDesk API plugin (koha-plugin-reprintsdesk)

=cut

sub new {
    my ( $class, $plugin_config ) = @_;

    my $cgi = new CGI;

    my $interface = C4::Context->interface;
    my $base_url  = 'https://hlisd.org/api/v1';

    my $self = {
        ua            => LWP::UserAgent->new,
        cgi           => new CGI,
        logger        => Koha::Logger->get( { category => 'Koha.Plugin.Com.PTFSEurope.HLISD.Lib.API' } ),
        base_url      => $base_url,
        plugin_config => $plugin_config
    };

    bless $self, $class;

    use Data::Dumper;
    $Data::Dumper::Maxdepth = 2;
    warn Dumper( '##### 1 #######################################################line: ' . __LINE__ );
    warn Dumper( $self->Authenticate() );
    warn Dumper('##### end1 #######################################################');

    return $self;
}

=head3 Authenticate

Make a call to /auth/login

=cut

sub Authenticate {
    my ($self) = @_;

    my $data = {
        email    => $self->{plugin_config}->{username},
        password => $self->{plugin_config}->{password},
    };

    return $self->_make_request( 'POST', 'auth/login', $data, undef );
}

# Makes a request to a specified endpoint using the provided method and payload data.
# Parameters:
#   $method: The HTTP method for the request.
#   $endpoint_url: The URL endpoint to make the request to.
# Return: The response from the endpoint.
sub _make_request {
    my ( $self, $method, $endpoint_url, $payload, $header ) = @_;

    # If token exists and is valid, use token

    #TODO:

    # Else, authenticate and fetch token

    my $uri = URI->new( $self->{base_url} . '/' . $endpoint_url );
    $uri->query_form($payload);

    my $request  = HTTP::Request->new( $method => $uri );
    my $ua       = LWP::UserAgent->new;
    my $response = $ua->request($request);

    return decode_json( $response->decoded_content );
}

1;
