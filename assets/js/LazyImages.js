function transform(el) {
  const baseUrl = el.dataset.baseUrl;
  el.querySelectorAll("img.lazy").forEach((image) => {
    image.src = baseUrl + image.dataset.src;
  });
}

export default {
  mounted() {
    transform(this.el);
  },
  updated() {
    transform(this.el);
  },
};
