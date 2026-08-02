# npm-trusted-publish-action

Publish npm packages with trusted publishing (OIDC) using release-type aware channel selection.

For stable releases (`patch`, `minor`, `major`) with `add-next-tag-on-stable: true` (default), this action treats moving the `next` dist-tag as a required step and fails the job if the mutation or verification fails.

If `package-name` and `version` are provided and that exact version is already on npm, the action enters recovery mode: it skips `npm publish`, continues with required stable `next` dist-tag mutation/verification, and exits successfully when reconciliation succeeds.

## Prerequisites

To use this action in a real publish pipeline, the package must be configured for npm trusted publishing and the workflow must be allowed to mint an OIDC token.

- In GitHub, grant the workflow job, as shown in the example below, `permissions: id-token: write` and `permissions: contents: read`.
- In npm, enable trusted publishing for the package and register the GitHub repository/workflow that will publish it.
- The job should run from the repository and workflow name you configured in npm, otherwise npm will reject the publish request.
- For a normal publish pipeline, use `actions/setup-node` with `registry-url: https://registry.npmjs.org` before running the action.
- For stable releases with `add-next-tag-on-stable: true`, the action exchanges the GitHub OIDC token for a short-lived npm registry token and uses it to run `npm dist-tag add ... next`.

Public docs: https://docs.npmjs.com/trusted-publishing

## Inputs

- `release-type`: `prerelease | patch | minor | major` (default: `prerelease`)
- `package-name`: required for stable releases when `add-next-tag-on-stable` is `true`
- `version`: required for stable releases when `add-next-tag-on-stable` is `true`
- `package-path`: path containing `package.json` (default: `.`)
- `access`: `public | restricted` (default: `public`)
- `tag-override`: optional explicit publish tag
- `add-next-tag-on-stable`: for stable releases, move and verify `next` dist-tag (default: `true`)
- `dry-run`: print commands without publishing (default: `false`)

## Outputs

- `published`: `true` when `npm publish` was executed in this run
- `already-published`: `true` when `package-name@version` already existed and publish was skipped
- `tag`: resolved publish tag
- `is-prerelease`: whether the release type was prerelease

## Example

```yaml
name: Release

on:
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  publish:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: 24
          registry-url: https://registry.npmjs.org
      - run: npm ci
      - run: npm run build

      - name: Publish package
        uses: vscheuber/npm-trusted-publish-action@v1
        with:
          release-type: prerelease
          package-name: '@my-scope/my-package'
          version: 1.2.3-1
```
