import { basename } from "node:path";
import { readFileSync } from "node:fs";

const [
  expectedCountArgument,
  label = "xcresult-tests",
  ...diagnosticPaths
] = process.argv.slice(2);
const expectedCount = Number(expectedCountArgument);

if (!Number.isInteger(expectedCount) || expectedCount <= 0) {
  console.error("Expected XCTest count must be a positive integer.");
  process.exit(64);
}

let input = "";
for await (const chunk of process.stdin) {
  input += chunk;
}

let summary;
try {
  summary = JSON.parse(input);
} catch (error) {
  console.error(`${label} did not produce a valid xcresult JSON summary: ${error.message}`);
  process.exit(1);
}

const isExactPass = summary.result === "Passed"
  && summary.totalTestCount === expectedCount
  && summary.passedTests === expectedCount
  && summary.failedTests === 0
  && summary.skippedTests === 0;

if (!isExactPass) {
  for (const failure of summary.testFailures ?? []) {
    const testName = failure.testName
      ?? failure.testIdentifierString
      ?? "unknown test";
    const failureText = failure.failureText ?? "No failure detail provided.";
    console.error(`${label} failure: ${testName}: ${failureText}`);
  }

  const diagnosticLines = new Set();
  const usefulAttachmentPattern = /App UI hierarchy|Debug description|Screen Recording|UI Snapshot/i;

  const unwrapped = (value) => {
    if (value && typeof value === "object" && "_value" in value) {
      return value._value;
    }
    return value;
  };

  const sourceLocation = (context) => {
    if (!context || typeof context !== "object") return null;
    const location = context.location ?? context;
    const file = unwrapped(
      location.filePath
        ?? location.fileURL
        ?? location.url
        ?? context.filePath
        ?? context.fileURL,
    );
    const line = unwrapped(
      location.lineNumber
        ?? location.line
        ?? context.lineNumber
        ?? context.line,
    );
    if (!file) return null;
    return `${basename(String(file))}${line === undefined ? "" : `:${line}`}`;
  };

  const walkDiagnostics = (value) => {
    if (Array.isArray(value)) {
      for (const item of value) walkDiagnostics(item);
      return;
    }
    if (!value || typeof value !== "object") return;

    if (value.nodeType === "Failure Message" && value.name) {
      diagnosticLines.add(String(value.name));
    }

    const location = sourceLocation(value.sourceCodeContext);
    if (location) {
      const description = value.title ?? value.name ?? "failure";
      diagnosticLines.add(`${location}: ${description}`);
    }

    if (value.isAssociatedWithFailure === true && value.title) {
      diagnosticLines.add(`Failure activity: ${value.title}`);
    }

    for (const attachment of value.attachments ?? []) {
      if (!usefulAttachmentPattern.test(attachment.name ?? "")) continue;
      const payload = attachment.payloadId
        ? ` (payload ${attachment.payloadId})`
        : "";
      diagnosticLines.add(`${attachment.name}${payload}`);
    }

    for (const child of Object.values(value)) {
      walkDiagnostics(child);
    }
  };

  for (const diagnosticPath of diagnosticPaths) {
    try {
      walkDiagnostics(JSON.parse(readFileSync(diagnosticPath, "utf8")));
    } catch (error) {
      console.error(
        `${label} could not parse xcresult diagnostic ${diagnosticPath}: ${error.message}`,
      );
    }
  }

  for (const line of diagnosticLines) {
    console.error(`${label} diagnostic: ${line}`);
  }

  console.error(
    `${label} expected exactly ${expectedCount} passed, 0 failed, 0 skipped; `
      + `received result=${summary.result}, total=${summary.totalTestCount}, `
      + `passed=${summary.passedTests}, failed=${summary.failedTests}, `
      + `skipped=${summary.skippedTests}.`,
  );
  process.exit(1);
}

console.log(`${label}: ${expectedCount} passed, 0 failed, 0 skipped.`);
