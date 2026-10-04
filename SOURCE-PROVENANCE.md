# Source provenance

## Adianti Framework

The vendored framework subset under `www/lib` was selected from the public
`plenatech/adianti_framework` repository at tag `7.4.1`. The included
`www/lib/VERSION` file reports framework version `7.4`.

That repository identifies itself as an unofficial redistribution. The lab
therefore uses it as a version-matched implementation reference. It does not
claim that the files are identical to any separately deployed application.

The Adianti license supplied with the source is retained at
`www/lib/ADIANTI-LICENSE`.

## Selection boundary

The upstream sample application, top-level diagnostic routes, Composer
dependencies, and network-capable helpers were not copied into the served
application. Legacy directly executable service classes that were unnecessary
for the dispatcher demonstration were also excluded.

The served shell references local assets only. The database is not published
to the host, and the web service is bound to loopback.

## Lab-owned reconstruction

Files outside the vendored `www/lib` subtree are local lab code or fixtures,
including:

- front controllers and bootstrap code;
- public carrier pages and protected demonstration classes;
- the synthetic user model and schema;
- Compose and web-server configuration;
- regression tests and the F001 helper; and
- all repository documentation.

The reconstructed application contains no production business logic, customer
records, captured requests, remote service addresses, or reused credentials.
The seeded `admin` / `LabAdmin!740` account is synthetic.

## Container runtime

The lab uses PHP 7.4 with Apache and MySQL 5.7 to preserve the request-merging
and framework behavior exercised by the regression suite. Container versions
are defined by the Dockerfile and Compose file; those files are authoritative
for a given checkout.

## Maintenance rule

When framework or container versions change, rerun the full clean-start
procedure in `VALIDATION.md`. Update this document only when the source origin,
vendored boundary, or reconstructed-file boundary changes.
