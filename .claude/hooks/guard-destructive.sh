#!/bin/bash
# PreToolUse(Bash) — CHARTER 4조 절대금지 명령 차단. LLM 판단 없이 결정론적으로.
set -uo pipefail
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

case "$COMMAND" in
  *"git push"*"--force"*|*"git push -f"*)
    deny "CHARTER 4조: force push 금지" ;;
  *"git reset --hard"*)
    deny "CHARTER 4조: git reset --hard 금지" ;;
  *"git branch -D"*origin*|*"git push"*"--delete"*|*"git tag -d"*)
    deny "CHARTER 4조: 브랜치/태그 삭제 금지" ;;
  *"rm -rf"*)
    deny "파괴적 삭제 명령 차단 — 필요하면 사장에게 질의" ;;
  *"pnpm add"*"@latest"*|*"pnpm up --latest"*|*"npm install"*"@latest"*)
    deny "CHARTER 4조: 의존성 메이저 업그레이드 금지" ;;
  *"pnpm install"*"--force"*"lockfile"*|*"rm"*"pnpm-lock.yaml"*)
    deny "CHARTER 4조: 락파일 재생성 금지" ;;
  *"vercel --prod"*|*"deploy"*"--prod"*|*"render deploy"*)
    deny "CHARTER 4조: 프로덕션 배포 트리거 금지 — 사장 결재 필요" ;;
  # main 직행 금지. 산출물은 claude/v3.0.N 브랜치 → PR 까지다.
  *"git push"*" main"*|*"git push"*":main"*|*"git push"*"main:"*)
    deny "main 직접 push 금지 — claude/v3.0.N 브랜치에 올리고 PR을 내라" ;;
  # 사장 전용 브랜치. 철자 오타(obserser)까지 같이 막는다.
  *"git push"*obserser*|*"git push"*observer*)
    deny "obserser/* 는 사장 전용 브랜치다 — 에이전트는 읽기만 한다" ;;
esac

# 브랜치 이름 규칙을 프롬프트가 아니라 여기서 강제한다.
# 에이전트 브랜치는 claude/vX.Y.Z 또는 cursor/vX.Y.Z 만 허용한다 — 슬러그·날짜·설명 금지.
# 무엇을 바꿨는지는 커밋 메시지와 PR 본문이 설명한다.
if [[ "$COMMAND" == *"git push"* ]]; then
  set -f  # 토큰에 * 가 들어와도 글로빙되지 않게
  for token in $COMMAND; do
    token="${token##*:}" # HEAD:claude/foo, refs/heads/claude/foo 형태 대응
    token="${token#refs/heads/}"
    case "$token" in
      claude/* | cursor/*)
        if [[ ! "$token" =~ ^(claude|cursor)/v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          set +f
          deny "브랜치 이름 규칙 위반: '$token' — claude/vX.Y.Z 또는 cursor/vX.Y.Z 만 허용한다. 이름은 직접 짓지 말고 scripts/next-branch.sh 로 받아라."
        fi
        ;;
    esac
  done
  set +f
fi

exit 0
