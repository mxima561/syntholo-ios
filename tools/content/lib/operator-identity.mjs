import { spawnSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const REPOSITORY_ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../..",
);

export const OPERATOR_ENVIRONMENTS_PATH = path.join(
  REPOSITORY_ROOT,
  "content/config/environments.json",
);
export const LAUNCH_CONTENT_DECISION_PATH = path.join(
  REPOSITORY_ROOT,
  "content/config/launch-content-decision.json",
);
export const LAUNCH_CONTENT_DECISION_SCHEMA_PATH = path.join(
  REPOSITORY_ROOT,
  "content/config/launch-content-decision.schema.json",
);
export const PRODUCT_BIBLE_PATH = path.join(
  REPOSITORY_ROOT,
  "docs/superpowers/specs/2026-08-25-syntholo-product-bible.md",
);

export const EMULATOR_OPERATOR_IDENTITY = Object.freeze({
  environment: "emulator",
  projectID: "syntholo-local",
  projectNumber: "emulator",
  credentialPrincipal: "emulator-local",
  publicationMode: "emulator",
});

export const LIVE_CREDENTIAL_TYPE = "impersonated-service-account";

export function isApprovedFirestoreEmulatorHost(value) {
  if (typeof value !== "string") return false;
  const match = /^127\.0\.0\.1:([1-9][0-9]{0,4})$/u.exec(value);
  if (!match) return false;
  const port = Number(match[1]);
  return Number.isInteger(port) && port >= 1 && port <= 65_535;
}

const ENVIRONMENTS = new Set(["emulator", "staging", "production"]);
const ENVIRONMENT_KEYS = new Set([
  "environment",
  "projectID",
  "projectNumber",
  "publicationMode",
  "credentialPrincipals",
]);
const CONFIG_KEYS = new Set(["schemaVersion", "environments"]);
const LIVE_PROJECT_ID_PATTERN = /^[a-z][a-z0-9-]{4,28}[a-z0-9]$/;
const LIVE_PROJECT_NUMBER_PATTERN = /^[0-9]{6,20}$/;
const SERVICE_ACCOUNT_LOCAL_PART_PATTERN =
  /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/;
const REQUESTED_BY_PATTERN = /^[^\u0000-\u001f\u007f]+$/u;
const OPEN_SPECIALIZATION_DECISION =
  "Which specialization is the first fully-built path (School / Work / Creation / Build)";
const SPECIALIZATIONS = Object.freeze([
  "school",
  "work",
  "creation",
  "build",
]);
const RESOLVER_OPTION_KEYS = new Set([
  "environment",
  "projectID",
  "confirmProject",
  "requestedBy",
  "firestoreEmulatorHost",
  "environmentsConfig",
  "environmentsPath",
  "decisionRecord",
  "decisionPath",
  "productBibleText",
  "productBiblePath",
  "liveIdentityResolver",
]);

function pointerToken(value) {
  return String(value).replaceAll("~", "~0").replaceAll("/", "~1");
}

function at(base, token) {
  return `${base}/${pointerToken(token)}`;
}

function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function issue(code, issuePath) {
  return Object.freeze({ code, path: issuePath });
}

function sortedIssues(issues) {
  return issues.sort(
    (left, right) =>
      left.code.localeCompare(right.code) || left.path.localeCompare(right.path),
  );
}

function deepFreeze(value) {
  if (value !== null && typeof value === "object" && !Object.isFrozen(value)) {
    Object.freeze(value);
    for (const child of Object.values(value)) deepFreeze(child);
  }
  return value;
}

function cloneAndFreeze(value) {
  return deepFreeze(structuredClone(value));
}

export class OperatorIdentityError extends Error {
  constructor(codeOrIssues, errorPath = "", message = "Operator authorization failed.") {
    const issues = Array.isArray(codeOrIssues)
      ? codeOrIssues
      : [issue(codeOrIssues, errorPath)];
    super(message);
    this.name = "OperatorIdentityError";
    this.issues = Object.freeze(sortedIssues([...issues]));
    this.code = this.issues[0]?.code ?? "OPERATOR_AUTHORIZATION_FAILED";
    this.path = this.issues[0]?.path ?? "";
  }

  toJSON() {
    return { code: this.code, path: this.path, issues: this.issues };
  }
}

