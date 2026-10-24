# Foundation execution evidence

## Status: COMPLETE for the four approved repairs only; P03 paused

Scope: approved `local/plan/plan-foundation.md`, P01–P03 only. The complete
3,365-line detailed plan and 279-line context pre-plan were read before writes.
The four approved corrections pass functional verification and fresh repair/
authentication review. P02 local task gates are restored, but the combined
identity-limit checklist's production source-IP/proxy qualification remains open.
The user limited this run to those fixes and explicitly paused P03. No whole
acceptance criterion or production qualification is closed. Earlier blockers
below are historical evidence, not current unresolved findings.

## Baseline

- Root: `/home/sony/www/ia/questify` (its own repository).
- `git status --short --branch`: `## No commits yet on main`.
- Staged and unstaged diffs were empty; no untracked application files existed.
- `git rev-parse --verify HEAD` failed as expected: no HEAD commit.
- Docker client and daemon: 28.3.2, linux/amd64.
- Shared host versions observed, not modified: Ruby 3.1.2 and Node 24.4.0.
- No applicable AGENTS.md was found in the project or ancestor paths.

## Executed verification

| Command/check | Actual result |
|---|---|
| `docker manifest inspect ruby:4.0.9-slim` | Available; amd64 manifest `sha256:d6ded695dfaaa7c6c374a166af4b2ae438e7b6ba09658114fccaf227e3468aa9` |
| `docker manifest inspect node:26.12.1-bookworm-slim` | Available; amd64 manifest `sha256:1884ec272c7c06aba7696262fb822dc602f8fa5eb978d03617d6bfe487d7ebac` |
| `docker manifest inspect postgres:17.6-bookworm` | Available; amd64 manifest `sha256:45cd22f8d32e189d245403954882f88e7a8714301fda80dab6da90f1265b25a3` |
| `docker compose config --quiet` | Passed |
| `docker compose build app` | Passed, including persistent Playwright browser binaries and OS dependencies |
| Pinned-container version commands | Ruby 4.0.9; RubyGems 4.0.20; Bundler 4.0.23; Node 26.12.1; npm 11.20.0 |
| Pinned Rails installation | Rails 8.1.4 installed inside the disposable container; native websocket-driver/nio4r extensions built |
| Approved external staging generator | Completed at `/tmp/opencode/questify-scaffold.PtIUmsst/questify` |
| Host `ruby bin/stage-scaffold /tmp/opencode/questify-scaffold.PtIUmsst/questify` | Failed before copying: `Errno::EACCES` resolving source |
| Container staging inspection | Staging parent is `drwx------ root:root`; required generated `storage/.keep` is absent |
| `ruby -c bin/stage-scaffold` | Passed on host and pinned container |
| PostgreSQL SQL version query | PostgreSQL 17.6 (Debian 17.6-2.pgdg12+1), x86_64 |

Built local test image ID:
`sha256:3f3e1693354bf00a807d998578615edb6d627e22b51e1430e89e645b44d096d6`.
It has no registry RepoDigest. Pulled PostgreSQL RepoDigest:
`postgres@sha256:f3bd19c606e442c3d7bdfa8002e03fe260a1023351e0ea4598032022b68dd6e3`.
Manifest availability and the tool image build do not establish application
compatibility, lock resolution, Bootsnap/pg/bcrypt builds, or behavioral GREEN.

## Stop conditions and required caller decisions

1. Review and amend the explicit transfer manifest: the approved generator uses
   `--skip-active-storage`, and its output does not contain `storage/.keep`.
   The plan explicitly requires stopping on a generated-manifest mismatch.
2. Approve a staging ownership/transfer execution correction: `mktemp` ran as
   container root and created an inaccessible 0700 staging parent. No ownership
   changes, permissions relaxation, or alternative transfer were attempted.
3. `.tool-versions` was created as approved but is globally ignored by
   `/home/sony/.gitignore_global`. The global `local` ignore remains intact.
   No ignore override or forced staging was performed.

No Rails scaffold files were copied. No dependency lockfile was created. No
R/F/B/E assertion or compiler RED/GREEN, queue persistence/restart, auth, CSRF,
limiter, race, browser, font-license, visual or installation claim is made.
P02/P03 and all acceptance criteria remain unverified.

