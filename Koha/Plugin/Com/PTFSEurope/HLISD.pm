package Koha::Plugin::Com::PTFSEurope::HLISD;

use Modern::Perl;
use strict;
use warnings;

use base            qw(Koha::Plugins::Base);
use Koha::DateUtils qw( dt_from_string );

use JSON           qw( encode_json decode_json );
use File::Basename qw( dirname );
use C4::Installer;
use Cwd qw(abs_path);
use CGI;
use JSON qw( decode_json );
use C4::Context;

use Koha::Plugin::Com::PTFSEurope::HLISD::Lib::API;

our $VERSION = "1.0.0";

our $metadata = {
    name            => 'HLISD API',
    author          => 'PTFS-Europe',
    date_authored   => '2024-04-26',
    date_updated    => '2024-04-26',
    minimum_version => '24.05.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'HLISD integration plugin'
};

=head3 new

Required I<Koha::Plugin> method

=cut

sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    $self->{config} = decode_json( $self->retrieve_data('hlisd_config') || '{}' );

    my $api = Koha::Plugin::Com::PTFSEurope::HLISD::Lib::API->new( $self->{config} );
    $self->{_api} = $api;

    return $self;
}

=head3 configure

Optional I<Koha::Plugin> method if it implements configuration

=cut

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template( { file => 'configure.tt' } );

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            config => $self->{config},
        );

        $self->output_html( $template->output() );
    } else {
        my $hashed = { map { $_ => ( scalar $cgi->param($_) )[0] } $cgi->param };

        $self->store_data( { hlisd_config => scalar encode_json($hashed) } );
        $self->go_home();
    }
}

sub install() {
    return 1;
}

sub upgrade {
    my ( $self, $args ) = @_;

    my $dt = dt_from_string();
    $self->store_data( { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') } );

    return 1;
}

sub uninstall() {
    return 1;
}

=head3 harvest_hlisd

TODO: Implement the code to actually do the harvesting, see the TODO comment in the code

=cut

sub harvest_hlisd {
    my ( $self, $args ) = @_;

    $self->_config_check();

    my $patrons = $self->_get_patrons();

    debug_msg(
        $args->{debug},
        sprintf( "Found %d %s patrons", $patrons->count(), C4::Context->preference('ILLPartnerCode') ));

    while ( my $patron = $patrons->next ) {

        #TODO: Get library id from patron attribute type configured

        #TODO: call LibraryDetails API

        # my $plugin = Koha::Plugin::Com::PTFSEurope::HLISD->new();
        # my $api    = $plugin->{_api};
        # my $res    = $api->LibraryDetails(3610);

        # if ( $res->is_success ) {
        #     debug_msg(
        #         $args->{debug},
        #         sprintf( "Harvesting data for patron #%s - %s", $patron->borrowernumber, $patron->surname )
        #     );

        #     my $data = decode_json( $res->decoded_content() );

        #     if ( $data->{status} eq 'success' && $data->{data} ) {
        #         $self->store_data(
        #             {
        #                 patron_id  => $patron->borrowernumber,
        #                 hlisd_data => encode_json( $data->{data} ),
        #             }
        #         );
        #     } else {
        #         debug_msg(
        #             $args->{debug},
        #             sprintf(
        #                 "HL-ISD API returned error for patron #%s - %s", $patron->borrowernumber, $patron->surname
        #             )
        #         );
        #     }

        # } else {
        #     debug_msg(
        #         $args->{debug},
        #         sprintf( "HL-ISD API request failed for patron #%s - %s", $patron->borrowernumber, $patron->surname )
        #     );
        # }
    }
}

=head3 debug_msg

 Prints a debug message to STDERR if debug mode is enabled.

 Parameters:
 - $msg: The message to be printed. If it is a hash reference, it will be converted to a string using Data::Dumper.

 Returns: None.

=cut

sub debug_msg {
    my ( $debug, $msg ) = @_;

    if ( !$debug ) {
        return;
    }

    if ( ref $msg eq 'HASH' ) {
        use Data::Dumper;
        $msg = Dumper $msg;
    }
    print STDERR "$msg\n";
}

=head3 _get_patrons

 Retrieves patrons from the database based on the partner code set in the system preferences.
 
 Parameters:
 - $self: The object instance of the class.
 
 Returns:
 - Koha::Patrons: A collection of patrons.

=cut

sub _get_patrons {
    my ($self) = @_;

    my $partner_code = C4::Context->preference('ILLPartnerCode');
    unless ($partner_code) {
        die "ERROR: No ILL partner code set. Please set the ILLPartnerCode system preference.";
    }

    my $patrons = Koha::Patrons->search( { categorycode => $partner_code } );
    unless ( scalar @{ $patrons->as_list() } ) {
        die "ERROR: No ILL partner patrons found.";
    }

    return $patrons;
}

=head3 _config_check

 Checks if the HL-ISD API credentials are set in the configuration.
 If not, it prints a debug message and returns.

 Parameters:
 - $self: The object instance.

 Returns: None.

=cut

sub _config_check {
    my ($self) = @_;

    my $config = $self->{config};

    unless ( $config->{email} && $config->{password} ) {
        die "HL-ISD API credentials not set, skipping harvest";
    }

    
}

1;
