#!/usr/bin/env bash
set -euo pipefail

release_type="${RELEASE_TYPE:-prerelease}"
package_name="${PACKAGE_NAME:-}"
version="${VERSION:-}"
package_path="${PACKAGE_PATH:-.}"
access="${ACCESS:-public}"
tag_override="${TAG_OVERRIDE:-}"
dual_release_on_stable="${DUAL_RELEASE_ON_STABLE:-false}"
companion_prerelease_version_input="${COMPANION_PRERELEASE_VERSION:-}"
dry_run="${DRY_RUN:-false}"
already_published='false'
publish_executed='false'
stable_published='false'
stable_already_published='false'
companion_prerelease_published='false'
companion_prerelease_already_published='false'
companion_prerelease_version=''

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

case "$dual_release_on_stable" in
  true|false) ;;
  *)
    echo "dual-release-on-stable must be one of: true, false"
    exit 1
    ;;
esac

require_cmd npm
require_cmd node

semver_stable_re='^([0-9]+)\.([0-9]+)\.([0-9]+)$'
semver_numeric_prerelease_re='^([0-9]+)\.([0-9]+)\.([0-9]+)-([0-9]+)$'

normalize_json_array() {
  local json_input="$1"
  node -e "const fs=require('fs'); const raw=fs.readFileSync(0,'utf8').trim(); if (!raw) { process.stdout.write('[]'); process.exit(0);} const data=JSON.parse(raw); if (Array.isArray(data)) { process.stdout.write(JSON.stringify(data)); process.exit(0);} if (typeof data === 'string') { process.stdout.write(JSON.stringify([data])); process.exit(0);} process.stdout.write('[]');" <<<"$json_input"
}

package_version_exists() {
  local pkg="$1"
  local ver="$2"
  npm view "${pkg}@${ver}" version --json >/dev/null 2>&1
}

set_package_version() {
  local target_version="$1"
  local pkg_json="${package_path}/package.json"

  node -e "const fs=require('fs'); const p=process.argv[1]; const v=process.argv[2]; const data=JSON.parse(fs.readFileSync(p,'utf8')); data.version=v; fs.writeFileSync(p, JSON.stringify(data, null, 2) + '\\n');" "$pkg_json" "$target_version"
}

compute_next_numeric_prerelease() {
  local pkg="$1"
  local stable_version="$2"

  local versions_raw
  local versions_json
  local next_number

  versions_raw="$(npm view "$pkg" versions --json 2>/dev/null || echo '[]')"
  versions_json="$(normalize_json_array "$versions_raw")"

  next_number="$(node -e 'const fs=require("fs"); const stable=process.argv[1]; const versions=JSON.parse(fs.readFileSync(0,"utf8")); const escaped=stable.replace(/[.*+?^${}()|[\]\\]/g,"\\$&"); const rx=new RegExp(`^${escaped}-(\\d+)$`); let max=0; for (const v of versions) { const m=String(v).match(rx); if (m) { const n=Number(m[1]); if (Number.isFinite(n) && n>max) max=n; } } process.stdout.write(String(max+1));' "$stable_version" <<<"$versions_json")"

  if [[ ! "$next_number" =~ ^[0-9]+$ ]]; then
    echo "Unable to compute prerelease counter for ${stable_version}; got: ${next_number}"
    exit 1
  fi

  echo "${stable_version}-${next_number}"
}

publish_if_missing() {
  local pkg="$1"
  local ver="$2"
  local tag="$3"
  local published_var="$4"
  local already_var="$5"

  if package_version_exists "$pkg" "$ver"; then
    printf -v "$already_var" '%s' 'true'
    echo "${pkg}@${ver} is already published; skipping npm publish"
    return
  fi

  pushd "$package_path" >/dev/null
  npm publish --access "$access" --tag "$tag"
  popd >/dev/null

  printf -v "$published_var" '%s' 'true'
  publish_executed='true'
}

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

is_stable_release='false'
if [[ "$release_type" != "prerelease" ]]; then
  is_stable_release='true'
fi

if [[ "$dual_release_on_stable" == 'true' && "$is_stable_release" == 'true' ]]; then
  if [[ -z "$package_name" || -z "$version" ]]; then
    echo "package-name and version are required when dual-release-on-stable is true for stable releases"
    exit 1
  fi

  if [[ ! "$version" =~ $semver_stable_re ]]; then
    echo "Stable release version must be x.y.z when dual-release-on-stable is true. Got: ${version}"
    exit 1
  fi
