import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

import { canonicalBytes } from "./canonical-json.mjs";
import {
  CURRICULUM_LIMITS,
  PublicationBudgetError,
  assertPublicationBudgetWithinLimit as assertRawPublicationBudgetWithinLimit,
  buildPublicationShape,
  calculatePublicationBudget,
} from "./firestore-shape.mjs";

export {
  CURRICULUM_LIMITS,
  calculatePublicationBudget,
};

export const SYNTHETIC_FIXTURE_SENTINEL =
  "SYNTHETIC-CONTRACT-FIXTURE-NEVER-PUBLISH";

const STABLE_ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const FORBIDDEN_CREDENTIAL_PATTERNS = [
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
  /AIza[0-9A-Za-z_-]{35}/,
  /\bsk-[A-Za-z0-9_-]{20,}\b/,
  /\bgh[pousr]_[A-Za-z0-9]{20,}\b/,
  /\bgithub_pat_[A-Za-z0-9_]{20,}\b/,
  /\b(?:AKIA|ASIA)[A-Z0-9]{16}\b/,
  /\bAWS_SECRET_ACCESS_KEY\b["']?\s*[:=]\s*["']?[A-Za-z0-9/+=]{40,}/i,
  /\bAWS_SESSION_TOKEN\b["']?\s*[:=]\s*["']?[A-Za-z0-9/+=]{16,}/i,
  /\bxox[baprs]-[0-9A-Za-z-]{10,}\b/,
];
const SAFE_FORBIDDEN_SOURCE_PROPERTIES = new Set([
  "byteCount",
  "contentDigest",
  "occurredAt",
  "payloadDigest",
  "publishedAt",
  "updatedAt",
]);
const REPOSITORY_ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../..",
);
const SYNTHETIC_FIXTURE_ROOT = path.join(
  REPOSITORY_ROOT,
  "tests",
  "fixtures",
  "content",
);
const SCHEMA_PATH = path.join(
  REPOSITORY_ROOT,
  "content",
  "schema",
  "curriculum-v1.schema.json",
);

const schema = JSON.parse(fs.readFileSync(SCHEMA_PATH, "utf8"));
const ajv = new Ajv2020({
  allErrors: true,
  strict: true,
  validateFormats: true,
});
addFormats(ajv);
const validateSchema = ajv.compile(schema);

export class CurriculumValidationError extends Error {
  constructor(issues, message = "Curriculum validation failed.") {
    super(message);
    this.name = "CurriculumValidationError";
    this.issues = issues;
  }
}

export function assertPublicationBudgetWithinLimit(budget) {
  try {
    return assertRawPublicationBudgetWithinLimit(budget);
  } catch (error) {
    if (!(error instanceof PublicationBudgetError)) throw error;
    const mapping = {
      IMMUTABLE_DOCUMENT_LIMIT_EXCEEDED: {
        code: "IMMUTABLE_DOCUMENT_LIMIT_EXCEEDED",
        path: "/budget/immutableDocumentCount",
      },
      PUBLICATION_SIZE_EXCEEDED: {
        code: "PUBLICATION_BYTES_LIMIT_EXCEEDED",
        path: "/budget/canonicalDocumentBytes",
      },
      TRANSACTION_BUDGET_EXCEEDED: {
        code: "TRANSACTION_BUDGET_EXCEEDED",
        path: "/budget/calculatedUnits",
      },
    };
    const mapped = mapping[error.code];
    throw new CurriculumValidationError([
      issue(mapped.code, mapped.path, error.message),
    ]);
  }
}

function pointerToken(value) {
  return String(value).replaceAll("~", "~0").replaceAll("/", "~1");
}

function at(base, token) {
  return `${base}/${pointerToken(token)}`;
}

function issue(code, instancePath, message, documentPath = null) {
  return {
    code,
    path: instancePath || "",
    instancePath: instancePath || "",
    documentPath,
    message,
  };
}

function addIssue(issues, code, instancePath, message, documentPath = null) {
  issues.push(issue(code, instancePath, message, documentPath));
}

function sortIssues(issues) {
  return issues.sort(
    (left, right) =>
      left.code.localeCompare(right.code) ||
      left.path.localeCompare(right.path) ||
      (left.documentPath ?? "").localeCompare(right.documentPath ?? ""),
  );
}

function walk(value, instancePath, visitor) {
  visitor(value, instancePath);
  if (Array.isArray(value)) {
    value.forEach((child, index) => walk(child, at(instancePath, index), visitor));
  } else if (value !== null && typeof value === "object") {
    for (const [key, child] of Object.entries(value)) {
      walk(child, at(instancePath, key), visitor);
    }
  }
}

function containsLoneSurrogate(value) {
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index);
    if (code >= 0xd800 && code <= 0xdbff) {
      const next = value.charCodeAt(index + 1);
      if (!(next >= 0xdc00 && next <= 0xdfff)) return true;
      index += 1;
    } else if (code >= 0xdc00 && code <= 0xdfff) {
      return true;
    }
  }
  return false;
}

