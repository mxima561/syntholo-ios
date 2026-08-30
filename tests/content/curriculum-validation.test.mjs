import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

import {
  canonicalBytes,
  canonicalString,
  contentDigest,
  payloadDigest,
  publicationDigest,
  sha256Hex,
} from "../../tools/content/lib/canonical-json.mjs";
import {
  CurriculumValidationError,
  SYNTHETIC_FIXTURE_SENTINEL,
  assertPublicationBudgetWithinLimit,
  assertPublicationSourceAllowed,
  assertValidCurriculumDraft,
  calculatePublicationBudget,
  isSyntheticCurriculumSource,
  validateCurriculumDraft,
} from "../../tools/content/lib/curriculum-validation.mjs";
import { buildPublicationShape } from "../../tools/content/lib/firestore-shape.mjs";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);
const fixturePath = path.join(
  repositoryRoot,
  "tests/fixtures/content/minimal-curriculum-v1.json",
);
const vectorPath = path.join(
  repositoryRoot,
  "content/schema/curriculum-v1.digest-vectors.json",
);
const schemaPath = path.join(
  repositoryRoot,
  "content/schema/curriculum-v1.schema.json",
);

const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
const digestVectors = JSON.parse(await readFile(vectorPath, "utf8"));
const curriculumSchema = JSON.parse(await readFile(schemaPath, "utf8"));
const schemaAjv = new Ajv2020({ allErrors: true, strict: true });
addFormats(schemaAjv);
schemaAjv.addSchema(curriculumSchema);
const schemaValidators = new Map();

const cloneFixture = () => structuredClone(fixture);

function schemaValidator(jsonPointer) {
  if (!schemaValidators.has(jsonPointer)) {
    schemaValidators.set(
      jsonPointer,
      schemaAjv.compile({ $ref: `${curriculumSchema.$id}#${jsonPointer}` }),
    );
  }
  return schemaValidators.get(jsonPointer);
}

function assertSchemaValid(jsonPointer, value, label = jsonPointer) {
  const validateValue = schemaValidator(jsonPointer);
  assert.equal(
    validateValue(value),
    true,
    `${label}: ${JSON.stringify(validateValue.errors)}`,
  );
}

function assertSchemaInvalid(jsonPointer, value, label = jsonPointer) {
  const validateValue = schemaValidator(jsonPointer);
  assert.equal(validateValue(value), false, `${label} unexpectedly passed`);
}

function validate(draft) {
  return validateCurriculumDraft(draft, { sourcePath: fixturePath });
}

function assertStructuredIssues(result) {
  assert.equal(result.ok, false);
  assert.ok(Array.isArray(result.issues));
  assert.ok(result.issues.length > 0);
  assert.equal(result.publication, undefined);

  for (const issue of result.issues) {
    assert.equal(typeof issue.code, "string");
    assert.ok(issue.code.length > 0);
    assert.equal(typeof issue.path, "string");
    assert.ok(issue.path === "" || issue.path.startsWith("/"));
  }
}

function assertInvalid(mutator, { codes, path: expectedPath }) {
  const draft = cloneFixture();
  mutator(draft);
  const result = validate(draft);
  assertStructuredIssues(result);

  const acceptedCodes = Array.isArray(codes) ? codes : [codes];
  const matchingIssue = result.issues.find((issue) => {
    const codeMatches = acceptedCodes.includes(issue.code);
    const pathMatches =
      expectedPath instanceof RegExp
        ? expectedPath.test(issue.path)
        : issue.path === expectedPath;
    return codeMatches && pathMatches;
  });

  assert.ok(
    matchingIssue,
    `Expected ${acceptedCodes.join(" or ")} at ${expectedPath}; received ${JSON.stringify(result.issues)}`,
  );
  return { draft, result };
}

function questionBlock(lesson) {
  const block = lesson.blocks.find((candidate) => candidate.type === "singleAnswerQuestion");
  assert.ok(block, "The synthetic fixture must contain its deterministic question block");
  return block;
}

function diagramBlock(lesson) {
  const block = lesson.blocks.find((candidate) => candidate.type === "stillDiagram");
  assert.ok(block, "The synthetic fixture must contain its still-diagram block");
  return block;
}

function addSecondSyntheticLesson(draft, { attachToModule = true } = {}) {
  const source = draft.lessonVersions[0];
  const copy = structuredClone(source);
  copy.lessonID = "synthetic-second";
  copy.lessonVersionID = "synthetic-second--en-us--v1";
  copy.title = "Synthetic second contract record";
  copy.prerequisiteLessonIDs = [];
  draft.lessonVersions.push(copy);
  if (attachToModule) {
    draft.moduleVersions[0].lessonVersionIDs.push(copy.lessonVersionID);
  }
  return copy;
}

function addComingSoonProgram(draft, index = 1) {
  const programID = `synthetic-shell-${index}`;
  const program = structuredClone(draft.programVersions[0]);
  Object.assign(program, {
    programID,
    programVersionID: `${programID}--en-us--v1`,
    title: `Synthetic coming-soon shell ${index}`,
    catalogState: "comingSoon",
    moduleVersionIDs: [],
    firstLessonVersionID: null,
  });
  draft.programVersions.push(program);
  draft.catalogVersion.programEntries.push({
    programPointerID: `${programID}--en-us`,
    programVersionID: program.programVersionID,
  });
  return program;
}

function addSecondAvailableProgram(draft) {
  const program = structuredClone(draft.programVersions[0]);
  Object.assign(program, {
    programID: "synthetic-second-program",
    programVersionID: "synthetic-second-program--en-us--v1",
    title: "Synthetic second available program",
    moduleVersionIDs: ["synthetic-second-module--en-us--v1"],
    firstLessonVersionID: "synthetic-second-lesson--en-us--v1",
  });

  const module = structuredClone(draft.moduleVersions[0]);
  Object.assign(module, {
    moduleID: "synthetic-second-module",
    moduleVersionID: "synthetic-second-module--en-us--v1",
    programID: program.programID,
    title: "Synthetic second available module",
    lessonVersionIDs: [program.firstLessonVersionID],
  });

  const lesson = structuredClone(draft.lessonVersions[0]);
  Object.assign(lesson, {
    lessonID: "synthetic-second-lesson",
    lessonVersionID: program.firstLessonVersionID,
    programID: program.programID,
    moduleID: module.moduleID,
    title: "Synthetic second available lesson",
  });

  draft.programVersions.push(program);
  draft.moduleVersions.push(module);
  draft.lessonVersions.push(lesson);
  draft.catalogVersion.programEntries.push({
    programPointerID: `${program.programID}--en-us`,
    programVersionID: program.programVersionID,
  });
}

function makeLargeLessonBlocks(lesson) {
  const diagram = structuredClone(diagramBlock(lesson));
  const question = structuredClone(questionBlock(lesson));
  const blocks = Array.from({ length: 38 }, (_, index) => ({
    blockID: `synthetic-large-concept-${index}`,
    type: "conceptText",
    order: index,
    body: "😀".repeat(4000),
  }));
  diagram.order = 38;
  question.order = 39;
  lesson.blocks = [...blocks, diagram, question];
}

