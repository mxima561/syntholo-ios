import {
  canonicalBytes,
  canonicalString,
  contentDigest,
  sha256Hex,
} from "./canonical-json.mjs";
import {
  assertPublicationSourceAllowed,
  validateCurriculumDraft,
} from "./curriculum-validation.mjs";
import { isApprovedFirestoreEmulatorHost } from "./operator-identity.mjs";
import {
  assertPublicationBudgetWithinLimit,
  calculatePublicationBudget,
} from "./firestore-shape.mjs";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const VERSION_ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*--[a-z0-9-]+--v[1-9][0-9]{0,9}$/;
const CATALOG_VERSION_ID_PATTERN = /^catalog--[a-z0-9-]+--v[1-9][0-9]{0,9}$/;
const POINTER_ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*--[a-z0-9-]+$/;
const STABLE_ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

const IMMUTABLE_KEYS = Object.freeze({
  catalogVersions: [
    "catalogVersionID",
    "version",
    "locale",
    "publicationState",
    "schemaVersion",
    "minimumClientSchemaVersion",
    "programEntries",
    "contentDigest",
    "publishedAt",
  ],
  programVersions: [
    "programVersionID",
    "programID",
    "version",
    "locale",
    "publicationState",
    "title",
    "promise",
    "catalogState",
    "schemaVersion",
    "minimumClientSchemaVersion",
    "moduleVersionIDs",
    "firstLessonVersionID",
    "contentDigest",
    "publishedAt",
  ],
  modules: [
    "moduleVersionID",
    "moduleID",
    "programID",
    "version",
    "locale",
    "publicationState",
    "title",
    "summary",
    "schemaVersion",
    "minimumClientSchemaVersion",
    "lessonVersionIDs",
    "contentDigest",
    "publishedAt",
  ],
  lessonVersions: [
    "lessonVersionID",
    "lessonID",
    "programID",
    "moduleID",
    "version",
    "locale",
    "publicationState",
    "title",
    "objective",
    "expectedDurationMinutes",
    "prerequisiteLessonIDs",
    "completionRule",
    "blocks",
    "rubricVersionID",
    "assetVersionIDs",
    "schemaVersion",
    "minimumClientSchemaVersion",
    "contentDigest",
    "publishedAt",
  ],
  rubricVersions: [
    "rubricVersionID",
    "rubricID",
    "version",
    "locale",
    "publicationState",
    "kind",
    "criteria",
    "clientScoringContract",
    "evaluationContractVersionID",
    "schemaVersion",
    "minimumClientSchemaVersion",
    "contentDigest",
    "publishedAt",
  ],
  evaluationContractVersions: [
    "evaluationContractVersionID",
    "evaluationContractID",
    "rubricVersionID",
    "version",
    "locale",
    "publicationState",
    "kind",
    "questionBlockID",
    "correctOptionID",
    "schemaVersion",
    "contentDigest",
    "publishedAt",
  ],
  assetVersions: [
    "assetVersionID",
    "assetID",
    "version",
    "locale",
    "publicationState",
    "kind",
    "mimeType",
    "byteCount",
    "payloadDigest",
    "payload",
    "accessibilityDescription",
    "rights",
    "schemaVersion",
    "minimumClientSchemaVersion",
    "contentDigest",
    "publishedAt",
  ],
});

const AUDIT_KEYS = Object.freeze([
  "schemaVersion",
  "operationID",
  "requestDigest",
  "action",
  "outcome",
  "environment",
  "projectID",
  "projectNumber",
  "credentialPrincipal",
  "requestedBy",
  "catalogPointerID",
  "fromCatalogVersionID",
  "toCatalogVersionID",
  "programSelections",
  "publicationDigest",
  "occurredAt",
]);

export const PUBLICATION_FAULT_PHASES = Object.freeze({
  afterReads: "afterReads",
  afterImmutableWrites: "afterImmutableWrites",
  afterPointerWrites: "afterPointerWrites",
  afterAuditWrite: "afterAuditWrite",
});

export class PublicationTransactionError extends Error {
  constructor(code, path = "", message = "Curriculum publication was rejected.") {
    super(message);
    this.name = "PublicationTransactionError";
    this.code = code;
    this.path = path;
    this.issues = Object.freeze([{ code, path }]);
  }
}

function fail(code, path = "", message) {
  throw new PublicationTransactionError(code, path, message);
}

function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function exactKeys(value, keys) {
  if (!isRecord(value)) return false;
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  return canonicalString(actual) === canonicalString(expected);
}

function isNativeTimestamp(value) {
  if (!value || typeof value !== "object") return false;
  if (typeof value.toMillis !== "function" || typeof value.toDate !== "function") {
    return false;
  }
  try {
    return Number.isFinite(value.toMillis()) && value.toDate() instanceof Date;
  } catch {
    return false;
  }
}

function assertTimestamp(value, path) {
  if (!isNativeTimestamp(value)) {
    fail("STORED_TIMESTAMP_INVALID", path);
  }
}

function canonicalEqual(left, right) {
  try {
    return canonicalString(left) === canonicalString(right);
  } catch {
    return false;
  }
}

function versionNumberFromID(value) {
  return Number(value.slice(value.lastIndexOf("--v") + 3));
}

function isBoundedVersionID(value, { catalog = false } = {}) {
  if (typeof value !== "string" || value.length > 114) return false;
  const pattern = catalog ? CATALOG_VERSION_ID_PATTERN : VERSION_ID_PATTERN;
  if (!pattern.test(value)) return false;
  const version = versionNumberFromID(value);
  return Number.isInteger(version) && version >= 1 && version <= 2_147_483_647;
}

function isStableID(value) {
  return (
    typeof value === "string" &&
    value.length >= 3 &&
    value.length <= 64 &&
    STABLE_ID_PATTERN.test(value)
  );
}

function withoutTimestamp(value, timestampKey) {
  const result = { ...value };
  delete result[timestampKey];
  return result;
}

function collectionForPath(documentPath) {
  return documentPath.split("/", 1)[0];
}

function documentIDForPath(documentPath) {
  return documentPath.slice(documentPath.indexOf("/") + 1);
}

function assertSafeDocumentID(value, { catalog = false, pointer = false } = {}) {
  if (typeof value !== "string") fail("STORED_GRAPH_INVALID", "");
  const valid = catalog
    ? isBoundedVersionID(value, { catalog: true })
    : pointer
      ? POINTER_ID_PATTERN.test(value)
      : isBoundedVersionID(value);
  if (
    !valid ||
    value.length > 128
  ) {
    fail("STORED_GRAPH_INVALID", "");
  }
}