function validateStrings(draft, issues) {
  walk(draft, "", (value, instancePath) => {
    if (typeof value !== "string") return;
    if (containsLoneSurrogate(value)) {
      addIssue(
        issues,
        "CANONICALIZATION_INVALID",
        instancePath,
        "String contains an unpaired UTF-16 surrogate.",
      );
    }
    if (value !== value.normalize("NFC")) {
      addIssue(
        issues,
        "CANONICALIZATION_INVALID",
        instancePath,
        "String must already be NFC-normalized.",
      );
    }
    if (/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/u.test(value)) {
      addIssue(
        issues,
        "CANONICALIZATION_INVALID",
        instancePath,
        "String contains a disallowed ASCII control character.",
      );
    }
    if (FORBIDDEN_CREDENTIAL_PATTERNS.some((pattern) => pattern.test(value))) {
      addIssue(
        issues,
        "PRIVATE_DATA_FORBIDDEN",
        instancePath,
        "Credential-shaped content is forbidden.",
      );
    }
  });
}

function addSchemaIssues(issues) {
  for (const error of validateSchema.errors ?? []) {
    let instancePath = error.instancePath ?? "";
    if (error.keyword === "required" && error.params?.missingProperty) {
      instancePath = at(instancePath, error.params.missingProperty);
    } else if (error.keyword === "additionalProperties" && error.params?.additionalProperty) {
      const property = error.params.additionalProperty;
      instancePath = at(
        instancePath,
        SAFE_FORBIDDEN_SOURCE_PROPERTIES.has(property)
          ? property
          : "<unknown-property>",
      );
    }
    addIssue(issues, "SCHEMA_INVALID", instancePath, "Value violates curriculum schema v1.");
  }
}

function checkDraftState(document, instancePath, issues) {
  if (document?.publicationState !== "draft") {
    addIssue(
      issues,
      "PUBLICATION_STATE_INVALID",
      at(instancePath, "publicationState"),
      "Authoring documents must be drafts.",
    );
  }
}

function uniqueBy(values, selector, instancePath, issues, identityKey = null) {
  if (!Array.isArray(values)) return;
  const seen = new Set();
  values.forEach((value, index) => {
    const identity = selector(value);
    if (identity === undefined || identity === null) return;
    if (seen.has(identity)) {
      addIssue(
        issues,
        "DUPLICATE_VALUE",
        identityKey ? `${at(instancePath, index)}/${pointerToken(identityKey)}` : at(instancePath, index),
        "Array identities must be unique.",
      );
    }
    seen.add(identity);
  });
}

function mapBy(values, key) {
  return new Map(
    (Array.isArray(values) ? values : [])
      .filter((value) => value && typeof value[key] === "string")
      .map((value) => [value[key], value]),
  );
}

function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isGraphShapeSafe(draft) {
  if (
    !isRecord(draft.catalogVersion) ||
    !Array.isArray(draft.catalogVersion.programEntries) ||
    !Array.isArray(draft.programVersions) ||
    !Array.isArray(draft.moduleVersions) ||
    !Array.isArray(draft.lessonVersions) ||
    !Array.isArray(draft.rubricVersions) ||
    !Array.isArray(draft.evaluationContractVersions) ||
    !Array.isArray(draft.assetVersions)
  ) {
    return false;
  }
  return (
    draft.catalogVersion.programEntries.every(isRecord) &&
    draft.programVersions.every(
      (program) => isRecord(program) && Array.isArray(program.moduleVersionIDs),
    ) &&
    draft.moduleVersions.every(
      (module) => isRecord(module) && Array.isArray(module.lessonVersionIDs),
    ) &&
    draft.lessonVersions.every(
      (lesson) =>
        isRecord(lesson) &&
        Array.isArray(lesson.prerequisiteLessonIDs) &&
        isRecord(lesson.completionRule) &&
        Array.isArray(lesson.completionRule.requiredBlockIDs) &&
        Array.isArray(lesson.blocks) &&
        lesson.blocks.every(
          (block) =>
            isRecord(block) &&
            (block.type !== "singleAnswerQuestion" || Array.isArray(block.options)),
        ) &&
        Array.isArray(lesson.assetVersionIDs),
    ) &&
    draft.rubricVersions.every(
      (rubric) =>
        isRecord(rubric) &&
        Array.isArray(rubric.criteria) &&
        isRecord(rubric.clientScoringContract),
    ) &&
    draft.evaluationContractVersions.every(isRecord) &&
    draft.assetVersions.every(
      (asset) =>
        isRecord(asset) &&
        typeof asset.accessibilityDescription === "string" &&
        isRecord(asset.payload) &&
        Array.isArray(asset.payload.nodes) &&
        asset.payload.nodes.every(isRecord) &&
        Array.isArray(asset.payload.connectors) &&
        asset.payload.connectors.every(isRecord) &&
        isRecord(asset.rights),
    )
  );
}

