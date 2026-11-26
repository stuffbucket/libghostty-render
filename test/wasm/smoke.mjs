// Loads the libghostty-render WebAssembly module and checks that it
// exports both libraries and that their version functions work.
//
// Usage: node test/wasm/smoke.mjs zig-out/bin/ghostty-render.wasm

import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const path = process.argv[2];
assert.ok(path, "usage: node test/wasm/smoke.mjs <ghostty-render.wasm>");

const module = new WebAssembly.Module(readFileSync(path));
const imports = {};
for (const i of WebAssembly.Module.imports(module)) {
  (imports[i.module] ??= {})[i.name] = () => {};
}
const { exports } = new WebAssembly.Instance(module, imports);

for (const name of [
  "gtr_version",
  "gtr_build_info",
  "ghostty_version",
  "ghostty_build_info",
]) {
  assert.equal(typeof exports[name], "function", `missing export ${name}`);
}

const cstring = (ptr) => {
  const bytes = new Uint8Array(exports.memory.buffer);
  let end = ptr;
  while (bytes[end] !== 0) end++;
  return new TextDecoder().decode(bytes.subarray(ptr, end));
};

const render = cstring(exports.gtr_version());
const vt = cstring(exports.ghostty_version());
assert.match(render, /^\d+\.\d+\.\d+/);
assert.match(vt, /^1\.\d+\.\d+/);

// No gtr_* or ghostty_* function may be missing a C name prefix.
const bad = Object.keys(exports).filter(
  (name) =>
    typeof exports[name] === "function" &&
    !name.startsWith("gtr_") &&
    !name.startsWith("ghostty_"),
);
assert.deepEqual(bad, [], `unexpected exports: ${bad.join(", ")}`);

console.log(`libghostty-render ${render} on libghostty-vt ${vt}`);
