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
  doc,
  documentId,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from "firebase/firestore";

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
