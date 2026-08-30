import {
  canonicalBytes,
  contentDigest,
  payloadDigest,
  publicationDigest as digestPublication,
} from "./canonical-json.mjs";

export const CURRICULUM_LIMITS = Object.freeze({
  immutableDocumentCount: 180,
  immutableDocumentBytes: 262_144,
  publicationBytes: 8 * 1024 * 1024,
  transactionUnits: 450,
});

export class PublicationBudgetError extends Error {
  constructor(code, message, budget) {
    super(message);
    this.name = "PublicationBudgetError";
    this.code = code;
    this.budget = budget;
  }
}

export function calculatePublicationBudget({
  immutableDocumentCount = 0,
  versionHeadCount = immutableDocumentCount,
  programPointerCount = 0,
  canonicalDocumentBytes = 0,
  documentWrites,
  timestampTransforms,
} = {}) {
  const derivedWrites =
    immutableDocumentCount + versionHeadCount + programPointerCount + 3;
  const resolvedWrites = documentWrites ?? derivedWrites;
  const resolvedTransforms = timestampTransforms ?? derivedWrites;

  return Object.freeze({
    immutableDocumentCount,
    versionHeadCount,
    programPointerCount,
    canonicalDocumentBytes,
    documentWrites: resolvedWrites,
    timestampTransforms: resolvedTransforms,
    calculatedUnits: resolvedWrites + resolvedTransforms,
  });
}

export function assertPublicationBudgetWithinLimit(budget) {
  if (budget.immutableDocumentCount > CURRICULUM_LIMITS.immutableDocumentCount) {
    throw new PublicationBudgetError(
      "IMMUTABLE_DOCUMENT_LIMIT_EXCEEDED",
      "Publication exceeds the immutable-document limit.",
      budget,
    );
  }
  if (budget.canonicalDocumentBytes > CURRICULUM_LIMITS.publicationBytes) {
    throw new PublicationBudgetError(
      "PUBLICATION_SIZE_EXCEEDED",
      "Publication exceeds the canonical-byte limit.",
      budget,
    );
  }
  if (budget.calculatedUnits > CURRICULUM_LIMITS.transactionUnits) {
    throw new PublicationBudgetError(
      "TRANSACTION_BUDGET_EXCEEDED",
      "Publication exceeds the calculated transaction budget.",
      budget,
    );
  }
  return budget;
}

function publishedCopy(draft) {
  return {
    ...structuredClone(draft),
    publicationState: "published",
  };
}

function immutableEntry(collection, id, data) {
  const withDigest = {
    ...data,
    contentDigest: contentDigest(data),
  };
  return {
    path: `${collection}/${id}`,
    data: withDigest,
  };
}

export function buildPublicationShape(draft) {
  const catalog = publishedCopy(draft.catalogVersion);
  const programs = draft.programVersions.map(publishedCopy);
  const modules = draft.moduleVersions.map(publishedCopy);
  const lessons = draft.lessonVersions.map(publishedCopy);
  const rubrics = draft.rubricVersions.map(publishedCopy);
  const evaluationContracts = draft.evaluationContractVersions.map(publishedCopy);
  const assets = draft.assetVersions.map((assetDraft) => {
    const asset = publishedCopy(assetDraft);
    return {
      ...asset,
      byteCount: canonicalBytes(asset.payload).byteLength,
      payloadDigest: payloadDigest(asset.payload),
    };
  });

  const immutableDocuments = [
    immutableEntry("catalogVersions", catalog.catalogVersionID, catalog),
    ...programs.map((program) =>
      immutableEntry("programVersions", program.programVersionID, program),
    ),
    ...modules.map((module) =>
      immutableEntry("modules", module.moduleVersionID, module),
    ),
    ...lessons.map((lesson) =>
      immutableEntry("lessonVersions", lesson.lessonVersionID, lesson),
    ),
    ...rubrics.map((rubric) =>
      immutableEntry("rubricVersions", rubric.rubricVersionID, rubric),
    ),
    ...evaluationContracts.map((contract) =>
      immutableEntry(
        "evaluationContractVersions",
        contract.evaluationContractVersionID,
        contract,
      ),
    ),
    ...assets.map((asset) =>
      immutableEntry("assetVersions", asset.assetVersionID, asset),
    ),
  ].sort(({ path: left }, { path: right }) => left.localeCompare(right));

  const canonicalDocumentBytes = immutableDocuments.reduce(
    (total, { data }) => total + canonicalBytes(data).byteLength,
    0,
  );
  const budget = calculatePublicationBudget({
    immutableDocumentCount: immutableDocuments.length,
    programPointerCount: catalog.programEntries.length,
    canonicalDocumentBytes,
  });

  const programByVersionID = new Map(
    programs.map((program) => [program.programVersionID, program]),
  );
  const localeToken = draft.locale.toLowerCase();
  const catalogPointer = {
    path: `catalogs/${localeToken}`,
    data: {
      locale: draft.locale,
      publishedCatalogVersionID: catalog.catalogVersionID,
      schemaVersion: draft.schemaVersion,
      minimumClientSchemaVersion: catalog.minimumClientSchemaVersion,
    },
  };
  const programPointers = catalog.programEntries.map((entry) => {
    const program = programByVersionID.get(entry.programVersionID);
    return {
      path: `programs/${entry.programPointerID}`,
      data: {
        programPointerID: entry.programPointerID,
        programID: program?.programID,
        locale: draft.locale,
        publishedVersionID: entry.programVersionID,
        schemaVersion: draft.schemaVersion,
      },
    };
  });
  const derivedConfiguration = {
    path: "featureConfiguration/curriculum",
    data: {
      schemaVersion: draft.schemaVersion,
      minimumClientSchemaVersion: catalog.minimumClientSchemaVersion,
      defaultLocale: draft.locale,
      supportedLocales: [draft.locale],
      catalogPointerIDs: [localeToken],
    },
  };

  return Object.freeze({
    immutableDocuments,
    immutableDocumentsByPath: Object.fromEntries(
      immutableDocuments.map(({ path, data }) => [path, data]),
    ),
    derivedPointers: Object.freeze({
      catalog: catalogPointer,
      programs: programPointers,
    }),
    derivedConfiguration,
    publicationDigest: digestPublication(immutableDocuments),
    budget,
  });
}
