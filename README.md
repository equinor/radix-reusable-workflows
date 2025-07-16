# radix-reusable-workflows

A collection of reusable GitHub workflows used by Radix.

# List of reusable workflows

## template-prepare-release-pr

A GitHub workflow to automate creation of pull requests for stable- and pre-release versions from [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/). This workflow is intended to be used together with the [template-create-release-from-pr](#template-create-release-from-pr) workflow, which handles the creation of GitHub release and tag from a merged pull request.

## Workflow permissions

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

### How it works

As mentioned before, this workflow is intended to be used together with the [template-create-release-from-pr](#template-create-release-from-pr) workflow. Together they handle the lifecycle of a release, from pull request to an actual GitHub release and tag.

This workflow adds label `release: pending` to the pull requests it creates. When you are ready to release, you merge the pull request and trigger the [template-create-release-from-pr](#template-create-release-from-pr) workflow, which takes a pull request number as input. It checks that the `release: pending` label is present and that the state of the pull request is `MERGED`. If both conditions are true, it creates a GitHub release and tag by reading the version defined in `version.txt` in the pull request. Afterwards it replaces the `release: pending` label with `release: tagged`.

Refer to [template-create-release-from-pr](#template-create-release-from-pr) for an example on how to trigger the release workflow.

#### Stable release pull requests

The workflow determines the next stable version based on conventional commits since the current stable version (tag), and creates a pull request if the the version must be bumped. The new version is written to the `version.txt` file, and `CHANGELOG.md` is updated to include the change log for the new version. The change log for the new version is set as the body for the pull request.

#### Pre-release pull requests

If `generate-pre-release-pr` is set to `true`, the workflow creates pre-release version pull requests (in addition to stable release PRs). It determines the next pre-release version since the latest version (both stable- and pre-release tags) and writes it to `version.txt`. The workflow does not update `CHANGELOG.md`, but it includes the changes in the pull request body.

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

## template-unreleased-prs-metadata