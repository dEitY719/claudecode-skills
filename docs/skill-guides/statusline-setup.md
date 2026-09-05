# statusline-setup

## 한 줄 요약

플러그인에 동봉된 `statusline-command.sh` / `statusline-tokens.sh` 를 Claude
설정 디렉터리에 설치하고, `settings.json` 의 `statusLine` 블록이 그 경로를
가리키게 합니다. 나머지 키는 전부 그대로 둡니다.

## 언제 쓰고 언제 안 쓰는가

**쓸 때**

- 새 PC 에 상태줄(모델 · git 브랜치 · 컨텍스트/토큰 사용량)을 설치할 때
- 상태줄 스크립트를 번들 버전으로 되돌리고 싶을 때

**쓰지 않을 때**

| 하려는 일 | 담당 |
|---|---|
| 상태줄을 처음부터 직접 작성 | 이 스킬 아님. 이건 번들 스크립트 설치 전용 |
| 캐시 TTL 변경 | `/claudecode:cache-ttl` |
| `model` / `permissions` 편집 | 이 스킬 아님 |

## 호출 형식

```
/claudecode:statusline-setup --dry-run
/claudecode:statusline-setup
/claudecode:statusline-setup help
```

| 인자 | 의미 |
|---|---|
| (없음) | 설치 + `settings.json` 패치 |
| `--dry-run` | 무엇을 할지만 출력하고 **아무것도 쓰지 않음** |
| `--usage-id ID` | `env.CLAUDE_STATUSLINE_USAGE_ID` 설정 |
| `--usage-api URL` | `env.CLAUDE_STATUSLINE_USAGE_API` 설정 |
| `--budget N` | `env.CLAUDE_STATUSLINE_BUDGET` 설정 (양의 정수) |
| `-h`, `--help`, `help` | 사용법 출력 후 중단 |

이미 상태줄을 쓰고 있는 사용자라면 `--dry-run` 을 먼저 돌려 보여 준 뒤
설치합니다.

## Bedrock 비용 세그먼트 설정

`~/.dotfiles-setup-mode` 가 `internal` 이거나 **사용자가 비용 세그먼트를 직접
요청했고**, `settings.json` 에 `env.CLAUDE_STATUSLINE_USAGE_ID` 가 아직 없을 때
해당합니다. 이때 스킬은 **사용자에게 usage id 와 usage API URL 을 물어본 뒤** 그
값을 위 플래그로 넘겨 설치합니다. 파일이 없거나 비어 있고 사용자 요청도 없으면
아무것도 묻지 않고 건너뛰며, 비용 세그먼트 없이 설치합니다.

**파일이 없는 경우를 묻는 조건에서 뺀 이유**: 그 파일은 dotfiles 산출물이므로,
없다는 것은 "이 PC 는 dotfiles 를 클론한 적이 없다" 는 적극적 증거입니다. 즉 이
플러그인만 단독으로 설치한 PC 이고, 조직 내부 usage id 를 갖고 있지 않습니다.
답을 모르는 사용자에게 묻지 않는 것이 맞습니다.

**런타임 게이트는 반대로 그 경우를 허용합니다** — 거기서는 두 환경변수가 실제
잠금장치이기 때문입니다: 설치 시 `--usage-id` / `--usage-api` 를 명시적으로 넘긴
사람에게만 값이 생기므로, 설정하지 않은 PC 는 여전히 아무것도 그리지 않고
네트워크 호출도 하지 않습니다. 반면 파일에 `external` 처럼 다른 값이 적혀
있으면 "이 PC 는 대상이 아니다" 라는 명시적 선언이므로 그대로 존중합니다.

스크립트는 절대 스스로 묻지 않습니다 — 비대화형으로 실행되므로 스크립트 안의
`read` 는 그대로 멈춰 버립니다. 묻는 쪽은 하네스입니다: Claude Code 에서는
`AskUserQuestion`, ask 도구가 없는 하네스는 답변에 질문을 적고 대기합니다.

값은 `~/.zshrc.local` 같은 셸 rc 가 아니라 `settings.json` 의 `env` 블록에
들어갑니다. Claude Code 가 이 블록을 상태줄 명령의 환경으로 주입하기 때문이며,
`cache-ttl` 스킬이 `ENABLE_PROMPT_CACHING_1H` 에 쓰는 경로와 같습니다.
플래그를 생략하면 그 키는 손대지 않습니다 — 이미 넣어 둔 값이 지워지는 일은
없습니다. 두 값 중 하나만 넘기면 경고를 출력하되 준 값은 그대로 쓰고 exit 0
입니다 (세그먼트는 둘 다 채워질 때까지 꺼진 상태로 남습니다).

## 선행 조건

- `jq` — 없으면 설치 안내 후 exit 3
- **bash 4.4 이상** — `statusline-command.sh` 가 연관 배열을 씁니다.
  macOS 기본 bash 는 3.2 이므로 `brew install bash` 가 먼저입니다.
  동작하지 않을 상태줄을 깔지 말고 이 사실을 말해 줍니다.

