import Dexie, { type Table } from "dexie";
import { api, bootstrap } from "./api";
import type { Bootstrap } from "./identity";

interface NamespaceRow {
  namespace: string;
  sealed: boolean;
}

export class BoundaryDatabase extends Dexie {
  namespaces!: Table<NamespaceRow, string>;

  constructor(name = "questify-boundary") {
    super(name);
    this.version(1).stores({ namespaces: "&namespace" });
  }
}

export interface PendingWorkAdapter {
  count(namespace: string): Promise<number>;
}

const db = new BoundaryDatabase();
const adapters = new Set<PendingWorkAdapter>();
let active: Bootstrap | null = null;
let generation = 0;
let namespaceWrites: Promise<void> = Promise.resolve();
const listeners = new Set<() => void>();
const channel = typeof BroadcastChannel === "undefined" ? null : new BroadcastChannel("questify-identity");

export function registerPendingWorkAdapter(adapter: PendingWorkAdapter): () => void {
  adapters.add(adapter);
  return () => adapters.delete(adapter);
}

export function identityGeneration(): number {
  return generation;
}

export function acceptGeneration(value: number): boolean {
  return value === generation;
}

export function observeIdentity(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function persistNamespaces(write: () => Promise<void>): Promise<void> {
  const result = namespaceWrites.then(write);
  namespaceWrites = result.catch(() => undefined);
  return result;
}

function requireGeneration(expected: number): void {
  if (expected !== generation) throw new Error("stale_identity_response");
}

async function seal(): Promise<void> {
  generation += 1;
  const namespace = active?.user?.namespace;
  active = null;
  listeners.forEach(listener => listener());
  if (namespace) {
    await persistNamespaces(async () => { await db.namespaces.put({ namespace, sealed: true }); });
  }
}

async function activate(value: Bootstrap, expected: number): Promise<number> {
  requireGeneration(expected);
  const oldNamespace = active?.user?.namespace;
  const nextNamespace = value.user?.namespace;
  if (oldNamespace !== nextNamespace) {
    expected += 1;
    await seal();
    requireGeneration(expected);
  }
  await persistNamespaces(async () => {
    requireGeneration(expected);
    if (nextNamespace) {
      await db.namespaces.put({ namespace: nextNamespace, sealed: false });
      if (expected !== generation) {
        // Finish stale-write compensation before a newer activation may persist.
        await db.namespaces.put({ namespace: nextNamespace, sealed: true });
        requireGeneration(expected);
      }
    }
    active = value;
    listeners.forEach(listener => listener());
    requireGeneration(expected);
  });
  return expected;
}

export async function refreshIdentity(): Promise<Bootstrap> {
  const captured = generation;
  const value = await bootstrap();
  requireGeneration(captured);
  const activated = await activate(value, captured);
  requireGeneration(activated);
  return value;
}

export async function beginGuest(): Promise<Bootstrap> {
  await api<Bootstrap>("/v1/guest", "POST", {});
  return refreshIdentity();
}

export async function logoutEmptyFoundation(): Promise<void> {
  if (!navigator.onLine) throw new Error("offline_handoff_required");
  if (!navigator.locks) throw new Error("identity_lock_unavailable");

  await navigator.locks.request("questify-identity", async () => {
    const namespace = active?.user?.namespace;
    if (namespace) {
      const counts = await Promise.all([...adapters].map(adapter => adapter.count(namespace)));
      if (counts.some(count => count !== 0)) throw new Error("pending_work_handoff_required");
    }
    await api("/v1/session", "DELETE", {});
    await seal();
    const marker = crypto.randomUUID();
    localStorage.setItem("questify-identity-invalidated", marker);
    channel?.postMessage(marker);
  });
}

channel?.addEventListener("message", () => { void seal(); });
globalThis.addEventListener("storage", event => {
  if (event.key === "questify-identity-invalidated") void seal();
});
