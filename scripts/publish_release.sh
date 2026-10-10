#!/usr/bin/env bash
# Publish one checked build, then retain the newest build releases and their tags.
# Usage: scripts/publish_release.sh OWNER/REPO FULL_COMMIT_SHA ASSET_DIR KEEP_COUNT
# Requires gh authentication with contents:write (GH_TOKEN in Actions, or gh auth locally).
set -euo pipefail

if [ "$#" -ne 4 ]; then
	echo "usage: scripts/publish_release.sh OWNER/REPO FULL_COMMIT_SHA ASSET_DIR KEEP_COUNT" >&2
	exit 2
fi

repo=$1
sha=$2
assets_dir=$3
keep=$4
if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]] || [[ ! "$keep" =~ ^[1-9][0-9]*$ ]]; then
	echo "publish_release.sh: expected a full lowercase commit SHA and a positive retention count" >&2
	exit 2
fi

tag="build-${sha:0:7}"
legacy_tag="build-$sha"
if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
	echo "Release $tag already exists; leaving its assets as they are."
elif gh release view "$legacy_tag" --repo "$repo" >/dev/null 2>&1; then
	echo "Release $legacy_tag already exists; leaving its assets as they are."
else
	shopt -s nullglob
	assets=("$assets_dir"/*)
	if [ "${#assets[@]}" -eq 0 ]; then
		echo "publish_release.sh: no assets in $assets_dir" >&2
		exit 2
	fi
	gh release create "$tag" "${assets[@]}" \
		--repo "$repo" \
		--target "$sha" \
		--title "Build ${sha:0:7}" \
		--notes "Automated build of $sha."
fi

# Include old full-SHA tags until they age out. Other releases and tags are untouched.
# Pagination is needed once the repository has more than 100 releases.
gh api --paginate "repos/$repo/releases?per_page=100" \
	--jq '.[] | select(.draft == false and .published_at != null and (.tag_name | test("^build-([0-9a-f]{7}|[0-9a-f]{40})$"))) | [.published_at, .tag_name] | @tsv' \
	| sort -r | tail -n "+$((keep + 1))" \
	| while IFS=$'\t' read -r published old_tag; do
		echo "Removing old build release and tag: $old_tag (published $published)"
		gh release delete "$old_tag" --repo "$repo" --cleanup-tag --yes
	done
