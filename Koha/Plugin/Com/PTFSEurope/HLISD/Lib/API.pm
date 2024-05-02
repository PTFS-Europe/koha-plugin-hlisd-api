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
use JSON qw( decode_json );
use CGI;
use URI;

use Koha::Logger;
use C4::Context;

use Koha::Plugin::Com::PTFSEurope::HLISD;
use Koha::DateUtils qw( dt_from_string );

=head1 NAME

HLISD - Client interface to HLISD API

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
        plugin_config => $plugin_config,
        auth          => undef,
    };

    bless $self, $class;

    return $self;
}

=head3 Libraries

Make a call to /api/v1/libraries

=cut

sub Libraries {
    my ( $self, $library_id ) = @_;

    return $self->_make_request( 'GET', 'libraries' );
}

=head3 LibraryDetails

Make a call to /api/v1/libraries/{id}

=cut

sub LibraryDetails {
    my ( $self, $library_id ) = @_;

    return $self->_make_request( 'GET', 'libraries/' . $library_id );
}

=head3 Authenticate

Make a call to /auth/login

=cut

sub Authenticate {
    my ($self) = @_;

    my $data = {
        email    => $self->{plugin_config}->{email},
        password => $self->{plugin_config}->{password},
    };

    return $self->_make_request( 'POST', 'auth/login', $data );
}


=head3 _make_request

Make a request to the HLISD API. If the request is not for /auth/login, it will automatically call
Authenticate before making the request.

=cut

sub _make_request {
    my ( $self, $method, $endpoint_url, $payload ) = @_;

    my $header;
    unless ( $endpoint_url eq 'auth/login' ) {

        $self->{auth} = $self->Authenticate() unless $self->{auth};

        die 'HLISD API error: ' . $self->{auth}->{error} if $self->{auth}->{error};

        my $now_time        = dt_from_string;
        my $token_exp_day   = substr $self->{auth}->{exp}, 3,  2;
        my $token_exp_month = substr $self->{auth}->{exp}, 0,  2;
        my $token_exp_year  = substr $self->{auth}->{exp}, 6,  4;
        my $token_exp_hour  = substr $self->{auth}->{exp}, 11, 2;
        my $token_exp_min   = substr $self->{auth}->{exp}, 14, 2;
        my $token_exp_dt =
            dt_from_string( $token_exp_year . '-'
                . $token_exp_month . '-'
                . $token_exp_day . ' '
                . $token_exp_hour . ':'
                . $token_exp_min );

        $self->{auth} = $self->Authenticate() if ( $now_time->epoch > $token_exp_dt->epoch );

        $header = HTTP::Headers->new( Authorization => 'Bearer ' . $self->{auth}->{token} );
    }

    my $uri = URI->new( $self->{base_url} . '/' . $endpoint_url );
    $uri->query_form($payload);

    my $request  = HTTP::Request->new( $method, $uri, $header, undef );
    my $ua       = LWP::UserAgent->new;
    my $response = $ua->request($request);

    return decode_json( $response->decoded_content );
}

1;