function fail(code, errorPath = "", message) {
  throw new OperatorIdentityError(code, errorPath, message);
}

function addUnknownPropertyIssues(value, allowedKeys, basePath, issues) {
  if (!isRecord(value)) return;
  for (const key of Object.keys(value)) {
    if (!allowedKeys.has(key)) {
      issues.push(issue("UNKNOWN_PROPERTY", at(basePath, "<unknown-property>")));
    }
  }
}

function duplicateIssues(values, selector, code, itemPath, issues) {
  const seen = new Set();
  values.forEach((value, index) => {
    const identity = selector(value);
    if (identity === undefined) return;
    if (seen.has(identity)) issues.push(issue(code, itemPath(index)));
    seen.add(identity);
  });
}

export function validateEnvironmentConfiguration(value) {
  const issues = [];
  if (!isRecord(value)) {
    issues.push(issue("ENVIRONMENT_CONFIG_SHAPE_INVALID", ""));
    return { ok: false, issues };
  }

  addUnknownPropertyIssues(value, CONFIG_KEYS, "", issues);
  if (value.schemaVersion !== 1) {
    issues.push(issue("ENVIRONMENT_CONFIG_SCHEMA_VERSION_INVALID", "/schemaVersion"));
  }
  if (
    !Array.isArray(value.environments) ||
    value.environments.length < 1 ||
    value.environments.length > 3
  ) {
    issues.push(issue("ENVIRONMENT_ENTRY_COUNT_INVALID", "/environments"));
    return { ok: false, issues: sortedIssues(issues) };
  }

  const entries = value.environments;
  duplicateIssues(
    entries,
    (entry) => entry?.environment,
    "DUPLICATE_ENVIRONMENT",
    (index) => `/environments/${index}/environment`,
    issues,
  );
  duplicateIssues(
    entries,
    (entry) => entry?.projectID,
    "DUPLICATE_PROJECT_ID",
    (index) => `/environments/${index}/projectID`,
    issues,
  );
  duplicateIssues(
    entries,
    (entry) => entry?.projectNumber,
    "DUPLICATE_PROJECT_NUMBER",
    (index) => `/environments/${index}/projectNumber`,
    issues,
  );

  entries.forEach((entry, index) => {
    const base = `/environments/${index}`;
    if (!isRecord(entry)) {
      issues.push(issue("ENVIRONMENT_ENTRY_SHAPE_INVALID", base));
      return;
    }
    addUnknownPropertyIssues(entry, ENVIRONMENT_KEYS, base, issues);

    if (!ENVIRONMENTS.has(entry.environment)) {
      issues.push(issue("ENVIRONMENT_INVALID", `${base}/environment`));
    }
    if (entry.publicationMode !== entry.environment) {
      issues.push(issue("PUBLICATION_MODE_MISMATCH", `${base}/publicationMode`));
    }
    if (
      !Array.isArray(entry.credentialPrincipals) ||
      entry.credentialPrincipals.length < 1 ||
      entry.credentialPrincipals.length > 10
    ) {
      issues.push(
        issue("CREDENTIAL_PRINCIPAL_COUNT_INVALID", `${base}/credentialPrincipals`),
      );
      return;
    }
    duplicateIssues(
      entry.credentialPrincipals,
      (principal) => principal,
      "DUPLICATE_CREDENTIAL_PRINCIPAL",
      (principalIndex) => `${base}/credentialPrincipals/${principalIndex}`,
      issues,
    );

    if (entry.environment === "emulator") {
      if (
        entry.projectID !== EMULATOR_OPERATOR_IDENTITY.projectID ||
        entry.projectNumber !== EMULATOR_OPERATOR_IDENTITY.projectNumber ||
        entry.publicationMode !== EMULATOR_OPERATOR_IDENTITY.publicationMode ||
        entry.credentialPrincipals.length !== 1 ||
        entry.credentialPrincipals[0] !==
          EMULATOR_OPERATOR_IDENTITY.credentialPrincipal
      ) {
        issues.push(issue("EMULATOR_ENTRY_INVALID", base));
      }
      return;
    }

    if (!LIVE_PROJECT_ID_PATTERN.test(entry.projectID ?? "")) {
      issues.push(issue("LIVE_PROJECT_ID_INVALID", `${base}/projectID`));
    }
    if (!LIVE_PROJECT_NUMBER_PATTERN.test(entry.projectNumber ?? "")) {
      issues.push(issue("LIVE_PROJECT_NUMBER_INVALID", `${base}/projectNumber`));
    }
    if (
      entry.projectID === EMULATOR_OPERATOR_IDENTITY.projectID ||
      entry.projectNumber === EMULATOR_OPERATOR_IDENTITY.projectNumber ||
      entry.credentialPrincipals.includes(
        EMULATOR_OPERATOR_IDENTITY.credentialPrincipal,
      )
    ) {
      issues.push(issue("RESERVED_EMULATOR_IDENTITY", base));
    }
    entry.credentialPrincipals.forEach((principal, principalIndex) => {
      const expectedSuffix = `@${entry.projectID}.iam.gserviceaccount.com`;
      const localPart =
        typeof principal === "string" && principal.endsWith(expectedSuffix)
          ? principal.slice(0, -expectedSuffix.length)
          : "";
      if (
        typeof principal !== "string" ||
        principal.length > 320 ||
        !SERVICE_ACCOUNT_LOCAL_PART_PATTERN.test(localPart)
      ) {
        issues.push(
          issue(
            "LIVE_CREDENTIAL_PRINCIPAL_INVALID",
            `${base}/credentialPrincipals/${principalIndex}`,
          ),
        );
      }
    });
  });

  return {
    ok: issues.length === 0,
    issues: Object.freeze(sortedIssues(issues)),
  };
}

