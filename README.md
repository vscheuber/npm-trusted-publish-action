# npm-trusted-publish-action

Publish npm packages with trusted publishing (OIDC) using release-type aware channel selection.

If `package-name` and `version` are provided and that exact version is already on npm, the action enters recovery mode: it skips `npm publish` and exits successfully.

When `dual-release-on-stable: true` and `release-type` is stable (`patch`, `minor`, `major`), the action performs a dual publish without dist-tag mutation:

- publish companion prerelease `x.y.z-n` to `next`
- publish stable `x.y.z` to `latest`

This keeps `next` aligned without relying on `npm dist-tag add`.

## Prerequisites

To use this action in a real publish pipeline, the package must be configured for npm trusted publishing and the workflow must be allowed to mint an OIDC token.

- In GitHub, grant the workflow job, as shown in the example below, `permissions: id-token: write` and `permissions: contents: read`.
- In npm, enable trusted publishing for the package and register the GitHub repository/workflow that will publish it.
- The job should run from the repository and workflow name you configured in npm, otherwise npm will reject the publish request.
- For a normal publish pipeline, use `actions/setup-node` with `registry-url: https://registry.npmjs.org` before running the action.

Public docs: https://docs.npmjs.com/trusted-publishing

## Inputs

- `release-type`: `prerelease | patch | minor | major` (default: `prerelease`)
- `package-name`: optional; used for already-published detection when `version` is also provided
- `version`: optional; used with `package-name` for already-published detection
- `package-path`: path containing `package.json` (default: `.`)
- `access`: `public | restricted` (default: `public`)
- `tag-override`: optional explicit publish tag
- `dual-release-on-stable`: for stable releases, publish companion prerelease `x.y.z-n` to `next` before publishing stable to `latest` (default: `false`)
- `companion-prerelease-version`: optional explicit companion prerelease version in `x.y.z-n`; if omitted, the action resolves the next numeric prerelease counter from npm
- `dry-run`: print commands without publishing (default: `false`)

## Outputs

- `published`: `true` when `npm publish` was executed in this run
- `already-published`: `true` when `package-name@version` already existed and publish was skipped
- `tag`: resolved publish tag
- `is-prerelease`: whether the release type was prerelease
- `stable_published`: whether stable `x.y.z` publish was executed in this run
- `stable_already_published`: whether stable `x.y.z` already existed and was skipped
- `companion_prerelease_published`: whether companion prerelease `x.y.z-n` publish was executed in this run
- `companion_prerelease_already_published`: whether companion prerelease `x.y.z-n` already existed and was skipped
- `companion_prerelease_version`: resolved companion prerelease version when dual release is enabled

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

## Stable Dual Release Example

```yaml
- name: Publish stable and companion prerelease
  uses: vscheuber/npm-trusted-publish-action@v1
  with:
    release-type: patch
    package-name: '@my-scope/my-package'
    version: 1.2.4
    dual-release-on-stable: true
```
```
