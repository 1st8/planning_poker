// Add logic to handle the triple-click event for showing the kill button
let clickCount = 0;
let clickTimeout;

document.body.addEventListener("click", () => {
  clickCount++;
  if (clickCount === 3) {
    const killButton = document.getElementById("kill-button");
    if (killButton) {
      killButton.classList.remove("hidden");
    }
    clickCount = 0;
  }

  clearTimeout(clickTimeout);
  clickTimeout = setTimeout(() => {
    clickCount = 0;
  }, 500); // Reset click count after 500ms
});