export function assertEnvironmentConfiguration(value) {
  const result = validateEnvironmentConfiguration(value);
  if (!result.ok) throw new OperatorIdentityError(result.issues);
  return cloneAndFreeze(value);
}

const decisionSchemaText = await readFile(
  LAUNCH_CONTENT_DECISION_SCHEMA_PATH,
  "utf8",
);
const decisionSchema = JSON.parse(decisionSchemaText);
const decisionAjv = new Ajv2020({ allErrors: true, strict: true });
addFormats(decisionAjv);
const validateDecisionSchema = decisionAjv.compile(decisionSchema);

export function validateLaunchContentDecision(value) {
  if (validateDecisionSchema(value)) {
    return { ok: true, issues: Object.freeze([]) };
  }
  const issues = (validateDecisionSchema.errors ?? []).map((schemaIssue) => {
    let errorPath = schemaIssue.instancePath || "";
    if (schemaIssue.keyword === "required") {
      errorPath = at(errorPath, schemaIssue.params.missingProperty);
    } else if (schemaIssue.keyword === "additionalProperties") {
      errorPath = at(errorPath, "<unknown-property>");
    }
    return issue("DECISION_SCHEMA_INVALID", errorPath);
  });
  return {
    ok: false,
    issues: Object.freeze(sortedIssues(issues)),
  };
}

export function assertLaunchContentDecision(value) {
  const result = validateLaunchContentDecision(value);
  if (!result.ok) throw new OperatorIdentityError(result.issues);
  return cloneAndFreeze(value);
}

export function assertLaunchContentDecisionMatchesBible(decision, productBibleText) {
  const validated = assertLaunchContentDecision(decision);
  if (typeof productBibleText !== "string") {
    fail("DECISION_BIBLE_READ_FAILED", "/productBibleDecision/documentPath");
  }
  if (productBibleText.includes(OPEN_SPECIALIZATION_DECISION)) {
    fail("DECISION_BIBLE_MISMATCH", "/productBibleDecision/decisionID");
  }

  const { decisionID, decisionDate } = validated.productBibleDecision;
  const selected = validated.specialization;
  const matchingRow = productBibleText
    .split(/\r?\n/u)
    .find((line) => {
      if (!line.trimStart().startsWith("|")) return false;
      const cells = line
        .split("|")
        .slice(1, -1)
        .map((cell) => cell.trim());
      if (!cells.includes(decisionID) || !line.includes(decisionDate)) return false;
      const lowered = line.toLocaleLowerCase("en-US");
      const mentioned = SPECIALIZATIONS.filter((specialization) =>
        new RegExp(`\\b${specialization}\\b`, "u").test(lowered),
      );
      return mentioned.length === 1 && mentioned[0] === selected;
    });

  if (!matchingRow) {
    fail("DECISION_BIBLE_MISMATCH", "/productBibleDecision/decisionID");
  }
  return validated;
}