test("the minimal synthetic authoring envelope validates and builds one deterministic publication", () => {
  const result = validate(fixture);

  assert.equal(result.ok, true, JSON.stringify(result.issues));
  assert.deepEqual(result.issues, []);
  assert.ok(result.publication);
  assert.deepEqual(result.publication, buildPublicationShape(fixture));
  assert.doesNotThrow(() =>
    assertValidCurriculumDraft(fixture, { sourcePath: fixturePath }),
  );
});

test("schema validation rejects unknown properties at envelope and nested document boundaries", async (t) => {
  await t.test("unknown envelope property", () => {
    assertInvalid(
      (draft) => {
        draft.unexpectedContractField = true;
      },
      {
        codes: ["UNKNOWN_PROPERTY", "SCHEMA_INVALID"],
        path: "/<unknown-property>",
      },
    );
  });

  await t.test("unknown nested property", () => {
    assertInvalid(
      (draft) => {
        draft.lessonVersions[0].unexpectedContractField = true;
      },
      {
        codes: ["UNKNOWN_PROPERTY", "SCHEMA_INVALID"],
        path: "/lessonVersions/0/<unknown-property>",
      },
    );
  });

  await t.test("integer and lower-bound enforcement", () => {
    assertInvalid(
      (draft) => {
        draft.lessonVersions[0].expectedDurationMinutes = 0;
      },
      {
        codes: "SCHEMA_INVALID",
        path: "/lessonVersions/0/expectedDurationMinutes",
      },
    );

    assertInvalid(
      (draft) => {
        draft.catalogVersion.version = 1.5;
      },
      {
        codes: "SCHEMA_INVALID",
        path: "/catalogVersion/version",
      },
    );
  });

  await t.test("closed block discriminator", () => {
    assertInvalid(
      (draft) => {
        draft.lessonVersions[0].blocks[0].type = "syntheticUnsupportedBlock";
      },
      {
        codes: ["UNKNOWN_DISCRIMINATOR", "SCHEMA_INVALID"],
        path: "/lessonVersions/0/blocks/0/type",
      },
    );
  });
});

test("stable, pointer, and immutable IDs are derived from locale, identity, and version", async (t) => {
  await t.test("stable IDs use lowercase ASCII kebab case", () => {
    assertInvalid(
      (draft) => {
        draft.programVersions[0].programID = "AI Foundations";
      },
      {
        codes: ["STABLE_ID_INVALID", "SCHEMA_INVALID"],
        path: "/programVersions/0/programID",
      },
    );
  });

  await t.test("program version ID is exact", () => {
    assertInvalid(
      (draft) => {
        draft.programVersions[0].programVersionID = "ai-foundations--en-us--v2";
      },
      {
        codes: "DERIVED_ID_MISMATCH",
        path: "/programVersions/0/programVersionID",
      },
    );
  });

  await t.test("catalog entry pointer ID encodes the selected program and locale", () => {
    assertInvalid(
      (draft) => {
        draft.catalogVersion.programEntries[0].programPointerID =
          "synthetic-other--en-us";
      },
      {
        codes: "DERIVED_ID_MISMATCH",
        path: "/catalogVersion/programEntries/0/programPointerID",
      },
    );
  });

  await t.test("launch locale is canonical en-US", () => {
    assertInvalid(
      (draft) => {
        draft.lessonVersions[0].locale = "en-us";
      },
      {
        codes: ["LOCALE_MISMATCH", "SCHEMA_INVALID"],
        path: "/lessonVersions/0/locale",
      },
    );
  });
});

test("only source drafts without generated publication fields are accepted", async (t) => {
  await t.test("envelope state", () => {
    assertInvalid(
      (draft) => {
        draft.publicationState = "published";
      },
      {
        codes: ["PUBLICATION_STATE_INVALID", "SCHEMA_INVALID"],
        path: "/publicationState",
      },
    );
  });

  await t.test("nested immutable state", () => {
    assertInvalid(
      (draft) => {
        draft.lessonVersions[0].publicationState = "published";
      },
      {
        codes: ["PUBLICATION_STATE_INVALID", "SCHEMA_INVALID"],
        path: "/lessonVersions/0/publicationState",
      },
    );
  });

  await t.test("client-authored digest", () => {
    assertInvalid(
      (draft) => {
        draft.lessonVersions[0].contentDigest = "0".repeat(64);
      },
      {
        codes: ["UNKNOWN_PROPERTY", "SCHEMA_INVALID"],
        path: "/lessonVersions/0/contentDigest",
      },
    );
  });

  await t.test("client-authored timestamp", () => {
    assertInvalid(
      (draft) => {
        draft.lessonVersions[0].publishedAt = "2026-08-30T00:00:00Z";
      },
      {
        codes: ["UNKNOWN_PROPERTY", "SCHEMA_INVALID"],
        path: "/lessonVersions/0/publishedAt",
      },
    );
  });
});

test("ordered arrays reject duplicate identities and non-consecutive presentation order", async (t) => {
  await t.test("duplicate catalog selection", () => {
    assertInvalid(
      (draft) => {
        draft.catalogVersion.programEntries.push(
          structuredClone(draft.catalogVersion.programEntries[0]),
        );
      },
      {
        codes: "DUPLICATE_VALUE",
        path: "/catalogVersion/programEntries/1/programPointerID",
      },
    );
  });

  await t.test("duplicate question option ID", () => {
    assertInvalid(
      (draft) => {
        const question = questionBlock(draft.lessonVersions[0]);
        question.options[1].optionID = question.options[0].optionID;
      },
      {
        codes: "DUPLICATE_VALUE",
        path: /\/lessonVersions\/0\/blocks\/\d+\/options\/1\/optionID/,
      },
    );
  });

  await t.test("block order is consecutive and matches array order", () => {
    assertInvalid(
      (draft) => {
        draft.lessonVersions[0].blocks[1].order = 0;
      },
      {
        codes: "ORDER_INVALID",
        path: "/lessonVersions/0/blocks/1/order",
      },
    );
  });
});

test("catalog graph validation rejects missing references, ownership drift, and orphans", async (t) => {
  await t.test("missing exact module version", () => {
    assertInvalid(
      (draft) => {
        draft.programVersions[0].moduleVersionIDs[0] =
          "synthetic-missing--en-us--v1";
      },
      {
        codes: "REFERENCE_NOT_FOUND",
        path: "/programVersions/0/moduleVersionIDs/0",
      },
    );
  });

  await t.test("cross-program module ownership", () => {
    assertInvalid(
      (draft) => {
        draft.moduleVersions[0].programID = "synthetic-other";
      },
      {
        codes: "OWNERSHIP_MISMATCH",
        path: "/moduleVersions/0/programID",
      },
    );
  });

  await t.test("unreachable lesson payload", () => {
    assertInvalid(
      (draft) => {
        addSecondSyntheticLesson(draft, { attachToModule: false });
      },
      {
        codes: "ORPHAN_DOCUMENT",
        path: "/lessonVersions/1",
      },
    );
  });
});

