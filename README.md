# Adianti 7.4 dispatcher authorization bypass lab

This repository is a disposable, local-only lab for reproducing a mixed-source
authorization bypass in an Adianti 7.4 dispatcher. It contains synthetic
application code, synthetic records, and regression tests. It is suitable for
private source review, demonstrations, and remediation testing.

The web service is published only on `127.0.0.1:18080`. The database is not
published to the host. Test and validation scripts reject non-loopback base
URLs.

## What the lab demonstrates

The outer dispatcher reads routing fields from PHP's merged `$_REQUEST`, while
an inherited `TPage::run()` path reads a second route from `$_GET`. A request
can therefore present an allowed page to the outer authorization gate while
retaining a protected class and method in the query string for the inner
dispatch.

The lab demonstrates the resulting authorization failure with:

- a protected canary method;
- a framework reload method that does not depend on the canary;
- a protected account impersonation action;
- an administrator-only Users page;
- a CSRF-protected profile password workflow; and
- direct, fresh-session, invalid-CSRF, and post-logout controls.

The detailed finding and remediation guidance are in
[`docs/VULNERABILITY.md`](docs/VULNERABILITY.md). The validation procedure is in
[`VALIDATION.md`](VALIDATION.md).

## Safety boundary

- Use only `http://127.0.0.1:18080` or an equivalent loopback URL.
- Do not expose the Compose service on a non-loopback interface.
- Do not adapt the F001 helper to accept remote hosts.
- All accounts and records in the lab are synthetic.
- The optional password-change demonstration must restore the original lab
  password before it reports success.
- Remove the database volume after testing to discard all runtime state.

## Requirements

- Docker with Compose v2
- `curl`
- Python 3 for the F001 workflow
- Bash for the regression scripts

## Start the lab

From this directory:

```bash
docker compose down -v --remove-orphans
docker compose up -d --build --wait
docker compose ps
```

Open <http://127.0.0.1:18080/>.

The seeded administrator account is:

```text
login:    admin
password: LabAdmin!740
```

These credentials exist only for the disposable lab.

## Run the regression suite

```bash
./tests/all.sh
```

The suite covers static dispatcher anchors, expected application behavior,
negative injection controls, repeated authentication failures, and the
mixed-source authorization bypass. Individual scripts can also be run:

```bash
./tests/static-audit.sh
./tests/parity.sh
./tests/extended.sh
./tests/bruteforce-control.sh
./tests/dispatcher-authorization-bypass.sh
./tests/f001-admin-access.sh
```

The HTTP scripts default to `http://127.0.0.1:18080`. If `B` is supported by a
script, it must still name a loopback host.

## Run the F001 workflow

The default run is read-only:

```bash
mkdir -p tests/.tmp
python3 tools/f001_admin_access.py \
  --base-url http://127.0.0.1:18080 \
  --login admin \
  --page-output tests/.tmp/admin-users.html \
  --output tests/.tmp/f001-read.json
```

It verifies that direct unauthenticated access is denied, uses the dispatcher
bypass to establish the synthetic administrator session, reads the protected
Users page, proves that a fresh session cannot read the same page, logs out,
and proves post-logout denial.

The reversible mutation run is explicit:

```bash
python3 tools/f001_admin_access.py \
  --base-url http://127.0.0.1:18080 \
  --login admin \
  --change-and-restore \
  --current-password 'LabAdmin!740' \
  --page-output tests/.tmp/admin-users-change.html \
  --output tests/.tmp/f001-change.json
```

This workflow generates a temporary password in memory and proves the complete
state transition:

1. The original password authenticates and the temporary password does not.
2. An invalid-CSRF control leaves the account unchanged.
3. The protected profile action changes the password.
4. The original password fails, while the temporary password authenticates and
   reaches a protected identity page.
5. A fresh CSRF token is obtained and the original password is restored.
6. The temporary password fails, while the original password authenticates
   again and reaches the protected page.
7. Non-password account fields remain unchanged and all sessions are closed.

The helper must return a failure if restoration cannot be proved. If a run is
interrupted, discard the local database volume and recreate the lab before
continuing.

To inspect the loopback requests in Burp, keep the lab on port 18080 and use
Burp's listener on port 8080:

```bash
python3 tools/f001_admin_access.py \
  --base-url http://127.0.0.1:18080 \
  --login admin \
  --proxy http://127.0.0.1:8080
```

## Cleanup

```bash
docker compose down -v --remove-orphans
rm -rf tests/.tmp
```

The volume removal restores the lab to its seeded state on the next start.

## Repository layout

- `www/`: local application and vendored framework subset
- `seed.sql`: synthetic database schema and records
- `tests/`: local regression and control scripts
- `tools/f001_admin_access.py`: loopback-only F001 demonstration
- `SECURITY-NOTES.md`: evidence boundary and concise security notes
- `SOURCE-PROVENANCE.md`: origin and reconstruction boundary
- `VALIDATION.md`: reproducible validation procedure