fi

if [[ "$dry_run" == "true" ]]; then
  if [[ "$dual_release_on_stable" == 'true' && "$is_stable_release" == 'true' ]]; then
    if [[ -n "$companion_prerelease_version_input" ]]; then
      companion_prerelease_version="$companion_prerelease_version_input"
    else
      companion_prerelease_version="${version}-<next-counter>"
    fi

    echo "[dry-run] dual stable release enabled"
    echo "[dry-run] set package version to ${companion_prerelease_version}"
    echo "[dry-run] npm publish --access $access --tag next"
    echo "[dry-run] set package version to ${version}"
    echo "[dry-run] npm publish --access $access --tag ${publish_tag}"
  else
    echo "[dry-run] npm publish --access $access --tag $publish_tag"
  fi

  {
    echo "published=false"
    echo "already_published=false"
    echo "tag=$publish_tag"
    echo "is_prerelease=$([[ "$release_type" == "prerelease" ]] && echo true || echo false)"
    echo "stable_published=false"
    echo "stable_already_published=false"
    echo "companion_prerelease_published=false"
    echo "companion_prerelease_already_published=false"
    echo "companion_prerelease_version=${companion_prerelease_version}"
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

if [[ "$dual_release_on_stable" == 'true' && "$is_stable_release" == 'true' ]]; then
  if [[ -n "$companion_prerelease_version_input" ]]; then
    companion_prerelease_version="$companion_prerelease_version_input"
    if [[ ! "$companion_prerelease_version" =~ $semver_numeric_prerelease_re ]]; then
      echo "companion-prerelease-version must match x.y.z-n. Got: ${companion_prerelease_version}"
      exit 1
    fi

    companion_core="${companion_prerelease_version%-*}"
    if [[ "$companion_core" != "$version" ]]; then
      echo "companion-prerelease-version must share stable core ${version}. Got: ${companion_prerelease_version}"
      exit 1
    fi
  else
    companion_prerelease_version="$(compute_next_numeric_prerelease "$package_name" "$version")"
  fi

  if [[ ! "$companion_prerelease_version" =~ $semver_numeric_prerelease_re ]]; then
    echo "Resolved companion prerelease version is invalid, expected x.y.z-n. Got: ${companion_prerelease_version}"
    exit 1
  fi

  echo "Dual stable release companion prerelease: ${companion_prerelease_version}"

  current_version="$(node -e "const fs=require('fs'); const p=process.argv[1]; const d=JSON.parse(fs.readFileSync(p,'utf8')); process.stdout.write(String(d.version || ''));" "${package_path}/package.json")"
  restore_version="$current_version"

  if [[ "$current_version" != "$companion_prerelease_version" ]]; then
    set_package_version "$companion_prerelease_version"
  fi
  publish_if_missing "$package_name" "$companion_prerelease_version" next companion_prerelease_published companion_prerelease_already_published

  if [[ "$restore_version" != "$version" ]]; then
    set_package_version "$version"
  fi
  publish_if_missing "$package_name" "$version" "$publish_tag" stable_published stable_already_published

  already_published="$stable_already_published"
else
  if [[ -n "$package_name" && -n "$version" ]] && package_version_exists "$package_name" "$version"; then
    already_published='true'
    echo "${package_name}@${version} is already published; skipping npm publish and continuing recovery flow"
  else
    pushd "$package_path" >/dev/null
    npm publish --access "$access" --tag "$publish_tag"
    popd >/dev/null
    publish_executed='true'
    stable_published='true'
  fi
fi

{
  echo "published=$publish_executed"
  echo "already_published=$already_published"
  echo "tag=$publish_tag"
  echo "is_prerelease=$([[ "$release_type" == "prerelease" ]] && echo true || echo false)"
  echo "stable_published=$stable_published"
  echo "stable_already_published=$stable_already_published"
  echo "companion_prerelease_published=$companion_prerelease_published"
  echo "companion_prerelease_already_published=$companion_prerelease_already_published"
  echo "companion_prerelease_version=$companion_prerelease_version"
} >> "$GITHUB_OUTPUT"
