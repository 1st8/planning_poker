/**
 * AutoResizeTextarea Hook
 *
 * Automatically resizes a textarea to fit its content as the user types.
 */
const AutoResizeTextarea = {
  mounted() {
    this.resize()
    this.el.addEventListener('input', () => this.resize())
  },

  updated() {
    this.resize()
  },

  resize() {
    // Reset height to auto to get the correct scrollHeight
    this.el.style.height = 'auto'
    // Set height to scrollHeight to fit all content
    this.el.style.height = this.el.scrollHeight + 'px'
  }
}

export default AutoResizeTextarea
