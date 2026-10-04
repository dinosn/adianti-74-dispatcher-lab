# Repository working rules

- Keep every HTTP validation destination on loopback.
- Keep the web service bound to `127.0.0.1` and the database unpublished.
- Use only the synthetic identities and credentials defined in `seed.sql`.
- Do not add customer names, remote service addresses, captured traffic,
  session values, credentials, or engagement evidence.
- Password mutation tests must restore the fixture credential and verify the
  restored login before reporting success.
- Keep generated evidence under ignored `artifacts/` or `tests/.tmp/` paths.
- Preserve the vendored framework license in `www/lib/ADIANTI-LICENSE`.
