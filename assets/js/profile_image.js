// ProfileImage hook: Handles image load failures and notifies the server
// to trigger fallback to Gravatar or initials-based images
export default {
  mounted() {
    this.handleError = () => {
      // Push event to the LiveComponent to trigger fallback
      this.pushEvent("image_load_failed", {});
    };

    this.el.addEventListener('error', this.handleError);
  },

  destroyed() {
    // Clean up event listener when the hook is destroyed
    this.el.removeEventListener('error', this.handleError);
  }
};