test("prerequisite validation enforces catalog-order reachability and a DAG", async (t) => {
  await t.test("later prerequisite cannot gate an earlier lesson", () => {
    assertInvalid(
      (draft) => {
        const second = addSecondSyntheticLesson(draft);
        draft.lessonVersions[0].prerequisiteLessonIDs = [second.lessonID];
      },
      {
        codes: "PREREQUISITE_ORDER_INVALID",
        path: "/lessonVersions/0/prerequisiteLessonIDs/0",
      },
    );
  });

  await t.test("cycle", () => {
    assertInvalid(
      (draft) => {
        const first = draft.lessonVersions[0];
        const second = addSecondSyntheticLesson(draft);
        first.prerequisiteLessonIDs = [second.lessonID];
        second.prerequisiteLessonIDs = [first.lessonID];
      },
      {
        codes: "PREREQUISITE_CYCLE",
        path: /\/lessonVersions\/\d+\/prerequisiteLessonIDs\/0/,
      },
    );
  });
});

test("available lessons require the closed block set and exact completion question", async (t) => {
  await t.test("concept block is required", () => {
    assertInvalid(
      (draft) => {
        draft.lessonVersions[0].blocks = draft.lessonVersions[0].blocks.filter(
          (block) => block.type !== "conceptText",
        );
        draft.lessonVersions[0].blocks.forEach((block, index) => {
          block.order = index;
        });
      },
      {
        codes: "REQUIRED_BLOCK_KIND_MISSING",
        path: "/lessonVersions/0/blocks",
      },
    );
  });

  await t.test("completion rule names the one deterministic question", () => {
    assertInvalid(
      (draft) => {
        draft.lessonVersions[0].completionRule.requiredBlockIDs[0] =
          "synthetic-missing-question";
      },
      {
        codes: "REFERENCE_NOT_FOUND",
        path: "/lessonVersions/0/completionRule/requiredBlockIDs/0",
      },
    );
  });

  await t.test("exactly one question is supported in schema v1", () => {
    assertInvalid(
      (draft) => {
        const lesson = draft.lessonVersions[0];
        const duplicate = structuredClone(questionBlock(lesson));
        duplicate.blockID = "synthetic-second-question";
        duplicate.order = lesson.blocks.length;
        lesson.blocks.push(duplicate);
      },
      {
        codes: "QUESTION_COUNT_INVALID",
        path: "/lessonVersions/0/blocks",
      },
    );
  });
});

test("diagram assets, accessibility, references, and rights fail closed", async (t) => {
  await t.test("diagram block resolves an exact declared asset", () => {
    assertInvalid(
      (draft) => {
        diagramBlock(draft.lessonVersions[0]).assetVersionID =
          "synthetic-missing-diagram--en-us--v1";
      },
      {
        codes: "ASSET_REFERENCE_INVALID",
        path: /\/lessonVersions\/0\/blocks\/\d+\/assetVersionID/,
      },
    );
  });

  await t.test("declared lesson asset cannot be unused", () => {
    assertInvalid(
      (draft) => {
        const extra = structuredClone(draft.assetVersions[0]);
        extra.assetID = "synthetic-unused-diagram";
        extra.assetVersionID = "synthetic-unused-diagram--en-us--v1";
        draft.assetVersions.push(extra);
        draft.lessonVersions[0].assetVersionIDs.push(extra.assetVersionID);
      },
      {
        codes: "ASSET_REFERENCE_INVALID",
        path: "/lessonVersions/0/assetVersionIDs/1",
      },
    );
  });

  await t.test("diagram connector nodes resolve and cannot self-link", () => {
    assertInvalid(
      (draft) => {
        const asset = draft.assetVersions[0];
        asset.payload.connectors.push({
          connectorID: "synthetic-broken-link",
          fromNodeID: asset.payload.nodes[0].nodeID,
          toNodeID: "synthetic-missing-node",
          label: null,
        });
      },
      {
        codes: "ASSET_REFERENCE_INVALID",
        path: /\/assetVersions\/0\/payload\/connectors\/\d+\/toNodeID/,
      },
    );
  });

  await t.test("accessibility description is non-empty", () => {
    assertInvalid(
      (draft) => {
        draft.assetVersions[0].accessibilityDescription = "";
      },
      {
        codes: "SCHEMA_INVALID",
        path: "/assetVersions/0/accessibilityDescription",
      },
    );
  });

  await t.test("licensed assets require HTTPS provenance and a license", () => {
    assertInvalid(
      (draft) => {
        draft.assetVersions[0].rights = {
          origin: "licensed",
          creator: "Synthetic fixture creator",
          sourceURL: null,
          license: null,
        };
      },
      {
        codes: "RIGHTS_INVALID",
        path: "/assetVersions/0/rights/sourceURL",
      },
    );
  });
});

test("public scoring metadata agrees with the protected evaluation contract", async (t) => {
  await t.test("question identity", () => {
    assertInvalid(
      (draft) => {
        draft.evaluationContractVersions[0].questionBlockID =
          "synthetic-other-question";
      },
      {
        codes: "SCORING_CONTRACT_MISMATCH",
        path: "/evaluationContractVersions/0/questionBlockID",
      },
    );
  });

  await t.test("correct option identity", () => {
    assertInvalid(
      (draft) => {
        const options = questionBlock(draft.lessonVersions[0]).options;
        assert.ok(options.length >= 2);
        draft.evaluationContractVersions[0].correctOptionID = options[1].optionID;
      },
      {
        codes: "SCORING_CONTRACT_MISMATCH",
        path: "/evaluationContractVersions/0/correctOptionID",
      },
    );
  });

  await t.test("evaluation contract pins its public rubric", () => {
    assertInvalid(
      (draft) => {
        draft.evaluationContractVersions[0].rubricVersionID =
          "synthetic-missing-rubric--en-us--v1";
      },
      {
        codes: "SCORING_CONTRACT_MISMATCH",
        path: "/evaluationContractVersions/0/rubricVersionID",
      },
    );
  });
});

test("shared RFC 8785 vectors freeze canonical UTF-8 bytes and SHA-256", () => {
  assert.equal(digestVectors.schemaVersion, 1);
  assert.ok(Array.isArray(digestVectors.vectors));

  const names = new Set(digestVectors.vectors.map((vector) => vector.name));
  for (const requiredName of [
    "ascii",
    "unicode",
    "nested-object",
    "array-order",
    "null",
    "omission",
  ]) {
    assert.ok(names.has(requiredName), `Missing ${requiredName} digest vector`);
  }

  for (const vector of digestVectors.vectors) {
    assert.equal(canonicalString(vector.value), vector.canonical, vector.name);
    assert.deepEqual(
      canonicalBytes(vector.value),
      Buffer.from(vector.canonical, "utf8"),
      vector.name,
    );
    assert.equal(sha256Hex(vector.canonical), vector.sha256, vector.name);
  }
});