class StrictJSONScanner {
  constructor(text) {
    this.text = text;
    this.index = 0;
  }

  parse() {
    this.skipWhitespace();
    this.parseValue("");
    this.skipWhitespace();
    if (this.index !== this.text.length) this.invalid();
  }

  parseValue(instancePath) {
    this.skipWhitespace();
    const character = this.text[this.index];
    if (character === "{") return this.parseObject(instancePath);
    if (character === "[") return this.parseArray(instancePath);
    if (character === '"') return void this.parseString();
    const token = this.text
      .slice(this.index)
      .match(/^(?:-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null)/u)?.[0];
    if (!token) this.invalid();
    this.index += token.length;
  }

  parseObject(instancePath) {
    this.index += 1;
    this.skipWhitespace();
    const keys = new Set();
    if (this.text[this.index] === "}") return void (this.index += 1);
    while (this.index < this.text.length) {
      if (this.text[this.index] !== '"') this.invalid();
      const key = this.parseString();
      if (keys.has(key)) fail("DUPLICATE_OBJECT_KEY", instancePath);
      keys.add(key);
      this.skipWhitespace();
      if (this.text[this.index] !== ":") this.invalid();
      this.index += 1;
      this.parseValue(at(instancePath, key));
      this.skipWhitespace();
      if (this.text[this.index] === "}") return void (this.index += 1);
      if (this.text[this.index] !== ",") this.invalid();
      this.index += 1;
      this.skipWhitespace();
    }
    this.invalid();
  }

  parseArray(instancePath) {
    this.index += 1;
    this.skipWhitespace();
    if (this.text[this.index] === "]") return void (this.index += 1);
    let itemIndex = 0;
    while (this.index < this.text.length) {
      this.parseValue(at(instancePath, itemIndex));
      itemIndex += 1;
      this.skipWhitespace();
      if (this.text[this.index] === "]") return void (this.index += 1);
      if (this.text[this.index] !== ",") this.invalid();
      this.index += 1;
      this.skipWhitespace();
    }
    this.invalid();
  }

  parseString() {
    const start = this.index;
    this.index += 1;
    while (this.index < this.text.length) {
      const character = this.text[this.index];
      if (character === '"') {
        this.index += 1;
        try {
          return JSON.parse(this.text.slice(start, this.index));
        } catch {
          this.invalid();
        }
      }
      if (character === "\\") {
        this.index += 2;
      } else {
        this.index += 1;
      }
    }
    this.invalid();
  }

  skipWhitespace() {
    while (/\s/u.test(this.text[this.index] ?? "")) this.index += 1;
  }

  invalid() {
    fail("JSON_PARSE_INVALID", "");
  }
}

async function readStrictJSON(filePath, missingCode, readCode) {
  let bytes;
  try {
    bytes = await readFile(filePath);
  } catch (error) {
    fail(error?.code === "ENOENT" ? missingCode : readCode, "");
  }
  let text;
  try {
    text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    new StrictJSONScanner(text).parse();
    return JSON.parse(text);
  } catch (error) {
    if (error instanceof OperatorIdentityError) throw error;
    fail("JSON_PARSE_INVALID", "");
  }
}

export async function loadEnvironmentConfiguration(
  filePath = OPERATOR_ENVIRONMENTS_PATH,
) {
  const value = await readStrictJSON(
    path.resolve(filePath),
    "ENVIRONMENT_CONFIG_REQUIRED",
    "ENVIRONMENT_CONFIG_READ_FAILED",
  );
  return assertEnvironmentConfiguration(value);
}

export async function loadLaunchContentDecision(
  filePath = LAUNCH_CONTENT_DECISION_PATH,
) {
  const value = await readStrictJSON(
    path.resolve(filePath),
    "DECISION_RECORD_REQUIRED",
    "DECISION_RECORD_READ_FAILED",
  );
  return assertLaunchContentDecision(value);
}

export function isTrackedRepositoryFile(filePath, repositoryRoot = REPOSITORY_ROOT) {
  const resolvedRoot = path.resolve(repositoryRoot);
  const resolvedFile = path.resolve(filePath);
  const relative = path.relative(resolvedRoot, resolvedFile);
  if (relative.startsWith("..") || path.isAbsolute(relative)) return false;
  const result = spawnSync(
    "git",
    ["-C", resolvedRoot, "ls-files", "--error-unmatch", "--", relative],
    { encoding: "utf8", stdio: ["ignore", "ignore", "ignore"] },
  );
  return result.status === 0;
}