function assertStoredImmutable(data, expected, documentPath) {
  const collection = collectionForPath(documentPath);
  const keys = IMMUTABLE_KEYS[collection];
  if (!keys || !exactKeys(data, keys)) {
    fail("IMMUTABLE_SHAPE_MISMATCH", "");
  }
  assertTimestamp(data.publishedAt, "/publishedAt");
  if (!canonicalEqual(withoutTimestamp(data, "publishedAt"), expected)) {
    fail("IMMUTABLE_COLLISION", "");
  }
  if (data.contentDigest !== contentDigest(data)) {
    fail("IMMUTABLE_DIGEST_MISMATCH", "");
  }
}

function assertStoredImmutableSelf(data, collection, expectedID) {
  const keys = IMMUTABLE_KEYS[collection];
  if (!keys || !exactKeys(data, keys)) fail("STORED_GRAPH_INVALID", "");
  assertTimestamp(data.publishedAt, "/publishedAt");
  const idField = {
    catalogVersions: "catalogVersionID",
    programVersions: "programVersionID",
    modules: "moduleVersionID",
    lessonVersions: "lessonVersionID",
    rubricVersions: "rubricVersionID",
    evaluationContractVersions: "evaluationContractVersionID",
    assetVersions: "assetVersionID",
  }[collection];
  if (
    data[idField] !== expectedID ||
    data.publicationState !== "published" ||
    data.schemaVersion !== 1 ||
    data.contentDigest !== contentDigest(data)
  ) {
    fail("STORED_GRAPH_INVALID", "");
  }
}

function localeToken(locale) {
  if (typeof locale !== "string") fail("LOCALE_INVALID", "/locale");
  return locale.toLowerCase();
}

function assertCatalogSemantics(data, expectedLocale) {
  const expectedCatalogVersionID =
    `catalog--${localeToken(data.locale ?? "")}--v${data.version}`;
  if (
    data.locale !== expectedLocale ||
    !Number.isInteger(data.version) ||
    data.version < 1 ||
    data.version > 2_147_483_647 ||
    data.catalogVersionID !== expectedCatalogVersionID ||
    !Number.isInteger(data.minimumClientSchemaVersion) ||
    data.minimumClientSchemaVersion < 1 ||
    data.minimumClientSchemaVersion > 2_147_483_647 ||
    !Array.isArray(data.programEntries) ||
    data.programEntries.length < 1 ||
    data.programEntries.length > 5
  ) {
    fail("CURRENT_CATALOG_CORRUPT", "");
  }
  const pointerIDs = new Set();
  const versionIDs = new Set();
  for (const entry of data.programEntries) {
    if (
      !exactKeys(entry, ["programPointerID", "programVersionID"]) ||
      typeof entry.programPointerID !== "string" ||
      typeof entry.programVersionID !== "string" ||
      !POINTER_ID_PATTERN.test(entry.programPointerID) ||
      !isStableID(
        entry.programPointerID.slice(
          0,
          -(`--${localeToken(expectedLocale)}`.length),
        ),
      ) ||
      !isBoundedVersionID(entry.programVersionID) ||
      !entry.programPointerID.endsWith(`--${localeToken(expectedLocale)}`) ||
      !entry.programVersionID.startsWith(`${entry.programPointerID}--v`) ||
      pointerIDs.has(entry.programPointerID) ||
      versionIDs.has(entry.programVersionID)
    ) {
      fail("CURRENT_CATALOG_CORRUPT", "");
    }
    pointerIDs.add(entry.programPointerID);
    versionIDs.add(entry.programVersionID);
  }
}

function assertCatalogPointerSemantics(data, pointerID, expectedLocale) {
  if (
    pointerID !== localeToken(expectedLocale) ||
    data.locale !== expectedLocale ||
    data.schemaVersion !== 1 ||
    !Number.isInteger(data.minimumClientSchemaVersion) ||
    data.minimumClientSchemaVersion < 1 ||
    data.minimumClientSchemaVersion > 2_147_483_647 ||
    !isBoundedVersionID(data.publishedCatalogVersionID, { catalog: true }) ||
    !data.publishedCatalogVersionID.startsWith(`catalog--${pointerID}--v`)
  ) {
    fail("CATALOG_POINTER_CORRUPT", "");
  }
}

function assertProgramPointerSemantics(data, documentID, expectedLocale) {
  if (
    typeof data.programID !== "string" ||
    typeof data.programPointerID !== "string" ||
    typeof data.publishedVersionID !== "string" ||
    !isStableID(data.programID) ||
    data.programPointerID !== documentID ||
    data.programPointerID !== `${data.programID}--${localeToken(expectedLocale)}` ||
    !POINTER_ID_PATTERN.test(data.programPointerID) ||
    !isBoundedVersionID(data.publishedVersionID) ||
    !data.publishedVersionID.startsWith(`${data.programPointerID}--v`) ||
    data.locale !== expectedLocale ||
    data.schemaVersion !== 1
  ) {
    fail("PROGRAM_POINTER_CORRUPT", "");
  }
}

function immutableIdentity(documentPath, data) {
  const collection = collectionForPath(documentPath);
  const mapping = {
    catalogVersions: ["catalog", "catalog"],
    programVersions: ["program", data.programID],
    modules: ["module", data.moduleID],
    lessonVersions: ["lesson", data.lessonID],
    rubricVersions: ["rubric", data.rubricID],
    evaluationContractVersions: [
      "evaluation-contract",
      data.evaluationContractID,
    ],
    assetVersions: ["asset", data.assetID],
  };
  const identity = mapping[collection];
  if (!identity || typeof data.locale !== "string" || !Number.isInteger(data.version)) {
    fail("IMMUTABLE_IDENTITY_INVALID", "");
  }
  const [kind, stableID] = identity;
  return Object.freeze({
    versionHeadID: `${kind}--${stableID}--${localeToken(data.locale)}`,
    kind,
    stableID,
    locale: data.locale,
    version: data.version,
  });
}

function expectedVersionHead(identity) {
  return {
    versionHeadID: identity.versionHeadID,
    kind: identity.kind,
    stableID: identity.stableID,
    locale: identity.locale,
    maxPublishedVersion: identity.version,
    schemaVersion: 1,
  };
}

function assertStoredHead(data, identity) {
  const expectedKeys = [
    "versionHeadID",
    "kind",
    "stableID",
    "locale",
    "maxPublishedVersion",
    "schemaVersion",
    "updatedAt",
  ];
  if (!exactKeys(data, expectedKeys)) fail("VERSION_HEAD_CORRUPT", "");
  assertTimestamp(data.updatedAt, "/updatedAt");
  if (
    data.versionHeadID !== identity.versionHeadID ||
    data.kind !== identity.kind ||
    data.stableID !== identity.stableID ||
    data.locale !== identity.locale ||
    data.schemaVersion !== 1 ||
    !Number.isInteger(data.maxPublishedVersion) ||
    data.maxPublishedVersion < 1 ||
    data.maxPublishedVersion > 2_147_483_647
  ) {
    fail("VERSION_HEAD_CORRUPT", "");
  }
  return data.maxPublishedVersion;
}