## Local side effects retained

### Fix-only authorization and verification

Final fresh repair/authentication review: **Approved**, all four prior findings
Fixed, no open Critical or Important findings. The reviewer independently ran
23 Rails tests/229 assertions, 4 frontend tests, strict TypeScript and affected
Ruby syntax checks successfully. It traced account/bucket/token/session lock
ordering and namespace persistence/generation ordering. It did not independently
rerun historical RED, cleanup, full build or browser evidence. Its verify pass
was in-context rather than a second independent reviewer. Scope was exactly the
eight repair paths below, with earlier P02 transition code read as context.

Files touched in this fixes-only resume:

- `app/controllers/v1/identity_controller.rb` (login only)
- `frontend/src/boundary.ts`
- `test/integration/login_reset_concurrency_test.rb` (new)
- `frontend/src/test/boundary.test.ts` (new)
- `test/models/credential_token_test.rb`
- `test/integration/identity_limits_test.rb`
- `local/plan/plan-foundation.md` (globally ignored)
- `docs/foundation-verification.md`

Existing scaffold/untracked foundation output was preserved, not staged or
committed. No unrelated user changes were identified. No P03 files were added.

The user instructed “only fix them and don't implement p03 yet”. This resume
changed only the four findings, associated regressions and plan/evidence. P03
source/assets/UI/PWA remain absent. No setup tests, setup/reset invocation,
deployment, mail sending, branch/stage/commit/push or shared-toolchain edits.

Login/reset regressions use queue barriers, separate actual PostgreSQL
connections and lock-wait observation; no sleeps choose the ordering. Before the
fix: 2 tests/10 assertions, 2 expected behavioral failures, zero errors: stale
loaded credentials returned 200 instead of 401, and comparison-before-reset
minted an unrevoked session. After locking/reloading account credentials and
creating the session inside the same account lock: both pass. Combined existing
session/reset endpoint tests: 17 tests/185 assertions passed.

Browser boundary tests pause actual Dexie writes with deferred promises and
dispatch the existing cross-tab storage invalidation event. Initial test
instrumentation used the wrong per-instance Table prototype, causing timeouts;
that and a test `this` annotation were corrected before recording behavioral RED.
Clean RED: 2 failures, expected Error but got null (stale refresh resolved), no
unhandled errors. Then serial namespace writes plus generation validation/stale
resealing passed both interleavings. No type suppression or production UI added.

Test-clock fixtures now freeze at an explicit whole-second UTC instant, keeping
all production expiry/window comparisons unchanged. Token teardown deletes only
its exact UUID-linked fixture rows in a transaction and asserts all four model
scopes are absent. Token and identity-limit tests: 5 tests/43 assertions passed.

Residual cleanup removed only these two previously logged failed-test fixtures:

| Session | User | Account | Verified session creation UTC |
|---|---|---|---|
| b3f01332-20b5-4154-aa2a-b01bfe3c6c2f | 23dd29e6-3a29-4025-b433-60f2963278bc | 098b37b7-c58c-4900-a58e-0dc01b84737d | 2026-10-24T15:39:35.907523Z |
| a1a2949a-34c3-490c-a22d-2e4e1be7154c | 8fa93154-1ece-47e9-ac64-2120abca2f3b | 0b82d1fd-6986-46f8-adfd-fa43bb3e2a1f | 2026-10-24T15:39:38.092447Z |

Before deletion, each had exactly one session, zero tokens/provenance rows,
account kind and synthetic UUID@example.com address. Transactional cleanup
rechecked exact IDs/relationships/timestamps, locked rows and required exact
delete counts. Earlier orphan users without confidently attributable IDs were
not removed. No blanket table deletion/reset or PostgreSQL storage change.

`docker compose run --rm app bin/verify all`: **34 Rails tests/267 assertions,
zero failures/errors/skips; 4 frontend tests; strict TypeScript/Vite build; 1
unchanged P01 Playwright test passed**. Isolated `PARALLEL_WORKERS=1` token,
limiter and login/reset race suites: **5 tests/27 assertions**, zero failures/
errors/skips. This is repair verification, not P03 cross-tab browser/UI proof.

