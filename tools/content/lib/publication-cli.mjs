import { spawn } from "node:child_process";
import { constants as fileConstants } from "node:fs";
import {
  chmod,
  mkdtemp,
  open,
  readFile,
  realpath,
  rm,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  CurriculumValidationError,
} from "./curriculum-validation.mjs";
import { PublicationBudgetError } from "./firestore-shape.mjs";
import {
  isApprovedFirestoreEmulatorHost,
  OperatorIdentityError,
} from "./operator-identity.mjs";
import { PublicationTransactionError } from "./publication-transactions.mjs";
import { parseStrictJSONBytes } from "./strict-json.mjs";

const REPOSITORY_ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../..",
);
const SECRET_SCANNER = path.join(REPOSITORY_ROOT, "scripts", "scan_secrets.sh");
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const CATALOG_POINTER_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const CATALOG_VERSION_PATTERN = /^catalog--[a-z0-9-]+--v[1-9][0-9]{0,9}$/;

export class PublicationCommandError extends Error {
  constructor(code, path = "", exitCode = 64) {
    super("Curriculum publication command was rejected.");
    this.name = "PublicationCommandError";
    this.code = code;
    this.path = path;
    this.exitCode = exitCode;
    this.issues = Object.freeze([{ code, path }]);
  }
}

function commandFail(code, path = "", exitCode = 64) {
  throw new PublicationCommandError(code, path, exitCode);
}

function readOption(tokens, index, name) {
  const value = tokens[index + 1];
  if (!value || value.startsWith("--")) commandFail("ARGUMENT_VALUE_MISSING", name);
  return value;
}

function validateCommon(options) {
  if (options.dryRun === options.apply) {
    commandFail("PUBLICATION_MODE_REQUIRED", "/mode");
  }
  for (const key of ["operationID", "environment", "projectID", "confirmProject"]) {
    if (!options[key]) commandFail("ARGUMENT_REQUIRED", `/${key}`);
  }
  if (!UUID_PATTERN.test(options.operationID)) {
    commandFail("OPERATION_ID_INVALID", "/operationID");
  }
  if (options.requestedBy !== null) {
    if (
      [...options.requestedBy].length > 320 ||
      options.requestedBy.length === 0 ||
      options.requestedBy !== options.requestedBy.normalize("NFC") ||
      /[\u0000-\u001f\u007f]/u.test(options.requestedBy)
    ) {
      commandFail("REQUESTED_BY_INVALID", "/requestedBy");
    }
  }
  return Object.freeze(options);
}

function assignOnce(options, key, value) {
  if (options[key] !== undefined && options[key] !== null) {
    commandFail("ARGUMENT_DUPLICATE", `/${key}`);
  }
  options[key] = value;
}

export function parsePublishArguments(tokens) {
  const options = {
    dryRun: false,
    apply: false,
    requestedBy: null,
  };
  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (token === "--dry-run" || token === "--apply") {
      const key = token === "--dry-run" ? "dryRun" : "apply";
      if (options[key]) commandFail("ARGUMENT_DUPLICATE", "/mode");
      options[key] = true;
      continue;
    }
    const mapping = {
      "--operation-id": "operationID",
      "--environment": "environment",
      "--project": "projectID",
      "--confirm-project": "confirmProject",
      "--source": "source",
      "--requested-by": "requestedBy",
    };
    const key = mapping[token];
    if (!key) commandFail("ARGUMENT_UNKNOWN", "");
    const value = readOption(tokens, index, token);
    assignOnce(options, key, value);
    index += 1;
  }
  if (!options.source) commandFail("ARGUMENT_REQUIRED", "/source");
  return validateCommon(options);
}