function expectedWithTimestamp(expected, timestampKey, serverTimestamp) {
  return { ...expected, [timestampKey]: serverTimestamp() };
}

function assertStoredMutable(data, expected, timestampKey, code) {
  const keys = [...Object.keys(expected), timestampKey];
  if (!exactKeys(data, keys)) fail(code, "");
  assertTimestamp(data[timestampKey], `/${timestampKey}`);
  if (!canonicalEqual(withoutTimestamp(data, timestampKey), expected)) {
    fail(code, "");
  }
}

function isStoredMutableMatch(data, expected, timestampKey) {
  try {
    assertStoredMutable(data, expected, timestampKey, "MUTABLE_STATE_DRIFT");
    return true;
  } catch {
    return false;
  }
}

function validateRequestedBy(value) {
  if (value === undefined || value === null) return null;
  if (
    typeof value !== "string" ||
    value.length < 1 ||
    [...value].length > 320 ||
    value !== value.normalize("NFC") ||
    /[\u0000-\u001f\u007f]/u.test(value)
  ) {
    fail("REQUESTED_BY_INVALID", "/requestedBy");
  }
  return value;
}

function assertOperationID(operationID) {
  if (typeof operationID !== "string" || !UUID_PATTERN.test(operationID)) {
    fail("OPERATION_ID_INVALID", "/operationID");
  }
}

function assertOperatorContext(operatorContext, requestedBy) {
  if (!isRecord(operatorContext)) fail("OPERATOR_CONTEXT_INVALID", "");
  const resolvedRequestedBy = validateRequestedBy(
    requestedBy === undefined ? operatorContext.requestedBy : requestedBy,
  );
  if (
    operatorContext.requestedBy !== undefined &&
    requestedBy !== undefined &&
    operatorContext.requestedBy !== requestedBy
  ) {
    fail("OPERATOR_CONTEXT_INVALID", "/requestedBy");
  }
  if (
    operatorContext.environment !== "emulator" ||
    operatorContext.projectID !== "syntholo-local" ||
    operatorContext.projectNumber !== "emulator" ||
    operatorContext.credentialPrincipal !== "emulator-local" ||
    operatorContext.publicationMode !== "emulator" ||
    !isApprovedFirestoreEmulatorHost(process.env.FIRESTORE_EMULATOR_HOST)
  ) {
    fail("EMULATOR_OPERATOR_REQUIRED", "");
  }
  return Object.freeze({ ...operatorContext, requestedBy: resolvedRequestedBy });
}

function requestObject({
  action,
  operator,
  catalogPointerID,
  toCatalogVersionID,
  publicationDigest,
}) {
  return Object.freeze({
    schemaVersion: 1,
    action,
    environment: operator.environment,
    projectID: operator.projectID,
    projectNumber: operator.projectNumber,
    credentialPrincipal: operator.credentialPrincipal,
    requestedBy: operator.requestedBy,
    catalogPointerID,
    toCatalogVersionID,
    publicationDigest,
  });
}

export function calculatePublicationRequestDigest(request) {
  return sha256Hex(canonicalBytes(request));
}

function auditRequestObject(audit) {
  return {
    schemaVersion: audit.schemaVersion,
    action: audit.action,
    environment: audit.environment,
    projectID: audit.projectID,
    projectNumber: audit.projectNumber,
    credentialPrincipal: audit.credentialPrincipal,
    requestedBy: audit.requestedBy,
    catalogPointerID: audit.catalogPointerID,
    toCatalogVersionID: audit.toCatalogVersionID,
    publicationDigest: audit.publicationDigest,
  };
}

function assertAuditShape(audit, operationID) {
  if (!exactKeys(audit, AUDIT_KEYS)) fail("OPERATION_AUDIT_CORRUPT", "");
  assertTimestamp(audit.occurredAt, "/occurredAt");
  const requestedByValid =
    audit.requestedBy === null ||
    (typeof audit.requestedBy === "string" &&
      audit.requestedBy.length > 0 &&
      [...audit.requestedBy].length <= 320 &&
      audit.requestedBy === audit.requestedBy.normalize("NFC") &&
      !/[\u0000-\u001f\u007f]/u.test(audit.requestedBy));
  const programPointers = new Set();
  const selectionsValid =
    Array.isArray(audit.programSelections) &&
    audit.programSelections.length >= 1 &&
    audit.programSelections.length <= 5 &&
    audit.programSelections.every((selection) => {
      if (
        !exactKeys(selection, [
          "programPointerID",
          "fromProgramVersionID",
          "toProgramVersionID",
        ]) ||
        typeof selection.programPointerID !== "string" ||
        !POINTER_ID_PATTERN.test(selection.programPointerID) ||
        selection.programPointerID.length > 101 ||
        !selection.programPointerID.endsWith(`--${audit.catalogPointerID}`) ||
        !isStableID(
          selection.programPointerID.slice(
            0,
            -(`--${audit.catalogPointerID}`.length),
          ),
        ) ||
        (selection.fromProgramVersionID !== null &&
          (typeof selection.fromProgramVersionID !== "string" ||
            selection.fromProgramVersionID.length > 114 ||
            !isBoundedVersionID(selection.fromProgramVersionID) ||
            !selection.fromProgramVersionID.startsWith(
              `${selection.programPointerID}--v`,
            ))) ||
        typeof selection.toProgramVersionID !== "string" ||
        selection.toProgramVersionID.length > 114 ||
        !isBoundedVersionID(selection.toProgramVersionID) ||
        !selection.toProgramVersionID.startsWith(
          `${selection.programPointerID}--v`,
        ) ||
        programPointers.has(selection.programPointerID)
      ) {
        return false;
      }
      programPointers.add(selection.programPointerID);
      return true;
    });
  if (
    audit.schemaVersion !== 1 ||
    audit.operationID !== operationID ||
    !UUID_PATTERN.test(audit.operationID) ||
    !["publish", "rollback"].includes(audit.action) ||
    !["applied", "noOp"].includes(audit.outcome) ||
    audit.environment !== "emulator" ||
    audit.projectID !== "syntholo-local" ||
    audit.projectNumber !== "emulator" ||
    audit.credentialPrincipal !== "emulator-local" ||
    !requestedByValid ||
    audit.catalogPointerID !== "en-us" ||
    audit.catalogPointerID.length > 35 ||
    !/^[a-z0-9]+(?:-[a-z0-9]+)*$/u.test(audit.catalogPointerID) ||
    (audit.fromCatalogVersionID !== null &&
      (typeof audit.fromCatalogVersionID !== "string" ||
        audit.fromCatalogVersionID.length > 114 ||
        !isBoundedVersionID(audit.fromCatalogVersionID, { catalog: true }) ||
        !audit.fromCatalogVersionID.startsWith(
          `catalog--${audit.catalogPointerID}--v`,
        ))) ||
    typeof audit.toCatalogVersionID !== "string" ||
    audit.toCatalogVersionID.length > 114 ||
    !isBoundedVersionID(audit.toCatalogVersionID, { catalog: true }) ||
    !audit.toCatalogVersionID.startsWith(
      `catalog--${audit.catalogPointerID}--v`,
    ) ||
    typeof audit.publicationDigest !== "string" ||
    !/^[0-9a-f]{64}$/u.test(audit.publicationDigest) ||
    typeof audit.requestDigest !== "string" ||
    !/^[0-9a-f]{64}$/u.test(audit.requestDigest) ||
    !selectionsValid ||
    audit.requestDigest !== calculatePublicationRequestDigest(auditRequestObject(audit))
  ) {
    fail("OPERATION_AUDIT_CORRUPT", "");
  }
}

