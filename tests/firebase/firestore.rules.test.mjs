import assert from "node:assert/strict";
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
  getDoc,
  getDocs,
  limit,
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

test("unauthenticated clients cannot read or create profile documents", async () => {
  const database = testEnvironment.unauthenticatedContext().firestore();

  await assertFails(getDoc(doc(database, "users", "teen-user")));
  await assertFails(
    setDoc(doc(database, "users", "teen-user"), userDocument("teen-user", "13-17")),
  );
  await assertFails(
    setDoc(
      doc(database, "preferences", "teen-user"),
      preferencesDocument("teen-user", "school"),
    ),
  );
  await assertFails(
    setDoc(doc(database, "publicProfiles", "teen-user"), {
      handle: "learner-11111111111111111111",
      isDiscoverable: false,
    }),
  );
});

test("an authenticated learner can atomically create and read only their private profile", async () => {
  const database = authenticatedDatabase("teen-user");

  await assertSucceeds(createProfileBatch(database, "teen-user", "13-17", "school"));
  await assertSucceeds(getDoc(doc(database, "users", "teen-user")));
  await assertSucceeds(getDoc(doc(database, "preferences", "teen-user")));
  await assertSucceeds(getDoc(doc(database, "publicProfiles", "teen-user")));
});

test("profile creation cannot omit either mandatory private document", async () => {
  const userDatabase = authenticatedDatabase("user-only");
  const preferencesDatabase = authenticatedDatabase("preferences-only");

  await assertFails(
    setDoc(
      doc(userDatabase, "users", "user-only"),
      userDocument("user-only", "18+"),
    ),
  );
  await assertFails(
    setDoc(
      doc(preferencesDatabase, "preferences", "preferences-only"),
      preferencesDocument("preferences-only", "work"),
    ),
  );
});

test("cross-user private reads and writes are denied", async () => {
  await seedProfile("teen-user", "13-17", "school");
  const attackerDatabase = authenticatedDatabase("other-user");

  await assertFails(getDoc(doc(attackerDatabase, "users", "teen-user")));
  await assertFails(getDoc(doc(attackerDatabase, "preferences", "teen-user")));
  await assertFails(
    updateDoc(doc(attackerDatabase, "preferences", "teen-user"), {
      coachMode: "funny",
      updatedAt: serverTimestamp(),
    }),
  );
});

test("a private age band is mandatory on first profile creation", async () => {
  const database = authenticatedDatabase("teen-user");
  const invalidUser = userDocument("teen-user", "13-17");
  delete invalidUser.ageBand;

  await assertFails(setDoc(doc(database, "users", "teen-user"), invalidUser));
});

test("a learner cannot mutate the private age band after creation", async () => {
  await seedProfile("teen-user", "13-17", "school");
  const database = authenticatedDatabase("teen-user");

  await assertFails(
    updateDoc(doc(database, "users", "teen-user"), {
      ageBand: "18+",
      updatedAt: serverTimestamp(),
    }),
  );
});

