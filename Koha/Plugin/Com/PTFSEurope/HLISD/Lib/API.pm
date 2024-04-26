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
use JSON qw( encode_json );
use CGI;
use URI;

use Koha::Logger;
use C4::Context;

=head1 NAME

ReprintsDesk - Client interface to ReprintsDesk API plugin (koha-plugin-reprintsdesk)

=cut

sub new {
    my ($class) = @_;

    my $cgi = new CGI;

    my $interface = C4::Context->interface;
    my $url =
        $interface eq "intranet"
        ? C4::Context->preference('staffClientBaseURL')
        : C4::Context->preference('OPACBaseURL');

    # We need a URL to continue, otherwise we can't make the API calls
    if ( !$url ) {
        Koha::Logger->get->warn("Syspref staffClientBaseURL or OPACBaseURL not set!");
        die;
    }

    my $uri = URI->new($url);
    my $self = {
        ua      => LWP::UserAgent->new,
        cgi     => new CGI,
        logger => Koha::Logger->get( { category => 'Koha.Plugin.Com.PTFSEurope.HLISD.Lib.API' } ),
        baseurl => $uri->scheme . "://" . $uri->host . ":" . $uri->port . "/api/v1/contrib/hlisd"
    };

    bless $self, $class;
    return $self;
}

=head3 Order_PlaceOrder2

Make a call to the /Order_PlaceOrder2 API

=cut

sub Order_PlaceOrder2 {
    my ( $self, $metadata, $borrowernumber, $illrequest_id ) = @_;

    my $borrower = Koha::Patrons->find($borrowernumber);

    my @address1_arr =
        grep { defined && length $_ > 0 } ( $borrower->streetnumber, $borrower->address, $borrower->address2 );
    my $address1_str = join ", ", @address1_arr;

    # Request including passed metadata
    my $body = {
        illrequest_id   => $illrequest_id,
        orderdetail     => $metadata,
        deliveryprofile => {
            firstname   => substr( $borrower->firstname,     0, 50 ) || "",
            lastname    => substr( $borrower->surname,       0, 50 ) || "",
            address1    => substr( $address1_str,            0, 50 ) || "",
            city        => substr( $borrower->city,          0, 50 ) || "",
            statecode   => substr( $metadata->{statecode},   0, 2 )  || "",
            statename   => substr( $metadata->{statename},   0, 50 ) || "",
            zip         => substr( $metadata->{zipcode},     0, 50 ) || "",
            countrycode => substr( $metadata->{countrycode}, 0, 2 )  || "",
            phone       => substr( $borrower->phone,         0, 50 ) || "",
            fax         => substr( $borrower->fax,           0, 50 ) || "",
            email       => substr( $borrower->email,         0, 64 ) || "",
        }
    };

    my $request = HTTP::Request->new( 'POST', $self->{baseurl} . "/placeorder2" );

    $request->header( "Content-type" => "application/json" );
    $request->content( encode_json($body) );

    return $self->{ua}->request($request);
}

=head3 User_GetOrderHistory

Make a call to the /User_GetOrderHistory API

=cut

sub User_GetOrderHistory {
    my ( $self, $filter_type_id ) = @_;

    my $body = encode_json( { filterTypeID => $filter_type_id } );

    my $request = HTTP::Request->new( 'POST', $self->{baseurl} . "/getorderhistory" );

    $request->header( "Content-type" => "application/json" );
    $request->content($body);

    return $self->{ua}->request($request);
}

=head3 ArticleShelf_CheckAvailability

Make a call to the /ArticleShelf_CheckAvailability ReprinsDesk webservice

=cut

sub ArticleShelf_CheckAvailability {
    my ( $self, $ids_to_check ) = @_;

    my $body = encode_json($ids_to_check);

    my $request = HTTP::Request->new( 'POST', $self->{baseurl} . "/checkavailability" );

    $request->header( "Content-type" => "application/json" );
    $request->content($body);

    return $self->{ua}->request($request);
}


=head3 Order_GetPriceEstimate2

Make a call to the /Order_GetPriceEstimate2 ReprinsDesk webservice

=cut

sub Order_GetPriceEstimate2 {
    my ( $self, $params ) = @_;

    my $body = encode_json($params);

    my $request = HTTP::Request->new( 'POST', $self->{baseurl} . "/getpriceestimate" );

    $request->header( "Content-type" => "application/json" );
    $request->content($body);

    return $self->{ua}->request($request);
}

1;
