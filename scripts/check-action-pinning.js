#!/usr/bin/env bun
// SPDX-License-Identifier: MPL-2.0
//
// Assert every workflow action ref is pinned to an immutable commit, and that
// actions.lock covers every step-level ref under the workflow that uses it.
//
// Pinned means EITHER an inline 40-hex SHA, OR a ref that actions.lock lists
// under THIS workflow and resolves through a well-formed dependency record
// (commit `sha1-<40 hex>`, and `ref` equal to the tag in the key). That is the
// per-workflow check GitHub itself applies at run start: a workflow that asks
// for a ref its own lock entry lacks is refused with zero jobs. Measured on
// this repo 2026-11-17: `CI` and `Static Analysis Gate` hit startup_failure
// on PR #67 for exactly that drift, and both ran once the lock was resynced.
//
// Why each rule is here (all found in review of the earlier template copy):
//
//   * Workflows are PARSED (Bun.YAML), not matched line by line, so quoted
//     refs and flow-style steps (`- { uses: "o/r@main" }`) are seen. A file
//     that does not parse is an error, never "no refs found".
//   * Coverage is per workflow. A global set accepted a ref because some OTHER
//     workflow's lock entry listed it.
//   * A workflow-list entry is not proof on its own: its dependency record
//     must exist and resolve to a commit.
//   * No name-based exemptions. `actions/github-script` used to be skipped by
//     substring, which also let `evil-actions/github-script@main` through.
//     Only local actions (`./…`) and `docker://` images are not GitHub refs.
//   * Job-level reusable-workflow calls (`jobs.<id>.uses`) must be SHA-pinned
//     but are not required in the lock: GitHub does not check them there
//     (standards#968, measured harmless).
//
// Runtime: Bun (estate first choice). Plain JavaScript, not TypeScript.
// Exit 0 if every ref passes, 1 otherwise (listing file: problem), 2 on a
// usage error. `--root DIR` checks another tree (used by the self-test).

import { readdirSync, readFileSync, existsSync, statSync } from "node:fs";
import { join } from "node:path";

const args = process.argv.slice(2);
const rootIdx = args.indexOf("--root");
const ROOT = rootIdx === -1 ? "." : args[rootIdx + 1];
if (rootIdx !== -1 && !ROOT) {
  console.error("usage: check-action-pinning.js [--root DIR]");
  process.exit(2);
}
const WF = join(ROOT, ".github/workflows");
const LOCK = join(WF, "actions.lock");
const isSha = (s) => s.length === 40 && /^[0-9a-f]+$/.test(s);

// owner/repo[/path]@ref -> { root: "owner/repo" (lower-cased), ref }
function split(uses) {
  const at = uses.lastIndexOf("@");
  if (at <= 0 || at === uses.length - 1) return null;
  const parts = uses.slice(0, at).split("/");
  if (parts.length < 2 || !parts[0] || !parts[1]) return null;
  return { root: `${parts[0]}/${parts[1]}`.toLowerCase(), ref: uses.slice(at + 1) };
}

// Every `uses:` in a parsed workflow, tagged step or job level.
function refsOf(doc) {
  const out = [];
  const jobs = doc && typeof doc === "object" ? doc.jobs : null;
  if (!jobs || typeof jobs !== "object") return out;
  for (const [id, job] of Object.entries(jobs)) {
    if (!job || typeof job !== "object") continue;
    if (typeof job.uses === "string") out.push({ level: "job", where: `jobs.${id}`, uses: job.uses.trim() });
    if (Array.isArray(job.steps)) {
      job.steps.forEach((step, i) => {
        if (step && typeof step === "object" && typeof step.uses === "string") {
          out.push({ level: "step", where: `jobs.${id}.steps[${i}]`, uses: step.uses.trim() });
        }
      });
    }
  }
  return out;
}

