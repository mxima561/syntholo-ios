import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { after, before, beforeEach, test } from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  documentId,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
} from "firebase/firestore";

import { loadMinimalDraft } from "../helpers/curriculum-publication-fixtures.mjs";
import { buildPublicationShape } from "../../tools/content/lib/firestore-shape.mjs";

const PROJECT_ID = "syntholo-local";
const RULES_PATH = "firestore.rules";
const DENY_ALL_RULES = `
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
`;

const emulatorAddress = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8088";
const [host, portText] = emulatorAddress.split(":");
const rules = existsSync(RULES_PATH)
  ? readFileSync(RULES_PATH, "utf8")
  : DENY_ALL_RULES;
const TEST_TIMESTAMP = Timestamp.fromMillis(1_777_500_000_000);
const LEARNER_CURRICULUM_COLLECTIONS = new Set([
  "featureConfiguration",
  "catalogs",
  "catalogVersions",
  "programs",
  "programVersions",
  "modules",
  "lessonVersions",
  "rubricVersions",
  "assetVersions",
]);
const IMMUTABLE_LEARNER_COLLECTIONS = new Set([
  "catalogVersions",
  "programVersions",
  "modules",
  "lessonVersions",
  "rubricVersions",
  "assetVersions",
]);
const publicationFixture = buildPublicationShape(await loadMinimalDraft());
const LEARNER_CURRICULUM_DOCUMENTS = [
  publicationFixture.derivedConfiguration,
  publicationFixture.derivedPointers.catalog,
  ...publicationFixture.derivedPointers.programs,
  ...publicationFixture.immutableDocuments.filter(({ path }) =>
    LEARNER_CURRICULUM_COLLECTIONS.has(collectionForPath(path)),
  ),
].map(storedPublicationDocument);
const LEARNER_CURRICULUM_BY_COLLECTION = new Map(
  LEARNER_CURRICULUM_DOCUMENTS.map((entry) => [collectionForPath(entry.path), entry]),
);
const PRIVATE_CURRICULUM_DOCUMENTS = [
  ...publicationFixture.immutableDocuments
    .filter(({ path }) => collectionForPath(path) === "evaluationContractVersions")
    .map(storedPublicationDocument),
  {
    path: "contentVersionHeads/lesson--synthetic-lesson--en-us",
    data: {
      versionHeadID: "lesson--synthetic-lesson--en-us",
      kind: "lesson",
      stableID: "synthetic-lesson",
      locale: "en-US",
      maxPublishedVersion: 1,
      schemaVersion: 1,
      updatedAt: TEST_TIMESTAMP,
    },
  },
  {
    path: "contentPublicationAudit/00000000-0000-4000-8000-000000000001",
    data: {
      schemaVersion: 1,
      operationID: "00000000-0000-4000-8000-000000000001",
      action: "publish",
      outcome: "applied",
      occurredAt: TEST_TIMESTAMP,
    },
  },
];
const AUTHORING_DOCUMENT = {
  path: "contentDrafts/synthetic-authoring-record",
  data: { publicationState: "draft", schemaVersion: 1 },
};
const ALLOWED_MISSING_CURRICULUM_PATHS = [
  "featureConfiguration/curriculum",
  "catalogs/en-us",
  "catalogVersions/catalog--en-us--v999",
  "programs/ai-foundations--en-us",
  `programs/${"a".repeat(64)}--en-us`,
  "programVersions/ai-foundations--en-us--v999",
  `programVersions/${"a".repeat(64)}--en-us--v2147483647`,
  "modules/synthetic-module--en-us--v999",
  "lessonVersions/synthetic-lesson--en-us--v999",
  "rubricVersions/synthetic-rubric--en-us--v999",
  "assetVersions/synthetic-diagram--en-us--v999",
];
const INVALID_MISSING_CURRICULUM_PATHS = [
  "featureConfiguration/not-curriculum",
  "catalogs/fr-fr",
  "catalogVersions/not-a-version",
  "catalogVersions/catalog--en-us--v12345678901",
  "programs/not-a-pointer",
  `programs/${"a".repeat(65)}--en-us`,
  "programVersions/not-a-version",
  "programVersions/ai-foundations--en-us--v12345678901",
  `programVersions/${"a".repeat(65)}--en-us--v1`,
  "modules/not-a-version",
  "lessonVersions/not-a-version",
  "rubricVersions/not-a-version",
  "assetVersions/not-a-version",
];

