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

Actions 탭 → **alpha-daily** → **Run workflow** → 실행.

초록이 뜨고 #request 채널에 지시서가 올라오면 끝이다. 이후는 손 안 대도 된다.
실패하면 채널에 "일일 루프가 실패했다" 한 줄과 실행 로그 링크가 올라온다.

## 스케줄

| 시각(KST) | cron(UTC) | 하는 일 |
|---|---|---|
| 14:00 | `0 5 * * *` | 스캔 → 재점검 → Slack #request 게시 (한 실행 안에서) |

GitHub의 예약 실행은 **정시 보장이 아니다.** 러너가 붐비면 수십 분 늦게 뜬다.

## 지시서는 리포에 남지 않는다

이 리포는 public이다. 지시서에는 아직 안 고친 결함의 위치가 `파일:줄` 단위로 들어간다.
그래서 `reports/` 는 `.gitignore` 에 있고, 지시서는 러너 안에서만 만들어져
Slack으로 나가고 러너와 함께 삭제된다.

**그 결과 이력은 #request 채널에만 있다.** 지난 지시서를 찾으려면 Slack을 검색해야 한다.
채널을 지우면 이력도 사라진다. 장기 보관이 필요하면 Slack 유료 플랜의 메시지 보존
설정을 확인하시라 — 무료 플랜은 최근 90일만 남는다.

리포를 private으로 바꾸시면 지시서를 다시 커밋해서 git으로 이력을 남길 수 있다.
그때는 `.gitignore` 의 `reports/` 줄을 지우고 스캔 스킬의 3번 항목을 되돌리면 된다.

## 끄고 싶으면

Actions 탭 → alpha-daily → 우상단 `...` → **Disable workflow**.
워크플로 파일을 지울 필요는 없다.