function replayResult(audit, { immutableDocumentCount = null } = {}) {
  return Object.freeze({
    action: audit.action,
    outcome: audit.outcome,
    replay: true,
    environment: audit.environment,
    projectID: audit.projectID,
    projectNumber: audit.projectNumber,
    credentialPrincipal: audit.credentialPrincipal,
    requestedBy: audit.requestedBy,
    operationID: audit.operationID,
    catalogPointerID: audit.catalogPointerID,
    fromCatalogVersionID: audit.fromCatalogVersionID,
    toCatalogVersionID: audit.toCatalogVersionID,
    programSelections: structuredClone(audit.programSelections),
    publicationDigest: audit.publicationDigest,
    requestDigest: audit.requestDigest,
    immutableDocumentCount,
    createdImmutableDocumentCount: 0,
    calculatedTransactionUnits: 0,
  });
}

function assertReplayMatches(audit, expectedRequest, operationID) {
  assertAuditShape(audit, operationID);
  if (!canonicalEqual(auditRequestObject(audit), expectedRequest)) {
    fail("OPERATION_ID_COLLISION", "/operationID");
  }
}

function assertRollbackReplayMatches(audit, expected, operationID) {
  assertAuditShape(audit, operationID);
  const storedRequest = auditRequestObject(audit);
  const expectedWithoutDigest = { ...expected };
  delete expectedWithoutDigest.publicationDigest;
  const storedWithoutDigest = { ...storedRequest };
  delete storedWithoutDigest.publicationDigest;
  if (!canonicalEqual(storedWithoutDigest, expectedWithoutDigest)) {
    fail("OPERATION_ID_COLLISION", "/operationID");
  }
}

async function injectFault(faultInjector, phase, context) {
  if (typeof faultInjector === "function") {
    await faultInjector(phase, Object.freeze(context));
  }
}

function historicalDocumentIDPrefix(identity, collection) {
  return collection === "catalogVersions"
    ? `catalog--${localeToken(identity.locale)}--v`
    : `${identity.stableID}--${localeToken(identity.locale)}--v`;
}

function historicalIdentityQuery(
  firestore,
  identity,
  collection,
  documentIDFieldPath,
) {
  const collectionReference = firestore.collection(collection);
  if (!documentIDFieldPath) return collectionReference;
  const prefix = historicalDocumentIDPrefix(identity, collection);
  const exclusiveUpperBound = `${prefix.slice(0, -1)}w`;
  return collectionReference
    .where(documentIDFieldPath, ">=", prefix)
    .where(documentIDFieldPath, "<", exclusiveUpperBound);
}

async function assertNoHistoricalVersionWithoutHead(
  transaction,
  firestore,
  entries,
  documentIDFieldPath,
) {
  for (const entry of entries) {
    const collection = collectionForPath(entry.path);
    const prefix = historicalDocumentIDPrefix(entry.identity, collection);
    const snapshot = await transaction.get(
      historicalIdentityQuery(
        firestore,
        entry.identity,
        collection,
        documentIDFieldPath,
      ),
    );
    const matchingPathHistory = snapshot.docs.some(
      (document) => document.id.startsWith(prefix),
    );
    if (matchingPathHistory) fail("VERSION_HEAD_MISSING", "");
  }
}

function snapshotData(snapshot) {
  return snapshot?.exists ? snapshot.data() : null;
}

async function getAll(transaction, references) {
  const unique = [];
  const seen = new Set();
  for (const reference of references) {
    if (!seen.has(reference.path)) {
      unique.push(reference);
      seen.add(reference.path);
    }
  }
  const snapshots =
    typeof transaction.getAll === "function"
      ? await transaction.getAll(...unique)
      : await Promise.all(unique.map((reference) => transaction.get(reference)));
  return new Map(snapshots.map((snapshot) => [snapshot.ref.path, snapshot]));
}

function buildAudit({
  request,
  requestDigest,
  operationID,
  outcome,
  fromCatalogVersionID,
  programSelections,
  serverTimestamp,
}) {
  return {
    schemaVersion: 1,
    operationID,
    requestDigest,
    action: request.action,
    outcome,
    environment: request.environment,
    projectID: request.projectID,
    projectNumber: request.projectNumber,
    credentialPrincipal: request.credentialPrincipal,
    requestedBy: request.requestedBy,
    catalogPointerID: request.catalogPointerID,
    fromCatalogVersionID,
    toCatalogVersionID: request.toCatalogVersionID,
    programSelections,
    publicationDigest: request.publicationDigest,
    occurredAt: serverTimestamp(),
  };
}

function finalResult({
  request,
  requestDigest,
  operationID,
  outcome,
  fromCatalogVersionID,
  programSelections,
  immutableDocumentCount,
  createdImmutableDocumentCount,
  calculatedTransactionUnits,
}) {
  return Object.freeze({
    action: request.action,
    outcome,
    replay: false,
    environment: request.environment,
    projectID: request.projectID,
    projectNumber: request.projectNumber,
    credentialPrincipal: request.credentialPrincipal,
    requestedBy: request.requestedBy,
    operationID,
    catalogPointerID: request.catalogPointerID,
    fromCatalogVersionID,
    toCatalogVersionID: request.toCatalogVersionID,
    programSelections: structuredClone(programSelections),
    publicationDigest: request.publicationDigest,
    requestDigest,
    immutableDocumentCount,
    createdImmutableDocumentCount,
    calculatedTransactionUnits,
  });
}