export function parseRollbackArguments(tokens) {
  const options = {
    dryRun: false,
    apply: false,
    requestedBy: null,
  };
  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (token === "--dry-run" || token === "--apply") {
      const key = token === "--dry-run" ? "dryRun" : "apply";
      if (options[key]) commandFail("ARGUMENT_DUPLICATE", "/mode");
      options[key] = true;
      continue;
    }
    const mapping = {
      "--operation-id": "operationID",
      "--environment": "environment",
      "--project": "projectID",
      "--confirm-project": "confirmProject",
      "--catalog-pointer": "catalogPointerID",
      "--to-catalog-version": "toCatalogVersionID",
      "--requested-by": "requestedBy",
    };
    const key = mapping[token];
    if (!key) commandFail("ARGUMENT_UNKNOWN", "");
    const value = readOption(tokens, index, token);
    assignOnce(options, key, value);
    index += 1;
  }
  for (const key of ["catalogPointerID", "toCatalogVersionID"]) {
    if (!options[key]) commandFail("ARGUMENT_REQUIRED", `/${key}`);
  }
  if (
    options.catalogPointerID !== "en-us" ||
    options.catalogPointerID.length > 35 ||
    !CATALOG_POINTER_PATTERN.test(options.catalogPointerID)
  ) {
    commandFail("CATALOG_POINTER_ID_INVALID", "/catalogPointerID");
  }
  if (
    options.toCatalogVersionID.length > 114 ||
    !CATALOG_VERSION_PATTERN.test(options.toCatalogVersionID) ||
    !options.toCatalogVersionID.startsWith("catalog--en-us--v") ||
    Number(options.toCatalogVersionID.slice(options.toCatalogVersionID.lastIndexOf("--v") + 3)) >
      2_147_483_647
  ) {
    commandFail("CATALOG_VERSION_ID_INVALID", "/toCatalogVersionID");
  }
  return validateCommon(options);
}

async function runScanner(resolvedSourcePath) {
  const exitCode = await new Promise((resolve, reject) => {
    const child = spawn(SECRET_SCANNER, ["--generated", resolvedSourcePath], {
      cwd: REPOSITORY_ROOT,
      env: process.env,
      stdio: ["ignore", "ignore", "ignore"],
    });
    child.once("error", reject);
    child.once("close", (code) => resolve(code));
  }).catch(() => null);
  if (exitCode !== 0) commandFail("SOURCE_SECRET_SCAN_FAILED", "", 1);
}

export async function loadScannedCurriculumSource(
  sourceArgument,
  { afterSourceRead } = {},
) {
  if (afterSourceRead !== undefined && typeof afterSourceRead !== "function") {
    commandFail("SOURCE_READ_HOOK_INVALID", "", 1);
  }
  let resolvedSourcePath;
  try {
    resolvedSourcePath = await realpath(path.resolve(sourceArgument));
  } catch {
    commandFail("SOURCE_READ_INVALID", "", 1);
  }
  // Preserve the literal resolved-path gate while the sealed snapshot below
  // binds the scanner result to the exact bytes that are parsed.
  await runScanner(resolvedSourcePath);

  let sourceHandle;
  let bytes;
  try {
    sourceHandle = await open(
      resolvedSourcePath,
      fileConstants.O_RDONLY | (fileConstants.O_NOFOLLOW ?? 0),
    );
    const sourceStat = await sourceHandle.stat();
    if (!sourceStat.isFile()) commandFail("SOURCE_READ_INVALID", "", 1);
    bytes = await sourceHandle.readFile();
  } catch {
    commandFail("SOURCE_READ_INVALID", "", 1);
  } finally {
    if (sourceHandle) await sourceHandle.close().catch(() => {});
  }
  if (afterSourceRead) {
    try {
      await afterSourceRead();
    } catch {
      commandFail("SOURCE_READ_HOOK_FAILED", "", 1);
    }
  }

  let snapshotDirectory;
  try {
    snapshotDirectory = await mkdtemp(
      path.join(os.tmpdir(), "syntholo-publication-source."),
    );
    await chmod(snapshotDirectory, 0o700);
    const snapshotPath = path.join(snapshotDirectory, "curriculum-source.json");
    await writeFile(snapshotPath, bytes, { flag: "wx", mode: 0o600 });
    await chmod(snapshotPath, 0o400);

    const snapshotHandle = await open(
      snapshotPath,
      fileConstants.O_RDONLY | (fileConstants.O_NOFOLLOW ?? 0),
    );
    try {
      const snapshotStat = await snapshotHandle.stat();
      if (
        !snapshotStat.isFile() ||
        snapshotStat.nlink !== 1 ||
        snapshotStat.size !== bytes.byteLength
      ) {
        commandFail("SOURCE_SNAPSHOT_INVALID", "", 1);
      }
    } finally {
      await snapshotHandle.close();
    }

    await runScanner(snapshotPath);
    const scannedBytes = await readFile(snapshotPath);
    if (!scannedBytes.equals(bytes)) {
      commandFail("SOURCE_SNAPSHOT_CHANGED", "", 1);
    }
    return Object.freeze({
      sourcePath: resolvedSourcePath,
      draft: parseStrictJSONBytes(bytes),
    });
  } catch (error) {
    if (error instanceof PublicationCommandError) throw error;
    if (
      error instanceof SyntaxError &&
      [
        "SOURCE_UTF8_INVALID",
        "JSON_PARSE_INVALID",
        "DUPLICATE_OBJECT_KEY",
      ].includes(error.code)
    ) {
      commandFail(error.code, "", 1);
    }
    commandFail("SOURCE_SNAPSHOT_INVALID", "", 1);
  } finally {
    if (snapshotDirectory) {
      await rm(snapshotDirectory, { recursive: true, force: true });
    }
  }
}

