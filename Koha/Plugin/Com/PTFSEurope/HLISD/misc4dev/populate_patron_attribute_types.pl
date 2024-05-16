
use Try::Tiny;

use Koha::Patron::Attribute::Type;

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