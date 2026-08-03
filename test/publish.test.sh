#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/scripts/publish.sh"

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "publish script not found at $SCRIPT_PATH"
  exit 1
fi

workspace="$(mktemp -d "${TMPDIR:-/tmp}/npm-trusted-publish-test.XXXXXX")"
trap 'rm -rf "$workspace"' EXIT

repo="$workspace/repo"
output_file="$workspace/output.txt"
mkdir -p "$repo"

cat > "$repo/package.json" <<'EOF'
{
  "name": "npm-trusted-publish-test",
  "version": "1.2.3"
}
EOF

mock_bin="$workspace/bin"
mkdir -p "$mock_bin"

cat > "$mock_bin/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "view" && "$2" == "npm-trusted-publish-action@1.2.3" && "$3" == "version" ]]; then
  exit 1
fi

if [[ "$1" == "publish" ]]; then
  echo "mock publish invoked" >&2
  exit 0
fi

if [[ "$1" == "install" ]]; then
  exit 0
fi

if [[ "$1" == "view" ]]; then
  echo "[]"
  exit 0
fi

exit 0
EOF
chmod +x "$mock_bin/npm"

cat > "$mock_bin/node" <<EOF
#!/usr/bin/env bash
exec "$(command -v node)" "$@"
EOF
chmod +x "$mock_bin/node"

assert_contains() {
  local file="$1"
  local line="$2"
  if ! grep -q "^${line}$" "$file"; then
    echo "Expected line not found: $line"
    cat "$file"
    exit 1
  fi
}

PATH="$mock_bin:$PATH" \
RELEASE_TYPE='patch' \
PACKAGE_NAME='npm-trusted-publish-action' \
VERSION='1.2.3' \
PACKAGE_PATH="$repo" \
DRY_RUN='true' \
GITHUB_OUTPUT="$output_file" \
bash "$SCRIPT_PATH"

assert_contains "$output_file" 'published=false'
assert_contains "$output_file" 'already_published=false'
assert_contains "$output_file" 'tag=latest'
assert_contains "$output_file" 'is_prerelease=false'

echo "All publish tests passed"