### Approved P02 prerequisite amendment execution

The caller supplied the approved sequencing amendment and explicit opt-out from
setup-specific tests. Only the approved Rails launcher replacement was made in
`bin/setup`; source inspection and pinned `ruby -c bin/setup` passed. Setup/reset
was not invoked. No setup test suite, fixture clone or proof database was created.
Startup commands and boundaries are documented in `docs/adr/0001-foundation.md`.

P02.1 real schema/models, including early unchanged LoginBucket, were installed.
Test `db:prepare` succeeded. Structural gate: 1 test/7 assertions, zero errors.
P02.2 approved cookie/guards installed; independent harness passed, root and /up
returned 200. P02.3 helper-free availability test failed exactly expected 200/
actual 404, one failure, zero errors. Real secure endpoints/routes/jobs/mailer
then passed 1 test/4 assertions; request prerequisites passed 1 test/8 assertions.
P02.4 unchanged browser boundary passed F (2 tests) and strict B build.

The amended P02.5 named negative regressions were each GREEN-first, not RED:
foreign object 1 test/16 assertions (including own GET/DELETE positive controls),
session boundaries 1/13, logout rotation 1/11. No insecure intermediate stage
was introduced. The selected-test commands emitted Minitest's advisory to use
`-i/--include` instead of the plan's `-n/--name`; filtering still selected 1 test.

### P02.5 failures and stop

Full R: **32 runs, 245 assertions, 2 failures, 1 error**, zero skips. Isolated
token plus limiter race run: **3 runs, 6 assertions, 1 failure, 1 error**.
The approved token teardown's association `delete_all` attempts to nullify a
NOT NULL user_id; user destruction also encounters cached restricted account.
The nontransactional failures leave synthetic test rows; no blanket cleanup was
attempted. The limiter concurrency admission test passed.

Token-expiry and recent-auth-window tests use relative travel from fractional
timestamps. A pinned Rails time-helper probe left 0.167232016 seconds before the
30-minute deadline and 0.167348623 seconds before the 15-minute boundary because
travel truncates subseconds. These setup/test precision problems were not counted
as legitimate security RED. No boundary assertion or policy was relaxed. Caller
must authorize deterministic test clocks and exact nontransactional cleanup.

### Fresh actual authentication/security review

A fresh code-reviewer reviewed all 94 Git-visible new files (P02 detailed; P01
boilerplate/locks skimmed) against this unborn repository and approved plan.
Verdict: **Requires Changes**, one Critical and three Important findings.
It independently reran 22 tests/194 assertions (foundation, credential delivery,
and limiter tests), strict TypeScript, two Vitest tests and Ruby syntax checks;
all selected checks passed. Known failing nontransactional tests were not rerun.
Findings use explicit code traces for concurrency; no race probe was executed.

Critical, `app/controllers/v1/identity_controller.rb:54–65`: login authenticates
the old password outside reset's account lock, then establishes its session.
A reset can acquire the account lock after that comparison, change the password,
revoke existing sessions and commit before login creates a new unrevoked session.
The new session therefore escapes successful reset revocation. This follows the
approved bodies, not an implementation policy change. Caller-authorized locking/
credential-revalidation amendment and deterministic overlapping regression needed.

Important, `frontend/src/boundary.ts:56–69`: activation can await seal persistence,
receive cross-tab invalidation, then resume and reactivate stale identity without
rechecking generation. Fix and interleaving test needed before P03 integration.
The other two Important findings are the clock and cleanup test blockers above.
No fixes beyond the approved work order were invented. P02.2/P02.3/P02.4 checkboxes
were reopened because their concurrency-sensitive guarantees remain unresolved.

The approved policy values remain unchanged. Retrospective lessons are returned
to the caller only, not persisted to a lessons file or memory.

### P02 sequencing stop and P01 code review

Before writing P02 production code, the approved named behavioral RED contract
was reconciled with current P01. A pinned test-environment integration probe
returned bootstrap status 404, users table absent, and Account model file absent.
The plan's expected named RED assumes existing insecure foreign/session access;
its supplied test helpers instead require identity models and successful login/
bootstrap first. Creating those tests directly cannot produce the stipulated
RED without additional prerequisite/test sequencing. Missing-model/setup errors
are expressly not valid behavioral RED. No permissive auth placeholder or
unapproved alternative RED was introduced. Caller must reconcile this narrow
test-first sequencing issue before P02; secure target behavior is unchanged.