function publicationValidation(draft, sourcePath, operator) {
  const validation = validateCurriculumDraft(draft, { sourcePath });
  if (!validation.ok) {
    throw new PublicationTransactionError(
      "CURRICULUM_VALIDATION_FAILED",
      validation.issues[0]?.path ?? "",
    );
  }
  assertPublicationSourceAllowed(draft, {
    sourcePath,
    environment: operator.environment,
    projectID: operator.projectID,
    credentialPrincipal: operator.credentialPrincipal,
  });
  return validation.publication;
}

function requireFirestoreArguments(firestore, serverTimestamp) {
  if (
    !firestore ||
    typeof firestore.doc !== "function" ||
    typeof firestore.collection !== "function" ||
    typeof firestore.runTransaction !== "function"
  ) {
    fail("FIRESTORE_ARGUMENT_INVALID", "");
  }
  if (typeof serverTimestamp !== "function") {
    fail("SERVER_TIMESTAMP_FACTORY_REQUIRED", "");
  }
}

export async function publishCurriculum({
  firestore,
  draft,
  sourcePath,
  operatorContext,
  operationID,
  requestedBy,
  documentIDFieldPath,
  serverTimestamp,
  faultInjector,
} = {}) {
  assertOperationID(operationID);
  const operator = assertOperatorContext(operatorContext, requestedBy);
  requireFirestoreArguments(firestore, serverTimestamp);
  const initialPublication = publicationValidation(draft, sourcePath, operator);
  const catalogData = initialPublication.immutableDocumentsByPath[
    `catalogVersions/${draft.catalogVersion.catalogVersionID}`
  ];
  const catalogPointerID = localeToken(draft.locale);
  const initialRequest = requestObject({
    action: "publish",
    operator,
    catalogPointerID,
    toCatalogVersionID: catalogData.catalogVersionID,
    publicationDigest: initialPublication.publicationDigest,
  });
  const initialRequestDigest = calculatePublicationRequestDigest(initialRequest);

  return firestore.runTransaction(async (transaction) => {
    const publication = publicationValidation(draft, sourcePath, operator);
    const request = requestObject({
      action: "publish",
      operator,
      catalogPointerID,
      toCatalogVersionID: catalogData.catalogVersionID,
      publicationDigest: publication.publicationDigest,
    });
    const requestDigest = calculatePublicationRequestDigest(request);
    if (requestDigest !== initialRequestDigest) fail("PUBLICATION_NONDETERMINISTIC", "");

    const auditReference = firestore.doc(`contentPublicationAudit/${operationID}`);
    const auditSnapshot = await transaction.get(auditReference);
    if (auditSnapshot.exists) {
      const audit = auditSnapshot.data();
      assertReplayMatches(audit, request, operationID);
      return replayResult(audit, {
        immutableDocumentCount: publication.immutableDocuments.length,
      });
    }

    const catalogPointerReference = firestore.doc(`catalogs/${catalogPointerID}`);
    const catalogPointerSnapshot = await transaction.get(catalogPointerReference);
    const currentCatalogPointer = snapshotData(catalogPointerSnapshot);
    if (currentCatalogPointer) {
      const keys = [
        "locale",
        "publishedCatalogVersionID",
        "schemaVersion",
        "minimumClientSchemaVersion",
        "updatedAt",
      ];
      if (!exactKeys(currentCatalogPointer, keys)) fail("CATALOG_POINTER_CORRUPT", "");
      assertTimestamp(currentCatalogPointer.updatedAt, "/updatedAt");
      assertCatalogPointerSemantics(
        currentCatalogPointer,
        catalogPointerID,
        draft.locale,
      );
    }

    const immutableReferences = publication.immutableDocuments.map(({ path }) =>
      firestore.doc(path),
    );
    const identities = publication.immutableDocuments.map(({ path, data }) => ({
      path,
      data,
      identity: immutableIdentity(path, data),
    }));
    const headReferences = identities.map(({ identity }) =>
      firestore.doc(`contentVersionHeads/${identity.versionHeadID}`),
    );
    const programPointerReferences = publication.derivedPointers.programs.map(({ path }) =>
      firestore.doc(path),
    );
    const additionalReferences = [
      ...immutableReferences,
      ...headReferences,
      ...programPointerReferences,
      firestore.doc(publication.derivedConfiguration.path),
    ];
    if (currentCatalogPointer) {
      additionalReferences.push(
        firestore.doc(
          `catalogVersions/${currentCatalogPointer.publishedCatalogVersionID}`,
        ),
      );
    }
    const snapshots = await getAll(transaction, additionalReferences);

    if (currentCatalogPointer) {
      const currentPath = `catalogVersions/${currentCatalogPointer.publishedCatalogVersionID}`;
      const currentSnapshot = snapshots.get(currentPath);
      if (!currentSnapshot?.exists) fail("CURRENT_CATALOG_MISSING", "");
      assertStoredImmutableSelf(
        currentSnapshot.data(),
        "catalogVersions",
        currentCatalogPointer.publishedCatalogVersionID,
      );
      assertCatalogSemantics(currentSnapshot.data(), draft.locale);
      if (
        currentCatalogPointer.minimumClientSchemaVersion !==
        currentSnapshot.data().minimumClientSchemaVersion
      ) {
        fail("CATALOG_POINTER_CORRUPT", "");
      }
    }

    const missing = [];
    const missingWithoutHead = [];
    for (const entry of identities) {
      const immutableSnapshot = snapshots.get(entry.path);
      const headPath = `contentVersionHeads/${entry.identity.versionHeadID}`;
      const headSnapshot = snapshots.get(headPath);
      if (immutableSnapshot?.exists) {
        assertStoredImmutable(immutableSnapshot.data(), entry.data, entry.path);
        if (!headSnapshot?.exists) fail("VERSION_HEAD_MISSING", "");
        const maxVersion = assertStoredHead(headSnapshot.data(), entry.identity);
        if (entry.identity.version > maxVersion) fail("VERSION_HEAD_CORRUPT", "");
      } else {
        if (headSnapshot?.exists) {
          const maxVersion = assertStoredHead(headSnapshot.data(), entry.identity);
          if (entry.identity.version <= maxVersion) {
            fail("HISTORICAL_VERSION_NOT_MONOTONIC", "");
          }
        }
        const missingEntry = { ...entry, headSnapshot };
        missing.push(missingEntry);
        if (!headSnapshot?.exists) missingWithoutHead.push(missingEntry);
      }
    }
    await assertNoHistoricalVersionWithoutHead(
      transaction,
      firestore,
      missingWithoutHead,
      documentIDFieldPath,
    );

    const programSelections = publication.derivedPointers.programs.map((pointer) => {
      const pointerSnapshot = snapshots.get(pointer.path);
      const existing = snapshotData(pointerSnapshot);
      if (existing) {
        const expectedIdentity = {
          programPointerID: existing.programPointerID,
          programID: existing.programID,
          locale: existing.locale,
          publishedVersionID: existing.publishedVersionID,
          schemaVersion: existing.schemaVersion,
        };
        assertStoredMutable(existing, expectedIdentity, "updatedAt", "PROGRAM_POINTER_CORRUPT");
        assertProgramPointerSemantics(
          existing,
          documentIDForPath(pointer.path),
          draft.locale,
        );
      }
      return {
        programPointerID: pointer.data.programPointerID,
        fromProgramVersionID: existing?.publishedVersionID ?? null,
        toProgramVersionID: pointer.data.publishedVersionID,
      };
    });

    const targetCatalogPath = `catalogVersions/${catalogData.catalogVersionID}`;
    const targetCatalogExists = snapshots.get(targetCatalogPath)?.exists === true;
    const targetCatalogLive =
      currentCatalogPointer?.publishedCatalogVersionID === catalogData.catalogVersionID;

    if (targetCatalogExists && !targetCatalogLive) {
      fail("USE_ROLLBACK", "/toCatalogVersionID");
    }

    for (const pointer of publication.derivedPointers.programs) {
      const existing = snapshotData(snapshots.get(pointer.path));
      const selectedDocumentPath = `programVersions/${pointer.data.publishedVersionID}`;
      const selectedExists = snapshots.get(selectedDocumentPath)?.exists === true;
      if (
        selectedExists &&
        existing?.publishedVersionID !== pointer.data.publishedVersionID
      ) {
        fail("USE_ROLLBACK", "/programSelections");
      }
    }

    const configurationSnapshot = snapshots.get(publication.derivedConfiguration.path);
    const configuration = snapshotData(configurationSnapshot);
    const catalogPointerMatches = Boolean(
      currentCatalogPointer &&
        isStoredMutableMatch(
          currentCatalogPointer,
          publication.derivedPointers.catalog.data,
          "updatedAt",
        ),
    );
    const programPointersMatch = publication.derivedPointers.programs.every((pointer) => {
      const existing = snapshotData(snapshots.get(pointer.path));
      return Boolean(
        existing &&
          isStoredMutableMatch(existing, pointer.data, "updatedAt"),
      );
    });
    const configurationMatches = Boolean(
      configuration &&
        isStoredMutableMatch(
          configuration,
          publication.derivedConfiguration.data,
          "updatedAt",
        ),
    );

    let outcome;
    if (targetCatalogLive) {
      if (
        missing.length > 0 ||
        !catalogPointerMatches ||
        !programPointersMatch ||
        !configurationMatches
      ) {
        fail("LIVE_STATE_DRIFT", "");
      }
      outcome = "noOp";
    } else {
      outcome = "applied";
    }

    const documentWrites =
      outcome === "noOp"
        ? 1
        : missing.length * 2 + publication.derivedPointers.programs.length + 3;
    const budget = calculatePublicationBudget({
      immutableDocumentCount: publication.immutableDocuments.length,
      versionHeadCount: missing.length,
      programPointerCount: publication.derivedPointers.programs.length,
      canonicalDocumentBytes: publication.budget.canonicalDocumentBytes,
      documentWrites,
      timestampTransforms: documentWrites,
    });
    assertPublicationBudgetWithinLimit(budget);

    await injectFault(faultInjector, PUBLICATION_FAULT_PHASES.afterReads, {
      action: "publish",
      outcome,
      operationID,
    });

    if (outcome === "applied") {
      for (const entry of missing) {
        transaction.create(
          firestore.doc(entry.path),
          expectedWithTimestamp(entry.data, "publishedAt", serverTimestamp),
        );
        const headReference = firestore.doc(
          `contentVersionHeads/${entry.identity.versionHeadID}`,
        );
        const head = expectedVersionHead(entry.identity);
        if (entry.headSnapshot?.exists) {
          transaction.set(
            headReference,
            expectedWithTimestamp(head, "updatedAt", serverTimestamp),
          );
        } else {
          transaction.create(
            headReference,
            expectedWithTimestamp(head, "updatedAt", serverTimestamp),
          );
        }
      }
      await injectFault(
        faultInjector,
        PUBLICATION_FAULT_PHASES.afterImmutableWrites,
        { action: "publish", outcome, operationID },
      );

      transaction.set(
        catalogPointerReference,
        expectedWithTimestamp(
          publication.derivedPointers.catalog.data,
          "updatedAt",
          serverTimestamp,
        ),
      );
      for (const pointer of publication.derivedPointers.programs) {
        transaction.set(
          firestore.doc(pointer.path),
          expectedWithTimestamp(pointer.data, "updatedAt", serverTimestamp),
        );
      }
      transaction.set(
        firestore.doc(publication.derivedConfiguration.path),
        expectedWithTimestamp(
          publication.derivedConfiguration.data,
          "updatedAt",
          serverTimestamp,
        ),
      );
      await injectFault(faultInjector, PUBLICATION_FAULT_PHASES.afterPointerWrites, {
        action: "publish",
        outcome,
        operationID,
      });
    }

    const fromCatalogVersionID =
      currentCatalogPointer?.publishedCatalogVersionID ?? null;
    const audit = buildAudit({
      request,
      requestDigest,
      operationID,
      outcome,
      fromCatalogVersionID,
      programSelections,
      serverTimestamp,
    });
    transaction.create(auditReference, audit);
    await injectFault(faultInjector, PUBLICATION_FAULT_PHASES.afterAuditWrite, {
      action: "publish",
      outcome,
      operationID,
    });

    return finalResult({
      request,
      requestDigest,
      operationID,
      outcome,
      fromCatalogVersionID,
      programSelections,
      immutableDocumentCount: publication.immutableDocuments.length,
      createdImmutableDocumentCount: missing.length,
      calculatedTransactionUnits: budget.calculatedUnits,
    });
  });
}

