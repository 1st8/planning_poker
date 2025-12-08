// Add logic to handle the triple-click event for showing hidden admin buttons
let clickCount = 0;
let clickTimeout;

document.body.addEventListener("click", () => {
  clickCount++;
  if (clickCount === 3) {
    // Show all elements with the triple-click-reveal class
    document.querySelectorAll(".triple-click-reveal.hidden").forEach((el) => {
      el.classList.remove("hidden");
    });
    clickCount = 0;
  }

  clearTimeout(clickTimeout);
  clickTimeout = setTimeout(() => {
    clickCount = 0;
  }, 500); // Reset click count after 500ms
});
