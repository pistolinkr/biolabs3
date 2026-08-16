#!/usr/bin/env bash
# find-todays-report.sh — 오늘자 인계 지시서의 경로를 돌려준다.
#
# 지시서는 커밋되지 않는다(.gitignore 의 reports/ 참조). 이 리포는 public이고
# 지시서에는 아직 안 고친 결함의 위치가 들어가기 때문이다. 그래서 이 스크립트는
# 원격을 뒤지지 않고 **러너 디스크에 있는 오늘자 파일**만 확인한다.
# scan 과 handoff 는 같은 실행 안에서 같은 디스크를 공유한다.
#
# 사용법:
#   REPORT="$(bash scripts/find-todays-report.sh)"
#   REPORT="$(bash scripts/find-todays-report.sh 2026-08-16)"
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# KST 기준 날짜. 러너는 UTC라 그냥 date 를 쓰면 하루가 밀린다.
DATE="${1:-$(TZ=Asia/Seoul date +%Y-%m-%d)}"
REPORT_PATH="reports/requests/${DATE}.md"

if [[ ! -f "$REPORT_PATH" ]]; then
  echo "find-todays-report.sh: ${REPORT_PATH} 가 없다 — /alpha-scan 이 돌지 않았거나 실패했다." >&2
  exit 1
fi

if [[ ! -s "$REPORT_PATH" ]]; then
  echo "find-todays-report.sh: ${REPORT_PATH} 가 비어 있다 — 빈 인계는 올리지 않는다." >&2
  exit 1
fi

echo "$REPORT_PATH"
