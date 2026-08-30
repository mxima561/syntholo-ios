import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const REPOSITORY_ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);
export const FIXTURE_PATH = path.join(
  REPOSITORY_ROOT,
  "tests/fixtures/content/minimal-curriculum-v1.json",
);
export const PROJECT_ID = "syntholo-local";
export const CATALOG_POINTER_ID = "en-us";
export const PROGRAM_POINTER_ID = "ai-foundations--en-us";

export const OPERATOR_CONTEXT = Object.freeze({
  environment: "emulator",
  projectID: PROJECT_ID,
  projectNumber: "emulator",
  credentialPrincipal: "emulator-local",
  requestedBy: null,
  publicationMode: "emulator",
});

export const PUBLICATION_COLLECTIONS = Object.freeze([
  "assetVersions",
  "catalogVersions",
  "catalogs",
  "contentPublicationAudit",
  "contentVersionHeads",
  "evaluationContractVersions",
  "featureConfiguration",
  "lessonVersions",
  "modules",
  "programVersions",
  "programs",
  "rubricVersions",
]);

export const VERSION_HEADS = Object.freeze([
  {
    path: "contentVersionHeads/catalog--catalog--en-us",
    kind: "catalog",
    stableID: "catalog",
  },
  {
    path: "contentVersionHeads/program--ai-foundations--en-us",
    kind: "program",
    stableID: "ai-foundations",
  },
  {
    path: "contentVersionHeads/module--synthetic-module--en-us",
    kind: "module",
    stableID: "synthetic-module",
  },
  {
    path: "contentVersionHeads/lesson--synthetic-lesson--en-us",
    kind: "lesson",
    stableID: "synthetic-lesson",
  },
  {
    path: "contentVersionHeads/rubric--synthetic-rubric--en-us",
    kind: "rubric",
    stableID: "synthetic-rubric",
  },
  {
    path: "contentVersionHeads/evaluation-contract--synthetic-evaluation--en-us",
    kind: "evaluation-contract",
    stableID: "synthetic-evaluation",
  },
  {
    path: "contentVersionHeads/asset--synthetic-diagram--en-us",
    kind: "asset",
    stableID: "synthetic-diagram",
  },
]);

export async function loadMinimalDraft() {
  return JSON.parse(await readFile(FIXTURE_PATH, "utf8"));
}

export function cloneDraft(draft) {
  return structuredClone(draft);
}

export function fullyVersionedDraft(source, version) {
  if (!Number.isInteger(version) || version < 1) {
    throw new TypeError("Fixture version must be a positive integer.");
  }
  const draft = JSON.parse(
    JSON.stringify(source).replaceAll("--en-us--v1", `--en-us--v${version}`),
  );
  draft.catalogVersion.version = version;
  for (const collectionName of [
    "programVersions",
    "moduleVersions",
    "lessonVersions",
    "rubricVersions",
    "evaluationContractVersions",
    "assetVersions",
  ]) {
    for (const document of draft[collectionName]) document.version = version;
  }
  draft.programVersions[0].promise =
    `Synthetic placeholder program contract version ${version}.`;
  return draft;
}

export function catalogOnlyVersionedDraft(source, version) {
  if (!Number.isInteger(version) || version < 1) {
    throw new TypeError("Catalog fixture version must be a positive integer.");
  }
  const draft = cloneDraft(source);
  draft.catalogVersion.catalogVersionID = `catalog--en-us--v${version}`;
  draft.catalogVersion.version = version;
  return draft;
}

export function overBudgetDraft(source, lessonCount = 27) {
  if (!Number.isInteger(lessonCount) || lessonCount < 2 || lessonCount > 64) {
    throw new TypeError("Synthetic lesson count must be between 2 and 64.");
  }
  const draft = cloneDraft(source);
  const sourceLesson = draft.lessonVersions[0];
  const sourceRubric = draft.rubricVersions[0];
  const sourceEvaluation = draft.evaluationContractVersions[0];
  const sourceAsset = draft.assetVersions[0];

  for (let index = 2; index <= lessonCount; index += 1) {
    const token = String(index).padStart(2, "0");
    const lessonID = `synthetic-lesson-${token}`;
    const rubricID = `synthetic-rubric-${token}`;
    const evaluationID = `synthetic-evaluation-${token}`;
    const assetID = `synthetic-diagram-${token}`;
    const lessonVersionID = `${lessonID}--en-us--v1`;
    const rubricVersionID = `${rubricID}--en-us--v1`;
    const evaluationVersionID = `${evaluationID}--en-us--v1`;
    const assetVersionID = `${assetID}--en-us--v1`;

    const lesson = cloneDraft(sourceLesson);
    lesson.lessonID = lessonID;
    lesson.lessonVersionID = lessonVersionID;
    lesson.title = `Synthetic contract lesson ${token}`;
    lesson.rubricVersionID = rubricVersionID;
    lesson.assetVersionIDs = [assetVersionID];
    lesson.blocks.find((block) => block.type === "stillDiagram").assetVersionID =
      assetVersionID;

    const rubric = cloneDraft(sourceRubric);
    rubric.rubricID = rubricID;
    rubric.rubricVersionID = rubricVersionID;
    rubric.evaluationContractVersionID = evaluationVersionID;

    const evaluation = cloneDraft(sourceEvaluation);
    evaluation.evaluationContractID = evaluationID;
    evaluation.evaluationContractVersionID = evaluationVersionID;
    evaluation.rubricVersionID = rubricVersionID;

    const asset = cloneDraft(sourceAsset);
    asset.assetID = assetID;
    asset.assetVersionID = assetVersionID;
    asset.accessibilityDescription =
      `Synthetic diagram ${token} with placeholder input and output.`;

    draft.lessonVersions.push(lesson);
    draft.rubricVersions.push(rubric);
    draft.evaluationContractVersions.push(evaluation);
    draft.assetVersions.push(asset);
    draft.moduleVersions[0].lessonVersionIDs.push(lessonVersionID);
  }

  return draft;
}

let operationSequence = 0;

export function nextOperationID() {
  operationSequence += 1;
  return `00000000-0000-4000-8000-${String(operationSequence).padStart(12, "0")}`;
}