function localeToken(locale) {
  return typeof locale === "string" ? locale.toLowerCase() : "";
}

function expectedVersionID(stableID, locale, version) {
  return `${stableID}--${localeToken(locale)}--v${version}`;
}

function checkVersionIdentity(
  document,
  { stableKey, versionKey, instancePath, catalog = false },
  issues,
) {
  if (!document || typeof document !== "object") return;
  const expected = catalog
    ? `catalog--${localeToken(document.locale)}--v${document.version}`
    : expectedVersionID(document[stableKey], document.locale, document.version);
  if (document[versionKey] !== expected) {
    addIssue(
      issues,
      "DERIVED_ID_MISMATCH",
      at(instancePath, versionKey),
      "Version identifier does not match stable identity, locale, and version.",
    );
  }
}

function checkEnvelopeIdentity(draft, issues) {
  if (draft?.publicationState !== "draft") {
    addIssue(
      issues,
      "PUBLICATION_STATE_INVALID",
      "/publicationState",
      "The authoring envelope must be a draft.",
    );
  }
  checkDraftState(draft?.catalogVersion, "/catalogVersion", issues);
  checkVersionIdentity(
    draft?.catalogVersion,
    {
      versionKey: "catalogVersionID",
      instancePath: "/catalogVersion",
      catalog: true,
    },
    issues,
  );

  const definitions = [
    ["programVersions", "programID", "programVersionID"],
    ["moduleVersions", "moduleID", "moduleVersionID"],
    ["lessonVersions", "lessonID", "lessonVersionID"],
    ["rubricVersions", "rubricID", "rubricVersionID"],
    [
      "evaluationContractVersions",
      "evaluationContractID",
      "evaluationContractVersionID",
    ],
    ["assetVersions", "assetID", "assetVersionID"],
  ];
  for (const [arrayKey, stableKey, versionKey] of definitions) {
    const values = Array.isArray(draft?.[arrayKey]) ? draft[arrayKey] : [];
    values.forEach((document, index) => {
      const instancePath = `/${arrayKey}/${index}`;
      checkDraftState(document, instancePath, issues);
      checkVersionIdentity(
        document,
        { stableKey, versionKey, instancePath },
        issues,
      );
      if (!isRecord(document)) return;
      if (document.locale !== draft.locale) {
        addIssue(
          issues,
          "LOCALE_MISMATCH",
          at(instancePath, "locale"),
          "Document locale must match the envelope locale.",
        );
      }
      if (document.schemaVersion !== draft.schemaVersion) {
        addIssue(
          issues,
          "SCHEMA_VERSION_MISMATCH",
          at(instancePath, "schemaVersion"),
          "Document schema version must match the envelope.",
        );
      }
      if (
        arrayKey !== "evaluationContractVersions" &&
        document.minimumClientSchemaVersion !== draft.minimumClientSchemaVersion
      ) {
        addIssue(
          issues,
          "SCHEMA_VERSION_MISMATCH",
          at(instancePath, "minimumClientSchemaVersion"),
          "Document minimum client schema must match the envelope.",
        );
      }
    });
    uniqueBy(values, (value) => value?.[versionKey], `/${arrayKey}`, issues);
    uniqueBy(values, (value) => value?.[stableKey], `/${arrayKey}`, issues);
  }
  if (isRecord(draft?.catalogVersion) && draft.catalogVersion.locale !== draft?.locale) {
    addIssue(
      issues,
      "LOCALE_MISMATCH",
      "/catalogVersion/locale",
      "Catalog locale must match the envelope locale.",
    );
  }
}

function referenceIssue(issues, instancePath) {
  addIssue(
    issues,
    "REFERENCE_NOT_FOUND",
    instancePath,
    "Referenced curriculum identity does not resolve.",
  );
}

function validateRights(asset, assetPath, issues) {
  const rights = asset?.rights;
  if (!rights || typeof rights !== "object") return;
  if (rights.origin === "licensed") {
    if (typeof rights.sourceURL !== "string" || !rights.sourceURL.startsWith("https://")) {
      addIssue(
        issues,
        "RIGHTS_INVALID",
        `${assetPath}/rights/sourceURL`,
        "Licensed assets require an HTTPS source.",
      );
    }
    if (typeof rights.license !== "string" || rights.license.length === 0) {
      addIssue(
        issues,
        "RIGHTS_INVALID",
        `${assetPath}/rights/license`,
        "Licensed assets require license metadata.",
      );
    }
  }
}

