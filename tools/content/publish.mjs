#!/usr/bin/env node

import { pathToFileURL } from "node:url";

import {
  assertPublicationSourceAllowed,
  CurriculumValidationError,
  validateCurriculumDraft,
} from "./lib/curriculum-validation.mjs";
import { resolveOperatorIdentity } from "./lib/operator-identity.mjs";
import {
  calculatePublicationRequestDigest,
  publishCurriculum,
} from "./lib/publication-transactions.mjs";
import {
  assertEmulatorConnectionContext,
  commandExitCode,
  loadScannedCurriculumSource,
  parsePublishArguments,
  safeIssue,
} from "./lib/publication-cli.mjs";

function previewResult({ options, operator, draft, publication }) {
  const catalogPointerID = draft.locale.toLowerCase();
  const toCatalogVersionID = draft.catalogVersion.catalogVersionID;
  const request = {
    schemaVersion: 1,
    action: "publish",
    environment: operator.environment,
    projectID: operator.projectID,
    projectNumber: operator.projectNumber,
    credentialPrincipal: operator.credentialPrincipal,
    requestedBy: operator.requestedBy,
    catalogPointerID,
    toCatalogVersionID,
    publicationDigest: publication.publicationDigest,
  };
  return {
    ok: true,
    action: "publish",
    outcome: "dryRun",
    replay: false,
    environment: operator.environment,
    projectID: operator.projectID,
    projectNumber: operator.projectNumber,
    credentialPrincipal: operator.credentialPrincipal,
    requestedBy: operator.requestedBy,
    operationID: options.operationID,
    catalogPointerID,
    toCatalogVersionID,
    programSelections: publication.derivedPointers.programs.map(({ data }) => ({
      programPointerID: data.programPointerID,
      toProgramVersionID: data.publishedVersionID,
    })),
    publicationDigest: publication.publicationDigest,
    requestDigest: calculatePublicationRequestDigest(request),
    immutableDocumentCount: publication.budget.immutableDocumentCount,
    canonicalDocumentBytes: publication.budget.canonicalDocumentBytes,
    calculatedTransactionUnits: publication.budget.calculatedUnits,
    auditAction: "publish",
  };
}

async function openEmulatorFirestore(operator, operationID) {
  assertEmulatorConnectionContext(operator);
  const [
    { initializeApp, deleteApp },
    { FieldPath, FieldValue, initializeFirestore },
  ] =
    await Promise.all([
      import("firebase-admin/app"),
      import("firebase-admin/firestore"),
    ]);
  const app = initializeApp(
    { projectId: operator.projectID },
    `syntholo-content-publish-${operationID}`,
  );
  return {
    firestore: initializeFirestore(app, { preferRest: false }),
    documentIDFieldPath: FieldPath.documentId(),
    serverTimestamp: () => FieldValue.serverTimestamp(),
    close: () => deleteApp(app),
  };
}

export async function main(tokens = process.argv.slice(2)) {
  let connection;
  try {
    const options = parsePublishArguments(tokens);
    const { sourcePath, draft } = await loadScannedCurriculumSource(options.source);
    const validation = validateCurriculumDraft(draft, { sourcePath });
    if (!validation.ok) {
      throw new CurriculumValidationError(validation.issues);
    }
    const operator = await resolveOperatorIdentity({
      environment: options.environment,
      projectID: options.projectID,
      confirmProject: options.confirmProject,
      requestedBy: options.requestedBy,
      firestoreEmulatorHost: process.env.FIRESTORE_EMULATOR_HOST,
    });
    assertPublicationSourceAllowed(draft, {
      sourcePath,
      environment: operator.environment,
      projectID: operator.projectID,
      credentialPrincipal: operator.credentialPrincipal,
      firestoreEmulatorHost: process.env.FIRESTORE_EMULATOR_HOST,
    });

    if (options.dryRun) {
      console.log(
        JSON.stringify(
          previewResult({
            options,
            operator,
            draft,
            publication: validation.publication,
          }),
        ),
      );
      return 0;
    }

    connection = await openEmulatorFirestore(operator, options.operationID);
    const result = await publishCurriculum({
      firestore: connection.firestore,
      draft,
      sourcePath,
      operatorContext: operator,
      operationID: options.operationID,
      requestedBy: options.requestedBy,
      documentIDFieldPath: connection.documentIDFieldPath,
      serverTimestamp: connection.serverTimestamp,
    });
    console.log(JSON.stringify({ ok: true, ...result }));
    return 0;
  } catch (error) {
    console.error(JSON.stringify({ ok: false, issues: safeIssue(error) }));
    return commandExitCode(error);
  } finally {
    if (connection) {
      try {
        await connection.close();
      } catch {
        // The command result is already final; never expose SDK cleanup details.
      }
    }
  }
}

const invokedPath = process.argv[1] ? pathToFileURL(process.argv[1]).href : null;
if (invokedPath === import.meta.url) {
  process.exitCode = await main();
}
