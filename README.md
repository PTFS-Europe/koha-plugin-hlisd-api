# koha-plugin-hlisd-api
[HLISD (Health Library & Information Services Directory)](https://hlisd.org/) integration Koha plugin

This plugin iterates on patrons from the category in the **ILLPartnerCode** system preference and updates their information details from data coming from HLISD.

It also utilizes patron attribute types to govern the harvest logic.

## Dev and setup

The script at `misc4dev/populate_patron_attribute_types.pl` creates the required patron attribute types for testing/dev.

To run the cron script to harvest data from HLISD:

```bash
perl harvest_hlisd.pm --debug
```

## HLISD API
Docs: https://hlisd.org/api-docs/index.html

Credentials sign-up: https://hlisd.org/api_registration

## Diagram
![HLISD](https://github.com/PTFS-Europe/koha-plugin-hlisd-api/blob/main/HLISD.jpg?raw=true)

### This plugin is sponsored by NHS E (National Health Service England)