function validateDiagram(asset, assetPath, issues) {
  const nodes = Array.isArray(asset?.payload?.nodes) ? asset.payload.nodes : [];
  const connectors = Array.isArray(asset?.payload?.connectors)
    ? asset.payload.connectors
    : [];
  uniqueBy(nodes, (node) => node?.nodeID, `${assetPath}/payload/nodes`, issues);
  uniqueBy(
    connectors,
    (connector) => connector?.connectorID,
    `${assetPath}/payload/connectors`,
    issues,
  );
  const nodeIDs = new Set(nodes.map((node) => node?.nodeID));
  connectors.forEach((connector, index) => {
    const connectorPath = `${assetPath}/payload/connectors/${index}`;
    if (!nodeIDs.has(connector?.fromNodeID)) {
      addIssue(
        issues,
        "ASSET_REFERENCE_INVALID",
        `${connectorPath}/fromNodeID`,
        "Diagram connector source must resolve.",
      );
    }
    if (!nodeIDs.has(connector?.toNodeID)) {
      addIssue(
        issues,
        "ASSET_REFERENCE_INVALID",
        `${connectorPath}/toNodeID`,
        "Diagram connector destination must resolve.",
      );
    } else if (connector?.fromNodeID === connector?.toNodeID) {
      addIssue(
        issues,
        "ASSET_REFERENCE_INVALID",
        `${connectorPath}/toNodeID`,
        "Diagram connector cannot link a node to itself.",
      );
    }
  });
  try {
    if (canonicalBytes(asset?.payload).byteLength > 131_072) {
      addIssue(
        issues,
        "DOCUMENT_SIZE_EXCEEDED",
        `${assetPath}/payload`,
        "Diagram payload exceeds the canonical-byte limit.",
      );
    }
  } catch {
    addIssue(
      issues,
      "CANONICALIZATION_INVALID",
      `${assetPath}/payload`,
      "Diagram payload cannot be canonicalized.",
    );
  }
}