let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host,
      port: Number(portText),
      rules,
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

test("authenticated exact gets read every valid learner curriculum document", async () => {
  await seedRulesDocuments(LEARNER_CURRICULUM_DOCUMENTS);
  const database = authenticatedDatabase("curriculum-reader");

  for (const entry of LEARNER_CURRICULUM_DOCUMENTS) {
    const snapshot = await assertSucceeds(getDoc(doc(database, entry.path)));
    assert.equal(snapshot.exists(), true, entry.path);
  }
});

test("authenticated exact gets distinguish allowed missing curriculum paths", async () => {
  const database = authenticatedDatabase("curriculum-reader");

  for (const path of ALLOWED_MISSING_CURRICULUM_PATHS) {
    const snapshot = await assertSucceeds(getDoc(doc(database, path)));
    assert.equal(snapshot.exists(), false, path);
  }
  for (const path of INVALID_MISSING_CURRICULUM_PATHS) {
    await assertFails(getDoc(doc(database, path)));
  }
});

test("unauthenticated exact gets fail for every learner curriculum document", async () => {
  await seedRulesDocuments(LEARNER_CURRICULUM_DOCUMENTS);
  const database = testEnvironment.unauthenticatedContext().firestore();

  for (const entry of LEARNER_CURRICULUM_DOCUMENTS) {
    await assertFails(getDoc(doc(database, entry.path)));
  }
});

test("curriculum collection and document-ID queries are always denied", async () => {
  await seedRulesDocuments(LEARNER_CURRICULUM_DOCUMENTS);
  const database = authenticatedDatabase("curriculum-reader");

  for (const entry of LEARNER_CURRICULUM_DOCUMENTS) {
    const collectionName = collectionForPath(entry.path);
    const documentID = documentIDForPath(entry.path);
    await assertFails(getDocs(collection(database, collectionName)));
    await assertFails(
      getDocs(
        query(
          collection(database, collectionName),
          where(documentId(), "==", documentID),
        ),
      ),
    );
  }
});

test("published state is required while nested validation remains outside Rules", async () => {
  const database = authenticatedDatabase("curriculum-reader");

  for (const entry of LEARNER_CURRICULUM_DOCUMENTS.filter(({ path }) =>
    IMMUTABLE_LEARNER_COLLECTIONS.has(collectionForPath(path)),
  )) {
    const data = cloneStoredData(entry.data);
    data.publicationState = "draft";
    await overwriteRulesDocument({ ...entry, data });
    await assertFails(getDoc(doc(database, entry.path)));
  }

  const shallowMutations = [
    ["catalogVersions", (data) => { data.programEntries = [{ malformed: true }]; }],
    ["lessonVersions", (data) => {
      data.completionRule = { malformed: true };
      data.blocks = [{ malformed: true }];
      data.contentDigest = "0".repeat(64);
    }],
    ["rubricVersions", (data) => {
      data.criteria = [{ malformed: true }];
      data.clientScoringContract = { malformed: true };
    }],
    ["assetVersions", (data) => {
      data.payload = { malformed: true };
      data.rights = { malformed: true };
    }],
  ];

  for (const [collectionName, mutate] of shallowMutations) {
    const entry = learnerEntry(collectionName);
    const data = cloneStoredData(entry.data);
    mutate(data);
    await overwriteRulesDocument({ ...entry, data });
    await assertSucceeds(getDoc(doc(database, entry.path)));
  }

  for (const collectionName of ["featureConfiguration", "catalogs"]) {
    const entry = learnerEntry(collectionName);
    const data = cloneStoredData(entry.data);
    data.minimumClientSchemaVersion = 2;
    await overwriteRulesDocument({ ...entry, data });
    await assertSucceeds(getDoc(doc(database, entry.path)));
  }

  const availableProgram = learnerEntry("programVersions");
  const comingSoonData = cloneStoredData(availableProgram.data);
  comingSoonData.programVersionID = "synthetic-shell--en-us--v1";
  comingSoonData.programID = "synthetic-shell";
  comingSoonData.catalogState = "comingSoon";
  comingSoonData.moduleVersionIDs = [];
  comingSoonData.firstLessonVersionID = null;
  comingSoonData.contentDigest = "0".repeat(64);
  const comingSoonEntry = {
    path: "programVersions/synthetic-shell--en-us--v1",
    data: comingSoonData,
  };
  await overwriteRulesDocument(comingSoonEntry);
  await assertSucceeds(getDoc(doc(database, comingSoonEntry.path)));
});

