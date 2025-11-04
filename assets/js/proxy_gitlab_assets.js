/**
 * ProxyGitLabAssets Hook
 *
 * Rewrites GitLab asset URLs (images, videos) to use the local proxy endpoint.
 * This works around cross-domain cookie issues in Firefox where cookies aren't
 * sent for cross-origin image requests.
 *
 * Transforms URLs like:
 *   https://gitlab.sys.mixxt.net/uploads/foo/bar.png
 * To:
 *   /proxy/uploads/foo/bar.png
 */

export default {
  mounted() {
    this.rewriteGitLabUrls();
  },

  updated() {
    this.rewriteGitLabUrls();
  },

  rewriteGitLabUrls() {
    // Get GitLab site URL from data attribute
    const gitlabSite = this.el.dataset.gitlabSite;
    if (!gitlabSite) {
      console.warn("ProxyGitLabAssets hook: data-gitlab-site attribute not found");
      return;
    }

    // Find all images and videos with GitLab URLs
    const assets = this.el.querySelectorAll(`img[src^="${gitlabSite}/uploads/"], video[src^="${gitlabSite}/uploads/"]`);

    assets.forEach(asset => {
      const originalSrc = asset.src;

      // Check if already proxied to avoid double-rewriting
      if (!originalSrc.startsWith("/proxy/")) {
        // Replace GitLab domain with local proxy path
        const proxiedSrc = originalSrc.replace(`${gitlabSite}/uploads/`, "/proxy/uploads/");
        asset.src = proxiedSrc;
      }
    });
  }
};
