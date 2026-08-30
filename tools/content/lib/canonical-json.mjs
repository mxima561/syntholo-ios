import { createHash } from "node:crypto";

import { canonicalize } from "json-canonicalize";

function assertCanonicalizable(value) {
  if (value === undefined) {
    throw new TypeError("Canonical JSON cannot encode undefined.");
  }
}

export function canonicalString(value) {
  assertCanonicalizable(value);
  const result = canonicalize(value);
  if (typeof result !== "string") {
    throw new TypeError("Value is not representable as canonical JSON.");
  }
  return result;
}

export function canonicalBytes(value) {
  return Buffer.from(canonicalString(value), "utf8");
}

export function sha256Hex(bytesOrString) {
  if (!(typeof bytesOrString === "string" || ArrayBuffer.isView(bytesOrString))) {
    throw new TypeError("SHA-256 input must be a string or byte view.");
  }
  return createHash("sha256").update(bytesOrString).digest("hex");
}

export function contentDigest(document) {
  if (document === null || typeof document !== "object" || Array.isArray(document)) {
    throw new TypeError("A content document must be an object.");
  }

  const digestInput = { ...document };
  delete digestInput.contentDigest;
  delete digestInput.publishedAt;
  return sha256Hex(canonicalBytes(digestInput));
}

export function payloadDigest(payload) {
  return sha256Hex(canonicalBytes(payload));
}

export function publicationDigest(immutableDocuments) {
  const digestMap = {};
  const entries = Array.isArray(immutableDocuments)
    ? immutableDocuments.map(({ path, data }) => [path, data?.contentDigest])
    : immutableDocuments instanceof Map
      ? [...immutableDocuments.entries()].map(([path, value]) => [
          path,
          typeof value === "string" ? value : value?.contentDigest,
        ])
      : Object.entries(immutableDocuments ?? {}).map(([path, value]) => [
          path,
          typeof value === "string" ? value : value?.contentDigest,
        ]);

  for (const [path, digest] of entries.sort(([left], [right]) => left.localeCompare(right))) {
    if (typeof path !== "string" || !path || typeof digest !== "string") {
      throw new TypeError("Each immutable document needs a path and content digest.");
    }
    if (Object.hasOwn(digestMap, path)) {
      throw new TypeError(`Duplicate immutable document path: ${path}`);
    }
    digestMap[path] = digest;
  }

  return sha256Hex(canonicalBytes(digestMap));
}