function validateRequest(options) {
  if (!isRecord(options)) fail("OPERATOR_OPTIONS_INVALID", "");
  for (const key of Object.keys(options)) {
    if (key === "credentialPrincipal") {
      fail("CALLER_SUPPLIED_PRINCIPAL_FORBIDDEN", "/credentialPrincipal");
    }
    if (!RESOLVER_OPTION_KEYS.has(key)) {
      fail("OPERATOR_OPTIONS_INVALID", "/<unknown-property>");
    }
  }
  if (!ENVIRONMENTS.has(options.environment)) {
    fail("ENVIRONMENT_INVALID", "/environment");
  }
  if (typeof options.projectID !== "string" || options.projectID.length === 0) {
    fail("REQUESTED_PROJECT_REQUIRED", "/projectID");
  }
  if (
    typeof options.confirmProject !== "string" ||
    options.confirmProject.length === 0
  ) {
    fail("PROJECT_CONFIRMATION_REQUIRED", "/confirmProject");
  }
  if (options.confirmProject !== options.projectID) {
    fail("PROJECT_CONFIRMATION_MISMATCH", "/confirmProject");
  }
  assertRequestedBy(options.requestedBy);
}

function assertRequestedBy(requestedBy) {
  if (
    requestedBy !== undefined &&
    requestedBy !== null &&
    (typeof requestedBy !== "string" ||
      [...requestedBy].length > 320 ||
      !REQUESTED_BY_PATTERN.test(requestedBy) ||
      requestedBy !== requestedBy.normalize("NFC"))
  ) {
    fail("REQUESTED_BY_INVALID", "/requestedBy");
  }
}

function findEnvironmentEntry(configuration, environment) {
  return configuration.environments.find(
    (entry) => entry.environment === environment,
  );
}

function resolvedContext(entry, requestedBy) {
  return deepFreeze({
    environment: entry.environment,
    projectID: entry.projectID,
    projectNumber: entry.projectNumber,
    credentialPrincipal:
      entry.environment === "emulator"
        ? EMULATOR_OPERATOR_IDENTITY.credentialPrincipal
        : entry.credentialPrincipal,
    requestedBy: requestedBy ?? null,
    publicationMode: entry.publicationMode,
  });
}

export function authorizeResolvedLiveIdentity({
  environmentEntry,
  requestedProjectID,
  derivedIdentity,
  requestedBy = null,
}) {
  if (!isRecord(environmentEntry) || environmentEntry.environment !== "staging") {
    fail("LIVE_ENVIRONMENT_INVALID", "/environment");
  }
  const validatedEntry = assertEnvironmentConfiguration({
    schemaVersion: 1,
    environments: [environmentEntry],
  }).environments[0];
  assertRequestedBy(requestedBy);
  if (!isRecord(derivedIdentity)) {
    fail("LIVE_IDENTITY_SHAPE_INVALID", "/derivedIdentity");
  }
  const exactKeys = new Set([
    "credentialType",
    "projectID",
    "projectNumber",
    "credentialPrincipal",
  ]);
  if (
    Object.keys(derivedIdentity).length !== exactKeys.size ||
    Object.keys(derivedIdentity).some((key) => !exactKeys.has(key))
  ) {
    fail("LIVE_IDENTITY_SHAPE_INVALID", "/derivedIdentity");
  }
  if (derivedIdentity.credentialType !== LIVE_CREDENTIAL_TYPE) {
    fail("LIVE_CREDENTIAL_TYPE_INVALID", "/derivedIdentity/credentialType");
  }
  if (
    requestedProjectID !== validatedEntry.projectID ||
    derivedIdentity.projectID !== requestedProjectID
  ) {
    fail("ACTUAL_PROJECT_MISMATCH", "/derivedIdentity/projectID");
  }
  if (derivedIdentity.projectNumber !== validatedEntry.projectNumber) {
    fail("ACTUAL_PROJECT_NUMBER_MISMATCH", "/derivedIdentity/projectNumber");
  }
  if (
    !validatedEntry.credentialPrincipals.includes(
      derivedIdentity.credentialPrincipal,
    )
  ) {
    fail(
      "CREDENTIAL_PRINCIPAL_NOT_ALLOWLISTED",
      "/derivedIdentity/credentialPrincipal",
    );
  }
  return resolvedContext(
    { ...validatedEntry, credentialPrincipal: derivedIdentity.credentialPrincipal },
    requestedBy,
  );
}