function stripStoredDocument(data, { asset = false } = {}) {
  const withoutServerFields = { ...data };
  delete withoutServerFields.contentDigest;
  delete withoutServerFields.publishedAt;
  const draft = structuredClone(withoutServerFields);
  draft.publicationState = "draft";
  if (asset) {
    delete draft.byteCount;
    delete draft.payloadDigest;
  }
  return draft;
}

async function requireDocuments(transaction, firestore, collection, ids) {
  const references = ids.map((id) => {
    assertSafeDocumentID(id, { catalog: collection === "catalogVersions" });
    return firestore.doc(`${collection}/${id}`);
  });
  const snapshots = await getAll(transaction, references);
  return ids.map((id) => {
    const snapshot = snapshots.get(`${collection}/${id}`);
    if (!snapshot?.exists) fail("ROLLBACK_TARGET_MISSING", "");
    const data = snapshot.data();
    assertStoredImmutableSelf(data, collection, id);
    return { path: `${collection}/${id}`, data };
  });
}

function uniqueStrings(values) {
  if (!Array.isArray(values) || values.some((value) => typeof value !== "string")) {
    fail("STORED_GRAPH_INVALID", "");
  }
  return [...new Set(values)];
}

async function loadRollbackPublication({
  transaction,
  firestore,
  targetCatalog,
  targetCatalogPath,
  operator,
}) {
  const programVersionIDs = uniqueStrings(
    targetCatalog.programEntries?.map((entry) => entry?.programVersionID),
  );
  const programs = await requireDocuments(
    transaction,
    firestore,
    "programVersions",
    programVersionIDs,
  );
  const modules = await requireDocuments(
    transaction,
    firestore,
    "modules",
    uniqueStrings(programs.flatMap(({ data }) => data.moduleVersionIDs)),
  );
  const lessons = await requireDocuments(
    transaction,
    firestore,
    "lessonVersions",
    uniqueStrings(modules.flatMap(({ data }) => data.lessonVersionIDs)),
  );
  const rubrics = await requireDocuments(
    transaction,
    firestore,
    "rubricVersions",
    uniqueStrings(lessons.map(({ data }) => data.rubricVersionID)),
  );
  const evaluations = await requireDocuments(
    transaction,
    firestore,
    "evaluationContractVersions",
    uniqueStrings(rubrics.map(({ data }) => data.evaluationContractVersionID)),
  );
  const assets = await requireDocuments(
    transaction,
    firestore,
    "assetVersions",
    uniqueStrings(lessons.flatMap(({ data }) => data.assetVersionIDs)),
  );

  const draft = {
    publicationState: "draft",
    schemaVersion: targetCatalog.schemaVersion,
    minimumClientSchemaVersion: targetCatalog.minimumClientSchemaVersion,
    locale: targetCatalog.locale,
    catalogVersion: stripStoredDocument(targetCatalog),
    programVersions: programs.map(({ data }) => stripStoredDocument(data)),
    moduleVersions: modules.map(({ data }) => stripStoredDocument(data)),
    lessonVersions: lessons.map(({ data }) => stripStoredDocument(data)),
    rubricVersions: rubrics.map(({ data }) => stripStoredDocument(data)),
    evaluationContractVersions: evaluations.map(({ data }) =>
      stripStoredDocument(data),
    ),
    assetVersions: assets.map(({ data }) =>
      stripStoredDocument(data, { asset: true }),
    ),
  };
  const validation = validateCurriculumDraft(draft);
  if (!validation.ok) fail("ROLLBACK_TARGET_INVALID", validation.issues[0]?.path ?? "");
  assertPublicationSourceAllowed(draft, {
    environment: operator.environment,
    projectID: operator.projectID,
    credentialPrincipal: operator.credentialPrincipal,
  });

  const storedDocuments = [
    { path: targetCatalogPath, data: targetCatalog },
    ...programs,
    ...modules,
    ...lessons,
    ...rubrics,
    ...evaluations,
    ...assets,
  ];
  const storedByPath = new Map(storedDocuments.map((entry) => [entry.path, entry.data]));
  if (storedByPath.size !== validation.publication.immutableDocuments.length) {
    fail("ROLLBACK_TARGET_INVALID", "");
  }
  for (const expected of validation.publication.immutableDocuments) {
    const stored = storedByPath.get(expected.path);
    if (!stored) fail("ROLLBACK_TARGET_INVALID", "");
    assertStoredImmutable(stored, expected.data, expected.path);
  }
  return {
    draft,
    publication: validation.publication,
    storedDocuments,
  };
}

