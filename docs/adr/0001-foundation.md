# Foundation architecture

Rails 8.1.4 serves a same-origin React/TypeScript/Vite application and JSON API.
PostgreSQL owns identities, sessions, credential transitions and shared rolling
abuse counters; Solid Queue provides durable jobs without Redis. Browser-private
namespaces are distinct from public service-worker assets.

Ruby 4.0.9 and Node 26.12.1 are isolated in project containers. Node 26's scheduled
LTS transition is not proof of production readiness; recheck release/security
status before separately authorized deployment. Vitest 4.1.12 was selected after
actual strict declaration incompatibility with 5.0.5 and jest-dom 7.0.1.

Local application commands use host-compatible `LOCAL_UID`/`LOCAL_GID` (1000:1000
defaults), HOME and Bundler configuration under the execution-owned bundle volume.
On another host, export these variables from `id -u` and `id -g` first.

Interactive startup: `docker compose run --rm --service-ports app bin/setup`.
Setup without server: `docker compose run --rm app bin/setup --skip-server`.
The launcher edit receives source/syntax verification only; setup-specific
automated tests were explicitly declined. Do not invoke destructive reset for
verification. Functional verification uses `docker compose run --rm app bin/verify all`.

Optional guest identity is not a verified account. Registration records immutable
guest provenance, but verification does not import data or switch ownership.
Existing-account login from a guest remains blocked pending P09 export/discard UX.
Complete authentication screens, product tasks, cloud synchronization, privacy
lifecycles and real-device qualification remain later work.

Credentials use encrypted cookies, server session expiry/revocation, real CSRF,
single-use expiring token digests and encrypted delivery payloads. Jobs carry UUIDs
only. Local mail uses the test adapter; no real SMTP is configured or authorized.
Northflank and Brevo are future provider selections, not provisioning permission.

See `docs/foundation-verification.md` for actual evidence and limitations. Foundation
tests cannot close whole CA-037/042/044/045 or establish public-release readiness.
