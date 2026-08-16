#!/usr/bin/env bash
# post-to-slack.sh — 마크다운 보고서를 Slack #request 채널에 올린다.
#
# 사용법:
#   SLACK_WEBHOOK_URL=... bash scripts/post-to-slack.sh reports/requests/2026-08-16.md
#
# 웹훅 URL은 인자로 받지 않는다. 인자는 프로세스 목록(ps)에 그대로 노출되기 때문에
# 반드시 환경변수로만 받는다. 이 스크립트는 URL을 어디에도 출력하지 않는다.
set -euo pipefail
set +x  # 웹훅 URL이 트레이스에 찍히는 사고 방지

REPORT="${1:-}"

if [[ -z "$REPORT" ]]; then
  echo "post-to-slack.sh: 보고서 경로가 필요하다" >&2
  exit 2
fi
if [[ ! -f "$REPORT" ]]; then
  echo "post-to-slack.sh: 파일이 없다: $REPORT" >&2
  exit 1
fi
if [[ -z "${SLACK_WEBHOOK_URL:-}" && "${DRY_RUN:-0}" != "1" ]]; then
  echo "post-to-slack.sh: SLACK_WEBHOOK_URL 이 비어 있다 — 리포 시크릿을 확인하라" >&2
  exit 1
fi
command -v jq >/dev/null || { echo "post-to-slack.sh: jq 가 필요하다" >&2; exit 1; }

# --- 마크다운 → Slack mrkdwn ------------------------------------------------
# Slack은 CommonMark가 아니다. 굵게는 *한 개*, 링크는 <url|text>.
mrkdwn="$(
  sed -E \
    -e 's/^#{1,6} +(.*)$/*\1*/' \
    -e 's/\*\*([^*]+)\*\*/*\1*/g' \
    -e 's/^- \[ \] /• /' \
    -e 's/^- \[x\] /✅ /' \
    -e 's/^\* /• /' \
    -e 's/^- /• /' \
    -e 's/\[([^]]+)\]\(([^)]+)\)/<\2|\1>/g' \
    "$REPORT"
)"

# --- 3000자 블록 제한에 맞춰 문단 단위로 자른다 -----------------------------
# Slack section block의 text는 3000자를 넘으면 요청 전체가 400으로 떨어진다.
LIMIT=2800
chunks=()
buf=""
while IFS= read -r line || [[ -n "$line" ]]; do
  if (( ${#buf} + ${#line} + 1 > LIMIT )); then
    chunks+=("$buf")
    buf="$line"
  else
    buf="${buf:+$buf$'\n'}$line"
  fi
done <<<"$mrkdwn"
[[ -n "$buf" ]] && chunks+=("$buf")

if (( ${#chunks[@]} == 0 )); then
  echo "post-to-slack.sh: 보고서가 비어 있다 — 게시하지 않는다" >&2
  exit 1
fi

# Slack 메시지 하나에 블록 50개가 상한. 넘치면 전송 자체가 실패하므로 잘라낸다.
MAX_BLOCKS=45
if (( ${#chunks[@]} > MAX_BLOCKS )); then
  echo "post-to-slack.sh: 블록 ${#chunks[@]}개 → ${MAX_BLOCKS}개로 자른다 (보고서가 너무 길다)" >&2
  chunks=("${chunks[@]:0:$MAX_BLOCKS}")
  chunks+=("_...(이하 생략) 전문: \`${REPORT}\`_")
fi

# 청크 하나씩 jq --arg 로 넘긴다. NUL 구분자를 쓰면 bash가 인자에 NUL을 못 실어
# 전부 빈 문자열이 되고, split("")이 글자 단위로 쪼개진다(실제로 겪은 버그).
blocks="$(
  for chunk in "${chunks[@]}"; do
    jq -n --arg t "$chunk" '{ type: "section", text: { type: "mrkdwn", text: $t } }'
  done | jq -s '.'
)"

payload="$(jq -n \
  --argjson blocks "$blocks" \
  --arg fallback "biolabs3 · Alpha 일일 인계" \
  '{ text: $fallback, blocks: $blocks }')"

# DRY_RUN=1 이면 전송 없이 페이로드만 확인한다(웹훅 없이 포맷 점검용).
if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "$payload" | jq .
  echo "post-to-slack.sh: DRY_RUN — 전송하지 않았다 (${#chunks[@]} block)" >&2
  exit 0
fi

# --- 전송 (네트워크 실패시 지수 백오프 재시도) ------------------------------
for attempt in 1 2 3 4; do
  http_code="$(
    curl --silent --show-error --output /tmp/slack-resp.txt --write-out '%{http_code}' \
      -X POST -H 'Content-Type: application/json' \
      --data "$payload" \
      "$SLACK_WEBHOOK_URL" 2>/tmp/slack-err.txt
  )" || http_code="000"

  if [[ "$http_code" == "200" ]]; then
    echo "post-to-slack.sh: 게시 완료 (${#chunks[@]} block, $REPORT)"
    exit 0
  fi

  # 4xx는 재시도해도 똑같다. 응답 본문만 남기고 끝낸다(URL은 찍지 않는다).
  if [[ "$http_code" =~ ^4 ]]; then
    echo "post-to-slack.sh: Slack이 거부했다 (HTTP $http_code): $(cat /tmp/slack-resp.txt)" >&2
    exit 1
  fi

  echo "post-to-slack.sh: 전송 실패 (HTTP $http_code), 재시도 $attempt/4" >&2
  sleep $((2 ** attempt))
done

echo "post-to-slack.sh: 4회 재시도 후에도 실패했다" >&2
exit 1