async function resolveDecision(options) {
  const decisionPath = path.resolve(
    options.decisionPath ?? LAUNCH_CONTENT_DECISION_PATH,
  );
  const decision = options.decisionRecord
    ? assertLaunchContentDecision(options.decisionRecord)
    : await loadLaunchContentDecision(decisionPath);

  if (!options.decisionRecord && !isTrackedRepositoryFile(decisionPath)) {
    fail("DECISION_RECORD_NOT_TRACKED", "/productBibleDecision/documentPath");
  }
  const expectedDocumentPath = decision.productBibleDecision.documentPath;
  const productBiblePath = path.resolve(
    options.productBiblePath ?? PRODUCT_BIBLE_PATH,
  );
  if (productBiblePath !== path.join(REPOSITORY_ROOT, expectedDocumentPath)) {
    fail("DECISION_PRODUCT_BIBLE_PATH_INVALID", "/productBibleDecision/documentPath");
  }
  let productBibleText = options.productBibleText;
  if (productBibleText === undefined) {
    try {
      productBibleText = await readFile(productBiblePath, "utf8");
    } catch {
      fail("DECISION_BIBLE_READ_FAILED", "/productBibleDecision/documentPath");
    }
  }
  return assertLaunchContentDecisionMatchesBible(decision, productBibleText);
}

export async function resolveOperatorIdentity(options) {
  validateRequest(options);

  const configuration = options.environmentsConfig
    ? assertEnvironmentConfiguration(options.environmentsConfig)
    : await loadEnvironmentConfiguration(
        options.environmentsPath ?? OPERATOR_ENVIRONMENTS_PATH,
      );

  if (options.environment === "production") {
    fail("PRODUCTION_PUBLICATION_DISABLED", "/environment");
  }

  if (options.environment === "emulator") {
    const entry = findEnvironmentEntry(configuration, "emulator");
    if (!entry) fail("ENVIRONMENT_NOT_CONFIGURED", "/environment");
    if (options.projectID !== entry.projectID) {
      fail("ENVIRONMENT_PROJECT_MISMATCH", "/projectID");
    }
    if (
      typeof options.firestoreEmulatorHost !== "string" ||
      options.firestoreEmulatorHost.trim().length === 0
    ) {
      fail("EMULATOR_HOST_REQUIRED", "/firestoreEmulatorHost");
    }
    if (!isApprovedFirestoreEmulatorHost(options.firestoreEmulatorHost)) {
      fail("EMULATOR_HOST_INVALID", "/firestoreEmulatorHost");
    }
    return resolvedContext(entry, options.requestedBy);
  }

  if (
    typeof options.firestoreEmulatorHost === "string" &&
    options.firestoreEmulatorHost.trim().length > 0
  ) {
    fail("EMULATOR_HOST_FOR_LIVE_ENVIRONMENT", "/firestoreEmulatorHost");
  }

  await resolveDecision(options);
  const entry = findEnvironmentEntry(configuration, options.environment);
  if (!entry) fail("ENVIRONMENT_NOT_CONFIGURED", "/environment");
  if (options.projectID !== entry.projectID) {
    fail("ENVIRONMENT_PROJECT_MISMATCH", "/projectID");
  }
  if (typeof options.liveIdentityResolver !== "function") {
    fail("LIVE_IDENTITY_RESOLVER_REQUIRED", "/liveIdentityResolver");
  }

  let derivedIdentity;
  try {
    derivedIdentity = await options.liveIdentityResolver({
      environment: entry.environment,
      projectID: entry.projectID,
      projectNumber: entry.projectNumber,
    });
  } catch {
    fail("LIVE_IDENTITY_RESOLUTION_FAILED", "/liveIdentityResolver");
  }
  return authorizeResolvedLiveIdentity({
    environmentEntry: entry,
    requestedProjectID: options.projectID,
    derivedIdentity,
    requestedBy: options.requestedBy,
  });
}