test("mismatched curriculum path and document identities are denied", async () => {
  const database = authenticatedDatabase("curriculum-reader");

  for (const entry of LEARNER_CURRICULUM_DOCUMENTS) {
    const mismatched = { ...entry, path: mismatchedPath(entry.path) };
    await overwriteRulesDocument(mismatched);
    await assertFails(getDoc(doc(database, mismatched.path)));
  }

  for (const [collectionName, identityField, invalidIdentity] of [
    ["catalogVersions", "catalogVersionID", "catalog--en-us--v12345678901"],
    [
      "programVersions",
      "programVersionID",
      "ai-foundations--en-us--v12345678901",
    ],
  ]) {
    const entry = learnerEntry(collectionName);
    const data = cloneStoredData(entry.data);
    data[identityField] = invalidIdentity;
    const invalidEntry = { path: `${collectionName}/${invalidIdentity}`, data };
    await overwriteRulesDocument(invalidEntry);
    await assertFails(getDoc(doc(database, invalidEntry.path)));
  }
});

test("unknown or missing top-level keys fail for every learner curriculum shape", async () => {
  const database = authenticatedDatabase("curriculum-reader");
  const requiredKeyByCollection = {
    featureConfiguration: "defaultLocale",
    catalogs: "locale",
    catalogVersions: "catalogVersionID",
    programs: "programPointerID",
    programVersions: "programVersionID",
    modules: "moduleVersionID",
    lessonVersions: "lessonVersionID",
    rubricVersions: "rubricVersionID",
    assetVersions: "assetVersionID",
  };

  for (const entry of LEARNER_CURRICULUM_DOCUMENTS) {
    const extraData = cloneStoredData(entry.data);
    extraData.unexpectedTopLevelField = true;
    await overwriteRulesDocument({ ...entry, data: extraData });
    await assertFails(getDoc(doc(database, entry.path)));

    const missingData = cloneStoredData(entry.data);
    delete missingData[requiredKeyByCollection[collectionForPath(entry.path)]];
    await overwriteRulesDocument({ ...entry, data: missingData });
    await assertFails(getDoc(doc(database, entry.path)));
  }
});

test("unsupported schemas and wrong top-level types fail for every curriculum shape", async () => {
  const database = authenticatedDatabase("curriculum-reader");
  const wrongTypeMutations = {
    featureConfiguration(data) { data.minimumClientSchemaVersion = "1"; },
    catalogs(data) { data.publishedCatalogVersionID = []; },
    catalogVersions(data) { data.programEntries = {}; },
    programs(data) { data.programID = 7; },
    programVersions(data) { data.moduleVersionIDs = {}; },
    modules(data) { data.lessonVersionIDs = {}; },
    lessonVersions(data) { data.blocks = {}; },
    rubricVersions(data) { data.criteria = {}; },
    assetVersions(data) { data.payload = []; },
  };

  for (const entry of LEARNER_CURRICULUM_DOCUMENTS) {
    const unsupported = cloneStoredData(entry.data);
    unsupported.schemaVersion = 2;
    await overwriteRulesDocument({ ...entry, data: unsupported });
    await assertFails(getDoc(doc(database, entry.path)));

    const wrongType = cloneStoredData(entry.data);
    wrongTypeMutations[collectionForPath(entry.path)](wrongType);
    await overwriteRulesDocument({ ...entry, data: wrongType });
    await assertFails(getDoc(doc(database, entry.path)));
  }
});

