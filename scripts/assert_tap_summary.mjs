const [expectedCountArgument, label = "tap-tests"] = process.argv.slice(2);
const expectedCount = Number(expectedCountArgument);

if (!Number.isInteger(expectedCount) || expectedCount <= 0) {
  console.error("Expected TAP count must be a positive integer.");
  process.exit(64);
}

let input = "";
for await (const chunk of process.stdin) {
  input += chunk;
}

const plainInput = input.replace(/\u001B\[[0-?]*[ -/]*[@-~]/g, "");
const requiredFields = ["tests", "pass", "fail", "cancelled", "skipped"];
const values = {};

for (const field of requiredFields) {
  const matches = [
    ...plainInput.matchAll(new RegExp(`^# ${field} (\\d+)\\s*$`, "gm")),
  ];
  if (matches.length !== 1) {
    console.error(`${label} expected one TAP summary field for ${field}; found ${matches.length}.`);
    process.exit(1);
  }
  values[field] = Number(matches[0][1]);
}

const isExactPass = values.tests === expectedCount
  && values.pass === expectedCount
  && values.fail === 0
  && values.cancelled === 0
  && values.skipped === 0;

if (!isExactPass) {
  console.error(
    `${label} expected exactly ${expectedCount} tests/pass, 0 fail/cancelled/skipped; `
      + `received tests=${values.tests}, pass=${values.pass}, fail=${values.fail}, `
      + `cancelled=${values.cancelled}, skipped=${values.skipped}.`,
  );
  process.exit(1);
}

console.log(`${label}: ${expectedCount} tests, ${expectedCount} passed, 0 failed, 0 cancelled, 0 skipped.`);
