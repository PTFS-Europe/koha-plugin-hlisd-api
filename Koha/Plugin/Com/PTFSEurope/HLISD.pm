package Koha::Plugin::Com::PTFSEurope::HLISD;

use Modern::Perl;
use strict;
use warnings;

use base qw(Koha::Plugins::Base);

use JSON           qw( encode_json decode_json );
use File::Basename qw( dirname );
use Cwd            qw(abs_path);
use CGI;

use Term::ANSIColor;
use C4::Installer;
use C4::Context;

use Koha::Plugin::Com::PTFSEurope::HLISD::Lib::API;
use Koha::DateUtils qw( dt_from_string );
use Koha::Patron::Attributes;
use Koha::Library;
use Koha::Libraries;

our $VERSION = "1.2.4";

our $metadata = {
    name            => 'HLISD API',
    author          => 'PTFS-Europe',
    date_authored   => '2024-04-26',
    date_updated    => '2024-08-01',
    minimum_version => '23.11.00.000',
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

    $self->{config} =
      decode_json( $self->retrieve_data('hlisd_config') || '{}' );

    my $api =
      Koha::Plugin::Com::PTFSEurope::HLISD::Lib::API->new( $self->{config} );
    $self->{_api} = $api;

    $self->{debug} = $args->{debug};
    $self->{type} = $args->{type};
    $self->{mode} = $args->{mode};

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
        $template->param( config => $self->{config}, );

        $self->output_html( $template->output() );
    }
    else {
        my $hashed =
          { map { $_ => ( scalar $cgi->param($_) )[0] } $cgi->param };

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
    $self->store_data(
        { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') } );

    return 1;
}

sub uninstall() {
    return 1;
}

=head3 harvest_hlisd

Method that handles a HLISD harvest

=cut

sub harvest_hlisd {
    my ($self) = @_;

    return unless $self->runtime_params_check();

    $self->plugin_config_check();

    if ( $self->{type} eq 'patron' && $self->{mode} eq 'update' ) {
        $self->harvest_patrons();
    }
    elsif ( $self->{type} eq 'library' && $self->{mode} eq 'create' ) {
        $self->harvest_libraries();
    }
    else {
        $self->log->error( "Invalid harvest type '" . $self->{type} . "' or mode '" . $self->{mode} . "'" );
    }
}

=head3 harvest_libraries

Method that handles a HLISD library harvest

This method retrieves a list of libraries from the HLISD API and creates
new libraries in Koha based on the mapping between Koha and HLISD fields.

DEV ONLY: Run the following SQL to delete all libraries where branchcode is numeric (this assumes that all libraries where branchcode is numeric have been imported through this method):
    DELETE FROM branches WHERE branchcode REGEXP '^[0-9]+$';

=cut

sub harvest_libraries {
    my ($self) = @_;

    my $res = $self->{_api}->Libraries();
    my $libraries = $res->{data};

    my $mapping = $self->koha_library_to_hlisd_mapping();
    my $importlibrariesstartingwith = $self->{config}->{importlibrariesstartingwith} || '';

    foreach my $library (@$libraries) {

        next if $importlibrariesstartingwith && !$library->{attributes}->{'document-supply'};
        next if $importlibrariesstartingwith
            and not grep { $library->{attributes}->{'document-supply'} =~ /^\Q$_\E/i }
                map { s/^\s+|\s+$//gr } split /,/, $importlibrariesstartingwith;

        my $hlisd_field = $self->get_HLISD_library_field('branchname');
        my $koha_library = Koha::Libraries->find(
            {
                branchcode => $library->{id}
            }
        );

        my $prepend = $library->{attributes}->{'document-supply'};
        $prepend = substr( $prepend, 0, index( $prepend, ';' ) ) if ( index( $prepend, ';' ) != -1 );

        if($koha_library){
            $self->debug_msg(
                sprintf(
                    "Library %s already exists. Skipping",
                    $library->{id}
                )
            );
            next;
        }

        my $address = $library->{attributes}->{ $self->get_HLISD_library_field('branchaddress1') };
        $address =~ s/,//g;

        my @address_split = split( /\r\n/, $address );
        my @address_lines = map { $_ =~ s/^\s+|\s+$//gr } @address_split;

        my $final_address = join( ', ', @address_lines );

        $self->debug_msg( sprintf( "Importing %s", $library->{id} ) );
        my $library = Koha::Library->new(
            {
                branchcode => $library->{id},
                branchname => $prepend
                    . ' - ' . $library->{attributes}->{ $self->get_HLISD_library_field('branchname') },
                branchaddress1 => $final_address,
                branchzip => $library->{attributes}->{$self->get_HLISD_library_field('branchzip')},
                branchemail => $library->{attributes}->{$self->get_HLISD_library_field('branchemail')},
                branchillemail => $library->{attributes}->{$self->get_HLISD_library_field('branchillemail')},
                branchcountry => $library->{attributes}->{$self->get_HLISD_library_field('branchcountry')},
                branchurl => $library->{attributes}->{$self->get_HLISD_library_field('branchurl')},
            }
        )->store();
    }
}

=head3 get_HLISD_library_field

Returns the value of the HLISD library field corresponding to the given Koha field.

=cut

sub get_HLISD_library_field {
    my ( $self, $koha_field ) = @_;

    my $mapping = $self->koha_library_to_hlisd_mapping();
    my @hlisd_field = grep { $_->{$koha_field} } @{$mapping};
    return $hlisd_field[0]->{$koha_field};
}

=head3 harvest_patrons

Method that handles a HLISD patron harvest

This method retrieves a list of libraries from the HLISD API and updates
their respective patrons' attributes in Koha based on the mapping between Koha and HLISD fields.

=cut

sub harvest_patrons {
    my ($self) = @_;
    $self->patron_attribute_types_check();

    my $patrons = $self->_get_patrons();

    $self->debug_msg(
        sprintf(
            "Found %d %s patrons",
            $patrons->count(), C4::Context->preference('ILLPartnerCode')
        )
    );

    while ( my $patron = $patrons->next ) {

        my $libraryidfield_type =
          $patron->get_extended_attribute( $self->{config}->{libraryidfield} );

        unless ($libraryidfield_type) {
            $self->debug_msg(
                "No library ID field data found for patron " . $patron->borrowernumber );
            next;
        }

        my $library_id = $libraryidfield_type->attribute;

        my $res = $self->{_api}->LibraryDetails($library_id);

        if ( !$res->{data} ) {
            $self->debug_msg(
                sprintf(
                    "Empty data returned for patron #%s - %s",
                    $patron->borrowernumber, $patron->surname
                )
            );
            next;
        }

        $self->debug_msg(
            sprintf(
                "\nChecking data for patron #%s - %s",
                $patron->borrowernumber, $patron->surname
            )
        );

        my $mapping = $self->koha_patron_to_hlisd_mapping();

        for my $mapping_item ( @{$mapping} ) {
            my $koha_field  = ( keys %{$mapping_item} )[0];
            my $hlisd_field = ( values %{$mapping_item} )[0];

            my $koha_value = $patron->$koha_field;
            $koha_value =~ s/^\s+|\s+$//g;

            my $hlisd_value = $res->{data}->{attributes}->{$hlisd_field};
            $hlisd_value =~ s/^\s+|\s+$//g;

            $self->debug_msg(
                sprintf(
                    "  Comparing '%s' (%s) and '%s' (%s): %s and %s",
                    $koha_field,
                    colored( 'Koha', 'green' ),
                    $hlisd_field,
                    colored( 'HLISD', 'blue' ),
                    (
                        defined $koha_value ? colored( $koha_value, 'green' )
                        : '(undef)'
                    ),
                    (
                        defined $hlisd_value ? colored( $hlisd_value, 'blue' )
                        : '(undef)'
                    )
                )
            );

            unless ( defined $koha_value
                && defined $hlisd_value
                && lc $koha_value eq lc $hlisd_value )
            {
                $patron->$koha_field($hlisd_value);
                $patron->store;

                $self->debug_msg(
                    colored( "  MISMATCH: ", 'yellow' )
                      . sprintf(
                        "Updated %s for patron #%s - %s",
                        $koha_field, $patron->borrowernumber,
                        $patron->surname
                      )
                );
            }
        }
    }
}

=head3 debug_msg

 Prints a debug message to STDERR if debug is enabled.

 Parameters:
 - $msg: The message to be printed. If it is a hash reference, it will be converted to a string using Data::Dumper.

 Returns: None.

=cut

sub debug_msg {
    my ( $self, $msg ) = @_;

    if ( !$self->{debug} ) {
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
 
 Returns:
 - Koha::Patrons: A collection of patrons.

=cut

sub _get_patrons {
    my ($self) = @_;

    my $partner_code = C4::Context->preference('ILLPartnerCode');
    die
"No ILL partner code set. Please set the ILLPartnerCode system preference."
      unless $partner_code;

    my $patrons = Koha::Patrons->search( { categorycode => $partner_code } );
    die "No ILL partner patrons found." unless scalar @{ $patrons->as_list() };

    my $patrons_to_update = Koha::Patron::Attributes->search(
        {
            'me.code'      => $self->{config}->{toupdatefield},
            'me.attribute' => 1
        },
        { join => 'borrower_attribute_types' }
    )->_resultset()->search_related('borrowernumber');
    die "No patron records set to update." unless $patrons_to_update->count;

    my $ill_partner_patrons =
      $patrons_to_update->search( { categorycode => $partner_code } );
    die "No ILL partner patrons found." unless $ill_partner_patrons->count;

    my $patrons_to_return = Koha::Patrons->_new_from_dbic($ill_partner_patrons);

    return $patrons_to_return;
}

=head3 plugin_config_check

Checks that the necessary plugin configuration has been set.

Throws a die() statement if any of the necessary configuration is missing.

=cut

sub plugin_config_check {
    my ($self) = @_;

    die "HLISD API email not set"    unless $self->{config}->{email};
    die "HLISD API password not set" unless $self->{config}->{password};

    if ( $self->{type} eq 'patron' ) {
        die "Patron attribute type field for 'Library ID' not set"
          unless $self->{config}->{libraryidfield};
        die "Patron attribute type field for 'To update' not set"
          unless $self->{config}->{toupdatefield};
    }
}

=head3 patron_attribute_types_check

Checks that the necessary patron attribute types have been set.

Throws a die() statement if any of the necessary patron attribute types is missing.

=cut

sub patron_attribute_types_check {
    my ($self) = @_;

    die "Patron attribute type '"
      . $self->{config}->{libraryidfield}
      . "' to map to 'Library ID' not found"
      unless Koha::Patron::Attribute::Types->find(
        { code => $self->{config}->{libraryidfield} } );

    die "Patron attribute type '"
      . $self->{config}->{toupdatefield}
      . "' to map to 'To update' not found"
      unless Koha::Patron::Attribute::Types->find(
        { code => $self->{config}->{toupdatefield} } );
}

=head3 koha_patron_to_hlisd_mapping

Maps the Koha borrowers column names to the names used in the HLISD API.

Returns a hash reference where the key is the Koha attribute name and the
value is the HLISD attribute name.

HLISD attributes example return:
    'lms'                     => 'koha',
    'telephone'               => '21312123',
    'collections-description' => '',
    'organisation'            => 'Organisation multiple word text',
    'longitude'               => '0.98765',
    'created-at'              => '2018-03-27T10:35:49.799Z',
    'document-supply'         => 'ABC',
    'email'                   => 'example@email.com',
    'updated-at'              => '2024-03-09T12:47:43.931Z',
    'postcode'                => 'ZIP CODE',
    'address'                 => 'Some Address',
    'opening-times'           => 'Mon-Fri: 9.00 - 17.00',
    'facebook'                => '',
    'accessibility'           => '',
    'import-key'              => '1234',
    'fax'                     => '',
    'twitter'                 => 'https://twitter.com/someurl',
    'website'                 => '',
    'name'                    => 'Organisation name multiple word text',
    'access-policy'           => '',
    'directions'              => '',
    'latitude'                => '12.12314',
    'country'                 => 'Country',
    'description'             => undef,
    'region-id'               => 5

=cut

sub koha_patron_to_hlisd_mapping {
    my ($self) = @_;

    return [
        { 'phone'   => 'telephone' },
        { 'email'   => 'email' },
        { 'address' => 'address' },
        { 'surname' => 'name' },
        { 'zipcode' => 'postcode' }
    ];
}

=head3 koha_patron_to_hlisd_mapping

Maps the Koha branch column names to the names used in the HLISD API.

Returns a hash reference where the key is the Koha attribute name and the
value is the HLISD attribute name.

=cut

sub koha_library_to_hlisd_mapping {
    my ($self) = @_;

    return [
        { 'branchcode'     => 'import-key' },
        { 'branchname'     => 'name' },
        { 'branchaddress1' => 'address' },
        { 'branchzip'      => 'postcode' },
        { 'branchemail'    => 'email' },
        { 'branchillemail' => 'email' },
        { 'branchcountry'  => 'country' },
        { 'branchurl'      => 'website' },
    ];
}

=head3 runtime_params_check

Checks the runtime parameters and sets default values if they are not set

=cut

sub runtime_params_check {
    my ($self) = @_;

    return 0 unless ( $self->{type} && ( $self->{type} eq 'patron' || $self->{type} eq 'library' ) );
    return 0 unless ( $self->{mode} && ( $self->{mode} eq 'update' || $self->{mode} eq 'create' ) );
    return 1;
}

1;
