#!/usr/bin/env bash
# find-todays-report.sh — 오늘자 인계 보고서가 올라간 claude/v3.0.* 브랜치를 찾아
# 그 파일을 워킹트리로 꺼낸다. 14:00 게시 잡이 08:00 스캔 잡의 산출물을 집을 때 쓴다.
#
# 08:00 잡과 14:00 잡은 서로 다른 워크플로 실행이라 아티팩트를 직접 주고받을 수 없다.
# 대신 스캔 잡이 브랜치에 커밋해 두고, 이 스크립트가 원격에서 되찾는다.
#
# 사용법:
#   REPORT="$(bash scripts/find-todays-report.sh)"   # 경로를 stdout으로
#   REPORT="$(bash scripts/find-todays-report.sh 2026-08-16)"
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# KST 기준 날짜. 러너는 UTC라 date만 쓰면 하루가 밀린다.
DATE="${1:-$(TZ=Asia/Seoul date +%Y-%m-%d)}"
REPORT_PATH="reports/requests/${DATE}.md"

for attempt in 1 2 3 4; do
  if git fetch --quiet origin '+refs/heads/claude/*:refs/remotes/origin/claude/*' 2>/dev/null; then
    break
  fi
  if [[ $attempt -eq 4 ]]; then
    echo "find-todays-report.sh: origin fetch 실패" >&2
    exit 1
  fi
  sleep $((2 ** attempt))
done

# 최근 커밋 순으로 훑어서 그 파일을 가진 첫 브랜치를 쓴다.
while read -r ref; do
  [[ -z "$ref" ]] && continue
  if git cat-file -e "${ref}:${REPORT_PATH}" 2>/dev/null; then
    mkdir -p "$(dirname "$REPORT_PATH")"
    git show "${ref}:${REPORT_PATH}" >"$REPORT_PATH"
    echo "$REPORT_PATH"
    exit 0
  fi
done < <(git for-each-ref --sort=-committerdate --format='%(refname)' 'refs/remotes/origin/claude/*')

echo "find-todays-report.sh: ${REPORT_PATH} 를 가진 claude/* 브랜치가 없다 — 08:00 스캔이 돌지 않았거나 실패했다." >&2
exit 1
