import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { after, before, beforeEach, test } from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import {
  FieldPath,
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";

import { canonicalBytes, sha256Hex } from "../../tools/content/lib/canonical-json.mjs";
import { validateCurriculumDraft } from "../../tools/content/lib/curriculum-validation.mjs";
import {
  LIVE_CREDENTIAL_TYPE,
  authorizeResolvedLiveIdentity,
  resolveOperatorIdentity,
} from "../../tools/content/lib/operator-identity.mjs";
import {
  publishCurriculum,
  rollbackCurriculum,
} from "../../tools/content/lib/publication-transactions.mjs";
import {
  commandExitCode,
  loadScannedCurriculumSource,
  safeIssue,
} from "../../tools/content/lib/publication-cli.mjs";
import {
  CATALOG_POINTER_ID,
  FIXTURE_PATH,
  OPERATOR_CONTEXT,
  PROGRAM_POINTER_ID,
  PROJECT_ID,
  PUBLICATION_COLLECTIONS,
  REPOSITORY_ROOT,
  VERSION_HEADS,
  catalogOnlyVersionedDraft,
  cloneDraft,
  fullyVersionedDraft,
  loadMinimalDraft,
  nextOperationID,
  overBudgetDraft,
} from "../helpers/curriculum-publication-fixtures.mjs";

const emulatorAddress = process.env.FIRESTORE_EMULATOR_HOST;
assert.ok(
  emulatorAddress,
  "The publication suite must run through its isolated Firestore emulator runner.",
);

const PUBLISH_PHASES = Object.freeze([
  "afterReads",
  "afterImmutableWrites",
  "afterPointerWrites",
  "afterAuditWrite",
]);
const ROLLBACK_PHASES = Object.freeze([
  "afterReads",
  "afterPointerWrites",
  "afterAuditWrite",
]);
const SENSITIVE_FIXTURE_STRINGS = Object.freeze([
  "SYNTHETIC-CONTRACT-FIXTURE-NEVER-PUBLISH",
  "Synthetic placeholder text for contract validation only",
  "Which synthetic option is the fixture's deterministic contract sentinel?",
  "Synthetic option A",
  "Synthetic correct-feedback placeholder",
  "correctOptionID",
]);

let app;
let firestore;
let temporaryDirectory;
let minimalDraft;

before(async () => {
  temporaryDirectory = await mkdtemp(
    path.join(os.tmpdir(), "syntholo-publication-tests."),
  );
  minimalDraft = await loadMinimalDraft();
  app = initializeApp(
    { projectId: PROJECT_ID },
    `curriculum-publication-${process.pid}`,
  );
  firestore = getFirestore(app);
  await clearEmulator();
});

beforeEach(async () => {
  await clearEmulator();
});

after(async () => {
  if (app) await deleteApp(app);
  if (temporaryDirectory) {
    await rm(temporaryDirectory, { recursive: true, force: true });
  }
});

function serverTimestamp() {
  return FieldValue.serverTimestamp();
}

async function clearEmulator() {
  const response = await fetch(
    `http://${emulatorAddress}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(
    response.ok,
    true,
    `Firestore emulator clear failed: ${response.status} ${await response.text()}`,
  );
}

function publish(
  draft,
  {
    operationID = nextOperationID(),
    operatorContext = OPERATOR_CONTEXT,
    requestedBy = null,
    faultInjector,
    sourcePath = FIXTURE_PATH,
  } = {},
) {
  return publishCurriculum({
    firestore,
    draft,
    sourcePath,
    operatorContext: { ...operatorContext, requestedBy },
    operationID,
    requestedBy,
    documentIDFieldPath: FieldPath.documentId(),
    serverTimestamp,
    faultInjector,
  });
}

function rollback(
  toCatalogVersionID,
  {
    operationID = nextOperationID(),
    operatorContext = OPERATOR_CONTEXT,
    requestedBy = null,
    faultInjector,
  } = {},
) {
  return rollbackCurriculum({
    firestore,
    catalogPointerID: CATALOG_POINTER_ID,
    toCatalogVersionID,
    operatorContext: { ...operatorContext, requestedBy },
    operationID,
    requestedBy,
    serverTimestamp,
    faultInjector,
  });
}

function normalizeFirestoreValue(value) {
  if (value instanceof Timestamp) {
    return {
      __timestamp: true,
      seconds: value.seconds,
      nanoseconds: value.nanoseconds,
    };
  }
  if (Array.isArray(value)) return value.map(normalizeFirestoreValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, child]) => [key, normalizeFirestoreValue(child)]),
    );
  }
  return value;
}

async function snapshotPublicationState() {
  const entries = [];
  for (const collectionName of PUBLICATION_COLLECTIONS) {
    const snapshot = await firestore.collection(collectionName).get();
    for (const document of snapshot.docs) {
      entries.push([
        `${collectionName}/${document.id}`,
        normalizeFirestoreValue(document.data()),
      ]);
    }
  }
  return Object.fromEntries(
    entries.sort(([left], [right]) => left.localeCompare(right)),
  );
}

function changedPaths(beforeState, afterState) {
  const paths = new Set([
    ...Object.keys(beforeState),
    ...Object.keys(afterState),
  ]);
  return [...paths]
    .filter(
      (documentPath) =>
        JSON.stringify(beforeState[documentPath]) !==
        JSON.stringify(afterState[documentPath]),
    )
    .sort();
}

async function assertRejectedWithoutMutation(action, messagePattern) {
  const beforeState = await snapshotPublicationState();
  await assert.rejects(action, (error) => {
    if (messagePattern) {
      assert.match(`${error.code ?? ""} ${error.message}`, messagePattern);
    }
    return true;
  });
  const afterState = await snapshotPublicationState();
  assert.deepEqual(afterState, beforeState);
}

function assertSafeMetadata(value) {
  const serialized = JSON.stringify(value);
  for (const sensitiveString of SENSITIVE_FIXTURE_STRINGS) {
    assert.equal(
      serialized.includes(sensitiveString),
      false,
      `Safe metadata disclosed curriculum content: ${sensitiveString}`,
    );
  }
}

function assertSafeCommandOutput(result) {
  const combined = `${result.stdout}\n${result.stderr}`;
  for (const sensitiveString of SENSITIVE_FIXTURE_STRINGS) {
    assert.equal(
      combined.includes(sensitiveString),
      false,
      `CLI output disclosed curriculum content: ${sensitiveString}`,
    );
  }
}

function runNodeCLI(relativePath, argumentsList, environment = {}) {
  return spawnSync(process.execPath, [relativePath, ...argumentsList], {
    cwd: REPOSITORY_ROOT,
    env: { ...process.env, ...environment },
    encoding: "utf8",
    timeout: 60_000,
    maxBuffer: 2 * 1024 * 1024,
  });
}

function firebaseAdminImportGuardNodeOptions() {
  return [
    process.env.NODE_OPTIONS ?? "",
    `--experimental-loader=${path.join(
      REPOSITORY_ROOT,
      "tests/helpers/reject-firebase-admin-loader.mjs",
    )}`,
  ].filter(Boolean).join(" ");
}

async function writeDraft(name, draft) {
  const destination = path.join(temporaryDirectory, name);
  await writeFile(destination, `${JSON.stringify(draft, null, 2)}\n`, "utf8");
  return destination;
}

async function writeScannerRecognizedSecretDraft() {
  const sourcePath = path.join(temporaryDirectory, "planted-secret.json");
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const planted = cloneDraft(minimalDraft);
    const accessKey = `AKIA${randomBytes(8).toString("hex").toUpperCase()}`;
    const secretKey = randomBytes(30).toString("base64").slice(0, 40);
    planted.programVersions[0].promise =
      `gitleaks:allow AWS_ACCESS_KEY_ID=${accessKey} AWS_SECRET_ACCESS_KEY=${secretKey}`;
    await writeFile(sourcePath, `${JSON.stringify(planted, null, 2)}\n`, "utf8");
    const scan = spawnSync(
      path.join(REPOSITORY_ROOT, "scripts/scan_secrets.sh"),
      ["--generated", sourcePath],
      {
        cwd: REPOSITORY_ROOT,
        env: process.env,
        encoding: "utf8",
        timeout: 30_000,
      },
    );
    if (scan.status === 1) return sourcePath;
  }
  assert.fail("Could not construct a redacted credential fixture recognized by the pinned scanner.");
}

function publishCLIArguments({
  operationID = nextOperationID(),
  mode = "--dry-run",
  source = FIXTURE_PATH,
} = {}) {
  return [
    mode,
    "--operation-id",
    operationID,
    "--environment",
    "emulator",
    "--project",
    PROJECT_ID,
    "--confirm-project",
    PROJECT_ID,
    "--source",
    source,
  ];
}

function rollbackCLIArguments({
  operationID = nextOperationID(),
  mode = "--dry-run",
  toCatalogVersionID = "catalog--en-us--v1",
} = {}) {
  return [
    mode,
    "--operation-id",
    operationID,
    "--environment",
    "emulator",
    "--project",
    PROJECT_ID,
    "--confirm-project",
    PROJECT_ID,
    "--catalog-pointer",
    CATALOG_POINTER_ID,
    "--to-catalog-version",
    toCatalogVersionID,
  ];
}

function assertTimestamp(value, label) {
  assert.ok(value instanceof Timestamp, `${label} must be a Firestore Timestamp.`);
}

async function assertVersionHeads(version) {
  for (const expected of VERSION_HEADS) {
    const snapshot = await firestore.doc(expected.path).get();
    assert.equal(snapshot.exists, true, `${expected.path} must exist.`);
    const data = snapshot.data();
    assert.deepEqual(
      Object.keys(data).sort(),
      [
        "kind",
        "locale",
        "maxPublishedVersion",
        "schemaVersion",
        "stableID",
        "updatedAt",
        "versionHeadID",
      ],
    );
    assert.equal(data.versionHeadID, expected.path.split("/")[1]);
    assert.equal(data.kind, expected.kind);
    assert.equal(data.stableID, expected.stableID);
    assert.equal(data.locale, "en-US");
    assert.equal(data.maxPublishedVersion, version);
    assert.equal(data.schemaVersion, 1);
    assertTimestamp(data.updatedAt, `${expected.path}.updatedAt`);
  }
}

async function assertImmutableDocuments(draft) {
  const validation = validateCurriculumDraft(draft, { sourcePath: FIXTURE_PATH });
  assert.equal(validation.ok, true, JSON.stringify(validation.issues));
  for (const expected of validation.publication.immutableDocuments) {
    const snapshot = await firestore.doc(expected.path).get();
    assert.equal(snapshot.exists, true, `${expected.path} must exist.`);
    const actual = snapshot.data();
    assertTimestamp(actual.publishedAt, `${expected.path}.publishedAt`);
    delete actual.publishedAt;
    assert.deepEqual(actual, expected.data, expected.path);
  }
  return validation.publication;
}

async function immutableAndHeadState() {
  const state = await snapshotPublicationState();
  return Object.fromEntries(
    Object.entries(state).filter(([documentPath]) =>
      /^(?:assetVersions|catalogVersions|contentVersionHeads|evaluationContractVersions|lessonVersions|modules|programVersions|rubricVersions)\//.test(
        documentPath,
      ),
    ),
  );
}

test("publish and rollback CLIs enforce exclusive mode and explicit identity arguments", async () => {
  const base = publishCLIArguments();
  const noMode = runNodeCLI(
    "tools/content/publish.mjs",
    base.filter((argument) => argument !== "--dry-run"),
  );
  assert.notEqual(noMode.status, 0);

  const bothModes = runNodeCLI("tools/content/publish.mjs", [
    "--apply",
    ...base,
  ]);
  assert.notEqual(bothModes.status, 0);

  const missingConfirmation = runNodeCLI(
    "tools/content/publish.mjs",
    base.filter((argument, index, values) =>
      argument !== "--confirm-project" && values[index - 1] !== "--confirm-project"),
  );
  assert.notEqual(missingConfirmation.status, 0);

  const callerPrincipal = runNodeCLI("tools/content/publish.mjs", [
    ...base,
    "--credential-principal",
    "forged@example.invalid",
  ]);
  assert.notEqual(callerPrincipal.status, 0);

  const rollbackBothModes = runNodeCLI("tools/content/rollback.mjs", [
    "--apply",
    ...rollbackCLIArguments(),
  ]);
  assert.notEqual(rollbackBothModes.status, 0);

  for (const result of [
    noMode,
    bothModes,
    missingConfirmation,
    callerPrincipal,
    rollbackBothModes,
  ]) {
    assertSafeCommandOutput(result);
  }

  const poisonedADC = runNodeCLI(
    "tools/content/publish.mjs",
    publishCLIArguments({ mode: "--apply" }),
    {
      FIRESTORE_EMULATOR_HOST: emulatorAddress,
      FIRESTORE_PREFER_REST: "true",
      GOOGLE_APPLICATION_CREDENTIALS:
        "/definitely/missing/syntholo-adc.json",
      NODE_OPTIONS: firebaseAdminImportGuardNodeOptions(),
    },
  );
  assert.notEqual(poisonedADC.status, 0);
  assertSafeCommandOutput(poisonedADC);
  assert.match(
    `${poisonedADC.stdout}\n${poisonedADC.stderr}`,
    /EMULATOR_REST_TRANSPORT_FORBIDDEN/,
  );
  assert.doesNotMatch(
    `${poisonedADC.stdout}\n${poisonedADC.stderr}`,
    /\/definitely|ENOENT|FIREBASE_ADMIN_IMPORTED_BEFORE_SOURCE_SCAN/,
  );
  assert.deepEqual(await snapshotPublicationState(), {});

  const foreign = Object.assign(new Error("foreign SDK failure"), {
    code: "ENOENT",
    path: "/definitely/missing/syntholo-adc.json",
    exitCode: 0,
    issues: [
      {
        code: "ENOENT",
        path: "/definitely/missing/syntholo-adc.json",
      },
    ],
  });
  assert.deepEqual(safeIssue(foreign), [
    { code: "PUBLICATION_REJECTED", path: "" },
  ]);
  assert.equal(commandExitCode(foreign), 1);
});

test("publish dry-run emits safe structural metadata without constructing or writing Firestore", async () => {
  const result = runNodeCLI(
    "tools/content/publish.mjs",
    publishCLIArguments(),
    {
      FIRESTORE_EMULATOR_HOST: "127.0.0.1:1",
      NODE_OPTIONS: firebaseAdminImportGuardNodeOptions(),
    },
  );
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
  assertSafeCommandOutput(result);
  assert.match(result.stdout, /catalog--en-us--v1/);
  assert.match(result.stdout, /syntholo-local/);
  assert.deepEqual(await snapshotPublicationState(), {});
});

test("publish apply CLI commits the synthetic graph and emits only safe metadata", async () => {
  const result = runNodeCLI(
    "tools/content/publish.mjs",
    publishCLIArguments({ mode: "--apply" }),
  );
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
  assertSafeCommandOutput(result);
  assert.match(result.stdout, /applied/);
  const pointer = await firestore.doc(`catalogs/${CATALOG_POINTER_ID}`).get();
  assert.equal(pointer.data().publishedCatalogVersionID, "catalog--en-us--v1");
});

test("rollback dry-run emits safe metadata and leaves an existing graph unchanged", async () => {
  await publish(minimalDraft);
  const beforeState = await snapshotPublicationState();
  const result = runNodeCLI(
    "tools/content/rollback.mjs",
    rollbackCLIArguments(),
    { NODE_OPTIONS: firebaseAdminImportGuardNodeOptions() },
  );
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
  assertSafeCommandOutput(result);
  assert.match(result.stdout, /catalog--en-us--v1/);
  assert.deepEqual(await snapshotPublicationState(), beforeState);
});

test("first publish atomically creates the complete immutable graph, heads, pointers, configuration, and audit", async () => {
  const operationID = nextOperationID();
  const result = await publish(minimalDraft, { operationID });
  const publication = await assertImmutableDocuments(minimalDraft);
  await assertVersionHeads(1);

  assert.equal(result.action, "publish");
  assert.equal(result.outcome, "applied");
  assert.equal(result.replay, false);
  assert.equal(result.operationID, operationID);
  assert.equal(result.catalogPointerID, CATALOG_POINTER_ID);
  assert.equal(result.fromCatalogVersionID, null);
  assert.equal(result.toCatalogVersionID, "catalog--en-us--v1");
  assert.equal(result.publicationDigest, publication.publicationDigest);
  assert.equal(result.immutableDocumentCount, 7);
  assert.equal(result.createdImmutableDocumentCount, 7);
  assert.equal(result.calculatedTransactionUnits, 36);
  assertSafeMetadata(result);

  const catalogPointer = (
    await firestore.doc(`catalogs/${CATALOG_POINTER_ID}`).get()
  ).data();
  assert.deepEqual(Object.keys(catalogPointer).sort(), [
    "locale",
    "minimumClientSchemaVersion",
    "publishedCatalogVersionID",
    "schemaVersion",
    "updatedAt",
  ]);
  assert.equal(catalogPointer.locale, "en-US");
  assert.equal(catalogPointer.publishedCatalogVersionID, "catalog--en-us--v1");
  assert.equal(catalogPointer.schemaVersion, 1);
  assert.equal(catalogPointer.minimumClientSchemaVersion, 1);
  assertTimestamp(catalogPointer.updatedAt, "catalog pointer updatedAt");

  const programPointer = (
    await firestore.doc(`programs/${PROGRAM_POINTER_ID}`).get()
  ).data();
  assert.deepEqual(Object.keys(programPointer).sort(), [
    "locale",
    "programID",
    "programPointerID",
    "publishedVersionID",
    "schemaVersion",
    "updatedAt",
  ]);
  assert.equal(programPointer.programPointerID, PROGRAM_POINTER_ID);
  assert.equal(programPointer.programID, "ai-foundations");
  assert.equal(programPointer.publishedVersionID, "ai-foundations--en-us--v1");
  assertTimestamp(programPointer.updatedAt, "program pointer updatedAt");

  const configuration = (
    await firestore.doc("featureConfiguration/curriculum").get()
  ).data();
  assert.deepEqual(Object.keys(configuration).sort(), [
    "catalogPointerIDs",
    "defaultLocale",
    "minimumClientSchemaVersion",
    "schemaVersion",
    "supportedLocales",
    "updatedAt",
  ]);
  assert.deepEqual(configuration.supportedLocales, ["en-US"]);
  assert.deepEqual(configuration.catalogPointerIDs, [CATALOG_POINTER_ID]);
  assertTimestamp(configuration.updatedAt, "configuration updatedAt");

  const audit = (
    await firestore.doc(`contentPublicationAudit/${operationID}`).get()
  ).data();
  assert.deepEqual(Object.keys(audit).sort(), [
    "action",
    "catalogPointerID",
    "credentialPrincipal",
    "environment",
    "fromCatalogVersionID",
    "occurredAt",
    "operationID",
    "outcome",
    "programSelections",
    "projectID",
    "projectNumber",
    "publicationDigest",
    "requestDigest",
    "requestedBy",
    "schemaVersion",
    "toCatalogVersionID",
  ]);
  assert.equal(audit.operationID, operationID);
  assert.equal(audit.action, "publish");
  assert.equal(audit.outcome, "applied");
  assert.equal(audit.environment, "emulator");
  assert.equal(audit.projectID, PROJECT_ID);
  assert.equal(audit.projectNumber, "emulator");
  assert.equal(audit.credentialPrincipal, "emulator-local");
  assert.equal(audit.requestedBy, null);
  assert.equal(audit.catalogPointerID, CATALOG_POINTER_ID);
  assert.equal(audit.fromCatalogVersionID, null);
  assert.equal(audit.toCatalogVersionID, "catalog--en-us--v1");
  assert.deepEqual(audit.programSelections, [
    {
      programPointerID: PROGRAM_POINTER_ID,
      fromProgramVersionID: null,
      toProgramVersionID: "ai-foundations--en-us--v1",
    },
  ]);
  assert.equal(audit.publicationDigest, publication.publicationDigest);
  assert.equal(
    audit.requestDigest,
    sha256Hex(
      canonicalBytes({
        schemaVersion: 1,
        action: "publish",
        environment: "emulator",
        projectID: PROJECT_ID,
        projectNumber: "emulator",
        credentialPrincipal: "emulator-local",
        requestedBy: null,
        catalogPointerID: CATALOG_POINTER_ID,
        toCatalogVersionID: "catalog--en-us--v1",
        publicationDigest: publication.publicationDigest,
      }),
    ),
  );
  assertTimestamp(audit.occurredAt, "audit occurredAt");
  assert.equal(Object.keys(await snapshotPublicationState()).length, 18);
});

test("requested-by remains descriptive while the derived principal authors the audit", async () => {
  const operationID = nextOperationID();
  const result = await publish(minimalDraft, {
    operationID,
    requestedBy: "synthetic release operator",
  });
  const audit = (
    await firestore.doc(`contentPublicationAudit/${operationID}`).get()
  ).data();
  assert.equal(audit.requestedBy, "synthetic release operator");
  assert.equal(audit.credentialPrincipal, "emulator-local");
  assert.equal(result.requestedBy, "synthetic release operator");
  assert.equal(result.credentialPrincipal, "emulator-local");
});

test("same-live same-digest publish writes exactly one no-op audit and no mutable timestamp", async () => {
  await publish(minimalDraft);
  const beforeState = await snapshotPublicationState();
  const operationID = nextOperationID();
  const result = await publish(minimalDraft, { operationID });
  const afterState = await snapshotPublicationState();

  assert.equal(result.outcome, "noOp");
  assert.equal(result.replay, false);
  assert.equal(result.createdImmutableDocumentCount, 0);
  assert.equal(result.calculatedTransactionUnits, 2);
  assertSafeMetadata(result);
  assert.deepEqual(changedPaths(beforeState, afterState), [
    `contentPublicationAudit/${operationID}`,
  ]);
  const audit = afterState[`contentPublicationAudit/${operationID}`];
  assert.equal(audit.outcome, "noOp");
  assert.equal(audit.fromCatalogVersionID, "catalog--en-us--v1");
  assert.deepEqual(audit.programSelections, [
    {
      fromProgramVersionID: "ai-foundations--en-us--v1",
      programPointerID: PROGRAM_POINTER_ID,
      toProgramVersionID: "ai-foundations--en-us--v1",
    },
  ]);
});

test("publish operation replay returns the recorded outcome after later state changes and writes nothing", async () => {
  const firstOperationID = nextOperationID();
  await publish(minimalDraft, { operationID: firstOperationID });
  await publish(fullyVersionedDraft(minimalDraft, 2));
  const beforeReplay = await snapshotPublicationState();

  const result = await publish(minimalDraft, { operationID: firstOperationID });
  assert.equal(result.outcome, "applied");
  assert.equal(result.replay, true);
  assert.equal(result.operationID, firstOperationID);
  assertSafeMetadata(result);
  assert.deepEqual(await snapshotPublicationState(), beforeReplay);
  const livePointer = (
    await firestore.doc(`catalogs/${CATALOG_POINTER_ID}`).get()
  ).data();
  assert.equal(livePointer.publishedCatalogVersionID, "catalog--en-us--v2");
});

test("publish rejects an operation-ID collision without changing state", async () => {
  const operationID = nextOperationID();
  await publish(minimalDraft, { operationID });
  await assertRejectedWithoutMutation(
    () => publish(fullyVersionedDraft(minimalDraft, 2), { operationID }),
    /operation|collision|request/i,
  );
});

test("publish rejects a corrupt stored audit instead of replaying unsafe metadata", async () => {
  const operationID = nextOperationID();
  await publish(minimalDraft, { operationID });
  const auditReference = firestore.doc(`contentPublicationAudit/${operationID}`);
  const originalAudit = (await auditReference.get()).data();
  const corruptions = [
    ["schemaVersion", 2],
    ["operationID", nextOperationID()],
    ["requestDigest", "1".repeat(64)],
    ["action", "rollback"],
    ["outcome", "corrupt"],
    ["environment", "staging"],
    ["projectID", "corrupt-project"],
    ["projectNumber", "999999999999"],
    ["credentialPrincipal", "corrupt-principal"],
    ["requestedBy", "corrupt requester"],
    ["catalogPointerID", "fr-fr"],
    ["fromCatalogVersionID", "not-a-catalog-version"],
    ["toCatalogVersionID", "catalog--en-us--v2"],
    [
      "programSelections",
      [],
    ],
    ["publicationDigest", "0".repeat(64)],
  ];

  for (const [field, value] of corruptions) {
    await auditReference.set({ ...originalAudit, [field]: value });
    await assertRejectedWithoutMutation(
      () => publish(minimalDraft, { operationID }),
      /audit|collision|request|corrupt/i,
    );
  }

  const correlatedFrenchAudit = {
    ...originalAudit,
    catalogPointerID: "fr-fr",
    toCatalogVersionID: "catalog--fr-fr--v1",
    programSelections: [
      {
        programPointerID: "ai-foundations--fr-fr",
        fromProgramVersionID: null,
        toProgramVersionID: "ai-foundations--fr-fr--v1",
      },
    ],
  };
  correlatedFrenchAudit.requestDigest = sha256Hex(
    canonicalBytes({
      schemaVersion: correlatedFrenchAudit.schemaVersion,
      action: correlatedFrenchAudit.action,
      environment: correlatedFrenchAudit.environment,
      projectID: correlatedFrenchAudit.projectID,
      projectNumber: correlatedFrenchAudit.projectNumber,
      credentialPrincipal: correlatedFrenchAudit.credentialPrincipal,
      requestedBy: correlatedFrenchAudit.requestedBy,
      catalogPointerID: correlatedFrenchAudit.catalogPointerID,
      toCatalogVersionID: correlatedFrenchAudit.toCatalogVersionID,
      publicationDigest: correlatedFrenchAudit.publicationDigest,
    }),
  );
  await auditReference.set(correlatedFrenchAudit);
  await assertRejectedWithoutMutation(
    () => publish(minimalDraft, { operationID }),
    /OPERATION_AUDIT_CORRUPT/,
  );
});

test("publisher rejects different content at an existing immutable version ID", async () => {
  await publish(minimalDraft);
  const collision = cloneDraft(minimalDraft);
  collision.programVersions[0].promise =
    "A different synthetic payload at the same immutable version identity.";
  await assertRejectedWithoutMutation(
    () => publish(collision),
    /digest|immutable|collision|different/i,
  );
});

test("publisher compares the entire immutable shape even when a stored digest is unchanged", async () => {
  await publish(minimalDraft);
  await firestore.doc("programVersions/ai-foundations--en-us--v1").update({
    promise: "Corrupt stored shape retaining its prior digest.",
  });
  await assertRejectedWithoutMutation(
    () => publish(minimalDraft),
    /shape|digest|immutable|corrupt/i,
  );
});

test("publisher fails closed when an existing immutable document has no version head", async () => {
  await publish(minimalDraft);
  await firestore
    .doc("contentVersionHeads/lesson--synthetic-lesson--en-us")
    .delete();
  await assertRejectedWithoutMutation(
    () => publish(minimalDraft),
    /head|corrupt/i,
  );
});

test("publisher cannot treat a later version as first publication when historical data exists without its head", async () => {
  await publish(minimalDraft);
  await firestore
    .doc("lessonVersions/synthetic-lesson--en-us--v1")
    .update({ lessonID: "corrupt-history", locale: "fr-FR" });
  await firestore
    .doc("contentVersionHeads/lesson--synthetic-lesson--en-us")
    .delete();
  await assertRejectedWithoutMutation(
    () => publish(fullyVersionedDraft(minimalDraft, 2)),
    /head|corrupt|history/i,
  );

  await clearEmulator();
  await firestore
    .doc("lessonVersions/synthetic-lesson--en-us--v\uffff")
    .set({ lessonID: "corrupt-high-suffix", locale: "fr-FR" });
  await assertRejectedWithoutMutation(
    () => publish(minimalDraft),
    /head|corrupt|history/i,
  );
});

test("publisher fails closed when an immutable version exceeds its corrupt historical head", async () => {
  const versionTwo = fullyVersionedDraft(minimalDraft, 2);
  await publish(versionTwo);
  await firestore
    .doc("contentVersionHeads/lesson--synthetic-lesson--en-us")
    .update({ maxPublishedVersion: 1 });
  await assertRejectedWithoutMutation(
    () => publish(versionTwo),
    /head|corrupt|version/i,
  );
});

test("publisher never recreates a missing immutable version at or below its historical maximum", async () => {
  await publish(minimalDraft);
  await firestore.doc("lessonVersions/synthetic-lesson--en-us--v1").delete();
  await assertRejectedWithoutMutation(
    () => publish(minimalDraft),
    /head|historical|corrupt|version/i,
  );
});

test("same-live mutable pointer drift fails closed and is never repaired by publish", async () => {
  await publish(minimalDraft);
  await firestore.doc(`programs/${PROGRAM_POINTER_ID}`).update({
    publishedVersionID: "ai-foundations--en-us--v999",
  });
  await assertRejectedWithoutMutation(
    () => publish(minimalDraft),
    /drift|pointer|rollback|corrupt/i,
  );
});

test("publisher rejects semantic corruption in the current catalog before deriving a transition", async () => {
  await publish(minimalDraft);
  await firestore.doc("catalogVersions/catalog--en-us--v1").update({
    locale: "fr-FR",
  });
  await assertRejectedWithoutMutation(
    () => publish(fullyVersionedDraft(minimalDraft, 2)),
    /catalog|locale|digest|corrupt|shape|graph|stored/i,
  );
});

test("publisher rejects an existing non-live target catalog and requires rollback", async () => {
  await publish(minimalDraft);
  const versionTwo = fullyVersionedDraft(minimalDraft, 2);
  await publish(versionTwo);
  await rollback("catalog--en-us--v1");
  await assertRejectedWithoutMutation(
    () => publish(versionTwo),
    /rollback|non-live|catalog/i,
  );
});

test("publisher rejects a new catalog that would repoint a program to an existing non-live version", async () => {
  await publish(minimalDraft);
  const versionTwo = fullyVersionedDraft(minimalDraft, 2);
  await publish(versionTwo);
  await rollback("catalog--en-us--v1");
  const catalogThreeSelectingProgramTwo = catalogOnlyVersionedDraft(
    versionTwo,
    3,
  );
  await assertRejectedWithoutMutation(
    () => publish(catalogThreeSelectingProgramTwo),
    /rollback|non-live|program/i,
  );
});

test("v2 roll-forward creates every new immutable version and atomically advances every historical head", async () => {
  await publish(minimalDraft);
  const versionTwo = fullyVersionedDraft(minimalDraft, 2);
  const result = await publish(versionTwo);
  await assertImmutableDocuments(minimalDraft);
  await assertImmutableDocuments(versionTwo);
  await assertVersionHeads(2);

  assert.equal(result.outcome, "applied");
  assert.equal(result.createdImmutableDocumentCount, 7);
  assert.equal(result.immutableDocumentCount, 7);
  assert.equal(result.calculatedTransactionUnits, 36);
  assert.equal(
    (await firestore.doc(`catalogs/${CATALOG_POINTER_ID}`).get()).data()
      .publishedCatalogVersionID,
    "catalog--en-us--v2",
  );
  assert.equal(
    (await firestore.doc(`programs/${PROGRAM_POINTER_ID}`).get()).data()
      .publishedVersionID,
    "ai-foundations--en-us--v2",
  );
});

test("immutable catalogs pin complete versioned graphs independently of mutable program pointers", async () => {
  await publish(minimalDraft);
  const versionTwo = fullyVersionedDraft(minimalDraft, 2);
  await publish(versionTwo);

  const catalogOne = (
    await firestore.doc("catalogVersions/catalog--en-us--v1").get()
  ).data();
  const catalogTwo = (
    await firestore.doc("catalogVersions/catalog--en-us--v2").get()
  ).data();
  assert.deepEqual(catalogOne.programEntries, [
    {
      programPointerID: PROGRAM_POINTER_ID,
      programVersionID: "ai-foundations--en-us--v1",
    },
  ]);
  assert.deepEqual(catalogTwo.programEntries, [
    {
      programPointerID: PROGRAM_POINTER_ID,
      programVersionID: "ai-foundations--en-us--v2",
    },
  ]);
  assert.equal(
    (await firestore.doc(`programs/${PROGRAM_POINTER_ID}`).get()).data()
      .publishedVersionID,
    "ai-foundations--en-us--v2",
  );
  assert.equal(
    (
      await firestore.doc("lessonVersions/synthetic-lesson--en-us--v1").get()
    ).exists,
    true,
  );
  assert.equal(
    (
      await firestore.doc("lessonVersions/synthetic-lesson--en-us--v2").get()
    ).exists,
    true,
  );
});

test("exact catalog rollback changes only pointers/configuration and audit while preserving immutables and historical maxima", async () => {
  await publish(minimalDraft);
  await publish(fullyVersionedDraft(minimalDraft, 2));
  const immutableBefore = await immutableAndHeadState();
  const operationID = nextOperationID();
  const result = await rollback("catalog--en-us--v1", { operationID });
  const immutableAfter = await immutableAndHeadState();

  assert.deepEqual(immutableAfter, immutableBefore);
  assert.equal(result.action, "rollback");
  assert.equal(result.outcome, "applied");
  assert.equal(result.replay, false);
  assert.equal(result.fromCatalogVersionID, "catalog--en-us--v2");
  assert.equal(result.toCatalogVersionID, "catalog--en-us--v1");
  assert.equal(result.createdImmutableDocumentCount, 0);
  assert.equal(result.calculatedTransactionUnits, 8);
  assertSafeMetadata(result);
  await assertVersionHeads(2);
  assert.equal(
    (await firestore.doc(`catalogs/${CATALOG_POINTER_ID}`).get()).data()
      .publishedCatalogVersionID,
    "catalog--en-us--v1",
  );
  assert.equal(
    (await firestore.doc(`programs/${PROGRAM_POINTER_ID}`).get()).data()
      .publishedVersionID,
    "ai-foundations--en-us--v1",
  );
  const audit = (
    await firestore.doc(`contentPublicationAudit/${operationID}`).get()
  ).data();
  assert.equal(audit.action, "rollback");
  assert.equal(audit.outcome, "applied");
  assert.deepEqual(audit.programSelections, [
    {
      programPointerID: PROGRAM_POINTER_ID,
      fromProgramVersionID: "ai-foundations--en-us--v2",
      toProgramVersionID: "ai-foundations--en-us--v1",
    },
  ]);
});

test("repeated rollback under a new operation ID writes one no-op audit and no pointer timestamp", async () => {
  await publish(minimalDraft);
  await publish(fullyVersionedDraft(minimalDraft, 2));
  await rollback("catalog--en-us--v1");
  const beforeState = await snapshotPublicationState();
  const operationID = nextOperationID();
  const result = await rollback("catalog--en-us--v1", { operationID });
  const afterState = await snapshotPublicationState();

  assert.equal(result.outcome, "noOp");
  assert.equal(result.replay, false);
  assert.equal(result.calculatedTransactionUnits, 2);
  assertSafeMetadata(result);
  assert.deepEqual(changedPaths(beforeState, afterState), [
    `contentPublicationAudit/${operationID}`,
  ]);
});

test("rollback operation replay returns its recorded outcome after a later roll-forward and writes nothing", async () => {
  await publish(minimalDraft);
  await publish(fullyVersionedDraft(minimalDraft, 2));
  const rollbackOperationID = nextOperationID();
  await rollback("catalog--en-us--v1", { operationID: rollbackOperationID });
  await rollback("catalog--en-us--v2");
  const beforeReplay = await snapshotPublicationState();

  const result = await rollback("catalog--en-us--v1", {
    operationID: rollbackOperationID,
  });
  assert.equal(result.outcome, "applied");
  assert.equal(result.replay, true);
  assertSafeMetadata(result);
  assert.deepEqual(await snapshotPublicationState(), beforeReplay);
  assert.equal(
    (await firestore.doc(`catalogs/${CATALOG_POINTER_ID}`).get()).data()
      .publishedCatalogVersionID,
    "catalog--en-us--v2",
  );
});

test("rollback rejects an operation-ID collision without changing state", async () => {
  await publish(minimalDraft);
  await publish(fullyVersionedDraft(minimalDraft, 2));
  const operationID = nextOperationID();
  await rollback("catalog--en-us--v1", { operationID });
  await assertRejectedWithoutMutation(
    () => rollback("catalog--en-us--v2", { operationID }),
    /operation|collision|request/i,
  );
});

test("rollback rejects a target graph with a missing immutable document and preserves current selection", async () => {
  await publish(minimalDraft);
  await publish(fullyVersionedDraft(minimalDraft, 2));
  await firestore.doc("lessonVersions/synthetic-lesson--en-us--v1").delete();
  await assertRejectedWithoutMutation(
    () => rollback("catalog--en-us--v1"),
    /missing|graph|immutable|corrupt/i,
  );
  assert.equal(
    (await firestore.doc(`catalogs/${CATALOG_POINTER_ID}`).get()).data()
      .publishedCatalogVersionID,
    "catalog--en-us--v2",
  );
});

test("rollback rejects malformed or cross-program immutable content and preserves current selection", async () => {
  await publish(minimalDraft);
  await publish(fullyVersionedDraft(minimalDraft, 2));
  await firestore.doc("modules/synthetic-module--en-us--v1").update({
    programID: "synthetic-corrupt-owner",
  });
  await assertRejectedWithoutMutation(
    () => rollback("catalog--en-us--v1"),
    /graph|digest|program|corrupt|shape/i,
  );
  assert.equal(
    (await firestore.doc(`catalogs/${CATALOG_POINTER_ID}`).get()).data()
      .publishedCatalogVersionID,
    "catalog--en-us--v2",
  );
});

test("exceptions injected at every publish transaction phase leave the prior graph byte-for-byte unchanged", async () => {
  const versionTwo = fullyVersionedDraft(minimalDraft, 2);
  for (const phaseToFail of PUBLISH_PHASES) {
    await clearEmulator();
    await publish(minimalDraft);
    const beforeState = await snapshotPublicationState();
    await assert.rejects(
      () =>
        publish(versionTwo, {
          faultInjector: async (phase) => {
            if (phase === phaseToFail) {
              throw new Error(`synthetic publish failure at ${phase}`);
            }
          },
        }),
      new RegExp(`synthetic publish failure at ${phaseToFail}`),
    );
    assert.deepEqual(
      await snapshotPublicationState(),
      beforeState,
      `Publish phase ${phaseToFail} leaked a partial write.`,
    );
  }
});

test("exceptions injected at every rollback transaction phase leave the live selection byte-for-byte unchanged", async () => {
  const versionTwo = fullyVersionedDraft(minimalDraft, 2);
  for (const phaseToFail of ROLLBACK_PHASES) {
    await clearEmulator();
    await publish(minimalDraft);
    await publish(versionTwo);
    const beforeState = await snapshotPublicationState();
    await assert.rejects(
      () =>
        rollback("catalog--en-us--v1", {
          faultInjector: async (phase) => {
            if (phase === phaseToFail) {
              throw new Error(`synthetic rollback failure at ${phase}`);
            }
          },
        }),
      new RegExp(`synthetic rollback failure at ${phaseToFail}`),
    );
    assert.deepEqual(
      await snapshotPublicationState(),
      beforeState,
      `Rollback phase ${phaseToFail} leaked a partial write.`,
    );
  }
});

test("transaction-budget rejection occurs before any Firestore write", async () => {
  const oversized = overBudgetDraft(minimalDraft);
  const validation = validateCurriculumDraft(oversized, {
    sourcePath: FIXTURE_PATH,
  });
  assert.equal(validation.ok, false);
  assert.ok(
    validation.issues.some(
      (issue) => issue.code === "TRANSACTION_BUDGET_EXCEEDED",
    ),
    JSON.stringify(validation.issues),
  );
  await assertRejectedWithoutMutation(
    () => publish(oversized),
    /budget|transaction|validation/i,
  );
  assert.deepEqual(await snapshotPublicationState(), {});
});

test("live authorization rejects a production identity disguised as staging", () => {
  const environmentEntry = {
    environment: "staging",
    projectID: "syntholo-staging",
    projectNumber: "123456789012",
    publicationMode: "staging",
    credentialPrincipals: [
      "curriculum-publisher@syntholo-staging.iam.gserviceaccount.com",
    ],
  };
  assert.throws(
    () =>
      authorizeResolvedLiveIdentity({
        environmentEntry,
        requestedProjectID: environmentEntry.projectID,
        derivedIdentity: {
          credentialType: LIVE_CREDENTIAL_TYPE,
          projectID: "syntholo-production",
          projectNumber: "999999999999",
          credentialPrincipal: environmentEntry.credentialPrincipals[0],
        },
      }),
    (error) => error.code === "ACTUAL_PROJECT_MISMATCH",
  );
});

test("live authorization rejects an unknown actual project number", () => {
  const environmentEntry = {
    environment: "staging",
    projectID: "syntholo-staging",
    projectNumber: "123456789012",
    publicationMode: "staging",
    credentialPrincipals: [
      "curriculum-publisher@syntholo-staging.iam.gserviceaccount.com",
    ],
  };
  assert.throws(
    () =>
      authorizeResolvedLiveIdentity({
        environmentEntry,
        requestedProjectID: environmentEntry.projectID,
        derivedIdentity: {
          credentialType: LIVE_CREDENTIAL_TYPE,
          projectID: environmentEntry.projectID,
          projectNumber: "999999999999",
          credentialPrincipal: environmentEntry.credentialPrincipals[0],
        },
      }),
    (error) => error.code === "ACTUAL_PROJECT_NUMBER_MISMATCH",
  );
});

test("live authorization rejects an unapproved derived principal", () => {
  const environmentEntry = {
    environment: "staging",
    projectID: "syntholo-staging",
    projectNumber: "123456789012",
    publicationMode: "staging",
    credentialPrincipals: [
      "curriculum-publisher@syntholo-staging.iam.gserviceaccount.com",
    ],
  };
  assert.throws(
    () =>
      authorizeResolvedLiveIdentity({
        environmentEntry,
        requestedProjectID: environmentEntry.projectID,
        derivedIdentity: {
          credentialType: LIVE_CREDENTIAL_TYPE,
          projectID: environmentEntry.projectID,
          projectNumber: environmentEntry.projectNumber,
          credentialPrincipal:
            "unapproved-publisher@syntholo-staging.iam.gserviceaccount.com",
        },
      }),
    (error) => error.code === "CREDENTIAL_PRINCIPAL_NOT_ALLOWLISTED",
  );
});

test("non-emulator authorization requires a tracked launch decision before live identity resolution", async () => {
  let resolverCalled = false;
  await assert.rejects(
    () =>
      resolveOperatorIdentity({
        environment: "staging",
        projectID: "syntholo-staging",
        confirmProject: "syntholo-staging",
        firestoreEmulatorHost: "",
        environmentsConfig: {
          schemaVersion: 1,
          environments: [
            {
              environment: "staging",
              projectID: "syntholo-staging",
              projectNumber: "123456789012",
              publicationMode: "staging",
              credentialPrincipals: [
                "curriculum-publisher@syntholo-staging.iam.gserviceaccount.com",
              ],
            },
          ],
        },
        decisionPath: path.join(temporaryDirectory, "missing-decision.json"),
        liveIdentityResolver: async () => {
          resolverCalled = true;
          throw new Error("must not run without a decision record");
        },
      }),
    (error) => error.code === "DECISION_RECORD_REQUIRED",
  );
  assert.equal(resolverCalled, false);
  assert.deepEqual(await snapshotPublicationState(), {});
});

test("synthetic source is rejected for every non-emulator publication context", async () => {
  const stagingContext = {
    ...OPERATOR_CONTEXT,
    environment: "staging",
    projectID: "syntholo-staging",
    projectNumber: "123456789012",
    credentialPrincipal:
      "curriculum-publisher@syntholo-staging.iam.gserviceaccount.com",
    publicationMode: "staging",
  };
  await assertRejectedWithoutMutation(
    () => publish(minimalDraft, { operatorContext: stagingContext }),
    /synthetic|emulator|forbidden/i,
  );
});

test("synthetic source requires a non-empty emulator host before transaction evaluation", async () => {
  const originalHost = process.env.FIRESTORE_EMULATOR_HOST;
  delete process.env.FIRESTORE_EMULATOR_HOST;
  try {
    await assertRejectedWithoutMutation(
      () => publish(minimalDraft),
      /synthetic|emulator|forbidden/i,
    );
  } finally {
    process.env.FIRESTORE_EMULATOR_HOST = originalHost;
  }

  for (const invalidHost of [
    "localhost:8080",
    "192.0.2.1:8080",
    "127.0.0.1:0",
    "127.0.0.1:65536",
  ]) {
    process.env.FIRESTORE_EMULATOR_HOST = invalidHost;
    try {
      await assertRejectedWithoutMutation(
        () => publish(minimalDraft),
        /emulator|host/i,
      );
    } finally {
      process.env.FIRESTORE_EMULATOR_HOST = originalHost;
    }
  }
});

test("source secret scanning runs before Firebase and ignores source-local suppression attempts", async () => {
  await writeFile(
    path.join(temporaryDirectory, ".gitleaks.toml"),
    '[allowlist]\npaths = [".*"]\n',
    "utf8",
  );
  await writeFile(
    path.join(temporaryDirectory, ".gitleaksignore"),
    "allow-everything\n",
    "utf8",
  );
  const sourcePath = await writeScannerRecognizedSecretDraft();

  const result = runNodeCLI(
    "tools/content/publish.mjs",
    publishCLIArguments({ source: sourcePath, mode: "--apply" }),
    {
      FIRESTORE_EMULATOR_HOST: "127.0.0.1:1",
      NODE_OPTIONS: firebaseAdminImportGuardNodeOptions(),
    },
  );
  assert.notEqual(result.status, 0);
  assertSafeCommandOutput(result);
  assert.match(`${result.stdout}\n${result.stderr}`, /secret|gitleaks|scan/i);
  assert.doesNotMatch(
    `${result.stdout}\n${result.stderr}`,
    /ECONNREFUSED|Firestore|14 UNAVAILABLE|FIREBASE_ADMIN_IMPORTED_BEFORE_SOURCE_SCAN/i,
  );
  assert.deepEqual(await snapshotPublicationState(), {});

  const raceSourcePath = await writeDraft("source-race.json", minimalDraft);
  const replacement = cloneDraft(minimalDraft);
  replacement.programVersions[0].promise =
    "Safe replacement written only after the authoritative source read.";
  let hookArgumentCount = null;
  const sealed = await loadScannedCurriculumSource(raceSourcePath, {
    afterSourceRead: async (...hookArguments) => {
      hookArgumentCount = hookArguments.length;
      await writeFile(
        raceSourcePath,
        `${JSON.stringify(replacement, null, 2)}\n`,
        "utf8",
      );
    },
  });
  assert.equal(hookArgumentCount, 0);
  assert.equal(
    sealed.draft.programVersions[0].promise,
    minimalDraft.programVersions[0].promise,
  );
  const currentSource = JSON.parse(await readFile(raceSourcePath, "utf8"));
  assert.equal(
    currentSource.programVersions[0].promise,
    replacement.programVersions[0].promise,
  );
});
