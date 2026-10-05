// Checks the web game's rule checker against the same scenarios as the Swift GameRulesTests.
//   node web/tests/game-rules.test.mjs
import { readFileSync } from "node:fs";

const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
const start = html.indexOf("/* ---------- Diagram Builder Game ---------- */");
const end = html.indexOf("// Progress lives in this browser only");
const { LEVELS, newBoard, addNode, connect, checkBoard, starsFor, introducedAt, SPECIES_ORDER } = new Function(
  html.slice(start, end) + "\nreturn { LEVELS, newBoard, addNode, connect, checkBoard, starsFor, introducedAt, SPECIES_ORDER };")();

let failures = 0;
const ok = (cond, msg) => { if (!cond) { failures++; console.log("FAIL:", msg); } };
const level = id => LEVELS.find(l => l.id === id);

/** Board for a level with `nv` vertices; externals are ids 0… (incoming first), vertices follow. */
function build(id, nv, links) {
  const l = level(id), b = newBoard(l), v = [...Array(nv)].map((_, i) => addNode(b, 0.3 + 0.2 * i, 0.5));
  for (const [p, q, s] of links(v)) { const r = connect(b, p, q, s ?? "photon", l); ok(r === null, `${id}: connect ${p}-${q}: ${r}`); }
  return [b, l];
}
const valid = (b, l, vertices, loops = 0) => {
  const c = checkBoard(b, l);
  ok(c.valid, `${l.id} should be valid: ${c.problems.map(p => p.message)}`);
  ok(c.vertexCount === vertices && c.loops === loops, `${l.id}: expected ${vertices} vertices and ${loops} loops`);
  ok(starsFor(c, l) === 3, `${l.id}: expected 3 stars`);
};
const invalid = (b, l, text) => {
  const c = checkBoard(b, l);
  ok(!c.valid && c.problems.some(p => p.message.includes(text)), `${l.id}: expected "${text}", got ${JSON.stringify(c.problems.map(p => p.message))}`);
};

let [b, l] = build("repel", 2, v => [[0, v[0]], [2, v[0]], [1, v[1]], [3, v[1]], [v[0], v[1], "photon"]]);
valid(b, l, 2);
[b, l] = build("annihilate", 2, v => [[0, v[0]], [2, v[0]], [1, v[1]], [3, v[1]], [v[0], v[1]]]);
invalid(b, l, "can't change an electron into a muon");
[b, l] = build("compton", 2, v => [[0, v[0]], [1, v[0]], [2, v[1]], [3, v[1]], [v[0], v[1], "e"]]);
valid(b, l, 2);
const internal = b.edges.at(-1); [internal.a, internal.b] = [internal.b, internal.a];
invalid(b, l, "Both fermion arrows point");
[b, l] = build("pair", 2, v => [[0, v[0]], [2, v[0]], [1, v[1]], [3, v[1]], [v[1], v[0], "e"]]);
valid(b, l, 2);
for (const id of ["muon", "beta"]) {
  [b, l] = build(id, 2, v => [[0, v[0]], [1, v[0]], [2, v[1]], [3, v[1]], [v[0], v[1], "w"]]);
  valid(b, l, 2);
  b.edges.at(-1).s = "photon";
  invalid(b, l, "Only the W changes flavor");
}
[b, l] = build("glue", 2, v => [[0, v[0]], [1, v[0]], [2, v[1]], [3, v[1]], [v[0], v[1], "gluon"]]);
valid(b, l, 2);
[b, l] = build("higgs", 3, v => [[0, v[0]], [1, v[1]], [2, v[2]], [v[0], v[1], "t"], [v[1], v[2], "t"], [v[2], v[0], "t"]]);
valid(b, l, 3, 1);
[b, l] = build("lfv", 1, v => [[0, v[0]], [1, v[0]], [2, v[0]]]);
invalid(b, l, "can't change a muon into an electron");

// d → u e⁺ νₑ: the quark end emits a W⁻ but the lepton end would need a W⁺.
const wl = { id: "w-charge", legs: [{ s: "d", anti: false, incoming: true }, { s: "u", anti: false, incoming: false },
  { s: "e", anti: true, incoming: false }, { s: "nuE", anti: false, incoming: false }], palette: ["w"], par: 2 };
const wb = newBoard(wl), w0 = addNode(wb, 0.4, 0.5), w1 = addNode(wb, 0.6, 0.5);
for (const [p, q] of [[0, w0], [1, w0], [2, w1], [3, w1], [w0, w1]]) connect(wb, p, q, "w", wl);
invalid(wb, wl, "Charge isn't conserved along this W");

const introduced = LEVELS.map((_, i) => introducedAt(i));
ok(JSON.stringify(introduced[0]) === '["e","photon"]', "level 1 introduces e and γ");
ok(JSON.stringify(introduced[1]) === '["mu"]', "level 2 introduces μ");
ok(new Set(introduced.flat()).size === SPECIES_ORDER.length && introduced.flat().length === SPECIES_ORDER.length,
  "every particle is introduced exactly once");

console.log(failures ? `${failures} failure(s)` : "All web game rule checks pass");
process.exit(failures ? 1 : 0);
