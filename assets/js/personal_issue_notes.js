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
    this.debounceTimer = null;
    this.badgeTimer = null;
    this.debounceDelay = 500; // milliseconds — push to server
    this.badgeDelay = 120;    // milliseconds — purely local badge refresh

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
    if (this.debounceTimer) clearTimeout(this.debounceTimer);
    if (this.badgeTimer) clearTimeout(this.badgeTimer);
  },

  loadNotes() {
    const storageKey = `planning_poker_notes_${this.participantId}`;
    const storedNotes = localStorage.getItem(storageKey);

    if (storedNotes) {
      try {
        const notes = JSON.parse(storedNotes);
        this.pushEvent("sync_notes", { notes: notes });

        const note = notes[this.issueId] || "";
        if (this.el.value !== note) {
          this.el.value = note;
        }
        this.refreshBadge(this.el.value);
      } catch (e) {
        console.error("Failed to parse notes from localStorage:", e);
      }
    } else {
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
