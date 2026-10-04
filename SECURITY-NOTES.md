# Security notes

## Verdict

**Lab-assisted:** the local Adianti 7.4 model demonstrates an unauthenticated
authorization bypass caused by inconsistent routing sources. A mixed request
passes an allowed class through the outer gate and reaches a protected class
and method through inherited page dispatch.

This conclusion applies only to the code and containers in this repository.
The repository contains no production data, service addresses, captured
traffic, or third-party validation artifacts.

## Root cause

The outer application authorization decision reads `class` and `method` from
`$_REQUEST`. In this PHP runtime, POST or cookie values can shadow query values
in that merged structure. An allowed public `TPage` subclass is therefore
accepted by the outer gate.

The accepted page later enters `TPage::run()`, which reads `class` and `method`
again from `$_GET`. The original protected query route remains present and is
invoked without repeating the authorization decision. The authorization check
and the eventual method invocation therefore operate on different routes.

## Demonstrated local impact

The lab proves that the bypass can:

- invoke a protected canary method;
- invoke a side-effect-free framework method;
- establish a synthetic administrator session without supplying its password;
- read the administrator-only Users page; and
- reach a protected profile action that changes the synthetic account password.

The mutation workflow is bounded to loopback and restores the original
synthetic password before reporting success. It also confirms that unrelated
account fields remain unchanged.

## Preconditions

- An unauthenticated page accepted by the outer dispatcher must inherit the
  affected `TPage` behavior.
- The PHP request merge order must allow a second input source to shadow the
  query routing fields in `$_REQUEST`.
- A protected class and callable method must be present in the application.
- The protected method's own checks must not independently reject the action.

## Positive controls

- A mixed GET/POST request reaches the protected canary through each allowed
  carrier page.
- A mixed request reaches the framework reload method.
- The F001 helper establishes the synthetic administrator session and reads a
  protected administrator page.
- The opt-in mutation run proves the old/new password differential before and
  after both the change and restoration.

## Negative controls

- Direct unauthenticated requests to protected routes are denied.
- A fresh cookie jar cannot read the protected administrator page.
- A nonexistent account does not establish an authenticated session.
- An invalid CSRF token leaves the complete user record unchanged.
- After logout, the prior session cannot read the protected page.
- After restoration, the temporary password fails and the original synthetic
  password succeeds.
- Login injection strings remain inert through the prepared ORM path.
- `index.php` does not expose the raw dispatcher exception path.

## Secondary information disclosure

The raw front controller reflects an attacker-controlled method name. When a
method does not exist and display errors are enabled, the uncaught
`ReflectionException` discloses local paths, framework class names, and call
frames. The regression suite compares this response with the expected local
fixture and confirms that the shell controller does not return the same trace.

## Remediation

1. Parse routing fields once from one canonical request source.
2. Convert the route into an immutable value and use it for both authorization
   and invocation.
3. Apply a default-deny allowlist for unauthenticated classes and methods.
4. Repeat authorization immediately before dynamic invocation, including
   nested or inherited dispatch paths.
5. Reject routing fields from cookies and reject conflicting route values
   across query and form inputs.
6. Require explicit authentication and role checks inside sensitive account
   actions.
7. Catch reflection failures and return a generic error; keep detailed traces
   in server-side logs with display errors disabled.
8. Add regression tests for direct denial, mixed-source conflicts, fresh
   sessions, logout, invalid CSRF tokens, and password restoration.

See [`docs/VULNERABILITY.md`](docs/VULNERABILITY.md) for the owner-facing
finding and [`VALIDATION.md`](VALIDATION.md) for the complete local procedure.