test("simple curriculum scalar and list bounds are enforced", async () => {
  const database = authenticatedDatabase("curriculum-reader");
  const cases = [
    ["featureConfiguration", (data) => { data.supportedLocales = Array(11).fill("en-US"); }],
    ["featureConfiguration", (data) => { data.minimumClientSchemaVersion = 0; }],
    ["catalogs", (data) => { data.minimumClientSchemaVersion = 0; }],
    ["catalogVersions", (data) => { data.programEntries = Array(6).fill({}); }],
    ["catalogVersions", (data) => { data.version = 2_147_483_648; }],
    ["catalogVersions", (data) => { data.contentDigest = "A".repeat(64); }],
    ["programs", (data) => { data.programID = "aa"; }],
    ["programVersions", (data) => { data.title = "T".repeat(121); }],
    ["programVersions", (data) => { data.promise = "P".repeat(501); }],
    ["programVersions", (data) => { data.moduleVersionIDs = Array(25).fill("module"); }],
    ["programVersions", (data) => { data.moduleVersionIDs = []; }],
    ["programVersions", (data) => {
      data.catalogState = "comingSoon";
      data.moduleVersionIDs = [];
    }],
    ["modules", (data) => { data.title = "T".repeat(121); }],
    ["modules", (data) => { data.summary = "S".repeat(501); }],
    ["modules", (data) => { data.lessonVersionIDs = Array(65).fill("lesson"); }],
    ["lessonVersions", (data) => { data.title = "T".repeat(121); }],
    ["lessonVersions", (data) => { data.objective = "O".repeat(501); }],
    ["lessonVersions", (data) => { data.expectedDurationMinutes = 181; }],
    ["lessonVersions", (data) => { data.prerequisiteLessonIDs = Array(17).fill("lesson"); }],
    ["lessonVersions", (data) => { data.blocks = Array(41).fill({}); }],
    ["lessonVersions", (data) => { data.assetVersionIDs = Array(129).fill("asset"); }],
    ["rubricVersions", (data) => { data.criteria = Array(13).fill({}); }],
    ["assetVersions", (data) => { data.byteCount = 131_073; }],
    ["assetVersions", (data) => { data.accessibilityDescription = "A".repeat(1001); }],
    ["assetVersions", (data) => { data.payloadDigest = "f".repeat(63); }],
  ];

  for (const [collectionName, mutate] of cases) {
    const entry = learnerEntry(collectionName);
    const data = cloneStoredData(entry.data);
    mutate(data);
    await overwriteRulesDocument({ ...entry, data });
    await assertFails(getDoc(doc(database, entry.path)));
  }
});

test("private curriculum authoring and unknown namespaces deny reads and lists", async () => {
  const deniedDocuments = [
    ...PRIVATE_CURRICULUM_DOCUMENTS,
    AUTHORING_DOCUMENT,
    { path: "unknownCurriculumSurface/record", data: { value: true } },
  ];
  await seedRulesDocuments(deniedDocuments);
  const database = authenticatedDatabase("curriculum-reader");

  for (const entry of deniedDocuments) {
    await assertFails(getDoc(doc(database, entry.path)));
    await assertFails(getDocs(collection(database, collectionForPath(entry.path))));
  }
});

test("clients cannot create update or delete curriculum or authoring records", async () => {
  const deniedDocuments = [
    ...LEARNER_CURRICULUM_DOCUMENTS,
    ...PRIVATE_CURRICULUM_DOCUMENTS,
    AUTHORING_DOCUMENT,
  ];
  const database = authenticatedDatabase("curriculum-writer");

  for (const entry of deniedDocuments) {
    await assertFails(setDoc(doc(database, entry.path), entry.data));
    await overwriteRulesDocument(entry);
    await assertFails(
      updateDoc(doc(database, entry.path), { schemaVersion: 1 }),
    );
    await assertFails(deleteDoc(doc(database, entry.path)));
  }
});

test("unauthenticated clients cannot access any profile surface", async () => {
  const database = testEnvironment.unauthenticatedContext().firestore();
  const handle = handleFor("teen-user");

  await assertFails(getDoc(doc(database, "users", "teen-user")));
  await assertFails(getDoc(doc(database, "preferences", "teen-user")));
  await assertFails(getDoc(doc(database, "publicProfiles", "teen-user")));
  await assertFails(getDoc(doc(database, "profileHandleClaims", handle)));
  await assertFails(getDoc(doc(database, "publicProfileDirectory", handle)));
  await assertFails(
    createProfileBatch(database, "teen-user", "13-17", "school"),
  );
});

test("an owner creates the authoritative five-document set in one batch", async () => {
  const database = authenticatedDatabase("teen-user");
  const handle = handleFor("teen-user");

  await assertSucceeds(
    createProfileBatch(database, "teen-user", "13-17", "school"),
  );
  await assertSucceeds(getDoc(doc(database, "users", "teen-user")));
  await assertSucceeds(getDoc(doc(database, "preferences", "teen-user")));
  await assertSucceeds(getDoc(doc(database, "publicProfiles", "teen-user")));
  await assertSucceeds(getDoc(doc(database, "profileHandleClaims", handle)));
  await assertSucceeds(getDoc(doc(database, "publicProfileDirectory", handle)));
});

