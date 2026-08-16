---
name: alpha-handoff
description: Alpha(Claude)의 14:00 인계. 08:00 alpha-scan이 만든 지시서를 최종 점검해 Slack #request 채널에 게시한다. GitHub Actions alpha-daily 워크플로의 handoff 잡이 호출한다.
---

# alpha-handoff — 14:00 인계

08:00에 만든 지시서를 **Slack #request에 올려 Cursor에게 넘긴다.**
새로 조사하지 않는다. 이미 만든 것을 검증하고 게시하는 단계다.

## 1. 오늘자 지시서를 찾는다

```bash
REPORT="$(bash scripts/find-todays-report.sh)"
echo "$REPORT"
```

이 스크립트는 원격의 `claude/v3.0.*` 브랜치들을 훑어 오늘자
`reports/requests/<YYYY-MM-DD>.md` 를 워킹트리로 꺼낸다.
날짜는 **KST 기준**이다(러너는 UTC라 그냥 `date`를 쓰면 하루가 밀린다).

**못 찾으면 게시하지 말고 멈춘다.** 08:00 스캔이 실패했다는 뜻이고,
빈 인계나 지어낸 인계를 올리는 것보다 안 올리는 게 낫다.
대신 실패 사실만 한 줄로 Slack에 올린다:

```bash
printf '# biolabs3 · Alpha\n\n오늘(%s) 08:00 스캔 산출물을 찾지 못했다. 인계할 내용이 없다.\nActions의 alpha-daily / scan 잡 로그를 확인하라.\n' \
  "$(TZ=Asia/Seoul date +%Y-%m-%d)" > /tmp/alpha-fail.md
bash scripts/post-to-slack.sh /tmp/alpha-fail.md
```

## 2. 게시 전 점검 (이게 이 스킬의 존재 이유다)

08:00의 자기 판정은 최종 판정이 아니다. 올리기 전에 다시 본다:

- **비밀값 유출** — 토큰·키·비밀번호·내부 호스트명이 본문에 있나?
  하나라도 있으면 그 줄을 지우고 위치 표기로 바꾼 뒤 커밋한다. 게시가 곧 유출이다.
- **근거 유효성** — 인용한 `파일:줄`이 지금도 그 내용인가?
  08:00 이후 누가 푸시해서 이미 고쳐졌을 수 있다. 고쳐진 항목은 지운다.
- **중복** — 어제 지시서(`reports/requests/`의 직전 파일)와 같은 항목이 있나?
  같은 항목이면 "어제 미처리 이월"이라고 표시한다. 새 발견인 척하지 마라.
- **실행 가능성** — 각 항목이 Cursor가 읽고 바로 착수할 수 있는가?
  "조사 필요"만 적힌 항목은 Cursor가 못 받는다. 착수점을 적어주거나 내려라.

수정했으면 같은 브랜치에 커밋해 원격에도 반영한다(영어 커밋 메시지 + 트레일러).

## 3. 게시한다

```bash
bash scripts/post-to-slack.sh "$REPORT"
```

- 웹훅 URL은 `SLACK_WEBHOOK_URL` 환경변수로만 들어온다.
  **어떤 로그·PR·보고서에도 출력하지 마라.**
- 포맷만 확인하고 싶으면 `DRY_RUN=1` 을 붙인다.
- 스크립트가 마크다운을 Slack mrkdwn으로 바꾸고, 3000자 블록 제한에 맞춰 자르고,
  네트워크 실패시 4회까지 지수 백오프로 재시도한다.

## 4. 게시 후

Slack에 올라간 시점부터 **그 지시서는 Cursor의 큐다.** Alpha는 손대지 않는다.
같은 항목을 Alpha가 나중에 직접 구현하면 충돌한다.

내일 08:00 스캔에서 어제 지시서의 처리 여부를 확인해
미처리 항목을 "이월"로 다시 올린다 — 그게 이 루프가 닫히는 방식이다.

## 5. 끝내기 전에

- [ ] 게시한 보고서에 비밀값이 없다
- [ ] `post-to-slack.sh` 가 exit 0 으로 끝났다 (HTTP 200)
- [ ] 게시 중 수정한 내용이 있으면 원격 브랜치에도 반영됐다
- [ ] 로그 어디에도 웹훅 URL이 찍히지 않았다