test("JCS ignores object key insertion order but preserves array order", () => {
  const first = { z: 3, nested: { b: 2, a: 1 }, values: ["first", "second"] };
  const reorderedKeys = {
    values: ["first", "second"],
    nested: { a: 1, b: 2 },
    z: 3,
  };
  const reorderedArray = {
    values: ["second", "first"],
    nested: { a: 1, b: 2 },
    z: 3,
  };

  assert.equal(canonicalString(first), canonicalString(reorderedKeys));
  assert.equal(sha256Hex(canonicalBytes(first)), sha256Hex(canonicalBytes(reorderedKeys)));
  assert.notEqual(canonicalString(first), canonicalString(reorderedArray));
  assert.notEqual(sha256Hex(canonicalBytes(first)), sha256Hex(canonicalBytes(reorderedArray)));
});

test("document and payload digests are deterministic and omit only generated document fields", () => {
  const payload = fixture.assetVersions[0].payload;
  assert.match(payloadDigest(payload), /^[0-9a-f]{64}$/);
  assert.equal(payloadDigest(payload), sha256Hex(canonicalBytes(payload)));

  const authoredDocument = {
    id: "synthetic-record",
    publicationState: "published",
    order: ["first", "second"],
  };
  const generatedFields = {
    ...authoredDocument,
    contentDigest: "0".repeat(64),
    publishedAt: { seconds: 1, nanoseconds: 0 },
  };

  assert.equal(contentDigest(authoredDocument), contentDigest(generatedFields));
  assert.notEqual(
    contentDigest(authoredDocument),
    contentDigest({ ...authoredDocument, order: ["second", "first"] }),
  );
});

test("publication shape includes recomputable document, asset, and manifest digests", () => {
  const publication = buildPublicationShape(fixture);
  assert.ok(Array.isArray(publication.immutableDocuments));
  assert.ok(publication.immutableDocuments.length > 0);

  const paths = publication.immutableDocuments.map((document) => document.path);
  assert.deepEqual(paths, [...paths].sort());

  for (const document of publication.immutableDocuments) {
    assert.match(document.path, /^[A-Za-z]+\/[a-z0-9-]+$/);
    assert.equal(document.data.publicationState, "published");
    assert.equal(Object.hasOwn(document.data, "publishedAt"), false);
    assert.match(document.data.contentDigest, /^[0-9a-f]{64}$/);
    assert.equal(document.data.contentDigest, contentDigest(document.data));
  }

  const asset = publication.immutableDocuments.find((document) =>
    document.path.startsWith("assetVersions/"),
  );
  assert.ok(asset);
  assert.equal(asset.data.payloadDigest, payloadDigest(asset.data.payload));
  assert.equal(
    asset.data.byteCount,
    Buffer.byteLength(canonicalBytes(asset.data.payload)),
  );

  assert.equal(
    publication.publicationDigest,
    publicationDigest(publication.immutableDocuments),
  );
});

test("publication digest sorts full document paths and changes with any document digest", () => {
  const documents = [
    {
      path: "lessonVersions/synthetic-b--en-us--v1",
      data: { contentDigest: "b".repeat(64) },
    },
    {
      path: "lessonVersions/synthetic-a--en-us--v1",
      data: { contentDigest: "a".repeat(64) },
    },
  ];
  const canonicalManifest = {
    "lessonVersions/synthetic-a--en-us--v1": "a".repeat(64),
    "lessonVersions/synthetic-b--en-us--v1": "b".repeat(64),
  };

  assert.equal(
    publicationDigest(documents),
    sha256Hex(canonicalBytes(canonicalManifest)),
  );
  assert.equal(publicationDigest(documents), publicationDigest([...documents].reverse()));

  const changed = structuredClone(documents);
  changed[0].data.contentDigest = "c".repeat(64);
  assert.notEqual(publicationDigest(documents), publicationDigest(changed));
});

test("publication budget uses the frozen conservative first-publication formula", () => {
  const immutableDocumentCount = 17;
  const programPointerCount = 3;
  const budget = calculatePublicationBudget({
    immutableDocumentCount,
    programPointerCount,
    canonicalDocumentBytes: 1024,
  });

  assert.deepEqual(budget, {
    immutableDocumentCount,
    versionHeadCount: immutableDocumentCount,
    programPointerCount,
    canonicalDocumentBytes: 1024,
    documentWrites: 2 * immutableDocumentCount + programPointerCount + 3,
    timestampTransforms: 2 * immutableDocumentCount + programPointerCount + 3,
    calculatedUnits: 4 * immutableDocumentCount + 2 * programPointerCount + 6,
  });
  assert.doesNotThrow(() => assertPublicationBudgetWithinLimit(budget));
});

test("raw calculated Firestore units pass at 450 and fail at 451", () => {
  const atLimit = calculatePublicationBudget({
    immutableDocumentCount: 0,
    versionHeadCount: 0,
    programPointerCount: 0,
    canonicalDocumentBytes: 0,
    documentWrites: 225,
    timestampTransforms: 225,
  });
  assert.equal(atLimit.calculatedUnits, 450);
  assert.doesNotThrow(() => assertPublicationBudgetWithinLimit(atLimit));

  const aboveLimit = calculatePublicationBudget({
    immutableDocumentCount: 0,
    versionHeadCount: 0,
    programPointerCount: 0,
    canonicalDocumentBytes: 0,
    documentWrites: 226,
    timestampTransforms: 225,
  });
  assert.equal(aboveLimit.calculatedUnits, 451);
  assert.throws(
    () => assertPublicationBudgetWithinLimit(aboveLimit),
    (error) => {
      assert.ok(error instanceof CurriculumValidationError);
      assert.ok(
        error.issues.some(
          (issue) =>
            issue.code === "TRANSACTION_BUDGET_EXCEEDED" &&
            issue.path === "/budget/calculatedUnits",
        ),
      );
      return true;
    },
  );
});

test("immutable document-count and canonical-byte budgets are independent", () => {
  const tooManyDocuments = calculatePublicationBudget({
    immutableDocumentCount: 181,
    programPointerCount: 1,
    canonicalDocumentBytes: 1,
  });
  assert.throws(
    () => assertPublicationBudgetWithinLimit(tooManyDocuments),
    (error) =>
      error instanceof CurriculumValidationError &&
      error.issues.some(
        (issue) =>
          issue.code === "IMMUTABLE_DOCUMENT_LIMIT_EXCEEDED" &&
          issue.path === "/budget/immutableDocumentCount",
      ),
  );

  const tooManyBytes = calculatePublicationBudget({
    immutableDocumentCount: 1,
    programPointerCount: 1,
    canonicalDocumentBytes: 8 * 1024 * 1024 + 1,
  });
  assert.throws(
    () => assertPublicationBudgetWithinLimit(tooManyBytes),
    (error) =>
      error instanceof CurriculumValidationError &&
      error.issues.some(
        (issue) =>
          issue.code === "PUBLICATION_BYTES_LIMIT_EXCEEDED" &&
          issue.path === "/budget/canonicalDocumentBytes",
      ),
  );
});