export async function rollbackCurriculum({
  firestore,
  catalogPointerID,
  toCatalogVersionID,
  operatorContext,
  operationID,
  requestedBy,
  serverTimestamp,
  faultInjector,
} = {}) {
  assertOperationID(operationID);
  if (
    typeof catalogPointerID !== "string" ||
    catalogPointerID !== "en-us" ||
    catalogPointerID.length > 35 ||
    !/^[a-z0-9]+(?:-[a-z0-9]+)*$/u.test(catalogPointerID)
  ) {
    fail("CATALOG_POINTER_ID_INVALID", "/catalogPointerID");
  }
  assertSafeDocumentID(toCatalogVersionID, { catalog: true });
  const operator = assertOperatorContext(operatorContext, requestedBy);
  requireFirestoreArguments(firestore, serverTimestamp);

  return firestore.runTransaction(async (transaction) => {
    const auditReference = firestore.doc(`contentPublicationAudit/${operationID}`);
    const auditSnapshot = await transaction.get(auditReference);
    const requestWithoutDigest = {
      schemaVersion: 1,
      action: "rollback",
      environment: operator.environment,
      projectID: operator.projectID,
      projectNumber: operator.projectNumber,
      credentialPrincipal: operator.credentialPrincipal,
      requestedBy: operator.requestedBy,
      catalogPointerID,
      toCatalogVersionID,
    };
    if (auditSnapshot.exists) {
      const audit = auditSnapshot.data();
      assertRollbackReplayMatches(audit, requestWithoutDigest, operationID);
      return replayResult(audit);
    }

    const catalogPointerReference = firestore.doc(`catalogs/${catalogPointerID}`);
    const targetCatalogPath = `catalogVersions/${toCatalogVersionID}`;
    const [catalogPointerSnapshot, targetCatalogSnapshot] = await Promise.all([
      transaction.get(catalogPointerReference),
      transaction.get(firestore.doc(targetCatalogPath)),
    ]);
    if (!targetCatalogSnapshot.exists) fail("ROLLBACK_TARGET_MISSING", "");
    const targetCatalog = targetCatalogSnapshot.data();
    assertStoredImmutableSelf(targetCatalog, "catalogVersions", toCatalogVersionID);
    if (localeToken(targetCatalog.locale) !== catalogPointerID) {
      fail("ROLLBACK_TARGET_INVALID", "/catalogPointerID");
    }
    const currentCatalogPointer = snapshotData(catalogPointerSnapshot);
    if (currentCatalogPointer) {
      const keys = [
        "locale",
        "publishedCatalogVersionID",
        "schemaVersion",
        "minimumClientSchemaVersion",
        "updatedAt",
      ];
      if (!exactKeys(currentCatalogPointer, keys)) fail("CATALOG_POINTER_CORRUPT", "");
      assertTimestamp(currentCatalogPointer.updatedAt, "/updatedAt");
      assertCatalogPointerSemantics(
        currentCatalogPointer,
        catalogPointerID,
        targetCatalog.locale,
      );
    }

    if (currentCatalogPointer) {
      const currentCatalogPath =
        `catalogVersions/${currentCatalogPointer.publishedCatalogVersionID}`;
      const currentCatalogSnapshot =
        currentCatalogPath === targetCatalogPath
          ? targetCatalogSnapshot
          : await transaction.get(firestore.doc(currentCatalogPath));
      if (!currentCatalogSnapshot.exists) fail("CURRENT_CATALOG_MISSING", "");
      const currentCatalog = currentCatalogSnapshot.data();
      assertStoredImmutableSelf(
        currentCatalog,
        "catalogVersions",
        currentCatalogPointer.publishedCatalogVersionID,
      );
      assertCatalogSemantics(currentCatalog, targetCatalog.locale);
      if (
        currentCatalogPointer.minimumClientSchemaVersion !==
        currentCatalog.minimumClientSchemaVersion
      ) {
        fail("CATALOG_POINTER_CORRUPT", "");
      }
    }

    const loaded = await loadRollbackPublication({
      transaction,
      firestore,
      targetCatalog,
      targetCatalogPath,
      operator,
    });
    const { publication } = loaded;
    const identities = publication.immutableDocuments.map(({ path, data }) => ({
      path,
      identity: immutableIdentity(path, data),
    }));
    const headReferences = identities.map(({ identity }) =>
      firestore.doc(`contentVersionHeads/${identity.versionHeadID}`),
    );
    const programPointerReferences = publication.derivedPointers.programs.map(({ path }) =>
      firestore.doc(path),
    );
    const stateSnapshots = await getAll(transaction, [
      ...headReferences,
      ...programPointerReferences,
      firestore.doc(publication.derivedConfiguration.path),
    ]);

    for (const { identity } of identities) {
      const headPath = `contentVersionHeads/${identity.versionHeadID}`;
      const headSnapshot = stateSnapshots.get(headPath);
      if (!headSnapshot?.exists) fail("VERSION_HEAD_MISSING", "");
      const maxVersion = assertStoredHead(headSnapshot.data(), identity);
      if (maxVersion < identity.version) fail("VERSION_HEAD_CORRUPT", "");
    }

    const programSelections = publication.derivedPointers.programs.map((pointer) => {
      const existing = snapshotData(stateSnapshots.get(pointer.path));
      if (existing) {
        const prior = {
          programPointerID: existing.programPointerID,
          programID: existing.programID,
          locale: existing.locale,
          publishedVersionID: existing.publishedVersionID,
          schemaVersion: existing.schemaVersion,
        };
        assertStoredMutable(existing, prior, "updatedAt", "PROGRAM_POINTER_CORRUPT");
        assertProgramPointerSemantics(
          existing,
          documentIDForPath(pointer.path),
          targetCatalog.locale,
        );
      }
      return {
        programPointerID: pointer.data.programPointerID,
        fromProgramVersionID: existing?.publishedVersionID ?? null,
        toProgramVersionID: pointer.data.publishedVersionID,
      };
    });

    const request = requestObject({
      action: "rollback",
      operator,
      catalogPointerID,
      toCatalogVersionID,
      publicationDigest: publication.publicationDigest,
    });
    const requestDigest = calculatePublicationRequestDigest(request);
    const catalogPointerMatches = Boolean(
      currentCatalogPointer &&
        isStoredMutableMatch(
          currentCatalogPointer,
          publication.derivedPointers.catalog.data,
          "updatedAt",
        ),
    );
    const programPointersMatch = publication.derivedPointers.programs.every((pointer) => {
      const existing = snapshotData(stateSnapshots.get(pointer.path));
      return Boolean(
        existing && isStoredMutableMatch(existing, pointer.data, "updatedAt"),
      );
    });
    const configuration = snapshotData(
      stateSnapshots.get(publication.derivedConfiguration.path),
    );
    const configurationMatches = Boolean(
      configuration &&
        isStoredMutableMatch(
          configuration,
          publication.derivedConfiguration.data,
          "updatedAt",
        ),
    );
    const outcome =
      catalogPointerMatches && programPointersMatch && configurationMatches
        ? "noOp"
        : "applied";
    const documentWrites =
      outcome === "noOp" ? 1 : publication.derivedPointers.programs.length + 3;
    const budget = calculatePublicationBudget({
      immutableDocumentCount: publication.immutableDocuments.length,
      versionHeadCount: 0,
      programPointerCount: publication.derivedPointers.programs.length,
      canonicalDocumentBytes: publication.budget.canonicalDocumentBytes,
      documentWrites,
      timestampTransforms: documentWrites,
    });
    assertPublicationBudgetWithinLimit(budget);

    await injectFault(faultInjector, PUBLICATION_FAULT_PHASES.afterReads, {
      action: "rollback",
      outcome,
      operationID,
    });
    if (outcome === "applied") {
      transaction.set(
        catalogPointerReference,
        expectedWithTimestamp(
          publication.derivedPointers.catalog.data,
          "updatedAt",
          serverTimestamp,
        ),
      );
      for (const pointer of publication.derivedPointers.programs) {
        transaction.set(
          firestore.doc(pointer.path),
          expectedWithTimestamp(pointer.data, "updatedAt", serverTimestamp),
        );
      }
      transaction.set(
        firestore.doc(publication.derivedConfiguration.path),
        expectedWithTimestamp(
          publication.derivedConfiguration.data,
          "updatedAt",
          serverTimestamp,
        ),
      );
      await injectFault(faultInjector, PUBLICATION_FAULT_PHASES.afterPointerWrites, {
        action: "rollback",
        outcome,
        operationID,
      });
    }

    const fromCatalogVersionID =
      currentCatalogPointer?.publishedCatalogVersionID ?? null;
    transaction.create(
      auditReference,
      buildAudit({
        request,
        requestDigest,
        operationID,
        outcome,
        fromCatalogVersionID,
        programSelections,
        serverTimestamp,
      }),
    );
    await injectFault(faultInjector, PUBLICATION_FAULT_PHASES.afterAuditWrite, {
      action: "rollback",
      outcome,
      operationID,
    });

    return finalResult({
      request,
      requestDigest,
      operationID,
      outcome,
      fromCatalogVersionID,
      programSelections,
      immutableDocumentCount: publication.immutableDocuments.length,
      createdImmutableDocumentCount: 0,
      calculatedTransactionUnits: budget.calculatedUnits,
    });
  });
}
