# statusline-setup 사용 결과

> **한 줄 요약** — 번들 asset 2개를 받아 Claude 설정 디렉터리에 설치하고 `settings.json` 의 `statusLine` 을 그 경로로 설정합니다.

```
assets/*.sh  ──▶  /claudecode:statusline-setup  ──▶  $CFG/*.sh + settings.json(statusLine)
```

## 1. 실행한 명령

범용 형식:

```
/claudecode:statusline-setup [--dry-run] [--usage-id ID --usage-api URL] [--budget N]
```

이번 실행 (격리 검증용 임시 설정 디렉터리 `$CFG` 를 대상으로, dry-run 먼저):

```sh
CLAUDE_CONFIG_DIR="$CFG" sh skills/statusline-setup/scripts/install-statusline.sh --dry-run
CLAUDE_CONFIG_DIR="$CFG" sh skills/statusline-setup/scripts/install-statusline.sh
```

## 2. 입력

- `skills/statusline-setup/assets/statusline-command.sh` (17162 bytes)
- `skills/statusline-setup/assets/statusline-tokens.sh` (5576 bytes)
- 앞선 `cache-ttl` 실행 결과가 남아 있는 `$CFG/settings.json`

## 3. 결과

`--dry-run` 은 `dry run: nothing written.` 만 출력하고 파일을 만들지 않았습니다.
실제 설치는 exit 0:

```
installed $CFG/statusline-command.sh
installed $CFG/statusline-tokens.sh
statusLine.command = $CFG/statusline-command.sh
```

`$CFG` 에 두 스크립트가 `-rwxr-xr-x` 로 나란히 설치됐고 `statusLine` 블록이
추가됐습니다. `model` · `env` · `permissions` 는 전부 보존됐습니다.

- 산출물: [`docs/skill-guides/statusline-setup.md`](../skill-guides/statusline-setup.md) — 스킬 설명서
