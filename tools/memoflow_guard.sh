#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  ./tools/memoflow_guard.sh check
  ./tools/memoflow_guard.sh check-staged
USAGE
}

die() {
  printf 'memoflow_guard: %s\n' "$1" >&2
  exit 2
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" ||
  die 'must be run inside a Git repository.'
cd "$repo_root" || die "failed to enter repository root: $repo_root"

denylist_file='.memoflow-public-denylist'
[[ -f "$denylist_file" ]] || die "missing denylist file: $denylist_file"

declare -a rules=()
declare -a path_rules=()
declare -a keyword_rules=()
declare -a failures=()

trim_line() {
  printf '%s' "$1" | sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

is_path_rule() {
  local rule="$1"
  case "$rule" in
    */*|*.entitlements|*.storekit|*.mobileprovision|*.xcarchive|*.dSYM.zip|*.ipa|*.p8)
      return 0
      ;;
  esac
  return 1
}

load_rules() {
  local raw rule
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    rule="$(trim_line "$raw")"
    [[ -z "$rule" ]] && continue
    [[ "${rule:0:1}" == '#' ]] && continue

    rules+=("$rule")
    if is_path_rule "$rule"; then
      path_rules+=("$rule")
    else
      keyword_rules+=("$rule")
    fi
  done <"$denylist_file"

  ((${#rules[@]} > 0)) || die "denylist has no active rules: $denylist_file"
}

add_failure() {
  failures+=("$1")
}

normalize_path() {
  local path="$1"
  path="${path#./}"
  printf '%s' "${path//\\//}"
}

path_is_content_excluded() {
  local path
  path="$(normalize_path "$1")"

  if path_is_build_artifact "$path"; then
    return 0
  fi

  case "$path" in
    "$denylist_file"|tools/memoflow_guard.sh|.github/scripts/public_repo_guardrails.ps1)
      return 0
      ;;
    .githooks/*)
      return 0
      ;;
    memos_flutter_app/test/architecture/ios_public_shell_guardrail_test.dart)
      return 0
      ;;
    memos_flutter_app/test/architecture/macos_distribution_identity_guardrail_test.dart)
      return 0
      ;;
    memos_flutter_app/test/private_hooks/public_shell_contract_test.dart)
      return 0
      ;;
  esac

  return 1
}

path_is_build_artifact() {
  local path
  path="$(normalize_path "$1")"

  case "$path" in
    build/*|*/build/*|.dart_tool/*|*/.dart_tool/*|ios/Pods/*|*/ios/Pods/*)
      return 0
      ;;
  esac

  return 1
}

path_matches_denylist() {
  local path="$1"
  local label="$2"
  local rule

  for rule in "${rules[@]}"; do
    if [[ "$path" == *"$rule"* ]]; then
      add_failure "$label path '$path' matches denylist rule '$rule'"
    fi
  done
}

check_workspace_paths() {
  local path normalized

  while IFS= read -r -d '' path; do
    normalized="$(normalize_path "$path")"
    [[ -z "$normalized" ]] && continue
    if path_is_build_artifact "$normalized"; then
      continue
    fi
    path_matches_denylist "$normalized" 'working tree'
  done < <(
    git -c core.quotepath=false ls-files -z --cached --others --exclude-standard
    git -c core.quotepath=false ls-files -z --others --ignored --exclude-standard
  )
}

check_staged_paths() {
  local path normalized

  while IFS= read -r -d '' path; do
    normalized="$(normalize_path "$path")"
    [[ -z "$normalized" ]] && continue
    if path_is_build_artifact "$normalized"; then
      continue
    fi
    path_matches_denylist "$normalized" 'staged'
  done < <(git -c core.quotepath=false diff --cached --name-only -z --diff-filter=ACMRT)
}

write_keyword_patterns() {
  local pattern_file="$1"
  local keyword

  : >"$pattern_file"
  for keyword in "${keyword_rules[@]}"; do
    printf '%s\n' "$keyword" >>"$pattern_file"
  done
}

check_tracked_content() {
  ((${#keyword_rules[@]} > 0)) || return 0

  local pattern_file grep_output status line
  pattern_file="$(mktemp "${TMPDIR:-/tmp}/memoflow-guard-patterns.XXXXXX")" ||
    die 'failed to create temporary pattern file.'
  write_keyword_patterns "$pattern_file"

  grep_output="$(
    git -c core.quotepath=false grep -I -n -F -f "$pattern_file" -- . \
      ":(exclude)$denylist_file" \
      ':(exclude)tools/memoflow_guard.sh' \
      ':(exclude).githooks/**' \
      ':(exclude).github/scripts/public_repo_guardrails.ps1' \
      ':(exclude)build/**' \
      ':(exclude)*/build/**' \
      ':(exclude).dart_tool/**' \
      ':(exclude)*/.dart_tool/**' \
      ':(exclude)ios/Pods/**' \
      ':(exclude)*/ios/Pods/**' \
      ':(exclude)memos_flutter_app/test/architecture/ios_public_shell_guardrail_test.dart' \
      ':(exclude)memos_flutter_app/test/architecture/macos_distribution_identity_guardrail_test.dart' \
      ':(exclude)memos_flutter_app/test/private_hooks/public_shell_contract_test.dart' 2>/dev/null
  )"
  status=$?
  rm -f "$pattern_file"

  if ((status == 0)); then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      add_failure "tracked content contains denylisted text: $line"
    done <<<"$grep_output"
  elif ((status != 1)); then
    die 'failed to scan tracked content.'
  fi
}

check_staged_added_content() {
  ((${#keyword_rules[@]} > 0)) || return 0

  local diff_output line file text keyword
  local new_line=0

  diff_output="$(
    git -c core.quotepath=false diff --cached --no-ext-diff --unified=0 -- . \
      ":(exclude)$denylist_file" \
      ':(exclude)tools/memoflow_guard.sh' \
      ':(exclude).githooks/**' \
      ':(exclude).github/scripts/public_repo_guardrails.ps1' \
      ':(exclude)build/**' \
      ':(exclude)*/build/**' \
      ':(exclude).dart_tool/**' \
      ':(exclude)*/.dart_tool/**' \
      ':(exclude)ios/Pods/**' \
      ':(exclude)*/ios/Pods/**' \
      ':(exclude)memos_flutter_app/test/architecture/ios_public_shell_guardrail_test.dart' \
      ':(exclude)memos_flutter_app/test/architecture/macos_distribution_identity_guardrail_test.dart' \
      ':(exclude)memos_flutter_app/test/private_hooks/public_shell_contract_test.dart'
  )"

  while IFS= read -r line; do
    case "$line" in
      '+++ /dev/null')
        file=''
        ;;
      '+++ b/'*)
        file="${line#+++ b/}"
        file="$(normalize_path "$file")"
        if path_is_content_excluded "$file"; then
          file=''
        fi
        ;;
      '@@ '*)
        if [[ "$line" =~ \+([0-9]+)(,([0-9]+))?[[:space:]]@@ ]]; then
          new_line="${BASH_REMATCH[1]}"
        else
          new_line=0
        fi
        ;;
      '+'*)
        [[ "$line" == '+++'* ]] && continue
        [[ -z "${file:-}" ]] && continue
        text="${line:1}"
        for keyword in "${keyword_rules[@]}"; do
          if [[ "$text" == *"$keyword"* ]]; then
            add_failure "staged content $file:$new_line contains denylist rule '$keyword'"
          fi
        done
        ((new_line++))
        ;;
      ' '*)
        ((new_line++))
        ;;
    esac
  done <<<"$diff_output"
}

check_remotes() {
  local line name url marker
  local remote_pattern='(^|[^[:alnum:]])(private|storekit|store-kit|iap|in[-_]?app|app[-_]?store|testflight|billing|entitlement|commercial|release)([^[:alnum:]]|$)'

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name="${line%%[[:space:]]*}"
    marker="${line#*[[:space:]]}"
    url="${marker%%[[:space:]]*}"

    if printf '%s\n' "$name $url" | grep -Eiq "$remote_pattern"; then
      add_failure "git remote '$name' points to private-capability destination '$url'"
    fi
  done < <(git remote -v 2>/dev/null | awk '!seen[$1 " " $2]++')
}

print_failures_and_exit() {
  local failure

  if ((${#failures[@]} == 0)); then
    return 0
  fi

  {
    printf 'memoflow_guard: blocked private-capability content in the public repository.\n'
    printf 'Denylist: %s\n' "$denylist_file"
    printf '\n'
    for failure in "${failures[@]}"; do
      printf '  - %s\n' "$failure"
    done
    printf '\n'
    printf 'Remove this content from the public repository, move it to the private overlay, or narrow the denylist rule if this is a documented false positive.\n'
  } >&2

  exit 1
}

main() {
  local mode="${1:-}"

  load_rules

  case "$mode" in
    check)
      check_workspace_paths
      check_tracked_content
      check_remotes
      ;;
    check-staged)
      check_staged_paths
      check_staged_added_content
      check_remotes
      ;;
    -h|--help|help|'')
      usage
      exit 2
      ;;
    *)
      usage
      die "unknown command: $mode"
      ;;
  esac

  print_failures_and_exit
  printf 'memoflow_guard: %s passed.\n' "$mode"
}

main "$@"
