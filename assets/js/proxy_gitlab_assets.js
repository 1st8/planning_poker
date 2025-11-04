/**
 * ProxyGitLabAssets Hook
 *
 * Rewrites GitLab project upload URLs (images, videos) to use the local proxy endpoint.
 * This works around cross-domain cookie issues in Firefox where cookies aren't
 * sent for cross-origin image requests.
 *
 * Transforms URLs like:
 *   https://gitlab.sys.mixxt.net/-/project/25/uploads/abc123/image.jpg
 * To:
 *   /proxy/project/25/uploads/abc123/image.jpg
 */

export default {
  mounted() {
    this.rewriteGitLabUrls();
  },

  updated() {
    this.rewriteGitLabUrls();
  },

  rewriteGitLabUrls() {
    // Get project ID from data attribute
    const projectId = this.el.dataset.projectId;
    console.log("[ProxyGitLabAssets] Project ID:", projectId);

    if (!projectId) {
      console.warn("ProxyGitLabAssets hook: data-project-id attribute not found");
      return;
    }

    // Find all images and videos with GitLab upload URLs
    // Pattern: /uploads/:hash/:filename (from our markdown renderer)
    const assets = this.el.querySelectorAll('img[src^="/uploads/"], video[src^="/uploads/"]');
    console.log("[ProxyGitLabAssets] Found assets:", assets.length);

    assets.forEach(asset => {
      const originalSrc = asset.getAttribute('src');
      console.log("[ProxyGitLabAssets] Processing:", originalSrc);

      // Check if already proxied to avoid double-rewriting
      if (!originalSrc.startsWith("/proxy/")) {
        // Pattern: /uploads/467af08891cb18bb726bcc3b1d4c098e/225434.jpg
        // Rewrite to: /proxy/project/25/uploads/467af08891cb18bb726bcc3b1d4c098e/225434.jpg
        const proxiedSrc = `/proxy/project/${projectId}${originalSrc}`;
        console.log("[ProxyGitLabAssets] Rewriting to:", proxiedSrc);
        asset.src = proxiedSrc;
      } else {
        console.log("[ProxyGitLabAssets] Already proxied, skipping");
      }
    });
  }
};
