/**
 * NoteParser — JS port of `PlanningPoker.MagicEstimation.NoteParser`.
 *
 * Pure parser for free-form estimation notes written by voters. The two
 * implementations (Elixir and JS) must stay semantically identical: the JS
 * version runs in the browser to give immediate "parses as …" feedback and
 * to emit a compact hint alongside the locally-stored raw note, while the
 * server re-parses authoritatively. No Jest/Vitest is wired up in this
 * repo; the client is best-effort and the server reparses every hint.
 *
 * `parse(note)` returns one of:
 *   * `{ ok: <number> }`  — a numeric estimate could be extracted
 *   * `"abstain"`         — blank / question-marks only
 *   * `"unparseable"`     — anything else
 *
 * Rules (applied in order) mirror the Elixir module:
 *
 *   1. `null` / empty-after-trim → abstain
 *   2. Any run of `?` after trimming → abstain
 *   3. Exact non-negative integer or decimal (`.` or `,` as separator)
 *   4. `<a><dash><b>` range → average. Dashes are `-`, U+2010–U+2015 (minus
 *      U+2014 em-dash and U+2013 en-dash are already in that block).
 *   5. Leading fuzz tokens (`~`, `≈`, `ca.`, `about `) then a valid number
 *      (or number + commentary).
 *   6. Number followed by whitespace / `(` / `,` and arbitrary commentary.
 *   7. Anything else → unparseable (includes negative, hex, words, …).
 */

// All dash variants that are treated as range separators. Keep in sync with
// the Elixir module. U+2013 (en-dash) and U+2014 (em-dash) are part of the
// U+2010–U+2015 block.
const DASHES = [
  "-",
  "\u2010",
  "\u2011",
  "\u2012",
  "\u2013",
  "\u2014",
  "\u2015",
];

// Build the dash alternation. None of our dash code points require escaping
// in a RegExp alternation (hyphen-minus only needs escaping inside a
// character class), and under the `u` flag escaping `-` would itself be an
// invalid escape.
const DASH_ALT = DASHES.join("|");

// Non-negative decimal with optional `.` or `,` fraction.
const NUMBER_SRC = "\\d+(?:[.,]\\d+)?";

const NUMBER_ONLY_RE = new RegExp("^" + NUMBER_SRC + "$");

// Range regex. `u` flag so multi-byte dashes are treated as single code
// points.
const RANGE_RE = new RegExp(
  "^(" + NUMBER_SRC + ")\\s*(?:" + DASH_ALT + ")\\s*(" + NUMBER_SRC + ")$",
  "u",
);

// Number followed by commentary that starts with whitespace, `(`, or `,`.
const NUMBER_WITH_COMMENTARY_RE = new RegExp(
  "^(" + NUMBER_SRC + ")(?:[\\s(,].*)$",
);

// Leading fuzz tokens, applied in order. Each is stripped literally; the
// remainder is left-trimmed and re-parsed as a number (with optional
// commentary).
const FUZZ_PREFIXES = ["~", "\u2248", "ca.", "about "];

/**
 * @param {string|null|undefined} note
 * @returns {{ok: number} | "abstain" | "unparseable"}
 */
export function parse(note) {
  if (note == null) return "abstain";
  if (typeof note !== "string") return "unparseable";

  const trimmed = note.trim();
  if (trimmed === "") return "abstain";
  if (onlyQuestionMarks(trimmed)) return "abstain";

  return parseTrimmed(trimmed);
}

function onlyQuestionMarks(str) {
  return str !== "" && str.replace(/\?/g, "") === "";
}

function parseTrimmed(str) {
  const exact = tryExactNumber(str);
  if (exact !== null) return exact;

  const range = tryRange(str);
  if (range !== null) return range;

  const fuzz = tryFuzz(str);
  if (fuzz !== null) return fuzz;

  const commentary = tryNumberWithCommentary(str);
  if (commentary !== null) return commentary;

  return "unparseable";
}

