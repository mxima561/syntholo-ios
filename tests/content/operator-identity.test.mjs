import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  EMULATOR_OPERATOR_IDENTITY,
  LIVE_CREDENTIAL_TYPE,
  OPERATOR_ENVIRONMENTS_PATH,
  PRODUCT_BIBLE_PATH,
  OperatorIdentityError,
  assertEnvironmentConfiguration,
  assertLaunchContentDecisionMatchesBible,
  authorizeResolvedLiveIdentity,
  isTrackedRepositoryFile,
  loadEnvironmentConfiguration,
  resolveOperatorIdentity,
  validateEnvironmentConfiguration,
  validateLaunchContentDecision,
} from "../../tools/content/lib/operator-identity.mjs";

const emulatorConfiguration = JSON.parse(
  await readFile(OPERATOR_ENVIRONMENTS_PATH, "utf8"),
);

const stagingEntry = Object.freeze({
  environment: "staging",
  projectID: "synthetic-stage-fixture",
  projectNumber: "123456789012",
  publicationMode: "staging",
  credentialPrincipals: [
    "synthetic-publisher@synthetic-stage-fixture.iam.gserviceaccount.com",
  ],
});
const liveConfiguration = {
  schemaVersion: 1,
  environments: [emulatorConfiguration.environments[0], stagingEntry],
};
const decisionRecord = Object.freeze({
  schemaVersion: 1,
  specialization: "school",
  productBibleDecision: {
    documentPath:
      "docs/superpowers/specs/2026-08-25-syntholo-product-bible.md",
    decisionID: "DEC-23",
    decisionDate: "2026-08-30",
  },
});
const decidedBible = `
## Binding decisions

| ID | Decision | Value |
| --- | --- | --- |
| DEC-23 | Launch specialization approved 2026-08-30 | **School** |
`;

function clone(value) {
  return structuredClone(value);
}

function codes(result) {
  return result.issues.map((entry) => entry.code);
}

async function assertRejectsCode(operation, code, expectedPath) {
  await assert.rejects(
    Promise.resolve().then(operation),
    (error) => {
      assert.ok(error instanceof OperatorIdentityError);
      assert.equal(error.code, code);
      if (expectedPath !== undefined) assert.equal(error.path, expectedPath);
      assert.deepEqual(Object.keys(error.toJSON()), ["code", "path", "issues"]);
      return true;
    },
  );
}

function validEmulatorRequest(overrides = {}) {
  return {
    environment: "emulator",
    projectID: "syntholo-local",
    confirmProject: "syntholo-local",
    firestoreEmulatorHost: "127.0.0.1:8080",
    environmentsConfig: emulatorConfiguration,
    ...overrides,
  };
}

function validLiveRequest(overrides = {}) {
  return {
    environment: "staging",
    projectID: stagingEntry.projectID,
    confirmProject: stagingEntry.projectID,
    environmentsConfig: liveConfiguration,
    decisionRecord,
    productBibleText: decidedBible,
    liveIdentityResolver: async () => ({
      credentialType: LIVE_CREDENTIAL_TYPE,
      projectID: stagingEntry.projectID,
      projectNumber: stagingEntry.projectNumber,
      credentialPrincipal: stagingEntry.credentialPrincipals[0],
    }),
    ...overrides,
  };
}

test("the checked-in environment configuration contains only the exact emulator identity", async () => {
  assert.deepEqual(emulatorConfiguration, {
    schemaVersion: 1,
    environments: [
      {
        environment: "emulator",
        projectID: "syntholo-local",
        projectNumber: "emulator",
        publicationMode: "emulator",
        credentialPrincipals: ["emulator-local"],
      },
    ],
  });
  const loaded = await loadEnvironmentConfiguration();
  assert.ok(Object.isFrozen(loaded));
  assert.ok(Object.isFrozen(loaded.environments));
  assert.ok(Object.isFrozen(loaded.environments[0]));
});

test("environment configuration is closed at root and entry boundaries", () => {
  const root = clone(emulatorConfiguration);
  root.credentialPrincipal = "caller-value";
  assert.ok(codes(validateEnvironmentConfiguration(root)).includes("UNKNOWN_PROPERTY"));

  const entry = clone(emulatorConfiguration);
  entry.environments[0].credentialPrincipal = "caller-value";
  assert.ok(codes(validateEnvironmentConfiguration(entry)).includes("UNKNOWN_PROPERTY"));
});