test("canonical string validation rejects non-NFC, lone-surrogate, control, and scalar overflow", async (t) => {
  await t.test("decomposed Unicode is not normalized silently", () => {
    assertInvalid(
      (draft) => {
        draft.lessonVersions[0].title = "Cafe\u0301";
      },
      {
        codes: "CANONICALIZATION_INVALID",
        path: "/lessonVersions/0/title",
      },
    );
  });

  await t.test("unpaired UTF-16 surrogate fails closed", () => {
    assertInvalid(
      (draft) => {
        draft.lessonVersions[0].title = "\ud800";
      },
      {
        codes: "CANONICALIZATION_INVALID",
        path: "/lessonVersions/0/title",
      },
    );
  });

  await t.test("forbidden ASCII control is rejected", () => {
    assertInvalid(
      (draft) => {
        draft.lessonVersions[0].title = "synthetic\u0001title";
      },
      {
        codes: ["CANONICALIZATION_INVALID", "SCHEMA_INVALID"],
        path: "/lessonVersions/0/title",
      },
    );
  });

  await t.test("Unicode limits count scalars rather than UTF-16 code units", () => {
    const atLimit = cloneFixture();
    atLimit.lessonVersions[0].title = "😀".repeat(120);
    assert.equal(validate(atLimit).ok, true);
    assertInvalid(
      (draft) => {
        draft.lessonVersions[0].title = "😀".repeat(121);
      },
      {
        codes: "SCHEMA_INVALID",
        path: "/lessonVersions/0/title",
      },
    );
  });
});

test("credential-shaped curriculum strings fail pure validation", () => {
  const accessKey = ["AKIA", "ABCDEFGHIJKLMNOP"].join("");
  assertInvalid(
    (draft) => {
      draft.lessonVersions[0].blocks[0].body = accessKey;
    },
    {
      codes: "PRIVATE_DATA_FORBIDDEN",
      path: "/lessonVersions/0/blocks/0/body",
    },
  );

  const secretValue = "Ab1/".repeat(10);
  assertInvalid(
    (draft) => {
      draft.lessonVersions[0].blocks[0].body =
        `AWS_SECRET_ACCESS_KEY=${secretValue}`;
    },
    {
      codes: "PRIVATE_DATA_FORBIDDEN",
      path: "/lessonVersions/0/blocks/0/body",
    },
  );
});

test("synthetic source classification survives copying and permits only the exact emulator tuple", () => {
  assert.equal(SYNTHETIC_FIXTURE_SENTINEL, fixture.programVersions[0].title);
  assert.equal(isSyntheticCurriculumSource(fixture, { sourcePath: fixturePath }), true);
  assert.throws(
    () =>
      assertPublicationSourceAllowed(fixture, {
        sourcePath: "/tmp/copied-curriculum.json",
        environment: "staging",
        projectID: "syntholo-staging",
        credentialPrincipal: "publisher@example.invalid",
        firestoreEmulatorHost: "127.0.0.1:8080",
      }),
    (error) =>
      error instanceof CurriculumValidationError &&
      error.issues.some((item) => item.code === "SYNTHETIC_SOURCE_FORBIDDEN"),
  );
  assert.throws(
    () =>
      assertPublicationSourceAllowed(fixture, {
        sourcePath: fixturePath,
        environment: "emulator",
        projectID: "syntholo-local",
        credentialPrincipal: "emulator-local",
        firestoreEmulatorHost: "",
      }),
    CurriculumValidationError,
  );
  assert.doesNotThrow(() =>
    assertPublicationSourceAllowed(fixture, {
      sourcePath: fixturePath,
      environment: "emulator",
      projectID: "syntholo-local",
      credentialPrincipal: "emulator-local",
      firestoreEmulatorHost: "127.0.0.1:8080",
    }),
  );
});

test("validation CLI uses fatal UTF-8 and duplicate-key parsing while printing safe summaries", async (t) => {
  const temporaryDirectory = await mkdtemp(
    path.join(os.tmpdir(), "syntholo-content-cli-tests."),
  );
  t.after(() => rm(temporaryDirectory, { recursive: true, force: true }));
  const cliPath = path.join(repositoryRoot, "tools/content/validate.mjs");

  await t.test("valid source prints only safe identifiers, counts, and digests", () => {
    const result = spawnSync(process.execPath, [cliPath, fixturePath], {
      cwd: repositoryRoot,
      encoding: "utf8",
    });
    assert.equal(result.status, 0, result.stderr);
    const output = JSON.parse(result.stdout);
    assert.equal(output.ok, true);
    assert.equal(output.synthetic, true);
    assert.equal(output.catalogVersionID, "catalog--en-us--v1");
    assert.doesNotMatch(result.stdout, /correctOptionID|correctFeedback|incorrectFeedback|Which synthetic option/u);
  });

  await t.test("duplicate object key is rejected before JSON.parse can erase it", async () => {
    const duplicatePath = path.join(temporaryDirectory, "duplicate.json");
    const privateKeyName = "private-token-must-not-reach-cli-output";
    await writeFile(
      duplicatePath,
      `{${JSON.stringify(privateKeyName)}:1,${JSON.stringify(privateKeyName)}:1}`,
      "utf8",
    );
    const result = spawnSync(process.execPath, [cliPath, duplicatePath], {
      cwd: repositoryRoot,
      encoding: "utf8",
    });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /DUPLICATE_OBJECT_KEY/u);
    assert.doesNotMatch(result.stderr, new RegExp(privateKeyName, "u"));
  });

  await t.test("unknown property names are redacted from validation output", async () => {
    const unknownPropertyPath = path.join(temporaryDirectory, "unknown-property.json");
    const privateKeyName = "private-token-must-not-reach-cli-output";
    const draft = cloneFixture();
    draft[privateKeyName] = true;
    await writeFile(unknownPropertyPath, JSON.stringify(draft), "utf8");
    const result = spawnSync(process.execPath, [cliPath, unknownPropertyPath], {
      cwd: repositoryRoot,
      encoding: "utf8",
    });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /<unknown-property>/u);
    assert.doesNotMatch(result.stderr, new RegExp(privateKeyName, "u"));
  });

  await t.test("invalid UTF-8 is rejected before validation", async () => {
    const invalidPath = path.join(temporaryDirectory, "invalid-utf8.json");
    await writeFile(invalidPath, Buffer.from([0xc3, 0x28]));
    const result = spawnSync(process.execPath, [cliPath, invalidPath], {
      cwd: repositoryRoot,
      encoding: "utf8",
    });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /SOURCE_READ_INVALID/u);
  });
});