function tryExactNumber(str) {
  if (NUMBER_ONLY_RE.test(str)) {
    return { ok: toFloat(str) };
  }
  return null;
}

function tryRange(str) {
  const m = RANGE_RE.exec(str);
  if (m) {
    const a = toFloat(m[1]);
    const b = toFloat(m[2]);
    return { ok: (a + b) / 2 };
  }
  return null;
}

function tryFuzz(str) {
  const rest = stripFuzz(str);
  if (rest === null) return null;

  const exact = tryExactNumber(rest);
  if (exact !== null) return exact;

  const commentary = tryNumberWithCommentary(rest);
  if (commentary !== null) return commentary;

  return null;
}

function stripFuzz(str) {
  for (const prefix of FUZZ_PREFIXES) {
    if (str.startsWith(prefix)) {
      // Strip the prefix then left-trim (matching `String.trim_leading/1`).
      return str.slice(prefix.length).replace(/^\s+/, "");
    }
  }
  return null;
}

function tryNumberWithCommentary(str) {
  const m = NUMBER_WITH_COMMENTARY_RE.exec(str);
  if (m) {
    return { ok: toFloat(m[1]) };
  }
  return null;
}

function toFloat(str) {
  // Accept `,` or `.` as decimal separator; always return a JS number.
  return parseFloat(str.replace(",", "."));
}

/**
 * Compact hint for sync_magic_hints. `raw_head` is deliberately short (32
 * chars after stripping trailing commentary) so the full note text stays
 * local while the server has enough to reparse deterministically.
 *
 * @param {string} note
 * @returns {{raw_head: string, client_parse: {ok:number}|"abstain"|"unparseable"}}
 */
export function hintFor(note) {
  const safe = typeof note === "string" ? note : "";
  return {
    raw_head: rawHead(safe),
    client_parse: parse(safe),
  };
}

/**
 * Strip trailing commentary (split at first newline / `(` / `,`) and return
 * the first 32 chars. This is intentionally conservative: it captures enough
 * for the server-side parser to reach the same verdict without sending
 * prose to the server.
 *
 * @param {string} note
 */
export function rawHead(note) {
  if (typeof note !== "string") return "";
  // Split at first newline, `(`, or `,` — matches the rule 6 commentary
  // separators plus hard line breaks.
  const idx = firstIndexOfAny(note, ["\n", "(", ","]);
  const head = idx === -1 ? note : note.slice(0, idx);
  return head.trim().slice(0, 32);
}

function firstIndexOfAny(str, chars) {
  let best = -1;
  for (const c of chars) {
    const i = str.indexOf(c);
    if (i !== -1 && (best === -1 || i < best)) best = i;
  }
  return best;
}

/**
 * Format a parse result for the live "parses as" badge.
 *
 * @param {{ok:number}|"abstain"|"unparseable"} result
 * @param {string} rawNote  — the full local note; used to detect whether a
 *                            range collapsed to an average so we can show
 *                            "parses as: 4 (from 3-5)".
 * @returns {string|null}   — null when nothing should be displayed (e.g.
 *                            empty note).
 */
export function formatBadge(result, rawNote) {
  if (result === "abstain") return "abstain";
  if (result === "unparseable") return "won't count toward magic";
  if (result && typeof result === "object" && typeof result.ok === "number") {
    const trimmed = typeof rawNote === "string" ? rawNote.trim() : "";
    const rangeM = RANGE_RE.exec(trimmed);
    if (rangeM) {
      return "parses as: " + formatNumber(result.ok) + " (from " + rangeM[1] + "-" + rangeM[2] + ")";
    }
    return "parses as: " + formatNumber(result.ok);
  }
  return null;
}

function formatNumber(n) {
  // Drop trailing `.0` for integers, otherwise keep up to 2 decimals.
  if (Number.isInteger(n)) return String(n);
  return String(Math.round(n * 100) / 100);
}
