# PlanningPoker

Select and estimate the weight of issues in a planning poker session.

## Configuration

The application can be configured using the following environment variables:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| SECRET_KEY_BASE | Used to sign/encrypt cookies and other secrets. You can generate a suitable value using `mix phx.gen.secret` if you have Elixir installed, or use a secure random string generator. | None | Yes |
| PHX_HOST | Sets the host name for URL generation. Used for setting the host in the endpoint configuration and generating OAuth callback URLs. | `example.com` | No |
| PORT | Sets the port on which the HTTP server will listen. | `4000` | No |
| GITLAB_SITE | The base URL of the GitLab instance used for OAuth authentication and API calls. | `https://gitlab.com` | No |
| GITLAB_CLIENT_ID | The OAuth client ID for GitLab authentication. | None | Yes (for GitLab auth) |
| GITLAB_CLIENT_SECRET | The OAuth client secret for GitLab authentication. | None | Yes (for GitLab auth) |
| DEFAULT_LIST_ID | Determines which list (from an issue board in GitLab) the issues for planning are loaded from. This is a temporary variable that might be replaced by a UI for defining issue selectors in the future. | `9945417` | No |

The GitLab authentication variables (`GITLAB_CLIENT_ID` and `GITLAB_CLIENT_SECRET`) can be obtained by creating a GitLab application under User Settings > Applications in GitLab. The `api` scope is required. The Callback URL should be set to `https://your-domain.com/auth/gitlab/callback` (replace `your-domain.com` with your actual domain).

## Using the Docker Image

To run the container:

```bash
docker run -p 4000:4000 \
  -e SECRET_KEY_BASE=your_secret_key_base \
  -e PHX_HOST=your-domain.com \
  -e PORT=4000 \
  -e GITLAB_SITE=https://gitlab.com \
  -e GITLAB_CLIENT_ID=your_gitlab_client_id \
  -e GITLAB_CLIENT_SECRET=your_gitlab_client_secret \
  -e DEFAULT_LIST_ID=your_list_id \
  ghcr.io/1st8/planning_poker:main
```

The `SECRET_KEY_BASE` environment variable is required for the application to run. The `GITLAB_CLIENT_ID` and `GITLAB_CLIENT_SECRET` variables are required if you want to use GitLab authentication. The `PHX_HOST`, `PORT`, `GITLAB_SITE`, and `DEFAULT_LIST_ID` variables are optional and will use their default values if not specified.