test("schema-invalid nested types return structured issues instead of throwing", async (t) => {
  const cases = [
    ["null program entry", (draft) => { draft.programVersions[0] = null; }],
    [
      "non-array completion references",
      (draft) => { draft.lessonVersions[0].completionRule.requiredBlockIDs = "synthetic-question"; },
    ],
    [
      "non-array question options",
      (draft) => { questionBlock(draft.lessonVersions[0]).options = {}; },
    ],
    [
      "null diagram connector",
      (draft) => { draft.assetVersions[0].payload.connectors = [null]; },
    ],
    [
      "non-string accessibility description",
      (draft) => { draft.assetVersions[0].accessibilityDescription = {}; },
    ],
  ];

  for (const [name, mutate] of cases) {
    await t.test(name, () => {
      const draft = cloneFixture();
      mutate(draft);
      let result;
      assert.doesNotThrow(() => {
        result = validate(draft);
      });
      assertStructuredIssues(result);
      assert.ok(result.issues.some((item) => item.code === "SCHEMA_INVALID"));
    });
  }
});

test("normative pre-server schemas freeze every generated Firestore key and private shape", () => {
  const publication = buildPublicationShape(fixture);
  const definitionByCollection = {
    assetVersions: "assetVersionPublishedWrite",
    catalogVersions: "catalogVersionPublishedWrite",
    evaluationContractVersions: "evaluationContractVersionPublishedWrite",
    lessonVersions: "lessonVersionPublishedWrite",
    modules: "moduleVersionPublishedWrite",
    programVersions: "programVersionPublishedWrite",
    rubricVersions: "rubricVersionPublishedWrite",
  };

  const assertExactDefinition = (definitionName, value, label) => {
    const definition = curriculumSchema.$defs[definitionName];
    assert.ok(definition, `Missing ${definitionName}`);
    assert.match(definition.$comment ?? "", /Firestore Timestamp/u);
    assert.deepEqual(
      Object.keys(value).sort(),
      [...definition.required].sort(),
      `${label} key drift`,
    );
    assertSchemaValid(`/$defs/${definitionName}`, value, label);
    assertSchemaInvalid(
      `/$defs/${definitionName}`,
      { ...value, unexpectedGeneratedField: true },
      `${label} unknown key`,
    );
    const missing = structuredClone(value);
    delete missing[definition.required[0]];
    assertSchemaInvalid(
      `/$defs/${definitionName}`,
      missing,
      `${label} missing key`,
    );
  };

  for (const document of publication.immutableDocuments) {
    const [collection] = document.path.split("/");
    assertExactDefinition(
      definitionByCollection[collection],
      document.data,
      document.path,
    );
  }
  assertExactDefinition(
    "catalogPointerWrite",
    publication.derivedPointers.catalog.data,
    publication.derivedPointers.catalog.path,
  );
  for (const pointer of publication.derivedPointers.programs) {
    assertExactDefinition("programPointerWrite", pointer.data, pointer.path);
  }
  assertExactDefinition(
    "featureConfigurationWrite",
    publication.derivedConfiguration.data,
    publication.derivedConfiguration.path,
  );

  assertExactDefinition(
    "contentVersionHeadWrite",
    {
      versionHeadID: "lesson--synthetic-lesson--en-us",
      kind: "lesson",
      stableID: "synthetic-lesson",
      locale: "en-US",
      maxPublishedVersion: 1,
      schemaVersion: 1,
    },
    "contentVersionHeads/lesson--synthetic-lesson--en-us",
  );
  assertExactDefinition(
    "contentPublicationAuditWrite",
    {
      schemaVersion: 1,
      operationID: "00000000-0000-4000-8000-000000000000",
      requestDigest: "0".repeat(64),
      action: "publish",
      outcome: "applied",
      environment: "emulator",
      projectID: "syntholo-local",
      projectNumber: "emulator",
      credentialPrincipal: "emulator-local",
      requestedBy: null,
      catalogPointerID: "en-us",
      fromCatalogVersionID: null,
      toCatalogVersionID: fixture.catalogVersion.catalogVersionID,
      programSelections: [
        {
          programPointerID:
            fixture.catalogVersion.programEntries[0].programPointerID,
          fromProgramVersionID: null,
          toProgramVersionID:
            fixture.catalogVersion.programEntries[0].programVersionID,
        },
      ],
      publicationDigest: publication.publicationDigest,
    },
    "contentPublicationAudit/synthetic-operation",
  );
});

test("synthetic fixture paths require the exact sentinel in a learner-visible title", () => {
  const draft = cloneFixture();
  draft.programVersions[0].title = "Synthetic fixture without its reserved title";
  draft.programVersions[0].promise = SYNTHETIC_FIXTURE_SENTINEL;

  const result = validate(draft);
  assertStructuredIssues(result);
  assert.ok(
    result.issues.some(
      (item) =>
        item.code === "SYNTHETIC_SENTINEL_REQUIRED" &&
        item.path === "/programVersions",
    ),
    JSON.stringify(result.issues),
  );
});

test("the Phase 2 catalog allows coming-soon shells but only Foundations may be available", () => {
  const withShell = cloneFixture();
  addComingSoonProgram(withShell);
  const shellResult = validate(withShell);
  assert.equal(shellResult.ok, true, JSON.stringify(shellResult.issues));

  const withSecondAvailable = cloneFixture();
  addSecondAvailableProgram(withSecondAvailable);
  const invalidResult = validate(withSecondAvailable);
  assertStructuredIssues(invalidResult);
  assert.ok(
    invalidResult.issues.some(
      (item) =>
        item.code === "FOUNDATIONS_CATALOG_INVALID" &&
        item.path === "/catalogVersion/programEntries",
    ),
    JSON.stringify(invalidResult.issues),
  );
});

