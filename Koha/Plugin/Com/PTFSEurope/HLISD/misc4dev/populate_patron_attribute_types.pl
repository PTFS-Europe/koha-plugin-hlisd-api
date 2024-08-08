
use Try::Tiny;
use C4::Context;

use Koha::Patron::Attribute::Type;
use Koha::Patron::Attributes;

my $ill_partner_category = C4::Context->preference('ILLPartnerCode') || 'IL';

try {
    Koha::Patron::Attribute::Type->new(
        {
            code          => 'hlisd_id',
            description   => 'This record\'s ID in HLISD',
            class         => 'HLISD',
            category_code => $ill_partner_category
        }
    )->store;
} catch {
    print "Error: $_\n";
};

try {
    Koha::Patron::Attribute::Type->new(
        {
            code                      => 'hlisd_update',
            description               => 'Perform HLISD update?',
            authorised_value_category => 'YES_NO',
            class                     => 'HLISD',
            category_code             => $ill_partner_category
        }
    )->store;
} catch {
    print "Error: $_\n";
};

1;
