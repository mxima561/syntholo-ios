const [expectedCountArgument, label = "xcresult-tests"] = process.argv.slice(2);
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
  console.error(
    `${label} expected exactly ${expectedCount} passed, 0 failed, 0 skipped; `
      + `received result=${summary.result}, total=${summary.totalTestCount}, `
      + `passed=${summary.passedTests}, failed=${summary.failedTests}, `
      + `skipped=${summary.skippedTests}.`,
  );
  process.exit(1);
}

console.log(`${label}: ${expectedCount} passed, 0 failed, 0 skipped.`);