function validateGraph(draft, issues) {
  const programs = Array.isArray(draft?.programVersions) ? draft.programVersions : [];
  const modules = Array.isArray(draft?.moduleVersions) ? draft.moduleVersions : [];
  const lessons = Array.isArray(draft?.lessonVersions) ? draft.lessonVersions : [];
  const rubrics = Array.isArray(draft?.rubricVersions) ? draft.rubricVersions : [];
  const evaluations = Array.isArray(draft?.evaluationContractVersions)
    ? draft.evaluationContractVersions
    : [];
  const assets = Array.isArray(draft?.assetVersions) ? draft.assetVersions : [];
  const entries = Array.isArray(draft?.catalogVersion?.programEntries)
    ? draft.catalogVersion.programEntries
    : [];

  const programMap = mapBy(programs, "programVersionID");
  const moduleMap = mapBy(modules, "moduleVersionID");
  const lessonMap = mapBy(lessons, "lessonVersionID");
  const rubricMap = mapBy(rubrics, "rubricVersionID");
  const evaluationMap = mapBy(evaluations, "evaluationContractVersionID");
  const assetMap = mapBy(assets, "assetVersionID");

  uniqueBy(
    entries,
    (entry) => entry?.programPointerID,
    "/catalogVersion/programEntries",
    issues,
    "programPointerID",
  );
  uniqueBy(
    entries,
    (entry) => entry?.programVersionID,
    "/catalogVersion/programEntries",
    issues,
    "programVersionID",
  );

  const reachable = {
    program: new Set(),
    module: new Set(),
    lesson: new Set(),
    rubric: new Set(),
    evaluation: new Set(),
    asset: new Set(),
  };
  const availableProgramIDs = [];

  entries.forEach((entry, entryIndex) => {
    const entryPath = `/catalogVersion/programEntries/${entryIndex}`;
    const program = programMap.get(entry?.programVersionID);
    if (!program) {
      referenceIssue(issues, `${entryPath}/programVersionID`);
      return;
    }
    reachable.program.add(program.programVersionID);
    const expectedPointer = `${program.programID}--${localeToken(program.locale)}`;
    if (entry.programPointerID !== expectedPointer) {
      addIssue(
        issues,
        "DERIVED_ID_MISMATCH",
        `${entryPath}/programPointerID`,
        "Program pointer does not match the referenced program identity.",
      );
    }
    if (program.catalogState === "available") {
      availableProgramIDs.push(program.programID);
    }

    const flattenedLessons = [];
    const moduleIDs = Array.isArray(program.moduleVersionIDs)
      ? program.moduleVersionIDs
      : [];
    uniqueBy(moduleIDs, (value) => value, `${entryPath}/moduleVersionIDs`, issues);
    moduleIDs.forEach((moduleVersionID, moduleOrder) => {
      const module = moduleMap.get(moduleVersionID);
      if (!module) {
        referenceIssue(issues, `/programVersions/${programs.indexOf(program)}/moduleVersionIDs/${moduleOrder}`);
        return;
      }
      reachable.module.add(moduleVersionID);
      if (module.programID !== program.programID) {
        addIssue(
          issues,
          "OWNERSHIP_MISMATCH",
          `/moduleVersions/${modules.indexOf(module)}/programID`,
          "Module ownership must match its program.",
        );
      }
      const lessonIDs = Array.isArray(module.lessonVersionIDs)
        ? module.lessonVersionIDs
        : [];
      uniqueBy(
        lessonIDs,
        (value) => value,
        `/moduleVersions/${modules.indexOf(module)}/lessonVersionIDs`,
        issues,
      );
      lessonIDs.forEach((lessonVersionID, lessonOrder) => {
        const lesson = lessonMap.get(lessonVersionID);
        if (!lesson) {
          referenceIssue(
            issues,
            `/moduleVersions/${modules.indexOf(module)}/lessonVersionIDs/${lessonOrder}`,
          );
          return;
        }
        reachable.lesson.add(lessonVersionID);
        flattenedLessons.push(lesson);
        if (lesson.programID !== program.programID || lesson.moduleID !== module.moduleID) {
          addIssue(
            issues,
            "OWNERSHIP_MISMATCH",
            `/lessonVersions/${lessons.indexOf(lesson)}`,
            "Lesson ownership must match its program and module.",
          );
        }
      });
    });

    if (program.catalogState === "available") {
      if (program.firstLessonVersionID !== flattenedLessons[0]?.lessonVersionID) {
        addIssue(
          issues,
          "REFERENCE_NOT_FOUND",
          `/programVersions/${programs.indexOf(program)}/firstLessonVersionID`,
          "First lesson must be the first eligible lesson in catalog order.",
        );
      }
      if ((flattenedLessons[0]?.prerequisiteLessonIDs?.length ?? 0) !== 0) {
        addIssue(
          issues,
          "PREREQUISITE_ORDER_INVALID",
          `/lessonVersions/${lessons.indexOf(flattenedLessons[0])}/prerequisiteLessonIDs`,
          "The first lesson cannot have a prerequisite.",
        );
      }
    } else if (flattenedLessons.length > 0) {
      addIssue(
        issues,
        "REFERENCE_NOT_FOUND",
        `/programVersions/${programs.indexOf(program)}/moduleVersionIDs`,
        "Coming-soon programs cannot resolve learning content.",
      );
    }

    const stableLessonIndex = new Map(
      flattenedLessons.map((lesson, index) => [lesson.lessonID, index]),
    );
    const prerequisiteGraph = new Map();
    flattenedLessons.forEach((lesson, lessonIndex) => {
      const prerequisites = Array.isArray(lesson.prerequisiteLessonIDs)
        ? lesson.prerequisiteLessonIDs
        : [];
      prerequisiteGraph.set(lesson.lessonID, prerequisites);
      uniqueBy(
        prerequisites,
        (value) => value,
        `/lessonVersions/${lessons.indexOf(lesson)}/prerequisiteLessonIDs`,
        issues,
      );
      prerequisites.forEach((prerequisiteID, prerequisiteIndex) => {
        const targetIndex = stableLessonIndex.get(prerequisiteID);
        const prerequisitePath = `/lessonVersions/${lessons.indexOf(lesson)}/prerequisiteLessonIDs/${prerequisiteIndex}`;
        if (targetIndex === undefined) {
          referenceIssue(issues, prerequisitePath);
        } else if (targetIndex >= lessonIndex) {
          addIssue(
            issues,
            "PREREQUISITE_ORDER_INVALID",
            prerequisitePath,
            "Prerequisites must appear earlier in catalog order.",
          );
        }
      });
    });

    const visiting = new Set();
    const visited = new Set();
    const visit = (lessonID) => {
      if (visiting.has(lessonID)) return true;
      if (visited.has(lessonID)) return false;
      visiting.add(lessonID);
      for (const prerequisiteID of prerequisiteGraph.get(lessonID) ?? []) {
        if (prerequisiteGraph.has(prerequisiteID) && visit(prerequisiteID)) return true;
      }
      visiting.delete(lessonID);
      visited.add(lessonID);
      return false;
    };
    if ([...prerequisiteGraph.keys()].some(visit)) {
      const cycleLessonIndex = flattenedLessons.findIndex(
        (lesson) => (lesson.prerequisiteLessonIDs?.length ?? 0) > 0,
      );
      const cycleLesson = flattenedLessons[Math.max(cycleLessonIndex, 0)];
      addIssue(
        issues,
        "PREREQUISITE_CYCLE",
        `/lessonVersions/${lessons.indexOf(cycleLesson)}/prerequisiteLessonIDs/0`,
        "Lesson prerequisites must form a directed acyclic graph.",
      );
    }

    flattenedLessons.forEach((lesson) => {
      const lessonIndex = lessons.indexOf(lesson);
      const lessonPath = `/lessonVersions/${lessonIndex}`;
      const blocks = Array.isArray(lesson.blocks) ? lesson.blocks : [];
      uniqueBy(blocks, (block) => block?.blockID, `${lessonPath}/blocks`, issues);
      blocks.forEach((block, blockIndex) => {
        if (block?.order !== blockIndex) {
          addIssue(
            issues,
            "ORDER_INVALID",
            `${lessonPath}/blocks/${blockIndex}/order`,
            "Block order must be consecutive and match array order.",
          );
        }
      });
      const concepts = blocks.filter((block) => block?.type === "conceptText");
      const diagrams = blocks.filter((block) => block?.type === "stillDiagram");
      const questions = blocks.filter((block) => block?.type === "singleAnswerQuestion");
      if (concepts.length < 1 || diagrams.length < 1 || questions.length !== 1) {
        addIssue(
          issues,
          "COMPLETION_CONTRACT_INVALID",
          `${lessonPath}/blocks`,
          "Available lessons require concept, diagram, and one deterministic question.",
        );
      }

      const question = questions[0];
      uniqueBy(
        question?.options,
        (option) => option?.optionID,
        `${lessonPath}/blocks/${blocks.indexOf(question)}/options`,
        issues,
        "optionID",
      );
      if (concepts.length < 1 || diagrams.length < 1) {
        addIssue(
          issues,
          "REQUIRED_BLOCK_KIND_MISSING",
          `${lessonPath}/blocks`,
          "Available lessons require concept and diagram blocks.",
        );
      }
      if (questions.length !== 1) {
        addIssue(
          issues,
          "QUESTION_COUNT_INVALID",
          `${lessonPath}/blocks`,
          "Schema v1 requires exactly one deterministic question.",
        );
      }
      (lesson?.completionRule?.requiredBlockIDs ?? []).forEach(
        (requiredBlockID, requiredIndex) => {
          if (requiredBlockID !== question?.blockID) {
            referenceIssue(
              issues,
              `${lessonPath}/completionRule/requiredBlockIDs/${requiredIndex}`,
            );
          }
        },
      );
      if (
        lesson?.completionRule?.minimumCorrectCount !== 1 ||
        lesson?.completionRule?.requiredBlockIDs?.length !== 1 ||
        lesson?.completionRule?.requiredBlockIDs?.[0] !== question?.blockID
      ) {
        addIssue(
          issues,
          "COMPLETION_CONTRACT_INVALID",
          `${lessonPath}/completionRule`,
          "Completion rule must require the sole question exactly once.",
        );
      }

      const rubric = rubricMap.get(lesson.rubricVersionID);
      if (!rubric) {
        referenceIssue(issues, `${lessonPath}/rubricVersionID`);
      } else {
        reachable.rubric.add(rubric.rubricVersionID);
        const rubricIndex = rubrics.indexOf(rubric);
        uniqueBy(
          rubric.criteria,
          (criterion) => criterion?.criterionID,
          `/rubricVersions/${rubricIndex}/criteria`,
          issues,
        );
        const scoring = rubric.clientScoringContract;
        const correctOptionIDs = new Set(
          (question?.options ?? []).map((option) => option?.optionID),
        );
        if (
          scoring?.questionBlockID !== question?.blockID ||
          !correctOptionIDs.has(scoring?.correctOptionID)
        ) {
          addIssue(
            issues,
            "SCORING_CONTRACT_MISMATCH",
            `/rubricVersions/${rubricIndex}/clientScoringContract`,
            "Public scoring must resolve to the lesson question and option.",
          );
        }
        const evaluation = evaluationMap.get(rubric.evaluationContractVersionID);
        if (!evaluation) {
          referenceIssue(
            issues,
            `/rubricVersions/${rubricIndex}/evaluationContractVersionID`,
          );
        } else {
          reachable.evaluation.add(evaluation.evaluationContractVersionID);
          if (
            evaluation.rubricVersionID !== rubric.rubricVersionID ||
            evaluation.questionBlockID !== scoring?.questionBlockID ||
            evaluation.correctOptionID !== scoring?.correctOptionID
          ) {
          const evaluationIndex = evaluations.indexOf(evaluation);
          if (evaluation.rubricVersionID !== rubric.rubricVersionID) {
            addIssue(
              issues,
              "SCORING_CONTRACT_MISMATCH",
              `/evaluationContractVersions/${evaluationIndex}/rubricVersionID`,
              "Protected scoring must pin the public rubric.",
            );
          }
          if (evaluation.questionBlockID !== scoring?.questionBlockID) {
            addIssue(
              issues,
              "SCORING_CONTRACT_MISMATCH",
              `/evaluationContractVersions/${evaluationIndex}/questionBlockID`,
              "Protected scoring must match the public question.",
            );
          }
          if (evaluation.correctOptionID !== scoring?.correctOptionID) {
            addIssue(
              issues,
              "SCORING_CONTRACT_MISMATCH",
              `/evaluationContractVersions/${evaluationIndex}/correctOptionID`,
              "Protected scoring must match the public correct option.",
            );
          }
          }
        }
      }

      const declaredAssetIDs = Array.isArray(lesson.assetVersionIDs)
        ? lesson.assetVersionIDs
        : [];
      uniqueBy(
        declaredAssetIDs,
        (value) => value,
        `${lessonPath}/assetVersionIDs`,
        issues,
      );
      const diagramAssetIDs = diagrams.map((block) => block.assetVersionID);
      declaredAssetIDs.forEach((assetID, assetIndex) => {
        if (!diagramAssetIDs.includes(assetID)) {
          addIssue(
            issues,
            "ASSET_REFERENCE_INVALID",
            `${lessonPath}/assetVersionIDs/${assetIndex}`,
            "Declared lesson asset is not used by a content block.",
          );
        }
      });
      diagramAssetIDs.forEach((assetVersionID) => {
        const diagram = diagrams.find((block) => block.assetVersionID === assetVersionID);
        const blockIndex = blocks.indexOf(diagram);
        if (!declaredAssetIDs.includes(assetVersionID)) {
          addIssue(
            issues,
            "ASSET_REFERENCE_INVALID",
            `${lessonPath}/blocks/${blockIndex}/assetVersionID`,
            "Block-level asset must be declared by the lesson.",
          );
        }
        const asset = assetMap.get(assetVersionID);
        if (!asset || asset.kind !== "diagramData") {
          addIssue(
            issues,
            "ASSET_REFERENCE_INVALID",
            `${lessonPath}/blocks/${blockIndex}/assetVersionID`,
            "Diagram block must resolve to diagram data.",
          );
          return;
        }
        reachable.asset.add(assetVersionID);
        if (!asset.accessibilityDescription?.trim()) {
          addIssue(
            issues,
            "ASSET_REFERENCE_INVALID",
            `/assetVersions/${assets.indexOf(asset)}/accessibilityDescription`,
            "Diagram requires a meaningful text alternative.",
          );
        }
      });
    });
  });

  if (
    availableProgramIDs.length !== 1 ||
    availableProgramIDs[0] !== "ai-foundations"
  ) {
    addIssue(
      issues,
      "FOUNDATIONS_CATALOG_INVALID",
      "/catalogVersion/programEntries",
      "Phase 2 requires ai-foundations to be the catalog's only available program.",
    );
  }

  const orphanDefinitions = [
    [programs, "programVersionID", reachable.program, "programVersions"],
    [modules, "moduleVersionID", reachable.module, "moduleVersions"],
    [lessons, "lessonVersionID", reachable.lesson, "lessonVersions"],
    [rubrics, "rubricVersionID", reachable.rubric, "rubricVersions"],
    [
      evaluations,
      "evaluationContractVersionID",
      reachable.evaluation,
      "evaluationContractVersions",
    ],
    [assets, "assetVersionID", reachable.asset, "assetVersions"],
  ];
  for (const [values, key, reached, arrayKey] of orphanDefinitions) {
    values.forEach((value, index) => {
      if (!reached.has(value?.[key])) {
        addIssue(
          issues,
          "ORPHAN_DOCUMENT",
          `/${arrayKey}/${index}`,
          "Every supplied document must be reachable from the target catalog.",
        );
      }
    });
  }

  assets.forEach((asset, index) => {
    validateRights(asset, `/assetVersions/${index}`, issues);
    validateDiagram(asset, `/assetVersions/${index}`, issues);
  });
}

