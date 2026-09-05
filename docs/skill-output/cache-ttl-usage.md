# cache-ttl 사용 결과

> **한 줄 요약** — 기존 `settings.json` 을 받아 `env.ENABLE_PROMPT_CACHING_1H` 한 키만 바꾼 `settings.json` 을 생성합니다.

```
settings.json  ──▶  /claudecode:cache-ttl 1h  ──▶  settings.json (env 키 1개 추가)
```

## 1. 실행한 명령

범용 형식:

```
/claudecode:cache-ttl [1h|5m]
```

이번 실행 (격리 검증용 임시 설정 디렉터리 `$CFG` 를 대상으로):

```sh
CLAUDE_CONFIG_DIR="$CFG" sh skills/cache-ttl/scripts/set-cache-ttl.sh 1h
```

## 2. 입력

`$CFG/settings.json` — `model`, `env.SOME_OTHER_KEY`, `permissions` 를 가진 기존 설정 파일.

## 3. 결과

exit 0. 스크립트 출력:

```
cache TTL: 5m -> 1h  (env.ENABLE_PROMPT_CACHING_1H: (unset) -> 1)
file: $CFG/settings.json
Restart Claude Code to pick it up.
```

`$CFG/settings.json` 에 `env.ENABLE_PROMPT_CACHING_1H: "1"` 이 추가됐고,
`model` · `env.SOME_OTHER_KEY` · `permissions` 세 키는 그대로 남았습니다.

- 산출물: [`docs/skill-guides/cache-ttl.md`](../skill-guides/cache-ttl.md) — 스킬 설명서
