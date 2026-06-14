#!/bin/bash
set -euo pipefail

if [ "${CHECK_VENDOR_UPDATE:-1}" = "0" ]; then
    echo "Skipping bundled aria2 vendor update check."
    exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "Warning: gh is not available; skipping bundled aria2 vendor update check." >&2
    exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Warning: not in a git repository; skipping bundled aria2 vendor update check." >&2
    exit 0
fi

echo "Checking bundled aria2 vendor update PR..."

vendor_prs=()
while IFS= read -r pr_number; do
    [ -n "$pr_number" ] && vendor_prs+=("$pr_number")
done < <(
    gh pr list \
        --state open \
        --search "Update bundled aria2 in:title" \
        --json number \
        --jq '.[].number'
)

if [ "${#vendor_prs[@]}" -eq 0 ]; then
    echo "No bundled aria2 vendor update PR found."
    exit 0
fi

if [ "${#vendor_prs[@]}" -gt 1 ]; then
    echo "Found multiple bundled aria2 update PRs: ${vendor_prs[*]}" >&2
    echo "Please review and merge manually before building a release." >&2
    exit 1
fi

pr_number="${vendor_prs[0]}"
pr_json="$(gh pr view "$pr_number" --json title,url,baseRefName,headRefName,files,statusCheckRollup,isDraft)"

PR_JSON="$pr_json" ruby <<'RUBY'
require "json"

pr = JSON.parse(ENV.fetch("PR_JSON"))
allowed = [
  %r{\Avendor/aria2/VERSION\z},
  %r{\Avendor/aria2/SHA256SUMS\z},
  %r{\Avendor/aria2/darwin-arm64/aria2c\z},
  %r{\Avendor/aria2/darwin-arm64/lib/[^/]+\.dylib\z}
]

errors = []
errors << "PR is draft" if pr["isDraft"]
errors << "base branch is #{pr["baseRefName"]}, expected main" unless pr["baseRefName"] == "main"
errors << "head branch #{pr["headRefName"]} does not match codex/update-aria2-*" unless pr["headRefName"].to_s.start_with?("codex/update-aria2-")
errors << "title does not match Update bundled aria2" unless pr["title"].to_s.start_with?("Update bundled aria2 to ")

files = pr.fetch("files", []).map { |file| file.fetch("path") }
errors << "PR has no file changes" if files.empty?
unexpected = files.reject { |path| allowed.any? { |rule| rule.match?(path) } }
errors << "unexpected files: #{unexpected.join(", ")}" unless unexpected.empty?

checks = pr.fetch("statusCheckRollup", [])
failed_checks = checks.select do |check|
  conclusion = check["conclusion"].to_s.upcase
  status = check["status"].to_s.upcase
  conclusion.empty? ? status != "COMPLETED" : !["SUCCESS", "SKIPPED", "NEUTRAL"].include?(conclusion)
end
errors << "checks are not passing" unless failed_checks.empty?

if errors.any?
  warn "Bundled aria2 update PR is not safe to merge automatically:"
  errors.each { |error| warn "- #{error}" }
  warn "PR: #{pr["url"]}"
  exit 1
end
RUBY

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "main" ]; then
    echo "Bundled aria2 update PR #$pr_number is ready, but the current branch is $current_branch." >&2
    echo "Switch to main before building so the vendor update can be merged safely." >&2
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "Bundled aria2 update PR #$pr_number is ready, but the working tree is not clean." >&2
    echo "Commit or stash local changes before building so the vendor update can be merged safely." >&2
    exit 1
fi

echo "Merging bundled aria2 update PR #$pr_number..."
gh pr merge "$pr_number" --squash --delete-branch

echo "Pulling latest main after bundled aria2 update..."
git pull --ff-only origin main

echo "Bundled aria2 vendor is up to date."