function validatePublicationLimits(publication, issues) {
  publication.immutableDocuments.forEach(({ path: documentPath, data }, index) => {
    if (canonicalBytes(data).byteLength > CURRICULUM_LIMITS.immutableDocumentBytes) {
      addIssue(
        issues,
        "DOCUMENT_SIZE_EXCEEDED",
        `/immutableDocuments/${index}`,
        "Immutable document exceeds the canonical-byte limit.",
        documentPath,
      );
    }
  });
  try {
    assertRawPublicationBudgetWithinLimit(publication.budget);
  } catch (error) {
    if (error instanceof PublicationBudgetError) {
      const code =
        error.code === "TRANSACTION_BUDGET_EXCEEDED"
          ? error.code
          : error.code === "PUBLICATION_SIZE_EXCEEDED"
            ? "PUBLICATION_SIZE_EXCEEDED"
            : "IMMUTABLE_DOCUMENT_LIMIT_EXCEEDED";
      addIssue(issues, code, "", error.message);
    } else {
      throw error;
    }
  }
}

export function validateCurriculumDraft(draft, { sourcePath } = {}) {
  const issues = [];
  const isSchemaValid = validateSchema(draft);
  if (!isSchemaValid) addSchemaIssues(issues);
  if (draft === null || typeof draft !== "object" || Array.isArray(draft)) {
    return { ok: false, issues: sortIssues(issues), publication: undefined };
  }

  validateStrings(draft, issues);
  checkEnvelopeIdentity(draft, issues);
  if (
    isSyntheticFixturePath(sourcePath) &&
    !hasSyntheticSentinelTitle(draft)
  ) {
    addIssue(
      issues,
      "SYNTHETIC_SENTINEL_REQUIRED",
      "/programVersions",
      "A synthetic fixture must use the reserved sentinel as a learner-visible title.",
    );
  }
  if (isGraphShapeSafe(draft)) validateGraph(draft, issues);

  let publication;
  if (isSchemaValid && issues.length === 0) {
    try {
      publication = buildPublicationShape(draft);
      validatePublicationLimits(publication, issues);
    } catch {
      addIssue(
        issues,
        "CANONICALIZATION_INVALID",
        "",
        "Curriculum publication shape could not be canonicalized.",
      );
    }
  }

  if (issues.length > 0) {
    return { ok: false, issues: sortIssues(issues), publication: undefined };
  }
  return {
    ok: true,
    issues: [],
    publication,
    source: {
      path: sourcePath ?? null,
      synthetic: isSyntheticCurriculumSource(draft, { sourcePath }),
    },
  };
}