test("Section 4.1 string, URL, stable-ID, and version boundaries are inclusive", () => {
  const concept = (draft) =>
    draft.lessonVersions[0].blocks.find((block) => block.type === "conceptText");
  const question = (draft) => questionBlock(draft.lessonVersions[0]);
  const stringCases = [
    ["title", 120, (draft, value) => { draft.moduleVersions[0].title = value; }],
    ["promise", 500, (draft, value) => { draft.programVersions[0].promise = value; }],
    ["summary", 500, (draft, value) => { draft.moduleVersions[0].summary = value; }],
    ["objective", 500, (draft, value) => { draft.lessonVersions[0].objective = value; }],
    ["concept body", 4000, (draft, value) => { concept(draft).body = value; }],
    ["question prompt", 1000, (draft, value) => { question(draft).prompt = value; }],
    ["option text", 300, (draft, value) => { question(draft).options[0].text = value; }],
    ["feedback", 1000, (draft, value) => {
      draft.rubricVersions[0].clientScoringContract.correctFeedback = value;
    }],
    ["criterion description", 1000, (draft, value) => {
      draft.rubricVersions[0].criteria[0].description = value;
    }],
    ["diagram node label", 120, (draft, value) => {
      draft.assetVersions[0].payload.nodes[0].label = value;
    }],
    ["connector label", 120, (draft, value) => {
      draft.assetVersions[0].payload.connectors[0].label = value;
    }],
    ["accessibility description", 1000, (draft, value) => {
      draft.assetVersions[0].accessibilityDescription = value;
    }],
    ["creator", 120, (draft, value) => {
      draft.assetVersions[0].rights.creator = value;
    }],
    ["license", 120, (draft, value) => {
      Object.assign(draft.assetVersions[0].rights, {
        origin: "licensed",
        sourceURL: "https://example.com/synthetic",
        license: value,
      });
    }],
  ];

  for (const [name, maximum, setValue] of stringCases) {
    const atMaximum = cloneFixture();
    setValue(atMaximum, "x".repeat(maximum));
    assert.equal(validate(atMaximum).ok, true, `${name} rejected its maximum`);

    const empty = cloneFixture();
    setValue(empty, "");
    assert.equal(validate(empty).ok, false, `${name} accepted an empty string`);

    const aboveMaximum = cloneFixture();
    setValue(aboveMaximum, "x".repeat(maximum + 1));
    assert.equal(
      validate(aboveMaximum).ok,
      false,
      `${name} accepted maximum + 1`,
    );
  }

  const optionalHeading = cloneFixture();
  delete concept(optionalHeading).heading;
  assert.equal(validate(optionalHeading).ok, true);
  concept(optionalHeading).heading = null;
  assert.equal(validate(optionalHeading).ok, false);

  const missingNullableConnectorLabel = cloneFixture();
  delete missingNullableConnectorLabel.assetVersions[0].payload.connectors[0].label;
  assert.equal(validate(missingNullableConnectorLabel).ok, false);

  const urlPrefix = "https://example.com/";
  const validURL = cloneFixture();
  Object.assign(validURL.assetVersions[0].rights, {
    origin: "licensed",
    sourceURL: urlPrefix + "a".repeat(2048 - urlPrefix.length),
    license: "Synthetic license",
  });
  assert.equal(validate(validURL).ok, true);
  validURL.assetVersions[0].rights.sourceURL += "a";
  assert.equal(validate(validURL).ok, false);
  validURL.assetVersions[0].rights.sourceURL = "http://example.com/source";
  assert.equal(validate(validURL).ok, false);

  for (const [length, expected] of [[3, true], [64, true], [2, false], [65, false]]) {
    const draft = cloneFixture();
    draft.rubricVersions[0].criteria[0].criterionID = "a".repeat(length);
    assert.equal(validate(draft).ok, expected, `stable ID length ${length}`);
  }

  const maximumVersion = cloneFixture();
  maximumVersion.catalogVersion.version = 2147483647;
  maximumVersion.catalogVersion.catalogVersionID =
    "catalog--en-us--v2147483647";
  assert.equal(validate(maximumVersion).ok, true);
  maximumVersion.catalogVersion.version = 2147483648;
  maximumVersion.catalogVersion.catalogVersionID =
    "catalog--en-us--v2147483648";
  assert.equal(validate(maximumVersion).ok, false);

  for (const [minutes, expected] of [[1, true], [180, true], [0, false], [181, false]]) {
    const draft = cloneFixture();
    draft.lessonVersions[0].expectedDurationMinutes = minutes;
    assert.equal(validate(draft).ok, expected, `duration ${minutes}`);
  }
  for (const [score, expected] of [[1, true], [100, true], [0, false], [101, false]]) {
    const draft = cloneFixture();
    draft.rubricVersions[0].criteria[0].maxScore = score;
    assert.equal(validate(draft).ok, expected, `criterion score ${score}`);
  }
  for (const minimumCorrectCount of [0, 2]) {
    const draft = cloneFixture();
    draft.lessonVersions[0].completionRule.minimumCorrectCount =
      minimumCorrectCount;
    assert.equal(
      validate(draft).ok,
      false,
      `completion minimum ${minimumCorrectCount}`,
    );
  }

  const versionIDSuffix = "--en-us--v1";
  const maximumVersionID = "a".repeat(114 - versionIDSuffix.length) + versionIDSuffix;
  assert.equal(maximumVersionID.length, 114);
  assertSchemaValid("/$defs/versionID", maximumVersionID);
  assertSchemaInvalid("/$defs/versionID", `a${maximumVersionID}`);

  const validDigest = "a".repeat(64);
  assertSchemaValid("/$defs/sha256Digest", validDigest);
  assertSchemaInvalid("/$defs/sha256Digest", validDigest.slice(1));
  assertSchemaInvalid("/$defs/sha256Digest", validDigest.toUpperCase());
});

