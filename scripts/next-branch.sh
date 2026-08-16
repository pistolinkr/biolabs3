#!/usr/bin/env bash
# next-branch.sh — 다음 에이전트 브랜치 이름을 채번한다.
#
# 규칙 (CLAUDE.md "브랜치 규칙"의 단일 구현체):
#   claude/v3.0.<PATCH>   Claude(Alpha)가 올리는 브랜치
#   cursor/v3.0.<PATCH>   Cursor가 올리는 브랜치
#   obserser/v3.0.<PATCH> 사장 전용. 에이전트는 절대 건드리지 않는다.
#
# PATCH는 **claude/ 와 cursor/ 를 하나의 수열로 묶어서** 최대값 +1 로 계산한다.
# 두 에이전트가 같은 번호를 쓰면 안 되기 때문이다. 예)
#   원격에 claude/v3.0.1, cursor/v3.0.2 가 있으면 → 다음은 claude/v3.0.3
#
# 사용법:
#   BRANCH="$(bash scripts/next-branch.sh)"          # claude/v3.0.N
#   BRANCH="$(bash scripts/next-branch.sh cursor)"   # cursor/v3.0.N
#   git checkout -b "$BRANCH"
#
# MINOR(3.0 → 3.1)는 사람만 올린다: config/branch-version.txt
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT="${1:-claude}"

case "$AGENT" in
  claude | cursor) ;;
  *)
    echo "next-branch.sh: 알 수 없는 에이전트 '$AGENT' (claude|cursor 만 허용)" >&2
    exit 2
    ;;
esac

# --- MINOR 계열 결정 -------------------------------------------------------
VERSION_FILE="$REPO_ROOT/config/branch-version.txt"
if [[ -f "$VERSION_FILE" ]]; then
  SERIES="$(tr -d '[:space:]' <"$VERSION_FILE")"
else
  SERIES="3.0"
fi

if [[ ! "$SERIES" =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo "next-branch.sh: config/branch-version.txt 값이 이상하다: '$SERIES' (예: 3.0)" >&2
  exit 2
fi

# --- 원격 + 로컬에서 이미 쓰인 PATCH 수집 ----------------------------------
# 원격을 못 읽으면 로컬만 보고 채번하는 건 위험하다(중복 push). 실패시 멈춘다.
REMOTE_REFS=""
for attempt in 1 2 3 4; do
  if REMOTE_REFS="$(git -C "$REPO_ROOT" ls-remote --heads origin 2>/dev/null)"; then
    break
  fi
  if [[ $attempt -eq 4 ]]; then
    echo "next-branch.sh: origin 조회 실패 — 중복 번호를 낼 수 있어 중단한다." >&2
    exit 1
  fi
  sleep $((2 ** attempt))
done

LOCAL_REFS="$(git -C "$REPO_ROOT" for-each-ref --format='%(refname)' refs/heads refs/remotes 2>/dev/null || true)"

# claude/vX.Y.N 과 cursor/vX.Y.N 을 한 수열로 본다.
# grep이 0건이면 파이프라인이 실패한다(pipefail). 0건은 정상 상태이므로 삼킨다.
MAX="$(
  {
    printf '%s\n%s\n' "$REMOTE_REFS" "$LOCAL_REFS" |
      grep -oE "(claude|cursor)/v${SERIES//./\\.}\.[0-9]+" |
      sed -E 's/.*\.([0-9]+)$/\1/' |
      sort -n |
      tail -1
  } || true
)"

# 아직 아무도 이 계열을 쓰지 않았으면 .1 부터 시작한다(.0은 비워 둔다).
NEXT=$(( ${MAX:-0} + 1 ))

echo "${AGENT}/v${SERIES}.${NEXT}"
