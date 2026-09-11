#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import path from "node:path";

import { validateCurriculumDraft } from "./lib/curriculum-validation.mjs";

class StrictJSONParser {
  constructor(text) {
    this.text = text;
    this.index = 0;
  }

  parse() {
    this.skipWhitespace();
    this.parseValue("");
    this.skipWhitespace();
    if (this.index !== this.text.length) this.fail("Unexpected trailing JSON input.");
  }

  parseValue(instancePath) {
    this.skipWhitespace();
    const character = this.text[this.index];
    if (character === "{") return this.parseObject(instancePath);
    if (character === "[") return this.parseArray(instancePath);
    if (character === '"') return void this.parseString();
    const remainder = this.text.slice(this.index);
    const number = remainder
      .match(/^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/u)?.[0];
    if (number) {
      if (/[.eE]/u.test(number)) {
        this.fail("Curriculum numbers must use integer JSON syntax.", "JSON_NUMBER_NOT_INTEGER");
      }
      this.index += number.length;
      return;
    }
    const token = remainder.match(/^(?:true|false|null)/u)?.[0];
    if (!token) this.fail("Invalid JSON value.");
    this.index += token.length;
  }

  parseObject(instancePath) {
    this.index += 1;
    this.skipWhitespace();
    const keys = new Set();
    if (this.text[this.index] === "}") {
      this.index += 1;
      return;
    }
    while (this.index < this.text.length) {
      if (this.text[this.index] !== '"') this.fail("Object key must be a JSON string.");
      const key = this.parseString();
      const childPath = `${instancePath}/${key.replaceAll("~", "~0").replaceAll("/", "~1")}`;
      if (keys.has(key)) {
        const error = new SyntaxError("Duplicate JSON object key.");
        error.code = "DUPLICATE_OBJECT_KEY";
        error.path = "";
        throw error;
      }
      keys.add(key);
      this.skipWhitespace();
      if (this.text[this.index] !== ":") this.fail("Object key must be followed by a colon.");
      this.index += 1;
      this.parseValue(childPath);
      this.skipWhitespace();
      if (this.text[this.index] === "}") {
        this.index += 1;
        return;
      }
      if (this.text[this.index] !== ",") this.fail("Object entries must be comma-separated.");
      this.index += 1;
      this.skipWhitespace();
    }
    this.fail("Unterminated JSON object.");
  }

  parseArray(instancePath) {
    this.index += 1;
    this.skipWhitespace();
    if (this.text[this.index] === "]") {
      this.index += 1;
      return;
    }
    let itemIndex = 0;
    while (this.index < this.text.length) {
      this.parseValue(`${instancePath}/${itemIndex}`);
      itemIndex += 1;
      this.skipWhitespace();
      if (this.text[this.index] === "]") {
        this.index += 1;
        return;
      }
      if (this.text[this.index] !== ",") this.fail("Array entries must be comma-separated.");
      this.index += 1;
      this.skipWhitespace();
    }
    this.fail("Unterminated JSON array.");
  }

  parseString() {
    const start = this.index;
    this.index += 1;
    while (this.index < this.text.length) {
      const character = this.text[this.index];
      if (character === '"') {
        this.index += 1;
        return JSON.parse(this.text.slice(start, this.index));
      }
      if (character === "\\") {
        this.index += 2;
      } else {
        this.index += 1;
      }
    }
    this.fail("Unterminated JSON string.");
  }

  skipWhitespace() {
    while (/\s/u.test(this.text[this.index] ?? "")) this.index += 1;
  }

  fail(message, code = "JSON_PARSE_INVALID") {
    const error = new SyntaxError(message);
    error.code = code;
    error.path = "";
    throw error;
  }
}

function safeIssues(issues) {
  return issues.map(({ code, path: instancePath, documentPath }) => ({
    code,
    path: instancePath,
    documentPath,
  }));
}

async function main() {
  const sourceArgument = process.argv[2];
  if (!sourceArgument || process.argv.length !== 3) {
    console.error("Usage: npm run content:validate -- <curriculum-draft.json>");
    process.exitCode = 64;
    return;
  }

  const sourcePath = path.resolve(sourceArgument);
  let text;
  try {
    const bytes = await readFile(sourcePath);
    text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    console.error(JSON.stringify({ ok: false, issues: [{ code: "SOURCE_READ_INVALID", path: "" }] }));
    process.exitCode = 1;
    return;
  }

  let draft;
  try {
    new StrictJSONParser(text).parse();
    draft = JSON.parse(text);
  } catch (error) {
    console.error(
      JSON.stringify({
        ok: false,
        issues: [{ code: error.code ?? "JSON_PARSE_INVALID", path: error.path ?? "" }],
      }),
    );
    process.exitCode = 1;
    return;
  }

  const result = validateCurriculumDraft(draft, { sourcePath });
  if (!result.ok) {
    console.error(JSON.stringify({ ok: false, issues: safeIssues(result.issues) }));
    process.exitCode = 1;
    return;
  }

  console.log(
    JSON.stringify({
      ok: true,
      synthetic: result.source.synthetic,
      catalogVersionID: draft.catalogVersion.catalogVersionID,
      immutableDocumentCount: result.publication.budget.immutableDocumentCount,
      canonicalDocumentBytes: result.publication.budget.canonicalDocumentBytes,
      calculatedTransactionUnits: result.publication.budget.calculatedUnits,
      publicationDigest: result.publication.publicationDigest,
    }),
  );
}

await main();