test("Section 4.1 array bounds and conditional branches are exact", () => {
  const programFactory = (index) => {
    const value = structuredClone(fixture.programVersions[0]);
    value.programID = `synthetic-program-${index}`;
    value.programVersionID = `${value.programID}--en-us--v1`;
    value.title = `Synthetic program ${index}`;
    return value;
  };
  const moduleFactory = (index) => {
    const value = structuredClone(fixture.moduleVersions[0]);
    value.moduleID = `synthetic-module-${index}`;
    value.moduleVersionID = `${value.moduleID}--en-us--v1`;
    return value;
  };
  const lessonFactory = (index) => {
    const value = structuredClone(fixture.lessonVersions[0]);
    value.lessonID = `synthetic-lesson-${index}`;
    value.lessonVersionID = `${value.lessonID}--en-us--v1`;
    return value;
  };
  const rubricFactory = (index) => {
    const value = structuredClone(fixture.rubricVersions[0]);
    value.rubricID = `synthetic-rubric-${index}`;
    value.rubricVersionID = `${value.rubricID}--en-us--v1`;
    return value;
  };
  const evaluationFactory = (index) => {
    const value = structuredClone(fixture.evaluationContractVersions[0]);
    value.evaluationContractID = `synthetic-evaluation-${index}`;
    value.evaluationContractVersionID =
      `${value.evaluationContractID}--en-us--v1`;
    return value;
  };
  const assetFactory = (index) => {
    const value = structuredClone(fixture.assetVersions[0]);
    value.assetID = `synthetic-asset-${index}`;
    value.assetVersionID = `${value.assetID}--en-us--v1`;
    return value;
  };
  const reference = (index) => `synthetic-reference-${index}--en-us--v1`;
  const stable = (index) => `synthetic-id-${index}`;

  const cases = [
    ["/properties/programVersions", 1, 5, programFactory],
    ["/properties/moduleVersions", 0, 48, moduleFactory],
    ["/properties/lessonVersions", 0, 128, lessonFactory],
    ["/properties/rubricVersions", 0, 128, rubricFactory],
    ["/properties/evaluationContractVersions", 0, 128, evaluationFactory],
    ["/properties/assetVersions", 0, 128, assetFactory],
    ["/$defs/catalogVersionDraft/properties/programEntries", 1, 5, (index) => ({
      programPointerID: `synthetic-program-${index}--en-us`,
      programVersionID: `synthetic-program-${index}--en-us--v1`,
    })],
    ["/$defs/programVersionDraft/properties/moduleVersionIDs", 0, 24, reference],
    ["/$defs/moduleVersionDraft/properties/lessonVersionIDs", 1, 64, reference],
    ["/$defs/lessonVersionDraft/properties/prerequisiteLessonIDs", 0, 16, stable],
    ["/$defs/lessonVersionDraft/properties/assetVersionIDs", 0, 128, reference],
    ["/$defs/completionRule/properties/requiredBlockIDs", 1, 20, stable],
    ["/$defs/singleAnswerQuestionBlock/properties/options", 2, 8, (index) => ({
      optionID: `synthetic-option-${index}`,
      text: `Synthetic option ${index}`,
    })],
    ["/$defs/rubricVersionDraft/properties/criteria", 1, 12, (index) => ({
      criterionID: `synthetic-criterion-${index}`,
      title: `Synthetic criterion ${index}`,
      description: `Synthetic criterion description ${index}`,
      maxScore: 1,
    })],
    ["/$defs/diagramAssetPayload/properties/nodes", 1, 12, (index) => ({
      nodeID: `synthetic-node-${index}`,
      label: `Synthetic node ${index}`,
      emphasis: "normal",
    })],
    ["/$defs/diagramAssetPayload/properties/connectors", 0, 24, (index) => ({
      connectorID: `synthetic-connector-${index}`,
      fromNodeID: "synthetic-node-a",
      toNodeID: "synthetic-node-b",
      label: null,
    })],
  ];

  for (const [jsonPointer, minimum, maximum, factory] of cases) {
    const values = (count) =>
      Array.from({ length: count }, (_, index) => factory(index));
    assertSchemaValid(jsonPointer, values(minimum), `${jsonPointer} minimum`);
    assertSchemaValid(jsonPointer, values(maximum), `${jsonPointer} maximum`);
    if (minimum > 0) {
      assertSchemaInvalid(
        jsonPointer,
        values(minimum - 1),
        `${jsonPointer} below minimum`,
      );
    }
    assertSchemaInvalid(
      jsonPointer,
      values(maximum + 1),
      `${jsonPointer} above maximum`,
    );
    if (maximum >= 2) {
      const duplicate = factory(0);
      assertSchemaInvalid(
        jsonPointer,
        [duplicate, structuredClone(duplicate)],
        `${jsonPointer} duplicate`,
      );
    }
  }

  const blockArrayPointer = "/$defs/lessonVersionDraft/properties/blocks";
  const blocks = Array.from({ length: 40 }, (_, index) => ({
    blockID: `synthetic-block-${index}`,
    type: "conceptText",
    order: index,
    body: `Synthetic body ${index}`,
  }));
  assertSchemaValid(blockArrayPointer, [blocks[0]], "blocks minimum");
  assertSchemaValid(blockArrayPointer, blocks, "blocks maximum");
  assertSchemaInvalid(blockArrayPointer, [], "blocks below minimum");
  assertSchemaInvalid(
    blockArrayPointer,
    [...blocks, { ...blocks[0], blockID: "synthetic-block-extra", order: 40 }],
    "blocks above maximum",
  );

  const available = structuredClone(fixture.programVersions[0]);
  assertSchemaValid("/$defs/programVersionDraft", available);
  available.moduleVersionIDs = [];
  available.firstLessonVersionID = null;
  assertSchemaInvalid("/$defs/programVersionDraft", available);

  const comingSoon = structuredClone(fixture.programVersions[0]);
  comingSoon.catalogState = "comingSoon";
  comingSoon.moduleVersionIDs = [];
  comingSoon.firstLessonVersionID = null;
  assertSchemaValid("/$defs/programVersionDraft", comingSoon);
  comingSoon.moduleVersionIDs = [fixture.moduleVersions[0].moduleVersionID];
  assertSchemaInvalid("/$defs/programVersionDraft", comingSoon);
});

test("validator enforces diagram, immutable-document, publication, and transaction budgets", () => {
  const oversizedDiagram = cloneFixture();
  oversizedDiagram.assetVersions[0].payload.nodes[0].label = "😀".repeat(40000);
  const diagramResult = validate(oversizedDiagram);
  assertStructuredIssues(diagramResult);
  assert.ok(
    diagramResult.issues.some(
      (item) =>
        item.code === "DOCUMENT_SIZE_EXCEEDED" &&
        item.path === "/assetVersions/0/payload",
    ),
    JSON.stringify(diagramResult.issues),
  );

  const oversizedDocument = cloneFixture();
  makeLargeLessonBlocks(oversizedDocument.lessonVersions[0]);
  const documentResult = validate(oversizedDocument);
  assertStructuredIssues(documentResult);
  assert.ok(
    documentResult.issues.some(
      (item) =>
        item.code === "DOCUMENT_SIZE_EXCEEDED" &&
        item.documentPath ===
          `lessonVersions/${oversizedDocument.lessonVersions[0].lessonVersionID}`,
    ),
    JSON.stringify(documentResult.issues),
  );

  const oversizedPublication = cloneFixture();
  makeLargeLessonBlocks(oversizedPublication.lessonVersions[0]);
  for (let index = 1; index < 14; index += 1) {
    const lesson = structuredClone(oversizedPublication.lessonVersions[0]);
    lesson.lessonID = `synthetic-large-lesson-${index}`;
    lesson.lessonVersionID = `${lesson.lessonID}--en-us--v1`;
    lesson.title = `Synthetic large lesson ${index}`;
    oversizedPublication.lessonVersions.push(lesson);
    oversizedPublication.moduleVersions[0].lessonVersionIDs.push(
      lesson.lessonVersionID,
    );
  }
  const publicationResult = validate(oversizedPublication);
  assertStructuredIssues(publicationResult);
  assert.ok(
    publicationResult.issues.some(
      (item) => item.code === "PUBLICATION_SIZE_EXCEEDED",
    ),
    JSON.stringify(publicationResult.issues),
  );

  const overTransactionBudget = cloneFixture();
  const secondModule = structuredClone(overTransactionBudget.moduleVersions[0]);
  secondModule.moduleID = "synthetic-budget-module-two";
  secondModule.moduleVersionID = "synthetic-budget-module-two--en-us--v1";
  secondModule.title = "Synthetic budget module two";
  secondModule.lessonVersionIDs = [];
  overTransactionBudget.moduleVersions.push(secondModule);
  overTransactionBudget.programVersions[0].moduleVersionIDs.push(
    secondModule.moduleVersionID,
  );
  for (let index = 1; index < 128; index += 1) {
    const lesson = structuredClone(overTransactionBudget.lessonVersions[0]);
    lesson.lessonID = `synthetic-budget-lesson-${index}`;
    lesson.lessonVersionID = `${lesson.lessonID}--en-us--v1`;
    lesson.title = `Synthetic budget lesson ${index}`;
    const targetModule = index <= 63
      ? overTransactionBudget.moduleVersions[0]
      : secondModule;
    lesson.moduleID = targetModule.moduleID;
    overTransactionBudget.lessonVersions.push(lesson);
    targetModule.lessonVersionIDs.push(lesson.lessonVersionID);
  }
  const transactionResult = validate(overTransactionBudget);
  assertStructuredIssues(transactionResult);
  assert.ok(
    transactionResult.issues.some(
      (item) => item.code === "TRANSACTION_BUDGET_EXCEEDED",
    ),
    JSON.stringify(transactionResult.issues),
  );
});
