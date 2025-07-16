# Radix Reusable Workflows

A collection of reusable GitHub workflows used by the Radix team to handle the release workflow of Radix components.

# List of reusable workflows

## template-prepare-release-pr

A GitHub workflow to automate creation of pull requests for stable- and pre-release versions from [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/). This workflow is intended to be used together with the [template-create-release-from-pr](#template-create-release-from-pr) workflow, which handles the creation of GitHub release and tag from a merged pull request.

### How it works

As mentioned before, this workflow is intended to be used together with the [template-create-release-from-pr](#template-create-release-from-pr) workflow. Together they handle the lifecycle of a release, from pull request to an actual GitHub release and tag.

This workflow adds label `release: pending` to the pull requests it creates. When you are ready to release, you merge the pull request and trigger the [template-create-release-from-pr](#template-create-release-from-pr) workflow, which takes a pull request number as input. It checks that the `release: pending` label is present and that the state of the pull request is `MERGED`. If both conditions are true, it creates a GitHub release and tag by reading the version defined in `version.txt` in the pull request. Afterwards it replaces the `release: pending` label with `release: tagged`.

Refer to [template-create-release-from-pr](#template-create-release-from-pr) for an example on how to trigger the release workflow.

#### Stable release pull requests

The workflow determines the next stable version based on conventional commits since the current stable version (tag), and creates a pull request if the the version must be bumped. The new version is written to the `version.txt` file, and `CHANGELOG.md` is updated to include the change log for the new version. The change log for the new version is set as the body for the pull request.

#### Pre-release pull requests

If `generate-pre-release-pr` is set to `true`, the workflow creates pre-release version pull requests (in addition to stable release PRs). It determines the next pre-release version since the latest version (both stable- and pre-release tags) and writes it to `version.txt`. The workflow does not update `CHANGELOG.md`, but it includes the changes in the pull request body.

### Workflow permissions

Ensure that the repository is configured to `Allow GitHub actions to create and approve pull requests`.

The workflow uses [orhun/git-cliff-action](https://github.com/orhun/git-cliff-action) to generate the change log, and [peter-evans/create-pull-request](https://github.com/peter-evans/create-pull-request) to create the pull requests. You must therefore assure that these actions are allowed in your repository.

You can find these settings under Settings > Actions > General in your repository.

The workflow will need the following permissions in your workflow file:
```yaml
permissions:
  contents: write # Required to create and push changes to the pull request branch
  pull-requests: write # Required to create pull requests
  issues: write # Required to create labels in the repository
```

### Configuration

Create a new workflow `.github/workflows/prepare-release-pr.yml` file with the following configuration. The workflow should trigger both when commits are pushed to the default branch (`main` in our example), and when tags are pushed. Triggering on tags is required to correctly recalculate the next version for active pull requests, especially when `generate-pre-release-pr` is enabled.

```yaml
on:
  push: 
    tags:
      - '**'
    branches: 
      - main
  workflow_dispatch:

jobs:
  prepare-release-pr:
    uses: nilsgstrabo/learnrelease/.github/workflows/template-prepare-release-pr.yml@main # You should pin this to a specific commit for security reasons
    permissions:
      contents: write
      pull-requests: write
      issues: write
    with:
      branch: main
```

### Inputs

All inputs, except `branch`, are optional.

| Name | Description | Default |
| ---- | --- | --- |
| `branch` | The name of the branch to analyze commits for calculating next version. This is also used as the base branch when creating release pull requests. | |
| `stable-release-pr-branch` | The pull request branch name for stable releases. | `release-pull-request/stable-release` |
| `generate-pre-release-pr` | Generate pre-release pull requests. | `false` |
| `pre-release-version-prefix` | The prefix to use in identifier for calculating pre-release versions. For example, if this value is set to "rc" (default), the first pre-release version for version "1.5.0" will be "1.5.0-rc.1", then "1.5.0-rc.2", and so on. | `rc` |
| `pre-release-pr-branch` | The pull request branch name for pre-releases. | `release-pull-request/pre-release` |
| `version-file-path` | The path to the file where the new version is written to. | `version.txt` |
| `changelog-path` | The path to the changelog to update for stable release pull requests. | `CHANGELOG.md` |
| `cliff-config-path` | The path to cliff.toml configuration file, used to configure the layout of the changelog. See https://git-cliff.org/docs/configuration/ for more information. git-cliff will use default configuration if this value is unset. |  |
| `extra-files` | A space or newline separated list of files to update with new version number. For each file, the workflow will look for lines containing the text '# x-patch-semver', and replace anything that matches a semver version with the new version. |  |

### Outputs

| Name | Description |
| ---- | --- |
| `stable-release-pull-request-number` | The stable release pull request number. |
| `stable-release-pull-request-operation` | The stable release pull request operation performed by the workflow. |
| `pre-release-pull-request-number` | The pre-release pull request number. |
| `pre-release-pull-request-operation` | The pre-release pull request operation performed by the workflow. |


## template-create-release-from-pr

A GitHub workflow that creates release and tag from a merged pull request with label `release: pending`. These pull requests should be created from the [template-prepare-release-pr](#template-prepare-release-pr) workflow to ensure that the GitHub release contains a proper change log and version.

### How it works

The workflow reads the pull request given in the `pull-request-number` input, and checks that the state is `MERGED` and that label `release: pending` exists. If these conditions are not met, the workflow exits with code 0 and sets the `release-result` output to `skipped`.

If the above conditions are met, the workflow tries to read the `version.txt` file from the pull request merge commit, and verify that the value is a valid sermver version. The workflow exists with a non-zero exit code if reading the file or verifying the version fails.

When all conditions are met, the workflow creates a GitHub release and tag (prefixing the version from `version.txt` with `v`) for the pull request commit. The pull request body is used as notes for the release. If the version is a pre-release then the GitHub release is also marked as a pre-release.

After the release is successfully created, the workflow removes the `release: pending` label and adds a `release: tagged` label.

### Workflow permissions

In order to create a release for specific commit, [GitHub requires a token with `workflow:write` permissions](https://github.blog/changelog/2023-11-02-github-actions-enforcing-workflow-scope-when-creating-a-release/). These permissions cannot be granted to the workflow's `secrets.GITHUB_TOKEN` or `github.token`. Instead you must use a PAT token or GitHub App token with `workflow:write` and `content:write` permissions. You can specify a token directly in the `release-token` secret, or you can have the workflow create an GitHub App token by setting `use-github-app-token` to `true` and specifying the GitHub App ID in `github-app-id` and corresponding private key in `github-app-private-key`.

Read [Installing your own GitHub App](https://docs.github.com/en/apps/using-github-apps/installing-your-own-github-app#installing-your-private-github-app-on-your-repository) for instruction on how to create and install a GitHub App.

The workflow will need the following permissions in your workflow file:
```yaml
permissions:
  pull-requests: write # Read pull request and write labels
  contents: read # Read the `version.txt` file from the repository
```

### Configuration

Example using PAT token stored in repository secret `RELEASE_TOKEN`:
```yaml
on:
  workflow_dispatch:
    inputs:
      pr-number:
        description: The pull request to release
        type: string
        required: true
  
jobs:
  release-pull-request:
    name: Release pull request
    permissions:
      pull-requests: write
      contents: read
    uses: nilsgstrabo/learnrelease/.github/workflows/template-create-release-from-pr.yml@main
    with:
      pull-request-number: ${{ inputs.pr-number }}
    secrets:
      release-token: ${{ secrets.RELEASE_TOKEN }}
```

Example using GitHub App ID, stored in repository variable `GH_APP_ID`, and corresponding private key, stored in repository secret `GH_APP_PRIVATE_KEY`:
```yaml
on:
  workflow_dispatch:
    inputs:
      pr-number:
        description: The pull request to release
        type: string
        required: true
  
jobs:
  release-pull-request:
    name: Release pull request
    permissions:
      pull-requests: write
      contents: read
    uses: nilsgstrabo/learnrelease/.github/workflows/template-create-release-from-pr.yml@main
    with:
      pull-request-number: ${{ inputs.pr-number }}
      github-app-id: ${{ vars.GH_APP_ID }}
      use-github-app-token: true
    secrets:
      github-app-private-key: ${{ secrets.GH_APP_PRIVATE_KEY }}      
```

### Inputs

Input `pull-request-number` is required. If `use-github-app-token` is `false` (default) then `release-token` must be provided, and if `use-github-app-token` is `true` then `github-app-id` and `github-app-private-key` must be provided.

| Name | Description | Default |
| ---- | --- | --- |
| `pull-request-number` | The pull request number to create release and tag from. |  |
| `version-file-path` | The path to the file where the new version is read from. | `version.txt` |
| `use-github-app-token` | Use GitHub App to make authenticated request for creating release and tag. When true, requires `github-app-id` and `github-app-private-key` to be set. When set to false, requires a token (PAT) to be set in `gh-release-token`. | `false` |
| `github-app-id` | The GitHub App ID to use for authentication when `use-github-app-token` is `true`. |  |
| `github-app-owner` | The GitHub App owner to use for authentication when `use-github-app-token` is `true`. Defaults to the owner of the current repo if not set. |  |
| `github-app-repositories` | Comma or newline-separated list of repositories to grant access to for GitHub App when `use-github-app-token` is `true`. If `github-app-owner` is set and `github-app-repositories` is empty, access will be scoped to all repositories the GitHub App is installed in. If `github-app-owner` and `github-app-repositories` are empty, access will be scoped to only the current repository. |  |
| `release-token` | A Github token with permission to create GitHub release for a specific target commit. Required when `use-github-app-token` is `false`. |  |
| `github-app-private-key` | The private key for the GitHub App defined by `github-app-id`. Required when `use-github-app-token` is `true`. |  |

### Outputs

| Name | Description |
| ---- | --- |
| `release-result` | The result of the release job. Possible values are success, failure, cancelled, or skipped. |
| `version` | The version that was released. |
| `tag` | The tag that was released. |
| `commit` | The commit that was released. |
| `is-prerelease` | Release is marked as pre-release. |

## template-unreleased-prs-metadata

### How it works

### Workflow permissions

### Configuration

### Inputs

### Outputs