test("environment configuration enforces schema version and entry count", () => {
  const badVersion = clone(emulatorConfiguration);
  badVersion.schemaVersion = 2;
  assert.ok(
    codes(validateEnvironmentConfiguration(badVersion)).includes(
      "ENVIRONMENT_CONFIG_SCHEMA_VERSION_INVALID",
    ),
  );
  assert.ok(
    codes(validateEnvironmentConfiguration({ schemaVersion: 1, environments: [] })).includes(
      "ENVIRONMENT_ENTRY_COUNT_INVALID",
    ),
  );
});

test("the emulator identity cannot be relabeled or changed", () => {
  for (const mutate of [
    (entry) => void (entry.projectID = "different-local"),
    (entry) => void (entry.projectNumber = "123456"),
    (entry) => void (entry.publicationMode = "staging"),
    (entry) => void (entry.credentialPrincipals = ["other-local"]),
  ]) {
    const candidate = clone(emulatorConfiguration);
    mutate(candidate.environments[0]);
    assert.ok(
      codes(validateEnvironmentConfiguration(candidate)).includes(
        "EMULATOR_ENTRY_INVALID",
      ),
    );
  }
});

test("live entries require exact project and service-account shapes", () => {
  assert.equal(validateEnvironmentConfiguration(liveConfiguration).ok, true);
  const malformed = clone(liveConfiguration);
  malformed.environments[1].projectNumber = "unknown";
  malformed.environments[1].credentialPrincipals = [
    "not an email@synthetic-stage-fixture.iam.gserviceaccount.com",
  ];
  const result = validateEnvironmentConfiguration(malformed);
  assert.ok(codes(result).includes("LIVE_PROJECT_NUMBER_INVALID"));
  assert.ok(codes(result).includes("LIVE_CREDENTIAL_PRINCIPAL_INVALID"));
});

test("environment, project, project-number, and principal identities are unique", () => {
  for (const [property, expectedCode] of [
    ["environment", "DUPLICATE_ENVIRONMENT"],
    ["projectID", "DUPLICATE_PROJECT_ID"],
    ["projectNumber", "DUPLICATE_PROJECT_NUMBER"],
  ]) {
    const candidate = clone(liveConfiguration);
    candidate.environments[1][property] = candidate.environments[0][property];
    assert.ok(codes(validateEnvironmentConfiguration(candidate)).includes(expectedCode));
  }

  const duplicatePrincipal = clone(liveConfiguration);
  duplicatePrincipal.environments[1].credentialPrincipals.push(
    duplicatePrincipal.environments[1].credentialPrincipals[0],
  );
  assert.ok(
    codes(validateEnvironmentConfiguration(duplicatePrincipal)).includes(
      "DUPLICATE_CREDENTIAL_PRINCIPAL",
    ),
  );
});

test("development is not a publication environment", () => {
  const candidate = clone(emulatorConfiguration);
  candidate.environments[0].environment = "development";
  candidate.environments[0].publicationMode = "development";
  assert.ok(codes(validateEnvironmentConfiguration(candidate)).includes("ENVIRONMENT_INVALID"));
});

test("resolver rejects development and unknown environment labels", async () => {
  for (const environment of ["development", "qa"]) {
    await assertRejectsCode(
      () =>
        resolveOperatorIdentity({
          environment,
          projectID: "syntholo-local",
          confirmProject: "syntholo-local",
          firestoreEmulatorHost: "127.0.0.1:8080",
          environmentsConfig: emulatorConfiguration,
        }),
      "ENVIRONMENT_INVALID",
      "/environment",
    );
  }
});

test("asserted configuration is a detached deeply frozen value", () => {
  const source = clone(liveConfiguration);
  const asserted = assertEnvironmentConfiguration(source);
  source.environments[1].projectID = "mutated-project";
  assert.equal(asserted.environments[1].projectID, stagingEntry.projectID);
  assert.ok(Object.isFrozen(asserted.environments[1].credentialPrincipals));
});

test("the launch decision schema is exact and enumerated", () => {
  assert.equal(validateLaunchContentDecision(decisionRecord).ok, true);
  for (const mutate of [
    (record) => void (record.specialization = "foundations"),
    (record) => void (record.schemaVersion = 2),
    (record) => void (record.productBibleDecision.decisionID = "CHOICE-23"),
    (record) => void (record.productBibleDecision.decisionDate = "08/30/2026"),
    (record) => void (record.productBibleDecision.documentPath = "another.md"),
    (record) => void (record.unexpected = true),
    (record) => void (record.productBibleDecision.unexpected = true),
  ]) {
    const candidate = clone(decisionRecord);
    mutate(candidate);
    const result = validateLaunchContentDecision(candidate);
    assert.equal(result.ok, false);
    assert.ok(codes(result).every((code) => code === "DECISION_SCHEMA_INVALID"));
  }
});

