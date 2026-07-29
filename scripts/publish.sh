#!/usr/bin/env bash
set -euo pipefail

release_type="${RELEASE_TYPE:-prerelease}"
package_name="${PACKAGE_NAME:-}"
version="${VERSION:-}"
package_path="${PACKAGE_PATH:-.}"
access="${ACCESS:-public}"
tag_override="${TAG_OVERRIDE:-}"
add_next_tag_on_stable="${ADD_NEXT_TAG_ON_STABLE:-true}"
dry_run="${DRY_RUN:-false}"

case "$release_type" in
  prerelease|patch|minor|major) ;;
  *)
    echo "release-type must be one of: prerelease, patch, minor, major"
    exit 1
    ;;
esac

if [[ -n "$tag_override" ]]; then
  publish_tag="$tag_override"
else
  if [[ "$release_type" == "prerelease" ]]; then
    publish_tag='next'
  else
    publish_tag='latest'
  fi
fi

if [[ ! -f "$package_path/package.json" ]]; then
  echo "package.json not found at ${package_path}/package.json"
  exit 1
fi

echo "Resolved publish tag: $publish_tag"

if [[ "$dry_run" == "true" ]]; then
  echo "[dry-run] npm publish --access $access --tag $publish_tag"
  if [[ "$release_type" != "prerelease" && "$add_next_tag_on_stable" == "true" && -n "$package_name" && -n "$version" ]]; then
    echo "[dry-run] npm dist-tag add ${package_name}@${version} next"
  fi
  echo "published=false" >> "$GITHUB_OUTPUT"
  echo "tag=$publish_tag" >> "$GITHUB_OUTPUT"
  echo "is_prerelease=$([[ "$release_type" == "prerelease" ]] && echo true || echo false)" >> "$GITHUB_OUTPUT"
  exit 0
fi

pushd "$package_path" >/dev/null
npm publish --access "$access" --tag "$publish_tag"
popd >/dev/null

if [[ "$release_type" != "prerelease" && "$add_next_tag_on_stable" == "true" && -n "$package_name" && -n "$version" ]]; then
  npm dist-tag add "${package_name}@${version}" next
fi

echo "published=true" >> "$GITHUB_OUTPUT"
echo "tag=$publish_tag" >> "$GITHUB_OUTPUT"
echo "is_prerelease=$([[ "$release_type" == "prerelease" ]] && echo true || echo false)" >> "$GITHUB_OUTPUT"
