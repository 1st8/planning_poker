// Server-driven re-sync of magic-estimation hints from localStorage.
// The hook is mounted on #magic-estimation-container and waits for a
// `request_magic_hints` event from the server (carrying the list of
// issue ids currently in the magic estimation session). Only hints for
// those ids are pushed back, so notes from prior sessions or unrelated
// issues stay out of the consensus aggregation.

import { rawHead } from "./magic_estimation/note_parser";

export default {
  mounted() {
    this.participantId = this.el.dataset.participantId;
    this.handleEvent("request_magic_hints", ({ issue_ids }) =>
      this.pushHintsFor(issue_ids),
    );
  },

  updated() {
    this.participantId = this.el.dataset.participantId;
  },

  pushHintsFor(issueIds) {
    if (!this.participantId) return;
    const allowed = new Set(Array.isArray(issueIds) ? issueIds : []);
    const raw = localStorage.getItem(
      `planning_poker_notes_${this.participantId}`,
    );

    let notes = {};
    if (raw) {
      try {
        notes = JSON.parse(raw);
      } catch (_) {
        notes = {};
      }
    }

    const hints = {};
    for (const [issueId, body] of Object.entries(notes || {})) {
      if (!allowed.has(issueId)) continue;
      if (typeof body !== "string") continue;
      if (body.trim() === "") continue;
      hints[issueId] = { raw_head: rawHead(body) };
    }

    this.pushEvent("sync_magic_hints", { hints });
  },
};
