# cache-ttl

## 한 줄 요약

Claude Code 의 프롬프트 캐시 TTL 을 5분 기본값과 1시간 사이에서 전환합니다.
`settings.json` 의 `env.ENABLE_PROMPT_CACHING_1H` 키 **하나만** 건드리고,
나머지 키는 전부 그대로 둡니다.

## 언제 쓰고 언제 안 쓰는가

**쓸 때**

- 긴 세션에서 같은 컨텍스트를 반복해서 읽히고 있어 캐시 수명을 늘리고 싶을 때
- 1시간 캐시를 켜 뒀다가 기본값으로 되돌리고 싶을 때

**쓰지 않을 때**

| 하려는 일 | 담당 |
|---|---|
| 모델 변경 | Claude Code 의 `/model` |
| 상태줄 설치 | `/claudecode:statusline-setup` |
| `permissions` / `hooks` 편집 | 이 스킬 아님. 직접 편집하거나 `/config` |

## 호출 형식

```
/claudecode:cache-ttl 1h
/claudecode:cache-ttl 5m
/claudecode:cache-ttl          # 인자 없으면 5m
/claudecode:cache-ttl help
```

| 인자 | 의미 |
|---|---|
| `1h` | `.env.ENABLE_PROMPT_CACHING_1H = "1"` |
| `5m` | 그 키를 **삭제**. 삭제 후 `.env` 가 비면 `.env` 자체도 제거 |
| (없음) | `5m` 과 동일 |
| `-h`, `--help`, `help` | 사용법 출력 후 중단 |

## 동작 단계

1. **모드 결정** — 사용자가 "1시간"/"1h"/"길게" 라고 하면 `1h`, "5분"/"기본값"/
   "꺼줘" 면 `5m`. 애매하면 **묻습니다**. 추측하지 않습니다.
2. **스크립트 실행** — `skills/cache-ttl/scripts/set-cache-ttl.sh <mode>`.
   모델이 `jq` 를 직접 타이핑하지 않는 것이 핵심입니다.
3. **보고** — 스크립트가 출력한 before -> after 줄을 그대로 전달하고,
   "Claude Code 재시작 후 적용" 한 문장을 덧붙입니다.

## 대상 파일과 멀티 계정

대상은 `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json` 입니다 (#1751 F-5).
계정이 여러 개면 호출 전에 변수를 지정합니다.

```sh
CLAUDE_CONFIG_DIR=~/.claude-work1 sh skills/cache-ttl/scripts/set-cache-ttl.sh 1h
```

## 안전 계약

- **손실 없는 병합** — `hooks`, `model`, `statusLine`, `permissions`, 그리고
  `.env` 안의 다른 키까지 전부 보존됩니다. `jq` 결과를 대상 디렉터리의 임시
  파일에 쓴 뒤 `mv` 하므로, `jq` 가 실패해도 원본이 잘리지 않습니다.
- **`settings.json` 이 없으면** `{}` 골격을 만든 뒤 패치합니다.
- **JSON 이 깨져 있으면** `settings.json.bak` 으로 복사만 하고 exit 4 로
  멈춥니다. 깨진 JSON 을 덮어쓰는 일은 절대 없습니다.

## 종료 코드

| 코드 | 의미 | 올바른 대응 |
|---|---|---|
| 0 | 성공 | before -> after 보고 |
| 2 | 인자가 `1h`/`5m` 이 아님 | 모드를 다시 정하고 재실행 |
| 3 | `jq` 없음 | 스크립트가 출력한 설치 안내를 전달하고 중단 |
| 4 | `settings.json` 이 유효한 JSON 이 아님 | `.bak` 이 저장됐고 아무것도 쓰지 않았음을 알림 |

`sed` / `python -c` 로 우회하지 않습니다. 깨진 JSON 을 건드리지 않는 것이
기능입니다.

## 독립 실행 (#1751 NF-1)

`dEitY719/dotfiles` 를 한 번도 클론하지 않은 PC 에서도 그대로 동작합니다.
스크립트는 POSIX sh + `jq` 외에 아무것도 요구하지 않고, 스킬 디렉터리 바깥의
어떤 경로도 참조하지 않습니다.