## 동작 단계

1. 번들 asset 2개를 `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/` 로 복사하고
   둘 다 `chmod +x` (dotfiles #1751 F-3).
2. 대상 파일이 이미 있고 **내용이 다르면** `<name>.bak` 으로 백업한 뒤 교체하고,
   백업했다는 사실을 출력합니다. 내용이 같으면 백업하지 않습니다.
3. `settings.json` 의 `.statusLine` 을
   `{"type":"command","command":"<절대경로>/statusline-command.sh"}` 로 설정
   (dotfiles #1751 F-4). 같은 병합에서 `--usage-id` / `--usage-api` / `--budget` 로
   넘어온 `env.CLAUDE_STATUSLINE_*` 키도 함께 씁니다.

두 파일은 반드시 같은 디렉터리에 나란히 있어야 합니다 —
`statusline-command.sh` 가 자신이 resolve 된 경로의 **형제**로
`statusline-tokens.sh` 를 source 하기 때문입니다.

## 경로에 `~` 를 쓰지 않는 이유

`statusLine.command` 에는 이미 확장된 절대 경로(`/home/you/.claude/...`)를
씁니다. Claude Code 가 이 자리의 `~` 를 안정적으로 확장하지 않기 때문이며,
보기 좋게 `~` 로 되돌리면 상태줄이 조용히 죽습니다.

## 안전 계약

- **손실 없는 병합** — `hooks`, `env`, `model`, `permissions` 전부 보존.
  임시 파일 + `mv` 라서 `jq` 실패가 원본을 자르지 못합니다.
- **JSON 이 깨져 있으면** `settings.json.bak` 만 남기고 exit 4 로 멈춥니다.
- **`--dry-run` 은 파일을 하나도 만들지 않습니다** — `settings.json` 조차
  생성하지 않습니다.

## 종료 코드

| 코드 | 의미 | 올바른 대응 |
|---|---|---|
| 0 | 성공 | 설치 경로와 `statusLine.command` 보고 |
| 2 | 알 수 없는 인자, 값 없는 플래그, 양의 정수가 아닌 `--budget` | 호출을 고쳐 재실행 (`--help` 참고) |
| 3 | `jq` 없음 | 설치 안내 전달 후 중단 |
| 4 | `settings.json` 이 유효한 JSON 이 아님 | `.bak` 저장됨, 아무것도 쓰지 않음 |
| 5 | 번들 asset 누락 | 플러그인 설치가 손상됨. 재설치 |

## asset 은 스냅샷입니다 (dotfiles #1751 Non-Goal)

`skills/statusline-setup/assets/` 의 두 파일은 `dEitY719/dotfiles` 의
`claude/statusline-{command,tokens}.sh` 를 커밋 `b23e4d9` 시점에 복사한
것입니다. upstream 을 추적하지 않습니다.

dotfiles 쪽이 바뀌어도 이 저장소는 알아채지 못하며, 이 드리프트는 dotfiles #1751 의
**명시적 Non-Goal** 이지 결함이 아닙니다. 재번들은 의도적인 수작업입니다 —
두 파일을 다시 복사하고 아래 변경 1건을 다시 적용한 뒤 SHA 가 적힌 모든 파일의
커밋 SHA 를 갱신하고 `tests/run.sh` 를 다시 돌립니다. 갱신 대상 목록의 SSOT 는
`skills/statusline-setup/references/re-bundling.md` 입니다.

`statusline-tokens.sh` 는 원본과 바이트 단위로 동일합니다. `statusline-command.sh`
는 한 곳만 다릅니다 — 원본의 Bedrock 비용 세그먼트는 조직 내부 사용자 id 와
usage API 호스트를 하드코딩하는데, 이 저장소는 공개이므로 번들 사본은 두 값을
`CLAUDE_STATUSLINE_USAGE_ID` / `CLAUDE_STATUSLINE_USAGE_API` 환경변수에서 읽고
(예산은 선택적 `CLAUDE_STATUSLINE_BUDGET`, 기본 175), 둘 다 설정돼 있지 않으면
세그먼트 자체를 건너뜁니다. 설정하지 않은 설치본은 네트워크 호출을 하지
않습니다. 그 값들은 위 "Bedrock 비용 세그먼트 설정" 대로 설치 스크립트가
`settings.json` 의 `env` 블록에 써 넣습니다. **재번들 때마다 이 변경을 다시
적용하세요.** 그 블록 외에는 asset 을 손으로 고치지 마세요.

## 독립 실행 (dotfiles #1751 NF-1)

`dEitY719/dotfiles` 를 한 번도 클론하지 않은 PC 에서도 그대로 동작합니다.
필요한 파일은 전부 스킬 디렉터리 안에 있습니다. 설치된 상태줄은 `--usage-id` 와
`--usage-api` 를 넘겼을 때만 usage API 를 호출하고, 그 외에는 네트워크를 쓰지
않습니다.