test("stable UID schema and created timestamp cannot be rewritten", async () => {
  await seedProfile("adult-user", "18+", "work");
  const database = authenticatedDatabase("adult-user");

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

test("initial public discoverability is false for both teen and adult profiles", async () => {
  const teenDatabase = authenticatedDatabase("teen-user");
  const adultDatabase = authenticatedDatabase("adult-user");

  await assertFails(
    createProfileBatch(teenDatabase, "teen-user", "13-17", "school", true),
  );
  await assertFails(
    createProfileBatch(adultDatabase, "adult-user", "18+", "work", true),
  );
});

test("teen discoverability cannot become true using mutable public age data", async () => {
  await seedProfile("teen-user", "13-17", "school");
  const database = authenticatedDatabase("teen-user");

  await assertFails(
    updateDoc(doc(database, "publicProfiles", "teen-user"), {
      ageBand: "18+",
      isDiscoverable: true,
    }),
  );
  await assertFails(
    updateDoc(doc(database, "publicProfiles", "teen-user"), {
      isDiscoverable: true,
    }),
  );
});

test("adult discoverability can become true only after a stable private profile exists", async () => {
  await seedProfile("adult-user", "18+", "work");
  const database = authenticatedDatabase("adult-user");

  await assertSucceeds(
    updateDoc(doc(database, "publicProfiles", "adult-user"), {
      isDiscoverable: true,
    }),
  );
});

test("public profiles reject email age and handle changes", async () => {
  await seedProfile("adult-user", "18+", "work");
  const database = authenticatedDatabase("adult-user");

  await assertFails(
    updateDoc(doc(database, "publicProfiles", "adult-user"), {
      email: "private@example.com",
    }),
  );
  await assertFails(
    updateDoc(doc(database, "publicProfiles", "adult-user"), {
      handle: "learner-ffffffffffffffffffff",
    }),
  );
});

test("preferences require Foundations plus the selected specialization", async () => {
  const database = authenticatedDatabase("adult-user");
  const missingFoundations = preferencesDocument("adult-user", "work");
  missingFoundations.enrolledProgramIDs = ["ai-work"];
  const mismatchedPath = preferencesDocument("adult-user", "work");
  mismatchedPath.enrolledProgramIDs = ["ai-foundations", "ai-school"];

  await assertFails(
    setDoc(doc(database, "preferences", "adult-user"), missingFoundations),
  );
  await assertFails(
    setDoc(doc(database, "preferences", "adult-user"), mismatchedPath),
  );
});

test("clients cannot add XP streak or subscription state to profile documents", async () => {
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
});

test("client writes to server-owned reward and entitlement collections are denied", async () => {
  const database = authenticatedDatabase("adult-user");

  await assertFails(setDoc(doc(database, "progress", "adult-user"), { xp: 100 }));
  await assertFails(
    setDoc(doc(database, "streaks", "adult-user"), { current: 30 }),
  );
  await assertFails(
    setDoc(doc(database, "subscriptions", "adult-user"), { tier: "pro" }),
  );
});

test("an exact discoverable-handle query returns only the allowed public fields", async () => {
  await seedProfile("adult-user", "18+", "work");
  const ownerDatabase = authenticatedDatabase("adult-user");
  await assertSucceeds(
    updateDoc(doc(ownerDatabase, "publicProfiles", "adult-user"), {
      isDiscoverable: true,
    }),
  );

  const searchDatabase = authenticatedDatabase("searcher-user");
  const exactHandleQuery = query(
    collection(searchDatabase, "publicProfiles"),
    where("handle", "==", "learner-22222222222222222222"),
    where("isDiscoverable", "==", true),
    limit(1),
  );
  const result = await assertSucceeds(getDocs(exactHandleQuery));

  assert.equal(result.size, 1);
  assert.deepEqual(
    Object.keys(result.docs[0].data()).sort(),
    ["handle", "isDiscoverable"],
  );
});

test("broad public-profile reads fail when they could include undiscoverable profiles", async () => {
  await seedProfile("teen-user", "13-17", "school");
  await seedProfile("adult-user", "18+", "work");
  const database = authenticatedDatabase("searcher-user");

  await assertFails(getDocs(collection(database, "publicProfiles")));
});

test("retrying the same UID remains one record per collection and preserves creation time", async () => {
  const database = authenticatedDatabase("adult-user");
  await assertSucceeds(createProfileBatch(database, "adult-user", "18+", "work"));

  const first = await getDocumentWithoutRules("users", "adult-user");
  await assertSucceeds(
    setDoc(
      doc(database, "users", "adult-user"),
      {
        email: "updated@example.com",
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    ),
  );
  const second = await getDocumentWithoutRules("users", "adult-user");

  assert.equal(first.createdAt.toMillis(), second.createdAt.toMillis());
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const adminDatabase = context.firestore();
    assert.equal((await getDocs(collection(adminDatabase, "users"))).size, 1);
    assert.equal((await getDocs(collection(adminDatabase, "preferences"))).size, 1);
    assert.equal((await getDocs(collection(adminDatabase, "publicProfiles"))).size, 1);
  });
});

function authenticatedDatabase(userID) {
  return testEnvironment.authenticatedContext(userID).firestore();
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
  isDiscoverable = false,
) {
  const batch = writeBatch(database);
  batch.set(doc(database, "users", userID), userDocument(userID, ageBand), {
    merge: true,
  });
  batch.set(
    doc(database, "preferences", userID),
    preferencesDocument(userID, selectedPath),
    { merge: true },
  );
  batch.set(
    doc(database, "publicProfiles", userID),
    {
      handle:
        userID === "adult-user"
          ? "learner-22222222222222222222"
          : "learner-11111111111111111111",
      isDiscoverable,
    },
    { merge: true },
  );
  return batch.commit();
}

async function seedProfile(userID, ageBand, selectedPath) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await createProfileBatch(
      context.firestore(),
      userID,
      ageBand,
      selectedPath,
    );
  });
}

async function getDocumentWithoutRules(collectionName, userID) {
  let data;
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const snapshot = await getDoc(doc(context.firestore(), collectionName, userID));
    data = snapshot.data();
  });
  return data;
}
