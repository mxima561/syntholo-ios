class StrictJSONScanner {
  constructor(text) {
    this.text = text;
    this.index = 0;
  }

  scan() {
    this.skipWhitespace();
    this.scanValue();
    this.skipWhitespace();
    if (this.index !== this.text.length) this.fail("JSON_PARSE_INVALID");
  }

  scanValue() {
    this.skipWhitespace();
    const character = this.text[this.index];
    if (character === "{") return this.scanObject();
    if (character === "[") return this.scanArray();
    if (character === '"') return void this.scanString();
    const token = this.text
      .slice(this.index)
      .match(/^(?:-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null)/u)?.[0];
    if (!token) this.fail("JSON_PARSE_INVALID");
    this.index += token.length;
  }

  scanObject() {
    this.index += 1;
    this.skipWhitespace();
    const keys = new Set();
    if (this.text[this.index] === "}") {
      this.index += 1;
      return;
    }
    while (this.index < this.text.length) {
      if (this.text[this.index] !== '"') this.fail("JSON_PARSE_INVALID");
      const key = this.scanString();
      if (keys.has(key)) this.fail("DUPLICATE_OBJECT_KEY");
      keys.add(key);
      this.skipWhitespace();
      if (this.text[this.index] !== ":") this.fail("JSON_PARSE_INVALID");
      this.index += 1;
      this.scanValue();
      this.skipWhitespace();
      if (this.text[this.index] === "}") {
        this.index += 1;
        return;
      }
      if (this.text[this.index] !== ",") this.fail("JSON_PARSE_INVALID");
      this.index += 1;
      this.skipWhitespace();
    }
    this.fail("JSON_PARSE_INVALID");
  }

  scanArray() {
    this.index += 1;
    this.skipWhitespace();
    if (this.text[this.index] === "]") {
      this.index += 1;
      return;
    }
    while (this.index < this.text.length) {
      this.scanValue();
      this.skipWhitespace();
      if (this.text[this.index] === "]") {
        this.index += 1;
        return;
      }
      if (this.text[this.index] !== ",") this.fail("JSON_PARSE_INVALID");
      this.index += 1;
      this.skipWhitespace();
    }
    this.fail("JSON_PARSE_INVALID");
  }

  scanString() {
    const start = this.index;
    this.index += 1;
    while (this.index < this.text.length) {
      const character = this.text[this.index];
      if (character === '"') {
        this.index += 1;
        try {
          return JSON.parse(this.text.slice(start, this.index));
        } catch {
          this.fail("JSON_PARSE_INVALID");
        }
      }
      if (character === "\\") {
        this.index += 2;
      } else {
        this.index += 1;
      }
    }
    this.fail("JSON_PARSE_INVALID");
  }

  skipWhitespace() {
    while (/[\u0009\u000a\u000d\u0020]/u.test(this.text[this.index] ?? "")) {
      this.index += 1;
    }
  }

  fail(code) {
    const error = new SyntaxError("Curriculum source is not strict JSON.");
    error.code = code;
    error.path = "";
    throw error;
  }
}

export function parseStrictJSONBytes(bytes) {
  let text;
  try {
    text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    const error = new SyntaxError("Curriculum source is not valid UTF-8.");
    error.code = "SOURCE_UTF8_INVALID";
    error.path = "";
    throw error;
  }
  new StrictJSONScanner(text).scan();
  try {
    return JSON.parse(text);
  } catch {
    const error = new SyntaxError("Curriculum source is not valid JSON.");
    error.code = "JSON_PARSE_INVALID";
    error.path = "";
    throw error;
  }
}