A fresh code-reviewer reviewed all 70 new Git-visible files plus ignored
`.tool-versions`, explicitly against the unborn repository, not a parent HEAD.
Verdict: Approved with Comments for P01 only; zero Critical findings. It reran
Rails 2 tests/5 assertions, Vitest 2 tests, strict TypeScript, and Playwright
1 test successfully. It did not independently rerun build, original RED cycles,
contract probes or worker restart evidence. Authentication review is pending
because no authentication implementation exists.

Unresolved Important finding: generated `bin/setup:33` unconditionally starts
absent `bin/dev` unless `--skip-server` is supplied. The reviewer reproduced
ENOENT in the pinned container. Compose verification is unaffected. This generated
entrypoint needs a caller-authorized correction; no unplanned entrypoint change
was made. Its documentation-summary suggestion was resolved above. No branch,
stage, commit, push, deployment, real email, or shared-toolchain edits occurred.

### Approved type correction and independent P01 completion

The user approved bounded matcher/type/dependency compatibility correction.
Published Vitest 4.1.12 and @vitest/expect 4.1.12 declarations were inspected in
an external temporary directory: `Assertion<T = any>` matches jest-dom 7.0.1.
Registry metadata declares Vite 8 and Node 26-compatible ranges and returned no
deprecation notice. Vitest changed 5.0.5 → 4.1.12; tsconfig now uses the exported
`@testing-library/jest-dom/vitest` entry instead of its Jest default. All other
direct pins remain unchanged. The npm lockfile was regenerated normally.

Installation, strict typecheck with skipLibCheck false, and two React/IndexedDB
tests passed. The intentional compiler initializer then produced **only**
`src/harness.ts(1,14): TS2322: Type '2' is not assignable to type '1'`.
Restoring 1 gave successful strict compilation and Vite publication.
The browser fixture reached its intended assertion failure (expected 2,
received 1), then passed after restoring 1. No assertion was removed.

`docker compose run --rm app bin/verify all` passed before any P02/P03 code:
Rails 2 tests/5 assertions, React/IndexedDB 2 tests, strict TypeScript plus Vite
hashed-asset build, Playwright 1 browser test. Local-only list reporter and
trace/screenshot/video off remained unchanged. npm reported zero vulnerabilities;
no comprehensive security-audit claim is made.

All three JSON contracts passed JSONSchemer meta-schema validation; an identity
fixture was accepted and its forged owner extra rejected. These are contract
probes, not identity-endpoint proof.

Queue restart experiment: start the development worker, terminate it gracefully
using timeout/SIGTERM, enqueue a probe while stopped, confirm PostgreSQL row 1
and ready execution, restart the worker, then stop it again. The row had
`finished_at` set and no failed execution after restart. The separate Rails
queue test verified enqueue persistence. No worker remains running.

### Approved ownership amendment and P01.2 completion

The caller relayed explicit user approval for narrowly repairing this execution's
generated files/cache/dependency volumes and using host-compatible app identity.
Host UID/GID were reconfirmed as 1000:1000. Compose labels confirmed that
`questify_bundle` and `questify_node_modules` belong to this execution's project.
Only the five named generated files, frontend mount directories, development log,
`tmp/cache`, `/bundle`, and the mounted frontend dependencies were repaired via
the existing container. PostgreSQL storage and unrelated files were untouched.
Compose app identity is now `${LOCAL_UID:-1000}:${LOCAL_GID:-1000}`, with writable
HOME and Bundler configuration under `/bundle`. Privileged image builds remain
unchanged. A container-created `tmp/identity-proof/generated.txt` was observed as
1000:1000, and a host append succeeded. npm's generated lockfile is also 1000:1000.

The required queue config tuning then succeeded. `bundle check`, development
and test `db:prepare` succeeded. The test runner reported queue tables present,
Solid Queue adapter active, CSRF protection true, and test mail delivery adapter.
P01.2 checkboxes are now complete; queue durability/restart remains P01.5.

