#!/usr/bin/env bash
set -euo pipefail

release_type="${RELEASE_TYPE:-prerelease}"
package_name="${PACKAGE_NAME:-}"
version="${VERSION:-}"
package_path="${PACKAGE_PATH:-.}"
access="${ACCESS:-public}"
tag_override="${TAG_OVERRIDE:-}"
dry_run="${DRY_RUN:-false}"
already_published='false'
publish_executed='false'

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd"
    exit 1
  fi
}

case "$release_type" in
  prerelease|patch|minor|major) ;;
  *)
    echo "release-type must be one of: prerelease, patch, minor, major"
    exit 1
    ;;
esac

require_cmd npm
require_cmd node

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
  {
    echo "published=false"
    echo "already_published=false"
    echo "tag=$publish_tag"
    echo "is_prerelease=$([[ "$release_type" == "prerelease" ]] && echo true || echo false)"
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

if [[ -n "$package_name" && -n "$version" ]] && npm view "${package_name}@${version}" version --json >/dev/null 2>&1; then
  already_published='true'
  echo "${package_name}@${version} is already published; skipping npm publish and continuing recovery flow"
else
  pushd "$package_path" >/dev/null
  npm publish --access "$access" --tag "$publish_tag"
  popd >/dev/null
  publish_executed='true'
fi

{
  echo "published=$publish_executed"
  echo "already_published=$already_published"
  echo "tag=$publish_tag"
  echo "is_prerelease=$([[ "$release_type" == "prerelease" ]] && echo true || echo false)"
} >> "$GITHUB_OUTPUT"