test("a derivative decision must match one dated, single-choice Product Bible row", () => {
  const matched = assertLaunchContentDecisionMatchesBible(
    decisionRecord,
    decidedBible,
  );
  assert.equal(matched.specialization, "school");
  assert.ok(Object.isFrozen(matched));
});

test("an unresolved or contradictory Product Bible decision fails closed", () => {
  for (const bible of [
    `${decidedBible}\n${"Which specialization is the first fully-built path (School / Work / Creation / Build)"}`,
    decidedBible.replace("2026-08-30", "2026-08-29"),
    decidedBible.replace("School", "Work"),
    decidedBible.replace("School", "School / Work"),
    decidedBible.replace("DEC-23", "DEC-24"),
  ]) {
    assert.throws(
      () => assertLaunchContentDecisionMatchesBible(decisionRecord, bible),
      (error) =>
        error instanceof OperatorIdentityError &&
        error.code === "DECISION_BIBLE_MISMATCH",
    );
  }
});

test("emulator resolution derives the exact fixed identity without consulting live ADC", async () => {
  let liveResolverCalled = false;
  const context = await resolveOperatorIdentity(
    validEmulatorRequest({
      requestedBy: "local-contract-test",
      liveIdentityResolver: async () => {
        liveResolverCalled = true;
        throw new Error("must not run");
      },
    }),
  );
  assert.deepEqual(context, {
    ...EMULATOR_OPERATOR_IDENTITY,
    requestedBy: "local-contract-test",
  });
  assert.equal(liveResolverCalled, false);
  assert.ok(Object.isFrozen(context));
});

test("emulator resolution requires a nonblank emulator host", async () => {
  for (const firestoreEmulatorHost of [undefined, "", "  "]) {
    await assertRejectsCode(
      () =>
        resolveOperatorIdentity(
          validEmulatorRequest({ firestoreEmulatorHost }),
        ),
      "EMULATOR_HOST_REQUIRED",
      "/firestoreEmulatorHost",
    );
  }

  for (const firestoreEmulatorHost of [
    "localhost:8080",
    "0.0.0.0:8080",
    "192.0.2.1:8080",
    "127.0.0.1:0",
    "127.0.0.1:65536",
    "127.0.0.1:08080",
    "http://127.0.0.1:8080",
  ]) {
    await assertRejectsCode(
      () =>
        resolveOperatorIdentity(
          validEmulatorRequest({ firestoreEmulatorHost }),
        ),
      "EMULATOR_HOST_INVALID",
      "/firestoreEmulatorHost",
    );
  }
});

test("explicit project confirmation is required and exact", async () => {
  await assertRejectsCode(
    () =>
      resolveOperatorIdentity(
        validEmulatorRequest({ confirmProject: undefined }),
      ),
    "PROJECT_CONFIRMATION_REQUIRED",
    "/confirmProject",
  );
  await assertRejectsCode(
    () =>
      resolveOperatorIdentity(
        validEmulatorRequest({ confirmProject: "another-project" }),
      ),
    "PROJECT_CONFIRMATION_MISMATCH",
    "/confirmProject",
  );
});

test("requested environment and project must match the allowlist entry", async () => {
  await assertRejectsCode(
    () =>
      resolveOperatorIdentity(
        validEmulatorRequest({
          projectID: "another-project",
          confirmProject: "another-project",
        }),
      ),
    "ENVIRONMENT_PROJECT_MISMATCH",
    "/projectID",
  );
});

test("a caller-supplied credential principal is rejected before resolution", async () => {
  await assertRejectsCode(
    () =>
      resolveOperatorIdentity({
        ...validEmulatorRequest(),
        credentialPrincipal: "emulator-local",
      }),
    "CALLER_SUPPLIED_PRINCIPAL_FORBIDDEN",
    "/credentialPrincipal",
  );
});