test("absent private claims stay denied while absent exact directory gets succeed", async () => {
  const database = authenticatedDatabase("new-user");
  const handle = handleFor("new-user");

  await assertFails(getDoc(doc(database, "profileHandleClaims", handle)));
  const directory = await assertSucceeds(
    getDoc(doc(database, "publicProfileDirectory", handle)),
  );
  assert.equal(directory.exists(), false);
});

test("an authenticated exact directory get can detect hidden occupancy without UID", async () => {
  await seedProfile("teen-user", "13-17", "school");
  const handle = handleFor("teen-user");
  const searcher = authenticatedDatabase("searcher-user");

  const occupied = await assertSucceeds(
    getDoc(doc(searcher, "publicProfileDirectory", handle)),
  );
  assert.equal(occupied.exists(), true);
  assert.deepEqual(Object.keys(occupied.data()).sort(), [
    "handle",
    "isDiscoverable",
  ]);
  assert.equal(occupied.data().handle, handle);
  assert.equal(occupied.data().isDiscoverable, false);
  assert.equal("userID" in occupied.data(), false);
});

test("adapter-shaped public preflight permits the first complete profile save", async () => {
  const userID = "first-save-user";
  const database = authenticatedDatabase(userID);
  const handle = handleFor(userID);

  const user = await assertSucceeds(getDoc(doc(database, "users", userID)));
  const directory = await assertSucceeds(
    getDoc(doc(database, "publicProfileDirectory", handle)),
  );
  assert.equal(user.exists(), false);
  assert.equal(directory.exists(), false);
  await assertSucceeds(
    createProfileBatch(database, userID, "18+", "work"),
  );
});

test("initial creation rejects every incomplete subset of the authoritative set", async () => {
  const requiredDocuments = [
    "user",
    "preferences",
    "publicProfile",
    "claim",
    "directory",
  ];

  for (const [index, omitted] of requiredDocuments.entries()) {
    const userID = `incomplete-${index}`;
    await assertFails(
      createProfileBatch(databaseFor(userID), userID, "18+", "work", {
        omit: omitted,
      }),
    );
  }
});

test("private age is mandatory and valid in an otherwise-complete atomic batch", async () => {
  const missingID = "missing-age";
  const invalidID = "invalid-age";

  await assertFails(
    createProfileBatch(databaseFor(missingID), missingID, "13-17", "school", {
      omitAge: true,
    }),
  );
  await assertFails(
    createProfileBatch(databaseFor(invalidID), invalidID, "fabricated-adult", "school"),
  );
});

test("program validation fails for its intended field in complete atomic batches", async () => {
  const missingID = "missing-foundations";
  const mismatchID = "mismatched-program";

  await assertFails(
    createProfileBatch(databaseFor(missingID), missingID, "18+", "work", {
      preferencesOverrides: { enrolledProgramIDs: ["ai-work"] },
    }),
  );
  await assertFails(
    createProfileBatch(databaseFor(mismatchID), mismatchID, "18+", "work", {
      preferencesOverrides: {
        enrolledProgramIDs: ["ai-foundations", "ai-school"],
      },
    }),
  );
});

test("cross-user private profile and UID-stub reads and writes are denied", async () => {
  await seedProfile("teen-user", "13-17", "school");
  const attacker = authenticatedDatabase("other-user");

  await assertFails(getDoc(doc(attacker, "users", "teen-user")));
  await assertFails(getDoc(doc(attacker, "preferences", "teen-user")));
  await assertFails(getDoc(doc(attacker, "publicProfiles", "teen-user")));
  await assertFails(
    updateDoc(doc(attacker, "preferences", "teen-user"), {
      coachMode: "funny",
      updatedAt: serverTimestamp(),
    }),
  );
});

