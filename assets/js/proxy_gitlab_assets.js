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
    // Get GitLab site URL from data attribute
    const gitlabSite = this.el.dataset.gitlabSite;
    if (!gitlabSite) {
      console.warn("ProxyGitLabAssets hook: data-gitlab-site attribute not found");
      return;
    }

    // Find all images and videos with GitLab project upload URLs
    // Pattern: https://gitlab.sys.mixxt.net/-/project/:id/uploads/:hash/:filename
    const assets = this.el.querySelectorAll(`img[src*="${gitlabSite}/-/project/"], video[src*="${gitlabSite}/-/project/"]`);

    assets.forEach(asset => {
      const originalSrc = asset.src;

      // Check if already proxied to avoid double-rewriting
      if (!originalSrc.startsWith("/proxy/")) {
        // Extract project ID and upload path using regex
        // Pattern: https://gitlab.sys.mixxt.net/-/project/25/uploads/abc123/image.jpg
        const match = originalSrc.match(/\/-\/project\/(\d+)\/(uploads\/.+)$/);

        if (match) {
          const [, projectId, uploadPath] = match;
          const proxiedSrc = `/proxy/project/${projectId}/${uploadPath}`;
          asset.src = proxiedSrc;
        }
      }
    });
  }
};