test("unknown resolver options and unsafe requested-by values are rejected safely", async () => {
  await assertRejectsCode(
    () => resolveOperatorIdentity({ ...validEmulatorRequest(), secret: "value" }),
    "OPERATOR_OPTIONS_INVALID",
    "/<unknown-property>",
  );
  await assertRejectsCode(
    () => resolveOperatorIdentity(validEmulatorRequest({ requestedBy: "" })),
    "REQUESTED_BY_INVALID",
    "/requestedBy",
  );
  const scalarBoundary = "😀".repeat(320);
  const resolved = await resolveOperatorIdentity(
    validEmulatorRequest({ requestedBy: scalarBoundary }),
  );
  assert.equal(resolved.requestedBy, scalarBoundary);
  await assertRejectsCode(
    () =>
      resolveOperatorIdentity(
        validEmulatorRequest({ requestedBy: `${scalarBoundary}😀` }),
      ),
    "REQUESTED_BY_INVALID",
    "/requestedBy",
  );
});

test("production publication is disabled even with explicit confirmation", async () => {
  await assertRejectsCode(
    () =>
      resolveOperatorIdentity({
        environment: "production",
        projectID: "synthetic-production-fixture",
        confirmProject: "synthetic-production-fixture",
        environmentsConfig: emulatorConfiguration,
      }),
    "PRODUCTION_PUBLICATION_DISABLED",
    "/environment",
  );
});

test("a non-emulator request requires the derivative decision before live identity", async () => {
  let resolverCalled = false;
  await assertRejectsCode(
    () =>
      resolveOperatorIdentity({
        environment: "staging",
        projectID: stagingEntry.projectID,
        confirmProject: stagingEntry.projectID,
        environmentsConfig: liveConfiguration,
        decisionPath: path.join(os.tmpdir(), "missing-launch-content-decision.json"),
        liveIdentityResolver: async () => {
          resolverCalled = true;
        },
      }),
    "DECISION_RECORD_REQUIRED",
  );
  assert.equal(resolverCalled, false);
});

test("an untracked non-emulator decision record is rejected", async () => {
  const temporaryDirectory = await mkdtemp(
    path.join(os.tmpdir(), "syntholo-untracked-decision-"),
  );
  try {
    const decisionPath = path.join(
      temporaryDirectory,
      "launch-content-decision.json",
    );
    await writeFile(decisionPath, JSON.stringify(decisionRecord));
    await assertRejectsCode(
      () =>
        resolveOperatorIdentity({
          environment: "staging",
          projectID: stagingEntry.projectID,
          confirmProject: stagingEntry.projectID,
          environmentsConfig: liveConfiguration,
          decisionPath,
          productBibleText: decidedBible,
          liveIdentityResolver: async () => {
            throw new Error("must not run");
          },
        }),
      "DECISION_RECORD_NOT_TRACKED",
      "/productBibleDecision/documentPath",
    );
  } finally {
    await rm(temporaryDirectory, { recursive: true, force: true });
  }
});

test("a live environment refuses an emulator host", async () => {
  await assertRejectsCode(
    () =>
      resolveOperatorIdentity(
        validLiveRequest({ firestoreEmulatorHost: "127.0.0.1:8080" }),
      ),
    "EMULATOR_HOST_FOR_LIVE_ENVIRONMENT",
    "/firestoreEmulatorHost",
  );
});

test("staging resolution accepts only derived impersonated allowlisted identity", async () => {
  const context = await resolveOperatorIdentity(
    validLiveRequest({ requestedBy: "release-operator" }),
  );
  assert.deepEqual(context, {
    environment: "staging",
    projectID: stagingEntry.projectID,
    projectNumber: stagingEntry.projectNumber,
    credentialPrincipal: stagingEntry.credentialPrincipals[0],
    requestedBy: "release-operator",
    publicationMode: "staging",
  });
  assert.ok(Object.isFrozen(context));
});

test("direct user ADC and service-account key identities are rejected", async () => {
  for (const credentialType of ["user-adc", "service-account-key", "refresh-token"]) {
    await assertRejectsCode(
      () =>
        resolveOperatorIdentity(
          validLiveRequest({
            liveIdentityResolver: async () => ({
              credentialType,
              projectID: stagingEntry.projectID,
              projectNumber: stagingEntry.projectNumber,
              credentialPrincipal: stagingEntry.credentialPrincipals[0],
            }),
          }),
        ),
      "LIVE_CREDENTIAL_TYPE_INVALID",
      "/derivedIdentity/credentialType",
    );
  }
});

