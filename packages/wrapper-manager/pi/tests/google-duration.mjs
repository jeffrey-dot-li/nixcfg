// Run with Node 24: node tests/google-duration.mjs <patched pi-mcp-adapter path>
import assert from "node:assert/strict";
import { copyFileSync, mkdtempSync, rmSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const packagePath = resolve(process.argv[2]);
const temp = mkdtempSync(join(tmpdir(), "pi-google-duration-test-"));
const warnings = [];
const originalWarn = console.warn;
try {
  // Node strips the TypeScript without needing the Pi runtime or a model call.
  copyFileSync(join(packagePath, "json-schema-validator.ts"), join(temp, "validator.mts"));
  symlinkSync(join(packagePath, "node_modules"), join(temp, "node_modules"));
  const { createJsonSchemaValidator } = await import(pathToFileURL(join(temp, "validator.mts")).href);
  console.warn = (...args) => warnings.push(args.join(" "));

  for (const dialect of [undefined, "http://json-schema.org/draft-07/schema#", "https://json-schema.org/draft/2020-12/schema"]) {
    const provider = createJsonSchemaValidator();
    const schema = {
      ...(dialect ? { $schema: dialect } : {}),
      type: "object",
      properties: { latency: { type: "string", format: "google-duration" } },
      required: ["latency"],
    };
    const validate = provider.getValidator(schema);
    for (const latency of ["0s", "1.250s", "-0.001s", "3.123456789s", "315576000000s", "-315576000000.000s"]) {
      assert.equal(validate({ latency }).valid, true, `${dialect}: ${latency}`);
    }
    for (const latency of ["1ms", "PT1S", "1", "1.1234567890s", "1.s", "315576000001s", "315576000000.001s", 1, null]) {
      assert.equal(validate({ latency }).valid, false, `${dialect}: ${latency}`);
    }
    const email = provider.getValidator({ ...schema, properties: { latency: { type: "string", format: "email" } } });
    assert.equal(email({ latency: "not-an-email" }).valid, false, "standard formats remain validated");
  }
  assert.deepEqual(warnings, [], "schema compilation should produce no warnings");
  console.log("PASS: Google duration validation, standard formats, and warning-free compilation in all three schema dialects");
} finally {
  console.warn = originalWarn;
  rmSync(temp, { recursive: true, force: true });
}
