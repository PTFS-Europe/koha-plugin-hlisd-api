
use Try::Tiny;
use C4::Context;

use Koha::Patron::Attribute::Type;

my $ill_partner_category = C4::Context->preference('ILLPartnerCode') || 'IL';

try {
    Koha::Patron::Attribute::Type->new(
        {
            code        => 'hlisd_id',
            description => 'This record\'s ID in HLISD'
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
            authorised_value_category => 'YES_NO'
        }
    )->store;
} catch {
    print "Error: $_\n";
};

1;