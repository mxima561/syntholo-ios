#!/usr/bin/env node

import { pathToFileURL } from "node:url";

import { resolveOperatorIdentity } from "./lib/operator-identity.mjs";
import { rollbackCurriculum } from "./lib/publication-transactions.mjs";
import {
  assertEmulatorConnectionContext,
  commandExitCode,
  parseRollbackArguments,
  safeIssue,
} from "./lib/publication-cli.mjs";

function previewResult(options, operator) {
  return {
    ok: true,
    action: "rollback",
    outcome: "dryRun",
    replay: false,
    environment: operator.environment,
    projectID: operator.projectID,
    projectNumber: operator.projectNumber,
    credentialPrincipal: operator.credentialPrincipal,
    requestedBy: operator.requestedBy,
    operationID: options.operationID,
    catalogPointerID: options.catalogPointerID,
    toCatalogVersionID: options.toCatalogVersionID,
    auditAction: "rollback",
  };
}

async function openEmulatorFirestore(operator, operationID) {
  assertEmulatorConnectionContext(operator);
  const [{ initializeApp, deleteApp }, { FieldValue, initializeFirestore }] =
    await Promise.all([
      import("firebase-admin/app"),
      import("firebase-admin/firestore"),
    ]);
  const app = initializeApp(
    { projectId: operator.projectID },
    `syntholo-content-rollback-${operationID}`,
  );
  return {
    firestore: initializeFirestore(app, { preferRest: false }),
    serverTimestamp: () => FieldValue.serverTimestamp(),
    close: () => deleteApp(app),
  };
}

export async function main(tokens = process.argv.slice(2)) {
  let connection;
  try {
    const options = parseRollbackArguments(tokens);
    const operator = await resolveOperatorIdentity({
      environment: options.environment,
      projectID: options.projectID,
      confirmProject: options.confirmProject,
      requestedBy: options.requestedBy,
      firestoreEmulatorHost: process.env.FIRESTORE_EMULATOR_HOST,
    });
    if (options.dryRun) {
      console.log(JSON.stringify(previewResult(options, operator)));
      return 0;
    }

    connection = await openEmulatorFirestore(operator, options.operationID);
    const result = await rollbackCurriculum({
      firestore: connection.firestore,
      catalogPointerID: options.catalogPointerID,
      toCatalogVersionID: options.toCatalogVersionID,
      operatorContext: operator,
      operationID: options.operationID,
      requestedBy: options.requestedBy,
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
