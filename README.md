# npm-trusted-publish-action

Publish npm packages with trusted publishing (OIDC) using release-type aware channel selection.

## Inputs

- `release-type`: `prerelease | patch | minor | major` (default: `prerelease`)
- `package-name`: optional package name for adding `next` tag after stable release
- `version`: optional version for adding `next` tag after stable release
- `package-path`: path containing `package.json` (default: `.`)
- `access`: `public | restricted` (default: `public`)
- `tag-override`: optional explicit publish tag
- `add-next-tag-on-stable`: add `next` dist-tag for stable releases (default: `true`)
- `dry-run`: print commands without publishing (default: `false`)

## Outputs

- `published`: `true` when `npm publish` was executed
- `tag`: resolved publish tag
- `is-prerelease`: whether the release type was prerelease

## Example

```yaml
permissions:
  contents: read
  id-token: write

steps:
  - uses: actions/checkout@v6
  - uses: actions/setup-node@v6
    with:
      node-version: 24
      registry-url: https://registry.npmjs.org
  - run: npm ci
  - run: npm run build
  - uses: vscheuber/npm-trusted-publish-action@v1
    with:
      release-type: prerelease
      package-name: my-scope/my-package
      version: 1.2.3-1
```