function loadLock(bad) {
  if (!existsSync(LOCK)) return null;
  let lock;
  try {
    lock = Bun.YAML.parse(readFileSync(LOCK, "utf8"));
  } catch (e) {
    bad.push(`${LOCK}: does not parse (${e.message})`);
    return undefined;
  }
  if (!lock || typeof lock.workflows !== "object" || typeof lock.dependencies !== "object") {
    bad.push(`${LOCK}: missing 'workflows' or 'dependencies' map`);
    return undefined;
  }
  // Dependency records that resolve, keyed by lower-cased owner/repo@ref.
  const resolved = new Set();
  for (const [key, rec] of Object.entries(lock.dependencies)) {
    const k = split(key);
    const commit = rec && typeof rec.commit === "string" ? rec.commit : "";
    const okCommit = commit.startsWith("sha1-") && isSha(commit.slice(5).toLowerCase());
    // A tag key must record that tag; a SHA key must resolve to that SHA.
    const okRef = k && (isSha(k.ref) ? commit.toLowerCase() === `sha1-${k.ref}` : rec.ref === k.ref);
    if (k && okCommit && okRef) resolved.add(`${k.root}@${k.ref}`);
    else bad.push(`${LOCK}: dependency record '${key}' does not resolve to a commit`);
  }
  // Per-workflow lists, keyed by workflow path relative to the root.
  const perWorkflow = new Map();
  for (const [path, list] of Object.entries(lock.workflows)) {
    const set = new Set();
    for (const entry of Array.isArray(list) ? list : []) {
      const k = typeof entry === "string" ? split(entry) : null;
      if (k) set.add(`${k.root}@${k.ref}`);
    }
    perWorkflow.set(path, set);
  }
  return { resolved, perWorkflow };
}

function main() {
  if (!existsSync(WF) || !statSync(WF).isDirectory()) {
    console.log("no .github/workflows — nothing to check");
    return 0;
  }
  const bad = [];
  const lock = loadLock(bad);
  if (lock) console.log(`lockfile present: ${lock.resolved.size} resolvable record(s)`);
  else if (lock === null) console.log("no lockfile — every ref must be an inline 40-character SHA");

  const files = readdirSync(WF).filter((f) => f.endsWith(".yml") || f.endsWith(".yaml")).sort();
  let count = 0;
  for (const f of files) {
    const rel = `.github/workflows/${f}`;
    let doc;
    try {
      doc = Bun.YAML.parse(readFileSync(join(WF, f), "utf8"));
    } catch (e) {
      bad.push(`${rel}: does not parse as YAML (${e.message})`);
      continue;
    }
    const listed = lock ? lock.perWorkflow.get(rel) : undefined;
    for (const { level, where, uses } of refsOf(doc)) {
      if (uses.startsWith("./") || uses.startsWith("docker://")) continue;
      count++;
      const k = split(uses);
      if (!k) { bad.push(`${rel} ${where}: '${uses}' is not owner/repo@ref`); continue; }
      const key = `${k.root}@${k.ref}`;
      if (level === "job") {
        if (!isSha(k.ref)) bad.push(`${rel} ${where}: reusable workflow '${uses}' is not pinned to a 40-hex commit`);
        continue;
      }
      if (lock) {
        if (!listed || !listed.has(key)) bad.push(`${rel} ${where}: '${uses}' is not in this workflow's actions.lock entry`);
        else if (!lock.resolved.has(key)) bad.push(`${rel} ${where}: '${uses}' has no dependency record that resolves to a commit`);
      } else if (!isSha(k.ref)) {
        bad.push(`${rel} ${where}: '${uses}' is not pinned to a 40-hex commit`);
      }
    }
  }

  if (bad.length) {
    console.log("\nERROR: unpinned or unlocked action refs:");
    for (const b of bad) console.log(`  ${b}`);
    console.log("\nPin to a full commit SHA, or run `gh actions-lock` so this workflow's lock entry resolves the ref.");
    return 1;
  }
  console.log(`all ${count} action ref(s) in ${files.length} workflow(s) are pinned`);
  return 0;
}

process.exit(main());
