import { render, screen } from "@testing-library/react";
import Dexie from "dexie";
import { expect, it } from "vitest";
import { harnessValue } from "../harness";

it("harness_reports_intentional_mismatch", () => {
  render(<main><h1>Questify — estrutura de testes</h1></main>);
  expect(screen.getByRole("heading", { name: "Questify — estrutura de testes" })).toBeVisible();
  expect(harnessValue).toBe(1);
});

it("indexeddb_harness_persists_and_reads", async () => {
  const db = new Dexie(`harness-${crypto.randomUUID()}`);
  db.version(1).stores({ probes: "id" });
  try {
    await db.table("probes").put({ id: "probe", value: 1 });
    expect((await db.table("probes").get("probe")).value).toBe(1);
  } finally {
    await db.delete();
  }
});
