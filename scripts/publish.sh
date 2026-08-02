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
already_published='false'
publish_executed='false'

oidc_audience='npm:registry.npmjs.org'

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd"
    exit 1
  fi
}

json_field() {
  local field="$1"
  local payload="$2"
  node -e "const fs=require('fs'); const d=JSON.parse(fs.readFileSync(0,'utf8')); const v=d['$field']; if (typeof v !== 'string' || !v) process.exit(2); process.stdout.write(v);" <<<"$payload"
}

urlencode() {
  local raw="$1"
  node -e "process.stdout.write(encodeURIComponent(process.argv[1]));" "$raw"
}

append_query_param() {
  local url="$1"
  local key="$2"
  local value="$3"
  if [[ "$url" == *\?* ]]; then
    echo "${url}&${key}=${value}"
  else
    echo "${url}?${key}=${value}"
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
require_cmd curl

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

needs_next_tag='false'
if [[ "$release_type" != "prerelease" && "$add_next_tag_on_stable" == "true" ]]; then
  needs_next_tag='true'
fi

if [[ "$needs_next_tag" == "true" ]]; then
  if [[ -z "$package_name" || -z "$version" ]]; then
    echo "package-name and version are required when add-next-tag-on-stable is true for stable releases"
    exit 1
  fi
fi

if [[ "$dry_run" == "true" ]]; then
  echo "[dry-run] npm publish --access $access --tag $publish_tag"
  if [[ "$needs_next_tag" == "true" ]]; then
    echo "[dry-run] request GitHub OIDC id_token for audience ${oidc_audience}"
    echo "[dry-run] exchange OIDC token for npm short-lived token scoped to ${package_name}"
    echo "[dry-run] npm dist-tag add ${package_name}@${version} next"
    echo "[dry-run] npm dist-tag ls ${package_name} (verify next -> ${version})"
  fi
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

if [[ "$needs_next_tag" == "true" ]]; then
  echo "Moving next dist-tag to ${package_name}@${version}"

  npm_registry_token=''
  if [[ -n "${NODE_AUTH_TOKEN:-}" ]]; then
    echo "Using provided NODE_AUTH_TOKEN for npm dist-tag mutation"
    npm_registry_token="${NODE_AUTH_TOKEN}"
  elif [[ -n "${NPM_TOKEN:-}" ]]; then
    echo "Using provided NPM_TOKEN for npm dist-tag mutation"
    npm_registry_token="${NPM_TOKEN}"
  else
    if [[ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" || -z "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ]]; then
      echo "Cannot request GitHub OIDC token. Ensure job permissions include id-token: write."
      exit 1
    fi

    oidc_url="$(append_query_param "$ACTIONS_ID_TOKEN_REQUEST_URL" "audience" "$oidc_audience")"
    oidc_response="$(curl -fsSL -H "Authorization: Bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "$oidc_url")"
    oidc_id_token="$(json_field value "$oidc_response")"

    encoded_package_name="$(urlencode "$package_name")"
    exchange_url="https://registry.npmjs.org/-/npm/v1/oidc/token/exchange/package/${encoded_package_name}"
    exchange_response="$(curl -fsSL -X POST -H "Authorization: Bearer ${oidc_id_token}" "$exchange_url")"
    npm_registry_token="$(json_field token "$exchange_response")"
  fi

  NODE_AUTH_TOKEN="$npm_registry_token" npm dist-tag add "${package_name}@${version}" next

  tag_listing="$(NODE_AUTH_TOKEN="$npm_registry_token" npm dist-tag ls "$package_name")"
  if ! grep -Eq "^next:[[:space:]]*${version}$" <<<"$tag_listing"; then
    echo "Failed to verify next dist-tag. Expected next: ${version}."
    echo "Current dist-tags:"
    echo "$tag_listing"
    exit 1
  fi
fi

{
  echo "published=$publish_executed"
  echo "already_published=$already_published"
  echo "tag=$publish_tag"
  echo "is_prerelease=$([[ "$release_type" == "prerelease" ]] && echo true || echo false)"
} >> "$GITHUB_OUTPUT"
