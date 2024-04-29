package Koha::Plugin::Com::PTFSEurope::HLISD;

use Modern::Perl;
use strict;
use warnings;

use base            qw(Koha::Plugins::Base);
use Koha::DateUtils qw( dt_from_string );

use JSON qw( encode_json decode_json );
use File::Basename qw( dirname );
use C4::Installer;
use Cwd            qw(abs_path);
use CGI;
use JSON qw( decode_json );

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



1;
