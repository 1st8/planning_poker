// Add logic to handle the triple-click event for showing hidden admin buttons
let clickCount = 0;
let clickTimeout;

document.body.addEventListener("click", () => {
  clickCount++;
  if (clickCount === 3) {
    // Show all buttons with the recently_opened class
    document.querySelectorAll(".recently_opened.hidden").forEach((button) => {
      button.classList.remove("hidden");
    });
    clickCount = 0;
  }

  clearTimeout(clickTimeout);
  clickTimeout = setTimeout(() => {
    clickCount = 0;
  }, 500); // Reset click count after 500ms
});