test("a production project disguised as staging is rejected from authenticated metadata", async () => {
  await assertRejectsCode(
    () =>
      resolveOperatorIdentity(
        validLiveRequest({
          liveIdentityResolver: async () => ({
            credentialType: LIVE_CREDENTIAL_TYPE,
            projectID: "synthetic-production-fixture",
            projectNumber: stagingEntry.projectNumber,
            credentialPrincipal: stagingEntry.credentialPrincipals[0],
          }),
        }),
      ),
    "ACTUAL_PROJECT_MISMATCH",
    "/derivedIdentity/projectID",
  );
});

test("an unknown authenticated project number is rejected", async () => {
  await assertRejectsCode(
    () =>
      resolveOperatorIdentity(
        validLiveRequest({
          liveIdentityResolver: async () => ({
            credentialType: LIVE_CREDENTIAL_TYPE,
            projectID: stagingEntry.projectID,
            projectNumber: "999999999999",
            credentialPrincipal: stagingEntry.credentialPrincipals[0],
          }),
        }),
      ),
    "ACTUAL_PROJECT_NUMBER_MISMATCH",
    "/derivedIdentity/projectNumber",
  );
});

test("an unapproved impersonated service account is rejected", async () => {
  await assertRejectsCode(
    () =>
      resolveOperatorIdentity(
        validLiveRequest({
          liveIdentityResolver: async () => ({
            credentialType: LIVE_CREDENTIAL_TYPE,
            projectID: stagingEntry.projectID,
            projectNumber: stagingEntry.projectNumber,
            credentialPrincipal:
              "unapproved-publisher@synthetic-stage-fixture.iam.gserviceaccount.com",
          }),
        }),
      ),
    "CREDENTIAL_PRINCIPAL_NOT_ALLOWLISTED",
    "/derivedIdentity/credentialPrincipal",
  );
});

test("derived live identity has a closed exact shape", async () => {
  await assertRejectsCode(
    () =>
      resolveOperatorIdentity(
        validLiveRequest({
          liveIdentityResolver: async () => ({
            credentialType: LIVE_CREDENTIAL_TYPE,
            projectID: stagingEntry.projectID,
            projectNumber: stagingEntry.projectNumber,
            credentialPrincipal: stagingEntry.credentialPrincipals[0],
            callerSupplied: true,
          }),
        }),
      ),
    "LIVE_IDENTITY_SHAPE_INVALID",
    "/derivedIdentity",
  );
});

test("live resolver failures are redacted into a safe fixed error", async () => {
  await assertRejectsCode(
    () =>
      resolveOperatorIdentity(
        validLiveRequest({
          liveIdentityResolver: async () => {
            throw new Error("private credential metadata");
          },
        }),
      ),
    "LIVE_IDENTITY_RESOLUTION_FAILED",
    "/liveIdentityResolver",
  );
});

test("pure live authorization rejects a malformed environment without throwing raw errors", () => {
  assert.throws(
    () =>
      authorizeResolvedLiveIdentity({
        environmentEntry: { environment: "staging" },
        requestedProjectID: stagingEntry.projectID,
        derivedIdentity: {},
      }),
    (error) => error instanceof OperatorIdentityError,
  );
});

test("strict config loading rejects duplicate keys and invalid UTF-8", async () => {
  const temporaryDirectory = await mkdtemp(
    path.join(os.tmpdir(), "syntholo-operator-identity-"),
  );
  try {
    const duplicatePath = path.join(temporaryDirectory, "duplicate.json");
    await writeFile(
      duplicatePath,
      '{"schemaVersion":1,"schemaVersion":1,"environments":[]}',
    );
    await assertRejectsCode(
      () => loadEnvironmentConfiguration(duplicatePath),
      "DUPLICATE_OBJECT_KEY",
    );

    const invalidUTF8Path = path.join(temporaryDirectory, "invalid-utf8.json");
    await writeFile(invalidUTF8Path, Buffer.from([0xff, 0xfe, 0xfd]));
    await assertRejectsCode(
      () => loadEnvironmentConfiguration(invalidUTF8Path),
      "JSON_PARSE_INVALID",
    );
  } finally {
    await rm(temporaryDirectory, { recursive: true, force: true });
  }
});

test("tracked-file proof rejects paths outside the repository", () => {
  assert.equal(isTrackedRepositoryFile(PRODUCT_BIBLE_PATH), true);
  assert.equal(isTrackedRepositoryFile(path.join(os.tmpdir(), "outside.json")), false);
});
