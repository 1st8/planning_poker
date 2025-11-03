/**
 * SectionEditor Hook
 *
 * Handles real-time collaborative editing of issue description sections.
 * Debounces input to avoid overwhelming the server with updates.
 */

export default {
  mounted() {
    this.sectionId =
      this.el.dataset.sectionId ||
      this.el.closest("[data-section-id]")?.dataset.sectionId;
    this.debounceTimer = null;
    this.debounceDelay = 300; // milliseconds

    // Get the component target for pushEventTo
    this.componentTarget = this.el.getAttribute("phx-target");

    // Focus the textarea when mounted (section just got locked)
    this.el.focus();

    // Move cursor to end of text
    const length = this.el.value.length;
    this.el.setSelectionRange(length, length);

    // Listen for input events
    this.el.addEventListener("input", this.handleInput.bind(this));

    // Listen for keyboard shortcuts
    this.el.addEventListener("keydown", this.handleKeydown.bind(this));
  },

  updated() {},

  destroyed() {
    // Clean up debounce timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
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
      this.pushUpdate(content);
    }, this.debounceDelay);
  },

  handleKeydown(event) {
    // Cmd/Ctrl + Enter to finish editing
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault();
      this.finishEditing();
    }

    // Escape to cancel/unlock
    if (event.key === "Escape") {
      event.preventDefault();
      this.finishEditing();
    }
  },

  pushUpdate(content) {
    // Send update to server - target the LiveComponent
    if (this.componentTarget) {
      this.pushEventTo(this.componentTarget, "update_section_content", {
        section_id: this.sectionId,
        content: content,
      });
    } else {
      // Fallback to parent LiveView if no target specified
      this.pushEvent("update_section_content", {
        section_id: this.sectionId,
        content: content,
      });
    }
  },

  finishEditing() {
    // Trigger blur which will unlock the section
    this.el.blur();
  },
};
