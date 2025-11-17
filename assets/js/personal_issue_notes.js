/**
 * PersonalIssueNotes Hook
 *
 * Manages personal notes for issues in localStorage.
 * Notes are stored client-side and synced to server for display.
 */

export default {
  mounted() {
    this.issueId = this.el.dataset.issueId;
    this.participantId = this.el.dataset.participantId;
    this.debounceTimer = null;
    this.debounceDelay = 500; // milliseconds

    // Load notes from localStorage
    this.loadNotes();

    // Listen for input events
    this.el.addEventListener("input", this.handleInput.bind(this));

    // Listen for server event to append transcription to notes
    this.handleEvent("append_to_personal_notes", (payload) => {
      // Only append if this is the correct issue
      if (payload.issue_id === this.issueId) {
        // Append text to textarea
        const currentValue = this.el.value;
        const newValue = currentValue + payload.text;
        this.el.value = newValue;

        // Save immediately (without debounce)
        this.saveNote(newValue);
      }
    });
  },

  updated() {
    // When the issue changes, reload the note for the new issue
    const newIssueId = this.el.dataset.issueId;
    if (newIssueId !== this.issueId) {
      this.issueId = newIssueId;
      this.loadNotes();
    }
  },

  destroyed() {
    // Clean up debounce timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }
  },

  loadNotes() {
    const storageKey = `planning_poker_notes_${this.participantId}`;
    const storedNotes = localStorage.getItem(storageKey);

    if (storedNotes) {
      try {
        const notes = JSON.parse(storedNotes);
        // Send all notes to server for rendering in other components
        this.pushEvent("sync_notes", { notes: notes });

        // Update textarea with current issue's note
        const note = notes[this.issueId] || "";
        if (this.el.value !== note) {
          this.el.value = note;
        }
      } catch (e) {
        console.error("Failed to parse notes from localStorage:", e);
      }
    }
  },

  handleInput(event) {
    const content = event.target.value;

    // Clear existing debounce timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }

    // Set new debounce timer
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
  }
};