test("age UID schema and created timestamps are immutable", async () => {
  await seedProfile("adult-user", "18+", "work");
  const database = authenticatedDatabase("adult-user");

  await assertFails(
    updateDoc(doc(database, "users", "adult-user"), {
      ageBand: "13-17",
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(database, "users", "adult-user"), {
      userID: "fabricated-user",
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(database, "users", "adult-user"), {
      schemaVersion: 2,
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(database, "users", "adult-user"), {
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test("initial discoverability true is denied for teen and adult complete batches", async () => {
  await assertFails(
    createProfileBatch(databaseFor("teen-user"), "teen-user", "13-17", "school", {
      isDiscoverable: true,
    }),
  );
  await assertFails(
    createProfileBatch(databaseFor("adult-user"), "adult-user", "18+", "work", {
      isDiscoverable: true,
    }),
  );
});

test("teen discovery true is denied from stable private age in a valid paired update", async () => {
  await seedProfile("teen-user", "13-17", "school");
  const database = authenticatedDatabase("teen-user");

  await assertFails(
    updateDiscoverability(
      database,
      "teen-user",
      handleFor("teen-user"),
      true,
    ),
  );
});

test("adult discovery requires an atomic consistent UID-stub and directory update", async () => {
  await seedProfile("adult-user", "18+", "work");
  const database = authenticatedDatabase("adult-user");
  const handle = handleFor("adult-user");

  await assertFails(
    updateDiscoverability(database, "adult-user", handle, true, {
      omit: "directory",
    }),
  );
  await assertFails(
    updateDiscoverability(database, "adult-user", handle, true, {
      omit: "publicProfile",
    }),
  );
  await assertSucceeds(
    updateDiscoverability(database, "adult-user", handle, true),
  );
});

test("a second account cannot claim an existing exact handle", async () => {
  const sharedHandle = handleFor("shared-handle");
  await assertSucceeds(
    createProfileBatch(databaseFor("adult-a"), "adult-a", "18+", "work", {
      handle: sharedHandle,
    }),
  );

  await assertFails(
    createProfileBatch(databaseFor("adult-b"), "adult-b", "18+", "work", {
      handle: sharedHandle,
    }),
  );

  const privateB = await getDocumentWithoutRules("users", "adult-b");
  assert.equal(privateB, undefined);
});

test("exact-key public directory get is the only cross-user lookup and exposes no UID", async () => {
  await seedProfile("adult-user", "18+", "work");
  const handle = handleFor("adult-user");
  await assertSucceeds(
    updateDiscoverability(
      authenticatedDatabase("adult-user"),
      "adult-user",
      handle,
      true,
    ),
  );

  const searcher = authenticatedDatabase("searcher-user");
  const result = await assertSucceeds(
    getDoc(doc(searcher, "publicProfileDirectory", handle)),
  );
  assert.deepEqual(Object.keys(result.data()).sort(), ["handle", "isDiscoverable"]);
  assert.equal(result.data().handle, handle);
  assert.equal(result.data().isDiscoverable, true);
  assert.equal("userID" in result.data(), false);
  await assertFails(getDoc(doc(searcher, "publicProfiles", "adult-user")));
});

test("directory lists equality queries and multi-handle queries are always denied", async () => {
  await seedProfile("adult-a", "18+", "work");
  await seedProfile("adult-b", "18+", "work");
  const database = authenticatedDatabase("searcher-user");
  const handles = [handleFor("adult-a"), handleFor("adult-b")];

  await assertFails(getDocs(collection(database, "publicProfileDirectory")));
  await assertFails(
    getDocs(
      query(
        collection(database, "publicProfileDirectory"),
        where(documentId(), "==", handles[0]),
      ),
    ),
  );
  await assertFails(
    getDocs(
      query(
        collection(database, "publicProfileDirectory"),
        where(documentId(), "in", handles),
      ),
    ),
  );
  await assertFails(getDocs(collection(database, "publicProfiles")));
});

test("handle claims are owner-bound private and cannot transfer", async () => {
  await seedProfile("adult-user", "18+", "work");
  const handle = handleFor("adult-user");
  const owner = authenticatedDatabase("adult-user");
  const other = authenticatedDatabase("other-user");

  const ownClaim = await assertSucceeds(
    getDoc(doc(owner, "profileHandleClaims", handle)),
  );
  assert.deepEqual(Object.keys(ownClaim.data()).sort(), ["handle", "ownerUID"]);
  await assertFails(getDoc(doc(other, "profileHandleClaims", handle)));
  await assertFails(getDocs(collection(owner, "profileHandleClaims")));
  await assertFails(
    updateDoc(doc(owner, "profileHandleClaims", handle), {
      ownerUID: "other-user",
    }),
  );
});

test("public documents reject UID email age and handle changes", async () => {
  await seedProfile("adult-user", "18+", "work");
  const database = authenticatedDatabase("adult-user");
  const handle = handleFor("adult-user");

  await assertFails(
    updateDoc(doc(database, "publicProfiles", "adult-user"), {
      userID: "adult-user",
    }),
  );
  await assertFails(
    updateDoc(doc(database, "publicProfileDirectory", handle), {
      email: "private@example.com",
      ageBand: "18+",
    }),
  );
  await assertFails(
    updateDoc(doc(database, "publicProfiles", "adult-user"), {
      handle: handleFor("another-handle"),
    }),
  );
});

test("XP streak subscription and entitlement writes remain server-owned", async () => {
  await seedProfile("adult-user", "18+", "work");
  const database = authenticatedDatabase("adult-user");

  await assertFails(
    updateDoc(doc(database, "users", "adult-user"), {
      xp: 100000,
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(database, "preferences", "adult-user"), {
      streak: 999,
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(database, "users", "adult-user"), {
      subscription: "pro",
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(setDoc(doc(database, "progress", "adult-user"), { xp: 100 }));
  await assertFails(setDoc(doc(database, "streaks", "adult-user"), { current: 30 }));
  await assertFails(
    setDoc(doc(database, "subscriptions", "adult-user"), { tier: "pro" }),
  );
});

test("full adapter-shaped retry remains five records and preserves creation time", async () => {
  const database = authenticatedDatabase("adult-user");
  const handle = handleFor("adult-user");
  await assertSucceeds(
    createProfileBatch(database, "adult-user", "18+", "work"),
  );
  const firstUser = await getDocumentWithoutRules("users", "adult-user");
  const firstPreferences = await getDocumentWithoutRules("preferences", "adult-user");

  await assertSucceeds(
    retryProfileBatch(database, "adult-user", handle, "work"),
  );

  const secondUser = await getDocumentWithoutRules("users", "adult-user");
  const secondPreferences = await getDocumentWithoutRules("preferences", "adult-user");
  assert.equal(firstUser.createdAt.toMillis(), secondUser.createdAt.toMillis());
  assert.equal(
    firstPreferences.createdAt.toMillis(),
    secondPreferences.createdAt.toMillis(),
  );
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    for (const collectionName of [
      "users",
      "preferences",
      "publicProfiles",
      "profileHandleClaims",
      "publicProfileDirectory",
    ]) {
      assert.equal((await getDocs(collection(admin, collectionName))).size, 1);
    }
  });
});

function collectionForPath(path) {
  return path.split("/", 1)[0];
}

function documentIDForPath(path) {
  return path.slice(path.indexOf("/") + 1);
}

function storedPublicationDocument(entry) {
  const collectionName = collectionForPath(entry.path);
  const timestampField = [
    "featureConfiguration",
    "catalogs",
    "programs",
  ].includes(collectionName)
    ? "updatedAt"
    : "publishedAt";
  return {
    path: entry.path,
    data: {
      ...structuredClone(entry.data),
      [timestampField]: TEST_TIMESTAMP,
    },
  };
}

function cloneStoredData(data) {
  const clone = structuredClone(data);
  for (const key of ["updatedAt", "publishedAt", "occurredAt"]) {
    if (key in data) clone[key] = data[key];
  }
  return clone;
}

function learnerEntry(collectionName) {
  const entry = LEARNER_CURRICULUM_BY_COLLECTION.get(collectionName);
  assert.ok(entry, `Missing learner Rules fixture for ${collectionName}`);
  return entry;
}

function mismatchedPath(path) {
  const replacements = {
    featureConfiguration: "featureConfiguration/not-curriculum",
    catalogs: "catalogs/fr-fr",
    catalogVersions: "catalogVersions/catalog--en-us--v2",
    programs: "programs/alternate-program--en-us",
    programVersions: "programVersions/alternate-program--en-us--v1",
    modules: "modules/alternate-module--en-us--v1",
    lessonVersions: "lessonVersions/alternate-lesson--en-us--v1",
    rubricVersions: "rubricVersions/alternate-rubric--en-us--v1",
    assetVersions: "assetVersions/alternate-asset--en-us--v1",
  };
  return replacements[collectionForPath(path)];
}

async function seedRulesDocuments(entries) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const batch = writeBatch(context.firestore());
    for (const entry of entries) {
      batch.set(doc(context.firestore(), entry.path), entry.data);
    }
    await batch.commit();
  });
}

async function overwriteRulesDocument(entry) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), entry.path), entry.data);
  });
}

function authenticatedDatabase(userID) {
  return testEnvironment.authenticatedContext(userID).firestore();
}

function databaseFor(userID) {
  return authenticatedDatabase(userID);
}

function handleFor(seed) {
  return `learner-${createHash("sha256").update(seed).digest("hex").slice(0, 20)}`;
}

function userDocument(userID, ageBand) {
  return {
    userID,
    email: `${userID}@example.com`,
    displayName: "Private Learner",
    ageBand,
    schemaVersion: 1,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

function preferencesDocument(userID, selectedPath) {
  return {
    userID,
    goal: selectedPath === "school" ? "studySmarter" : "workProductivity",
    experience: "beginner",
    selectedPath,
    coachMode: "supportive",
    enrolledProgramIDs: ["ai-foundations", `ai-${selectedPath}`],
    schemaVersion: 1,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

function createProfileBatch(
  database,
  userID,
  ageBand,
  selectedPath,
  options = {},
) {
  const handle = options.handle ?? handleFor(userID);
  const user = { ...userDocument(userID, ageBand), ...options.userOverrides };
  const preferences = {
    ...preferencesDocument(userID, selectedPath),
    ...options.preferencesOverrides,
  };
  if (options.omitAge) {
    delete user.ageBand;
  }
  const publicProfile = {
    handle,
    isDiscoverable: options.isDiscoverable ?? false,
  };
  const claim = { handle, ownerUID: userID };
  const directory = {
    handle,
    isDiscoverable: options.isDiscoverable ?? false,
  };
  const batch = writeBatch(database);
  if (options.omit !== "user") {
    batch.set(doc(database, "users", userID), user, { merge: true });
  }
  if (options.omit !== "preferences") {
    batch.set(doc(database, "preferences", userID), preferences, { merge: true });
  }
  if (options.omit !== "publicProfile") {
    batch.set(doc(database, "publicProfiles", userID), publicProfile, { merge: true });
  }
  if (options.omit !== "claim") {
    batch.set(doc(database, "profileHandleClaims", handle), claim, { merge: true });
  }
  if (options.omit !== "directory") {
    batch.set(doc(database, "publicProfileDirectory", handle), directory, {
      merge: true,
    });
  }
  return batch.commit();
}

function retryProfileBatch(database, userID, handle, selectedPath) {
  const batch = writeBatch(database);
  batch.set(
    doc(database, "users", userID),
    {
      userID,
      email: "updated@example.com",
      displayName: "Private Learner",
      schemaVersion: 1,
      updatedAt: serverTimestamp(),
    },
    { merge: true },
  );
  const preferences = preferencesDocument(userID, selectedPath);
  delete preferences.createdAt;
  batch.set(doc(database, "preferences", userID), preferences, { merge: true });
  batch.set(
    doc(database, "publicProfiles", userID),
    { handle, isDiscoverable: false },
    { merge: true },
  );
  batch.set(
    doc(database, "profileHandleClaims", handle),
    { handle, ownerUID: userID },
    { merge: true },
  );
  batch.set(
    doc(database, "publicProfileDirectory", handle),
    { handle, isDiscoverable: false },
    { merge: true },
  );
  return batch.commit();
}

function updateDiscoverability(
  database,
  userID,
  handle,
  isDiscoverable,
  options = {},
) {
  const batch = writeBatch(database);
  if (options.omit !== "publicProfile") {
    batch.set(
      doc(database, "publicProfiles", userID),
      { handle, isDiscoverable },
      { merge: true },
    );
  }
  if (options.omit !== "directory") {
    batch.set(
      doc(database, "publicProfileDirectory", handle),
      { handle, isDiscoverable },
      { merge: true },
    );
  }
  return batch.commit();
}

async function seedProfile(userID, ageBand, selectedPath) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await createProfileBatch(context.firestore(), userID, ageBand, selectedPath);
  });
}

async function getDocumentWithoutRules(collectionName, documentID) {
  let data;
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const snapshot = await getDoc(
      doc(context.firestore(), collectionName, documentID),
    );
    data = snapshot.data();
  });
  return data;
}