export function safeIssue(error) {
  const owned =
    error instanceof PublicationCommandError ||
    error instanceof OperatorIdentityError ||
    error instanceof CurriculumValidationError ||
    error instanceof PublicationTransactionError ||
    error instanceof PublicationBudgetError;
  if (!owned) return [{ code: "PUBLICATION_REJECTED", path: "" }];

  const issues =
    Array.isArray(error.issues) && error.issues.length > 0
      ? error.issues
      : [{ code: error.code, path: error.path ?? "" }];
  const safe = issues.map(({ code, path: issuePath }) => ({
    code,
    path: issuePath,
  }));
  if (
    safe.some(
      ({ code, path: issuePath }) =>
        typeof code !== "string" ||
        !/^[A-Z][A-Z0-9_]{0,95}$/u.test(code) ||
        typeof issuePath !== "string" ||
        issuePath.length > 512 ||
        !/^(?:|(?:\/(?:[A-Za-z0-9_.<>-]|~[01])+)+)$/u.test(issuePath),
    )
  ) {
    return [{ code: "PUBLICATION_REJECTED", path: "" }];
  }
  return safe;
}

export function commandExitCode(error) {
  return error instanceof PublicationCommandError &&
    Number.isInteger(error.exitCode) &&
    error.exitCode >= 1 &&
    error.exitCode <= 255
    ? error.exitCode
    : 1;
}

export function assertEmulatorConnectionContext(operator) {
  const preferRest = process.env.FIRESTORE_PREFER_REST?.trim().toLowerCase();
  if (
    operator?.environment !== "emulator" ||
    operator?.projectID !== "syntholo-local" ||
    operator?.projectNumber !== "emulator" ||
    operator?.credentialPrincipal !== "emulator-local" ||
    operator?.publicationMode !== "emulator" ||
    !isApprovedFirestoreEmulatorHost(process.env.FIRESTORE_EMULATOR_HOST)
  ) {
    commandFail("EMULATOR_CONNECTION_REQUIRED", "", 1);
  }
  if (preferRest && preferRest !== "false" && preferRest !== "0") {
    commandFail("EMULATOR_REST_TRANSPORT_FORBIDDEN", "", 1);
  }
}

export { REPOSITORY_ROOT };
