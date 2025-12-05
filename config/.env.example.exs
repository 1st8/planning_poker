# Issue Provider Configuration
# Determines which issue tracking system to use
# Options: "mock" (local development), "gitlab" (production)
# Defaults: mock in dev/test, gitlab in prod
System.put_env("ISSUE_PROVIDER", "mock")

# GitLab OAuth Configuration (only needed when ISSUE_PROVIDER=gitlab)
# Create an OAuth application at: https://gitlab.com/-/profile/applications
# Redirect URI should be: http://localhost:4000/auth/gitlab/callback
# System.put_env("GITLAB_CLIENT_ID", "your-client-id")
# System.put_env("GITLAB_CLIENT_SECRET", "your-client-secret")
# System.put_env("GITLAB_SITE", "https://gitlab.com")  # Optional, defaults to gitlab.com
# System.put_env("DEFAULT_LIST_ID", "9945417")  # Optional, board list ID to fetch issues from

# Mock Provider Authentication (only when ISSUE_PROVIDER=mock)
# Navigate to these URLs to login as different users for testing collaboration:
# - http://localhost:4000/auth/mock/alice
# - http://localhost:4000/auth/mock/bob
# - http://localhost:4000/auth/mock/carol
