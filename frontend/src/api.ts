import type { Bootstrap } from "./identity";

let csrf = "";

export class ApiFailure extends Error {
  constructor(public readonly status: number, public readonly code: string) {
    super(code);
  }
}

export async function api<T>(path: string, method = "GET", body?: Record<string, unknown>): Promise<T> {
  if (!path.startsWith("/v1/")) throw new Error("API path must be same-origin /v1/");
  const response = await fetch(path, {
    method,
    credentials: "same-origin",
    cache: "no-store",
    headers: {
      Accept: "application/json",
      ...(method === "GET" ? {} : { "Content-Type": "application/json", "X-CSRF-Token": csrf })
    },
    body: body === undefined ? undefined : JSON.stringify(body)
  });
  const data: unknown = await response.json();
  if (!response.ok) {
    const error = data as { error?: { code?: string } };
    throw new ApiFailure(response.status, error.error?.code ?? "request_failed");
  }
  return data as T;
}

export async function bootstrap(): Promise<Bootstrap> {
  const value = await api<Bootstrap>("/v1/bootstrap");
  csrf = value.csrf_token;
  return value;
}
