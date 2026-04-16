/**
 * PersonalIssueNotes Hook
 *
 * Manages personal notes for issues in localStorage.
 * Notes are stored client-side and synced to server for display.
 *
 * In addition to the existing `sync_notes` event (which carries the full
 * notes map for rendering in the owning participant's own UI only), this
 * hook emits `sync_magic_hints` — a compact per-issue hint map:
 *
 *     { issueId: { raw_head: "first 32 chars after stripping commentary",
 *                  client_parse: {ok: 5} | "abstain" | "unparseable" } }
 *
 * The hint map intentionally leaves raw prose in the browser: only the
 * first 32 chars (trimmed, cut at the first newline / `(` / `,`) travel to
 * the server. The server reparses those heads authoritatively for the
 * magic-auto-sort aggregation (see subtask 67e7d711).
 *
 * Badge visibility: the "parses as …" badge is only shown when the
 * textarea carries `data-magic-mode="true"` (i.e. the session is in
 * magic-estimation voting). The PersonalIssueNotesComponent is already
 * only rendered in that state, so the gate is belt-and-suspenders.
 */

import { hintFor, parse, formatBadge } from "./magic_estimation/note_parser";

export default {
  mounted() {
    this.issueId = this.el.dataset.issueId;
    this.participantId = this.el.dataset.participantId;
    this.debounceTimer = null;
    this.badgeTimer = null;
    this.debounceDelay = 500; // milliseconds — push to server
    this.badgeDelay = 120;    // milliseconds — purely local badge refresh

    this.badgeEl = this.ensureBadge();

    // Load notes from localStorage (also re-emits hints for reconnect/reload).
    this.loadNotes();

    // Listen for input events
    this.handleInputBound = this.handleInput.bind(this);
    this.el.addEventListener("input", this.handleInputBound);
  },

  updated() {
    // When the issue changes, reload the note for the new issue
    const newIssueId = this.el.dataset.issueId;
    if (newIssueId !== this.issueId) {
      this.issueId = newIssueId;
      this.badgeEl = this.ensureBadge();
      this.loadNotes();
    }
    this.refreshBadge(this.el.value);
  },

  destroyed() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer);
    if (this.badgeTimer) clearTimeout(this.badgeTimer);
  },

  loadNotes() {
    const storageKey = `planning_poker_notes_${this.participantId}`;
    const storedNotes = localStorage.getItem(storageKey);

    if (storedNotes) {
      try {
        const notes = JSON.parse(storedNotes);
        // Send all notes to server for rendering in other components
        this.pushEvent("sync_notes", { notes: notes });
        // Re-emit the full hint map so reconnect/reload resyncs the
        // server-side aggregation.
        this.pushEvent("sync_magic_hints", { hints: this.buildHints(notes) });

        // Update textarea with current issue's note
        const note = notes[this.issueId] || "";
        if (this.el.value !== note) {
          this.el.value = note;
        }
        this.refreshBadge(this.el.value);
      } catch (e) {
        console.error("Failed to parse notes from localStorage:", e);
      }
    } else {
      // No stored notes — still push an empty hint map on mount so the
      // server's assigns reflect reality for this participant.
      this.pushEvent("sync_magic_hints", { hints: {} });
      this.refreshBadge(this.el.value);
    }
  },

  handleInput(event) {
    const content = event.target.value;

    // Fast-path: update the badge with a short debounce so typing feels
    // responsive. No server round-trip here.
    if (this.badgeTimer) clearTimeout(this.badgeTimer);
    this.badgeTimer = setTimeout(() => this.refreshBadge(content), this.badgeDelay);

    // Slow-path: persist + push with the full 500ms debounce.
    if (this.debounceTimer) clearTimeout(this.debounceTimer);
    this.debounceTimer = setTimeout(() => {
      this.saveNote(content);
    }, this.debounceDelay);
  },

  saveNote(content) {
    const storageKey = `planning_poker_notes_${this.participantId}`;

    // Load existing notes
    let notes = {};
    const storedNotes = localStorage.getItem(storageKey);
    if (storedNotes) {
      try {
        notes = JSON.parse(storedNotes);
      } catch (e) {
        console.error("Failed to parse notes from localStorage:", e);
      }
    }

    // Update note for current issue
    if (content.trim() === "") {
      // Remove empty notes
      delete notes[this.issueId];
    } else {
      notes[this.issueId] = content;
    }

    // Save to localStorage
    localStorage.setItem(storageKey, JSON.stringify(notes));

    // Send updated notes to server for rendering
    this.pushEvent("sync_notes", { notes: notes });
    this.pushEvent("sync_magic_hints", { hints: this.buildHints(notes) });
  },

  /**
   * Build the per-issue hint map from the raw notes map. Issues with
   * empty-after-trim notes are omitted so the server sees "no hint" rather
   * than an explicit abstain for issues the user hasn't touched.
   */
  buildHints(notes) {
    const hints = {};
    if (!notes || typeof notes !== "object") return hints;
    for (const [issueId, raw] of Object.entries(notes)) {
      if (typeof raw !== "string") continue;
      if (raw.trim() === "") continue;
      hints[issueId] = hintFor(raw);
    }
    return hints;
  },

  ensureBadge() {
    // Place a small muted badge immediately after the textarea. Reuse any
    // existing badge (e.g. when LV re-renders the textarea in place).
    const existingId = `personal-notes-badge-${this.issueId}`;
    let badge = document.getElementById(existingId);
    if (badge) return badge;

    badge = document.createElement("p");
    badge.id = existingId;
    badge.className = "text-xs text-base-content/50 italic";
    badge.setAttribute("aria-live", "polite");
    badge.dataset.role = "magic-parse-badge";
    this.el.insertAdjacentElement("afterend", badge);
    return badge;
  },

  refreshBadge(content) {
    if (!this.badgeEl || !this.badgeEl.isConnected) {
      this.badgeEl = this.ensureBadge();
    }

    // Gate visibility: only show the badge while the host LV explicitly
    // marks the textarea as being in magic-estimation mode. The component
    // itself is only rendered in that state, but the `data-magic-mode`
    // attribute makes the contract explicit and keeps this hook reusable.
    const magicMode = this.el.dataset.magicMode === "true";
    if (!magicMode) {
      this.badgeEl.textContent = "";
      return;
    }

    const trimmed = (content || "").trim();
    if (trimmed === "") {
      this.badgeEl.textContent = "";
      return;
    }

    const result = parse(content);
    const label = formatBadge(result, content);
    this.badgeEl.textContent = label || "";
  },
};