### P01.3 harness evidence and compiler blocker

`npm --prefix frontend install` succeeded inside the pinned app container:
113 packages added; npm reported zero vulnerabilities (not a comprehensive audit).

| Check | Observed result |
|---|---|
| Rails intentional assertion RED | `Expected: 1`, `Actual: 2`; one failure, zero errors |
| React intentional assertion RED | `expected 1 to be 2`; one failed assertion, IndexedDB test passed |
| Compiler probe with initializer 2 | Expected TS2322 occurred, **plus unrelated declaration errors**, so not accepted as clean compiler RED |
| Restored Rails harness | One test, one assertion, zero failures/errors/skips |
| Restored React/IndexedDB harness | Two tests passed |
| Restored strict typecheck | Still fails with TS2688 and TS2428 dependency/configuration errors |

Actual strict-typecheck errors after restoring the initializer:

```text
@testing-library/jest-dom/types/jest.d.ts(1,23): TS2688: Cannot find type definition file for 'jest'.
@testing-library/jest-dom/types/vitest.d.ts(5,13): TS2428: All declarations of 'Assertion' must have identical type parameters.
vitest/dist/chunks/config.d.QBNYCgFU.d.ts(1710,11): TS2428
vitest/dist/chunks/task-utils.d.PFh2BV6Q.d.ts(40,12): TS2428
```

Inspection confirms jest-dom's default type entry references Jest, while its
Vitest augmentation declares one `Assertion<T>` parameter; installed Vitest
5 declares two parameters, `Assertion<R, T>`. No skipLibCheck relaxation,
dependency changes, package patching, type suppression, or Node downgrade was
attempted. This requires caller-authorized compatibility correction.

P01.3 remains unchecked. Vite publication and browser tests have not run;
`frontend/e2e/harness.spec.ts` intentionally retains its planned `1` versus `2`
RED assertion awaiting a working build. P01.4/P01.5 and P02/P03 are not started.
The earlier blocker sections below are historical evidence, not current status.

### P01.2 attempted verification and new permission blocker

`docker compose run --rm app bundle install` succeeded: seven direct Gemfile
dependencies and 78 installed gems, with a generated `Gemfile.lock`. Bootsnap
1.26.0, bcrypt 3.1.22 and Puma 8.0.2 compiled; pg 1.7.0 installed its Linux
binary package. Application boot proceeded far enough for the Solid Queue
installer; application tests and database preparation have not run.

`docker compose run --rm app bin/rails solid_queue:install` succeeded and emitted
`config/queue.yml`, `config/recurring.yml`, `db/queue_schema.rb`, and `bin/jobs`,
and updated production queue configuration. Output was inspected. The subsequent
required patch to `config/queue.yml` failed:
`EACCES: permission denied, open '/home/sony/www/ia/questify/config/queue.yml'`.
The generated queue config and lockfile were observed as root-owned 0644.
No project ownership correction or alternative write was attempted. The approved
ownership amendment covered only the external staging tree, not project files.
P01.2 remains unchecked; its required queue tuning was not applied. Caller must
approve a narrowly scoped generated-file ownership/execution correction before
continuation. The installer runs as root under the approved Compose setup.

### Approved resume corrections

The user approved removing only `storage/.keep` from the generated transfer
manifest and correcting only the named staging tree's ownership. Host UID/GID
were inspected as 1000:1000. Through the existing container, `chown -R
1000:1000 /tmp/opencode/questify-scaffold.PtIUmsst` succeeded; its parent remains
0700, without world-readable permission changes. Generated credentials were not
copied or printed. The amended transfer succeeded, and all 31 manifest files
matched their staged originals byte-for-byte. Compose configuration and transfer
script syntax passed. The original failed attempt above remains historical evidence.

The built `questify-app` image, pulled PostgreSQL image, Compose network and
volumes (`questify_pgdata`, `questify_bundle`, `questify_node_modules`), running
`questify-db-1`, and external root-owned scaffold staging remain for the caller.
No application server or worker was started. No real mail, deployment, branch,
stage, commit, push, remote change, shared-toolchain change or reference-asset
change occurred.
