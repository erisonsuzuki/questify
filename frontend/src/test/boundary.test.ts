import Dexie from "dexie";
import { afterEach, expect, it, vi } from "vitest";
import { BoundaryDatabase, refreshIdentity } from "../boundary";
import type { Bootstrap } from "../identity";

function deferred() {
  let resolve!: () => void;
  const promise = new Promise<void>(done => { resolve = done; });
  return { promise, resolve };
}

function identity(id: string): Bootstrap {
  return {
    user: { id, kind: "guest", namespace: `user:${id}` },
    capabilities: { online_authority: true, verified_account: false },
    csrf_token: "synthetic-csrf"
  };
}

function respond(value: Bootstrap): Response {
  return new Response(JSON.stringify(value), { headers: { "Content-Type": "application/json" } });
}

function invalidate() {
  globalThis.dispatchEvent(new StorageEvent("storage", { key: "questify-identity-invalidated" }));
}

afterEach(() => {
  vi.restoreAllMocks();
  invalidate();
});

for (const boundary of ["old namespace seal", "next namespace activation"] as const) {
  it(`invalidation during ${boundary} cannot resurrect identity`, async () => {
    const a = identity(crypto.randomUUID());
    const b = identity(crypto.randomUUID());
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(respond(a));
    await refreshIdentity();
    const observer = new BoundaryDatabase();
    const entered = deferred();
    const release = deferred();
    const prototype: typeof observer.namespaces = Object.getPrototypeOf(Object.getPrototypeOf(observer.namespaces));
    const original = prototype.put;
    let held = false;
    const put = vi.spyOn(prototype, "put").mockImplementation(function (this: typeof observer.namespaces, row, key) {
      const result = original.call(this, row, key);
      const target = boundary === "old namespace seal"
        ? row.namespace === a.user?.namespace && row.sealed
        : row.namespace === b.user?.namespace && !row.sealed;
      if (!held && target) {
        held = true;
        return result.then(value => {
          entered.resolve();
          return Dexie.Promise.resolve(release.promise).then(() => value);
        });
      }
      return result;
    });
    fetchMock.mockResolvedValueOnce(respond(b));
    const refreshing = refreshIdentity();
    const outcome = refreshing.then(() => null, (error: unknown) => error);
    try {
      await entered.promise;
      invalidate();
      release.resolve();
      const error = await outcome;
      expect(error).toBeInstanceOf(Error);
      expect(error).toHaveProperty("message", "stale_identity_response");
      expect((await observer.namespaces.get(a.user!.namespace))?.sealed).toBe(true);
      expect((await observer.namespaces.get(b.user!.namespace))?.sealed).not.toBe(false);
    } finally {
      release.resolve();
      await refreshing.catch(() => undefined);
      put.mockRestore();
      await observer.namespaces.bulkDelete([a.user!.namespace, b.user!.namespace]);
      observer.close();
    }
  });
}