export function assertValidCurriculumDraft(draft, options) {
  const result = validateCurriculumDraft(draft, options);
  if (!result.ok) throw new CurriculumValidationError(result.issues);
  return result.publication;
}

function hasSyntheticSentinel(draft) {
  let found = false;
  walk(draft, "", (value) => {
    if (value === SYNTHETIC_FIXTURE_SENTINEL) found = true;
  });
  return found;
}

function hasSyntheticSentinelTitle(draft) {
  let found = false;
  const visit = (value) => {
    if (found || value === null || typeof value !== "object") return;
    if (
      !Array.isArray(value) &&
      Object.hasOwn(value, "title") &&
      value.title === SYNTHETIC_FIXTURE_SENTINEL
    ) {
      found = true;
      return;
    }
    for (const child of Array.isArray(value) ? value : Object.values(value)) {
      visit(child);
    }
  };
  visit(draft);
  return found;
}

function resolvedPath(sourcePath) {
  if (!sourcePath) return null;
  const absolute = path.resolve(sourcePath);
  try {
    return fs.realpathSync(absolute);
  } catch {
    return absolute;
  }
}

function isInside(parent, child) {
  const relative = path.relative(parent, child);
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function isSyntheticFixturePath(sourcePath) {
  const source = resolvedPath(sourcePath);
  return Boolean(
    source && isInside(fs.realpathSync(SYNTHETIC_FIXTURE_ROOT), source)
  );
}

export function isSyntheticCurriculumSource(draft, { sourcePath } = {}) {
  return Boolean(
    hasSyntheticSentinel(draft) ||
      isSyntheticFixturePath(sourcePath),
  );
}

export function assertPublicationSourceAllowed(
  draft,
  {
    sourcePath,
    environment,
    projectID,
    credentialPrincipal,
    firestoreEmulatorHost = process.env.FIRESTORE_EMULATOR_HOST,
  } = {},
) {
  if (!isSyntheticCurriculumSource(draft, { sourcePath })) return true;
  const allowed =
    environment === "emulator" &&
    projectID === "syntholo-local" &&
    credentialPrincipal === "emulator-local" &&
    typeof firestoreEmulatorHost === "string" &&
    firestoreEmulatorHost.length > 0;
  if (!allowed) {
    throw new CurriculumValidationError([
      issue(
        "SYNTHETIC_SOURCE_FORBIDDEN",
        "",
        "Synthetic curriculum may be published only to the configured emulator.",
      ),
    ]);
  }
  return true;
}

export function isStableCurriculumID(value) {
  return (
    typeof value === "string" &&
    value.length >= 3 &&
    value.length <= 64 &&
    STABLE_ID_PATTERN.test(value)
  );
}
