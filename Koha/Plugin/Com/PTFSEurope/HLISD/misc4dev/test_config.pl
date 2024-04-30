
use Try::Tiny;

use Koha::Patron::Attribute::Type;

try {
    Koha::Patron::Attribute::Type->new(
        {
            code => 'hlisd_id',
            description => 'Field to be used by HLISD plugin to match on library id'
        }
    )->store;
} catch {
    print "Error: $_\n";
};

try { 
    Koha::Patron::Attribute::Type->new(
        {
            code        => 'hlisd_toup',
            description =>
                'Field to be used by HLISD plugin to determine if update should happen or not for a given patron'
        }
    )->store;
} catch {
    print "Error: $_\n";
};

try {
    Koha::Patron::Attribute::Type->new(
        {
            code        => 'hlisd_chan',
            description =>
                'Field to be used by HLISD plugin to store HLISD changelog',
            repeatable  => 1
        }
    )->store;
} catch {
    print "Error: $_\n";
};

1;