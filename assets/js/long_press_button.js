const LongPressButton = {
  mounted() {
    const button = this.el;
    const minPressTime = 800; // milliseconds for long press
    let pressTimer = null;
    let startTime = 0;
    let isAnimating = false;

    // Progress display
    const progressIndicator = document.createElement('div');
    progressIndicator.className = 'long-press-progress';
    button.style.position = 'relative';
    button.style.overflow = 'hidden';
    progressIndicator.style.position = 'absolute';
    progressIndicator.style.left = '0';
    progressIndicator.style.bottom = '0';
    progressIndicator.style.height = '4px';
    progressIndicator.style.width = '0%';
    progressIndicator.style.backgroundColor = 'rgba(255, 255, 255, 0.5)';
    progressIndicator.style.transition = 'width 800ms linear';
    button.appendChild(progressIndicator);

    // Touch/mouse events
    const startPress = () => {
      if (pressTimer === null) {
        startTime = Date.now();
        isAnimating = true;
        progressIndicator.style.width = '100%';
        
        pressTimer = setTimeout(() => {
          triggerAction();
        }, minPressTime);
      }
    };

    const endPress = () => {
      if (pressTimer !== null) {
        clearTimeout(pressTimer);
        pressTimer = null;
        
        if (isAnimating) {
          progressIndicator.style.transition = 'width 0.1s ease-out';
          progressIndicator.style.width = '0%';
          setTimeout(() => {
            progressIndicator.style.transition = 'width 800ms linear';
            isAnimating = false;
          }, 100);
        }
      }
    };

    const triggerAction = () => {
      // Push the event to the server
      this.pushEvent(button.dataset.action || 'long_press');
      
      // Reset the button state
      progressIndicator.style.transition = 'width 0.1s ease-out';
      progressIndicator.style.width = '0%';
      setTimeout(() => {
        progressIndicator.style.transition = 'width 800ms linear';
        isAnimating = false;
      }, 100);
      
      pressTimer = null;
    };

    // Add event listeners
    button.addEventListener('mousedown', startPress);
    button.addEventListener('touchstart', startPress);
    button.addEventListener('mouseup', endPress);
    button.addEventListener('mouseleave', endPress);
    button.addEventListener('touchend', endPress);
    button.addEventListener('touchcancel', endPress);

    // Prevent default click
    button.addEventListener('click', (e) => {
      e.preventDefault();
    });

    // Cleanup on destroy
    this.destroy = () => {
      button.removeEventListener('mousedown', startPress);
      button.removeEventListener('touchstart', startPress);
      button.removeEventListener('mouseup', endPress);
      button.removeEventListener('mouseleave', endPress);
      button.removeEventListener('touchend', endPress);
      button.removeEventListener('touchcancel', endPress);
      button.removeEventListener('click', (e) => { e.preventDefault(); });
      
      if (pressTimer) {
        clearTimeout(pressTimer);
      }
    };
  },
  
  destroyed() {
    if (this.destroy) {
      this.destroy();
    }
  }
};

export default LongPressButton;
