// Manages personal notes for issues in localStorage and renders a small
// "parses as …" badge while the textarea is in magic-estimation mode.
// Magic-hint collection for consensus is decoupled from this hook — see
// magic_hints_resync.js, which responds to a server request in
// :magic_estimation rather than pushing on every keystroke.

import { parse, formatBadge } from "./magic_estimation/note_parser";

export default {
  mounted() {
    this.issueId = this.el.dataset.issueId;
    this.participantId = this.el.dataset.participantId;
    this.syncTimer = null;
    this.badgeTimer = null;
    this.syncDelay = 500;  // milliseconds — push sync_notes to server
    this.badgeDelay = 120; // milliseconds — purely local badge refresh

    this.badgeEl = this.ensureBadge();

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
    if (this.badgeTimer) clearTimeout(this.badgeTimer);
    if (this.syncTimer) clearTimeout(this.syncTimer);
  },

  loadNotes() {
    const notes = this.readNotes();
    this.pushEvent("sync_notes", { notes });

    const note = notes[this.issueId] || "";
    if (this.el.value !== note) {
      this.el.value = note;
    }
    this.refreshBadge(this.el.value);
  },

  handleInput(event) {
    const content = event.target.value;

    // localStorage is the authoritative source for magic-hint collection
    // (MagicHintsResync reads it when the server pushes request_magic_hints).
    // back_to_lobby can fire well within any debounce window, so we persist
    // synchronously on every keystroke — localStorage writes are cheap.
    this.persistLocalNote(content);

    // Fast-path: update the badge with a short debounce so typing feels
    // responsive.
    if (this.badgeTimer) clearTimeout(this.badgeTimer);
    this.badgeTimer = setTimeout(() => this.refreshBadge(content), this.badgeDelay);

    // Slow-path: only the server `sync_notes` push (used to render notes
    // alongside cards in magic-estimation) is debounced.
    if (this.syncTimer) clearTimeout(this.syncTimer);
    this.syncTimer = setTimeout(() => {
      this.pushEvent("sync_notes", { notes: this.readNotes() });
    }, this.syncDelay);
  },

  readNotes() {
    const storageKey = `planning_poker_notes_${this.participantId}`;
    const raw = localStorage.getItem(storageKey);
    if (!raw) return {};
    try {
      return JSON.parse(raw);
    } catch (_) {
      return {};
    }
  },

  persistLocalNote(content) {
    const storageKey = `planning_poker_notes_${this.participantId}`;
    const notes = this.readNotes();

    if (content.trim() === "") {
      delete notes[this.issueId];
    } else {
      notes[this.issueId] = content;
    }

    localStorage.setItem(storageKey, JSON.stringify(notes));
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
