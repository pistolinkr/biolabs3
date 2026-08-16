# Alpha 일일 루프 — 사장이 한 번만 해줘야 하는 설정

코드는 다 올라가 있다. 아래 두 개만 넣으면 다음 날 08:00부터 자동으로 돈다.

## 1. Slack Incoming Webhook 만들기

1. https://api.slack.com/apps → **Create New App** → From scratch
2. 앱 이름 `biolabs3 Alpha`, 워크스페이스 선택
3. 좌측 **Incoming Webhooks** → 토글 **On**
4. **Add New Webhook to Workspace** → 채널로 **#request** 선택 → Allow
5. 생성된 `https://hooks.slack.com/services/...` URL을 복사

이 URL은 **그 자체가 비밀번호다.** 이걸 가진 사람은 #request에 아무거나 올릴 수 있다.
어디에도 붙여넣지 말고 바로 다음 단계로 간다. 새면 같은 화면에서 Revoke 하고 다시 만든다.

## 2. 리포 시크릿 등록

`https://github.com/pistolinkr/biolabs3/settings/secrets/actions` → **New repository secret**

| Name | Value |
|---|---|
| `SLACK_WEBHOOK_URL` | 1번에서 복사한 URL |
| `ANTHROPIC_API_KEY` | https://console.anthropic.com/settings/keys 에서 발급 |

`ANTHROPIC_API_KEY`는 이 리포 전용으로 새로 발급하는 걸 권한다. 다른 데 쓰던 키를
같이 쓰면 나중에 폐기할 때 뭐가 같이 죽는지 알 수 없다.

## 3. 확인

Actions 탭 → **alpha-daily** → **Run workflow** → phase `scan` 선택 → 실행.

- 초록이면: `claude/v3.0.1` 브랜치에 `reports/requests/<오늘>.md` 가 생겼는지 본다.
- 그 다음 phase `handoff` 로 한 번 더 돌려서 #request에 글이 올라오는지 본다.

두 번 다 확인되면 이후는 손 안 대도 된다.

## 스케줄

| 시각(KST) | cron(UTC) | 하는 일 |
|---|---|---|
| 08:00 | `0 23 * * *` | 버그 탐지 · 코드 리뷰 · 보안 · 리서치 → 지시서 커밋 |
| 14:00 | `0 5 * * *` | 지시서 재점검 → Slack #request 게시 |

GitHub의 예약 실행은 **정시 보장이 아니다.** 러너가 붐비면 수십 분 늦게 뜬다.
14:00 잡은 08:00 잡의 결과를 원격 브랜치에서 찾아 쓰기 때문에, 08:00 잡이
늦게 끝나도 순서는 깨지지 않는다. 다만 08:00 잡이 **실패**하면 14:00 잡은
빈 인계 대신 "스캔 실패" 한 줄만 올린다 — 지어낸 지시서를 올리지 않기 위해서다.

## 끄고 싶으면

Actions 탭 → alpha-daily → 우상단 `...` → **Disable workflow**.
워크플로 파일을 지울 필요는 없다.
