# Hyphen — 시스템 아키텍처 브리프 (SSOT)

> **작성일**: 2026-05-22
> **상태**: 합의 완료 — 이후 모든 작업의 중심 문서
> **적용 범위**: `apps/facing-app` (폰) + `web/facing-admin` (PC) + `services/facing` (백엔드)
>
> ⚠️ **이 문서가 우선이에요.** 코드 변경·새 기능 설계 시 이 브리프와 충돌하면 브리프를 따르고, 브리프를 바꿔야 한다면 사용자 명시 승인 후 문서 먼저 갱신해요.

---

## 0. 한 줄 요약

> **폰은 일상, PC는 운영. 백엔드는 단일 진실. 역할은 회원·코치·사장 3개. 실시간 동기화는 SSE.**

**시스템 카테고리**: CrossFit 박스 전용 **Vertical SaaS for Gym** (B2B2C · 멀티테넌시 + flat RBAC 3-tier + 실시간 SSE). 해외 동종: Wodify·PushPress·Mindbody. 아키텍처 패턴·법규·학술 근거 SSOT → `~/.claude/reference/study/gym-management-saas.md` (15 sub-topic · 94 source).

---

## 0.1. PHASE4 시작 (2026-05-23)

> **상태**: PHASE3 P0 18 + P1 24 + P2 14 = 56 task 완료 후 진입 예정. 본 섹션은 PHASE4 계획 선등록.
> **상세 로드맵**: `docs/_archive/PHASE4_ROADMAP.md`(2026-08-13 폐기 이동)

### 0.1.1. PHASE4 목표 — 듀얼 포지셔닝 확립

**"linko 는 운영, Hyphen 은 운영 + 선수."**

linko.my (한국 1위급, 350+ 박스) 의 운영 자동화 7 모듈을 흡수하면서, Hyphen 만의 선수 도구 4 모듈을 동시에 강화해 패스트팔로워 함정을 회피한다.

### 0.1.2. 11 모듈 요약

**흡수 7 모듈 (linko.my 추격)**:
1. §1.1 예약 시스템 (Class Reservation) — **P0** 1주
2. §1.2 카카오 알림톡 알림 자동화 — **P0** 3일 + NHN 사전심사 1주 (→ **2026-08-26 D60 폐기** — 알림은 앱 쪽지로 통일, `api/notifications/note.py`)
3. §1.3 전자계약 (e-Sign, PDF, audit hash) — **P0** 1주
4. §1.4 다지점 그룹 (gym_group + RLS) — P1 2주
5. §1.5 Toss 빌링키 자동결제 + 재시도 + grace period — **P0** 1주
6. §1.6 WOD 디자인 도구 + 월간 캘린더 + 복붙 — P1 1주
7. §1.7 AI 코칭 보조 (Claude API, HITL 의무) — P2 3일

**차별 강화 4 모듈 (Hyphen 만)**:
8. §2.1 W-prime·CGM 페이싱 알고리즘 정밀화 — **P0** 2주
9. §2.2 5-Tier Engine 백분위 + 박스 leaderboard — P1 3일
10. §2.3 Games 선수 어휘·톤 PC 확장 — P2 2일
11. §2.4 듀얼 포지셔닝 B2B2C 데이터 브릿지 — **P0** 1주

**P0 총 공수**: ~6.4주 (parallel 시 ~5주) / **전체**: ~9~10주

### 0.1.3. B2B2C 데이터 브릿지 흐름

```
[폰 facing-app]               [PC facing-admin]
  회원 1RM·Engine·Tier   →    회원 등록 시 hydrate
        ↓                            ↓
    [services/facing 백엔드]
        ↓
   [linko 운영 자동화 흡수]
   예약·알림톡·전자계약·다지점
```

회원이 facing-app 으로 입력한 1RM·Engine·Tier → 박스 가입 시 코치에게 자동 공유 (PIPA §22 별도 동의). linko 가 따라올 수 없는 B2B2C 융합 영역.

---

## 0.5. 인프라 카탈로그 (헷갈림 차단 — INDEX)

### 0.5.1. 포트 · URL · 환경

| 컴포넌트 | 로컬 URL | Flask 환경 | 에뮬레이터 호출 URL | 실기/배포 호출 URL | 비고 |
|---|---|---|---|---|---|
| **백엔드** `services/facing` | `http://localhost:5060` | `debug=True` (Werkzeug dev) | `http://10.0.2.2:5060` | `http://<LAN-IP>:5060` 또는 Railway URL | 폰·PC 둘 다 호출. host=`0.0.0.0` 으로 LISTEN |
| **PC 사장 웹** `web/facing-admin` | `http://localhost:8081` | `debug=True` (Werkzeug dev) | (해당 없음) | (Phase 2 후반 Railway) | **5060/5061 은 Chrome `ERR_UNSAFE_PORT` 차단**. 8081 사용 필수 |
| **폰 앱** `apps/facing-app` | (해당 없음) | Flutter | `flutter run` 시 `--dart-define=API_BASE_URL=http://10.0.2.2:5060` | release APK 빌드 시 `--dart-define=API_BASE_URL=http://192.168.x.x:5060` 또는 배포 URL | base URL 미지정 default = `10.0.2.2:5060` (에뮬레이터 전용) |

### 0.5.2. 데이터베이스

| 컴포넌트 | 경로 | 형식 | git 추적 | 비고 |
|---|---|---|---|---|
| 백엔드 메인 DB | `services/facing/data/facing.db` | SQLite | **추적 X** (.gitignore) | 페르소나·박스·WOD·결과 등 모든 진실 |
| 백엔드 WAL | `facing.db-wal` / `facing.db-shm` | SQLite WAL | 추적 X | 자동 생성 |
| PC 사장 mockup | `web/facing-admin/data/mock_*.json` | JSON | 추적 O (회의 데모용) | Phase 1.5 에서 `facing.db` 의 신규 6 테이블로 마이그레이션 → 폐기 |
| 페르소나 SSOT | `services/facing/data/personas.json` | JSON | 추적 O | 시드 스크립트 입력 |

### 0.5.3. 환경변수

| 변수 | 위치 | 값 | 용도 |
|---|---|---|---|
| `SECRET_KEY` | `C:/dev/.env` (글로벌) 또는 `services/facing/.env` | 사용자 정의 (없으면 default `facing_default_salt`) | device_hash 솔트. 변경 시 페르소나 해시 모두 어긋남 |
| `PORT` | `services/facing/.env` | 5060 | 백엔드 포트 (글로벌 PORT 와 분리) |
| `APP_TEST_ADMIN_ID` / `APP_TEST_ADMIN_PASSWORD` | `C:/dev/.env` | 사용자 정의 | 슈퍼관리자 시드 (CLAUDE.md §3-A) |
| `ANTHROPIC_API_KEY` | 배포 PaaS 만 (Railway 콘솔) | Anthropic key | **로컬 .env 에 절대 X** (CLI 우회용) |
| `API_BASE_URL` | Flutter dart-define (빌드 시) | URL | facing-app 백엔드 호출 base |

### 0.5.4. 데모 계정 (의무 시드)

| ID | PW | 권한 | 시드 위치 |
|---|---|---|---|
| `admin` | `1234` | 슈퍼관리자 (모든 환경 시드) | 백엔드 부팅 시 자동 |
| `${APP_TEST_ADMIN_ID}` | `${APP_TEST_ADMIN_PASSWORD}` | 슈퍼관리자 (env 있을 때만, 프로덕션 skip) | env 기반 |
| `boss_seongsu` | `1234` | HYPHEN 사장 (PC 웹) | Phase 1 마이그레이션 |
| `coach_park` | `1234` | HYPHEN 코치 (폰 페어링 가능) | Phase 1 |

폰 페르소나 4명 (`persona-coach-park-2026` 등) 은 device_id 시드로 별도. 위 ID/PW 계정은 PC 사장 웹 로그인 전용.

### 0.5.5. 자주 헷갈리는 점

- ⚠️ **에뮬레이터 `10.0.2.2`** 는 Android 가상 호스트 PC 별칭. 실기는 LAN IP (예: `192.168.1.100`) 또는 배포 URL.
- ⚠️ **`localhost:5061` Chrome 에서 안 열림** — SIP-TLS 표준 포트라 차단. 사장 웹은 8081.
- ⚠️ **`SECRET_KEY` 변경하면 페르소나 해시 다 어긋남** — 시드 재실행 필요. 회의 직전엔 default salt 유지.
- ⚠️ **Windows bash + curl 한글 payload 깨짐** — 검증용으로 curl 쓸 때만. 폰·웹 폼은 정상 (UTF-8 자동).
- ⚠️ **debug APK 약 178MB / release APK 약 30MB** — 회의 시연은 페르소나 스위처 필요 → debug 필수.

---

## 1. 시스템 구성

```
                      ┌────────────────────────┐
                      │ Backend (Flask+SQLite) │
                      │  services/facing       │
                      │  단일 진실 (SSOT)      │
                      └───┬────────────────┬───┘
                          │ REST + SSE     │ REST + SSE
                          │                │
              ┌───────────▼──────┐   ┌─────▼──────────────┐
              │ 폰 앱 (Flutter)  │   │ PC 웹 (Flask)      │
              │ apps/facing-app  │   │ web/facing-admin   │
              │                  │   │                    │
              │ 회원 + 스태프    │   │ 스태프 전용        │
              │ (회원은 여기만)  │   │ (사장 = 코치)      │
              └──────────────────┘   └────────────────────┘
```

- **백엔드 1개** (`services/facing`, Flask + SQLite) — 단일 진실 (SSOT)
- **클라이언트 2개** (§2-0 대전제 2·3)
  - **폰** (`apps/facing-app`, Flutter): 회원의 **유일한** 창구 + 스태프 보조 운영
  - **PC 웹** (`web/facing-admin`, Flask + 바닐라 HTML/CSS/JS): 스태프(사장·코치·매니저) 주 창구
- **통신**: REST + SSE (Server-Sent Events)

> **회원용 웹 화면은 만들지 않는다 (강제·차단).** 회원이 PC 로 이 서비스를 쓸
> 일도, 그럴 가치도 없다. 회원의 창구는 폰 앱 하나뿐이고, 백엔드가 회원에게
> 내주는 것은 JSON API 뿐이다. 브라우저 화면은 코치·사장용 PC 웹 하나다.
> (2026-08-12 — 시험 삼아 만들었던 회원 모바일 웹 `/m` 은 삭제. 재도입 금지.)

폰과 PC 가 같은 DB·같은 API 를 다른 화면으로 본다는 게 핵심이에요. 클라이언트는 따로지만 데이터는 한 곳.

**PHASE4 B2B2C 확장 (§0.1.3 참조)**:

```
[폰 facing-app]                    [PC facing-admin]
  회원 1RM·Engine·Tier     →       회원 등록 시 hydrate
  (device_hash 익명 → 동의 연결)         ↓
        ↓                     코치 클래스 12명 페이싱 카드
    [services/facing 백엔드 — 단일 진실]
        ↓
   [PHASE4 운영 자동화 흡수]
   예약·카카오 알림톡·전자계약·다지점·Toss 빌링키
```

---

## 2. RBAC — 역할은 셋뿐 (코치 · 회원 · 회원신청자)

### 2-0. 3면 공통 대전제 (강제·차단 · 2026-08-12 사용자 지시)

> **이 대전제가 Hyphen 전체(앱·PC 웹·백엔드)의 상위 규칙이다.** 아래 표·D 결정·각 repo
> CLAUDE.md 는 전부 이것의 각론이다. 충돌하면 **이 대전제가 이긴다.**
>
> ※ **5번(제품은 코치↔회원 4기둥뿐)은 3면 CLAUDE.md 가 정본**이라 아래 표에 행이 없다
> (D64·D65). 번호는 3면 CLAUDE.md 와 같은 것을 가리킨다.

| # | 규칙 | 뒤따르는 금지 |
|---|---|---|
| **1** | **사장 = 매니저 = 코치 = 운영 권한.** 셋을 권한으로 가르지 않는다 | 코치라서 막는 분기 신설 금지 (nav·버튼·API 전부). 새 스태프 엔드포인트는 `@require_staff` 하나 |
| **2** | **회원은 폰(앱)에서만 쓴다** | 회원용 웹 화면·템플릿·로그인 페이지 신설 금지. 백엔드가 회원에게 주는 것은 **JSON API 뿐** |
| **3** | **사장·코치는 PC 에서도 쓴다** (PC 가 주, 폰이 보조) | "사장은 폰 안 씀"·"코치는 PC 안 씀" 같은 전제 금지. 스태프 기능은 양면 모두에서 도달 가능해야 한다 |
| **4** | **전 체육관은 한국이다 — 시간대는 KST 하나** (2026-08-26 사용자 "전부 한국이야, 확실히 못박아놔" = D56) | `gyms.timezone` 'Asia/Seoul' 외 값 · 다른 시간대 대비 작업(func.date 범위 전환·시간대 설정 화면) 금지. 폰·PC 는 표시만 기기 시간대 |
| **6** | **한 사실은 한 곳에서만 센다** (2026-08-29 사용자 "각자 다른 걸 말하는 이원화 현상이 주된 이유다. 명백히 법적으로 막아라") | 같은 사실을 두 곳에서 세는 것 금지 · 등재 안 한 창구 신설 금지 · 사실이 바뀌는 사건을 덮어쓰는 것 금지 |

**규칙 6 — 이원화 금지 (강제·차단 · 2026-08-29 사용자 지시).**

1. **화면에 보이는 모든 수치·판정은 세는 함수 한 개에서만 나온다.** API 도 화면도
   **부르기만** 한다. 정본 = `services/facing/api/_metrics.py` (§0-B).
2. **같은 사실을 두 곳에서 세면 값이 우연히 같아도 결함이다.** 한쪽만 고치는 순간
   두 화면이 다른 숫자를 말한다 — 지금까지 난 결함의 뿌리가 전부 이것이었다
   (예약 인원 4곳 · 대기 인원 3곳에 정의 2가지 · 매출 3곳에 기준 3가지 ·
   만료 임박 3곳에 모집단 3가지).
3. **새 창구는 일치 검사 목록에 등재해야 한다.** 등재 안 하면 통과하지 못한다.
4. **사실이 바뀌는 사건은 덮어쓰지 말고 쌓는다.** 취소 이력이 지워져 결함 두 건이 났다.
5. **위반은 게이트 둘이 자동으로 잡는다** — 문서로 적는 것은 이미 여러 번 뚫렸다.
   - `services/facing/tests/test_ssot_metrics_lint.py` — 정의를 정본 밖에서 다시
     적으면 실패 (기존 위반은 baseline, **늘면 실패 · 줄면 낮추라고 알림**).
   - `services/facing/tests/test_ssot_agreement.py` — 창구 **등록제**. 값 대조 정본은
     `tests/test_roundtrip_numbers.py`.
6. **6-b 이음새 (2026-08-29 사용자 "절대규칙으로 이음새, 이원화, api, 같은 곳을 보고, 같은 것을
   계산하고, 이거 정말 중요하다").** 수치 밖에도 적용한다 — 앱↔서버↔PC 를 건너는 모든 것
   (**허용값·라벨·검증 규칙·표시 텍스트 렌더링·정렬 기준·범위 정의**)은 정의 1곳에서만 나오고
   나머지는 부르기만 한다. PC JS·앱에 매핑 표·검증·정책 계산 복제 금지 (API 응답의 값·라벨
   그대로). 서버 안에서도 같은 리터럴 집합을 두 파일에 적지 않는다 (import 파생). 정의를 만들면
   같은 커밋에 정적 게이트. 첫 적용 = D88 (`services/program_lines.py` · `models/movement_library.py`
   · `tests/test_ssot_program_lint.py`). 3면 CLAUDE.md 규칙 6 에 같은 문구.

**규칙 1 에 예외는 없다 (D37, 2026-08-12).** 회원 이름·연락처·생년월일 전부 스태프
평문이다. 구 PII 마스킹(D30)은 폐기 — 아래 D37 참조.

**규칙 2 의 배경** — 회원 모바일 웹 `/m` 은 2026-08-12 전부 삭제됐다. 재도입 금지.
회원 화면 검증은 앱(에뮬레이터·실기)으로 한다. "브라우저로 대신 확인" 경로를 다시 만들지 말 것.

**규칙 3 의 현재 배선** — PC = `web/facing-admin` (주) · 폰 = `apps/facing-app` 사장 화면 (보조).
둘 다 같은 백엔드·같은 세션 계정(ID/PW)을 쓴다.

**규칙 1 의 이름은 넷뿐 — 정본 = `services/facing/api/roles.py` (강제·차단).**

| 쓸 것 | 뜻 |
|---|---|
| `STAFF_ROLES` | 운영 권한 역할 목록 `("boss","manager","coach")`. **다른 파일에서 재정의 금지** |
| `@require_staff` | 스태프 엔드포인트의 **유일한** 게이트 데코레이터 |
| `is_staff(role)` | 함수 중간 분기용 판정 |
| `FORBIDDEN_STAFF_MSG` | 거절 문구 — "운영 권한이 필요합니다." 하나 |

한국어 용어도 **"운영 권한"** 하나로 쓴다 ("사장 권한"·"권한 부족" 금지).
역할 목록을 인자로 받는 게이트(`require_role([...])` 류)는 만들지 않는다 — 호출부마다
목록이 갈려 매니저가 코치보다 낮아지는 역전을 낳은 장본인이다.

**2026-08-12 통일 — 여섯 이름이 흩어져 있던 것을 위 넷으로 합쳤다 (옛 이름·별칭 전부 삭제).**

| 없어진 이름 | 있던 곳 | 문제였던 점 |
|---|---|---|
| `BOSS_LEVEL_ROLES` | `api/admin.py` | 같은 튜플이 두 파일에 |
| `_STAFF_ROLES` | `api/classes.py` | 〃 — 한쪽만 열려 사고 |
| `require_boss` | `api/admin.py` (71곳) | 이름이 "boss" 라 스태프 게이트인 줄 모름 |
| `require_role([...])` | `api/admin.py` (10곳) | 호출부마다 목록이 달라 매니저 역전 |
| `_require_boss` · `_require_boss_or_coach` | `api/contracts.py` | 파일 자체 게이트 — 공용 상수를 안 봄 |
| `_require_admin_role` | `api/classes.py` | 사용처 0, 권한 재분할의 씨앗 |

**회귀 방지** — `services/facing/tests/test_rules_prem.py` 9개가 이 3줄을 코드로 강제한다.
`boss` 는 통과시키면서 `coach`/`manager` 를 막는 게이트(튜플·단일비교 양쪽)를 정적 검사로
잡고, **역할 목록이 `roles.py` 밖에 또 정의되는 것**과 **거절 문구가 갈리는 것**까지 막는다.
백엔드 HTML 렌더 0개·삭제된 회원 웹 미부활·폐기 전제 주석 재등장도 함께 본다.
인가 게이트만 골라내려고 "403 을 뱉는가"로 판정한다 (신원 환산용 role 분기는 정상이라 제외).

**실호출 검증 (2026-08-12, 신규 임시 DB · boss_seongsu·coach_park·mgr_test)**
계약서 9종 + 가입코드 발급 1종 × 3역할 = **30콜 전부 게이트 통과 (403 0건)**.
쓰기 엔드포인트는 빈 본문·없는 id 로 호출해 400/404 를 받아 **데이터는 안 바꿨다**.
비로그인 7콜은 전부 401 — 게이트를 없앤 게 아니라 스태프에게만 연 것이 맞다.

> ⚠ **로컬 dev DB 스키마 드리프트** — `data/facing.db` 의
> `ck_gym_manager_role` 이 `('boss','coach')` 라 **매니저 계정을 아예 못 만든다**
> (운영·신규 DB 는 `('boss','manager','coach')` 로 정상). 매니저 역전 버그가 오래 살아남은
> 이유가 이것이다 — 로컬에서 재현이 불가능했다. 위 검증을 신규 임시 DB 로 돌린 이유.


### 2-0-1. 역할은 **딱 셋** (강제·차단 · 2026-08-12 사용자 지시 = D35)

> "코치(사장이자 매니저이자 모든 것) · 회원 · 회원신청자(뉴비) 딱 3개밖에 없다."
> 넷째 역할을 새로 만드는 제안·코드·문서는 **전부 반려**한다.

| 역할 | 클라이언트 | 권한 | 백엔드 값 (계약 — 그대로 둠) |
|---|---|---|---|
| **코치** | **PC 주 + 폰 보조** | 박스 운영 **전권**. 회원 DB CRUD·회원권·락커·전자계약·통계·WOD 게시·수업·가입 승인·쪽지. PII 전부 평문 (D37) | `gym_managers.role ∈ (boss, manager, coach)` — **셋 다 같은 코치** |
| **회원** | **폰 전용** | 자기 WOD·결과 저장·수업 예약·박스 공지·코치에게 쪽지·배지·tier | `gym_members.status = approved` |
| **회원신청자** | **폰 전용** | 가입 신청서 제출·심사 결과 확인까지. 박스 콘텐츠 열람 불가 | `gym_members.status = pending` |

- **super admin (서비스 운영자 = 사용자 본인) 은 아직 없다.** 필요해지면 그때 넷째로 추가한다
  — 지금 자리를 미리 파두지 않는다 (사용자 명시: "이건 나중에 하기로 한다").
- 사람이 읽는 말은 위 셋뿐이다. 사장·오너·매니저·짐매니저·관리자는 **제품에 없는 말**
  (표기 정본 = `docs/GLOSSARY.md`, 자동 게이트 = `test/copy_lint_test.dart`).
- **백엔드 enum 은 이번에 바꾸지 않는다** — `boss|manager|coach` 3값은 DB·API 계약이라
  3면 동시 수정이 필요하다 (§0-B). 지금 통일된 것은 **개념과 표기**이며, 게이트는 이미
  `STAFF_ROLES` 하나라 권한상 차이는 **이미 0** 이다. 값 정리는 별도 승인 작업.
- **거부됨(rejected)·탈퇴(left) 는 역할이 아니라 상태다.** 회원신청자의 심사 결과일 뿐,
  넷째 역할로 세지 않는다.

> **D29 (2026-08-12 사용자 결정) — 코치 = 사장.** 코치에게 수업 삭제를 포함한 운영 권한 전부 부여.
> 구 정의(회원 권한 + WOD 게시·회원 목록·쪽지·피드백·가입 승인)는 폐기.
>
> - 구현 지점 1곳: `services/facing/api/roles.py` `STAFF_ROLES`
>   — `@require_staff` 를 쓰는 모든 엔드포인트의 접근 주체를 이 상수가 정한다.
>   되돌리려면 이 한 줄을 `("boss",)` 로 좁히면 끝 (2026-08-12 이름 통일 후).
> - `web/facing-admin` 은 nav·버튼의 coach 분기를 전면 제거 (`_layout.html`·`members.html`).
> - PII 마스킹은 D30 에서 이름만 열었다가 **D37 에서 통째로 폐기**됐다 (아래).
> - **manager 포함** (2026-08-12 후속). 코치만 올리면 manager < coach 역전이 생겨
>   `STAFF_ROLES = ("boss", "manager", "coach")` 로 함께 정리했다.
> - 클래스 CRUD 의 인라인 role 체크도 같이 열었다 — 데코레이터가 아니라 함수 안
>   `if` 라 상수 변경만으로는 안 열렸다. 지금은 그 자리도 `is_staff()` 를 본다.
>
> **실기 검증 (2026-08-12, 로컬 5060 · coach_park/1234)**
> 락커·계약서·요금제·코치목록·회원목록·대시보드·알림설정·클래스목록 8종 전부 200,
> 수업 생성(201)→수정(200)→명단(200)→취소(200) 4단계 통과. 타 박스 클래스는 403 유지
> (테넌트 격리 정상). 당시 PII 는 코치에게 마스킹돼 있었다 — D37 에서 폐기.

> **D30 (2026-08-12) — 코치는 회원 '이름' 만 평문.** → **D37 로 대체됨 (폐기).**
> 마스킹을 항목 단위로 조금 열어 본 중간 단계였다. 반나절 만에 같은 문제가
> 연락처에서 다시 터져 마스킹 자체를 없앴다. 기록만 남긴다.

> **D37 (2026-08-12 사용자 결정) — 코치 PII 마스킹 전면 폐기. 규칙 1 에 예외 없음.**
> 코치는 한 명뿐이고 그 사람이 박스를 통째로 운영한다. 명단에서 "누가 예약했는지" 를 봐도 번호가 `010-****-0002`
> 면 결석 연락·대기 승격 안내를 못 한다. "권한은 같게, 개인정보만 최소권한" 이라는
> 축 분리는 이 박스의 운영 실제와 맞지 않았다.
>
> - 삭제: `api/admin.py` 의 `ROLE_SCOPES` · `_viewer_scope()` · `_mask_pii()` (별칭도 없음).
>   호출부는 회원 목록(`/admin/gyms/<id>/members`)과 명단(`/admin/classes/<id>/reservations`) 둘.
> - 응답에서 `viewer_scope` 필드도 사라졌다 (소비처 0곳 확인 후 제거).
> - 회원 개인정보 보호는 **테넌트 격리**(`assert_gym_match`) + **감사로그**(`AuditLog`)가 맡는다.
>   남의 박스 회원은 애초에 404 라 마스킹이 방어선이었던 적이 없다.
> - **재도입 금지** — `tests/test_rules_prem.py::test_no_pii_masking_for_staff` 가
>   심볼 부활과 "전화번호를 별표로 덮는 새 코드" 양쪽을 정적 검사로 잡는다.

> **D38 (2026-08-12 사용자 지시) — 코치 계정 관리 기능 전면 폐기.**
> "이건 그냥 코치 한 명이 회원관리 앱으로 쓰는 것" — 코치를 여러 명 두고 뽑고
> 내보내는 전제 자체가 이 제품에 없다.
>
> - 삭제(백엔드): GET/POST/PATCH/DELETE `/api/v1/admin/gyms/<id>/coaches[...]` ·
>   페어링 코드 재발급 · `POST /api/v1/coach/pair` · `_make_pairing_code` ·
>   `_pairing_expired` · `PAIRING_CODE_TTL_HOURS` · 세션·응답의 `employment_type`
> - 삭제(PC 웹): `/coaches` 라우트 + `templates/coaches.html` + 좌측 nav '코치' +
>   수업 생성·수정 모달의 '담당 코치' 선택과 코치 매핑 JS
> - 삭제(시드): 마스킹 검증용으로만 있던 '알바 코치' 계정 + 고용형태 값
> - **남긴 것**: 코치 **프로필**(`/api/v1/gyms/<id>/coaches`) — 회원 앱 박스 소개
>   카드에 쓰는 공개 정보라 계정 관리와 다른 기능이다
> - **휴면 컬럼**: `gym_managers.pairing_code` · `pairing_code_issued_at` ·
>   `employment_type` — 2026-08-13 사용자 승인으로 **DROP 완료** (아래 D40)
> - 재도입 금지 — `tests/test_rules_prem.py::test_no_staff_management` 가 감시

> **D40 (2026-08-13 사용자 승인) — 계약서 읽는 표 일원화 + 휴면 스키마 DROP.**
>
> - **계약서 정본은 `contract_instances` 하나.** 발급(POST)은 템플릿 기반
>   ContractInstance 를 쓰는데 회원 상세의 조회(GET)만 레거시 `gym_contracts` 를
>   읽고 있어, 계약서를 발급해도 그 탭이 **영원히 "계약서 없음"** 이었다.
>   `GET /api/v1/admin/members/<id>/contracts` 를 `api/contracts.py` 로 옮겨
>   ContractInstance 를 읽게 하고, `api/admin.py` 의 레거시 핸들러 3개
>   (회원별 목록 · 박스 전체 목록 · `POST .../contracts/<id>/sign`)는 삭제했다.
>   개인정보 export(`api/privacy.py`)도 같은 표를 본다.
> - **DROP (`models/base.py::_migrate_drop_dormant`, 부팅 시 idempotent)**:
>   표 `gym_contracts`(0행일 때만) · `member_claim_codes` /
>   컬럼 `gym_managers.pairing_code` · `pairing_code_issued_at` ·
>   `employment_type` · `user_id`, `gym_members.claim_code` ·
>   `claim_code_expires_at` · `user_id`.
>   `user_id` 는 소셜 계정 역참조인데 실제 연결은 `social_accounts.device_hash` ·
>   `staff_login_id` 가 하고 있어 모델에도 없던 죽은 컬럼이다.
> - 곁가지: `gym_managers` 를 모델 DDL 로 다시 만들면서 옛 role CHECK
>   (`boss`·`coach` 뿐이라 `manager` 를 못 넣던 것)가 모델 기준으로 맞춰졌다.

> **D41 (2026-08-24) — 예약 정책 2종: 종료 수업 차단 + 하루 예약 한도.**
>
> - **종료 수업 차단 (갭 픽스)**: 종전엔 어제 수업도 `status=open` 이면 예약이
>   통과됐다. `POST /member/classes/<id>/reservations` 와 회원 취소 DELETE 에
>   `CLASS_ENDED`(409) 게이트 — **컷오프 = 시작 + duration_minutes (종료 시각)**.
>   시작 시각이 아닌 이유: 코치 대리 예약 API 가 없어 지각 회원의 수업 중
>   자가 예약(→명단 등재)이 유일한 구제 경로다. 취소까지 막는 이유: 끝난 뒤
>   취소하면 노쇼 기록을 회피한다 — 출결 정정은 스태프 PATCH 만.
>   앱 거울: `ClassSessionDto.isEnded` (appClock) → 버튼 숨김 + '종료' 배지.
>   주간 보드(week_board `isOver`)는 시작 시각 기준으로 더 엄격 — 기존 유지.
> - **하루 예약 한도 (opt-in)**: 신규 표 `gym_class_settings.daily_reservation_limit`
>   (0=무제한 기본·1~10, gym_id PK — gym_point_settings 패턴).
>   설정 API `GET/PATCH /admin/gyms/<gid>/class-settings` (staff + audit,
>   `api/class_settings.py`) · 앱 코치 설정 '예약' 탭.
>   집행 = `api/classes.py _daily_limit_blocked` **한 곳** — 신규 confirmed ·
>   취소 후 재활성 · 대기 신청 세 진입로 전부 + 대기열 승격 재검사(초과 회원은
>   건너뛰고 다음 대기자 승격, 건너뛴 회원은 대기열 잔류).
>   기준일 = 수업 시작일(KST) · 카운트 = confirmed+attended. 초과 시
>   `DAILY_LIMIT_REACHED`(409). 리워드 엔진의 reserved_at 기준 "예약 행동일"
>   정규화와는 다른 축 (그쪽은 보상 1회 제한, 이쪽은 예약 자체 제한).
> - **같은 날 후속 (G29·G30 픽스)**: 재활성 분기를 정원 검사 안쪽으로 이동
>   (만석이면 waitlist 로) + 대기 중 재신청 `ALREADY_WAITLISTED`(409) 차단 +
>   대기 이탈 신설 `DELETE /member/classes/<id>/waitlist` (미승격 sentinel 행만
>   삭제 · SSE `member_waitlist_cancelled`) — 폰 `cancelClassFlow` 가 대기
>   상태면 전용 DELETE 로 분기 ('대기를 취소할까요?'). 종전엔 대기 '취소'
>   버튼이 예약 행 부재로 조용히 무동작이었다.
> - 회귀 게이트: 서버 `tests/test_reservation_policy.py`(11)·`tests/test_class_settings.py`(8),
>   골든 `state_07_class_ended`·`boss_08_settings_reservation`·`state_08_waitlist_cancel_dialog`.

> **D42 (2026-08-25 사용자 지시) — 로그인 창구는 하나. 역할 판정은 서버가 한다.**
>
> 종전엔 진입 화면에서 사람이 '아이디로 로그인(회원)' 과 '코치 로그인' 중 하나를
> 골라 들어갔다. 자기 역할을 사용자가 고르는 구조 자체를 폐기한다.
> - **신규 `POST /api/v1/auth/login {login_id, password}`** (`api/auth_login.py`) —
>   서버가 `gym_managers` → `member_credentials` 순으로 조회해 `kind: coach|member`
>   와 각자의 payload 를 함께 내려준다. 같은 아이디가 양쪽에 있으면 **비밀번호가
>   맞는 쪽**이 이긴다 (스태프 쪽 불일치여도 회원 표를 한 번 더 본다).
>   판정 몸통은 구 창구와 공유 — `admin.authenticate_manager()` ·
>   `member_auth.authenticate_member()` 로 뽑아 두 벌이 되지 않게 했다 (§0-B).
> - **구 창구 2개는 유지**: `/api/v1/admin/login`(관리자 웹) ·
>   `/api/v1/auth/member-login`(이미 배포된 APK). 앱 신버전은 통합 창구만 쓴다.
> - **rate limit 2겹**: IP 20회/5분(체육관 공용 공유기) + **계정 5회/5분**
>   (구 admin/login 수준 유지 — 창구가 넓어진 만큼 계정 축을 새로 조인다).
>   Flask-Limiter 기본 429 는 HTML 이라 앱이 파싱하다 죽어 `app.py` 에
>   JSON 429 핸들러(`RATE_LIMITED`)를 붙였다.
> - **아이디에 대소문자 규칙은 없다** (같은 날 사용자 추가 지시). 스태프는 원래
>   대소문자를 무시했는데 회원만 구분해서, 창구가 합쳐진 뒤 같은 화면인데 규칙이
>   둘로 보였다. 회원 조회 정본 = `models/member_credential.find_credential()`
>   한 곳 (자가가입 중복 검사도 같은 함수 — 'Member' 와 'member' 가 둘 다
>   만들어지지 않게). 세션·응답에는 사용자가 친 문자열이 아니라 **저장된 정본
>   아이디**를 담는다. 비밀번호는 그대로 대소문자를 구분한다.
> - **앱**: `login_screen.dart`(구 `member_login_screen.dart`) 한 화면 —
>   **브랜드 로고 없음**(사용자 지시 — 진입 화면 `signup_screen.dart` 도 같이
>   철수. 로고가 남는 자리는 스플래시·전면 로딩 둘뿐) · 역할 선택 UI 없음 · `kind` 로
>   `/boss/dashboard` ↔ `/shell` 분기. `BossLoginScreen`·`/boss/login` 삭제
>   (README §제거된 기능 대장 15). '아이디 기억하기' 저장 칸도 회원/코치 2칸 →
>   1칸 (구 값은 첫 로드 때 흡수).
> - 회귀 게이트: 서버 `tests/test_unified_login.py`(11) · 앱
>   `test/remembered_login_test.dart`(8) · 골든 `common_08_login`(로고 없는 통합
>   로그인)·`common_05_signup`(코치 줄 사라진 진입)·`state_09_login_remembered`.

> **D43 (2026-08-25 사용자 지시) — 폰 코치는 보는 쪽. 수업 내용은 PC 에서 쓴다.**
>
> "코치로 로그인 하면 예약 현황만 제대로 보이고, 수업 내용 게시하는 건 굳이 폰에
> 넣지 말자 — 그런 상세 내역은 PC 에서 하게 하자." 대전제 3(코치는 PC 가 주,
> 폰이 보조)의 화면 단위 집행이다.
> - 앱에서 삭제: `WodPostScreen`(수업 내용 작성 폼) · 수업 탭 '수업 내용 게시'
>   FAB · WodRow 삭제 아이콘. 게시가 PC 몫이 되면 삭제도 PC 몫이다 — 폰에서
>   지울 수는 있는데 다시 쓸 수는 없는 상태가 더 나쁘다. 죽은 배선
>   (`gym_state`·`gym_repository` 의 postWod·deleteWod)까지 같이 내렸다.
> - **백엔드는 그대로**: `POST/DELETE /api/v1/gyms/<id>/wods` 는 PC 웹이 쓴다.
>   폰만 창구를 닫은 것이지 기능을 없앤 것이 아니다.
> - 폰 코치에 남는 쓰기 동선은 **예약 현황 탭** 쪽뿐이다 — 수업 등록·수정·취소
>   (G24 시트) · 출석/노쇼 체크(D31) · 가입 승인. 이건 '예약 현황' 의 일부라
>   이번 스코프에 넣지 않았다 (더 내릴지는 사용자 결정 대기).
> - 회귀 게이트: 골든 `coach_02_shell_board`(FAB·삭제 아이콘 없는 수업 탭) ·
>   `test/button_lint_test.dart` baseline 래칫 1줄 축소.

> **D44 (2026-08-25 사용자 지시) — 폰 코치는 '오늘 돌리는 것'만.**
>
> D43 직후 사용자가 "코치가 폰에서 되는 것" 전수 목록을 받아 직접 추렸다.
> 남긴 것 = 오늘 예약·출석 수치 · 오늘 수업 목록 · 예약자 명단 · 출석/노쇼 체크 ·
> 가입 신청 승인/거절 · 쪽지 · 알림 on/off · 가입 자동 승인 · 하루 예약 한도 ·
> 수업 내용 읽기. 내린 것 = 위 README §제거된 기능 대장 17 (수업 등록·수정·취소 ·
> 회원 명단/통계/상세 · 코치 노트 · 회원 요청 · 만료 임박 · 체육관 프로필 수정 ·
> 요금제 탭).
> - **대기자 승격은 자동이 정본** (사용자 지시 "7은 자동으로 해라"). 서버가 이미
>   그렇게 동작한다 — `api/classes.py cancel_reservation` 이 취소 즉시
>   `waitlisted_at` 순으로 다음 대기자를 confirmed 로 올리고 `member_promoted_from_waitlist`
>   SSE 를 쏜다 (하루 예약 한도 초과자는 건너뛰고 대기열에 남긴다). 폰에 수동
>   승격 버튼은 원래 없었다 — 명단의 '승격' 은 상태 배지다.
>   ~~⚠ 갭: PC 에서 정원을 늘렸을 때는 승격이 돌지 않는다~~ → **2026-08-25 해소**
>   (서버 `_promote_waitlist()` 한 곳 — 취소·정원 증가 두 진입로 공유, 갭대장 16차).
> - 화면 개명: `CoachDashboardScreen` → `MemberApprovalsScreen` — 가입 승인만
>   남아 이름이 실물과 어긋났다 (§0-B). 진입 버튼 '회원 관리' → '가입 신청'.
> - 코치 설정 4탭 → 3탭 (알림 · 자동 가입 · 예약).
> - 회귀 게이트: 골든 55장 (5장 삭제: boss_04·05·06·07·09) ·
>   `boss_02_dashboard`·`boss_03_class_roster`·`coach_01` 재생성 ·
>   button_lint baseline 2줄 축소 + 1줄 개명.

> **D45 (2026-08-25 사용자 지시) — 폰 코치 설정 화면 폐지 + 자동 가입 승인 기능 폐기.**
>
> D44 목록을 한 번 더 추린 결과. 폰 코치 설정 3탭이 전부 사라진다.
> - 알림 on/off · 하루 예약 한도 → **PC** (관리자 웹에 이미 화면이 있다:
>   `notifications.html` · `settings_reservations.html`).
> - **자동 가입 승인은 기능 자체를 없앤다** — "내가 항상 승인해서 하는걸로".
>   가입 신청은 예외 없이 코치가 직접 승인한다. 앱 탭 + 백엔드 엔드포인트
>   (`/api/v1/admin/gyms/<id>/auto-approve`) + `api/gym.py` 의 분기까지 전부 삭제.
>   `GymProfile.auto_approve_joins` 는 읽는 코드 0 인 휴면 컬럼으로만 남긴다
>   (gym_point_settings 와 같은 처리). 되살리지 말 것.
>   ※ 공식 HYPHEN HQ 체육관 즉시 승인(`OFFICIAL_GYM_NAME` 분기)은 데모 계정용
>   별개 장치라 유지한다 — 코치가 설정으로 켜고 끄는 물건이 아니다.
> - 폰 코치 AppBar 에 남는 것은 로그아웃 하나. 폰에서 코치가 할 수 있는 일은
>   이제 **7가지**다: 오늘 예약·출석 수치 · 오늘 수업 목록 · 예약자 명단 ·
>   출석/노쇼 체크 · 가입 신청 승인/거절 · 쪽지 · 수업 내용 읽기.
> - 회귀 게이트: 골든 54장(boss_08 삭제) · button_lint baseline 1줄 축소 ·
>   서버 211건.

> **D46 (2026-08-25 사용자 지시) — 코치 셸 상단바는 하나.**
>
> "폰에서 예약(현황)일 때 상단화면과 수업일 때 상단화면이 또 다르잖아. 이런 거
> 하지 말고 통일하라고 1개로." 탭마다 화면이 자기 AppBar 를 들고 오면서
> 예약 현황(체육관명+역할+로그아웃) · 수업(제목+COACH 배지+종+새로고침+회원) ·
> 쪽지(제목만) 세 개가 제각각이었다.
> - **상단바 소유권을 셸로 올린다.** `CoachShell` 이 Scaffold+AppBar 를 갖고,
>   세 페이지는 `embedded: true` 로 자기 AppBar 를 그리지 않는다
>   (`BossDashboardScreen`·`BoxWodScreen`·`MessagingScreen` 공통 플래그 —
>   variant 신설이 아니라 state 한 칸, §3).
> - 단일 바 = **체육관명 + '코치' + 로그아웃**. 어느 탭인지는 하단 탭바가
>   알려주므로 제목은 신원 하나로 고정한다. 로그아웃 처리도 셸로 옮겼다.
> - 뺀 것: 종·새로고침·COACH 배지·회원 아이콘. 종은 쪽지 탭이 그 목적지라
>   중복이고, 새로고침은 예약 현황·수업 둘 다 당겨서 새로고침이 있다.
>   회원 아이콘은 예약 현황 탭 '가입 신청' 버튼과 중복.
> - **회원 셸(MainShell)은 건드리지 않았다** — 탭별 제목(홈·수업·내 정보)이
>   이미 같은 골격이고 이번 지시는 코치 화면을 가리킨다. `embedded` 기본값
>   false 라 회원 쪽 렌더는 1픽셀도 안 바뀐다 (골든으로 확인).
> - 회귀 게이트: 골든 `coach_01`·`coach_02`·`coach_03` 재생성 (세 장 상단바 동일).

> **D47 (2026-08-25 사용자 지시) — 앱 UI 골격 SSOT: 인라인·이원화 전부 HKit/테마 한 곳으로.**
>
> "PC 에서 SSOT 로 하나로 묶어서 하듯이 앱에서도 인라인으로 되어 있거나 이원화되어
> 있거나 찾아서 전부 통일." 전수 조사 결과 5종이 흩어져 있었다 — 상단바 31곳 ·
> 다이얼로그 11곳 · 바텀시트 13곳 · 원시 버튼 71곳(22파일) · 입력칸 스타일 4벌.
> - **정본 신설 (`lib/widgets/hkit.dart`)**: `HkAppBar`(push 화면) / `HkAppBar.identity`
>   (셸: 체육관명 + 역할) · `HkDialog.confirm/info/custom` · `HkSheet.show` ·
>   `HkInlineError`. 모양은 `theme.dart` 가 갖는다 — `dialogTheme`·`bottomSheetTheme`
>   신설, `inputDecorationTheme` 에 에러 테두리·errorStyle 보강 (이게 없어서 로그인·
>   가입 화면이 각자 `_inputDeco` 를 들고 있었다).
> - **회원 셸도 상단바 하나** (D46 코치 셸에 이어): 체육관명 + '회원' + 종.
>   홈·수업·내 정보 세 탭이 `embedded: true` 로 들어와 자기 AppBar 를 안 그린다.
>   홈의 새로고침 아이콘은 당겨서 새로고침(RefreshIndicator)으로 이관.
> - **원시 버튼 0건**: ElevatedButton/OutlinedButton/TextButton 직접 사용 71곳 전부
>   `HkButton.primary/secondary/tertiary` 로. `button_lint_test.dart` baseline 이
>   22파일 → **빈 집합** (래칫 종료). 영문 라벨 잔재(Start/Resume/Save/Send/Ask
>   Coach/Share)는 이 김에 한글로.
> - **바텀시트 모서리 r5 로 통일** (DESIGN-SSOT §모서리 — 종전엔 r3/r4 혼재) ·
>   다이얼로그 r4 · 위험 동작(탈퇴·초기화·계정 삭제·세션 종료) 확정 버튼은
>   `danger: true` 채움으로 통일.
> - **새 게이트 `test/ssot_lint_test.dart`**: lib/features/** 에서 `AppBar(`·
>   `AlertDialog(`·`showModalBottomSheet`·`InputDecoration _x(`·`OutlineInputBorder(`·
>   인라인 에러 박스 6패턴 0건 강제 — 다시 인라인이 생기면 CI 에서 죽는다.
> - 남겨 둔 것 (보고): `hyphen_pictogram.dart` 의 hex 32개는 업적 픽토그램 6색 팔레트
>   ×N — 토큰으로 올리면 테마가 부풀어 art asset 으로 취급. `avatar.dart` hex 6개
>   (이니셜 배경 해시 팔레트)·`grain_overlay.dart` 1개 동일.

> **D48 (2026-08-25 사용자 지시) — 구조 이원화 6건 통일: 같은 정보를 두 화면이 다르게 그리지 않는다.**
>
> D47 뒤 "앱 UI 따로 있는 부분 전수조사" → 12건 중 **구조가 갈라진 6건**을 먼저.
> - **하단 탭바 2벌 → `HkTabBar`** (hkit): 회원 셸·코치 셸이 테마·구분선·SafeArea 까지
>   복사해 들고 있었다. 셸은 destinations 만 준다. `ssot_lint_test` 에 `NavigationBar(` 금지 추가.
> - **승인 대기 화면 2벌 → `MembershipStatusView`** (gym/membership_status_view.dart):
>   셸 입구 게이트(`_PendingGate`)와 수업 탭 안 미가입/대기/거절 3종이 같은 상태를 두
>   문구·두 골격으로. none/pending/rejected 한 위젯 — 게이트는 `onRecheck`·`onSignOut` 만 더 준다.
> - **회원 수업 예약 UI 2벌 → 주간보드 하나**: `/classes` 별도 화면(카드형) 삭제
>   (README §제거된 기능 대장 19). 예약·취소 흐름은 `classes/class_flows.dart`.
> - **코치 수업 카드 2벌 → `ClassLine`** (classes/class_line.dart): 예약 현황 탭 카드와
>   주간보드 줄이 같은 수업을 다른 모양으로. 골격 하나 + 우측 슬롯만 시점별 —
>   `ClassLine.coach`(인원 + 명단 진입) / `ClassLine.member`(예약·대기·취소 배지).
>   **코치가 수업 탭에서도 인원+명단을 본다** — 회원용 예약 배지가 코치에게 보이던
>   문제가 같이 닫혔다 (WeekBoard `isOwner`).
> - **공지 행 2벌 → `AnnouncementRow`** (announcements/announcement_row.dart): 홈·수업 탭
>   아코디언이 본문 줄 수만 다른 복사본. `bodyMaxLines` 인자.
> - **에러 뷰 4벌 → HKit**: 코치 대시보드 `_ErrorView`·계약 `_ErrorRetry` → `HkErrorState`,
>   수업 탭 `_LoadErrorBanner`·주간보드 수업 에러 줄 → `HkInlineError(onRetry:)`.
>   `HkErrorState` 안의 원시 OutlinedButton 도 HkButton 으로.
> - 곁가지: `core/time_format.dart` 신설 (hhmm·hhmmIso·ymd·mdDot) — 이번에 손댄
>   파일의 날짜 헬퍼만 이관, 나머지 7개 파일은 "작은 것" 단계에서.
> - 회귀 게이트: 골든 54장 재생성 (member_07·08·state_07·08 은 주간보드로 재촬영) ·
>   앱 194건 · ssot_lint 7패턴.

> **D49 (2026-08-25 사용자 지시) — 부품 인라인 6건 통일: 정본이 있는데 안 쓰던 곳을 전부 갈아끼움.**
>
> D48 뒤 "작은 것 6건" — 판단은 없고 양만 많은 갈아끼우기.
> - **섹션 라벨 77곳 → `HkSectionLabel`** (`Text('X', style: sectionLabel)` 직접 지정 26파일).
>   `.copyWith` 변형 3곳만 남김 (색·굵기를 바꾸는 자리).
> - **스피너 13곳 → `HkLoading`** — 크기 18/20/22·색 muted/primary/accent 가 섞여 있었다.
>   22×22 stroke 2 muted 한 규격.
> - **빈 상태 8곳 → `HkEmptyState`** (업적·계약·가입 신청·수업 기록·기록 상세·그룹 ×2·노트).
>   폼 안 부연 문구 4곳(주간보드 "등록된 수업 없음"·내 정보 "체육관 없음"·노트 작성 "동작 없음")은
>   화면 상태가 아니라 줄 안 메모라 그대로.
> - **통계 타일 → `HkStatTile`**: 코치 예약 현황 `_CounterCard` (h1 숫자·자체 카드) →
>   명단 시트·홈 마일스톤과 같은 타일. `_ProgressStat`(홈)은 이미 HkListRow 위의 진행바,
>   `_StatsHeader`(업적)는 히어로 숫자 — 타일이 아니라 그대로.
> - **날짜·시각 함수 7파일 → `core/time_format.dart`** (`ymd`·`hhmm`·`hhmmIso`·`mdDot`·`mdHm`·`mmss`).
>   `history_detail._formatDate`(ISO→`yyyy.MM.dd HH:mm`) 1개만 잔존 — 다음 표기 추가 때 흡수.
> - **카드 크롬 → `HkCard`**: 정식 크롬(surface + border + r3) 38곳 중 Container 인자가
>   margin/padding/child 뿐인 2곳만 자동 치환. 나머지 36곳은 `clipBehavior`·`width`·
>   `alignment`·색 테두리 등이 붙어 있어 HkCard 시그니처 밖 — **보고만** (HkCard 에
>   `clipBehavior`/`borderColor` 를 열어 주는 결정이 먼저).
> - 게이트 추가 (`ssot_lint_test`): `CircularProgressIndicator(` · `style: sectionLabel[,)]` ·
>   `String _fmt/_hhmm/_ymd/_dateShort…(` 3패턴 → 총 10패턴.
> - 회귀: 골든 54장 재생성 · 앱 194건.

> **D50 (2026-08-25 사용자 지시 "1,2,3번 다") — 카드 마저 · 코치 다중 기기 · 코치 수업 탭 읽기 전용.**
>
> - **카드 27곳 → `HkCard`**: 정본에 `radius`(r2 카드)·`borderColor`(예약됨=초록 같은
>   상태 테두리)·`borderWidth`·`clipBehavior`·`width` 네 칸을 열어 D49 에서 시그니처 밖이던
>   것을 흡수. 남은 10곳은 카드가 아니다 — 왼쪽 색띠(업적·칭호), 원형(코치 사진),
>   말풍선(채팅), 요일 타일(주간보드), 내 기록 강조(배경 색 조건), 결과 시트 헤더.
> - **코치 다중 기기 페어링 (서버)**: `GymManager.device_hash` 1개가 마지막 로그인 기기로
>   덮어써져 에뮬레이터 로그인 뒤 갤S22 수업 탭이 '미가입'으로 떨어졌다 (실기 발견).
>   신규 표 `gym_manager_devices(gym_id, login_id, device_hash, paired_at, last_seen_at)`
>   — 로그인마다 upsert. 판정·SSE 구독·기기 폴백은 `roles.staff_rows_for_device()`
>   **한 곳**(표 ∪ 구 컬럼). 구 컬럼은 '마지막 로그인 기기' 로 계속 갱신 — PC 쪽지함
>   신원(`_staff_device_hash`) 등 구 경로 호환. 회귀: `tests/test_manager_devices.py`(4).
> - **코치 수업 탭 읽기 전용**: 회원용 '완료 표시'(내 기록) 배지를 코치에게 숨김
>   ('메시지' 는 이미 숨김). 코치가 이 탭에서 하는 건 읽기 + 인원·명단뿐 (D43·D44 정합).

> **D51 (2026-08-25 사용자 결정 "니 말대로 1" + 쪽지 단순화 지시) — 코치 앱 2탭 · 정본은 부품이지 화면이 아니다.**
>
> 질문 "코치가 앱으로 로그인했을 때 수업 화면이 회원과 같을 필요가 있나" → 없다.
> 회원 주간보드를 코치에게 얹고 `isOwner` 분기를 하나씩 깎던 것은 한 위젯 안의 이원화였다.
> - **코치 셸 = 2탭**: 예약 현황(오늘 수치 · 가입 신청 · **주간** 수업/예약) · 쪽지.
>   '수업' 탭 폐지 (README 대장 20). 주간 수업/예약 = `boss/coach_week_classes.dart` —
>   부품은 회원 쪽과 같은 규격(주간 헤더·ClassLine.coach·명단 시트·HkCard), 화면 조립은
>   코치용. 데이터는 코치 세션 API(`GET /admin/gyms/<id>/classes?from&to`,
>   `BossApiClient.getList` 신설) — 회원 API 기기 폴백에 기대지 않는다.
> - **회원 화면에서 코치 분기 전부 제거**: week_board `isOwner`·명단 진입, box_wod 코치
>   배지·가입 신청 아이콘, wod_row 완료 표시/메시지 가드, wod_detail 배지·요청 가드,
>   mypage 가입 신청 버튼·'코치' 라벨. 회원 셸은 순수 회원 화면 (isOwner 잔존 = 쪽지·
>   wod_session 의 권한 가드 2곳뿐 — 화면 분기 아님).
> - **쪽지 단순화 (사용자 지시)**: '그룹' 버튼·그룹 관리 화면·그룹 모델·리포지토리 그룹
>   메서드 삭제. '새 쪽지' = 내 회원 목록 → 받을 사람 탭 → 그 회원과의 대화 화면
>   (`ChatThreadScreen`)에서 아래 입력칸에 쓰고 전송 (`inbox/new_note_screen.dart`).
>   대상 3종·종류 2종·제목·근거·기한·동작 표를 전부 걷었다 (대장 21). **API 는 그대로** —
>   `POST /gym/<id>/notes` individual/note 라 PC 쪽지함(`admin._staff_device_hash` 공용
>   owner 해시 규칙)이 종전처럼 받는다. 그룹·숙제 서버 API 는 PC 용으로 존치.
> - 회귀: 골든 `coach_01`(주간) 재생성 · `coach_02` 삭제 · `coach_04_new_note_members` 신규 ·
>   `coach_03` 재생성(그룹 버튼 없음).

> **프로드 실검증 (2026-08-30 16:35~16:45 · 사용자 "1할때 2도 동시체크")** — 프로드 관리자 웹(admin/1234 = 체육관 HYPHEN, gym 2)과
> 에뮬레이터 프로드 APK 로 한 바퀴: 임시 회원 `d98test` 가입 신청(API) → PC 승인·1일 기간제 발급 → PC 수업 등록(AWAKE · A 세션, 16:58) →
> **게시 모달** [수업 종류 AWAKE]×[세션 A] 게시 = 세션 자동 게시 글에 upsert(그날 글 1건, 제목 'AWAKE · A 세션') → **시간표 규칙**
> AWAKE 05:00 C 세션 저장 → 'AWAKE · C 세션' 수업 20개 실체화 확인 → 규칙 삭제로 20개 정리 → 에뮬 회원 예약 → 취소 다이얼로그에
> **서버 판정 문구**('늦은 취소로 기록됩니다…', D96) → 취소 → 쪽지함 활동 칸에 **'취소 · 노쇼 안내'**(D97) 도착. 검증 데이터(글·수업·회원)
> 전부 삭제. 잡은 것: 기간제 회원에게 '이번은 면제' 라고 쓰던 문구 → '기간제 회원권이라 차감은 없습니다' (`policy_outcome(on_pass)`).

> **D118 (2026-09-05 집행) — 밀림 후보 잔여 4건 + 버튼 폭 튐 (앱).
> D117 이 "정직하게 남긴다" 고 적어 둔 4를 마저 집행했고, 그 과정에서 드러난
> 부품 결함 하나를 더 고쳤다. §4 밀림 후보 10건이 이로써 전부 닫혔다.**
>
> - **순서를 또 지켰다.** 네 건 모두 게이트를 먼저 얹어 **실패를 눈으로 확인하고**
>   고쳐서 통과시켰다. 잰 값 — 채팅 입력바 **65 → 129 (+64px)** · 수업 상세 시트
>   **23px** · 홈 도전 섹션 로딩·0건·실패 **0px ↔ 도착 289px**(홈 스크롤 총길이
>   145 → 434) · 계약 목록·상세 첫 줄 **68 ↔ 405 = 337px**(본문 자리 높이 728,
>   기대 132) · 버튼 폭 **57.6 → 360**.
> - **채팅 전송 아이콘 — 원인이 세로가 아니라 가로였다.** "입력칸 안이라 제약을
>   받아 안 밀릴 것" 이라던 짐작이 틀렸다. 아이콘 자리는 최소 48×48 이라 세로는
>   멀쩡했는데, 스피너를 그리던 `HkLoading()` 이 `Center` 라 **남는 가로폭을 전부
>   먹어**(48 → 336) 글자 칸이 0 으로 눌렸고 한 줄이 네 줄로 접히며 위 대화 목록이
>   64px 깎였다. 이제 버튼은 그대로 있고 **그 안의 아이콘만** 스피너로 바뀐다.
> - **같은 원인이 버튼에도 살아 있었다 — 같이 고쳤다.** 전체폭이 아닌 버튼은 글자가
>   폭을 정하는데 그 글자를 스피너로 갈아 끼우면 폭의 근거가 사라져 남는 자리를 다
>   먹는다(실측 57.6 → 360, tertiary 49.6 → 360, 나란한 '취소' 가 1.8px 밀림).
>   글자를 **투명하게 남겨 폭을 붙들고**(`Visibility(maintainSize)`) 그 위에 스피너만
>   얹는다. 게이트 = `test/button_busy_width_test.dart`(3종 × 폭·높이 + 두 버튼 나란히).
>   부품 규격도 하나 늘었다 — **`HkLoading.icon()`**(원 크기 그대로, 옆 칸을 안 민다).
> - **수업 상세 시트 — 바텀시트에는 "아래로 내리기" 가 안 통한다.** 시트는 아래에
>   붙어 **위로 자란다.** 실패 문구를 버튼 아래로 내려도 시트 전체가 늘어 그 위가
>   전부 위로 튄다(보내기 버튼만 716 에 남고 제목·안내·두 입력칸이 23px 위로).
>   D117 #3 의 정답이 여기선 오답이다 — 높이가 고정된 자리 안에서 **글자만** 바꾼다
>   (`HkReservedSlot(slotRequestNoticeH 38)`). 모달은 `pumpWidget` 한 번으로 못 만들어
>   상태 절차를 `test/golden/wod_request_sheet.dart` 로 뽑았다(로그인의 `login_states.dart` 결).
> - **홈 도전 섹션** — "홈 마지막이라 위는 안 밀린다" 는 안전의 근거가 못 됐다:
>   스크롤 위치·막대 길이가 튀고, 홈 아래에 무엇이 붙는 날 그대로 밀린다. 그리고
>   **실패를 0px 로 숨긴 것은 거짓말**이었다 — 못 읽은 것과 없는 것이 화면에서
>   똑같이 보였다. 이제 라벨·카드는 **항상** 서고 카드 안만 갈아 끼운다
>   (로딩 = `HkLoading.slot` · 0건 = '등록된 도전 없음' · 실패 = `HkErrorState`).
> - **0건에 빈 카드를 세우는 결정** — 홈이 이미 공지에서 같은 답을 쓰고 있고
>   ('등록된 공지 없음' 상시 노출, v3.43), 바닥 132 는 D115 가 정한 공통값이며
>   마침 도전 한 행의 실측(128.5)과 거의 같다(규칙 1건 체육관은 사실상 안 밀림).
>   빈 자리는 회색 띠가 아니라 카드 안 가운데 문구다.
> - **계약 목록·상세** — 본문 **전체**를 상태로 갈아 끼우던 것을 그만뒀다. 상태
>   위젯은 남는 높이를 다 먹고 내용을 세로 가운데에 놓는데 목록은 위에서부터
>   그려져 337px 이 뛰었다. 뼈대(상단바 + 본문 자리)는 고정하고
>   `HkReservedSlot(stateSlotH)` **안**에서만 바꾼다. 목록의 로딩은 스피너 대신
>   **카드와 같은 높이(78)의 스켈레톤** — 도착하는 순간 첫 줄이 제자리에서 내용이
>   된다(`Align(topCenter)` 로 늘어남 방지, 게이트가 두 높이를 대조한다).
> - **검사 수를 세는 기준을 못 박는다 (§0-B).** D117 '25', 두 갈래가 각각 '26'·'31'
>   을 적었는데 셋 다 `grep` 이었고 **for 문 안의 `testWidgets` 를 한 번으로 세어**
>   어긋났다. 앞으로는 **러너가 센 값**만 쓴다 — 안정성 12파일 **35**,
>   자리 높이·버튼 폭까지 넣으면 14파일 **42**.
> - 전체 **273 통과**(256 + 밀림 4건 13 + 버튼 폭 4) · analyze 0 · 골든 **89장 유지, 1장 재생성**
>   (`member_13_achievement_detail` — 홈이 길어져 시트 **뒤 배경**의
>   `scrollUntilVisible` 도달 위치가 달라졌다. 시트 자체는 그대로).
> - **남은 밀림 후보 0.** 다만 완전한 0px 는 아니다 — 계약 로딩 스켈레톤 1행은
>   2건 도착 시 132 → 164 로 32px 자라고(2행으로 그리면 빈·에러 132 와 바닥이
>   갈라져 "같은 바닥" 을 택했다), 예약된 자리 **안**에서는 세로 정렬 차이로
>   첫 글자가 30~50px 움직인다. 자리 밖은 안 밀린다. 목록 = `docs/UI-INDEX.md §12`.

> **D129 (2026-09-07 집행) — 홈 업적 예약 자리 3줄 → 2줄 (앱).**
>
> 업적이 0인 회원에게는 이 자리가 통째로 비어 홈에서 가장 큰 공백이었다 (에뮬 3036 실측).
> `AchievementSection.kRows` 3 → **2**. 밀림 방지 규칙(v3.34 — 예약 자리와 표시 줄 수를
> 같은 값으로 묶는다)은 그대로 두고 값만 내렸다. **대가**: 업적이 많은 회원의 홈은 2줄만
> 보이고 나머지는 "그 외 N개" 와 헤더 '전체 보기' 가 받는다.
>
> 내리자마자 **이원화가 하나 드러났다** — 로딩 스켈레톤 줄 수가 `kRows` 가 아니라 리터럴 3
> 이라, 예약 높이(2줄)와 스켈레톤(3줄)이 갈려 `stability_home_test` 가 잡았다.
> `List.generate(kRows, …)` 로 파생시켰다. 숫자를 두 곳에 적으면 언젠가 갈린다 (대전제 6-b).

> **D128 (2026-09-07 집행) — 가시성 점검 §4·§5 잔손질 3건 + 실측으로 걷어낸 2건 (앱).**
>
> - **섹션 라벨 대비**: `sectionLabel` 색 `muted`(#71717A) → `fgSecondary`(#52525B).
>   흰 바탕 4.83 은 통과했지만 **회색 상자(#F5F5F5) 위 4.43** 으로 기준(4.5) 미달이었다 —
>   수업 탭 펼침 상자의 파트 라벨이 그 자리다. 한 토큰이라 전 화면이 같이 올라간다.
> - **내 정보 이름 중복**: 로그아웃 줄이 `auth.displayName` 을 caption 으로 한 번 더 찍고 있었다
>   (위 카드에 h3 이름이 이미 있다). 지우고 `Spacer` 로 자리만 남겼다.
> - **로그인 법적 고지 위계**: '이용약관 · 개인정보처리방침' 이 본문 굵기라 정작 눌러야 할
>   '회원 가입 신청'(빨강)보다 무거웠다. `HkButton.small`(HKit 신설 — tertiary 잔글씨,
>   글자만 caption 으로 내리고 **터치 48 은 유지**)로 내렸다.
> - **실측으로 걷어낸 2건** — 점검 §4 가 지목한 둘은 에뮬(3036)에서 재확인하니 defect 가 아니었다.
>   ① 홈 "업적~마일스톤 사이 90dp 빈 예약 자리" 는 없다. 실제로 보이는 것은 업적 **빈 상태 카드**의
>   내부 여백과 홈 맨 아래 도전 빈 슬롯(132)인데, 후자는 D118 이 **일부러 세워 둔 자리**다
>   (규칙이 도착할 때 홈이 3배로 늘어나던 밀림을 막는다). 지우면 그 결함이 돌아온다.
>   ② 쪽지함 "빈 공지 카드 170dp" 도 아니다 — 카드에 고정 높이가 없어 공지가 없으면 한 줄로 짧고,
>   실측 화면은 공지가 있어 제 크기였다. **둘 다 변경 없음.**
> - 골든 64장 재생성(섹션 라벨 색이 거의 모든 화면에 있다), 장수 91 불변.

> **D127 (2026-09-07 집행) — 행동 배지 3단: 채움·외곽선·민글자 (앱).
> 가시성 점검 `docs/audit-visibility-2026-09-06.html` §2, 목업 `docs/mockup-badge-tiers.html` 승인 후.**
>
> - **증상**(점검 §2 "누르는 글자가 제일 작다"): 배지 글자가 `micro` 13 w700 이라 같은 줄 제목(17)·
>   캡션(13)보다 작거나 같았다. 무게는 채움/외곽선 2단뿐이라 **못 누르는 것이 버튼처럼 보였다** —
>   '수업 시작 전' · '예약 필요' 가 '메시지' · '자세히' 와 같은 외곽선이었다. 한글에 자간 +0.8 을
>   주고 있어 글로벌 §2-B-자간(한글 자간은 항상 음수)에도 어긋났다.
> - **점검 보고서 정정**: §2 는 "주 행동 '완료 표시' 가 외곽선" 이라고 적었으나 **사실이 아니다** —
>   `wod_row.dart` 의 '완료 표시'·'기록 N' 은 2026-08-12(91e8998)부터 `selected: true` 라 이미
>   채움이었다. 실제로 외곽선이던 주 행동은 `class_line.dart` 의 '예약'·'대기' 였다. 목업을 만들며
>   코드로 확인해 범위를 줄였다 (그림 없이 집행했으면 없는 문제를 고칠 뻔했다).
> - **집행**: `HkBadgeTier { action, secondary, reason }` 신설 — 채움(주 행동) · 외곽선(보조·상태,
>   기본) · 민글자(이유). 글자는 `micro` 13 w700 자간 +0.8 → **`body` 15 w600 자간 음수**,
>   안쪽 여백 `sp2×3` → `sp3×sp1`. 채움 판정 = `selected || tier == action` — `selected` 는
>   **켜짐/꺼짐 토글**(출석·노쇼)의 뜻으로 남기고, 주 행동은 `tier` 가 말한다 (뜻이 다르므로 이름도 다르다).
> - **호출처 6곳**: `class_line.dart` 예약·대기 = action / 취소됨·회원권 필요·마감 = reason ·
>   `wod_row.dart` 완료 표시 = action(구 `selected: true`) / 수업 시작 전·예약 필요 = reason.
>   나머지 배지는 손대지 않았다 — 기본값이 secondary 라 글자만 커진다.
> - **곁가지 2건**: 업적 목록 행 `kRowH` 64 → 72 (배지가 커지며 제목 줄이 6px 넘쳤다. 배지는 1종이
>   원칙이라 행이 받는다) · `touch_target_test` 의 표시 전용 배지 검사 축을 **폭 → 높이**로
>   ('마감' 두 글자도 15sp 면 자연 폭이 48 을 넘는다. "조작 배지만 48 상자" 라는 뜻은 그대로).
> - **골든 40장 재생성, 장수 91 불변.** 탭 동작·서버 판정·배지 색·모서리(r1)·대문자 변환은 그대로.

> **D125 (2026-09-06 집행) — 완료 시트 가시성: 숫자 칸·라벨·위계·고정 저장 바 (앱).
> 가시성 점검 `docs/audit-visibility-2026-09-06.html` §1, 사용자 "1"(완료 시트 먼저) → "ㄱ".**
>
> - **증상**(사용자 "숫자 1만 입력하면 되는데 칸이 광활 · 배색이 흐림 · 누르는 글자가 작아짐"): 완료 시트의
>   모든 칸이 `Expanded` TextField(156~328dp)에 15sp 왼쪽 정렬이라 1~3자리 값이 구석에 묻혔고, 빈 칸의
>   이름은 placeholder 색(#A1A1AA · 2.56:1)뿐이었다. 세트 5개 = 카드 5장 565dp 라 저장 버튼이 두 화면
>   아래로 밀렸다. 파트 머리(sectionLabel 12 회색)가 안의 항목(15 w600 검정)보다 작았다.
> - **집행**: `HkNumberField`(HKit 신설 — 폭 고정·오른쪽 정렬·단위 밖·라벨 위, `''` 라벨은 빈 줄 예약) ·
>   세트는 동작 이름 한 줄 + `1세트 [100] kg × [5] 회`(48dp, 카드·테두리 없음) · 파트 머리 `HkSectionLabel(strong:)` ·
>   시트 = 머리(고정)·본문(스크롤)·저장 바(고정) 세 층. 라벨·힌트·축·키·payload 는 D122/D124 그대로 —
>   **보이는 것만 바꿨다.** 수업 내용 본문은 접지 않았다(D120·v3.45) — 색만 fgSecondary.
> - **검사·골든이 시트를 올리는 법이 바뀜**: `SingleChildScrollView` 로 감싸지 않고 `Scaffold(body:)` 에
>   직접 — 고정 저장 바는 높이가 유한한 자리에서만 성립하고 실물(HkSheet)과 같은 구조여야 한다.
> - 폭 표 = `wod_result_sheet.dart _W` 한 곳 (분·초 88 · 라운드 96 · 완료한 분 112 · +회/남긴 렙스 128 ·
>   무게 88 · 세트 횟수 72 · 자유 목표 112 · 세트 라벨 52). 360dp 기준 가장 넓은 줄 = 세트 줄 ≈ 280dp.
> - 게이트 = `test/number_field_test.dart`(12 — 폭·높이 48·단위 위치·빈 라벨 y 예약·힌트·자판·정렬) ·
>   `result_axes*_test.dart`(라벨은 `HkNumberField.label` 로 읽음) · `stability_result_sheet_test.dart`(저장 바 y).
> - 골든 **5장 재생성, 장수 불변(91)** — member_06 · member_06b · state_28 · state_29 · state_34. state_28 검사는
>   단언도 고침(코치 무게가 값이자 힌트라 `find.text` 가 둘을 셈 → 칸 값을 직접 읽는다).
> - **잔손질(2026-09-07, 리뷰 차단 0 · 3건)**: 검사 4곳(`stability_result_sheet_test` 2 · `result_axes_test` 2)이
>   아직 `SingleChildScrollView` 로 감싸던 것을 `Scaffold(body:)` 직접으로 — 실물과 같은 구조를 잰다. 코치 무게가
>   없는 동작의 무게 힌트 `'0'` → **'선택'** 복구(D125 전 값). 힌트 글자가 바뀌어 member_06b 1장 재생성, 장수 불변.
> - 남은 것(점검 §2·§4·§5 — 별건): 행동 배지 3단(HkBadge 15sp·채움/외곽선/글자) · 홈 공백 · 쪽지함 빈 카드 ·
>   로그인 약관 굵기 · 내 정보 이름 중복 · 회색 상자 위 12sp 라벨 색.

> **D124 (2026-09-06 집행) — 6-b 잔여 사본 3곳 제거: 종류 라벨·힌트 문장·편집기 축을 전부 서버가 준다 (서버·앱·PC).
> 사용자 "전부 다 하자, 깨끗하게 정리".**
>
> - **앱 `wod_type_label.dart` 삭제** — `for_time` → 'FOR TIME' 조립 8곳이 모델 `GymWodPost.wodTypeLabel`
>   (서버 `wod_type_label`, 정본 `program_lines.WOD_TYPE_LABELS`) 을 그대로 그린다. 라벨을 안 실은 옛 응답은
>   값을 그대로 보인다 — 글자를 지어내지 않는다. `LockedWodBanner` 도 라벨을 받는다(`typeLabel`).
> - **앱 힌트 문구** `'$n 미만'`·`'$n분 중'` 조립 삭제 — 파트 응답의 `score_hints`(`result_axes.part_score_hints`,
>   `{'extra_reps': '21 미만'}`·`{'rounds': '10분 중'}`) 문장을 그대로. 숫자가 없으면 키가 없고 화면은 빈 값 '0'.
> - **PC `ROUNDS_NOT_PRESCRIBED`·`SET_BASED_TYPES` 삭제** — `program-meta` 의 `wod_types[]` 가 종류마다
>   `rounds_prescribed`·`set_based`(`result_axes.editor_axes`) 를 싣고 편집기는 읽기만 한다. 메타 전이면 둘 다 false.
> - 게이트: 서버 `test_ssot_result_axes_lint.py`(정본 마커 2·재정의 금지·힌트 문장 리터럴) ·
>   `test_result_axes_d122.py` 3·3b·3c(`score_hints`) · `test_program_d88.py` j(메타 축) / 앱 `test/ssot_lint_test.dart`
>   (`wodTypeLabel(`·`replaceAll('_',' ').toUpperCase()`·`'$n 미만'` 0건) · `result_axes2_test.dart` / PC `design/lint.py §7.10`
>   (판정 원천 = 메타 `rounds_prescribed`/`set_based`, 리터럴 목록은 있으면 위반).
> - 골든 픽셀 변화 0 (서버 라벨 = 종전 조립 결과). 가짜 서버(`fakes.dart`)가 `wod_type_label`·`score_hints` 를 싣는다.

> **D123 (2026-09-06 집행) — 시각·날짜는 체육관 시각(Asia/Seoul) 하나로. 기기 시간대 표시 폐기 (앱).
> 사용자 지시 "업계 표준대로" (Wodify·SugarWOD·BTWB — 수업 시각·날짜는 체육관 시간대).**
>
> - **증상**: UTC 에뮬레이터에서 9/8 06:30 수업이 "9/7 21:30" 으로 보이고 9/7 묶음에 들어가
>   **9/7 글**과 짝이 됐다. 그래서 예약한 9/8 수업 아래 9/7 글의 '예약 필요' 가 뜨고, 같은 날처럼
>   보이는 9/7 수업들의 '예약' 이 안 사라지는 것으로 보였다 — 둘 다 **잣대가 둘**인 결과였다
>   (글 = 서버 한국 날짜 `post_date`, 수업 = 기기 날짜 `toLocal()`).
> - **결정**: 대전제 4 의 "폰·PC 는 표시만 기기 시간대" 를 **폐기**. 표시·날짜 묶음·조회 범위·
>   '오늘' 전부 체육관 시각 하나. 회원 폰이 어디 있든 06:30 수업은 06:30 이다.
> - 정본 = `lib/core/time_format.dart` 의 `.gym()`(TZDateTime — 순간 보존, 비교 안전)·`.gymDay()`
>   (체육관 자정). `lib/**` 의 `.toLocal()` 51곳(21파일) → `.gym()`, 기기 자정 생성 4곳 → `.gymDay()`.
>   두 번째 것을 놓쳤을 때 **조회 범위가 9시간 밀려 06:30 수업이 목록에서 빠졌다** — 실측 후 잡음.
> - 게이트 = `test/ssot_lint_test.dart` — `lib/**` 에 `.toLocal()` 0건 · `DateTime(x.year,x.month,x.day)`
>   0건 (생년월일 검증기만 예외). 심어서 잡히는 것 확인.
> - 실측: UTC 에뮬에서 오늘이 **일 6**(한국)으로, 9/7 이 06:30·10:00·18:30·19:30·20:30 으로,
>   9/8 06:30 AWAKE 가 제 날에 예약됨으로. 같은 날 다른 줄의 '예약' 은 하루 한도대로 사라진다.
> - 골든 변화 0 (검사 PC 가 한국 시각). 329 통과 · analyze 0.

> **D122 (2026-09-06 집행) — 축을 서버가 내려주고, 강도가 다르면 비교하지 않는다 (서버·앱·PC).
> 계약 = `docs/CONTRACT-result-axes-2.md`. 사용자 "전부 집행".**
>
> - **근력 무게 배선 복구**(서버 §1) — 세트 줄에서 최고 무게·reps·동작명을 결과 행에 파생.
>   `existing.weight_kg` 무조건 대입 제거. v3.45 이후 죽어 있던 넷(히스토리 헤드라인·strength PR·
>   1RM 보드·동작 묶기) 복구. 앱 변경 0.
> - **강도 비교**(§2) — `load_fingerprint`·`capped` 를 비교 후보 열쇠에. 43kg→20kg 은 PR 이 아니라
>   `'20kg 로는 첫 기록'`. 무게 축(strength)에는 지문을 걸지 않는다 — 무게가 곧 점수. 컬럼 0 증가.
> - **축을 서버가 내려준다**(§3) — 파트마다 `score_keys`·`score_labels`·`score_target`·
>   `show_movement_reps`·`set_based`. 앱의 `_scoredTypes`·`_noRepsTypes` 사본 삭제 → 시트에 종류
>   리터럴 0건. **종류 추가에 앱 재배포 불필요.**
> - **EMOM**(§4) = ROUNDS 축 '완료한 분'. 맨몸 EMOM 파트가 화면에서 사라지던 것 해소.
> - **AMRAP**(§5) — `+ 회`(구 '추가 회' 는 뜻이 뒤집혀 읽혔다), 힌트 `N 미만`, 고정 높이 안내 줄,
>   무게 없는 동작은 서버 `lines` 읽기 전용. `round_reps` 스냅샷(컬럼 1개, **명시 commit**)·
>   `extra_reps >= round_reps` 400. PC 편집기는 AMRAP 라운드 칸 잠금(옛 값은 보존, 코치가 지움).
> - **STRENGTH**(§6) `set_reps` 프리필, `set_count = len(set_reps)`. 세트 줄 힌트가 전부
>   `5-5-5-5-5` 였던 것도 해소.
> - **히스토리**(§7) `parts[]`(서버 완성 문장 `line` + `score`)·`capped`→'캡' 배지·
>   `headline_part_label`, 둘째 줄 2줄. 글 응답에 `wod_type_label` (앱·PC 라벨 조립 제거 근거).
> - **종류 5개 동결**(§8) 게이트. 게이트 총 — 서버 34 · 앱 29+정적 3 · PC 2. 전부 붙이기 전 실패 확인.
> - 서버 **771 통과** · 앱 **329 통과** · 골든 91장(+2: state_34 EMOM 시트 · hist_07 캡 상세, 8장 재생성).
> - **실측(에뮬 · 운영 서버)**: 어제 BUILD 5파트 기록을 다시 열자 세트별 횟수 프리필, `+ 회 12`,
>   안내 줄, KB Swing·Toes-to-Bar·Pull-up 읽기 전용 줄, **D 파트 EMOM '완료한 분' 칸**, 버튼 라벨 `기록 8R+12`.
> - **남긴 것**: 앱 `wod_type_label.dart`(라벨 조립, 8곳)는 서버 `wod_type_label` 로 옮길 후보 —
>   서버는 실었고 앱 교체는 별건. 앱 힌트 문구(`N 미만`·`N분 중`)는 아직 앱에 있다(`score_hints` 후보).

> **D121 (2026-09-05 집행) — 파트 종류가 기록 칸을 정한다 (서버·앱·계약).
> 사용자 지적: "백스쿼트 5×5 면 첫 세트에 몇 kg 로 몇 회를 적고 싶지 않겠나. FOR TIME 은
> 동작마다 무게가 필요하면 넣고(토투바는 필요 없음), 그보다 몇 분 만에 끝났나가 중요할 거고."**
>
> - **맞는 지적이었다.** 시트는 파트 종류와 무관하게 `[한 횟수][무게]` 두 칸만 줬다 —
>   strength 는 세트별 무게를 못 적고, for_time 은 **완주 시간 칸이 아예 없었고**,
>   맨몸 동작에도 무게 칸이 섰다. v3.45(09-02)가 점수 UI 를 걷어낸 이틀 뒤 D109 파트가
>   들어오며 **파트도 종류도 못 보는** 상태가 됐다. 서버 컬럼(`time_sec`·`rounds`·
>   `extra_reps`)과 `movement_library.has_load` 는 내내 살아 있었다 — 없앤 건 UI 뿐.
> - **계약을 먼저 못박고 서버·앱을 병렬로 만들었다** (`docs/CONTRACT-result-axes.md`).
>   런타임 정본 = `services/result_axes.py` 하나, 앱은 `wod_type`·`has_load`·`set_count` 를
>   읽어 그리기만 한다 (6-b). 이미 나간 APK 의 옛 제출 형식도 계속 받는다.
> - 축: for_time → 완주 시간(+캡 종료·남긴 렙스) · amrap → 라운드+추가 회 ·
>   strength → 세트별 `[무게][횟수]` · emom → 점수 없음 · custom → 동작별 횟수.
>   **무게 칸은 `has_load` 인 동작에만.** 코치 PC 는 이미 그 규칙을 지키고 있었다 —
>   **서버도 알고 PC 도 쓰는데 폰만 무시하고 있었다.**
> - 저장: 새 표 `gym_wod_result_parts` + `result_movements` 에 `part_index`·`set_index`.
>   기존 데이터 보존. 게이트 = 서버 축 표 중복 감지(9)·라운드트립(17) · 앱 축 렌더(13)·
>   밀림(3). 서버 **737 통과** · 앱 **295 통과** · 골든 89장(4장 재생성).
> - **실사용 확인 (에뮬레이터·운영 서버)**: 코치 웹에서 FOR TIME 수업(Thruster 21-15-9
>   42.5kg + Toes-to-Bar 21-15-9, 캡 12분)을 만들고 회원으로 예약 → 시작 후 완료 →
>   시트에 **완주 시간(분·초)·캡 종료·남긴 렙스** 가 서고 **Thruster 만 무게 칸**,
>   **Toes-to-Bar 는 줄 자체가 없다.** 9분 42초로 저장 → 히스토리 목록 `9:42`,
>   상세 헤드라인 `9:42` + 동작별 `Thruster · 42.5kg`.

> **D121-사고 (2026-09-05) — 배포 직후 프로덕션 500. 마이그레이션이 커밋되지 않았다.**
>
> - `/api/v1/gyms/{id}/wods` 가 `no such column: gym_wod_result_movements.part_index`.
>   코드가 아니라 **마이그레이션이 살아남지 못한 것**이었다: `migrate_db` 는
>   `engine.connect()`(비커밋) 안에서 도는데, pysqlite 는 DDL 을 autocommit 하지만
>   **앞선 마이그레이션의 DML 이 트랜잭션을 열어 두면** 그 뒤 DDL 까지 커넥션이 닫힐 때
>   롤백된다. 바로 위 `_migrate_parts_d109` 가 매 부팅 UPDATE 를 돈다.
> - 고침 = 이 파일의 기존 관례대로 **명시 커밋**. 재배포 후 정상 확인.
> - **곁다리로 잡은 잠복 결함**: `class_template` 모델 import 누락 — 빈 볼륨 첫 부팅이면
>   `class_sessions.template_id` FK 를 못 풀어 `create_all` 이 죽는다 (기존 DB 는 표가
>   있어 안 드러났다).
> - 게이트 `tests/test_migrate_commits.py` 3건 — 사고 성질 재현 · D109 뒤 마이그레이션의
>   명시 커밋 강제 · 옛 스키마에서 D121 컬럼 생존.
> - **남은 것(별건)**: D109 앞 33개도 같은 형태다. 그쪽 DML 은 조건부라 평소엔 트랜잭션이
>   안 열려 몇 달간 드러나지 않았다. 블록 전체를 커밋되는 트랜잭션으로 바꾸는 근본 정리는
>   `BEGIN` 중첩·WAL 전환 제약이 얽혀 있어 사고 수습과 분리했다.

> **D120 (2026-09-05) — 실사용 한 바퀴(코치 PC → 회원 앱 → 히스토리)로 잡은 것:
> 완료 시트의 '수업 내용' 이 넉 줄에서 잘려 B 파트가 안 보였다.**
>
> - 사용자 지시로 **코치 웹에서 9/10 AWAKE 를 A·B 파트로 게시**하고(동작 사전에서 골라
>   Back Squat 5-5-5-5-5회·60kg / Thruster 12회·40kg · Pull-up 9회 · Box Jump 15회),
>   같은 내용을 **오늘 12:30 AWAKE** 로도 하나 만들어 회원 앱으로 예약 → 완료 → 기록 →
>   히스토리까지 실제로 걸었다.
> - **잘 도는 것 (확인됨)**: 파트 표시(A·B 머리줄 + 동작 줄) · 예약(캐릭터 토스트) ·
>   코치 명단에 즉시 반영 · **완료 게이트**('수업 시작 전' → 시각이 지나자 '완료 표시') ·
>   **완료 시트의 코치 값 프리필**(동작 넷 전부, 무게 칸 포함) · 저장 후 '기록' 배지 ·
>   히스토리 목록·상세(동작별 기록 + 수업 내용 + 동작별 보기 배지) · 재열람 시 **내가 고친
>   값**(60 → 65)이 다시 채워지고 '이미 저장한 기록이 있습니다' 고지.
> - **잡은 결함**: 시트 위쪽 '수업 내용' 이 `maxLines: 4` 라 **A 파트에서 잘렸다**.
>   그 값은 파트가 생기기 전(D109 이전)의 것이다. 아래 '내 기록' 에는 B 파트 동작이
>   입력 칸으로 서 있는데 위에서는 그 파트가 안 보여, **자기가 지금 적는 것이 무엇인지
>   못 보는 화면**이었다. 시트는 이미 스크롤되므로 자를 이유가 없다 — 제한을 걷었다.
>   게이트 = `test/result_sheet_content_test.dart`(줄 수 제한 없음 + B 파트 실제 렌더).
>   골든 1장 재생성(member_06 — 이제 A·B·C 세 파트가 다 보인다).
> - 전체 **279 통과** · analyze 0 · 골든 89장(1장 재생성).
> - **에뮬레이터는 날짜 경계 검증에 쓰지 않는다** — 기기 시간대가 UTC 라 KST 9/10 06:30 이
>   9/9 21:30 으로 묶여 '아직 게시 전' 으로 보인다. 서버 응답(`post_date` 2026-09-10 ·
>   `first_class_at` +09:00)은 정확하다. 날짜가 걸린 확인은 KST 실기로 한다.

> **D119 (2026-09-05 집행) — 수업 줄 오른쪽은 누를 게 없으면 비운다 (앱).
> 사용자 지시: "날짜가 지나면 굳이 종료라고 버튼 해서 지저분하게 하지말고, 그냥 깨끗하게
> 아무것도 없는 화면으로 하고, 예약하고 나서도 다른곳도 오늘 예약완료 그런 문구도 그냥
> 없애자. 걍 깨끗한 화면."**
>
> - 없앤 것 둘 — **'종료'**(지난 수업)와 **'오늘/이번 주 예약 완료'**(하루·주 한도).
>   둘 다 누를 수 없는 배지였고, 앞엣것은 날짜·시각이 이미 말하는 것을 한 번 더 말했다.
>   D82(예약 오픈 전) 때 '오픈 전' 배지를 없앤 것과 같은 방향이다 — **못 하는 것을
>   배지로 설명하지 않는다.**
> - **자리는 비우되 높이는 지킨다.** `_emptyAction` = 손가락 기준(48)과 같은 높이의 빈
>   자리다. 배지만 지우면 줄이 짧아져 목록이 들쭉날쭉해지고 상태가 바뀔 때 아래가
>   밀린다 (D115~D118 에서 내내 다룬 그 문제). 게이트 = `test/class_row_clean_test.dart`
>   — 문구 부재 2건 + **예약 가능·지난 수업·한도 도달 세 줄의 높이 동일**.
> - 남는 배지는 종전대로다 — 예약 · 대기 · 예약됨 · 취소 · 취소됨 · 마감 · 회원권 필요.
>   **'회원권 필요' 는 남긴다**: 그건 지난 일이 아니라 지금 사람이 손쓸 수 있는 일이고,
>   탭하면 서버 문구를 스낵바로 준다.
> - **잃는 것도 적어 둔다.** 한도에 걸린 줄을 탭해 받던 서버 문구("하루 예약 한도(1회)를
>   초과했습니다")를 이제 볼 수 없다. 사용자가 "그 문구도 없애자" 라고 명시했고, 예약
>   배지가 서지 않는다는 사실 자체가 한도를 말한다고 보아 그대로 집행했다. 서버 게이트는
>   그대로다 — 화면만 조용해졌고 판정은 종전과 같은 함수(`reserve_limit_reached`).
> - 골든 **89장 유지 · 2장 재생성**(state_07 종료 수업 · state_32 하루 한도).
>   전체 278 통과 · analyze 0. `touch_target_test` 의 표본 라벨에서 사라진 '종료' 를
>   빼고 살아 있는 '취소'·'마감' 으로 교체 (§0-B).

> **D118-실기 (2026-09-05) — 에뮬레이터로 릴리즈 APK 를 실제로 돌려 잡은 것:
> 수업 탭이 '불러오기 실패' 를 '체육관 미가입' 이라고 말하고 있었다.**
>
> - 폰이 무선 디버깅 꺼져 있어 **에뮬레이터**(Medium Phone API 36.1)에 운영 URL 릴리즈
>   APK 를 설치하고 심사 계정 `testmember1` 로 들어갔다. 승인된 회원(gym 2 · approved)인데
>   수업 탭이 **'체육관 미가입'** 을 띄웠다. 앱을 껐다 켜니 정상이었다.
> - **화면 코드가 `hasGym` 만 보고 있었다.** `GymState.error` 는 존재하는데 아무도 안 읽어,
>   못 읽은 것과 소속이 없는 것이 **같은 문장**으로 나왔다. 게다가 그 화면엔 다시 시도할
>   길이 없어 앱을 껐다 켜는 것 말고는 방법이 없었다. 홈 도전 섹션이 실패를 0px 로
>   숨기던 것(D118 #7)과 **같은 병**이다 — 제1원칙: 화면은 거짓말하지 않는다.
> - 고침 = 실패 분기를 세워 `HkErrorState` + '다시 시도'. 게이트 =
>   `test/golden/class_tab_error_test.dart` 두 검사(실패는 에러로 / 진짜 미가입은 그대로).
>   붙이기 전 첫 검사가 '체육관 미가입' 을 찾아내며 실패하는 것을 확인했다.
> - **재현 범위는 정직하게 적는다.** 이 증상은 **덮어쓰기 설치 + 만료된 세션**이 남아 있던
>   기기에서 한 번 관측됐고, `pm clear` 후 **깨끗한 설치에서는 재현되지 않았다**(로그인
>   직후 수업 목록이 정상 표시). 즉 심사원이 밟는 길(새 설치)은 지금도 정상이다. 다만
>   위 코드 결함은 통신이 한 번만 실패해도 그대로 드러나므로 재현 여부와 무관하게 고쳤다.
> - 서버는 결백했다 — `/api/v1/gyms/mine` 은 채택한 기기 id 헤더만으로 쿠키 없이도
>   gym 2·approved 를 정확히 내려준다(직접 호출로 확인).
> - **같은 날 실기(갤S22 · SM-S901N · 안드로이드 16)로 다시 확인**했다. 빌드 3029 설치 →
>   실계정으로 수업 탭·홈·내 정보·전자계약서·쪽지함·대화까지 걸어 봤다. 홈 '도전' 칸이
>   항상 서고, 전자계약서 빈 상태가 예약된 자리의 **위에서부터** 그려지며, 채팅 입력줄이
>   한 줄로 유지되는 것을 눈으로 확인. 걷는 동안 크래시·flutter 에러 로그 **0건**.
>   ※ 이미 떠 있던 앱이 지난주(9.7–9.13)를 보여 준 것은 **살아 있던 프로세스의 이동 상태**였다 —
>   강제 종료 후 다시 열면 이번 주(8.31–9.6)·오늘(토 5)로 정확히 열린다. 결함 아님.

> **D118-PC (2026-09-05 집행) — 사문 부품 13건 전량 삭제 · 페이지 `<style>` 10 → 2 ·
> 게이트 §7.8 (관리자 웹).**
>
> - **목록을 그대로 믿지 않았다.** `docs/UI-INDEX.md §7-2` 가 지목한 13건을 `class=` 뿐
>   아니라 `className =` 대입 · `classList` · 백틱 조립 · Jinja 조건 · 파이썬 문자열까지
>   전수로 다시 확인했다(같은 문서가 "`class=` 만 grep 하면 오판한다" 고 경고해 뒀다).
>   **13건 전부 사용처 0** — 전량 삭제하고, 지운 자리마다 "언제·왜 지웠고 지금은 무엇이
>   그 일을 하는가" 를 주석으로 남겼다.
> - **`.stack` 3종은 '철회' 로 기록**했다. SSOT §9-C·갤러리 §17 에 "A안 확정 승인까지
>   받았으나 3주간 도입 0건" 이 남는다 — 승인 이력을 조용히 지우지 않는다.
> - **게이트가 사람을 이겼다.** `design/lint.py §7.8 사문 부품`(§7.5 유령 클래스의
>   반대편)을 붙이자마자 **손으로 센 목록에 없던 3건**을 더 잡았다 — `.more-link` ·
>   `.class-card` · **`.page-banner-slot`**. 마지막 것은 D115 에 만든 배너 자리 그릇인데
>   마크업에 안 붙어 있어 **배너 아래 여백이 3주간 빠져 있던 원인**이었다.
> - **페이지 전용 `<style>` 10 → 2** (남긴 둘 = 셸을 안 쓰는 landing·login) · 인라인
>   `style=""` 6 → 5 (남은 5 는 전부 색·높이 같은 **데이터**). 흡수하며 이원화가 더
>   나왔다 — 날짜 피커 CSS 2벌(한쪽에 08-19 에 지운 **다크 잔재** 생존) · `.dday-badge`
>   정의 2벌 + 톤 이름 2세트 · `tr.row-urgent` ↔ `tr.is-urgent` · 규격에 없는 초록 뱃지 ·
>   **`stats.html` 이 D115 컨트롤 높이 통일(34)을 통째로 비껴가 있던 것**(29·24·33).
> - 명단 출석·노쇼 토글은 JS 가 `style="…"` 문자열로 **부품 하나를 통째로** 그리고
>   있었다(D116 토스트가 세 벌로 갈렸던 것과 같은 병) → `.roster-mark` + `--mark-tone`
>   변수 하나, 색 리터럴 0.
> - 린트 위반 **0** 유지 · 토큰 드리프트 없음 · PC 게이트 **6종 → 7종**. 로컬 백엔드와
>   함께 띄워 브라우저로 12화면을 실제로 열어 확인(콘솔 에러 0, `getComputedStyle` 실측).
> - **안 한 것**: `dead_utilities` 16건(생성 유틸)은 `scripts/inline_style_sweep.py` 가
>   "수동 편집 금지" 블록이라 손대지 않고 **래칫으로만 묶었다** — 실제 정리는 생성기에
>   pruning 을 넣어야 한다.

> **D117 (2026-09-04 집행) — 앱 밀림 후보 6건 + 높이 검사 도구 (앱).
> 사용자 지시 "니가 제안하는 작업시작" — 추천안이 '고치기 전에 검사부터 쓴다' 였다.**
>
> - **순서를 지켰다.** 게이트를 먼저 얹어 **지금 밀리는 것을 실패시키고** 고쳤다.
>   실제로 잰 값: 완료 시트 **27px** · 쪽지함 목록 **89px** · 22↔36 스왑 2곳 14px ·
>   코치 주간은 **앵커 소실**(카드 7행을 배너로 통째 치환해서 요일 행이 사라졌다 —
>   앵커가 없어지면 좌표 검사를 걸 수조차 없다).
> - **완료 시트 실패 문구** — 버튼 위 조건부 블록을 없애고, **버튼 아래 이미 있던
>   고지 한 줄**에서 글자만 바꾼다. 빈 띠를 새로 만들지 않는 쪽이다(§레이아웃 안정성의
>   '빈 띠 없이 자리를 지키는 법'). 실패 직후가 다시 누르기 가장 쉬운 순간인데
>   버튼이 손가락 아래에서 27px 도망갔다.
> - **코치 주간** — 카드는 그대로 세우고 실패 문구를 **카드 아래**로. 아래에 요소가
>   없어 아무것도 안 밀고, 주를 옮겨 다시 시도하는 길(주간 헤더)도 남는다.
> - **쪽지함 대화·활동 목록** — 빈 상태만 자리를 안 잡고 있었다(로딩·에러는 D115 로
>   132). `HkReservedSlot(stateSlotH)` 로 바닥을 맞췄다 — 문구 모양은 그대로.
> - **22↔36 스왑 2곳**(미가입 확인 버튼 · 수업 질문 보내기) → `HkButton(busy:)`.
>   문서에 이미 '밀림 4번 정답' 으로 적혀 있던 것이 화면 두 곳에 안 닿아 있었다.
> - **검사 도구가 하나 늘었다 — `expectStableHeight`.** `expectStableAnchorY` 는
>   앵커의 **시작 y** 만 재서, 자리가 목록 **맨 아래**면 그 안이 132→43 이 돼도
>   안 걸린다. 쪽지함이 정확히 그 상태였다. 이제 자리의 **높이**를 재는 헬퍼가 따로 있다.
> - 안정성 검사 **21 → 25**. 전체 256 통과 · analyze 0 · **골든 재생성 0**
>   (에러·빈 상태는 캡처 대상이 아니라 픽셀이 안 바뀌었다).
> - **남은 밀림 후보 4** (정직하게 남긴다): 수업 상세 대체요청 시트(앵커 밖) ·
>   홈 도전 섹션(홈 마지막이라 위는 안 밀림) · 계약 목록(화면 전체 교체라 앵커 설계 필요) ·
>   채팅 전송 아이콘(**미확인** — 실측이 먼저). 목록 = `docs/UI-INDEX.md §11`.

> **D116 (2026-09-04 집행) — 토스트 한 벌 (PC). 사용자 지시 "토스트 한 벌로 — 남은 이원화 하나."**
>
> - **세 벌이었다.** `static/style.css .toast`(패딩 24×36 · 왼쪽선 8 · 위로 솟는 애니메이션) ·
>   `showSyncToast`(20×28 · 간격 16 · 최대폭 680 · **테두리 전체가 톤색**) ·
>   `showToast`(28×32 · 간격 24 · 640 · `--border` + 왼쪽 6). 애니메이션 이름도 둘
>   (`toast-in` / `toastSlideIn`). 게다가 **CSS 쪽은 아무도 안 썼고**, 갤러리가 그
>   사본을 보여 줘서 시안이 실물과 달랐다 (D114 감사 §3 의 "갤러리가 틀린 곳" 2번).
> - **모양은 `.toast` 한 곳.** 톤은 상태 클래스가 `--toast-tone` **하나만** 바꾼다
>   (`.is-success`·`.is-warn`·`.is-error`). 아이콘 stroke 도 그 변수라 색 리터럴 0.
>   뼈대 = `.toast > [.toast-icon] + .toast-body(.toast-msg/.toast-sub) + [.toast-time]` —
>   아이콘·시각은 선택이라 두 함수가 같은 부품 위에서 다른 내용을 담는다.
>   자리 잡기는 그릇(`#churnToastContainer`)이 하고 `.toast` 는 position 을 안 잡는다.
> - **톤 이름 정본 = success · warn · error · info.** 구 `danger`(showSyncToast 만 쓰던
>   이름)는 `error` 로 받는다 — 실사용 0건이라 호출부 변경 없음.
> - **게이트 §7.7 `style.cssText` 금지 (신설).** `style="` 래칫이 안 세는 사각지대였고,
>   토스트가 세 벌로 갈린 경로가 정확히 이것이다. 남아 있던 실물 1건(SSE 연결 끊김 띠)도
>   `.sse-banner` 부품으로 올려 **현재 0건**. 음성 검사로 실제 검출을 확인했다.
> - **덤으로 잡힌 결함**: 동기화 토스트 시각이 `toLocaleTimeString('ko').slice(0,5)` 라
>   "오후 10:03:22" 를 잘라 **"오후 10"** 을 보여 주고 있었다 → 24시각 `hh:mm`.
> - SSOT 등록: `design/SSOT.md §19` · `CLAUDE.md` UI 컴포넌트 표준 · 갤러리 §10 시안 교체.
>   검증: 린트 위반 0 · 토큰 드리프트 0 · 실브라우저로 4종 렌더 · 인라인 style 0 확인.

> **D115 (2026-09-04 집행) — 자리 예약 + 컨트롤 높이 통일 (앱 · PC).
> 사용자 지시 "스켈레톤으로 자리 잘 비워두고 특히 레이아웃 시프트 발생 안 하도록 하고,
> 또 버튼 크기나 그런것도 좀 통일하고 ㄱㄱ SSOT 등록 필수!"**
>
> - **앱 — 로딩·빈·에러가 같은 바닥.** 실측 22 / 70·97 / 131 로 **최대 109px** 낙차였다.
>   `HyphenTokens.stateSlotH`(132)를 셋의 최소 높이로. `HkLoading()` 기본은 22 그대로 두고
>   자리를 차지하는 쪽은 **`HkLoading.slot()`** — 버튼 안 스피너까지 132 로 만들면 안 된다.
>   같은 자리 삼항 교체 12곳 이관 · 가입 신청 목록의 평문 `Text` 에러 → `HkErrorState`.
>   게이트 `test/state_slot_test.dart` — **상수 비교가 아니라 실물을 `getSize` 로 잰다**.
> - **PC — 세 상태가 같은 자리(`--slot-msg` 76 · 넉넉본 132).** 종전 스켈레톤 ~80 → 문구 ~74 →
>   실제 행으로 바뀔 때마다 아래가 튀었다. 원인은 공용 로더 둘 중 `fetchTableInto` 만
>   스켈레톤을 안 깐 것 — 그래서 표 화면 7곳이 글자로 남아 로딩 표시가 **5갈래**로 갈렸다.
>   로더 한 곳을 고쳐 전부 옮겼다. 첫 화면 정적 자리표시자도 같은 마크업.
> - **PC — 조건부·폭 변동 예약.** `.page-banner` 는 `display:none` → `.is-empty`(visibility);
>   배너가 뜰 때 페이지가 약 45px 밀리던 것 차단. 공지 월 라벨·회원 상세 포인트는
>   최소 폭 + 자릿수 고정폭 (값이 길어지면 옆 버튼을 밀었다).
> - **PC — 컨트롤 높이 하나 `--ctrl-h` 34.** 실측 33/35/29/26/34/28 여섯 가지였다.
>   버튼·입력칸·검색칸·칩·탭칩·페이저 전부 34 (`textarea` 만 예외). 탭 줄 그릇은
>   **`.tab-row` 하나** — 구 `.tabs` 는 CSS 정의가 없는 유령 클래스였고 "다른 화면과
>   같은 부품" 이라던 주석도 사실이 아니었다.
> - **게이트 2종 신설 (문서로만 막지 않는다 — 대전제 6-b)**: `design/lint.py`
>   §7.5 유령 클래스(마크업이 부르는데 정의 없음) · §7.6 로딩 자리(자리 부품 없이 맨몸).
>   첫 실행 22건 → **전부 수정**, 최종 위반 0. 한 줄 라벨 3종만 §7.6 면제.
> - **SSOT 등록**: 앱 `DESIGN-SSOT §레이아웃 안정성` · PC `design/SSOT.md §17·§18` ·
>   갤러리 `§21·§22` · PC `CLAUDE.md` 규칙 절. **용어 정본은 앱 문서 하나**, PC 는 링크만.
>   두 면 부품·화면 인덱스 = `docs/UI-INDEX.md` (D114 감사에서 신설, §9 에 집행 결과).
> - 검증: 앱 249 통과(+3) · analyze 0 · 골든 89장(1장 재생성) / PC 린트 위반 0 ·
>   토큰 드리프트 0 · 실브라우저로 세 상태 높이 76/76/76 · 컨트롤 34 확인.

> **D114 (2026-09-04 집행) — 알림 설정 보관함 탭 + 노쇼 정책 배열 (PC · 서버).
> 사용자 지시 "PC 화면에서 알림설정에서 최근발송, 발송시각 다른 로그 보관함 (탭 만들어서) 저장하고,
> 노쇼정책에서 또 버튼들 아무 규칙없이 제멋대로 배열되어있다. SSOT 찾아서 우리 화면 레이아웃에 맞춰서 제작".**
>
> - **탭 3개** — 알림 · 노쇼 정책 · **보관함**. '발송 시각'(정보)과 '최근 발송'(기록)이 보관함으로 옮겨졌다.
>   알림 탭이 세로 2600px 이라 기록이 맨 밑에 묻혀 있었고, 그 기록은 **최근 7일 100건**이 전부였다.
> - **보관함 = 영구 기록 창구.** 발송 기록은 `AuditLog(action='note.auto')` 이고 이 표는 **삭제 안 함**
>   (`models/audit_log.py` — 정보통신망법 §29). 그러니 화면도 전부 꺼낼 수 있어야 한다:
>   기간(7·30·90일·**전체**) · 발송 항목 · '더 보기'(`before_id` 커서, 한 쪽 `LOG_PAGE_SIZE`=50).
>   `GET .../notification-logs?days=&category=&before_id=` → `{items, next_cursor, days, category, options}`.
>   구 응답은 배열 하나였다 — **응답 모양이 바뀌었으므로 이 엔드포인트를 부르는 곳은 PC 한 곳뿐임을 확인했다.**
> - **선택지는 서버가 만든다 (대전제 6-b).** 기간·항목의 라벨·허용값 정본 =
>   `api/notifications/note.py` `LOG_RANGES` · `log_range_options/days` · `log_category_options/category`.
>   PC 는 `options` 를 그대로 그리고 값 검증을 다시 하지 않는다. 항목 라벨은 `NOTE_TEMPLATES` 그대로.
>   항목 거르기는 payload(JSON) 안이라 `func.json_extract(payload,'$.category')` — SQLite 전용이나 이 제품은 SQLite 하나다.
> - **왜 '제멋대로' 였나 (노쇼 정책)** — 규칙 줄이 `.setting-row`(= `justify-content: space-between`)였다.
>   그 부품은 **'이름 왼쪽 · 조작 오른쪽' 전용**이라 칸 5개를 640px 에 균등 분산시켰고, 낱말('이후 취소하면')이
>   자기 칸에서 떨어져 문장이 끊겼으며 **맨 끝 '삭제' 는 카드 테두리 밖으로 잘려** 있었다. 카드는 `padding: 0`
>   이라 글자가 테두리에 붙었고, 바닥은 `.row-between` 이라 빨간 [저장] 과 빨간 [기본 규칙으로] 가 양 끝에
>   찢어져 있었다 (죽은 별칭 `.btn-primary` 도 남아 있었다 — SSOT §8.3 은 버튼 변형 없음).
> - **바뀐 것** — 카드 2장 + div 줄 → **규칙 표 한 장**(줄 묶음 제목 = 기존 `tr.plan-group`). 서버 응답도
>   `policies` 한 배열이라 표 하나가 그 모양 그대로다. 조치·면제 칸이 세로로 맞고, '+ 취소 시점 추가' 는
>   **표 안 마지막 줄**의 글자 버튼, '기본 규칙으로' 는 `.form-actions` 줄 끝 글자 버튼 —
>   **패널의 빨간 버튼은 '저장' 하나**다. 카드는 `p-24`.
> - **판정은 그대로 서버 한 곳** (`api/_membership.py`) — 이 화면은 규칙 줄을 고를 뿐이고, 적용 문구(`label`)도
>   서버가 만든 것을 그대로 보여준다 (줄을 고치는 중이면 "저장하면 …표시됩니다").
> - **디자인 SSOT 등재**: 부품 `.form-actions`(동작 줄) + 규칙 표 = `web/facing-admin/design/SSOT.md §16`,
>   시안 = `design/gallery.html §19·§20`. 삭제된 부품: `.log-row`(보관함이 표가 되며 쓰임 0).
> - **검사**: `tests/test_notification_note_gates.py` 에 2건 추가 —
>   선택지가 note.py 에서 온다(라벨 복제 금지) · 항목 거르기 + 커서 페이징(앞뒤 쪽이 겹치지 않음) + `days=0` 전체.
>   서버 708 passed · PC 디자인 린트 위반 0(baseline 유지) · 로컬 실브라우저 왕복(추가·삭제·저장·되돌리기·
>   기간/항목 전환·더 보기 50→78) 확인.

> **D113 (2026-09-04 집행) — 손가락 영역 48: 누르는 배지·요일 칸·여닫기 화살표가 가로도 48 을 갖는다 (앱).
> 사용자 지시 "너 말대로 폭 48 적용시키자" (페르소나 5명 실측에서 예약 배지 42×48 · 요일 칸 45×58 · 화살표 32×32 로 드러남).**
>
> - **왜**: `DESIGN-SSOT §3` 은 터치 48 을 요구하는데 `HkBadge` 는 **세로만** 48 을 잡고 가로는 글자 폭을 따라갔다 —
>   '예약' 두 글자가 42px 였다. 요일 띠는 칸 사이 4px 간격 때문에 45px, D112 로 넣은 여닫기 화살표는 32px 였다.
> - **바뀐 것 (그림은 그대로, 누르는 상자만)**: `HkBadge` 의 `SizedBox(height: touchMin)` → `ConstrainedBox(minWidth/minHeight:
>   touchMin)` (`widthFactor: 1` 유지 — Row 안에서 남는 폭을 먹지 않는다) · `HkDayStrip` 칸 사이 간격 4 → 0 (336 / 7 = 48,
>   경계는 배경·테두리가 말한다) · `ClassLine` 여닫기 화살표 상자 32 → 48 (아이콘은 20 그대로).
> - **표시 전용 배지는 종전 크기** — `onTap` 이 없는 배지(종료·기록 표시 등)는 넓히지 않는다. 조작 배지만 48 이다.
> - **게이트**: `test/touch_target_test.dart` — 상수를 다시 적지 않고 **실물 렌더를 `tester.getSize` 로 잰다**
>   (조작 배지 5종 가로·세로 · 표시 배지는 48 미만 유지 · 요일 칸 7개, 360 폭 기준). 골든 21장 재생성(89장 불변).

> **D112 (2026-09-04 집행) — 수업 탭은 닫힌 채로 연다: 날짜를 누르면 줄만, 이름 옆 화살표로 그날 운동을 여닫는다 (앱).
> 사용자 지시 "날짜를 클릭해서 들어오면 지금처럼 시간별 옆에 예약 버튼도 있고, 각 운동프로그램 AWAKE·SWEAT 등 옆에
> 화살표(아래 방향)를 둬서 누르면 운동이 보이게 하고, 다시 누르면 닫히게. 아무것도 안 누르고 날짜만 클릭해서 그 날로
> 돌아왔을 때는 지정한 수업시간·운동프로그램·정원·예약 혹은 종료 이런 버튼만 보이게".**
>
> - **접힌 줄 = 시각 · 수업 이름(+화살표) · 정원/대기 · 배지(예약·대기·예약됨·종료·마감·오늘 예약 완료)** 넷뿐이다.
>   D111 의 접힌 줄 요약(서버 `summary`) 줄은 **삭제** — 줄이 답할 것은 "언제 · 무슨 수업 · 자리 · 지금 뭘 누를 수 있나" 다.
>   (서버 `summary` 키는 그대로 둔다 — 히스토리와 같은 함수라 비용이 없고, 다시 쓸 자리가 생기면 그대로 받는다.)
> - **여닫기는 사람만.** D111 의 자동 펼침(`autoExpanded` — 내 예약 줄 전부 / 없으면 다음 수업 1개)은 **폐기·함수 삭제**.
>   날짜를 눌러 들어오면 모든 줄이 닫혀 있고, **이름 오른쪽 화살표**(∨/∧, `ClassLine.onToggle`)나 줄 본문을 눌러야 열린다.
>   여러 줄을 함께 열어 둘 수 있다. **날짜·주를 옮기면 전부 닫힌 상태로 돌아간다**(`_expanded` 를 비운다) — 열어 둔 것을
>   기억하지 않는다(사용자 "그 날로 돌아왔을 때는 …버튼만").
> - **'프로그램' 밑 카드도 닫힌 채로 선다** — 수업 줄이 없는 종류의 글(`leftoverPrograms`)에 걸린 구 v3.41 '전부 펼침'
>   (`initiallyExpanded: true`)을 끊었다. 한 화면에 여는 규칙이 둘이면 그게 곧 헷갈림이다.
> - **배지 탭은 종전 그대로** — 예약·취소는 배지의 InkWell 이 먼저 받는다(화살표와 떨어져 있어 오탭이 없다).
> - **게이트**: `test/golden/class_tab_test.dart`(들어오면 전부 닫힘 · 화살표 하나씩 · 열고 닫기 · 날짜 이동 시 초기화 ·
>   예약이 있어도 안 열림) · `test/golden/stability_wod_test.dart`(접힘/펼침 두 상태에서 위 y 불변 — 상태 이름을 뒤집었다) ·
>   골든 19장 재생성(89장 불변). 검사가 펼친 본문에 닿을 때 쓰는 공용 진입 = `test/golden/harness.dart`
>   `openClassRow(tester, classId)` · `openProgramCard(tester, postId)`.

> **D111 (2026-09-04 집행) — 회원 수업 탭 = 통합 한 줄: 요일 띠 + 수업 줄(시간 · 내용 · 예약 · 완료 한 자리). 두 칸(프로그램 · 수업 시간) 세그먼트 폐기 (앱 · 서버 한 줄).
> 사용자 지시 "수업은 수업대로 보고, 예약은 예약대로 … 가독성·레이아웃 통일성 떨어져서 반응 유도 어려울 것 같은데" → 목업 세 안 중 **"1안"** 선택.**
>
> - **왜**: 회원의 결정은 하나("20:00 SWEAT 에 가서 이걸 한다")인데 화면이 동기(프로그램 칸)와 버튼(수업 시간 칸)을 갈랐다.
>   같은 주간 아코디언에 문법이 다른 두 칸 · 요일+카드 이중 펼침 · '수업 없음' 요일 줄의 세로 낭비가 겹쳐 가독성이 떨어졌다.
> - **구조** (`lib/features/gym/week_board.dart` 재편, 화면은 `box_wod_screen.dart` 그대로 수업 탭):
>   1. 주 이동 줄(‹ 8.10 – 8.16 [이번 주] ›) 유지.
>   2. **요일 띠** 7칸(요일 글자 + 날짜 숫자, 오늘 = 채움). 고른 날 하나만 아래에 편다. 기본 = 오늘(그 주에 있으면), 다른 주는 월.
>      칸 아래 점: 그날 **내 예약** 있으면 주색 점, 예약은 없고 수업만 있으면 회색 점, 수업 없으면 점 없음 (그 주의 수업 목록으로 판정 —
>      정의 1곳 `week_board.dart dayMark(date)`). 띠·주 이동 줄의 y 는 어느 날을 골라도 불변.
>   3. **수업 줄 목록**(고른 날, 시작 시각 순) — 줄 = 기존 `ClassLine.member` 규격 그대로(시각 · `display_title` · 정원/대기/상태 메타 ·
>      오른쪽 배지 예약/대기/예약됨/대기 N/종료/오늘 예약 완료 — 판정·문구 종전 코드 재사용, 새로 세지 않는다). 줄 본문 탭 = 펼침.
>      **접힌 줄 메타 끝에 그 종류의 그날 프로그램 한 줄 요약**(서버 `summary`, 없으면 생략).
>   4. **펼침** = 그 줄의 수업 종류(`templateId`)에 붙은 그날 글(`wods` 중 `templateId` 일치, 없으면 '아직 게시 전.'/'게시된 프로그램 없음.')을
>      **기존 `WodRow` 본문 그대로**(파트 세로 · 메모 · [완료 표시/예약 필요/기록 N] [메시지] [자세히]) — 카드 머리(이름표 줄)는 접힌 줄이
>      이미 말했으므로 생략. 잠긴 글은 `LockedWodBanner`. 같은 종류 두 타임이면 각 줄 펼침에 같은 본문(별도 "위와 같음" 없음).
>   5. **자동 펼침** = 그날 내 예약 줄 전부 + (예약 없으면) 다음 수업 1개(시작 시각 ≥ 지금인 첫 줄). 지난 날은 아무 줄도 안 편다.
>   6. **수업 종류가 없는 단발 글·그날 수업이 없는 종류의 글**은 목록 아래 '프로그램' 섹션 라벨 밑에 종전 `WodRow`(머리 포함)로 —
>      글이 사라지지 않는다(`visibleProgram` 재사용). 수업도 글도 없으면 '등록된 수업 없음.' 한 줄(HkSectionSlot 예약 자리).
> - **서버 (두 줄)**: 모든 수업 직렬화(`class_public_fields`)에 `template_id` — 회원 `GET /member/classes` 에 없어 앱이 수업 줄과 글을
>   못 맞추던 갭(앱 fork 발견, 이름으로 맞추지 않는다 6-b). 회원 `GET /gyms/<id>/wods` 항목에 `summary` = `program_lines.movement_summary(post)`(히스토리 둘째 줄과 같은 함수 —
>   'Back Squat 5-5-5회 · 100kg · KB Swing 15회'). 앱은 그대로 적는다(요약 조립 금지).
> - **폐기**: 프로그램/수업 시간 `HkSegment` · 요일 아코디언 `_DayTile` · 두 칸 회귀 `test/golden/week_pane_test.dart` · 칸 전환 안정성
>   `test/golden/stability_wod_test.dart`(→ 요일 띠 전환 안정성으로 교체). 홈 '오늘 내 예약' 카드 · 코치 셸(`coach_week_classes.dart`) 무변경.
> - **게이트**: `test/golden/program_order_test.dart`(줄 순서 = 시작 시각 · 자동 펼침 규칙 · 단발 글 섹션) · `test/golden/stability_wod_test.dart`
>   (요일 전환·펼침 시 띠·주 이동 줄 y 불변, 목록 로딩 자리 예약) · 골든 member_07(수업 탭 기본 = 오늘, 다음 수업 펼침)·member_26(예약 줄
>   펼침 + 파트) 재정의 · `copy_lint`·`ssot_lint`. 서버 `tests/test_program_parts_d109.py` 에 `summary` 키 검사 1건.

> **D110 (2026-09-04 집행) — 프로그램 보관함: 코치가 그날 운동(파트 포함)을 이름 붙여 미리 짜 두고 수업 등록·수정·게시에서 불러온다 (서버·PC).
> 사용자 지시 "PC 에서 운동 수업 설정할 때 안에 들어가는 운동 프로그램들 내가 더 추가할 수 있는 탭 사이드바 어디에 만들어놔
> (api, 이음새, SSOT 철저히 지켜서)".** 4기둥 판정 = '수업 공개' 의 받침(코치가 수업 내용을 미리 짜 둔다).
>
> - **뜻**: 보관 프로그램 = 이름 + 그날 운동 구조(파트 목록 + 메모). 수업 종류·날짜에 묶이지 않는다. 수업 등록·수정 모달과
>   게시 모달의 편집기에 **'보관함에서 불러오기'** 셀렉트가 붙어 고르면 편집기·메모가 그 내용으로 채워진다 — 그 뒤 저장은
>   종전 경로(수업 POST/PATCH `program` · 게시 POST/PATCH `program`) 그대로다. 보관함은 **원본이 아니라 복사 원천** — 보관
>   프로그램을 고친다고 이미 게시된 글이 바뀌지 않는다.
> - **동작 사전 입구 복구**: 8/13 '수업 내용' 링크를 숨기며 그 안의 동작 사전 탭도 사이드바에서 사라졌다. 보관함 페이지의
>   둘째 탭이 동작 사전이다 — 사전 탭 마크업·JS 는 부분 템플릿 `templates/_movement_library_tab.html` 한 벌로 옮기고
>   숨은 `/wod` 페이지도 같은 부분 템플릿을 include 한다 (복제 0).
> - **정의 = 서버 한 곳** (6-b): 검증 `program_lines.normalize_program`(수업·게시와 같은 함수) · 미리보기 본문
>   `apply_program`(제목 = 보관 이름) · PC 프리필 `program_of` · 한 줄 요약 `movement_summary` · 총 시간
>   `program_lines.program_duration_min(parts)`(파트 duration 합, 하나도 없으면 None) — 전부 기존 함수 재사용. PC 는 API 값만 그린다.
> - **데이터**: 새 표 `gym_programs` (`models/gym_program.py GymProgram`) — `id · gym_id(FK gyms, index) · name(60, NOT NULL) ·
>   wod_type · rounds · time_cap_sec · rounds_data(Text) · content(Text, 렌더 미리보기) · is_active(기본 1) · created_at · updated_at`.
>   게시물과 **같은 구조 컬럼**이라 `apply_program`/`program_of`/`movement_summary` 가 행을 그대로 받는다. 삭제 = `is_active=0`
>   (휴면 — 데이터 삭제 없음). `create_all` 이 만든다(멱등).
> - **API** (admin · `require_staff` · 쓰기는 CSRF · 다른 체육관 403):
>   - `GET /api/v1/admin/gyms/<gym_id>/programs` → `{items:[{id, name, summary, part_count, duration_min, content, program:{parts, memo},
>     updated_at}]}` — `is_active` 만, `updated_at` 내림차순.
>   - `POST /api/v1/admin/gyms/<gym_id>/programs` `{name, program, memo}` → 201 item. `name` 빈값·60자 초과 400 `VALIDATION_ERROR`,
>     같은 체육관 활성 이름 중복 409 `DUPLICATE_NAME`, `program` 은 `normalize_program`(400 `INVALID_PROGRAM`), 동작 0 이면 400
>     `INVALID_PROGRAM` "동작을 하나 이상 고르세요".
>   - `PATCH /api/v1/admin/programs/<id>` `{name?, program?, memo?}` → item. `DELETE /api/v1/admin/programs/<id>` → `{deleted:true}`
>     (is_active=0, 이미 꺼진 것은 404).
> - **PC**: 사이드바 '수업' 그룹에 **프로그램 보관함**(`/programs`, 수업 관리 다음 줄). 페이지 탭 = 보관함(목록 카드: 이름 · 요약 ·
>   파트 수 · 총 시간 · 수정 · 삭제 + '+ 프로그램' 모달 = 이름 · `ProgramEditor` · 메모) · 동작 사전(부분 템플릿). 수업 등록·수정
>   모달과 게시 모달의 '그날 운동' 라벨 옆에 `보관함에서 불러오기` 셀렉트(목록은 GET programs, 고르면 `editor.setValue(item.program)`
>   + 메모 칸 = `item.program.memo`, 비어 있으면 '보관함 비어 있음 — 프로그램 보관함에서 추가' 안내 링크).
> - **앱**: 변경 없음 (회원은 게시된 글만 본다).
> - **게이트**: 서버 `tests/test_programs_library_d110.py`(CRUD · 검증 · 체육관 격리 · 보관 → 수업 등록 program 왕복이 같은 파트를
>   만든다 · 소프트 삭제) + `tests/test_ssot_program_lint.py` 스캔에 새 파일 포함(자동) · PC `design/lint.py`.

> **D109 (2026-09-04 집행) — 파트: 그날 운동을 한 수업 안에서 A·B·C 구간으로 나눈다 (세션 D89·D98·D107 폐기 — 서버·PC·앱).
> 사용자 지시 "PC 에서 코치가 1개의 운동에서 SWEAT 에서 A세션 B세션 C세션 나눠서 운동을 설정했는데 폰에는 3개의 운동으로
> 표시 … 60분 운동에서 A세션때 15분 B세션때 20분 이런식으로 사람들이 보기 쉬우라는 거지. 다른 운동이 아님" → "파트 느낌
> SSOT 에 잘 기록해두고 API 일원화 및 이음새 문제없도록 단단히 못박고, 작업시작".**
>
> - **뜻**: 파트 = 같은 수업(그날 × 수업 종류) **한 프로그램 안의** 순서 있는 구간 (A 파트 15분 · B 파트 20분 · C 파트 25분).
>   파트는 다른 운동이 아니다 — 회원 카드 **한 장** 안에 A·B·C 가 시간과 함께 세로로 선다. D89 의 "세션 = 수업 시간에 붙는
>   글자 · 세션마다 다른 글" 은 폐기 — 그 모델로는 60분 안의 A·B·C 를 표현할 수 없었고, 프로드 실측(9/1·9/3)에서 코치가 A 를
>   고르자 10시 수업이 통째로 'SWEAT · A 세션' 이 됐으며 19:30 공통 예약자는 그 글에 완료를 못 눌렀다(게이트가 세션까지 맞췄다).
> - **정본 단위 = (날짜 × 수업 종류) 한 글** (D89 이전으로 복귀). 수업(class_sessions)·반복 시간표(class_schedule_rules)에는
>   파트 개념이 없다. `class_sessions.variant`·`class_schedule_rules.variant`·`gym_wod_posts.variant` 세 컬럼은 **휴면**
>   (읽지도 쓰지도 않는다 — 표는 남긴다, 규칙 5). 부팅 마이그레이션 `models/base.py _migrate_parts_d109` 가 수업·규칙 variant 를
>   NULL 로, 게시물 variant 는 같은 (체육관·날짜·종류)에 다른 글이 없을 때만 NULL 로 내리고 본문 첫 줄을 종류 이름으로 다시
>   그린다(옛 'SWEAT · B 세션' 첫 줄 제거). 겹치는 글은 손대지 않는다(앱은 종류당 첫 글만 보인다).
> - **정의 = `services/program_lines.py` 한 곳** (6-b): `MAX_PARTS`(8) · `part_label(i)`('A'…'Z') · `part_title(part, single)`
>   — 머리줄 `A 파트 · 15분 · AMRAP · 3라운드 · 캡 12분` (파트 하나뿐이면 라벨 없이 `15분 · AMRAP · 캡 12분`, 아무것도 없으면 '') ·
>   `render_program_content(title, parts, memo)` · `api_rounds(post)`(API 용 — 저장 구조에 `title`·`lines`(동작 줄) 렌더 첨부) ·
>   `normalize_program`(파트 목록 검증 — `duration_min` 1~240 또는 없음, 동작 없는 파트는 버린다, 전부 비면 None, 파트 수 초과·
>   형식 오류는 ValueError → 400 `INVALID_PROGRAM`) · `apply_program`. PC·앱은 라벨·머리줄·동작 줄을 **조립하지 않는다**.
> - **저장** `gym_wod_posts.rounds_data` = 파트 목록 `[{label, duration_min, wod_type, rounds, time_cap_sec, content(메모 —
>   [0] 에만, 옛 자리 그대로), movements}]`. 게시물 `wod_type`·`rounds`·`time_cap_sec` 는 파트 하나면 그 파트 값(종전과 같음),
>   둘 이상이면 `custom`·NULL·NULL (전체를 대표하는 종류가 없다 — 카드 머리에 종류를 안 적는다). 옛 글(한 라운드, 파트 필드
>   없음)은 파트 하나로 읽힌다 — 데이터 변환 없음.
> - **API (계약 — 세 면이 같은 것을 본다)**:
>   - program 객체 (PC → 서버 · 수업 POST/PATCH `program` · 게시 POST/PATCH `program`):
>     `{"parts":[{"wod_type","rounds","time_cap_min","duration_min","movements":[{"movement_id","reps","load_kg"}]}]}`.
>     종전 평평한 꼴(`{wod_type, rounds, time_cap_min, movements}`)은 파트 하나로 읽는다(어댑터 1곳 `normalize_program`).
>   - 게시물 읽기 (회원 `GET /gyms/<id>/wods` · admin wod-posts GET `program`): `rounds_data[]` 항목 = `{label, title, duration_min,
>     wod_type, rounds, time_cap_sec, lines[], content, movements[]}` (`title`·`lines` 는 읽을 때 `api_rounds` 가 붙인다 — 저장하지
>     않는다) + 게시물 `memo`(= `stored_memo`). `display_name` = 수업 종류 이름. `variant`·`variant_label` 키 **삭제**.
>     admin `program` = `{parts:[{wod_type, rounds, time_cap_min, duration_min, movements:[{movement_id, name, unit, reps, load_kg}]}], memo}`.
>   - `GET /admin/program-meta` 에 `parts: {max, labels:["A 파트", …]}` — PC 편집기 파트 머리 글자 (PC 는 'A 파트' 를 조립하지 않는다).
>   - 수업 직렬화 `display_title` = `title` (키는 유지 — 앱·PC 가 읽는다). `variant`·`variant_label` 키 삭제, POST/PATCH `variant`
>     무시. `GET /admin/gyms/<id>/program-variants` **삭제**. class-rules 응답 `variant_options` 삭제, `variant` 무시. 완료
>     게이트(`completion_gate`)·`first_class_at` 은 (날짜 × 종류) 만 본다. 쪽지·SSE 수업명 = `title`.
> - **PC**: 수업 등록·수정 모달의 '세션' 칩 삭제, 게시 모달의 '세션' 셀렉트 삭제, 수업 종류 시간표 행의 '세션' 셀렉트 삭제,
>   D107 세션 이동 409 처리 삭제. 운동 편집기(`static/program_editor.js`)가 **파트 단위**가 된다 — 파트마다 머리 [A 파트 · 시간(분) ·
>   종류 · 라운드 · 타임캡] + 동작 줄, '+ 파트 추가' / 파트 삭제 / 파트 순서. `getValue()` = `{parts:[…]}` 또는 null(동작 0).
>   `setValue` 는 `{parts}` 와 평평한 옛 꼴 둘 다 받는다. 프리필은 `GET wod-posts?date=` 의 (template_id) 글 한 곳(`_dayPostFor`).
> - **앱**: 카드 한 장 = 수업 종류. 파트가 둘 이상이면 카드 머리에 종류·캡·라운드를 적지 않고, 본문은 파트마다 서버 `title`
>   (섹션 라벨) + `lines`(동작 줄) 세로, 끝에 `memo`. 파트 하나면 종전대로 `content`. 프로그램 칸 중복 판정 = `templateId` 하나
>   (`visibleProgram`). `GymWodPost.variant/variantLabel`·`ClassSessionDto.variant/variantLabel` 삭제(`displayName`·`displayTitle`
>   유지). 상세 화면 동작 카드 라벨 = 서버 `title`. 완료 시트 동작 목록 = 전 파트 합산(종전 flatten 그대로).
> - **게이트**: 서버 `tests/test_program_parts_d109.py`(정규화·저장·렌더·API 키·마이그레이션·완료 게이트·수업 직렬화) +
>   `tests/test_ssot_program_lint.py`(`… 파트"` 조립·`variant` 재사용 감지, 정본 마커 갱신) · 앱 `test/golden/program_order_test.dart`
>   (같은 종류 = 카드 하나 · 파트 세로) + 골든 재생성 · PC `design/lint.py`.
> - **폐기**: D89 세션(수업·게시물 variant, `display_title(title, variant)`), D98 세션 칩·규칙 variant·`free_items`, D107 세션 이동
>   409 `VARIANT_MOVE_DROPS_POST`. 용어: `docs/GLOSSARY.md` '세션·공통' 행 → **파트** (코드 `part`, 표시 'A 파트').

> **D106 (2026-08-30 집행) — 회귀 검증 1회차(PC playwright + 에뮬레이터 로컬 빌드, V1~V8 전부 통과)에서 나온 미비 18건 중 범위 안 결함 수정
> (사용자 "회귀검증 2회 시작. pc에뮬레이터로" · "2번 이상 검증하고 보고, 미비하면 솔직히, 있는 기능 끝까지").**
>
> - **이원화·라벨 사본 제거**: 계약 발급 모달 종료일 +30(JS) → 회원권과 같은 `membership-plans/<id>/period` 창구(+29) · 회원권 표 '이용중' 사전
>   (만료된 active 행에도 표시) → 서버 `_membership.membership_status_code/label`(해지·환불·만료 > 종료일 경과 > 해지 예정 > 시작 전 > 정지 중 >
>   정지 예정 > 이용중) 을 코치 회원권 탭·명단·회원 앱 세 창구에 실음, 린트 `test_ssot_membership_label_lint` · 이름 없는 회원 표시 =
>   서버 `admin.member_display_name`("이름 미입력 (앱 가입 · 해시8)") 으로 드롭다운·계약 목록 세 창구 동일.
> - **서버 결함**: 수업 세션 공통→D 변경 시 D 게시물이 안 생기던 것 → `_carry_program_on_variant_move`(양방향 테스트) · 수업 등록·수정이 SSE
>   `wod.posted` 를 안 쏴 앱 프로그램 칸이 재시작 전엔 안 바뀌던 것 · 결과 저장 응답 `attendance_added`(정본 `attended_on`) — 앱 '출석 +1' 은
>   true 일 때만 · 계약번호·발급일을 `contracts/pdf_generator.contract_auto_variables` 한 곳이 채워 앱 본문에도 · 요금제 기간 비우면 30 으로
>   저장되던 것 → 횟수권은 null, 기간제는 400.
> - **PC**: 업적 빌더 '생일' 전환 시 67px 밀림 → 자리 유지(`is-invisible`) · 인라인 display/visibility 요소 96 → 0(출처는 공용 `pictogram.js`
>   배지 48개 + `_layout.html` 확인 오버레이 — 클래스로) · 발급 직후 회원 상세 헤더 재조회.
> - **앱**: 히스토리 상세 '동작별 기록' 칸(서버 `movements[].line` 을 안 그리던 결함) · 늦은 취소 토스트 하이픈 U+2011(ㅠ‑ㅠ 줄바꿈 방지).
>   골든 hist_04·snack_05·state_30 재생성.
> - **재현 실패 2(솔직히)**: 계약 수정 모달 자동 닫힘(코드에 주기 재렌더 없음 — 1회차 중 다른 fork 의 5060 점유로 백엔드가 끊겨 로그인으로 튕긴
>   것이 유력) · 동작 칸 포커스 0건(200ms 에 60건). **의도로 판정**: 쪽지함 상단 '공지' 카드(D81 원문 "쪽지함 핀 카드는 그대로").
> - **미검증**: 서명 합성 PDF·해시는 로컬 GTK 부재로 HTML 폴백 — 프로드 weasyprint 조건 미검증. 회원권 표 '수정·해지' 링크 노출은 아직 PC 판정.
> - 서버 665 passed · 앱 232 passed · 골든 84장. 2회차 = 같은 V1~V8 + 수정분 R1~R5 실물 재검증.

> **D105 (2026-08-30 집행) — 회원 활동 요약: 코치 회원 파악용 (사용자 "이 회원이 얼마나 다녔구나 무슨 수업시간에 자주 오는구나 …
> 회원 리스트 어떤 화면에서"). 4기둥 판정 = 받침(회원 명단)의 코치용 표시면, 사용자 명시.**
>
> - 기록 잔존 점검: 예약(`class_reservations`)·취소 원장·대기/승격·출석(`gym_attendances`, 하루 1회)·결제(`gym_payments`)·회원권·수업 기록·
>   쪽지 전부 KST 시각으로 남는다. 휴강(코치 사유) 취소는 원장에 안 남음(D99 설계). 앱 열람·로그인은 저장 안 함(대상 아님).
> - **정본 하나** `api/_metrics.py member_activity_summary()`(단건) · `member_activity_lines_bulk()`(명단, 2쿼리) — 같은 `_compose_activity`.
>   필드: 출석 일수(`attendance_day()` KST distinct)·최근 30일·마지막 출석·최근 90일 수강(자리 잡은 예약, 취소·노쇼 제외)·자주 듣는 수업 5·
>   Track·**자주 오는 시간(시각 분포)**·문장 `activity_line`("출석 42일 · 최근 30일 8일 · 마지막 08-28 · 자주 오는 시간 06시 12회 · 19시 5회").
>   노쇼·늦은 취소 수는 `_membership.session_summary` 를 부른다(다시 세지 않음).
> - 창구: `GET /admin/members/<m>/lessons`(PC 상세 수강 이력 탭 — inline 쿼리 4개 제거) · `GET /admin/gyms/<g>/members`(행 `activity_line`,
>   `last_class_date` 원천 = `last_reserved_class_at_bulk`). PC `member_detail.html` 헤더 한 줄 + 탭 상단 블록. **'최근 90일 출석' 이라던
>   라벨은 실은 수업 수 → '최근 90일 수강' 으로 정정.** 앱 코치 셸에는 회원 명단 화면이 없어 앱 표시 없음(PC 가 주). 목록 표 열은 안 늘림.
> - 게이트 = `test_ssot_metrics_lint.py` FACTS["회원 활동 요약"] · `test_ssot_agreement.py` WINDOWS 2건 · `tests/test_member_activity_summary.py` 4건.
> - 주의: 90일 창이 `now-90d`(시각) → `오늘-90일 자정` 으로 통일돼 경계 하루가 종전과 다를 수 있다.

> **D104 (2026-08-30 집행) — 회원권 생애주기 검증·정본화 (사용자 "회원권 설정에서 만든 회원권 가상 회원에서 적용 … 시작일 종료일 …
> 일시정지 기간 동안 회원권의 기간").**
>
> - `tests/test_membership_lifecycle.py` 13건 — 코치 회원권 탭 · 코치 명단 · 회원 앱 카드 **세 창구를 매번 대조**. 30일권 종료 = 시작 포함
>   +29 · 10회권은 종료일 필수 · 미래 시작 · 이어서 시작(`next_start_date`) · 정지(+7 → 만료 +7, 정지 중 잠금·창 밖 OK) · 정지 예정 ·
>   정지 중 해제(실제 쉰 날만) · 정지 창이 만료 넘음 · 겹치는 정지 409 · 만료.
> - **잡은 결함**: PC 폼 두 곳이 종료일을 +29 / +30 으로 **하루 다르게** 계산 · 만료 뒤 정지가 허용돼 **만료된 권이 되살아남** · 기간 없는 종류에
>   6개월을 지어내던 JS.
> - **정본** `api/_membership.py`: `is_paused_on` · `is_pause_scheduled_on` · `membership_dday` · `plan_period_end`(시작 포함 +days−1) ·
>   `membership_calendar_fields`. `admin.py` 정지 판정 inline 2곳·`_calc_dday` → 정본, 발급 시 종료일 비우면 서버가 종류 기간으로 확정,
>   정지는 기간 밖 400. **신설** `GET /admin/membership-plans/<id>/period?start=` (PC 두 폼의 종료일 창구). 회원 앱 `profile.py` 에
>   `is_paused·is_pause_scheduled·d_day·d_day_label·is_current`(대표권 = `governing_membership`), 수업 목록에 `membership_ok`(= `pick_membership`).
> - 앱: `membership.dart` 정지/D-day/coversDay Dart 계산 삭제 → 서버 필드, `gym_state.currentMembership` = 서버 `is_current`, 주간 보드
>   '회원권 필요' 배지 = 수업별 `membership_ok`. `ssot_lint_test.dart` 재발 패턴 3. 골든 PNG 변경 0.
> - 게이트 = `test_ssot_metrics_lint.py` "회원권 정지"(canonical) · `test_ssot_agreement.py` "회원권 정지" 창구 3곳.
> - 남은 것(범위 밖): 연장 모달이 시작일 변경 시 종료일 재계산 안 함(종전) · 두 번째 정지가 첫 창을 덮어씀(행에 창 1개) · 락커 D-day·환불 미리보기 JS 는 아직 폰/PC 계산.

> **D103 (2026-08-30 집행) — 포인트 적립 규칙 트리거 매트릭스 + 이원화 3곳 정리 (사용자 "트리거 별 … 다 제대로 작동하는지 10개 이상 테스트").**
>
> - `tests/test_reward_triggers_matrix.py` 17건: 수업 기록×기간 N회(매주·매달 경계·날짜당 1회) · 동작 지정(게시물 동작 / D94 회원 동작별 값 우선 ·
>   불일치 무발동) · 연속·누적 경계 · PR 실발동 · 출석 훅 · 재저장/스윕 이중 지급 없음 · 비활성→활성 · 타 체육관 · 미소급 · 업적·쪽지·사유
>   한 문자열 · 카드 진행 = 엔진 수 · meta = 엔진 상수 · 미리보기 = 저장 문장 · 잘못된 조합 6종 400.
> - **이원화 제거**: 앱 도전 카드 n/N 을 `api/reward_rules.py member_reward_progress` 가 엔진 내부 도우미로 **복제 계산** → 엔진
>   `services/reward_engine.py progress_count()·target_of()` 하나로(지급 판정과 같은 함수). 라벨·허용값 표(`TRIGGER_KO` 등)도 엔진 한 곳.
>   PC 업적 빌더의 JS 표·정적 옵션·미리보기 문장 조립·클라이언트 검증 4건 → **`GET /admin/reward-meta`** + **`POST …/reward-rules/preview`**
>   (생성과 같은 `_validate`+`_sentence`) 로 서버가 주고 PC 는 그리기만. 인라인 `style.display` 토글 11곳 → `is-hidden/is-invisible` 클래스.
> - 게이트 = `tests/test_ssot_reward_lint.py` 4건(라벨 재정의·엔진 내부 재계산·PC 표/문법/인라인 style/정적 옵션·심은 위반 자기 검사).
> - **미비(솔직히)**: 사용자 원문의 "기록 이내 / 기록 이상"(무게·시간 임계값) 트리거는 **제품에 없다** — 있는 것은 PR·동작 포함·횟수·연속·누적.
>   지시("기능 추가 금지")대로 만들지 않음, 별도 결정 사항. 앱은 포인트 잔액만(사유 내역 화면 없음, 현 사양). PC 픽토그램 라벨 55종은 아직 JS.

> **D102 (2026-08-30 집행) — 전자계약서 보기·수정·회원 서명 점검 (사용자 "내용보기 하면 보이는데 수정은 어떻게 … 회원이 어디서 어떻게 싸인").**
>
> - **회원 서명 창구는 이미 있었다** — 내 정보 → 전자계약서 → 상세(sent→viewed) → 서명 패드(CustomPaint→PNG) → `POST /member/contracts/<id>/sign`
>   → 서명 합성 PDF·SHA-256 → PC SSE `contract_signed`·'서명 완료'·다운로드 → QR 검증 `/verify`. 이식 불필요.
> - **잡은 결함 4**: PC 수정(PATCH) 뒤 서명 때까지 '보기' 가 "PDF 파일 없음"(초안 무효화만) → 발급과 같은 방식으로 **초안 재생성** ·
>   회원이 발급 사실을 모름(PC SSE 만) → 알림 항목 `contract` '계약서 도착 안내' 신설, 발급 즉시 쪽지 · 상태 라벨·권한이 **5곳 사본**
>   ('발송'·'발송·대기'·'서명 대기'·'발송됨') → 서버 `api/contracts.py contract_flags()`(status_label·signable·editable·cancellable·downloadable)
>   하나, 5곳 사전 폐기 · 앱 서명 패드 '제출' busy 스왑 밀림 → 버튼 자리 그대로.
> - 게이트 = `tests/test_contract_flow_d102.py` 5건(회원 sign·PATCH 잠금 — 종전 0건) · `tests/test_ssot_contract_lint.py`(서버 라벨 1곳·PC 사전 재정의 금지) ·
>   앱 `ssot_lint_test.dart` D102 패턴. 골든 `member_28_contract_detail_signed` · `member_29_contract_sign_pad` (84장).
> - 미비: PDF 재생성은 스텁 검증(로컬 GTK 없으면 실제 렌더는 발급과 같은 조건으로 경고) · 옛 초안 파일 미삭제(발급과 동일 관행) ·
>   수정 가능 변수 목록은 PC·앱 각자 필터(서버가 목록을 안 내려줌 — 작음).

> **D101 (2026-08-30 집행) — 동작 사전 연관도순 검색: 코치 PC 동작 고르기 검색창 + "백스쿼트" 띄어쓰기 무시 (사용자 "운동목록을 만들고
> 쌤이 수업 등록할때도 불러오기 기능 통해서 … 연관도순으로 빨리 검색 … 백스쿼트라고 입력을 하게되면").**
>
> - **이미 있던 것 확인**: 동작 사전 60종(D88) · 코치가 사전에서 고른 동작이 `movement_id` 로 저장돼 회원 앱 수업 내용에 게시 · 회원 앱 프로그램 칸
>   (오늘 운동 전부, D78) · 히스토리 검색(D95)·상세(D91/D94, 보기 전용). 앱 변경 0.
> - **갭 1 — 순위 정본 한 곳** (`services/history_search.py`): `match_kind` 가 칸 그대로 못 맞추면 **띄어쓰기 뺀 글자**로 한 번 더 본다
>   ('백스쿼트'='백 스쿼트', 'backsquat'='Back Squat') — 앱 히스토리 검색과 PC 검색이 같이 좋아진다. `rank_movements(query, rows)` 신설
>   (영문 3·한글 3·세부분류 1·분류 라벨 1, 토큰 AND, 동점은 영문 이름순). `GET /api/v1/admin/movement-library?q=` 가 이 순서로 내려준다.
> - **갭 2 — PC 검색창** (`web/hyphen-admin/static/program_editor.js`): 줄마다 `<select>` → 검색 상자(포커스 = 전체 사전, 입력 = 서버 `?q=`
>   결과 순서 그대로, ↑↓/Enter/Esc, 검색어 캐시). 값은 종전 hidden `movement_id` 라 저장 계약 불변 — 수업 등록·수정·게시 모달 셋 다 같은 모듈.
> - 게이트 = `tests/test_ssot_history_lint.py::test_search_ranking_is_defined_only_in_history_search`(검색 함수 재정의 금지 + PC 편집기가
>   `?q=` 를 쓰고 자체 sort/filter 없음) · `tests/test_movement_library_d88.py` 2건(순위·띄어쓰기 무시).
> - **PC 실물 확인(로컬)**: 수업 등록 모달 → 동작 칸 포커스 = 사전 전체 → '백스쿼트' = Back Squat 1건 → Enter = 단위 '회'·무게 칸 →
>   저장 → 게시물 본문 `Back Squat 5-5-5회 · 60kg` → 수업 내용 페이지 표시. 업적 빌더의 동작 목록(`settings_achievements.html`)은 검색 없음 — 범위 밖.

> **D100 (2026-08-30 집행) — 늦은 취소 토스트 + 코치 전송 (사용자 "노쇼규칙에 의해서 또 취소하려고 하면 … 토스트바로:
> 'N달, N회째 레이트 캔슬 입니다. 주의부탁드려요 ㅠ-ㅠ / 이 내용은 코치에게 전송됩니다'").**
>
> - **문장·횟수는 서버 한 곳** (`api/_membership.py`): `LATE_CANCEL_TOAST`("{M}월, {k}회째 레이트 캔슬입니다. 주의 부탁드려요 ㅠ-ㅠ\n이 내용은
>   코치에게 전송됩니다.") · `policy_cancel_count_in_month()`(원장 `class_reservation_cancels` 를 **회원 × KST 달** 로 셈 — 정책에 걸린 모든
>   선, 경고만인 선 포함 · 이번 것 포함) · `late_cancel_notice()` → `{month, nth, toast}`, 제때 취소는 None. 취소 응답
>   (`DELETE /member/reservations/<id>`) 에 `notice` 로 내려가고 앱은 그대로 띄운다 — 달·횟수를 세지 않는다 (규칙 6).
> - **"코치에게 전송됩니다" 는 사실이다**: `api/notifications/note.py send_coach_note()`(회원 쪽지의 거울, `auto_kind='notify:late_cancel'`,
>   SSE `note.new`) 가 회원→코치 쪽지 자리에 자동 쪽지 1통 — `COACH_LATE_CANCEL_LINE` "{회원명} — {M}월 {k}회째 늦은 취소 · {수업명} ({일시})".
>   PC 코치 쪽지함 그 회원 스레드에 안읽음으로 보인다. 회원 앱 '코치' 칸(사람 대화만)에는 안 보이도록 `coach_note.build_messages/build_threads`
>   가 **보낸 쪽 자동 쪽지도** 거른다 (종전엔 받은 쪽만).
> - **앱** (`class_flows.dart showCancelResult`): 취소 성공 뒤 `notice` 가 있으면 D86 골격의 토스트 — 첫 줄 굵게 + 나머지 줄 + 차감 문구(`message`),
>   슬픈 하이피, 폭죽 없음. 없으면 종전 한 줄. 골든 `snack_05_late_cancel_toast` · `state_30_late_cancel_done`(실흐름).
> - 게이트 = `tests/test_late_cancel_toast_d100.py`(같은 달 1→2회째 · 문장 정확일치 · 코치 쪽지 발신/수신/본문 · 제때 취소 None·통보 없음 ·
>   달 바뀌면 1회째 · 회원 코치 칸 숨김/PC 노출).
> - 같은 날 **완료 저장 토스트** (사용자 "'수업을 저장중이에요' 로딩바 두두둥 → '하이피가 예____ 화이팅!!!!'"): `wod_result_sheet.dart _submit` —
>   저장 시작 즉시 `HkSnack.progress('수업을 저장 중이에요')`(가로 로딩바), 응답 오면 `dismiss` → 웃는 **하이피**(마스코트 이름, 사용자 원문)
>   "예____ 화이팅!!!!" + '저장됨 · 출석 +1' + 서버 비교 문구, `is_pr` 면 폭죽. 저장 버튼은 자리 그대로 busy — 누르는 순간 고지 줄이
>   30px 튀던 밀림 0 (`test/golden/stability_result_sheet_test.dart`). 골든 `snack_06_saving` · `snack_07_saved_fighting` · `state_29_result_sheet_saving`.

> **D99 (2026-08-30 집행) — 코치 사유 취소 = 예약 전부 리셋 + 횟수권 반환, 휴강은 코치가 다시 열기 전까지 휴강 (사용자
> "휴강처리하거나 그날 수업을 취소하거나 — 코치의 이유로 사라지게 되면 예약 모두 리셋되고 횟수권도 돌려주고").**
>
> - **리셋·반환은 이미 그대로였다** (`admin_cancel_class` — 예약 전부 cancelled · 늦은 취소/시한 후 취소 표시 해제 · `recompute_session_charges`
>   로 횟수 0 · 예약자 전원 쪽지). 이번에 게이트로 못박음.
> - **잡은 결함 — 휴강이 몰래 풀림**: 반복 규칙을 고치면(정원·세션) `_prune_future_slots` 가 휴강 슬롯을 '예약 0건' 으로 보고 지웠고,
>   `materialize_rules` 가 같은 시각에 새 open 수업을 만들었다. 지워질 때 취소된 예약 줄도 CASCADE 로 사라져 사건 기록이 없어졌다(규칙 6).
>   이제 cancelled 슬롯은 is_overridden 과 같은 급으로 **보존** — 규칙 수정·삭제 모두. 되살리는 창구는 없다(코치가 새 수업을 만든다).
> - 코치 사유로 수업이 사라지는 경로는 휴강(취소) 하나뿐임을 확인 — 수업 DELETE API 없음 · 규칙 수정/삭제는 살아 있는 예약이 있는 슬롯을
>   건드리지 않음 · 수업 종류 삭제는 soft 라 수업에 영향 없음.
> - 게이트 = `tests/test_class_cancel_reset_d99.py`(휴강 → 예약 리셋·표시 해제·횟수 0 · 규칙 정원/세션 수정 후 휴강 슬롯·취소 줄 보존·
>   같은 시각 open 없음 · 규칙 삭제 후 보존).

> **D98 (2026-08-30 집행) — 세션 칩을 남은 두 창에 붙임 (사용자 "ㅇㅇ 붙여"): 반복 시간표 규칙 · PC 수업 내용 게시 모달.**
>
> - **반복 시간표**: `class_schedule_rules.variant`(NULL = 공통, 종류 없는 규칙은 무시). 수업 안내 → 수업 종류 수정 → 매주 시간표
>   행마다 [세션] 선택(공통·A~E — 선택지·라벨은 `GET /admin/gyms/<g>/class-rules` 의 `variant_options`, PC 는 조립하지 않는다).
>   규칙이 실체화하는 수업이 세션을 달고 나오고(`materialize_rules`), 규칙의 세션을 바꾸면 미래 무예약·미수정 수업도 새 세션을 단다
>   (같은 시각이라 남겨 둔 것 포함). 같은 요일·시각이라도 세션이 다르면 다른 줄(AWAKE 06:00 A · 06:00 B). 옛 세션 키의 게시물은 지우지 않는다.
>   부수 결함: `update_rule` 이 prune 뒤 flush 없이 재실체화해 **같은 시각으로 바꾸면 방금 지운 슬롯을 '있는 것' 으로 보고 다시
>   만들지 않던** 잠복 결함을 함께 잡았다 (SessionLocal autoflush=False).
> - **게시 모달** (`wod.html`): [수업 종류 (선택)] × [세션] — 종류를 고르면 이 글은 세션 자동 게시와 **같은 키**(날짜 × 종류 × 세션)의
>   정본이라 이미 있으면 새 글이 아니라 그 글을 고친다(`admin_create_wod_post` upsert, 응답 `created`). 제목 줄 = 'AWAKE · A 세션'.
>   세션 선택지 = `program-variants` 의 `items`(있는 것) + **`free_items`**(안 쓴 글자, 라벨째 — D98 신설). 종류 없으면 종전 자유 게시.
>   수정(PATCH)은 종류·세션 변경을 받고 다른 글의 키면 409 `DUPLICATE_POST`; **종류 있는 글의 제목 줄을 지우던 결함**(title="")도
>   함께 잡았다. 목록에 `display_name`.
> - 게이트 = `tests/test_session_chips_d98.py`(규칙 세션 실체화·변경·무종류 무시 · 게시 upsert·B 별도·free_items·PATCH 제목 유지·409·
>   타 체육관 종류 400 · 자유 게시). PC 실검증(로컬): 수업 안내 시간표 행 세션 선택 · 게시 모달 종류/세션 선택 → 게시.

> **D97 (2026-08-30 집행) — 알림 항목 '늦은 취소 · 노쇼 안내' (사용자 "알림 항목 추가하고").**
> `NOTE_TEMPLATES["noshow"]`(기본 on, 문구 수정 가능) — 노쇼 정책에 걸린 취소를 한 즉시(`api/classes.py cancel_reservation`)와
> 코치가 노쇼로 찍은 즉시(`admin_patch_reservation_status`) 회원 앱 쪽지 `{회원명}님, {수업명} ({일시}) — {사유}. {조치}`.
> 조치 문장 정본 = `_membership.policy_outcome`(경고로 기록 / 횟수권 N회 차감 / 이번은 면제). 제때 취소·되돌리기는 안 보낸다.
> 게이트 = `test_noshow_policy_d96.py`(쪽지 본문 4건) · `test_notification_note_gates.py`(항목 목록).
> **브라우저 실검증(로컬 PC)**: 알림 탭에 항목이 뜨고, 노쇼 정책 탭에서 규칙 추가 → 1시간 전 경고 → 저장 → 새로고침 후 유지 확인.
> 그 과정에서 **관리자 프록시가 PUT 을 막아 저장이 405** 였던 결함을 잡아 고쳤다 (`web/hyphen-admin/app.py proxy_passthrough`).

> **D96 (2026-08-30 집행) — 노쇼 정책: 코치가 PC 알림 설정 → '노쇼 정책' 탭에서 늦은 취소·노쇼의 조치를 정한다.
> 사용자 지시 "알림설정에서 탭 하나 더 만들어서 노쇼정책이란 탭 … 수업 1시간 전(선택), 취소하면 경고(선택) … 60분 전 30분 전
> 10분 전 등, 경고·1회 차감·2회 차감".**
>
> - **표 `gym_noshow_policies`** — 행 = 규칙: `kind`(cancel·no_show) · `minutes_before`(cancel: 10·20·30·60·120·180·1440 중 하나) ·
>   `penalty_sessions`(0 = 경고만, 1~5 = 횟수권 N회 차감) · `free_count`(회원권당 면제 0~5). 행이 없으면 **D57 그대로**
>   (`default_policies` — 20분 전 이후 취소 1회 차감·면제 1 / 노쇼 1회 차감·면제 1). **정의 정본 = `api/_membership.py`**:
>   `gym_policies` · `cancel_policy_for`(지난 선 중 **가장 임박한 것** — 1시간 전 경고 + 20분 전 1회 차감이면 30분 전 취소 = 경고,
>   10분 전 = 차감) · `no_show_policy` · `policy_label`('수업 1시간 전 이후 취소 → 경고') · `cancel_notice`(앱 다이얼로그 한 줄) ·
>   `cancel_message`(취소 응답 스낵바) · `minutes_label`(60 → '1시간 전', 1440 → '1일 전').
> - **취소 순간의 스냅샷** — `class_reservation_cancels.policy_minutes/policy_penalty/policy_free`(어느 선·조치·면제였나) +
>   `charged_sessions`(예약 줄·원장 둘 다 — 2회 차감이 가능해져 bool 만으론 못 센다, `session_charged` 는 >0 과 같은 뜻으로 유지).
>   **쓴 횟수 = `charged_count` 하나** = 예약 줄 합 + 원장 합 — 잔여·예약 게이트·회원권 요약이 같은 수 (종전엔 잔여는 줄만, 요약은
>   원장까지 세어 갈릴 수 있었다). 정책을 나중에 바꿔도 지난 취소는 스냅샷대로 다시 센다(사실은 쌓고 덮어쓰지 않는다). 옛 늦은 취소
>   행(스냅샷 없음)은 종전 규칙으로 굳혔다(마이그레이션 + recompute 폴백). 노쇼는 그 체육관의 no_show 규칙(2회 차감이면 잔여 2 감소).
> - **API**: `GET/PUT /api/v1/admin/gyms/<g>/noshow-policy`(행 전체 교체 — 허용 분값·선 중복·노쇼 1행·범위 검증, 빈 목록 = 기본으로) ·
>   **`GET /api/v1/member/reservations/<rid>/cancel-preview`** — 회원 앱 취소 확인 다이얼로그의 안내 한 줄을 **누르는 순간 서버가 판정**
>   (종전엔 앱이 '20분' 상수 `kLateCancelMinutes` 로 스스로 판정 — 6-b 위반, 폐기).
> - **PC**: `notifications.html` 상단 탭 [알림 | 노쇼 정책] — 취소 규칙 행(수업 N분 전 이후 취소하면 → 경고/N회 차감 → 면제) + 노쇼 규칙 한 줄
>   + [취소 규칙 추가]·[저장]·[기본 규칙으로], 현재 적용 규칙 한 줄 미리보기. 라벨·선택지는 서버 `options`·`label` 그대로.
>   `settings_plans.html` 의 하드코딩 문구('20분 전 …')는 이 탭으로 안내.
> - **앱**: `ClassesRepository.cancelPreview` → `class_flows.cancelClassFlow` 가 다이얼로그 전에 문구를 받아 그대로 (실패해도 취소는 막지 않는다).
>   골든 `state_22`·`state_23`·`cancel_dialog_notice_test` 는 서버 문구를 가짜로. 게이트 = `ssot_lint_test.dart`(`kLateCancelMinutes`·`isLateCancel(` 금지).
> - **게이트**: `tests/test_noshow_policy_d96.py`(기본값 = D57 · PUT 검증 · 경고 선/차감 선 판정과 미리보기·응답 문구·잔여 · 노쇼 2회 차감 =
>   잔여·요약 같은 수 · 정책 변경 후 스냅샷 유지). 기존 `test_session_pass`·`test_reservation_policy`·왕복 검사 전부 그대로 통과.

> **D95 (2026-08-30 집행) — 히스토리 검색을 서버가 한다: `GET /api/v1/history/wod?q=` 연관도순 + 동작 사전 번호 일치 (사용자 "일단 이것부터").**
>
> - **정의 = `services/history_search.py` 하나** (D84 폰 순위 규칙을 그대로 옮김: 낱말 AND · 칸 전체 일치 10/앞부분 6/단어 앞 4/포함 2 ·
>   제목 3·요약 3·종류 2·날짜 2·본문 1·메모 1·난도 1·점수 1·동작 이름 1 · 같은 점수면 최근순) + **동작 번호 일치 = 제목 전체 일치와
>   같은 무게**: 낱말이 동작 사전(`movement_library` name_en·name_ko)에 맞으면 그 번호가 든 기록(회원이 적은 동작별 값 → 없으면 그날
>   운동)을 글자 표기와 무관하게 잡는다 — '스쿼트'·'squat' 둘 다 Back Squat. 검색 때는 회원 기록 전부(상한 1000)를 세운 뒤 offset/limit.
>   `meta.query`·`meta.matched` 로 되돌려 준다.
> - **앱**: `history_search.dart`·`test/history_search_test.dart` 삭제 — 폰은 300ms 디바운스 뒤 `?q=` 로 한 번 묻고 받은 순서 그대로
>   그린다. `ssot_lint_test.dart` 가 `rankHistory(`·`scoreHistoryItem(` 부활을 막는다. 골든 `hist_03` 은 서버가 세워 준 결과를 가짜로.
> - **게이트**: e2e `test_13`(burpee·run·한글 이름·AND·종류 라벨·세션 이름·검색어 없으면 최근순).

> **D94 (2026-08-30 집행) — 동작별 완료 값: 회원이 그날 운동의 동작마다 실제 한 횟수·무게·난도를 적고, 그 값이 히스토리·리워드 판정의
> 원천이 된다 (D88 2단계 잔여 해소). 사용자 지시 순서 "3 하고, 2 는 1일 1회, 다 하고 1".**
>
> - **표**: `gym_wod_result_movements`(result_id FK cascade · position · movement_id · name · unit · reps · load_kg · scaled) — 결과 하나에
>   동작 줄들, 재저장은 통째 교체. **정의 = `services/program_lines.py`**: `normalize_result_movements`(오늘 게시물의 동작 중에서만 —
>   id 또는 이름으로 맞춤, 없는 동작은 ValueError → 400 `INVALID_MOVEMENTS` 한국어 문구 · reps 는 목표와 같은 `_REPS_OK` · load ≥ 0 ·
>   최대 20 · 중복은 뒤 것 버림) · `result_movement_line`/`result_movements_summary`(본문 동작 줄과 **같은 렌더러** + ' SCALED') ·
>   `result_has_movement`(리워드 동작 조건 — **적은 값이 있으면 그것**, 없으면 게시물). 읽기 정본 = `api/_metrics.class_result_movements`.
> - **API**: `POST /gyms/<g>/wods/<post>/results` 가 `movements: [{movement_id|name, reps, load_kg, scaled}]` 를 받는다 — 키가 없으면
>   종전 값 유지(옛 앱), `[]` 면 지움. 피드 `my_result.movements`(프리필) · 히스토리 `movements[]`(각 줄 `line`) · **`summary` 는 적은 값이
>   있으면 그것**('Push-up 80회 SCALED'), 없으면 그날 운동 요약. `reward_engine` wod_log 동작 조건이 `result_has_movement` 를 쓴다.
> - **앱**: 완료 시트 '동작별 기록' — 동작마다 [한 횟수][무게 kg] 칸이 **코치가 정한 값으로 미리 채워져** 있고 다르게 했을 때만 고친다
>   (SCALED/RXD 칩 유지, 무게 칸은 코치 무게가 있거나 SCALED 일 때 — 자리는 항상 예약). 저장된 값이 있으면 같은 동작에 프리필
>   (`MyResultMovement`). 구 `_movesSummary`(앱이 메모 문장을 조립) 폐기 — 요약은 서버. `WodMovementItem.movementId/unit` 추가.
>   골든 `state_28_result_sheet_movements` 신규.
> - **게이트**: e2e `test_12`(오늘 동작만 · 히스토리 둘째 줄·상세·피드 프리필 · 없는 동작 400 · 키 없는 재저장 값 유지 · 빈 목록 삭제 ·
>   포인트 이중 지급 없음). strength 게시물은 최고 무게 한 값이 점수라 동작별 값을 보내지 않는다.

> **D93 (2026-08-30 집행) — 출석 = 하루 1회 (사용자 결정 "1일은 1회만 출석임").**
>
> - **정의 = `api/_metrics.py`**: `attendance_on(day)`(그날 필터 식) · `attended_on(s, member, gym, day)`(하루 1회 규칙의 **관문** — 출처
>   self/manual 불문) · `attended_member_count_on`/`attended_member_ids_on`(그날 출석 **인원** — 행이 아니라 사람). 쓰는 손 넷(회원 결과
>   저장 `api/gym.py` · 코치 명단 출석 `api/classes.py` · 코치 수기 추가 `api/admin.py` · 데모 시드)과 세는 창구 셋(통계 오늘 출석·7일
>   시리즈·홈 오늘 출석)이 전부 정본을 부른다 — 종전엔 같은 날짜 식이 일곱 자리에 각자 적혀 있었다.
> - **게이트**: `test_ssot_metrics_lint.py` FACTS["출석 (하루 1회)"](`func.date(GymAttendance.checked_at) ==` baseline 0) · e2e `test_11`
>   (회원 저장 뒤 코치가 명단에서 찍어도 행 1 · 수기 추가 409 · 통계 오늘 출석 1명).
> - 하루에 수업 여러 개를 완료해도 출석은 하루 하나 — 리워드 `attendance` 트리거도 날짜당 1 (종전 그대로).

> **D92 (2026-08-30 집행) — 홈 연속일도 서버 meta.streak_days · Streak Freeze 폐기 (사용자 지시 "3 하고").**
>
> - 홈 레벨 카드의 연속 기록일이 앱 계산(`_currentStreak`·`_uniqueDays` + 폰 로컬 Streak Freeze 보정)에서 **서버 `meta.streak_days`**
>   (`api/_metrics.class_streak_days` — 코치 명단과 같은 함수)로. `lib/core/streak_freeze.dart`·`test/streak_freeze_test.dart` 삭제,
>   `_GamificationBody` 는 `records` 를 더 받지 않는다(total·pr·streak 세 수만). 게이트 = 앱 `ssot_lint_test.dart`(`StreakFreeze`·
>   `_currentStreak(`·`_uniqueDays(` 금지). README 제거 대장 40.

> **D91 (2026-08-30 집행) — 히스토리 완전 통합: 히스토리 탭·검색·상세·XP·카탈로그 업적·코치 명단이 정본 `gym_wod_results` 를 직접
> 읽고 센다 (D90 거울 `wods` 쓰기 폐기). 사용자 지시 "완전 통합하고 어디에 무엇을 배선해 뒀는지 적어 두고 저장해 둬".**
>
> - **정의 = `api/_metrics.py` 한 곳** (대전제 6): `class_results_of`(회원 기기의 결과 행 전부, 게시물 join, 최근순) ·
>   `class_result_count` · `class_pr_count`(저장 시점 서버 판정 `is_pr`) · `class_result_times`/`class_result_days` ·
>   `class_streak_days`(오늘 또는 어제부터 연속 — 종전 코치 명단은 '가장 최근 기록일' 부터 세어 3주 전 연속이 지금도 보였다) ·
>   `class_result_stats_bulk`(명단용 1쿼리). 서버 안의 셈은 전부 이 함수를 부른다.
> - **API**: `GET /api/v1/history/wod` 가 결과 표를 직렬화한다 — 행 id = **결과 id**, `title`(본문 첫 줄 'AWAKE · A 세션') ·
>   `summary`(그날 운동 한 줄 — `program_lines.movement_summary`, 본문과 같은 렌더러) · `wod_type_label` · `kind`/`label`
>   (`wod_compare.result_kind_of`/`fmt_result_label` — '4:18'·'5R+3'·'40kg×5') · `is_pr` · `scale_level` · `notes`(회원 메모) ·
>   `content`. `meta` 에 **레벨 카드의 세 수**(total·pr_count·streak_days·last_at). `GET /history/wod/<result_id>` = 같은 줄 +
>   게시물(content·scale_guide·movements) + 완료한 수업(display_title). `POST /history/wod`·`DELETE` 는 폐기 — 결과 저장 창구는
>   `POST /gyms/<g>/wods/<post>/results` 하나. 엔진 시절 `wods` 행(D90 거울 행 포함)은 **읽지도 쓰지도 않는다**(휴면, 데이터 보존).
> - **업적·리워드**: `achievement_checker` 의 wod_count·pr_count·pr_category·season_wod·weekly_streak·comeback 이 정본 함수로
>   (device_hash 기준 — Profile 이 없는 앱 전용 회원도 평가된다: `_eval_trigger(session, device_hash, profile_id|None, …)`,
>   `check_and_unlock` profile_id None 허용, `/achievements/check` 가 Profile 없이도 카탈로그 스윕). `reward_engine` 의
>   wod_log·pr 에서 엔진 표 합산 제거 — 원천 하나. `pr_category` 는 PR 기록의 그날 운동 본문·적어 낸 동작 이름을 본다.
> - **앱**: `WodHistoryItem` = 서버 한 줄 그대로(제목·요약·라벨·PR·난도), `WodHistoryPage`(items+meta) ·
>   `ApiClient.getPage`. 홈 레벨 카드 XP 의 총 기록 수·PR 수는 **`meta.total`·`meta.pr_count`** — 목록 길이(limit 200 로 잘림)와
>   클라이언트 PR 판정 `PrDetector` 폐기(파일 삭제). 히스토리 행 = 수업 이름 / 그날 운동 요약 / 종류·일시 + 점수 라벨(+PR 배지,
>   자리 예약) · 상세 = 점수·난도·PR·메모·수업 내용(서버가 그린 글 그대로)·난도 안내. **타이머 화면(`wod_session_screen.dart`)의
>   저장도 결과 제출 창구 하나로** — 종전엔 엔진 표에 먼저 쓰고 리더보드는 best-effort 였다(D90 이 놓친 두 번째 쓰기 손).
>   검색(`history_search.dart`)은 제목 3·요약 3·종류 2·날짜 2·본문 1·메모 1·난도 1·점수 1·동작 1.
> - **게이트 (같은 커밋)**: `tests/test_ssot_history_lint.py`(엔진 표 재사용·거울 부활·정본 삭제·'회원 기록 전부' 재정의) ·
>   `test_ssot_metrics_lint.py` FACTS["수업 기록"](baseline 0) · `test_ssot_agreement.py` WINDOWS 3창구 등재 ·
>   e2e `test_6`(같은 줄·상세·404)·`test_6b`·`test_8`·**`test_10`**(히스토리 meta = 업적 ctx = 코치 명단, 휴면 표 행은 무시) ·
>   `test_reward_rules.test_pr_lifetime_count`(PR 원천 = 결과 표) · gap 테스트 2종의 `_mk_wods` 가 결과 행을 만든다 ·
>   앱 `ssot_lint_test.dart`(PrDetector·`/api/v1/history` POST·`records.length` 금지) · 골든 `hist_02`·`hist_03` 재생성 +
>   **`hist_04_detail` 신규**. 서버 전량 583 passed.
> - **배선 문서**: `services/hyphen/docs/SSOT/배선지도-D88~D91.md` — 원천 표 → 정의 → API → 화면 → 게이트 한 줄씩 (INDEX 상단 링크).
> - **남긴 것**: 홈 레벨 카드의 연속일은 앱이 센다(Streak Freeze 가 폰 로컬) — 서버 `meta.streak_days` 와 같은 정의, freeze 보정만 앱.
>   `wods`·`pacing_*` 표는 휴면 존치(`api/profile.py` 초기화 cascade 만 닿는다). 옛 엔진 행을 히스토리에 병합하지 않았다 —
>   히스토리는 '수업 기록' 이고 엔진 화면은 v3.2 에서 삭제됐다(되살릴 일 없음, 데이터는 남는다).

> **D90 (2026-08-30 집행) — 히스토리 탭 정본화: 수업 결과 저장이 같은 트랜잭션에서 히스토리 행을 쓴다 (앱 2차 전송 폐기).
> 사용자 지시 "코치가 세션 A·B·C 를 만들고 운동을 정하고 → 회원 폰이 예약·완료 → 기록 입력 때 코치가 정한 운동이 자동으로
> 잡히고 → 그 기록이 히스토리에 쌓이고 → 그걸 바탕으로 포인트·업적이 쌓이는지 완전히 다른 3가지 방식으로 검증".**
>
> - **3중 검증 결과**: ① 실제 UI(PC playwright 세션 등록 → 에뮬레이터 회원 예약 3건 → 완료 시트 3건 → 히스토리·내 정보·홈·활동·PC 회원
>   상세) ② HTTP 만의 영구 테스트 `tests/test_e2e_sessions_flow_d89.py`(7건) ③ DB 독립 재계산 감사(서브에이전트) — 세 방식 모두
>   **코치 프로그램 → 완료 시트가 그 동작을 자동으로 싣고(동작별 난도·코치 무게·무게 기록 칩) → `gym_wod_results`(class_session_id·
>   wod_post_id) → 포인트(+20/+25/+30 = 105P)·업적 3건(RULE_2/3/4)·활동 쪽지·출석(날짜당 1행) → PC 회원 상세 105P** 가 같은 값이었다.
>   무게 기록(Thruster 40kg) 은 '최고 기록' 화면에 그대로 (정본 `gym_wod_results`, `member_pr` 아님).
> - **발견한 결함 (대전제 6 위반)**: 회원 폰 히스토리 탭은 `/api/v1/history/wod`(엔진 시절 `wods` 표)를 읽는데, 서버는 결과 저장 때
>   그 표를 쓰지 않고 **앱이 결과 저장 뒤 한 번 더 POST** 했다(`wod_result_sheet.dart`). 그래서 (a) 재저장마다 히스토리 행이 하나 더
>   (로컬 실검증에서 C 세션 재저장 → 행 46 중복) (b) AMRAP 라운드 결과가 '-' (앱이 시간만 보냄) (c) 2차 호출이 실패하면 포인트는 붙는데
>   히스토리엔 없는 상태 가능. 세 방식이 전부 같은 자리를 짚었다.
> - **집행**: 정본 = `gym_wod_results`. `services/history_mirror.py`(`history_note`·`detect_pr`·`mirror_class_result`) 한 곳이 결과
>   저장(`api/gym.py submit_wod_result`)과 **같은 트랜잭션**에서 `wods` 거울 행을 upsert 한다 — 키 `wods.gym_result_id`(멱등 ALTER +
>   옛 앱 전송 행 백필 연결, 중복 행은 지우지 않고 연결만 안 함). 라운드·시간·난도·표시 제목('수업 #N · AWAKE · A 세션')이 실린다.
>   PR·XP 판정(`detect_pr`)은 `api/history.py` 와 공유(정의 1곳). 앱은 2차 전송을 지웠고 히스토리 목록은 시간이 없으면 라운드(`5R`)
>   를 적는다(`WodHistoryItem.scoreDisplay`). XP·레벨·'수업 기록 N회' 카탈로그 업적(`achievement_checker.wod_count`)은 종전대로 `wods`
>   를 읽으므로 서버 거울로 계속 오른다. 린트 3번(세션 라벨 조립)은 두 번째 괄호가 세션일 때만 걸리게 좁혔다.
> - **감사가 더 짚은 이음새 2곳(같은 날 집행)**: ⓐ 무게 기록(동작 이름+kg)을 붙인 완료는 `signature` 가 동작 단위로 바뀌어 게시물별
>   '내 기록'(`wod_my_history`)이 비었다 → `wod_post_id` 로도 잡는다(`or_`). ⓑ 카탈로그 업적(예: '수업 기록 10회')은
>   `achievement_checker._send_congratulation` 이 폐기 엔진 문구 6종만 알아 쪽지가 안 갔다 → 리워드 규칙과 같은 창구
>   `send_member_note(…, "achievement", 업적=카탈로그 이름)` 로, after_commit 1회. 게이트 `tests/test_achievement_note_d90.py` 2건 ·
>   e2e `test_6b`. 백필은 결과 하나에 거울 행 하나만 남긴다(매 부팅 멱등).
> - **잔여(다음)**: 히스토리 탭이 아예 `gym_wod_results` 를 직접 읽고 XP·카탈로그도 그 표에서 세는 완전 통합(거울 폐기) — 표 두 벌은
>   여전히 두 벌이다. 지금은 쓰는 손이 하나(서버·같은 트랜잭션)라는 것까지. 로컬 검증 DB 의 옛 중복 행(46)은 데이터 보존 원칙대로
>   남겨 두었다(연결만 해제).
> - 게이트: `tests/test_e2e_sessions_flow_d89.py` test_6(라운드·시간이 히스토리에 실림)·test_8(재제출 = 갱신, 총 건수 불변) — 서버 전량 578 passed.

> **D89 (2026-08-30 집행) — 수업 세션 (A·B…): 같은 수업 종류 안에서 그날 운동이 세션마다 다르다 (서버·PC·앱).
> 사용자 지시 "수업 관리에서 수업 선택할 때 같은 수업이라도 A 세션·B 세션 (세션 추가) 모달 안에 — AWAKE 안에서도
> A 세션은 푸시업 100, B 세션은 달리기 10분, 이런 식으로 다르게 표시".**
>
> - **정의 = `services/program_lines.py` 한 곳** (6-b): `normalize_variant`(영문 한 글자 A~Z, 대소문자·공백 정리, 빈값 = None =
>   **공통**) · `variant_label`('A 세션' / '공통') · `display_title`('AWAKE · A 세션') · `free_variants`/`next_variant`(안 쓴 글자).
>   PC JS·앱은 라벨·제목을 조립하지 않는다 — API 의 `variant_label`·`display_title`(수업)·`display_name`(게시물)·
>   `next_label`·`free_variants` 를 그대로 쓴다. 게이트 = `tests/test_ssot_program_lint.py` 3번(f"{v} 세션"·제목 조립 감지).
> - **데이터**: `class_sessions.variant`·`gym_wod_posts.variant` (VARCHAR(8) NULL, 멱등 ALTER — `models/base.py`
>   `_migrate_class_tables`·`_migrate_gym_wod_columns`). **그날 운동의 정본 단위 = (날짜 × 수업 종류 × 세션)** —
>   `_sync_wod_post` 키·취소 시 "남은 타임" 판정·완료 게이트(`completion_gate.gated_sessions`) 전부 세션까지 같아야 한다.
>   게시물 본문 첫 줄 = 표시 제목('AWAKE · A 세션') — 옛 앱도 세션을 읽는다. 세션 이동(PATCH variant A→B)은 옛 키에
>   활성 수업이 없으면 그 게시물을 지운다(`_drop_orphan_variant_post`). 수업 종류가 없는 단발 수업은 세션 무시.
> - **API**: 수업 POST/PATCH `variant` 수용(400 `INVALID_VARIANT`) · 모든 수업 직렬화에 `variant`·`variant_label`·`display_title`
>   (`class_public_fields` — list/create/member classes/reservations/roster), 쪽지·SSE 수업명도 표시 제목 ·
>   `GET /admin/gyms/<id>/program-variants?date=&template_id=` = 공통 + 그날 세션(글자·program·memo·수업 수) + `free_variants` ·
>   회원 `GET /gyms/<id>/wods` 에 `variant`·`variant_label`·`display_name`, `first_class_at` 은 세션별 · admin wod-posts GET 에 `variant`.
> - **PC**: 수업 등록 모달이 640 폭으로 넓어지고 **세션 칩(공통 · A 세션 · B 세션 · + 세션 추가) + 그날 운동 편집기 + 메모**를
>   갖는다(수정 모달과 같은 부품 `ProgramEditor.create` · 신규 `ProgramEditor.createVariantPicker`). 수업 종류를 고르면 그날
>   세션 목록을 불러 공통을 고른 채 편집기를 채우고, 칩을 바꾸면 그 세션 내용으로 바뀐다. 수정 모달에도 같은 칩 — 바꾸면
>   수업이 그 세션으로 옮겨간다. 달력 칩·상세 제목·취소 확인은 `display_title`. `_dayPostFor` 는 (template_id, variant) 로 찾는다.
> - **앱**: `ClassSessionDto/MyReservationItem.displayTitle`·`GymWodPost.variant/variantLabel/displayName`. 수업 줄·요약·예약
>   다이얼로그·알림 제목·오늘 예약 카드 = `displayTitle`. 프로그램 칸 중복 판정 = (templateId, variant) — AWAKE A 와 B 는 둘 다
>   선다(`visibleProgram`, 회귀 `test/golden/program_order_test.dart` 세션 그룹). 코치 명단 시트 제목 = 서버 `display_title`.
> - **골든**: 가짜 데이터에 AWAKE B 세션(19:00 · Run) + 수업 'WOD Class · A 세션' 추가 — 프로그램 칸·수업 시간 칸 골든 재생성.
> - 게이트: `tests/test_program_variants_d89.py` 12건 (정규화·세션별 게시물·회원 피드·완료 게이트·세션 목록·이동·취소·
>   직렬화·거부) — 서버 전량 568 passed.

> **D88-2·3 (2026-08-30 집행) — 완료 = 예약한 사람만·수업 시작 후 (서버) · 동작 조건 업적 "X 동작을 Y 기간 Z 번" (서버·PC).
> 사용자 지시 "다하고나면 너가 직접, 코치로 운동 짜보고, 회원으로(PC 에뮬레이터) 예약하고 운동 완료 눌러서 …
> 포인트·업적도 달성되는지 체크 … X운동을 Y시간동안 Z번 하면 완료-업적 트리거도 설정해놓고 (가상) ㄱㄱ".**
>
> - **완료 게이트 정본 = `services/completion_gate.py completion_check`** (한 곳). 수업 종류(template)에 묶인 그날 운동은
>   같은 날·같은 종류 수업에 `RESERVED_STATUSES` 예약이 있어야 하고(없으면 403 `RESERVATION_REQUIRED` "예약한 수업만
>   완료할 수 있습니다."), 그 수업 시작 시각을 지나야 한다(403 `CLASS_NOT_STARTED` "수업 시작 후에 완료할 수 있습니다.").
>   단발 수업은 그 세션으로, 손 게시물(연결 없음)은 종전대로 누구나, 코치 기기는 게이트 없음. 결과 행에 `class_session_id`
>   저장(어느 수업의 완료인지). 앱은 무변경 — 결과 시트가 서버 문구를 그대로 띄운다(D67 인라인 에러 자리).
> - **이음새 결함 수정**: 리워드 '수업 기록'(wod_log) 트리거가 페이싱 표 `WOD` 만 세고 회원 수업 결과(`gym_wod_results`)를
>   안 셌다 → 두 원천을 합친다(pr 분기와 같은 결). `submit_wod_result` 가 wod_log 트리거도 평가한다(종전 pr·attendance 만).
> - **동작 조건 = `gym_reward_rules.movement_id`** (NULL 허용, wod_log 트리거만). 판정 = 결과의 게시물 `stored_movements` 에
>   그 동작이 있는가(`program_lines.post_has_movement` 한 곳). 기간 Y·횟수 Z 는 기존 조건 슬롯(window week/month·lifetime·
>   condition_value) 그대로 — 새 조건 타입 없음. `_sentence` 가 "Thruster 포함 수업 기록 누적 1회 달성 시 30P 적립 + 업적
>   부여" 로 읽어 준다. PC 규칙 빌더에 '동작 (선택)' 드롭다운(사전, `name` 그대로) + '동작 목표 — 매주 3회 50P' 프리셋.
>   `movement_id: null` 은 값 기준으로 "없음"(키 존재로 400 내지 않는다 — PC 가 모든 트리거에 키를 보낸다).
> - **곁가지 결함(선재)**: 규칙 삭제가 카탈로그 행을 숨김으로 남기는데 SQLite 가 규칙 id 를 재사용해 같은 `RULE_n` code 로
>   INSERT → UNIQUE 500 (E2E 첫 규칙 생성에서 재현). `create_rule` 이 같은 code 행을 되살려 덮어쓴다 + 회귀 테스트.
> - 게이트: `tests/test_completion_and_movement_rule_d88.py` · `test_reward_rules.py::test_recreate_rule_after_delete_…`.
>   서버 전량 555 passed (`test_roundtrip_numbers::test_reserved_count_survives_attendance_marking` 는 00:00~00:30 KST 에만
>   실패하는 자정 경계 시계 의존 — 코드 결함 아님, 00:30 뒤 재실행 통과 확인).
> - **E2E 실검증 결과 (2026-08-30 09:53 로컬)**: 코치 PC 에서 AWAKE 수업 7(AMRAP 캡10 · Thruster 10회 40kg · Row 250m)
>   + 규칙 "Thruster 첫 완료"(wod_log · movement_id · lifetime 1회 · 30P · 업적 First Thruster) 생성 → 회원 에뮬 예약 →
>   시작 전 '저장' 은 403 `CLASS_NOT_STARTED` 문구 그대로 표시 → 시작 후 '저장' 성공. 한 번의 저장으로
>   `gym_wod_results` 1건(class_session_id=7 · rounds 3) · `member_points` +30("규칙 달성 — Thruster 첫 완료") ·
>   `user_achievements` RULE_1 · `gym_attendances` source=self · 자동 쪽지 '업적 달성'(auto_kind notify:achievement) 이
>   같은 트랜잭션 시각에 생겼다. 폰 = 캐릭터 스낵바 "First Thruster Earned." · 카드 '기록 3R' · 내 정보 30P ·
>   쪽지함 활동 칸 '업적 달성'(코치 칸은 비어 있음 — D72 판정대로). PC = `GET /admin/members/1/points` balance 30.
>   세 면이 같은 값을 말한다. 앱 코드 무변경.

> **D88-1 (2026-08-30 집행) — 1단계: 동작 사전 + 코치 드롭다운 (서버·PC). 앱 무변경.**
>
> - **동작 사전 = `movement_library`** (기존 60종 시드 — PC '동작 라이브러리' 탭이 이미 쓰던 표). D88 원문의
>   "기본 세트 = 구 `movements` 23종" 은 폐기된 페이싱 엔진 표라 **정정** — 사전을 둘로 두지 않는다(§0-B).
>   컬럼 추가: `gym_id`(NULL=공용·값=체육관 추가분) · `unit`(reps/meters/calories/seconds) · `has_load` · `is_active`.
>   unique 는 `(gym_id, name_en)` 복합으로 표 재작성(id 보존, 프로드 SQLite 멱등). 표시 이름 = **영문 동작명 하나**
>   (`display_name = name_en` — 검증 중 사전 '에어로바이크' ↔ 본문 'Bike' 불일치를 잡아 통일, 한글은 `name_ko` 곁들임).
> - **그날 운동 = 게시물 `gym_wod_posts.rounds_data`** (v1.25 라운드 JSON 재사용 — 새 표 없음). 동작 줄에 `movement_id`·`unit`
>   추가, 메모는 `round[0].content`. **정의·검증·렌더링 정본 = `services/program_lines.py`** (`WOD_TYPES/WOD_TYPE_LABELS` ·
>   `normalize_program` · `apply_program` · `render_program_content` · `program_of`). 본문 `content` 는 서버가 구조에서
>   그린다: `제목 / FOR TIME · 캡 12분 / Thruster 21-15-9회 · 43kg / Row 500m / (빈 줄) 메모` — 옛 앱도 그대로 읽는다.
> - **API**: `GET /admin/movement-library`(체육관 범위) · `POST/PATCH /admin/gyms/<id>/movement-library`(코치 추가·빼기, 공용 행
>   403 BASE_MOVEMENT, 중복 409) · `GET /admin/program-meta`(종류·단위·분류 선택지 — PC JS 에 표를 두지 않는다, 6-b) ·
>   수업 POST/PATCH 와 wod-posts POST/PATCH 가 `program` 객체 수용, wod-posts GET 에 `program` 동봉. `_sync_wod_post` 는
>   program 미지정이면 있던 구조를 유지(폰 시트가 메모만 보내도 PC 구조가 안 지워짐), **program=None 명시 + 메모 없음**
>   이면 템플릿 게시물도 지운다(구조를 보고 비운 창구의 뜻 — 조용히 무시하면 화면이 거짓말한다).
> - **PC**: 공용 편집기 `static/program_editor.js` 한 벌을 수업 수정 모달·게시 모달이 같이 쓴다 (종류·라운드·캡 + 동작 줄
>   [사전 select(분류 optgroup)·목표·단위 라벨·무게 kg(has_load 만)·↑↓✕] + '사전에 없는 동작' 인라인 폼). 읽기 표시는
>   서버 `content` 그대로(PC 가 줄을 다시 조립하지 않는다). '동작 라이브러리' 탭 → **'동작 사전'**(추가·빼기). 이름·단위·분류
>   글자는 API 의 `name/unit_label/category_label`, 검증은 서버 400 문구 그대로. 디자인 린트 baseline 유지.
> - **게이트**: `tests/test_ssot_program_lint.py`(wod_type 리터럴 재정의·본문 손조립 감지, baseline 0) ·
>   `tests/test_movement_library_d88.py` 16건 · `tests/test_program_d88.py` 15건 (본문 기대값은 문자열 리터럴 고정).
>   서버 전량 540 passed. 로컬 실검증: PC 수정 모달에서 Thruster 21-15-9 43kg + Row 500 저장 → 회원 API `rounds_data`
>   에 movement_id·unit → 에뮬레이터 앱 프로그램 카드에 같은 본문(2026-08-30 00:04).
> - 잔여: 앱 카드가 제목 줄과 머리줄을 카드 헤더(`AWAKE · FOR TIME · 12min cap`)와 겹쳐 두 번 보여준다 — 2단계(앱 완료
>   입력) 때 카드에서 본문 첫 두 줄을 접는다. 앱 `wodTypeLabel`·`WodMovementItem.displayLine` 의 영문 라벨/단위 표기는 서버
>   `wod_type_label`·`unit_label` 로 옮길 대상(6-b, 2단계).

> **D88 (2026-08-29 사용자 확정 · 미착수) — 운동을 데이터로: 동작 사전 → 그날 운동 → 예약자만 완료 → 업적 자동 → 히스토리 검색.**
>
> 사용자 원문 요지: "업적-포인트-히스토리-운동(그날그날 바뀌는 것, 수업 종류 말고)을 서로 연동. 1 예약 → 2 운동 →
> 3 완료(예약한 사람만, 코치가 입력한 그날 운동 리스트에서 내가 한 운동을 알맞게 입력) → 4 그걸로 업적 자동 pass →
> 5 코치는 텍스트가 아니라 운동 목록에서 드롭다운 선택 → 6 히스토리 검색으로 자기 기록·무게 확인." Claude 의 6단계
> 재서술·갭 대조에 "완벽히 정확하다. 전부 맞음".
>
> - **지금 상태**: 1 있음 · 3 결과 제출은 회원이면 누구나(예약 검사 없음, `submit_wod_result`), 동작별 입력 없음 ·
>   4 리워드 트리거는 출석·PR·결제·생일·수동뿐(동작 기반 조건 없음) · 5 서버 `movements` 23종·4분류(페이싱 시절)는 있으나
>   PC 수업 관리는 자유 텍스트 · 6 D84 검색은 글자 기준.
> - **표 4개**: 동작 사전(체육관 공용 · 이름·분류·기록 단위) / 그날 운동(날짜×수업 종류에 동작 줄: 동작·목표·순서·라운드/캡)
>   / 회원 완료 기록(예약 1건에 1개 · 동작별 실제 값 + 전체 시간/라운드) / 업적 조건(동작 누적 N회 · 무게 ≥ Y · N종 경험).
> - **순서**: ① 동작 사전 + 코치 드롭다운(PC·서버) → ② 회원 완료 입력(예약자만·동작별 값, 앱·서버) → ③ 업적 자동 판정 +
>   히스토리 동작 검색. 큰 틀(AWAKE·SWEAT·BUILD)은 그대로. 기존 자유 텍스트 기록·표는 지우지 않는다(휴면).
> - **기본값(Claude 추천, 사용자 미답 — 반대 없으면 적용)**: 완료는 수업 **시작 후**부터 · 예약 없이 온 사람은 코치 PC
>   대리 출석+기록 · 동작 사전은 기본 세트(기존 23)+코치 추가 · 무게/횟수 동작만 필수 입력(나머지 체크).
> - 4기둥 판정: 수업 공개 + 업적 기둥 사이 배선. 메모리 `project-movement-data-flow`.

> **D87 (2026-08-29 사용자 보고) — PC 수업 관리: 취소한 수업이 달력에 그대로 떠 있던 것 (PC).**
>
> 사용자 원문: "수업을 클릭해서 취소누르고 취소하겠냐해서 취소했는데 계속 화면에 떠있다, 실시간 연동되서
> 바로바로 되도록 체크하고, 회원들 폰에서도 똑바로 api 보내져서 연동되서 보일 수 있도록 체크"
>
> - **재현(로컬 playwright)**: 취소 → 서버 200 · `status=cancelled` · SSE `class_cancelled` 발행 · 페이지가 목록을
>   두 번 다시 받음(취소 응답 뒤 + SSE 수신) — 전부 정상. 그런데 `renderCalendar` 가 **status 를 안 봐서** 빨간 칩이
>   그대로였다. 데이터·연동이 아니라 **그리기**의 결함.
> - 수정(`web/facing-admin templates/classes.html`): `status=cancelled` 칩은 `is-cancelled` — 바탕 `--bg` · 글자 `--fg`
>   + `--dim` · 점선 테두리 · 제목 취소선 · 아랫줄 '취소됨'. 지우지 않는다(그 시각에 수업이 있었다는 사실, 폰의
>   '취소됨' 흐림 배지와 같은 뜻). 상세 모달은 그대로 열리고 취소 버튼은 비활성(종전 그대로). 시각 라벨의 프로그램
>   이름 폴백에서 취소 수업 제외. `design/lint.py` baseline 유지(`--muted` 폐기 토큰 회피).
> - **실시간 검증**: 다른 창구(fetch)에서 취소해도 페이지가 SSE 로 2.5초 안에 흐림 표시로 바뀜. (수업 **생성**은
>   SSE 사건이 없어 다른 탭엔 안 뜬다 — 만든 탭은 스스로 다시 받으므로 실사용 문제 아님. 미결로 기록.)
> - **회원 폰**: 서버 `sse_publish(gym_id, 'class_cancelled')` 는 체육관 구독자 전원(PC·폰 같은 큐)에게 가고, 앱
>   `week_board._classReloadEvents` 에 `class_cancelled` 가 있어 수신 즉시 `_loadClasses()` → 줄이 '취소됨' 흐림
>   배지로 바뀐다(`ClassLine.member` muted). 코드 경로 확인 — 실기 SSE 도달은 D79 에서 3종 검증됨.
> - 레이아웃 점검(1920 폭): 주간 달력·접힌 시간 행·칩·모달 겹침 없음, 가로 스크롤 없음, 깨진 이미지 0.

> **D86 (2026-08-29 사용자 지시) — 예약 완료: 세 줄 토스트 + 화면 중앙 폭죽 (앱).**
>
> 사용자 원문: "예약이 성공적으로 완료되면 아래같은 스타일의 글이 나오게 깔끔하게(토스트) 그리고 화면 중앙에
> 폭죽 잠깐 쏴지는 애니메이션 — 예약이 완료되었습니다. / 수업시간 최소5분전 도착해서 운동준비를 마쳐주세요 /
> 5분 이상 지각은, 수업에 참여할 수 없습니다"
>
> - **토스트** = `HkSnack.info(detail:)` — 굵은 제목 한 줄 + 안내 줄(caption·fgSecondary) 두 줄, 웃는 캐릭터, 5초.
>   HkSnack 하나에 `detail` 만 늘렸다(다른 모양의 토스트를 만들지 않는다 — §3 코드·클래스 SSOT).
>   문구 정본 = `class_flows.dart kReservedTitle · kReservedDetail`: "예약이 완료되었습니다." / "수업 시간 최소 5분
>   전에 도착해 운동 준비를 마쳐 주세요." / "5분 이상 지각은 수업에 참여할 수 없습니다." (띄어쓰기·마침표만 정리).
> - **폭죽** = `HkConfetti.burst(context)` (HKit) — 루트 Overlay 에 한 장 얹고 1.1초 뒤 스스로 걷는다. 터치를
>   막지 않고 레이아웃에 끼어들지 않는다(아래 화면 0픽셀 이동). 조각 56개 · 브랜드 5색 사각 · 고정 시드(같은 모양,
>   골든이 잡는다) · 시스템 '애니메이션 줄이기' 면 안 쏜다. 외부 패키지 없음.
> - **쏘는 때** = 예약이 **확정**된 순간만(`reserveClassFlow` status ≠ waitlisted). 대기 등록은 자리가 아직 아니라
>   종전 한 줄('대기열 N번 등록.')·폭죽 없음. 취소·오픈 전 안내도 폭죽 없음.
> - 골든: `snack_04_reserved`(토스트) · `state_27_reservation_done`(예약 탭 350ms 뒤 — 토스트 + 폭죽 프레임) 신규
>   → **75장**. 빌드 **3025**.

> **D84 (2026-08-29 사용자 지시) — 히스토리 목록에 검색 · 연관도순 (앱).**
>
> 사용자 원문: "히스토리 라는 목록 만들어. 거기는 검색이 되는거고 연관도순으로 검색되게 하고"
> (4기둥 판정: 수업 공개의 받침인 '내 수업 기록' 목록 — 기존 화면(내 정보 → 메뉴 → 히스토리)에 검색을 얹은 것).
>
> - **검색 칸이 목록 위에 항상 선다** (로딩·빈 상태·에러에도 — 레이아웃 안정성). 검색어가 비면 최근순,
>   치면 **연관도순**. 결과 0건이면 '검색 결과 없음' + "'q' 에 맞는 기록 없음."
> - **순위 규칙 정본 = `lib/features/history/history_search.dart` 한 곳** (`rankHistory`). 낱말 전부 AND ·
>   낱말 점수 = 가장 잘 맞는 칸의 (맞는 정도 × 칸 가중치): 칸 전체 일치 10 · 칸 앞부분 6 · 단어 앞부분 4 ·
>   포함 2 × 요약 3 · 종류 2 · 날짜 2 · 본문 1 · 난도 1 · 시간 1. 같은 점수면 최근 것이 먼저. 화면에 보이는
>   값만 찾는다(보이지 않는 값으로 순위가 오르면 "왜 위에 있지" 가 된다). 단위 검사 `test/history_search_test.dart` 7건.
> - **서버는 손대지 않았다.** 히스토리는 회원 한 사람 것이라 저장소가 100건씩 끝까지 받아 폰에서 고른다
>   (`listAllWodHistory`). 페이싱 계산이 아니라 목록 고르기라 "계산은 서버" 원칙과 충돌하지 않는다.
>   기록이 수천 건이 되면 그때 `q=` 서버 검색으로 옮긴다 — 순위 규칙은 이 파일의 표를 그대로 옮기면 된다.
> - 목록 줄: 제목 = **수업 내용 첫 줄**(`WodHistoryItem.summary` — 결과 저장이 남기는 '수업 #N · …'),
>   아랫줄 = 종류 · 일시, 오른쪽 = 시간. 찾은 이유가 줄에서 바로 읽힌다 (종전엔 종류만 굵게, 내용은 안 보였다).
> - 골든: hist_02_list · hist_03_search 신규, hist_01 재생성 → **72장**. 빌드 **3023**.
> - **D85 (같은 날 사용자 "하단 4번째 탭으로도 좀 줘")**: 회원 셸 **4탭 = 홈 · 수업 · 히스토리 · 내 정보**
>   (`HistoryScreen(embedded: true)` — 상단바는 셸 하나). 내 정보 메뉴의 '히스토리' 줄은 그대로("~로도").
>   기본 진입(수업)·공지 점(수업 탭) 불변. 골든 member_27_shell_history 신규 → **73장**. 빌드 **3024**.

> **D83 (2026-08-29 사용자 지시) — 내 정보 메뉴 항상 펼침 · '알림 받기' 메뉴 안으로 · '체육관 정보' 화면 신설 (앱).**
>
> 사용자 원문: "내정보에 메뉴란 항상 펼쳐놓고, 알림받기도 밑에 메뉴안에 1곳으로 넣고, 저기에 체육관정보
> 새로만들고, 거기에 누르면 수업종류 설명 칸 넣자" — D81 이 남긴 '수업 안내(수업 종류) 노출 자리' 결정.
>
> - **메뉴는 항상 펼침.** v1.31 의 아코디언(기본 접힘)을 폐기하고 섹션 라벨 '메뉴' + 표(HkRowCard) 하나.
>   앵커 `kMenu` 는 라벨 자리로 옮겼다(안정성 검사는 그대로 7 상태 y 동일).
> - **'알림 받기' 는 메뉴 표 안 한 줄.** 종전엔 포인트 아래 별도 카드였다. 토글·관문(`NotificationService`)·
>   세 상태 한 줄 부제 규칙은 그대로 — 카드 껍데기만 표가 가진다. 앵커 `kNotifications` 는 그 줄에.
> - **'체육관 정보' 줄 신설 (메뉴 첫 줄)** → `GymInfoScreen`(`lib/features/gym/gym_info_screen.dart`) —
>   상단바 '체육관 정보' + `GymInfoCard` 하나. 이름·주소·전화 · 코치 · **수업 종류(이름 + 한 줄 설명,
>   이벤트 배지)** · 수업 시간 · 모토. D79 가 붙이고 D81 이 걷어 갔던 수업 종류 노출 자리가 여기로 복구.
>   카드 내용은 GymInfoCard 한 곳에만 있다(화면은 세우기만).
> - 메뉴 순서 = 체육관 정보 · 전자계약서 · 히스토리 · 최고 기록 · 알림 받기 · 개인정보처리방침 · 이용약관.
> - 골든: member_04(메뉴 펼침, 알림 받기 포함) · member_25(GymInfoScreen 실화면) 재생성 · member_05(펼침 캡처)는
>   같은 그림이라 삭제 → **70장**. 회원권 아래 겹쳐 있던 구분선 두 겹도 한 겹으로. 빌드 **3022**.

> **D82 (2026-08-29 사용자 지시 2단) — 예약 오픈 전: '예약' 버튼은 살려 두고, 누르면 캐릭터 스낵바 (앱).**
>
> 사용자 원문 (최종): "그 예약버튼 누르고싶은데, 아직 설정한 시간이 아닐때 누르면 스낵바나 토스트(지금 있는것처럼)
> 로 '예약 가능한 시간이 아니에요' 캐릭터와 함께 뜨면 안될까?"
> (1단 지시 "안 되더라도 플레이스홀더로 보여줘야 함" 으로 빌드 3020 에 줄 안 문장을 세웠다가, 같은 날 이 지시로 교체.)
>
> - 종전(D58)엔 예약 오픈 전 수업의 우측이 작은 회색 배지 **'오픈 전'** — 누를 것이 없어 보였다. 이제 오픈 전이어도
>   **'예약'(찼으면 '대기') 배지가 그대로 선다** — `ClassLine.member` 는 여기서 잠그지 않는다.
> - 누르면 `reserveClassFlow` 가 서버를 두드리지 않고 **담담한 캐릭터(neutral) 스낵바** — `'예약 가능한 시간이
>   아니에요'` + 둘째 줄 `'8/30 11:00 부터'`. 실패(붉은 테두리·우는 얼굴)가 아니라 상태 안내다: 회원이 잘못한 게 없다.
>   시각은 서버가 준 `booking_open_at` 그대로 붙인다(정책 계산을 앱에 두 번 적지 않는다).
> - 기기 시계가 틀려 앞 검사를 지나쳐도 서버 409 `BOOKING_NOT_OPEN` 을 같은 문구로 잡는다 (정본은 여전히 서버).
> - 문구 정본 = `lib/features/classes/class_flows.dart kBookingNotOpenSnack` — 골든 `state_15` 가 '예약' 을 눌러
>   스낵바까지 찍는다. 3020 의 `HkSlotNote` 는 호출처 0 이 되어 삭제. 개념어 '오픈 전'(GLOSSARY)은 그대로.
>   '회원권 필요'·'마감'·'종료' 배지는 그대로.
> - 회귀: `flutter test` 전량 · `analyze` 0 · 골든 71장(state_15 재생성, 수 변화 없음). 빌드 **3021**.

> **D81 (2026-08-29 사용자 지시 5건) — 홈 공지 검정 전광판 · 공지는 홈에서만 · 수업 탭 하단 2개 · 내 정보 3곳 삭제 (앱).**
>
> 사용자 원문: "공지부분은 검정바탕에-흰글자가-꽉채워서 흐르게 하자. 공지는 홈에서만 보이게하고,
> 수업들어와서 프로그램 수업시간 하단에 체육관정보, 공지 2개 삭제, 내정보에서 상단에 체육관주소
> 안보이게하고, 체육관 기록(주의사항)부분 보일필요없고, 내 체육관 부분도 안보이게 삭제"
>
> - **홈 공지 = 검정 전광판.** 접힌 줄이 `fg` 바탕 · `bg` 글자, `HkMarquee(fill: true)` 로
>   짧은 글도 이어 붙여 줄을 꽉 채우고 **항상** 흐른다(D80 의 "넘칠 때만" 은 fill 이 아닐 때의
>   기본값으로 남는다). 공지 여러 건은 ` · ` 로 이어 한 줄. 0건이면 문구만 서 있다.
>   펼치면 종전처럼 흰 카드에 최신 3건. 접근성 '애니메이션 줄이기' 존중.
> - **공지는 홈에서만.** 수업 탭 하단 '체육관 정보'·'공지' 아코디언 삭제. 쪽지함 핀 카드는
>   지시에 없어 그대로(그 카드는 마키 넘침 모드).
> - **내 정보** 신원 카드의 주소 줄 · '체육관 기록'(주의 사항·메모) 카드 · '내 체육관' 섹션 삭제.
>   남는 순서 = 신원(이름 · 체육관·역할) → 회원권 → 로그아웃 → 포인트 → 알림 받기 → 메뉴.
>   `_ProfileRow`·`_MyBoxSection` 고아 위젯도 함께 걷음. 안정성 검사 앵커 `kGymInfo`·`kMyGym` 제거.
> - ⚠ **딸려 나간 것 — 사용자 결정 대기**: 수업 탭 하단 체육관 정보가 D79 '수업 종류(수업 안내)'
>   칸의 유일한 노출 자리였다. `GymInfoCard` 는 호출처 0곳이 됐다(위젯·모델·저장소·골든은 보존).
>   두 지시가 충돌한 자리라 임의로 옮기지 않았다 — 어디에 둘지(홈 카드 / 내 정보 메뉴 / 폐기) 결정 필요.
> - 회귀: `test/marquee_test.dart` fill 3건 추가(채워 흐름 · 빈 글 정지 · 접근성) ·
>   `flutter test` **243** · `analyze` 0 · 골든 71장(19장 재생성, 수 변화 없음).

> **D80 (2026-08-29 사용자 "공지 칸만 좌에서 우로 안에 내용이 TEXT 가 슬라이드 돌아가게") — 공지 한 줄 전광판 (앱).**
>
> - 공지가 노출되는 세 자리(수업 탭 아코디언 · 홈 공지 카드 · 쪽지함 핀)의 **접힌 한 줄**이
>   `…` 로 잘려 뒷말이 안 보였다. 펼치면 다 보이지만 "펼쳐야 보인다" 가 안 읽히는 이유.
> - `HkMarquee` 신설(HKit — §3 코드·클래스 SSOT, 세 자리가 이 하나를 쓴다):
>   **넘칠 때만** 오른쪽→왼쪽으로 흐른다(짧은 글은 서 있다 — 흔들면 시선만 뺏는다) ·
>   넘침은 실제 레이아웃 폭으로 잰다(글자 수 추정 금지) · 초당 32px, 시작 1.2초 멈춤 ·
>   두 벌 이어 붙여 끊김 없이 반복 · 시스템 '애니메이션 줄이기' 면 서 있고 `…`.
> - 골든 71장 **변경 0** — 첫 프레임은 정지라 기존 캡처가 그대로 맞다. '흐른다' 는
>   골든이 못 잡으므로 `test/marquee_test.dart` 3건(서 있음 · 왼쪽 이동 · 접근성)이 못 박는다.
> - 회귀: `flutter test` **240** · `analyze` 0.

> **D79 (2026-08-29 사용자 "수업안내노출도 필요하고, 지금 공지 제대로 작동안한다") — 수업 안내 회원 노출 · 공지 실시간 갱신 (앱 + 서버).**
>
> **1. 수업 안내(수업 종류)가 회원 폰에 안 보이던 것** — 서버 창구
> `GET /api/v1/member/gyms/<id>/class-templates` 는 살아 있었고 **앱이 한 번도 안 불렀다**
> (오늘 세 번째 같은 유형 — 칭호·결제축 매출과 같은 "서버·데이터는 있는데 화면 경로가 끊김").
> - 앱 `models/class_template.dart` 신설 · `GymRepository.listClassTemplates` ·
>   `GymState.loadMine` 에서 코치 목록과 같은 자리에서 함께 받는다(실패해도 다른 결과 유지).
> - 노출 자리 = **체육관 정보 카드**(`gym_info_card.dart _ClassTypesSection`) — 회원이 이미
>   여는 자리에 '수업 종류 (N)' 칸. 이름 · 설명 · `kind == 'event'` 는 **'이벤트' 배지**.
>
> **2. 공지가 PC 에서 올려도 폰에 안 보이던 것** — 서버 필터는 정상이었다(프로드 실측:
> 유효 기간 안 공지 1건이 회원 창구로 정상 응답). 원인은 앱 두 겹:
> - `AnnouncementsState.bind` 가 "이미 묶였고 목록이 있으면" 건너뛰어 **첫 응답이 앱을
>   껐다 켜기 전까지 굳었다.**
> - `announcement.posted` SSE 는 `GymState` 만 reload 시켰는데 GymState 는 공지를 싣지 않는다
>   — AnnouncementsState 를 다시 묻게 하는 코드가 **0곳**이었다.
> - 수정: `GymState.announcementsChanged` 스트림 신설(SSE posted/updated/deleted → 신호) ·
>   `AnnouncementsState.bind(..., changed:)` 가 그 신호를 듣고 `refresh`. 같은 체육관 재바인딩은
>   조용히(셸 재빌드마다 서버를 두드리지 않는다), 체육관이 바뀌면 다시 묻는다.
> - 서버: 공지 **수정·삭제**도 SSE 를 쏜다(종전엔 등록만) — 고친 문구·지운 공지가 폰에 남지 않게.
> - 지난 공지 2건(`ㅎㅎㅎ`·`안녕하세요`)이 안 보인 것은 **유효 기간이 끝나서**다 — 결함 아님.
>   PC 에서 기간을 안 넣으면 시작=오늘 00:00 · 끝=오늘 23:59 로 저장돼 **그날만** 보인다.
>
> - 회귀: `test/golden/announcements_refresh_test.dart` 신설(신호 → 갱신 · 재바인딩 조용히) ·
>   픽스처 `class-templates` 4종(정규 3 + 이벤트 1) · `flutter test` **237** · `analyze` 0 ·
>   골든 71장(`member_25_gym_info` 재생성) · 서버 `pytest tests/` 503.

> **D78 (2026-08-29 사용자 "그날 수업이 시간 순서대로, 중복은 표시하지 않고") — 프로그램 칸 정렬·중복 제거·전부 펼침 (앱 + 서버).**
>
> - **서버**: 회원용 `GET /api/v1/gyms/<id>/wods` 응답에 `template_id`·`template_name`·
>   **`first_class_at`**(그날 그 수업 종류의 첫 수업 시각) 추가. 프로그램은
>   `(post_date, template_id)` 단위인데 응답에 그 연결이 없어 앱이 순서를 알 방법이
>   없었다. **정렬 기준을 서버가 정해 내려주면 화면마다 다르게 정렬될 일이 없다**(대전제 6).
> - **앱**: `week_board.visibleProgram()` 이 정본 —
>   첫 수업 시각 오름차순(없는 글은 맨 뒤, 그 안에서 게시 순) · 같은 `templateId` 는 한 번만
>   (하루에 BUILD 가 두 번 돌아도 내용은 하나다) · `initiallyExpanded: true` 로 **전부 펼침**.
>   접힌 줄 요약도 같은 목록을 써서 요약과 내용이 어긋나지 않는다.
> - **카드 제목** = `AWAKE · FOR TIME` — 회원이 아는 이름(수업 종류)을 먼저, 오늘 무엇을
>   하느냐(운동 종류)를 뒤에. 종전엔 `FOR TIME` 뿐이라 어느 수업의 것인지 알 수 없었다.
> - 구 "첫 개만 펼친다"(2026-08-12 그 밑 수업이 밀려서)는 폐기 — v3.37 분리로 프로그램
>   칸에는 수업 줄이 아예 없어 밀릴 것이 없다.
> - 회귀: `test/golden/program_order_test.dart` 신설(순서·중복·펼침 4건) ·
>   픽스처 `gymWods()` 가 **일부러 뒤섞인 순서에 BUILD 중복**을 담아 그 자체로 증명 ·
>   `flutter test` **235** · `analyze` 0 · 골든 71장 · 서버 `pytest tests/` 503.

> **D77 (2026-08-29 사용자 "수업시간-프로그램 순서 바꾸자") — 수업 탭 칸 순서 뒤집기 · 프로그램이 기본 진입 (앱).**
>
> 사용자 원문: "지금 앱에서 수업시간-프로그램 순서 바꾸자. 프로그램 누르면 그날 운동되는
> 운동목록이 한번에 보이게만 하고(그날 운동은 펼쳐져서 다 보임 =today), 수업시간으로 가면
> 지금처럼 시간-예약 되게."
>
> - 칸 순서 **프로그램 · 수업 시간**, 기본 진입도 프로그램. 탭을 열면 "오늘 뭐 하지"가
>   먼저 답해지고, 예약하러 온 사람은 옆 칸 한 번이면 된다 (구 v3.37 은 반대였다).
> - **프로그램 칸으로 갈 때 오늘을 펼친다** — 그 칸의 목적이 "오늘 운동"이라 접힌 채로
>   열리면 답이 안 보인다. 보고 있던 주에 오늘이 없으면(지난 주·다음 주) 건드리지 않는다.
>   수업 시간 칸은 종전대로 보던 자리를 유지한다.
> - 수업 시간 칸 내용은 **그대로** (시간 → 예약 버튼).
> - 검사 갱신: 예약·취소가 걸린 캡처·검사는 먼저 `tapSchedulePane()` 으로 옮긴다.
>   harness 에 `_tapPane` 공용 헬퍼 + `tapSchedulePane` 신설 — 이미 그 칸이면 `_selectPane`
>   이 조용히 빠지므로 항상 눌러도 무해하다(기본값이 또 바뀌어도 안 깨진다).
> - 회귀: `flutter test` **231** · `analyze` 0 · 골든 **71장**(수 변화 없음, 다수 재생성) ·
>   `week_pane_test`·`stability_wod_test` 의 칸 전제 갱신.

> **D74 (2026-08-29 사용자 "그럼 없애야지, 지금 업적으로 하는거잖아") — 칭호(Panel B) 일체 제거. 게이미피케이션은 업적 하나 (앱 + 서버 한 줄).**
>
> - **왜**: 업적 화면 우상단 '칭호' 버튼으로 **도달 가능한** 화면인데, 해금 판정이
>   `profile.benchmarks`(back_squat_1rm_lb·snatch·run_5km_sec·fran_sec …)를 읽는다.
>   그 값은 폰 로컬(SharedPreferences)에만 있고 서버엔 없으며, **`setBenchmark` 호출처가 0곳**
>   이다 — 입력 화면(Benchmarks 온보딩)이 v2.6/v3.2 에서 삭제됐다.
>   → 신규 설치 회원은 그 조건의 칭호가 **영원히 안 풀린다.** 조건은 보이는데 달성할 길이 없다
>   (제1원칙 — 화면이 거짓말하지 않을 것). 살아 있던 신호는 `hasGym`·쪽지 수 정도.
> - **지운 것**: `panel_b_screen.dart` · `titles_catalog.dart`(칭호 26종·`TitleUnlockSignals`·
>   `PanelBUnlocker`) · `share_count_store.dart` · 진입 버튼 · 내 정보 착용 배지 ·
>   `GoalsState.wornTitle` 일체 · 골든 `state_06_worn_title` · 테스트 2벌.
>   대장 = `README.md §제거된 기능 대장 37`.
> - **남긴 것**: `pr_detector.dart`(홈 화면이 쓴다 — 지우기 전 호출처 재확인, 대전제 5) ·
>   서버 `member_goals.worn_title` 컬럼과 **기존 값**(DB 는 지우지 않는다).
>   서버 `api/profile.py` 는 `worn_title` **키가 있을 때만** 갱신하도록 한 줄 고쳤다 —
>   앱이 이제 그 키를 안 보내는데 종전처럼 무조건 덮으면 지난 착용값이 빈 문자열로 지워진다.
> - **제거 제안이 아니라 사용자 지시로 집행**했다 (대전제 5 존치 확정 목록과 충돌하지 않는다 —
>   목표·최고기록·히스토리는 그대로 남아 있고, 걷은 것은 칭호뿐이다).
> - 회귀: 앱 `flutter test` **231** (직전 251 — 삭제한 테스트 2벌 20건) · `analyze` 0 ·
>   골든 **71장** (직전 72) · 서버 `pytest tests/` **501 passed · 0 xfailed** 유지.

> **D73 (2026-08-29 사용자 "나머지결함까지 다 하고") — 남은 결함 10건 수정. 왕복 점검 24건 전부 종료 (서버 + PC).**
>
> `pytest tests/` 의 **xfail 이 0** 이 됐다 (501 passed · 1 skipped · 0 xfailed).
>
> - **공지 원문 보존 (2건).** 저장할 때 `html.escape` 를 걸어 '1+1 & 경품' 이 회원 폰에
>   '1+1 &amp; 경품' 으로 떴고(폰은 Flutter Text 라 HTML 을 해석하지 않는다), GET 이 준
>   본문을 그대로 PATCH 하면 이스케이프가 한 겹씩 쌓여 편집할 때마다 글자가 망가졌다.
>   **막는 자리를 그리는 쪽으로 옮겼다** — 서버는 원문 저장, PC 는 innerHTML 직전 `esc()`.
>   이미 저장된 행은 `_migrate_unescape_announcements` 가 **한 번만** 되돌린다
>   (완료 표시 = `audit_logs.action='announcement.unescape_once'`. 두 번 돌면 코치가
>   진짜로 '&amp;' 라 적은 글이 깨진다 — 로컬 DB 사본으로 3회 연속 실행 검증).
> - **페어링 코치 기기도 공지 게시·조회·수정·삭제** (대전제 1). 공지 라우트만
>   `owner_hash` 단독 게이트라, 같은 파일의 회원 목록·수업 내용·쪽지(`is_staff_device` 인정)와
>   어긋났고 오너가 아닌 코치는 공지를 못 올렸다.
> - **회원↔회원 쪽지 창구 차단** (대전제 5). `member-report` 의 `to` 검증이
>   `_is_coach_device or _is_approved_member` 라 승인 회원 해시를 넣으면 그대로 수신자가 됐다.
>   이 제품은 코치↔회원뿐이다 — 코치만 수신자로 인정한다.
> - **상태가 뒤로 가지 않는다.** 완료한 숙제를 다시 열면 `completed → read` 로 되돌아가
>   코치 보낸함의 완료 집계가 1 → 0 으로 사라졌다. `_STATUS_RANK` 를 두고 **같거나 앞선
>   상태만** 덮어쓴다. 읽음 집계에 `asked` 를 넣어(`_READ_STATUSES`) 질문까지 한 회원이
>   '안 읽음' 으로 보이던 것도 함께 고쳤다.
> - **회원권 없으면 수업 내용도 잠긴다.** 회원권 행이 하나도 없으면 '무료 체육관' 으로 보고
>   잠금을 건너뛰는 분기가 있어, 예약은 MEMBERSHIP_REQUIRED 로 막히는 같은 회원에게
>   수업 공개는 그대로 내려갔다(두 게이트가 다른 규칙). 두 곳 다 '유효 회원권 없으면 잠금'.
> - **회원이 남긴 출석이 코치의 되돌리기에 지워지지 않는다.** 둘 다 `source='manual'` 이라
>   코치가 출석을 되돌리면 그날 manual 행을 조건 없이 지우면서 회원 기록까지 날아갔다.
>   회원 경로를 **`source='self'`** 로 분리 — 각자 만든 것만 각자 지운다.
> - **리워드 보조 스윕이 실제로 돈다.** `check_achievements` 가 `Profile` 이 없으면 곧바로
>   return 해 뒤따르는 `evaluate_all_for_device` 를 건너뛰었는데, 그 Profile 을 만드는 곳은
>   폐기된 페이싱 엔진 경로 하나뿐이라 **앱만 쓰는 회원은 그 행을 가질 수 없다**.
>   놓친 적립을 메우는 안전망이 지금 회원에게는 한 번도 안 돌던 것이다.
> - **탈퇴자도 앱에서 다시 신청할 수 있다.** 재신청 분기가 `rejected` 만 되돌려,
>   `left` 는 앱·코치·DB(UNIQUE) 어느 쪽으로도 길이 없었다. `("rejected", "left")` 로 확장.
> - 회귀: 서버 **501 passed · 1 skipped · 0 xfailed** (직전 491·10) ·
>   관리자 웹 `design/lint.py` baseline 유지.

> **D72 (2026-08-29 사용자 지시) — 회원 쪽지함을 '코치' / '활동' 두 칸으로 · 빠져 있던 자동 통보 4종 배선 (앱 + 서버 + 구 D60 개정).**
>
> 사용자 원문: **"쪽지는 쪽지고(코치와 대화), 업적알림 가입 예약완료 등등 이런건 활동로그
> 이런걸 만들어서 거기에 그냥 쌓이게 하면 안돼? 그리고 쪽지와 업적알림 모두 토글에 연동시켜놔서"**
> 후속: "회원의 경우에 쪽지 누르면 지금 있는 것처럼 코치가 있고 옆에 활동이란 탭도 있고,
> 코치 누르면 코치랑 대화로 연결, 활동 누르면 예약이 되었다·회원권이 결제되었다·업적이 완료되었다 등등"
>
> - **구 D60 개정.** "알림 = 앱 쪽지 하나"의 **채널**은 그대로 하나다(카카오·FCM 없음).
>   달라지는 것은 **한 화면 안에서 갈래를 나눈다**는 것 — 자동 통보가 체육관 공용 해시로
>   나가 코치와 같은 대화 스레드에 섞여 들어왔고, 코치와의 대화를 열면 결제·만료 안내가
>   사이사이 끼어 읽기 어려웠다.
> - **가르는 판정은 서버 한 곳** — `coach_note._is_conversation()` (auto_kind 가 비었나).
>   '활동' 은 그 여집합이라 **한 쪽지가 두 칸에 겹치거나 어느 칸에서도 새지 않는다**(대전제 6).
>   `build_threads`/`build_messages` 에 `include_auto` 를 달고 **회원 창구만** False —
>   PC 코치 화면은 종전과 같다(코치 칸 분리는 별건, 사용자 판단 대기).
>   새 창구 = `GET /api/v1/gym/<id>/activity` (자동 통보만·안읽음 수 포함).
> - **자동 통보 4종 신설** (`NOTE_TEMPLATES` — 종전 4 → **8**):
>   `booking`(예약 완료) · `promotion`(대기 → 자리 받음) · `signup`(가입 승인) ·
>   `achievement`(업적 달성). 전부 왕복 점검 결함이었다 — 일이 벌어져도 회원은 앱을
>   다시 열어야만 알 수 있었고, 특히 대기 승격은 **자리를 받아 놓고 안 와서 노쇼**가 됐다.
>   - `signup` 은 **승인만** 보낸다. 반려된 사람은 쪽지함 자체를 못 연다
>     (`_is_approved_member` 403) — 아무도 못 읽는 쪽지를 쌓지 않는다. 반려는 로그인 응답의 status.
>   - `achievement` 는 `reward_engine._grant` 안이 아니라 **`after_commit`(once)** 에 건다.
>     `_grant` 는 호출부 트랜잭션 안이고 `send_member_note` 는 새 연결을 열어, 커밋 전에
>     쓰면 SQLite 가 잠긴다. 호출부가 롤백하면 쪽지도 안 나간다 — 원하는 동작이다.
> - **공지 알림 토글이 실제로 무언가를 한다.** `announcement` 키는 PATCH·GET 이 저장만
>   하고 **읽는 코드가 0건**이라, 코치가 껐는데도 알림이 그대로 나갔다(화면이 거짓말).
>   `api/gym.py` 공지 등록의 SSE 발행에 게이트를 걸었다 — 알림만 막고 공지 자체는 올라간다.
>   `_ALLOWED_KEYS` 도 `{enabled, announcement, *NOTE_TEMPLATES}` 로 묶어 키가 갈라지지 않게 했다.
> - **회원 '알림 받기' 토글은 이미 하나였다** (2026-08-28). 쪽지·업적·수업 리마인더가 전부
>   `NotificationService` 관문 하나를 지난다. 꺼도 쪽지·활동은 **조용히 쌓인다** — 안 울리게
>   한 것이지 기록을 지운 것이 아니다.
> - **앱**: `MessagingFeed` 가 StatefulWidget 이 되고 `HkSegment('코치','활동')` 한 줄
>   (수업 탭 2칸과 같은 부품·같은 자리). 활동 칸은 숨은 칸이라 `retainError` 로 감쌌다.
>   코치 셸에는 칸을 두지 않는다 — 코치가 보는 것은 회원과의 대화뿐이다.
> - 회귀: 서버 **491 passed · 1 skipped · 10 xfailed** (직전 487·14 — 알림 결함 4건의
>   xfail 을 걷었다) · 앱 `flutter test` **251** · `analyze` 0 · 골든 **72장**
>   (`state_26_inbox_activity` 신규, `state_20`·`member_11` 재생성).
>   구 D60 계약을 못 박던 `test_auto_note_shares_thread_with_coach_note` 는
>   `test_auto_note_goes_to_activity_not_coach_thread` 로 바꿔, 두 칸이 겹치지 않는 것까지 본다.

> **D71 (2026-08-29 사용자 "숫자부터 고쳐") — 코치가 보는 숫자 4건 수정 · 이원화 기준선 3종 0 달성 (서버).**
>
> 코치 화면에만 뜨는 잘못된 숫자를 고쳤다. 회원 쪽은 멀쩡했고, 코치가 그 숫자를 믿고
> 판단하던 자리다. 넷 다 뿌리가 같아 **세는 자리를 정본으로 옮기는 것**으로 풀렸다.
>
> - **만료 임박 — 통계 1명 vs 홈 0명.** 대시보드가 이름(프로필) 행을 inner join 해
>   **이름 없는 회원을 통째로 버렸다** (코치가 재등록 대상을 놓친다). 모집단을
>   **회원권 행**으로 확정하고 `_metrics.expiring_memberships` /
>   `expiring_membership_count` / `is_expiring_soon` 으로 세 창구(명단 플래그·통계 수·
>   대시보드 목록)를 합쳤다. 이름은 화면이 따로 붙인다 — 세는 일과 보여 주는 일을 나눴다.
>   상수 `EXPIRING_SOON_DAYS` 정본도 `admin.py` → `_metrics.py` 로 이동(§0-B, 그쪽은 재수출).
> - **대기 인원 — 홈 대시보드가 언제나 0.** `ClassReservation.status == 'waitlist'` 를
>   셌는데 그 상태값은 예약 모델의 CheckConstraint 밖이라 제품 경로로 생기지 않는다.
>   원천인 `class_waitlist_promotions` + `is_pending_waitlist()` 로 교체.
>   **검사도 같이 틀려 있었다** — `test_dashboard_roster` 의 헬퍼가 그 가짜 상태를
>   직접 넣어 초록이었다. 헬퍼를 대기 표에 줄 세우도록 고쳤다(화면과 검사가 같은
>   틀린 정의를 쓰면 게이트가 아무것도 못 막는다).
> - **오늘 예약 — 건수가 아니라 사람 수.** 한 회원이 오늘 두 수업을 잡으면 수업별 합은
>   2 인데 1 이라고 말했다. 중복 제거한 목록은 **표시용**으로만 두고 수는 행 수로.
> - **수강 이력 총계 — top 5 만 합산.** 제목 GROUP BY LIMIT 5 의 합을 총계로 써서
>   6종류 이상 들은 회원은 6번째부터 빠졌다(같은 응답의 by_track 합과 불일치). 전량 COUNT 로.
> - **덤 — 예약 상태 집합 5곳 정리.** 남아 있던 `("confirmed","attended")` 직접 표기를
>   전부 `RESERVED_STATUSES` import 로 (admin 4곳 · reward_engine 1곳).
> - 회귀: 서버 **487 passed · 1 skipped · 14 xfailed** (직전 483·18) ·
>   이원화 기준선 **예약 인원 5→0 · 대기 인원 1→0 · 만료 임박 3→0** (매출만 정가 축 3 잔존).

> **D70 (2026-08-29 사용자 "돈부터") — 왕복 점검 결함 24건 중 돈에 닿는 6건 수정 (서버 + PC).**
>
> 앞선 세션이 `xfail(strict=True)` 로 박아 둔 24건 중, **틀린 장부**를 만드는 것부터 고쳤다.
> 나머지는 불편이지만 이 6건은 시간이 갈수록 잘못된 숫자가 쌓인다.
>
> - **취소 원장 신설 — `class_reservation_cancels` (뿌리 수정).** 예약 줄은
>   `(class_session_id, member_id)` UNIQUE 라 한 회원·한 수업당 하나뿐이고, 재예약하면 그 줄을
>   되살리며 `late_cancel`·`deadline_cancel` 을 지웠다. 그래서 (1) 코치가 보는 '시한 후 취소'
>   누적이 재예약 한 번에 1 → 0 으로 줄고 (2) '늦은 취소 첫 1회 무료' 가 매번 되채워져
>   **같은 수업을 반복 예약·늦은 취소하면 횟수권이 영원히 안 깎였다.** 취소는 예약 줄의
>   현재 상태가 아니라 **일어난 사건**이므로 append-only 표로 분리했다.
>   - 세는 자리 3곳을 원장 기준으로 옮겼다 — `recompute_session_charges`(취소된 예약 줄은
>     이제 어떤 횟수도 잡지 않는다. 두 곳에서 세면 한 번의 취소가 두 번 깎인다) ·
>     `session_summary` · `deadline_cancel_counts_bulk`. 쓰는 자리는 `record_cancel` 한 곳.
>   - **체육관 사정 취소는 원장에 안 적는다** (수업 통째 취소 · D58 회원권 소멸 회수) —
>     회원의 기록이 아니다. 예약 줄의 두 플래그 리셋은 그대로 두었다 (줄 = 지금 상태).
>   - 마이그레이션 `_migrate_cancel_ledger` — 기존 `status='cancelled'` 줄을 원장으로 옮기고
>     그 줄의 `session_charged` 를 0 으로 내린다. 비어 있을 때만 넣어 재기동에 안전.
>     로컬 DB 사본으로 2회 연속 실행 검증(6건 이관 · 늦은취소 2 · 점유 1 보존).
> - **미수금 환불 차단.** 환불 상한이 `p.amount`(= 미수금 행에서는 정가)라 **받은 적 없는 돈을
>   환불 처리**해 결제이력이 '전액 환불' 로 굳었다. 상한을 **받은 돈**으로 바꾸고(`refundable_of`),
>   0 이면 `NOTHING_RECEIVED` 로 거절. PC 도 그 행의 환불 링크를 감춘다 — 못 하는 일을 화면이
>   권하지 않는다 (제1원칙).
> - **회원권 가격 수정 → 결제이력 동기화** (`_resync_payments_to_price`). 종전엔 회원권 탭 150,000 ·
>   결제이력 100,000 이고 차액이 미수금으로도 안 잡혔다. **받은 돈은 손대지 않고** 정가와 미수금만
>   따라간다 — 미수금은 회원권당 잔액 하나라 가장 최근 결제 행에 얹는다.
> - **겹친 회원권은 가장 엄한 한도가 이긴다** (`plan_limits_on` 신설, `governing_membership` 에서
>   분리). 종전엔 대표 한 장의 한도만 봐서, 먼저 끝나는 무제한권이 대표가 되면 같이 든 주3회권이
>   무력화됐다(그 주 4회 예약 성공). 다 쓴 횟수권은 셈에서 뺀다.
> - **선결제 매출 이중 기준 해소.** 홈 대시보드가 하한(이달 1일)만 걸어 다음 달 결제까지 이번 달로
>   셌다. 결제 축 정의를 `_metrics.payment_revenue_in_month` 한 곳으로 합치고 두 창구가 그것을
>   부른다. 회원권 **정가** 축(`gym_stats` 매출 추정)은 다른 사실이라 그대로 — 차액이 미수금이다.
>   ⚠ **정정 (2026-08-29 16:05 실사)**: 여기서 합친 두 창구
>   (`admin_dashboard.this_month_revenue` · `payments_admin.gym_revenue.net_revenue`)는
>   **어느 화면도 쓰지 않는다** — PC 웹·폰 앱 전수 grep 0건. 코치가 실제로 보는 '이번 달 매출'
>   (통계 화면)은 **정가 축 하나뿐**이다(`stats.month.revenue_estimate`). 결함은 사실이었으나
>   (두 API 가 다른 답을 준다) **코치가 잘못된 숫자를 보고 있던 것은 아니다.**
>   결제 축을 화면에 노출할지는 미결 — 사용자 판단 대기 (2026-08-29 "일단 추후").
> - 회귀: 서버 `pytest tests/` **483 passed · 1 skipped · 18 xfailed** (직전 477·24 — 결함 6건의
>   xfail 마커를 함께 걷었다) · `test_ssot_metrics_lint` 매출 baseline 5 → **3** ·
>   앱 `flutter test`·`analyze` 무변경 통과 · 관리자 웹 `design/lint.py` baseline 유지.

> **D69 (2026-08-28 테스터 확정 — 시한이 지나도 회원이 스스로 취소한다, 대신 늦은 취소는 차감) — 회원 취소 시한 차단 폐기 · 늦은 취소 사실 고지 (앱 + 서버).**
>
> 하루 전 지시로 넣었던 **취소 60분 시한**(앱이 버튼을 미리 잠그고 이유를 적던 것)을 걷었다.
> 시한을 지나도 회원이 스스로 취소한다 — 정산은 막는 대신 D57 의 차감 규칙이 한다.
> - **구간 3단**: 60분 전까지 = 종전과 같음 · 60~20분 전 = 그냥 취소, 차감 없음 ·
>   20분 전 이후 = 취소되고 **늦은 취소로 기록**되어 횟수가 깎일 수 있음(회원권별 첫 1회 면제).
> - **앱**: `classes/class_flows.dart` 의 사전 차단·안내 스낵바 삭제. 남은 것은 `kLateCancelMinutes`
>   (=20, 서버 `api/_membership.py LATE_CANCEL_MINUTES` 거울) 과 `isLateCancel()` 뿐이고, 쓰임은
>   **취소 확인 다이얼로그 한 줄 고지** 하나다 — "늦은 취소로 기록됩니다. 횟수권은 1회 차감될 수
>   있습니다." 조용히 차감하면 화면이 거짓말을 한다 (제1원칙). 코치 쪽 기록 이야기는 회원 문구에
>   넣지 않는다. 구 60분 상수와 그 판정 함수는 §0-B 로 전량 제거 (옛 이름 grep 0건).
> - **공간 예약은 하지 않는다**: 처음엔 안내가 없을 때도 자리를 잡아 뒀으나(`reserveNotice`),
>   흔한 쪽(20분 전까지) 다이얼로그에 빈 띠만 남아 미완성으로 보였다 — `state_23` 캡처로 확인 후
>   철회. 공간 예약은 **보고 있는 화면 안에서 상태가 바뀔 때**의 규칙이고(로그인 에러·목록 로딩),
>   이 안내는 어느 수업을 취소하느냐로 정해져 열린 뒤 붙거나 빠지지 않는다. `HkDialog.confirm` 은
>   `notice:` 하나만 받는다.
> - 회귀: 골든 65 → **67** (`state_22_late_cancel_dialog` · `state_23_cancel_dialog` 신규) ·
>   `test/golden/cancel_dialog_notice_test.dart`(늦은 취소만 안내 · 평상시 무문구 · 코치 기록
>   문구 미노출 3건) · 앱 `flutter test` · `flutter analyze` 0.

> **D68 (2026-08-27 사용자 "당연하지 고쳐봐라") — 앱 전역 레이아웃 시프트 제거 (조사 19건 → 전부 수정).**
>
> - **조사**: 소넷 서브에이전트 4명이 3면 중 **폰 앱 전역**을 4갈래(홈·수업·셸 / 내 정보·업적·기록 /
>   코치·쪽지·가입 / 공용 위젯·스플래시)로 나눠 정독. 확정 19건 · 오탐 다수 제외(Stack·최하단·
>   가로 변화·모달·1회 계산). 상위가 상위 4건을 코드로 직접 재확인.
> - **수정 (5 작업자 병렬, 파일 소유 분리)**
>   1. **홈 4겹** — 오프라인 배너를 `OfflineBannerOverlay`(Stack 오버레이)로 전환(온라인일 때 0px) ·
>      공지 카드 `SizedBox.shrink` 폐지(공지 0건도 같은 골격, 부제만 '등록된 공지 없음') ·
>      업적 섹션 `kRows=3`·`kBodyH=184` 예약 + 로딩 스켈레톤(`HkSkeletonRow`) · 출석 줄 항상 렌더(`--`).
>   2. **가입 폼·온보딩** — validator 6칸 전부 `helperText: ' '`+`errorMaxLines: 1`(최장 문구 실측으로
>      2줄 예약 불필요 확인) · 경력 미리보기 `HkPreviewSlot` · 로딩 교체 → `HkButton(busy:)`.
>      예약분만큼 폼이 길어지지 않게 칸 사이 간격을 줄여 순증 ~60px(원래 ~156px).
>   3. **수업 상세·수업 탭·주간 보드** — 4개 비동기 구역을 `HkSectionSlot`(실측 1줄 높이)으로,
>      **로딩·없음·실패를 구분**(전엔 `snap.data ?? []` 로 전부 '없음') · 수업 탭 에러 배너 `HkNoticeSlot`
>      (문구·재시도 유지 = "실패를 먼저 말한다" 의도 보존) · 요일 펼침 `classSlotH=65`.
>      **`Future.wait` 묶기(가)는 기각** — 느린 하나가 나머지를 인질로 잡고 실패가 전파된다.
>   4. **코치 주간·쪽지함·노트 상세** — `HkReservedSlot` 신설로 셋 통일(`daySlotMinH=72` ·
>      공지 `announcementSlotH=123` 실측 최대 · 액션 `_actionSlotH(n)`).
>   5. **내 정보** — 포인트 카드 상시 렌더(값만 `-- P`→실값) · 회원권 섹션 로딩/미보유 3분기 ·
>      배너 3종을 `_MembershipStatusSlot` 하나로 통합(모델 확인 결과 **최대 2개 동시** 표시 가능).
> - **게이트**: 화면별 `test/golden/stability_*.dart` 5종 신설(로그인 포함 6종). 헬퍼
>   `layout_stability.dart expectStableAnchorY` 가 `getTopLeft().dy` 로 상태 간 y 를 비교.
>   **역검증 실시** — 각 작업자가 예약을 일부러 되돌려 게이트가 실제로 실패하는 것을 확인.
>   상위도 로그인 게이트를 두 방식으로 파괴 검증(안내 슬롯 조건부화 → 실패, 복구 → 통과).
> - **테스트 함정 (기록 필수)**: `pumpWidget` 은 같은 타입 트리를 만나면 **State·Provider 를 재사용**해
>   상태를 갈아 끼워도 앞 상태가 그대로 남는다 — 작업자 3명이 각각 여기 걸려 **첫 통과가 전부
>   거짓 통과**였다. 상태 절차마다 트리를 버리고(`pumpWidget(SizedBox.shrink())`/`UniqueKey`),
>   `expect(find.text(...))` 로 "정말 그 상태인지" 못 박을 것.
> - **부수 수정**: `test/golden/fakes.dart` 의 `/api/v1/member/points` 가 `points` 키를 주는데 서버·앱은
>   `balance` (서버 `api/gym.py:1398`) — 페이크가 틀렸다. 고치니 골든의 포인트 카드가 `-- P` → `300 P`.
> - 검증: `flutter analyze` 0 · `flutter test` **217 통과** · 골든 61장(장수 불변, 다수 갱신).
> - **남은 것(보고)**: 예약은 **한 줄 기준**이라 내용이 여러 줄 도착하는 구역(댓글·수업 많은 날·
>   코치 명단 2건+)은 **첫 도착에서 한 번** 늘어난다(네 번 밀림 → 한 번). 완전 고정은 내부 스크롤이
>   필요해 별건. 홈 최상위 `FutureBuilder` 전면 교체 1건도 남았다.

> **D67 (2026-08-27 사용자 지시 "네이버 로그인이나 다른 SaaS 처럼 통일된 화면이야. 아이디 입력칸 비밀번호 입력칸은 고정 같은 자리에 있고 밑에 회원가입신청도 고정 같은 자리고, 그러니까 변수가 생길 부분은 변수 자리를 미리 만들고 나머지는 고정 위치에 깔끔하게 보이길 원해" + 후속 "고정 레이아웃, 변수는 변수칸을 만들어서 저장한다 이런 기술을 뭐라고 하는데? 또 이걸 SSOT에 저장하고 지키게 하고 싶은데") — 로그인 화면 고정 레이아웃 + 레이아웃 안정성 규칙 신설 (앱만).**
>
> **용어 (이 이름만 쓴다 — 새 별칭 금지, §0-B)**: 밀리는 현상 = **레이아웃 시프트(layout shift)**,
> 계량 지표 = **CLS(Cumulative Layout Shift, Core Web Vitals · 좋음 ≤ 0.1)**, 해결 기법 =
> **공간 예약(space reservation)**, 목표 상태 = **레이아웃 안정성(layout stability)**.
> 로딩 중 모양만 보여 주는 것은 **스켈레톤(skeleton screen)** — 이번 건과 다른 기법이다.
>
> **(1) 밀림 4대 원인 제거 (`lib/features/auth/login_screen.dart`).** 상태가 바뀌어도
> 아이디칸·비밀번호칸·로그인 버튼·회원 가입 신청·약관의 y 가 움직이지 않는다.
> - **조건부 상단바** — `appBar: Navigator.canPop(context) ? HkAppBar() : null` 은 들어온 경로에
>   따라 본문을 통째로 52px 밀었다. `Scaffold.appBar` 를 버리고 body 최상단에 높이 고정 띠
>   **`HkBackBar`**(신규 HKit) — 띠는 항상 있고 **화살표만** 조건부, 구분선 없음(빈 띠가
>   '죽은 줄'로 보이던 이유). 뒤로가기는 `Navigator.maybePop` + tooltip '뒤로', 터치 48.
> - **생겼다 사라지던 안내·에러 블록** — `if (_error != null) ...[HkInlineError]` → 고정 높이
>   **`HkNoticeSlot`**(신규 HKit, `HyphenTokens.noticeSlotH = 56` = caption 2줄+패딩+보더).
>   세션 만료 안내(D59)와 로그인 실패가 같은 예약 자리를 쓴다. 표시는 종전 `HkInlineError`.
> - **입력칸 검증 에러** — 두 `TextFormField` 에 `helperText: ' '` + `errorMaxLines: 1` 로
>   에러 줄을 **항상 예약**(Flutter 표준 공간 예약). 높이가 같아야 하므로 테마
>   `inputDecorationTheme.helperStyle` 을 `errorStyle` 과 같은 micro 로 맞췄다 (`theme.dart`).
> - **로딩 스왑** — `_busy ? HkLoading() : HkButton.primary(...)` (36↔22 차이만큼 밀림) →
>   **`HkButton(busy: true)`**: 자리를 그대로 둔 채 글자만 스피너, 면은 primary 유지(비활성
>   회색으로 내리면 같은 자리에 있어도 '사라진 것'으로 읽힌다). `HkLoading` 에 `color` 슬롯 추가.
> - 곁들임: 가로는 `ConstrainedBox(maxWidth: HyphenTokens.formMaxW = 420)` + 중앙 정렬
>   (폰 360 에서는 무영향, 태블릿에서 입력칸이 늘어지지 않게). 본문은 종전대로
>   `SingleChildScrollView` — 키보드가 올라오면 스크롤되고, 그 밖에는 위에서부터 고정.
> - **로그인 로직·인증 흐름·문구 뜻은 그대로** (레이아웃 안정화 전용). 로고 없음(D42)·
>   창구 하나(서버 `kind` 판정)·한글 명사형 카피 유지.
>
> **(2) 규칙화 — SSOT + 자동 게이트.**
> - `docs/DESIGN-SSOT.md` **§레이아웃 안정성 — 공간 예약 (강제)** 신설: 원칙 한 줄
>   ("상태가 바뀌어도 요소의 y 좌표가 변하지 않는다. 변하는 것은 미리 자리를 잡아 둔다") +
>   위 4대 패턴과 각각의 정답 + 적용 대상(상태에 따라 내용이 바뀌는 모든 화면) + 검증 방법.
> - 재사용 게이트 `test/golden/layout_stability.dart` — `expectStableAnchorY(tester,
>   states:, anchors:)` 가 상태 N개를 렌더하며 앵커 위젯의 `getTopLeft().dy` 를 비교한다
>   (PNG 스캔보다 정확·빠름: 안티에일리어싱·색 변화에 안 흔들리고, 어느 앵커가 몇 px
>   밀렸는지 바로 짚는다). 앵커는 `LoginScreen.kIdField` 등 `Key` 상수.
> - 상태 절차 정본 `test/golden/login_states.dart` — 골든(픽셀)과 y 검사가 **같은 절차**를
>   공유한다. 골든 하네스 `FakeBossApi` 에 `failures`(경로별 예외)·`hold`(로딩 붙잡기) 추가.
> - 회귀: `flutter analyze` 0 · `flutter test` **202**(198 +3 골든 +1 레이아웃 게이트) ·
>   골든 **58 → 61장** (`state_17_login_error`·`state_18_login_validation`·`state_19_login_busy`
>   신규, `common_08_login`·`state_09_login_remembered`·`state_16_coach_session_expired` 재생성) ·
>   갤러리·SECTIONS 갱신 · 확인용 `build/login_layout_check.html`.
> - 6 상태 y 실측(논리 px): 아이디칸 247.0 · 비밀번호칸 343.0 · 로그인버튼 485.0 ·
>   가입신청 541.0 · 약관 585.0 — 전 상태 동일 (골든 PNG 독립 스캔도 같은 결론).

> **D66 (2026-08-27 사용자 승인 "로그인 화면 하나로 합치는 것이 맞습니다. 앱을 열면 바로 아이디·비밀번호가 나오고, 그 아래에 '회원 가입 신청' 을 작은 줄로 두면 됩니다" + 후속 지시 "내정보 메뉴에서, FAQ, 목표, 고객지원, 데이터 초기화, 버튼 삭제 및 안에 내용까지 삭제") — 앱 첫 화면 = 로그인 · 내 정보 메뉴 4건 삭제 (앱만).**
>
> **(1) 로그인 통합 — 갈림길 화면 폐지.** 앱을 열면 스플래시 다음이 곧바로 로그인이다.
> - 삭제: `lib/features/auth/signup_screen.dart`(SignupScreen) + `/signup` 라우트 + 골든
>   `common_05_signup`. 소셜 로그인이 v1.33 에서 내려가고(`_kShowSocialLogin=false`) 코치 입구도
>   D42(v3.19)에서 없어져, 남은 건 [로그인]·[회원 가입 신청] 두 버튼과 약관 링크뿐인 껍데기였다.
>   위쪽 `HkEntryLogoGap` 자리가 로고 없이 비어 있던 문제도 화면과 함께 사라진다.
> - 이동: '회원 가입 신청'(→ `/signup/self`)은 로그인 화면 **버튼 아래 작은 줄**(HkButton.tertiary)로,
>   이용약관·개인정보처리방침 두 링크는 그 아래로. 법적 고지라 위치만 옮기고 목적지는 그대로
>   (`TermsScreen`·`PrivacyScreen`). 가입 신청 흐름(`SelfSignupScreen`)은 손대지 않았다.
> - 진입점 전환 3곳: 스플래시 미로그인(`splash_screen._onStart`) · 회원 로그아웃
>   (`mypage._confirmSignOut`) · 코치 세션 만료(`coach_shell._leaveExpired`, D59). 특히 D59 는
>   `/signup` 위에 `/login` 을 얹던 2단 push 였는데, 인자를 실은 `pushNamedAndRemoveUntil` 1단으로
>   합쳤다 (만료 안내 문구는 그대로 뜬다 — 골든 `state_16` 재생성).
> - **`social_auth_service.dart` 는 존치** — 실 OAuth(네이버·구글) 복구용 자산이고, 되살릴 때는
>   로그인 화면에 `HkSocialButton` 두 줄을 얹는다. 지금은 앱 안 참조 0건 (유일 소비처가 SignupScreen 이었다).
> - 창구는 여전히 하나다 (D42): 로그인 화면에 브랜드 로고 없음 · 역할 선택 없음 · 코치/회원 판정은 서버 `kind`.
>
> **(2) 내 정보 메뉴 4건 삭제 (앱 화면만).**
> - **목표** 행 + `lib/features/goals/goals_screen.dart` · **FAQ** 행 + `mypage/faq_screen.dart` ·
>   **고객지원** 행(카카오톡 채널 `launchUrl` — 화면 없음, 행만) · **데이터 초기화** 버튼 +
>   `_confirmReset`(`prefs.clear()` → `/splash`). 골든 `member_16_goals`·`member_17_faq` 삭제,
>   `member_05_profile_menu_open` 재생성 (남은 메뉴 = 전자계약서·히스토리·최고 기록·개인정보처리방침·이용약관).
> - **서버는 그대로** — 목표 API(`/api/v1/member/me/goals` 계열)·DB 는 손대지 않았다.
>   `core/goals_state.dart`(GoalsState) 도 존치: 착용 칭호(`wornTitle`)를 같은 상태가 들고 있어
>   내 정보 이름 밑 배지와 업적 화면이 계속 쓴다. 사라진 것은 **목표를 편집하던 화면**뿐이다.
> - D65 가 존치로 못 박았던 '목표' 는 이 지시로 **앱 메뉴에서만** 뒤집힌다 (서버·DB 존치라 D65 의
>   "데이터 손실 0" 원칙과 충돌하지 않는다). 재제안 금지 대상은 나머지 5종 그대로.
>
> - 회귀: `flutter analyze` 0 · `flutter test` **198** (골든 테스트 3개 삭제로 201→198) ·
>   골든 **61 → 58장** · 갤러리·`tool/golden_gallery.py` SECTIONS 갱신 · 실기(갤S22) 릴리즈 APK 확인.

> **D65 (2026-08-27 사용자 "아니 놔둬, 지금있는것까지는 괜찮아") — 4기둥 밖 잔여 기능 6종 존치 확정.**
>
> - D64 가 "아직 결정 안 한 4기둥 밖 덩어리" 로 올렸던 **락커 · 통계 · 결제/환불 · WOD 소셜
>   (리더보드·댓글·코치 피드백·내 이전 기록) · 목표/최고기록/히스토리 · 전자계약서** 는 **제거하지 않는다.**
>   케어 필요(D60)·개인정보/약관(D17)도 마찬가지로 존치.
> - **4기둥의 성격 정정**: 4기둥은 **앞으로 새로 만들 것**을 거르는 게이트이지, **이미 있는 것을
>   걷어내는 근거가 아니다.** 3면 CLAUDE.md 대전제 5번의 "4기둥 밖은 제거 대상" 문구를 그에 맞게 교체.
>   집행된 제거는 D63(인스타·로고)·D64(사문 코드)까지가 끝 — **재제안 금지**.
> - 코드 변경 0 (문서·룰만). 이 결정은 메모리 `project-four-pillars-scope` 에도 반영.

> **D64 (2026-08-27 — D63 과 같은 지시의 후속) — 4기둥을 3면 대전제 5번으로 승격 + 검증된 사문 코드 제거.**
>
> - **스코프 정본 승격**: 4기둥(공지사항·쪽지·수업 예약·수업 공개+업적)을 `apps/facing-app/CLAUDE.md
>   §제품 스코프` 로 재작성하고, **3면 CLAUDE.md 공통 대전제에 5번 항목으로 추가**(구 3기둥 서술은
>   "앱 셸 탭 축" 으로 격하·존치). 받침 목록(회원 명단·가입 승인 · 회원권 · 수업 종류/시간표 · 인증 ·
>   업적/포인트 설정 · 출석 · 체육관 1곳 식별)을 명문화 — 지우면 기둥이 무너지므로 제거 금지.
> - **감사 오탐 교훈 (§5 탐색 경제성)**: 4기둥 대조 감사가 "사문" 으로 지목한 것 중 **2건이 실제로는
>   살아 있었다** — `openPanelB`(`achievements_screen.dart:133` 이 호출) · `services/leaderboard.py`
>   (`api/admin.py`·`services/wod_compare.py` 가 import). 이후 **지우기 직전 호출처 재확인**을 규칙으로
>   못박고(대전제 5번), 실제 제거는 상위가 직접 grep 으로 확인한 목록만 집행.
> - **제거 집행 (참조 0 재확인분만)**: 앱 빈 폴더 3(`pacing_result`·`presets`·`wod_builder`) ·
>   앱 죽은 repository 메서드 6(`GymRepository.search` · `updateProfileInfo`/`getProfileInfo` —
>   **서버 라우트 자체가 없었음** · 초대코드 3종) · 백엔드 죽은 서비스 3(`cohort.py`·
>   `marketing_dashboard.py`·`receipt_pdf.py`) · 쪽지 그룹 라우트 4(2개만 지우면 "그룹은 못 만드는데
>   멤버는 추가 가능" 이 되므로 CRUD 전량) · 초대코드 라우트 3 + `_generate_invite_code` ·
>   다중 체육관 전환 2면(`api/admin.py switch-gym` + PC `/api/proxy/switch-gym`).
>   README §제거된 기능 대장 **24~30번** 등재.
> - **지우지 않은 것 3건 (재확인에서 살아 있음이 드러남)**: `models/wod_session.py`(`wod_score` 의 FK
>   대상 — 지웠으면 부팅이 깨짐) · `models/membership_plan.py`(G04 마이그레이션 회귀를 지키는
>   테스트가 실사용) · `/gyms/search` 라우트(`sanity_check.py` 운영 점검 + persona E2E 헬퍼).
>   또 `post_note` 의 `target_type='group'` 분기는 발송 라우트가 아직 써서 휴면 존치.
> - **DB 는 건드리지 않았다** — 테이블 DROP 0건. `gym_groups`·`gym_group_members`·`gyms.invite_code`·
>   `wod_session`·`gym_membership_plans` 전부 휴면. 사용자 데이터 손실 0 (D63 의 instagram 휴면과 동일 원칙).
> - **아직 결정 안 한 4기둥 밖 덩어리 (보고만, 손대지 않음)**: 락커 · 통계 · 결제·환불 · WOD 소셜
>   (리더보드·댓글·코치 피드백) · 목표/최고기록/히스토리 · 전자계약서(D27) · 케어 필요(D60) ·
>   개인정보·약관(법적 의무라 존치 권고). 제거 시 없어지는 총량 추정 = PC 페이지 5·앱 화면 8·
>   백엔드 라우트 약 40·테이블 약 20.
> - 검증: 백엔드 pytest **291 passed, 1 skipped**(증감 0) · Flutter **201 통과**·analyze 0·골든 61장 무손상 ·
>   PC design lint baseline 유지 · 백엔드 재부팅 `/health` 200·Traceback 0, 삭제 라우트 4종 404·존치 라우트 200 ·
>   PC 3면 렌더·콘솔 0.

> **D63 (2026-08-27 사용자 결정 "이건 코치와 회원 간의 공지사항·쪽지·수업 예약·수업 공개(+업적) 그게 끝이야. 여기에 위배되거나 필요없는 건 없애도 된다니까") — 체육관 프로필 인스타그램·로고 이미지 URL 제거 (3면).**
>
> - **판단 근거**: 두 칸은 4기둥(공지·쪽지·수업 예약·수업 공개 +업적) 어디에도 속하지 않고,
>   앱에 **이미지를 그리는 코드가 아예 없다**(`Image.network` 0건 · `GymProfile.instagram`
>   참조 위젯 0건). 코치가 채워도 어느 화면에도 안 나오는 입력칸이었다 (D62 미결 항목).
> - **PC** `web/facing-admin/templates/settings_gym_profile.html`: 입력칸 2개 + 라벨 +
>   `FIELD_MAP` 2행 삭제 (16 → **14 필드**). 나머지 14칸 저장 경로는 그대로.
> - **백엔드** `services/hyphen`: `api/gym.py` `_profile_dict` 직렬화 2줄 · PATCH 수용
>   2블록 삭제. 시드도 정리 (`seeds/personas.json` 2곳 · `seeds/seed_personas.py`
>   생성자 2인자 · `seeds/home_gym.py` `_LEGACY_PROFILE`/`_NEW_PROFILE`).
> - **DB 컬럼은 남긴다 (휴면)**: `gym_profiles.instagram`·`logo_url`. 이 repo 는 alembic
>   이 없고 `models/base.py migrate_db()` 의 손수 `_migrate_*` 함수로 부팅 때 스키마를
>   맞춘다. 운영 DB 에 코치가 실제로 넣은 값이 들어 있어 DROP 은 되돌릴 수 없는 데이터
>   손실이다 — **사문 컬럼 < 데이터 손실**. `auto_approve_joins`(2026-08-25) 와 같은
>   처리이며 모델 파일에 휴면 주석을 박았다. 되살리려면 사용자 결정부터.
> - **앱** `apps/facing-app`: `models/gym.dart` 필드·생성자·`fromJson` 파싱 삭제
>   (`isEmpty` 는 원래 두 필드를 안 봤다) · `gym_repository.dart`·`gym_state.dart` 의
>   **`updateGymProfile` 두 메서드 통째 삭제** — 폰에 체육관 프로필 편집 화면이 없어
>   `lib/` 호출처 0건이었다 (편집 창구는 PC 하나). 골든 fixture 1줄도 정리.
> - **안내문 정정 (사실만)**: 종전 "회원 앱의 체육관 소개 화면에 그대로 보여요" 는 거짓이었다 —
>   수업 시간표·모토는 소개 화면이 아니라 **수업 탭 맨 위 카드**(`GymInfoCard` →
>   `box_wod_screen.dart`)에 나온다. 섹션마다 어느 화면에 나오는지 `.setting-desc` 로 적었다.
> - 회귀: 백엔드 pytest **291 passed, 1 skipped**(증감 0) · Flutter analyze 0 · **201 통과**,
>   골든 **61장 그대로**(두 필드가 아무 화면에도 안 그려졌다는 증거) · PC design lint
>   인라인 7·블록 10 유지 · sync --check 드리프트 0.

> **D62 (2026-08-27 사용자 지시 "이원화 없는지 교차검증해봐 · 고아버튼이나 틀린게 있는지 찾아봐" → 확정 21건 보고 → "1,2번 까지하고 3번은 나에게 다시 보고") — 설정 9화면 교차검증 후 결함 수리 + 3면 표기 통일.**
>
> - **교차검증(4갈래)**: 용어 이원화 · 고아 버튼 정적 대조 · fetch↔프록시↔백엔드 3단 계약 · 실물 클릭 순회.
>   확정 21건. **깨끗한 축** = 없는 라우트 0 · 프록시 메서드 불통과 0 · 응답 필드 경로 불일치 0 ·
>   미정의 핸들러 0 · 위임 분기 누락 0 · 콘솔 에러 0 · 저장 실패를 성공으로 표시하는 자리 0.
> - **P1-A 회귀 수리 (D61 자책)**: 마스터 OFF 시 `.setting-list.is-off{pointer-events:none}` 가 같은
>   컨테이너에 들어온 '문구 수정' 까지 잠갔다. 잠금을 토글로 좁힘(`.is-toggle-locked .toggle`) +
>   키보드 경로 가드 + 하위 토글 시각 상태를 `master && stored` 로(저장값은 보존 — 마스터 재점등 시 조합 복원)
>   + 이유 한 줄. **알림을 꺼 둔 채 문구만 다듬는 순서가 정본.**
> - **P1-C 틀린 버튼**: 수업 안내 '삭제' = 소프트 삭제임을 문구·동작에 반영하고 `settings_plans` 정본 패턴
>   (활성=삭제 / 비활성=복구 · "삭제(비활성) N개 보기" 토글 · 기본 숨김) 이식 — 죽은 재클릭·복구 불가 동시 해소.
>   락커 타일 `×` 키보드 경로(부모 keydown `e.target!==e.currentTarget` 가드).
> - **P1-C4 이벤트 구분 모순 (UI+백엔드 양면)**: PC 는 `kind='event'` 선택 시 매주 시간표·4주 자동등록
>   안내를 감추고 저장 시 규칙 diff 를 건너뛴다(기존 규칙 행은 **지우지 않음** — `_prune_future_slots` 는
>   되돌릴 수 없으므로). 실질 차단은 백엔드: `api/class_schedule_rules.py materialize_rules` 가
>   `tmpl.kind == 'event'` 규칙을 건너뛴다(행 보존 — 'regular' 로 되돌리면 그대로 재개).
>   테스트 2건 신설(event 0건 생성 · regular 29건 회귀 방지).
> - **P1-D 실패의 빈 상태 위장 4건**: 락커 목록 · 업적 규칙/대기함 · 수업 안내 시간표 규칙 · 계약 발급 모달.
>   전부 `res.ok`·`data.ok` 검사 + try/catch 로 **"불러오기 실패 — 다시 시도"** 표시(기존 `.table-msg.is-error`
>   재사용). 계약 발급은 실패 시 **모달을 열지 않는다**(종전 catch 는 401/503 이 정상 JSON 이라 발동 못 했음).
>   락커 실패 화면에서 '+ 일괄 추가' 유도 문구 제거 — **코치가 다시 만들게 두는 것이 이 병의 실피해**였다.
> - **P2 표기 통일 (3면)**: 앱 희귀도 COMMON/RARE/EPIC/LEGENDARY → 기존 `RarityPalette.ko`(일반/희귀/에픽/전설,
>   새 맵 신설 금지 §0-B) 6곳 · 회원권 상태 Active/EXPIRED → 이용중/만료 · 알림함 → **쪽지함**(코치 '쪽지' 와 통일,
>   PC `messages.html` 안내문 동반) · 계약 → **전자계약서** · 폴백 문자열 `'BOX'`→'체육관'·`'Leave failed.'`·
>   `'AUTO'/'COACH'/'NOTICE'` 등 영문 코드값 노출 정리. 백엔드 사용자 노출 에러 "클래스"→"수업" 8곳
>   (전부 `ClassSession` 조회 실패 = 실제 수업 1회) · 알림 변수 `{상품명}`→`{회원권}`(템플릿+호출부 동시, §0-B).
>   PC 객체명 "수업 종류" 통일(페이지명 '수업 안내' 는 사용자 호칭이라 유지) · 정지 표기 3종 → 일시정지/일시정지 중.
> - ~~**미결(사용자 결정 대기)**: 체육관 프로필의 **인스타그램·로고 이미지 URL**~~
>   → **D63 (2026-08-27) 로 해소 — 두 칸 제거.**
> - **다음 후보(보고만)**: 알림 설정 JSON 키 `reservation`(=수업 취소)·`cancel`(=회원권 해지) 개명 —
>   PC 토글 키·기존 설정 행 마이그레이션 동반. (앱 휴면 편집 경로 `GymState.updateGymProfile` → D63 에서 삭제.)
> - 검증: 백엔드 pytest **291 passed**(신규 2) · Flutter **201 통과**, 골든 61장 갱신(장수 증감 0) ·
>   PC design lint 인라인 7·블록 10 유지 · 실패 경로 재현 13/13 · 수업 안내 실물 28단계.

> **D61 (2026-08-27 사용자 지시 — PC 웹 손질 6건: "공지·일정 조금 더 컴팩트하게 · 수업 안내 수정 모달 글자 잘림 · 체육관 프로필 다른 화면 같은 느낌 · 회원권/횟수권 라인 구분 · 포인트 설정 '프리셋' 엉뚱한 말 · 알림 문구 내가 수정할 수 있게") — 알림 문구 체육관별 덮어쓰기 + PC 5화면 정돈.**
>
> - **알림 문구 편집 (백엔드 `services/hyphen`)**: 기본 문구는 그대로 `note.py NOTE_TEMPLATES` 코드 상수,
>   체육관별 덮어쓰기는 `gym_notification_settings.settings.templates` JSON
>   (`{"payment":{"title","body"}, "expiry":{"title","variants":{"d7","d3","d0"}}, …}` — 필드 단위 부분 덮어쓰기,
>   기본과 같거나 빈 값은 키째 삭제 = 되돌리기). 스키마 변경 없음. `render_note(…, gym_id=)` 가 덮어쓰기 우선,
>   `send_member_note` 가 설정 1회 읽어 게이트+렌더 — 발송 4지점 자동 반영. `describe_templates(gym_id)` 응답에
>   `variables[]`·`custom`·`default_title/body`·(expiry) `variants[{key,label,body,default_body,custom}]` 추가.
>   PATCH `templates` 검증 = 제목 120자·본문 500자·허용 변수 외 `{x}` → 400 `INVALID_TEMPLATE`
>   ("사용할 수 없는 변수: {x}. 사용 가능: …"). 라벨·발송 시점(`when`)은 편집 대상 아님. pytest 289.
> - **PC 알림 설정**: 항목 카드 '문구 수정' → 카드 안 인라인 편집(제목·본문, 만료는 7일 전/3일 전/당일 3칸,
>   변수 칩 클릭 = 커서 삽입, 저장·취소·기본 문구로) · 덮어쓴 항목 '수정됨' 배지. 새 CSS 0.
> - **PC 정돈 5건**: 공지·일정 = 달력 셀 34→26·막대 32→24·표 셀 패딩 축소 + `.ann-stack`(달력+표가 뷰포트
>   안에서 나눠 쓰고 표는 내부 스크롤) → 1440×900·1280×800 페이지 스크롤 0 · 수업 안내 수정/추가 모달 =
>   `<input type=time>` 고정폭 112 → auto(min 120) — 한국어 로케일 "오전 06:00" 분 자리 잘림 해소 ·
>   체육관 프로필 = `.page-narrow` + `.card p-16-20` 2장(기본 정보·이용 안내) + `.section-label`, 라벨 위 간격
>   `--sp-3` (형제 설정 화면 골격) · 회원권 설정 = 표 하나 안 그룹 헤더 행 2개("회원권 · 기간제"/"횟수권",
>   판정 `plan_type=='session_based' || session_count`), 횟수권 행 바탕 `color-mix(--border 40%, --bg)`,
>   빈 그룹 한 줄 · 포인트 설정 = 노출 문구 "프리셋" → **"적립 항목"** (버튼·모달·빈 상태·미리보기·에러,
>   회원 상세 적립 모달 라벨 "적립 규칙" 도 같은 말로 — JS 변수·API·PointRule 이름은 그대로).
> - 앱(폰) 변경 0. 검증: 6 작업자 격리 chromium 실클릭(추가→수정→적립→삭제 · 문구 저장→400→되돌리기 · 실제 결제
>   1건 등록 시 수정 문구로 쪽지 도착) · design lint 인라인 7·블록 10 유지.

> **D60 (2026-08-26 사용자 지시 — PC 웹 개편 6건 + "카카오 알림톡 필요 없음, 앱 쪽지로. 야간 발송 금지 없애고 보내는 시간은 오후 3시로 통일. 각 알림마다 뭐가 발송되는지 보여라") — 알림 = 앱 쪽지 하나 · PC 사이드바/공지·일정/케어/수업/알림 설정 개편.**
>
> - **알림 채널 = 회원 앱 쪽지 하나** (카카오 알림톡·NHN 폐기 — `_archive/dead-2026-08-26/`). 정본 =
>   `services/hyphen/api/notifications/note.py`: `NOTE_TEMPLATES`(expiry·payment·reservation·cancel — 키 =
>   설정 토글 키) · `send_member_note()` (발신 = `admin._staff_device_hash` owner 해시 → 회원 `device_hash`,
>   `GymCoachNote kind='note'` + Recipient + SSE `note.new` + AuditLog `note.auto`) · `describe_templates()` ·
>   `SEND_HOUR = 15`. 발송 4지점(해지·수업 취소·결제 입력·만료)이 전부 이 함수 하나.
> - **발송 시각**: 만료 안내(D-7·D-3·D-0)는 매일 **15:00 KST** 잡 하나(`daily_expiry_notify_15`, AuditLog 로
>   같은 날 멱등). 결제·수업 취소·해지는 **사건 즉시** — "뭐든지 오후 3시" 를 수업 취소 통보에까지 적용하면
>   다음날 3시에 알리게 되어 무의미하므로 일일 배치에만 적용 (Claude 판단, 사용자 재결정 가능).
>   야간 발송 금지(quiet_start/quiet_end) 개념 삭제 — 설정 키·검증·UI 전부 제거.
> - **설정 API** `notification-settings` GET/PATCH 응답에 `send_hour`·`templates[{key,label,when,title,body}]`
>   동봉 — PC 알림 설정 화면이 항목마다 **실제 발송 문구**를 보여 준다 (사용자 "뭐가 발송되는지 알아야 토글을
>   켠다"). `alimtalk-logs` → `notification-logs` (note.auto 최근 7일).
> - **PC 웹 (web/facing-admin)**: 사이드바 = '일정 달력'+'공지사항' → **'공지 · 일정'** 한 화면
>   (`/announcements` = 월 달력 막대 + 공지 표 + 모달, 막대 클릭 = 같은 화면 수정 모달, `/calendar` 는 302) ·
>   '처음 시작하기' 링크 삭제(라우트 존치) · 푸터 = 로그아웃만(문의하기 카카오톡·평일 10–18시·v1.0 베타 삭제) ·
>   케어 필요 = 카드 그리드 → **표 2개**(케어 필요·만료 임박, 긴급 행 좌측 rail) · 수업 안내 매주 시간표 =
>   규칙당 **요일 스트립 7칸 + 시각** 한 줄, '+ 시간'·× 삭제, 편집은 '수정' 모달 안 "매주 시간표" 섹션
>   (요일 칩·시각·행 추가/삭제, 저장 시 규칙 diff → POST/PATCH/DELETE) · 수업 관리 시간 축 = 수업 있는 시간
>   **앞 1시간 ~ 끝나는 시각**만, 2시간 이상 빈 구간은 접힌 행("12:00 ~ 16:00 비어 있음 · 펼치기"), 수업 없는
>   주는 06~20.
> - 앱(폰) 변경 0 — 자동 쪽지는 기존 쪽지함에 코치 발신으로 도착. 골든 변경 없음.
> - 검증: 백엔드 pytest 270 passed · PC 6화면 playwright 실클릭(코치 로그인) · design lint 인라인 8→7.

> **D59 (2026-08-26 사용자 선택 "옵션 1" — 인계장 대기 1번) — 폰 코치 셸 세션 만료 시 로그인 화면 자동 이동.**
>
> - 증상: 코치 셸(예약 현황·쪽지)에서 서버 세션이 만료되면 `require_staff` 의 401 UNAUTHORIZED
>   가 `HkErrorState('로그인이 필요합니다.' / 다시 시도)` 로만 떠서 갇혔다 — 우상단 로그아웃
>   아이콘을 눌러야만 나갈 수 있었다.
> - 처리 (폰 3곳, 백엔드·PC 변경 0):
>   1. `BossApiClient._checkSession` — 인증 요청 응답이 `401 + code UNAUTHORIZED` 면
>      `BossAuthState.expire()` (저장 로그인 삭제 + notify). `_unwrap`·`getList` 공통 — 어느
>      코치 API 든 한 곳. 로그인 창구(`_loginTo`, INVALID_LOGIN)는 이 길을 타지 않는다.
>   2. `CoachShell` — `BossAuthState` 리스너: 로그인이 풀리면 다음 프레임에 로그아웃과 같은
>      뒷정리(`DeviceIdService.reset` · `GymState.resetLocal`, S1) 뒤 `/signup` 위에 `/login`
>      을 얹는다. 로그아웃 버튼 경로는 `_leaving` 빗장으로 이중 이동 방지. `main.dart` 의
>      기존 리스너가 스태프 SSE 를 멈춘다.
>   3. `LoginScreen` — 라우트 인자 `{argNotice: noticeSessionExpired}` 를 에러 줄
>      (`HkInlineError`) 자리에 한 번 띄운다: "로그인이 만료되었습니다. 다시 로그인해 주세요."
>      다음 로그인 시도에서 사라진다.
> - 골든: `state_16_coach_session_expired` (states 2부 — 대시보드 401 → 로그인 화면 + 사유).
>   하네스 `routes` 주입구 신설 (화면이 스스로 라우트를 넘어가는 상태 캡처용) ·
>   `FakeBossApi.unauthorizedPaths` · `FakeBossAuth.loggedIn` 가변.
> - 안 한 것: 회원 API(X-Device-Id)에는 세션이 없어 해당 없음. 코치 쪽지 탭·가입 신청은
>   기기 페어링(gym_manager_devices)이라 세션 만료와 무관 — 대시보드·주간 수업·명단이 대상.

> **D58 (2026-08-26 사용자 지시 "해지·일시정지·만료되면 그 권으로 예약된 건 사라지게" + "예약은 매일 전날 오전 11시부터 — 보기는 언제든지, 월요일 수업은 일요일 11시부터 일괄") — 회원권 무효 시 예약 소멸 + 예약 오픈 시각.**
>
> - **예약 소멸 (`classes.revoke_uncovered_reservations`)**: 회원의 **앞으로의** confirmed 예약·미승격 대기 각각을
>   예약 게이트와 같은 `pick_membership`(자기 행 점유 제외)로 다시 판정 — 그날을 덮는 유효권이 없으면 취소
>   (`late_cancel=False`, 횟수 점유 해제) + 빈자리 대기열 승격 + SSE `member_reservation_cancelled`. 호출처 =
>   즉시 해지(`admin_cancel_membership` — **환불은 소멸 뒤 잔여로**: 체육관이 지운 예약 몫은 돌려준다) ·
>   정지(`admin_pause_membership_v2`) · 수정(`admin_edit_membership` — 기간 단축·횟수 축소) · 자연 만료는
>   `sweep_uncovered_reservations` (expiry_scheduler 매시 :05 + 부팅 직후, 멱등). 기간 만료 시 해지는 만료일까지
>   유효하므로 즉시 소멸 없음(만료 뒤 스윕). 응답 `revoked: [{reservation_id, class_session_id, title, start_at}]`,
>   PC 토스트 "예약 N건 자동 취소".
> - **예약 오픈 시각 (`gym_class_settings.booking_open_hour`)**: 수업 **전날** 이 시 정각에 그날 수업 예약·대기 신청이
>   일괄로 열린다 (`classes.booking_open_at` = 수업일−1 의 hour:00, 체육관 시간대). 전이면 409 `BOOKING_NOT_OPEN`
>   "예약은 8/27 11:00 부터 가능합니다." — 신규·재활성·대기 신청 세 진입로, 승격은 예외(이미 열린 수업의 빈자리).
>   NULL/행 없음 = 제한 없음(테스트·신규 체육관). 마이그레이션 `_migrate_booking_open_hour` 가 기존 체육관 행을
>   11 로 채우고 행 없는 체육관엔 행을 만든다. PC 예약 설정 "예약 오픈 시각" 셀렉트(제한 없음 / 전날 00~23시,
>   새 행 기본 11). 목록 응답 `booking_open_at` 동봉 → 폰 `ClassSessionDto.isBookingNotOpen` → **'예약' 배지는
>   그대로 서고, 누르면 캐릭터 스낵바 '예약 가능한 시간이 아니에요' + 둘째 줄 'M/D HH:MM 부터'**(D82 · 2026-08-29 — 구 '오픈 전'
>   배지 폐기. 시각은 서버 `booking_open_at` 그대로). 보기는 종전대로 언제나.
> - 회귀: 서버 `tests/test_booking_window_revoke.py` 7건 (오픈 전 차단·대기 신청 차단·목록 open_at·NULL 해제·
>   즉시 해지 소멸+환불 3/3·정지 창 안만 소멸·기간 단축 소멸+승격·스윕 멱등) + 기존 환불 테스트 기대값 갱신 —
>   265 passed 1 skipped. `test_reservation_policy._set_limit` 은 오픈 시각 None 고정(시각 비의존). 앱 199+1 ·
>   골든 60 (`state_15_class_booking_not_open` 신규).
>   - 보고만: **자동 노쇼는 추후** (사용자 결정 20:28 "지금 구현하기는 어렵다") — 시스템이 출석을 아는 경로는 코치 명단 체크뿐(QR 폐지)이라
>     노쇼 면제 규칙은 코치가 찍을 때만 성립. 재개 안 = 명단을 한 명이라도 찍은 수업만 종료 1시간 뒤 나머지를 노쇼로 굳힘.
>   - **정지 중 열람 = 허용 (2026-08-26 21:29 사용자 결정 "정지하면 열람가능, 만료회원은 만료불가 형식")**: 일시정지 회원은
>     수업 내용(게시물)을 그대로 보고 **예약만** 막힌다(D58 소멸). 만료·해지 회원만 자물쇠("회원권 만료. 갱신 후 열람.").
>     정본 = `gym.py` WOD 목록 locked 판정 `status=active AND end_date>=오늘` — 정지는 status 가 active 로 남아 자동 통과.
>     정지 전용 잠금 분기 신설 금지. 코치 PC 실주행(COACH 계정 정지→폰 예약 소멸→해제) 캡처 = `project/hyphen-journey-2026-08-26/pause/`.

> **D57 (2026-08-26 사용자 지시 "횟수권도 있으면 좋겠는데 … 3회 9,900 이벤트 할 계획" + 차감 규칙 "1회 노쇼·20분 전 취소 노패널티, 2회 노쇼부터 차감, 20분 이후 취소도 1회는 노패널티 2회부터 차감") — 횟수권(세션권) 신설.**
>
> 회원권은 기간제 하나뿐이었다 (`gym_membership_plans`/`gym_plan` 에 `session_based` 유형만 휴면). 3면 같이 집행.
> - **자료**: `gym_memberships.session_total` (NULL = 기간제) · `class_reservations.membership_id`(어느
>   횟수권에서 나온 예약인지) · `late_cancel`(취소 시각이 시작 20분 전을 지났는가) ·
>   `session_charged`(지금 1회를 점유하는가). 요금제는 기존 `gym_plan.session_count` 를 PC 어댑터
>   (`/admin/gyms/<id>/membership-plans` GET/POST/PATCH) 가 드디어 노출·저장 — 횟수가 있으면
>   `plan_type='session_based'`, `duration_days` 는 **사용 기한**. 마이그레이션 `_migrate_session_pass_columns`
>   (`_migrate_class_tables` 의 표 재생성 **뒤**에 — 앞에 두면 새 컬럼이 같이 지워진다).
> - **규칙 (정본 `api/_membership.py`)**: 유효 = S5 와 동일(수업일 기준 active 기간·정지 창 밖).
>   기간제가 유효하면 횟수 안 깎음. 횟수권만 있으면 잔여 ≥ 1 인 권(만료 임박 순)에 붙이고
>   예약 확정 순간 1회 점유 → 잔여 0 이면 **예약·대기 신청 모두** 409 `SESSIONS_EXHAUSTED`
>   "회원권 횟수를 모두 사용했습니다." (유효권 자체가 없으면 종전 `MEMBERSHIP_REQUIRED`).
>   점유는 `recompute_session_charges` 가 **회원권 단위로 시간순 재계산** — 예약중·출석 = 점유 ·
>   제때 취소(시작 20분 전까지, `LATE_CANCEL_MINUTES=20`) = 해제 · 노쇼 = 회원권별 첫 1회 무료,
>   2회째부터 점유 · 늦은 취소 = 노쇼와 **별도 카운터**로 첫 1회 무료, 2회째부터 점유 ·
>   체육관 사정 취소(`admin_cancel_class`) = 해제·늦은 취소 아님. 코치가 출결을 되돌리면 다시
>   세므로 카운터 드리프트 없음 (예: 첫 노쇼를 출석으로 고치면 둘째 노쇼가 무료가 된다).
>   대기열 승격(`_promote_waitlist`)도 잔여를 재검사해 0 이면 건너뛴다.
> - **응답**: `/member/me/memberships`·PC 이력 GET 에 `session_total·session_used·session_remaining·
>   no_show_count·late_cancel_count·free_no_show_left·free_late_cancel_left` 동봉 (기간제는 null/0).
>   회원 취소 DELETE 응답에 `late_cancel·session_charged·message` — 문구("… 1회 차감" / "… 이번은
>   차감 없음")는 서버가 정본, 폰은 그대로 스낵바.
> - **PC**: 회원권 설정 표·모달에 '횟수 (회) — 비우면 기간제' 칸(+ 차감 규칙 한 줄 안내) ·
>   발급 모달은 종류를 고르면 횟수 자동 · 이력 표 종류 아래 "1/3회 사용 · 잔여 2회 · 노쇼 면제 1회 ·
>   늦은 취소 면제 1회" · 수정 모달 횟수 칸 · 회원 리스트 회원권 칸 "잔여 2회 / 3회".
> - **폰**: `Membership.isSessionPass/sessionProgress` + `coversDay` 가 잔여 0 이면 false → 주간보드
>   '회원권 필요' 배지 재사용(신규 배지 없음). 내 정보 요약 "2회 남음 · 27일 후 만료", 카드 막대 =
>   사용 횟수 비율("1회 사용 / 2회 남음") + "노쇼 면제 1회 · 늦은 취소 면제 1회 남음". 취소 다이얼로그는
>   시작 20분 전을 지났으면 "횟수권은 1회 차감될 수 있습니다" 한 줄(`kLateCancelMinutes` = 서버 상수 거울).
>   예약·취소 성공 뒤 `GymState.refreshMemberships()` 로 잔여를 다시 받는다 — 에뮬 실주행에서
>   내 정보가 앱 재시작 전까지 옛 잔여(3회)를 보이던 것을 잡음 (기간제는 영향 없음).
> - 회귀: 서버 `tests/test_session_pass.py` 10건(점유·소진·제때/늦은 취소·노쇼 무료 1회·자가 치유·
>   기간제 우선·대기 신청 차단·승격 skip·수업 취소 해제·폰/PC 응답·발급/수정) — 257 passed 1 skipped.
>   앱 199 · 골든 59 (`state_14_mypage_session_pass` 신규, 기존 58 무변화).
> - **PC·코치 계정 실주행 (18:08~18:22, 사용자 "코치거 줬다가 회원권 삭제·수정·권한·기능수정 체크")**:
>   COACH(role coach) 로 로그인해 횟수 수정(3→5→4→5→6)·즉시 해지·재발급·요금제 수정/삭제(비활성)/복구
>   전부 통과 — `require_staff` 가 boss/manager/coach 동일 (대전제 1). 발견·수정 3건:
>   (a) 즉시 해지 환불이 횟수권에도 **일수** 비례(₩9,773)로 계산 → 잔여 횟수 비례(3/5 → ₩5,940)로
>   서버 `admin_cancel_membership` + PC 미리보기 수정, 테스트 +1 (258 passed).
>   (b) PC 에서 횟수를 고쳐도 폰이 재시작 전까지 옛 잔여 — 서버가 쏘던 `membership.updated/paused/resumed`
>   를 `GymState._reloadTriggers` 에 추가 (해지·발급은 이미 듣고 있었음). (c) 해지된 회원권이 내 정보에
>   "3회 남음" 으로 남아 보임 → 활성권이 없으면 "해지됨/만료됨" + 카드 한 줄. '회원권 삭제' 는 없고
>   해지(기간 만료/즉시)만 있음 — 의도된 설계(이력 보존).
> - 보고만: PC 발급 모달에서 종류를 고른 뒤 시작일을 바꾸면 종료일이 재계산되지 않음 (D57 이전부터).
>   에뮬 `INSTALL_FAILED_INSUFFICIENT_STORAGE` — `adb install -r` 이 조용히 옛 APK 를 남긴 것이 "첫 빌드
>   누락" 의 정체 (`dumpsys package … lastUpdateTime` 으로 확인). 재설치 전 `adb uninstall` 로 공간 확보.

> **D56 (2026-08-26 사용자 지시 "전부 한국이야 걱정하지마. 이거 확실히 못박아놔") — 전 체육관 = 한국, 시간대 KST 하나로 확정. 3면 대전제 4번.**
>
> - D55 4단계의 `gyms.timezone` 은 'Asia/Seoul' **한 값만** 가진다. 서버 `api/_time.py tz_of` 는
>   이름이 무엇이든 항상 KST 를 돌려주고(다른 값은 경고 로그), 테스트
>   `test_tz_of_is_always_kst_korea_only` 가 못박는다. 컬럼은 이미 프로드에 나간 마이그레이션이라
>   그대로 두되 값은 고정 — 설정 화면 없음.
> - D55 에서 "남은 경계" 로 적었던 `func.date()` 13곳(저장 벽시계 KST 축)은 **갭이 아니다** —
>   한국 전용이라 그 축이 곧 정답. 범위 전환·다른 시간대 대비 작업은 금지 (갭대장 22차 종결).
> - 폰·PC 의 표시 변환(`toLocal()`)은 그대로 — 해외에서 앱을 열어도 같은 순간을 기기 시간대로
>   그리는 것은 '표시' 규칙이지 체육관 시간대가 아니다.

> **D55 (2026-08-26 사용자 결정 "다른곳처럼 (표준대로) 우리도 저렇게 할까?" → 예) — 시간대 표준 채택: 저장·전송 = 오프셋 포함 순간 · 표시만 시간대 변환 · '하루' = 체육관 시간대.**
>
> - **1단계 서버 직렬화 한 곳** — `api/_time.py` 신설. 응답 순간값 datetime `.isoformat()` 94줄
>   (+ DB datetime→날짜 유도 8곳 `kst_date`)을 `iso()` 로 — naive(SQLite)=KST 벽시계로 읽어 `+09:00`
>   을 붙이고, aware(Postgres)는 KST 로 변환. SQLite·Postgres 가 같은 문자열을 내린다. 날짜
>   컬럼(String(10)) 62줄은 시간대 무관이라 그대로. 클라이언트 ISO 입력 6경로(수업 생성 · 목록
>   from/to 2벌 · 공지 start/end 2벌)는 `parse_client_time` 한 곳(Z·오프셋·없음 전부 KST).
>   `date.today()` 9곳 → `kst_today()`(Railway UTC 컨테이너의 한국 저녁 하루 밀림). 파일마다 있던
>   `KST`·`_now`·`_kst_today`·`_kst_wall`·`_as_kst`·`_to_kst_naive`·`_parse_to_kst_naive` 를 이 모듈
>   하나로 (§0-B rename — 이름사전 도메인 14). 스트릭 계산의 `now_utc`(실은 KST) 이름·축 정정.
> - **2단계 앱 파서 통일** — 서버 순간값 `DateTime.parse/tryParse` 26곳(업적·공지·쪽지·피드백·
>   체육관·기록·채팅)을 `parseServerTime(...).toLocal()` 로. 표시 직전 `.toLocal()` 이라 KST 폰은
>   픽셀 동일(골든 58 무변화), UTC 기기도 같은 순간을 그린다. 전송은 수업 목록 `from/to` 를
>   `toUtc().toIso8601String()`(Z) 으로 — 오프셋 포함. 날짜 전용(회원권·락커 기간·로컬 저장값) 17곳은
>   대상 아님.
> - **3단계 테스트 시계** — `tests/*.py` naive `datetime.now()` 17곳 → `datetime.now(KST)` (UTC CI 에서
>   서버 `now_kst` 와 어긋나지 않게). `_today_class_or_skip` 자정 skip 은 시간대와 무관(2시간 뒤가
>   내일이 되는 문제)이라 유지.
> - **4단계 체육관 시간대 자리** — `gyms.timezone` String(40) default 'Asia/Seoul' + idempotent
>   ADD COLUMN. `_time.py` `tz_of·date_in·day_bounds_wall·gym_tz·gym_today·gym_date`(캐시 없음
>   §2-A-5). 하루 예약 한도는 `func.date` 대신 체육관 하루 `[lo, hi)` 범위, 회원권 게이트는
>   `gym_date`, PC 관리자 '오늘' 23곳은 `_gym_today()`(세션 체육관). PC 설정 화면은 보류(HYPHEN
>   1곳 — 값 고정). **남은 경계**: `func.date(...)` 13곳(admin 9 · classes 3 · gym 1 — 출석 통계·
>   오늘 수업 집계)은 저장 벽시계(KST) 축 — 체육관이 KST 라 지금은 동일, 다른 시간대 체육관이
>   생기면 `day_bounds_wall` 범위로 전환 (갭대장 21차).
> - 회귀: 서버 247 passed(+10 `tests/test_time_std.py`) · 앱 198 · 골든 58 무변화.

> **D54 (2026-08-26 사용자 지시 "s6 하고, s7 시각이 지나면 안보이게, s9 는 당연한 것") — 가입 폼 BACK 확인 · 서버 시각 KST 고정 · HYPHEN 전용 앱 확정.**
>
> - **S6** — 가입 신청 폼(`self_signup_screen.dart`)을 `PopScope(canPop:false)` 로 감싸 입력이
>   하나라도 있으면 '작성을 그만둘까요? / 입력한 내용이 사라집니다.' (계속 작성 · 나가기) —
>   비어 있으면 그대로 나간다. 제출 중엔 BACK 무시. 골든 `state_13_signup_back_dialog`.
> - **S7 근본 원인은 시간대 파싱** — 서버(SQLite)는 KST 벽시계를 오프셋 없이 내려주는데
>   `DateTime.parse` 가 기기 시간대로 읽어, 기기 시계가 UTC 면 20:00 KST 수업이 9시간 뒤로
>   밀려 시작이 지난 뒤에도 '예약' 이 살아 있었다(에뮬 1차 S7 = 에뮬 UTC 시계 때문).
>   `core/time_format.dart parseServerTime` — 오프셋 없으면 +09:00 고정, 있으면(Postgres
>   프로드 aware) 그대로. `ClassSessionDto`·`MyReservationItem`·명단 시트 `_notStarted`·
>   `hhmmIso` 가 이걸 쓴다. KST 폰에서는 종전과 픽셀 동일(골든 무변화), 시간대가 다른 기기
>   에서도 '시작 지남'→'종료' 배지·'예약' 숨김이 서버(KST)와 같은 순간에 일어난다.
> - **S9 는 결함이 아니라 결정** — 이 앱은 **HYPHEN 체육관 1곳 전용**. 가입 신청 대상이
>   'HYPHEN' 으로 고정된 것은 의도. 다른 체육관을 받게 되면 그때 선택 UI 를 (숨긴 채) 살리는
>   식으로 확장 — 지금은 손대지 않는다. `_kBrandGymName` 주석에 같은 결정 기록.
> - 회귀: 앱 198건 · 골든 58장.

> **D53 (2026-08-26 사용자 결정 "회원권 없으면 예약·대기 당연히 안 된다. 2번은 하고") — 회원권 게이트 (S5) + 문구·코치 UX (S8·S10).**
>
> D52 에서 보고만 했던 S5·S8·S10 을 사용자 결정으로 집행. S6·S7·S9·S11 은 계속 보고만.
> - **S5 회원권 게이트 (차단, 무료 제공 없음)** — 서버 `classes._membership_blocked`
>   한 곳: `_daily_limit_blocked` 와 같은 자리에서 신규 confirmed · 취소 후 재활성 ·
>   대기 신청 세 진입로 + `_promote_waitlist` 승격 재검사가 전부 지난다.
>   유효 = `gym_memberships.status='active'` · `start_date ≤ 수업일 ≤ end_date` ·
>   수업일이 정지 창(`pause_start ≤ 날 < pause_end`, admin.py `is_paused` 와 같은 배타
>   경계) 밖. 아니면 `MEMBERSHIP_REQUIRED`(409) "유효한 회원권이 없어 예약할 수
>   없습니다." **기준일 = 수업 시작일(KST)** ('오늘' 이 아님 — 하루 한도와 같은 축.
>   미리 결제한 다음 달 권으로 다음 달 수업은 잡히고, 이번 달 권으로 만료 뒤 수업은
>   막힌다). 회원권을 한 장도 안 준 승인 회원(에뮬 member 계정)이 예약·대기·승격을
>   전부 통과하던 갭.
>   폰: `Membership.coversDay` + `GymState.hasMembershipOn(day)` 가 같은 규칙의
>   표시용 거울 — 주간보드 `ClassLine.member` 가 그날 유효권이 없으면 예약·대기 대신
>   **'회원권 필요'** 배지(탭하면 서버 409 문구를 스낵바로 — 정책 문구는 서버 하나).
>   목록을 아직 못 받은 상태(`_membershipsLoaded=false`)는 '없음' 으로 그리지 않는다.
> - **S8 서버 노출 문구 금지어** — `api/*.py` 문자열 리터럴 117줄 '박스'→'체육관'
>   (인계장의 8곳은 표본이었고 실제는 11개 파일 — `_err(...)`·`"error":`·엑셀 컬럼
>   '박스명'). 주석·docstring·내부 식별자(인박스 등)는 그대로. 회귀 테스트는 응답
>   문구를 단언하지 않아 무영향.
> - **S10 코치 UX 2건** — (a) 코치 셸 로그아웃이 확인 없이 기기 페어링을 풀던 것 →
>   `HkDialog.confirm`(회원 `_confirmSignOut` 과 같은 골격, 문구 '이 기기와 코치 연결이
>   끊깁니다'). (b) 명단 시트 머리의 코치가 login_id('admin') 로 뜨던 것 → 서버
>   `admin_list_class_reservations` 가 `coach_name`(gym_managers.name, login_id 매칭)
>   동봉, 폰 `ClassRoster.coachDisplay` = 이름 → 아이디 폴백.
> - 회귀 게이트: 서버 `tests/test_reservation_policy.py` +8 (회원권 없음·오늘 만료·
>   미래 시작·비active·정지일·대기 신청·재활성·승격 skip) — 237 passed 1 skipped.
>   기존 예약 테스트 회원은 헬퍼가 ±60일 active 권을 기본 발급. 골든
>   `state_11_class_membership_required` · `state_12_coach_logout_dialog` 신규,
>   `boss_03`·`state_10` 재생성(코치 이름). 57장.
> - 이름사전 +2 행 (MEMBERSHIP_REQUIRED · coach_name) · 갭대장 19차.

> **D52 (2026-08-26 사용자 지시 "1 하고 다시보고") — 에뮬 실주행 갭 4건 수정 (S1~S4).**
>
> 8/26 로컬 서버 + 에뮬레이터 회원·코치 1바퀴 실주행(캡처 37장)에서 나온 갭 중
> 사용자가 고른 4건. 정책 결정이 필요한 S5~S10 은 보고만 (README 인계 archive).
> - **S1 치명 — 로그아웃 뒤 같은 폰 가입 신청이 기존 승인 회원에 붙음.**
>   앱: `DeviceIdService.reset()` 신설 — 회원 `AuthState.signOut()`·코치
>   `CoachShell._logout` 이 이 기기의 device_id 를 새 UUID 로 되돌린다 (로그인은
>   서버가 내려주는 값을 `adopt` 하므로 기록은 그대로 이어짐). 로그아웃 3경로
>   (내 정보·승인 대기 셸·계정 삭제)와 코치 로그아웃이 `GymState.resetLocal()` 로
>   옛 소속 캐시도 비운다.
>   서버: `POST /member/gyms/<gid>/self-signup` 의 같은 기기 중복 분기가 **다른
>   아이디**의 자격증명이 이미 이 기기에 묶여 있으면
>   `DEVICE_BOUND_TO_OTHER_ACCOUNT`(409) — 종전엔 기존 회원 행에 새 아이디·
>   비밀번호를 덮어써 승인·회원권이 남에게 넘어갔다. 같은 아이디 재신청·
>   자격증명 없는 기기 전용 회원은 그대로 통과.
> - **S2 — 회원 주간 목록 `reserved_count` 가 confirmed 만 셈** →
>   `confirmed+attended` (정원 판정·대기 승격과 같은 기준). 코치가 출석을 찍을수록
>   회원 화면 예약 숫자가 줄던 결함.
> - **S3 — 수업 시작 전 출석 체크 통과** → `PATCH /admin/reservations/<id>/status`
>   가 attended·no_show 를 시작 시각 전엔 `CLASS_NOT_STARTED`(409). confirmed
>   (되돌리기)는 언제든. 폰 명단 시트는 같은 기준(`appClock`)으로 배지를 잠그고
>   '출석 체크는 수업 시작 후' 한 줄. (종료 컷오프 CLASS_ENDED 와 짝 — 예약은
>   종료까지, 출석은 시작부터.)
> - **S4 — 쪽지 발신자 'facing'**: 코치 쪽지는 체육관 공용 owner_hash 로 나가는데
>   그 해시엔 프로필이 없어 해시 조각이 이름으로 떴다. `coach_note._profile_display`
>   폴백 = 체육관 대표 스태프(boss 우선·재직) 이름 → 없으면 체육관 이름.
>   해시 값에 무관하므로 프로드 gym 2 owner_hash 를 손대지 않는다.
> - 회귀 게이트: 서버 `tests/test_reservation_policy.py` +3 ·
>   `tests/test_member_detail_linkage.py` +1 · `tests/test_coach_note_sender_display.py`(4 신규)
>   — 228 passed 1 skipped. 골든 `boss_03_class_roster`(시작 지난 수업으로 fake 이동) ·
>   `state_10_roster_before_start` 신규.

> **D31 (2026-08-12) — 명단에서 출석 체크 + 대기 순번 정정.**
>
> - **대기 순번**: `class_waitlist_promotions.promoted_position` 은 "줄 설 때" 번호라
>   앞사람이 승격·이탈해도 안 줄어든다 (실측: 대기 1명인데 화면엔 `대기 4`).
>   표시용 순번은 `api/classes.py _current_waitlist_position()` 으로 **매 조회마다 다시 센다**.
>   적용 3곳: 관리자 명단 · 회원 클래스 목록(`my_waitlist_position`) · 회원 예약 목록.
>   저장 컬럼은 이력용으로 보존하고 명단 응답에 `original_position` 으로 함께 내려준다.
> - **출석 체크**: `PATCH /api/v1/admin/reservations/<id>/status`
>   `{status: confirmed|attended|no_show}`. `cancelled` 는 의도적으로 거부 —
>   예약 취소는 회원 DELETE / 클래스 전체 취소 경로에만 있어야 이력이 남는다.
>   스태프(`is_staff()`) 전용 · 박스 일치 검사 · `AuditLog(class.reservation_status)` 기록.
> - **gym_attendances 동기화**: '출석' 시 그날 출석행이 없으면 `source='manual'` 1건 생성
>   (통계가 `distinct(member_id)` 라 QR 과 겹쳐도 중복 집계 없음). 되돌릴 때는
>   **같은 날 다른 수업에 출석 표시가 하나도 안 남았을 때만** manual 행을 지우고,
>   `source='qr'` 행은 실제 출입 기록이라 어떤 경우에도 건드리지 않는다.
> - UI: 앱 `class_roster_sheet.dart` 행 우측 [출석][노쇼] FkBadge 토글(같은 배지 재탭 = 확정
>   되돌리기) + 상단 '출석' 카운터, 시트를 바꾼 채 닫으면 대시보드 재조회.
>   웹 `classes.html` 상세 모달 명단에 같은 규칙의 버튼 2개.
>   대기자·고아(탈퇴 회원) 행에는 버튼을 붙이지 않는다.
> - 검증 (로컬, 계정 coach_park·boss_seongsu·admin): 상태 왕복 4단계 `synced`
>   created→None→removed 기대대로, 같은 회원 하루 2수업 분기에서 첫 수업만 되돌렸을 때
>   출석행 유지 확인, 잘못된 status 3종 400, 타 박스 스태프 403.

> **D32 (2026-08-12) — 고아 행 정리 + FK 강제 실증.**
> D29 에서 "예약 2명인데 명단 0명" 을 만든 고아 데이터의 뿌리를 정리했다.
>
> - **원인**: SQLite FK 는 연결마다 켜야 강제된다. `models/base.py` 의 connect 이벤트가
>   `PRAGMA foreign_keys=ON` 을 거는데, **그 리스너가 붙기 전에 지워진 회원**의 자식 행이
>   남은 것이다. 지금은 정상 — 임시 회원+예약+프로필을 만들어 회원만 지웠을 때
>   자식이 함께 사라지는 것을 실증했다 (`PRAGMA foreign_keys = 1` 확인).
>   raw `sqlite3.connect` 경로는 2곳뿐이고(스키마 편집·Postgres 내보내기) 행 삭제를 안 한다.
> - **도구**: `services/facing/scripts/fix_orphans.py` — `PRAGMA foreign_key_list` 로
>   FK 를 introspect 하므로 테이블이 늘어도 그대로 쓴다. 기본은 점검만, `--apply` 로 삭제.
>   삭제 전 `data/backup/` 에 DB 스냅샷(`sqlite3.backup` — WAL 안전). `ON DELETE CASCADE`
>   인 FK 의 고아만 지우고, 그 외는 의도일 수 있어 보고만 한다.
> - **로컬 DB 결과**: 14건 삭제 (class_reservations 12 · class_waitlist_promotions 1 ·
>   gym_member_profiles 1, 전부 `gym_members` 참조). 이후 `PRAGMA foreign_key_check` 0건.
> - **⚠ 운영 DB 는 아직 안 함** — Railway 볼륨은 사용자 승인 후
>   `python scripts/fix_orphans.py --db /app/data/facing.db` 로 먼저 점검할 것.
> - 명단 API 의 `orphan` 처리(outerjoin + '탈퇴 회원')는 **그대로 둔다** — 운영 DB 가
>   아직 안 정리됐고, 데이터가 깨끗해져도 방어로서 값이 싸다.

> **D33 (2026-08-12 사용자 지시) — 회원 폰 WOD 탭 = 그 주 월~일 아코디언.**
> "WOD 들어가면 아직도 보기가 너무 힘들다" 는 지적에서 나온 화면 구조 결정.
>
> - **전**: 오늘 / 예정 / 지난 3섹션이 세로로 이어지고, 그 아래에 수업 목록이 또
>   따로 쌓였다. 같은 날 정보가 두 곳에 나뉘어 "오늘 뭐 하고 몇 시에 가나" 를 보려면
>   두 군데를 봐야 했다.
> - **후**: 한 주가 7줄로 고정된다 (월~일 + 날짜, 오늘 표시). 요일·날짜를 누르면
>   그 자리에서 **그날 WOD + 그날 수업(줄마다 예약 버튼)** 이 함께 펼쳐진다.
>   한 번에 하나만 열리고, 주 이동은 헤더의 ◀ ▶.
> - 코드: `lib/features/gym/week_board.dart` (신설) · WOD 행은
>   `lib/features/gym/wod_row.dart` 로 분리해 보드와 공유 · 예약·취소 흐름은
>   `features/classes/classes_screen.dart` 의 `reserveClassFlow`/`cancelClassFlow`
>   한 벌 (§3 코드 SSOT).
> - 수업은 주 단위 1회 조회 (`GET /api/v1/member/classes?from=월&to=다음 월`) —
>   요일마다 부르면 7배 왕복. 백엔드 변경 0건.
> - D25 의 "WOD 탭 = 코치 오늘 WOD" 는 유지 — 오늘이 기본으로 열린 날일 뿐,
>   책임이 바뀐 것은 아니다.

> **D34 (2026-08-12 사용자 지시) — 회원 프로필에서 ENGINE 섹션 내림.**
> "engine 은 우리가 쓸 데 없다" 는 지시. 3기둥(게이미피케이션·WOD 보드·프로필)
> 집중(v1.27)의 연장선이다.
>
> - **화면에서만 제외, 코드는 보존** (CLAUDE.md "숨김 = 코드 보존"). Tier 배지 ·
>   Engine 점수 · LV · 칭호 · 6 카테고리 칩 · 추세 delta · 약점 카드 일습은
>   `lib/features/mypage/score_section.dart` 로 옮겨 두었다 (`ScoreSection`).
>   되살리려면 `MyPageScreen` children 에 `ScoreSection()` 한 줄이면 된다.
> - 같은 데이터를 쓰는 **온보딩 `/onboarding/grade` · 벤치마크 시트는 그대로 산다** —
>   Engine 측정 자체를 없앤 결정이 아니다. 프로필에서 되비추던 자리만 없앴다.
> - 백엔드 계약 변경 0건 (`overall_number`·`overall_score`·카테고리 응답 그대로).
> - 함께 처리: WOD 행의 '완료 표시'를 FkBadge 로 내려 수업 줄의 예약·대기 배지와
>   같은 크기로 통일 ("지금도 좀 커서 거북하다"). 터치 48 은 FkBadge 가 내부에서
>   확보하므로 DESIGN-SSOT §3 터치 기준은 유지된다.

> **D35 (2026-08-12 사용자 지시) — 역할은 코치·회원·회원신청자 셋뿐.** 전문 = §2-0-1.
> 표기 정본 = `docs/GLOSSARY.md` (사장·오너·매니저·관리자는 제품에 없는 말, copy lint 게이트).
> super admin(서비스 운영자)은 나중에. 앱 문구 22곳 정리 + `role_labels.dart` 매핑 4종 → 코치.

> **D36 (2026-08-12 사용자 지시) — 회원 레벨은 경력 3단으로 통일.**
> "PC 에서 회원 레벨을 맞추는 것도 경력에 따라 나눈다."
>
> | 크로스핏 경력 | 레벨 |
> |---|---|
> | 1년 미만 | **SCALED** |
> | 1~3년 | **RXD** |
> | 3년 이상 | **ELITE** |
>
> - **구 방식 폐기**: "레벨은 앱 사용 기반 자동 산정"(2026-06-08 결정, `members.html` 주석)은
>   더 이상 기준이 아니다. Engine 점수와도 무관하다 (D34 로 프로필에서 ENGINE 을 내린 것과 같은 줄기).
> - 사다리는 **셋뿐** — `RX+`·`Games` 는 회원 레벨에 쓰지 않는다. WOD 결과 1건의
>   `scale_level` 도 같은 셋(`scaled`/`rx`/`elite`).
> - **아직 구현 안 됨 (미착수 — 이 결정은 규칙만 확정)**. 필요한 것:
>   1. 회원에게 **크로스핏 시작일**(경력 기산점) 필드가 없다 — `gym_member_profiles` 컬럼 추가 + 마이그레이션
>   2. `level` 산정 = 시작일→오늘 경과로 서버가 계산 (수기 입력 금지 — 두 기준이 갈리면 원점)
>   3. PC 회원 폼(`web/facing-admin/templates/members.html`)의 레벨 읽기전용 안내 문구 교체 +
>      시작일 입력칸 추가
>   → DB 스키마 적용은 사용자 확인 대상 (§4). 착수 전 이 3줄을 먼저 갱신할 것.

> **D38 (화면 쪽 각론) — 코치 '관리' 면 폐기. 결정 전문 = 위 D38 (§2 뒤).**
> "코치 관리 이딴 거 없다. 내가 곧 코치이자 사장이니까. 직원 고용은 나중 일."
>
> ⚠ 이 블록은 2026-08-12 밤에 **D37 번호로 적혔다가 D38 로 정정**됐다. 같은 날 두
> 세션이 각자 번호를 매겨 D37 이 두 번 쓰였다 — PII 폐기가 D37, 코치 관리 폐기가 D38 이다.
> (커밋 `8cb9a53` 의 메시지에 남은 "D37" 은 이 D38 을 가리킨다.)
>
> - **폐기 대상 = 코치를 *등록·고용·관리* 하는 면**. PC 온보딩 STEP 2 의 '코치 등록 +
>   페어링 코드' 카드와 `/coaches` 링크 3곳(구 페이지는 같은 날 이미 삭제) · 랜딩·통계의
>   "코치 관리/코치 설정" 문구 · 앱 프로필의 '직원 계정 연결' 행.
>   STEP 2 이름도 "코치 · 운영 설정" → **"수업 · 회원권"**.
> - **남긴 것 (관리가 아님)**: 박스 소개의 코치 소개 카드(회원이 코치가 누군지 보는 곳) ·
>   회원↔코치 쪽지 · 수업 담당 표기. 회원 관리(`CoachDashboardScreen`)는 이름만 coach 일 뿐
>   **회원**을 다루는 화면이라 그대로 둔다. `/auth/link-staff` 도 남는다 (소셜 계정에
>   본인 코치 계정을 잇는 1회용 화면이라 '관리' 가 아니다).
> - ⚠ **백엔드 코드는 보존이 아니라 삭제됐다** — 같은 날 후속 지시("그런 비슷한 것도
>   전부 없애라")로 코치 계정 CRUD·페어링·고용형태를 실제로 지웠다. 위 D38 본문 참조.
>   한때 이 자리에 "숨김 = 코드 보존" 이라고 적혀 있었으나 사실과 다르다.
> - 이 결정으로 D35 의 "역할 셋"이 화면에서도 참이 된다 — 관리할 넷째 주체가 없다.

> **D39 (2026-08-13 사용자 지시) — 가짜 데이터는 코드에서도 지운다.**
> "리스트 하드코딩된 거 전부 지워라. 테스트로 뒀던 것들 싹 지워."
>
> - **백엔드**: 가짜 회원·페르소나·더미 쪽지를 만들던 시드를 파일째 삭제.
>   부팅 시드 = 카탈로그 + 박스 + 로그인 계정(admin·슈퍼씨드)뿐. 고정 테스트
>   계정(coach/member/new)·기본 락커·요금제 시드도 없앴다.
>   청소 도구 = `services/facing/scripts/blank_slate.py` (미리보기 기본, --apply 시 백업).
>   로컬·운영 둘 다 적용 완료 (운영은 `railway ssh`).
> - **앱**: 가짜 CrossFit 시즌 일정(`core/season.dart`)과 그 위에 얹혀 있던
>   시즌 배지(`core/season_badges.dart`)를 삭제. 화면에 `* Mock schedule` 이라고
>   적힌 배너가 실제로 사용자에게 보이고 있었고, 실제 대회 일정과 무관한
>   날짜로 배지를 주고 있었다. 제거 지점 4곳 — 계산 진입 배너 · 업적 패널 ·
>   결과 화면 · 세션 화면.
> - **남긴 것**: `weak_insight.dart`(점수 기반 규칙 코멘트)는 D34 로 이미 화면에서
>   내려간 `score_section.dart` 만 참조한다 — 사용자에게 안 보여서 그대로 뒀다.
> - 재도입 금지. 데모가 필요하면 **시드가 아니라 그때 손으로** 넣는다.

- **사장은 운영자**, PHASE5 부터는 **외출·이동 중 폰 보조 운영 가능** (linko 격차 해소 — `docs/_archive/PHASE5_ROADMAP.md`(2026-08-13 폐기 이동) 참조). PC 가 주, 폰이 보조. **폰 사장 로그인 = PC 동일 ID/PW** 사용. 회원·코치는 device_hash 익명 유지.
- 한 사람이 두 역할 가질 수 있어요 (예: 박지훈 = 사장 + 코치). DB 상으로는 `gym_managers` 에 두 행 (또는 role 컬럼 set 형).
- **PHASE5 추가 가정**: facing-app 진입 시 `user_type` 분기 — `device_hash` (회원·코치 익명) vs `login_id` (사장·매니저 ID/PW). 같은 앱 바이너리, 다른 진입 플로우.

---

## 3. 신규 가입 흐름 (가장 중요한 데모 흐름)

```
[현장]                      [폰 회원]                 [PC 사장]
────────                    ──────────                ──────────
체육관 방문
      │
      ▼
QR 또는 카운터 안내    →    1. 박스 찾기 화면
                            2. HYPHEN 선택
                            3. 가입 신청 (pending)
                                 │
                                 │ POST /join
                                 ▼
                                                      ─── SSE ───▶ 4. 알림 토스트
                                                                    "신규 신청 1건"
                                                                      │
                                                                      ▼
                                                                    5. 회원 카드 클릭
                                                                    6. 이름·생년·전화·
                                                                       회원권·락커 입력
                                                                    7. "승인 + 등록"
                                                                      │
                                                                      │ POST /admin/members
                                                 ◀─── SSE/Push ───   ▼
                        8. "등록 완료" 알림   ◀
                           NOTICE 탭에 박스
                           정보 카드 자동 노출
```

회의 데모 핵심 흐름. **폰에서 시작한 신청이 SSE 로 PC 사장 화면에 실시간 푸시**.

---

## 4. SSE 채널

```python
GET /api/v1/admin/events  → Server-Sent Events stream (사장 PC 구독)
GET /api/v1/member/events → 회원 폰 구독 (또는 30초 poll fallback)

이벤트 종류 (대표 — 전체 목록의 정본은 코드):
- member_join_request   : 폰 → 사장 (신규 신청)
- member.created        : 사장 PC → 구독자 (회원 등록)
- membership.issued     : 사장 PC → 구독자 (회원권 발급)
- wod.posted            : 코치 → 회원 (오늘 WOD 게시)
- wod_result.posted     : 폰 → 코치 (회원 결과 제출)
- note.new              : 폰·PC → 구독자 (1:1 쪽지 — payload preview·sender_name)
```

> **이벤트명 SSOT = 코드 두 곳** (2026-08-06 §0-B 정정): 발행 = `api/*.py` 의
> `sse_publish(gym_id, "<이름>", …)` 호출부(현재 35종) / 수신 = `facing-admin`
> `templates/_layout.html` 의 `_eventToastMap` 키. **두 목록의 키는 반드시 일치**해야 한다 —
> 어긋나면 토스트가 조용히 죽는다 (D28 에서 `message.received` 사문 발견). 명명 규약은
> 점 표기(`도메인.동작`)가 기본이며, 초기 도입분 일부(`member_join_request`·
> `attendance_checked`·`contract_issued` 등)는 밑줄 표기로 남아 있다.
>
> **2026-08-06 대조 결과**: 수신만 있고 발행 없는 사문 = 0건. 발행하지만 PC 토스트가 없는
> 10종(`coach.profile.updated`·`gym.profile.updated`·`locker.added`·`wod.deleted`·
> `membership.paused|resumed|updated`·`daily_plan.created|updated|deleted`)은 **전부
> PC 에서 시작한 동작**이라 자기 행동 되울림이 되므로 의도적 무음. 폰에서 시작하는 이벤트는
> 전부 토스트가 있어야 하며, 이 대조에서 `member.self_signup`(앱 자가가입) 누락을 발견해 추가했다.

- **모바일은 SSE 끊김 잦음** → 폰은 SSE 시도 + 실패 시 30초 poll fallback
- **PC 브라우저는 EventSource 안정적** → SSE 만

---

## 5. 데이터 모델 — 신규 테이블 6개

| 테이블 | 누가 쓰나 | 핵심 컬럼 |
|---|---|---|
| `gym_managers` | 운영자(코치) 계정 — 다중 박스 OK | gym_id, login_id, password_hash, role (boss/manager/coach — 셋 다 같은 '코치'), name, phone, device_hash, hired_at, left_at |
| `gym_member_profiles` | 사장 회원 DB | gym_id, member_id (FK), name, gender, birth_date, phone, level, preferred_time_slot, preferred_coach_gender, safety_note, note |
| `gym_memberships` | 회원권 관리 | member_id, plan_name, start_date, end_date, price, status (active/expired/refunded), refund_amount, refunded_at, **session_total** (D57 횟수권 — NULL=기간제; 사용 횟수는 `class_reservations.session_charged` 집계) |
| `gym_lockers` | 락커 관리 | gym_id, locker_no, member_id, start_date, end_date |
| `contract_instances` | 전자계약 (정본 — 구 `gym_contracts` 는 D40 에서 DROP) | template_id, gym_id, member_id, status, variables, pdf_path, signed_pdf_path, signed_at, signature_* |
| `gym_attendances` | 통계용 | member_id, gym_id, checked_at, source (qr/manual) |
| `gym_inquiries` | 회원→사장 직접 문의 (환불·계약·분쟁) | gym_id, member_id, subject, body, status, responded_at |
| `audit_logs` | 개인정보 접근·변경 감사 | actor_login_id, action, target_member_id, payload_hash, created_at, ip |

기존 `gym_members` (device_hash 기반) 와 1:1 외래키. 폰은 device_hash 그대로 쓰고, PC 는 member_id 기반 + 사장 로그인.

**기존 `gym_members` 에 컬럼 추가**: `status` (`pending`/`approved`/`rejected`/`left`/`removed`), `left_at`, `left_reason` — **M14 자발적 탈퇴 처리** 위해 필요.

**`gym_managers` 다중 박스 (M7·M8)**: 한 login_id 가 박스 2곳 운영 시 두 행 INSERT (gym_id 다르게). PK = (gym_id, login_id) 복합키. 사장 로그인 시 박스 선택 토글 (또는 통합 대시보드).

기존 테이블 (유지): gyms · gym_members · gym_wod_posts · gym_wod_results · gym_messages · gym_announcements · gym_coach_feedback · gym_member_requests · gym_profile (박스 정보).

---

## 6. 사장 통계 — 게이미피케이션 빼고 운영 숫자만

```
┌─ 오늘 ────────────────────┐  ┌─ 이번 달 ──────────────────┐
│ 출석 회원   38명          │  │ 신규 가입       12명       │
│ WOD 게시    2건           │  │ 만료 회원       8명        │
│ 가입 신청   3건 (대기)    │  │ 만료 임박       5명        │
└───────────────────────────┘  │ 매출 추정    8,400,000원   │
                               └────────────────────────────┘
┌─ Retention ───────────────┐  ┌─ 락커 점유율 ──────────────┐
│ 3개월 retention   78%     │  │ A존  10/12 (83%)           │
│ 6개월 retention   62%     │  │ B존  16/22 (72%)           │
│ 1년  retention    44%     │  │ 만료 임박     2개          │
└───────────────────────────┘  └────────────────────────────┘
```

- **게이미피케이션(배지·streak·tier)** 은 회원 폰에는 그대로 유지 (회원 유지 동기), 사장 화면은 **숫자만**
- 사장 = 결정 빠르게 내릴 수 있는 운영 지표 중심

### 6.1 측정 알고리즘 (M13 — 통계 정의 명시)

| 지표 | 정의 | SQL 의사코드 |
|---|---|---|
| 오늘 출석 | 오늘(KST) `gym_attendances.checked_at` UNIQUE(member_id) 수 | `COUNT(DISTINCT member_id) WHERE DATE(checked_at)=today` |
| 이번 달 신규 가입 | 이번 달 안에 `gym_memberships.start_date` ≥ first_day_of_month | `COUNT WHERE start_date BETWEEN month_start AND month_end` |
| 만료 임박 | `end_date` 가 오늘로부터 14일 이내 + status=active | `WHERE end_date BETWEEN today AND today+14d` |
| 매출 추정 (이번 달) | 이번 달 시작된 회원권 price 합 + 갱신 매출 | `SUM(price) WHERE start_date IN month` |
| 3개월 retention | M-3 코호트(3개월 전 가입자) 중 지금까지 1회 이상 출석한 비율 | `cohort 가입자 N / 그 중 M+0~M+3 동안 attendance 1+ 인원` |
| 6개월 retention | M-6 코호트 | 동일 패턴 |
| 1년 retention | M-12 코호트 | 동일 패턴 |
| 락커 점유율 | `gym_lockers` 중 `member_id IS NOT NULL` 비율 | `COUNT(occupied) / COUNT(total)` |
| 여성 비중 (M10) | gym_member_profiles WHERE gender='여' 비율 | gender 분포 |
| 여성 시간대 분포 (M10) | preferred_time_slot 별 GROUP BY | bar chart |

retention 정의 = "코호트(가입 월) 의 N개월 후 시점에 attendance ≥ 1 인 비율". 출석 기록 없으면 "left" 로 간주 (자발적 탈퇴와 별개).

---

## 7. 인증·보안

| 플랫폼 | 인증 방식 | 비고 |
|---|---|---|
| 폰 (회원·코치) | device_hash (X-Device-Id 헤더) | ⚠️ **D26으로 대체 예정** — 소셜 로그인 통일. device_hash 는 데이터 연결키로 격하 |
| PC (사장) | ID/PW + 세션 쿠키 (httpOnly Secure) | ⚠️ **D26으로 대체 예정** — 사장도 소셜 로그인. ID/PW 는 전환기 fallback |
| 시드 계정 | `boss_seongsu / 1234` (데모) + `APP_TEST_ADMIN_*` env (슈퍼) | CLAUDE.md §3-A 의무 시드 |
| 출석 체크인 | 1회용 QR (60초 만료) | 박스 입구 디스플레이가 토큰 갱신, 폰이 스캔 → POST `/attendances` |
| 결제 (Toss Payments) | webhook HMAC-SHA256 서명 검증 + timing-safe compare + idempotency key | reference/payment.md + reference/webhook.md 준수 |

- 회원 개인정보(이름·생년·전화·서명)는 들어가는 순간 **개인정보보호법 적용**. 암호화·접근로그·감사 필수.
- 사장 mutation 액션(승인/연장/락커 배정)은 **GET 절대 금지** (CSRF). POST/PATCH/DELETE + CSRF 토큰.
- 결제 webhook idempotency: 같은 Toss orderId 두 번 들어와도 1회만 처리.

### 7.1 개인정보 보존·삭제 (M5 — 개인정보보호법 §29 준수)

| 데이터 | 보존 기간 | 삭제 시점 | 근거 |
|---|---|---|---|
| 회원 이름·전화·생년 | 회원 탈퇴 후 5년 (세무·소비자 분쟁 대비) | 5년 경과 자동 cron 으로 NULL 처리 (member_id 만 유지) | 국세기본법 §85-3 (5년 보존) |
| 전자계약서·서명 이미지 | 계약 종료 후 5년 | 동일 | 전자문서법 §5 |
| WOD 결과·페이싱 기록 | 영구 (운동 기록은 회원 자산) | 회원이 명시 요청 시 즉시 익명화 | GDPR §17 (삭제 권리), 개인정보보호법 §36 |
| 출석 기록 | 회원 탈퇴 후 1년 | 1년 경과 자동 익명화 (회원 단위 식별 제거, 통계 카운트만 유지) | 통계 가치 vs 최소 보존 원칙 |
| audit_logs | 영구 (위변조 방지) | 절대 삭제 X | 정보통신망법 §29 (감사로그) |

**회원이 "삭제 요청" 시**: 사장 PC 화면에서 "개인정보 삭제" 버튼 → 30일 유예 → 자동 NULL 처리. audit_logs 에는 "deletion_requested_at" 만 남김.

---

## 8. 게이미피케이션 정책

- **회원 폰** — 배지·tier·streak·season 유지. 회원 유지율 핵심 가치.
- **사장 PC** — 게이미피케이션 노출 X. 사장은 운영 숫자만.
- **코치 폰** — 회원 게이미피케이션 진행도 조회 가능 (코칭 도구), 단 사장처럼 retention 통계는 X.

---

## 9. 빌드 우선순위

| Phase | 작업 | 무게 |
|---|---|---|
| **1. 백엔드 기반** | 신규 6 테이블 마이그레이션 + 사장 로그인 + SSE 채널 | 2일 |
| **1.5. 결제·체크인·푸시** | Toss Payments 통합 + QR 출석 체크인 + FCM 푸시 (D13·D14) | 1.5일 |
| **2. PC 사장 화면 풀** | 회원 DB CRUD + 회원권 3-tier (D9) + 락커 + 통계 대시보드 (여성 비중 D10 포함) + 전자계약 + SSE 알림 + churn win-back UI (D8) | 3일 |
| **3. 폰 가입 흐름 연동** | 박스 찾기 → 신청 → SSE 푸시 알림 수신 → 박스 정보 hydrate + first-week buddy 자동 메시지 (D11) | 1.5일 |
| **4. 폰 코치 모드 보강** | 사장 등록 회원과 device_hash 매핑 + 회원 목록 동기화 + buddy assign UI | 1일 |
| **5. 사용성 테스트** | 사장 5명·회원 5명 think-aloud 30분 (D14, Nielsen) → 발견 이슈 hotfix | 1일 |

총 약 10일 풀빌드. mockup (`web/facing-admin` v0.2) 은 이미 1번 일부 + 2번 부분 완료 상태.

---

## 10. 결정 사항 / 합의

| # | 결정 | 근거 |
|---|---|---|
| D1 | 백엔드 1개 (services/facing) — 분리 X | SSOT 단일성, 작업·인증 일관성 |
| D2 | ~~폰은 device_hash 익명 유지~~ → **D26으로 대체** (소셜 로그인 통일) | 회원 가입장벽 ↓, 기존 코드 호환 |
| D3 | ~~사장은 ID/PW 로그인~~ → **D26으로 대체** (사장도 소셜) | 개인정보 다루므로 신원 식별 필수 |
| D4 | SSE 사용 (WebSocket X) | 단방향 푸시면 충분, Flask Werkzeug 호환 |
| D5 | 사장 화면 게이미피케이션 X | 운영자 결정 속도 중심, 숫자만 |
| D6 | 폰·PC 모두 같은 박스(gym_id) 기반 | RBAC 가 gym 단위로 분리 |
| D7 | 신규 가입 = 폰 시작, PC 완성 | 사용자가 명시한 핵심 흐름 |
| D8 | **Churn 방지**: 만료 7·14일 전 자동 알림 (push+SMS) + 연장 시 10% 할인. cancel flow 에 "save offer" (1개월 무료) 1회 | subscription-fitness §4 (retention 벤치) + pricing §10.4 (cancel flow) |
| D9 | **회원권 3-tier + decoy**: charm 99k / 279k / 990k (12개월) + decoy 12개월+PT 1,490k (anchor). Annual 가입 시 churn 50% ↓ | pricing §1·§6·§9 + §10.2 (annual vs monthly churn) |
| D10 | **여성 회원 특수 필드**: `preferred_time_slot` (여성 전용/심야), `preferred_coach_gender`, `safety_note`. 사장 통계에 여성 비중·시간대 분포 추가 | subscription-fitness §5 (여성 20-39 WTP) |
| D11 | **신규 first-week buddy assign**: 사장이 가입 승인 시 코치에게 buddy 매칭 지시. 폰에서 buddy 첫 메시지 자동 트리거. 1주 retention 측정 | subscription-fitness §6 (group dynamics retention 1.5~2x) |
| D12 | **페르소나 = JTBD 라벨**: 박지훈="회원 관리 시간 줄이기" / 김도윤="내 PR 자동 추적" / 송예준="박스 안 다녀도 자체 WOD" / 최서윤="처음이라 뭐부터 할지 모름" | ux-testing §2 (JTBD & behavioral segmentation) |
| D13 | **출석 체크인 = QR 1회용 (60초 만료)** / **결제 = Toss Payments + webhook 서명 검증** | 사용자 명시 + subscription-fitness §2 (multi-gym 결제) |
| D14 | **FCM 푸시 통합** (Phase 2 후반) + **사용성 테스트 사장 5명·회원 5명 think-aloud** (Nielsen 5-user 84% 발견율) | ux-testing §3.3 (Nielsen 5-user rule) |
| D15 | **API 엔드포인트 카탈로그를 §13 에 통일 명세** — REST 동사·경로·인증·응답 형식 SSOT | 통독 M1 |
| D16 | **회원 탈퇴 처리**: `gym_members.status='left'` + `left_at` + `left_reason` 추가. 자발적 탈퇴와 만료 분리 | 통독 M14 |
| D17 | **개인정보 보존 5년 + 자동 익명화 cron**: §7.1 보존 표 준수 | 개인정보보호법 §29·§36 · 국세기본법 §85-3 |
| D18 | **사장 다중 박스**: `gym_managers` PK 복합키 (gym_id, login_id). 로그인 시 박스 선택 토글 + 통합 대시보드 (총매출/총회원) | 통독 M7 |
| D19 | **코치 다중 박스**: 동일 패턴. 코치 폰에 박스 선택 토글 + 박스별 알림 분리 | 통독 M8 |
| D20 | **다국어 정책**: 폰 = 영문 헤드라인 + 한글 캡션 (V8~V10 SSOT 유지) / **PC 사장 = 전체 한글** (운영자 한국인) / 코치 폰 = 폰과 동일 | facing-app CLAUDE.md V8~V11 |
| D21 | **환불·해지 자동 계산** (M3): 잔여기간 × 1일 단가 − 위약금 10%. 환불 상태 = gym_memberships.status='refunded'. 환불 처리 화면 사장 PC §14 | 소비자보호법 · 체육시설업 표준약관 |
| D22 | **알림 게이트웨이**: SMS = **NHN Cloud Toast SMS** (D8 만료 알림) · 이메일 = **Mailgun** (계약서 PDF 발송) · 푸시 = FCM (D14) | 한국 시장 가용성 + Mailgun 무료 tier |
| D23 | **DB 백업**: SQLite `facing.db` 일일 새벽 03:00 → `data/backup/facing-YYYYMMDD.db` (30일 보존) + 주간 외부 백업 (Railway Volume snapshot) | 회원 50명 시점부터 적용 |
| D24 | **사장의 코치 관리 페이지** 신설 (§14) — 가장 큰 빈약점 보강. 코치 추가/제거·시급·스케줄·페어링 코드 발급 | 통독 M15 |
| D25 | **폰 탭별 화면 책임 재배치** (2026-06-02): **Home** = 공지/쪽지 아코디언(최상단·접힘) + 게이미피케이션(Level·업적·Milestones) / **WOD** = 코치 오늘 WOD + 하단 프리셋 카테고리 아코디언(참조) / **Notice** = 쪽지·숙제·공지 전체 피드(Home은 요약본) / **Attend** = 출석 캘린더 전담(Profile에서 이동) / **Profile** = Identity + 점수(숫자만, radar·sparkline 그래프 제거) + Body·Membership·Locker·MyBox·Settings·Actions. 페이싱 엔진 Home→Profile 강등은 §11.5 positioning(엔진=부가 기능, 홈 노출 위계↓) 과 정합. 5탭 구조·라벨·인덱스 유지 | 사용자 결정 2026-06-02 + §11.5 |
| D26 | **인증 통일 (2026-06-03)**: 회원·코치·사장 **전원 소셜 로그인(네이버·구글)**. ① device_hash = 익명 식별 → **데이터 연결키**로 격하 (계정에 link). ② 사장 ID/PW(D3·§7) = 소셜로 대체, 전환기엔 fallback 병행. ③ 로그인 응답에 `role` 포함 → 앱이 자동 분기 (수동 mode_select·role_entry 화면 폐기). ④ **백엔드·앱 실 구현 완료 (2026-06-03), 실 OAuth 키 대기**: 백엔드 3 라우트(`/auth/social`·`logout`·`me`)·`social_accounts` 테이블·`gym_managers/members.user_id` 링크·httpx 토큰검증(google tokeninfo·naver userinfo)·role 결정·세션·rate limit 구현+모킹검증 완료. 앱 `RealSocialAuthService`+`resolveSocialAuthService` 팩토리(`USE_REAL_AUTH` 플래그)+pubspec(google_sign_in·naver_login_sdk, **디버그 APK 빌드 통과**) 완료. 기본은 여전히 `StubSocialAuthService`. 키는 전부 `--dart-define` 주입(안드로이드 manifest 수정 0). **남은 것 = GOOGLE_CLIENT_ID/SECRET 발급 → `--dart-define=USE_REAL_AUTH=true` (절차: `apps/facing-app/docs/NATIVE_AUTH_SETUP.md`)**. OAuth 2.1 Authorization Code + PKCE(security.md). 상세: `services/facing/docs/AUTH_SOCIAL_DESIGN.md` | 사용자 결정 2026-06-03 (D2·D3·§7 대체) |
| D27 | **기본 전자계약 흐름 단순화 (2026-06-05)**: ㉠회원폰·㉡현장·㉢이메일 3경로를 **"현장 1기기 서명 + 메일 발송"** 하나로 통일. 코치·사장 폰(또는 PC) 한 대를 회원에게 건네 **회원 본인이 직접 서명**(코치 대필 금지 — 전자서명법 §3) → 완성 PDF 를 **회원 이메일로 발송**. 회원 이메일 = D26 소셜 로그인(네이버·구글) 계정 이메일 자동 사용(미로그인 시 등록폼 1칸). 발송 채널 = Mailgun(D22). 회원 앱 설치 불요. 구현 시 staff-기기 서명 경로(proxy-sign 변형, "현장 본인 서명" vs "대리" 구분) + 메일 발송 1건 추가. 상세: `services/facing/docs/ONBOARDING_FLOW.md §2·§4` | 사용자 결정 2026-06-05 (㉠㉡㉢ 단순화) |
| D28 | **쪽지 = 폰 + PC 양쪽 (2026-08-06)**: 회원이 보낸 1:1 쪽지를 코치·사장이 **PC 어드민에서도 읽고 회신**한다. 기존엔 폰 전용(device_hash 인증)이라 "중요한 일은 PC 에서 처리"가 불가능했다. 데이터·직렬화는 그대로 `gym_coach_notes`(+recipients) 1벌 — 조회 로직을 `api/coach_note.build_threads()`·`build_messages()` 로 추출해 폰(device 인증)·PC(세션 인증)가 **같은 코드**를 쓴다. PC 신원 환산: boss·manager = `gyms.owner_hash`, coach = 페어링된 `gym_managers.device_hash`(미페어링이면 안내문과 함께 빈 목록). 신규 엔드포인트 3개 = §13.2. 함께 수정: SSE 이벤트명 — PC 는 `message.received` 를 듣고 있었으나 백엔드는 그 이름을 **한 번도 발행한 적이 없어** 쪽지 토스트가 죽어 있었다 → `note.new` 로 교체 + payload 에 `preview`·`sender_name` 동봉 | 사용자 결정 2026-08-06 (§2 RBAC 코치 클라이언트 갱신 동반) |

---

## 13. API 엔드포인트 카탈로그 (M1)

> ⚠️ **부분폐기 (2026-08-13 전수조사)**: 이 §13 은 실코드와 대조되지 않은 낡은 카탈로그다.
> 실구현 정본 = `services/facing/docs/SSOT/` (라우트 212개 전량 `_facts/facts_01_url_map.txt` + 4면 `대차대조표.md`).
> 아래 표는 역사 기록으로만 보존한다 — 새 작업의 근거로 쓰지 말 것.

### 13.1 기존 (현재 동작 — facing-app 폰 호출)

| 동사 | 경로 | 인증 | 비고 |
|---|---|---|---|
| GET | `/api/v1/gyms/search?q=` | device_hash | 박스 검색 |
| GET | `/api/v1/gyms/mine` | device_hash | 내 박스 (owner_hash + profile) |
| POST | `/api/v1/gyms` | device_hash | 박스 생성 (owner) |
| POST | `/api/v1/gyms/{id}/join` | device_hash | 가입 신청 |
| DELETE | `/api/v1/gyms/{id}/leave` | device_hash | 탈퇴 |
| PATCH | `/api/v1/gyms/{id}/profile` | device_hash (owner) | 박스 정보 수정 |
| GET/POST/DELETE | `/api/v1/gyms/{id}/wods` | device_hash | 오늘의 WOD |
| GET/POST/PATCH | `/api/v1/gyms/{id}/members` | device_hash (owner) | 회원 목록·승인 |
| GET/POST/DELETE | `/api/v1/gyms/{id}/announcements` | device_hash | 공지 |
| GET | `/api/v1/gym/{id}/messages` · `/threads` | device_hash | 1:1 쪽지 타임라인·스레드 목록 (발송은 `/gym/{id}/notes`·`/member-report`). **경로가 `gym` 단수** — 다른 행의 `gyms` 복수와 다름 (2026-08-06 실경로 대조 정정) |
| GET/POST | `/api/v1/gyms/{id}/wods/{wid}/results` | device_hash | 결과·리더보드 |
| GET/POST/DELETE | `/api/v1/gyms/{id}/wods/{wid}/comments` | device_hash | WOD 댓글 |
| GET/POST/DELETE | `/api/v1/gyms/{id}/wods/{wid}/feedback` | device_hash (owner) | 코치 1:1 피드백 |
| GET/POST/PATCH | `/api/v1/gyms/{id}/requests` | device_hash | 회원 사전 건의 |

### 13.2 신규 (Phase 1·2 — 사장 PC + 폰 가입 흐름 보강)

| 동사 | 경로 | 인증 | 용도 |
|---|---|---|---|
| POST | `/api/v1/auth/social` | provider token (body) | **D26 소셜 로그인** — 네이버·구글 검증→계정 upsert→role 반환. 설계: `services/facing/docs/AUTH_SOCIAL_DESIGN.md` |
| POST | `/api/v1/auth/logout` | 세션 | D26 로그아웃 |
| GET | `/api/v1/auth/me` | 세션 | D26 본인 정보 + role + 소속 박스 |
| POST | `/api/v1/auth/link-staff` | 세션 + login_id/PW | D26 전환기 — 기존 코치/사장 계정을 소셜계정에 link → role 자동 boss/coach (설계 §4.1) |
| POST | `/api/v1/auth/login` | ID/PW (+X-Device-Id) | **D42 통합 로그인 — 창구는 하나.** 서버가 `kind: coach\|member` 판정 후 각자 payload 반환. 앱(폰)의 유일한 로그인 경로 |
| POST | `/api/v1/admin/login` | ID/PW → 세션 쿠키 | 코치 로그인 — **관리자 웹 전용** (D42 이후 앱은 `/auth/login` 사용) |
| POST | `/api/v1/admin/logout` | 세션 | 로그아웃 |
| GET | `/api/v1/admin/me` | 세션 | 본인 정보 + 박스 목록 (다중 박스) |
| GET | `/api/v1/admin/gyms/{id}/members` | 세션 (boss) | 회원 DB 풀 리스트 |
| POST | `/api/v1/admin/gyms/{id}/members` | 세션 (boss) | 회원 추가 (이름·전화·생년 입력) |
| PATCH | `/api/v1/admin/members/{mid}` | 세션 (boss) | 회원 정보 편집 |
| DELETE | `/api/v1/admin/members/{mid}` | 세션 (boss) | 회원 삭제 (status='removed') |
| POST | `/api/v1/admin/members/{mid}/leave` | 세션 (boss) | 자발적 탈퇴 처리 (D16) |
| POST | `/api/v1/admin/members/{mid}/memberships` | 세션 (boss) | 회원권 발급 |
| PATCH | `/api/v1/admin/memberships/{mid}/extend` | 세션 (boss) | 회원권 연장 (D8 win-back) |
| POST | `/api/v1/admin/memberships/{mid}/refund` | 세션 (boss) | 환불 처리 (D21) |
| GET/POST/PATCH | `/api/v1/admin/gyms/{id}/lockers` | 세션 (boss) | 락커 관리 |
| GET/POST | `/api/v1/admin/members/{mid}/contracts` | 세션 (boss) | 전자계약 |
| GET | `/api/v1/admin/gyms/{id}/stats` | 세션 (boss) | §6 통계 한 묶음 |
| GET/POST/PATCH/DELETE | `/api/v1/admin/gyms/{id}/coaches` | 세션 (boss) | **코치 관리 §14 (D24)** |
| POST | `/api/v1/admin/gyms/{id}/coaches/{cid}/pairing-code` | 세션 (boss) | 코치 폰 페어링 코드 발급 |
| GET | `/api/v1/admin/gyms/{id}/message-threads` | 세션 (boss·manager·coach) | **D28 회원 쪽지** — 상대별 1:1 스레드 요약(안읽음 포함) |
| GET | `/api/v1/admin/gyms/{id}/messages?peer=&read=1` | 세션 (boss·manager·coach) | D28 — 특정 회원과의 타임라인. `read=1` 이면 열람 시 읽음 처리 |
| POST | `/api/v1/admin/gyms/{id}/messages` | 세션 + CSRF | D28 — PC 에서 회원에게 1:1 회신 (500자) |
| POST | `/api/v1/admin/members/{mid}/inquiries/{iid}/respond` | 세션 (boss) | 회원 문의 답변 |
| GET | `/api/v1/admin/events` | 세션 (boss) | **SSE stream §4** |
| POST | `/api/v1/attendances` | device_hash + QR 토큰 | 출석 체크인 (D13) |
| POST | `/api/v1/payments/webhook` | HMAC-SHA256 서명 | Toss webhook (D13) |
| GET | `/api/v1/member/events` | device_hash | 회원 폰 SSE stream |
| POST | `/api/v1/member/inquiries` | device_hash | 회원→사장 직접 문의 |
| POST | `/api/v1/admin/members/{mid}/claim-code` | 세션 (boss) | **이음새 1** — 폰 없이 선등록한 회원에 가입 코드 발급(6자리·7일). 상세: `services/facing/docs/ONBOARDING_FLOW.md §4` |
| POST | `/api/v1/member/claim` | device_hash + code | **이음새 1** — 회원이 앱에서 코드 입력→임시 레코드에 폰 device_hash 흡수(중복 self-signup 병합) |

**응답 형식** 통일: `{ok: true, data: {...}}` / `{ok: false, error: "한글", code: "MACHINE_CODE"}` (기존 envelope 유지).

---

## 14. 코치 관리 페이지 (M15·D24 — 가장 큰 빈약점 보강)

### 14.1 사장 PC 화면 (`/admin/coaches`)

```
┌─ 코치 명단 ──────────────────────────────────────────────────┐
│ 이름      전화          입사일      시급       상태   액션  │
│ 박지훈    010-...       2024-03-01  35,000원   재직   편집 │
│ 김민수    010-...       2025-08-15  28,000원   재직   편집 │
│ 이수연    010-...       2024-11-10  30,000원   퇴사   복원 │
└─────────────────────────────────────────────────────────────┘
[+ 코치 추가]  [급여 정산 export]
```

### 14.2 코치 추가 흐름

1. 사장이 "+ 코치 추가" 클릭 → 폼 (이름·전화·시급·시작일)
2. 백엔드 `POST /api/v1/admin/gyms/{id}/coaches` → `gym_managers` INSERT (role='coach')
3. 자동으로 **페어링 코드 6자리 발급** + SMS 발송
4. 코치가 폰 facing-app 켜고 "코치 페어링 코드 입력" → device_hash ↔ login_id 연결
5. 코치 폰이 코치 모드 활성화 (기존 owner 와 동일 권한)

### 14.3 코치 제거 / 퇴사

- "퇴사 처리" 클릭 → `gym_managers.left_at = now()` (행 삭제 X, 이력 보존)
- 해당 코치의 폰 device_hash 는 그 박스에서 권한 박탈
- 회원에게 보낸 쪽지·피드백은 history 로 유지 (작성자 표기는 "(퇴사) 이수연")

### 14.4 시급·스케줄 (Phase 5+)

- 시급 입력만 v1. 자동 정산은 Phase 5+ (회계 시스템 연동 후보)
- 스케줄 (수업 시간표) 은 D2 (이번 빌드 X)

### 14.5 다중 박스 코치 (M8·D19)

- 같은 코치가 박스 2곳 등록 시 `gym_managers` 에 두 행 (gym_id 다르게)
- 코치 폰에 박스 선택 토글 (상단 메뉴)
- 시급·페이먼트는 박스별 독립

---

## 11. 변경 절차

이 브리프와 충돌하는 코드 변경이 필요할 때:
1. Claude 가 충돌 감지 → 사용자에게 보고 ("이 브리프와 어긋나는데 어느 쪽 우선?")
2. 사용자 명시 승인 → 브리프 먼저 갱신 → 코드 변경
3. 변경 이력은 §10 결정 사항 표에 D8, D9... 로 추가

브리프 우선 원칙. 코드만 갱신하고 브리프 방치 금지 (글로벌 §0-B SSOT 룰).

### 11.1. PHASE4 신규 테이블 (12개) — 사전 합의 등록

> 등록일: 2026-05-23. 상세 DDL: `docs/_archive/PHASE4_ROADMAP.md`(2026-08-13 폐기 이동) 각 §1.x·§2.x.
> Migration 방법: `services/facing/models/base.py` `_migrate()` 함수에 `CREATE TABLE IF NOT EXISTS` 패턴 추가 (기존 Phase 1 방식 동일).

| # | 테이블 명 | PHASE4 Week | 모듈 | 브리프 §5 다이어그램 갱신 필요 |
|---|---|---|---|---|
| 1 | `class_session` | Week 1 | §1.1 예약 | 예 |
| 2 | `class_reservation` | Week 1 | §1.1 예약 | 예 |
| 3 | `class_waitlist_promotion` | Week 1 | §1.1 예약 대기열 audit | 예 |
| 4 | `notification_template` | Week 3 | §1.2 카카오 알림톡 (D60 폐기 — 템플릿은 `note.py NOTE_TEMPLATES` 코드 상수, 표 없음. D61 체육관별 덮어쓰기는 `gym_notification_settings.settings.templates` JSON) | 예 |
| 5 | `notification_dispatch` | Week 3 | §1.2 발송 이력 | 예 |
| 6 | `contract_template` | Week 1 | §1.3 전자계약 템플릿 | 예 |
| 7 | `contract_instance` | Week 1 | §1.3 서명 인스턴스 | 예 |
| 8 | `gym_group` | Week 5 | §1.4 다지점 그룹 | 예 |
| 9 | `billing_key` | Week 2 | §1.5 Toss 빌링키 | 예 |
| 10 | `billing_schedule` | Week 2 | §1.5 자동결제 스케줄 | 예 |
| 11 | `ai_coaching_session` | Week 7 | §1.7 AI 코칭 보조 | 아니오 (Phase 2 연기) |
| 12 | `wod_calendar_plan` | Week 4 | §1.6 WOD 월간 캘린더 | 예 |

> `billing_key` 는 PHASE3 C-1 에서 일부 구현됐을 수 있음. 코드 착수 시 `services/facing/models/` 확인 후 중복 방지.

### 11.2. PHASE4 ALTER 컬럼 (3건) — 사전 합의 등록

> Migration 방법: `_migrate()` 내 `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` (SQLite 호환 — `IF NOT EXISTS` 는 SQLite 3.37+ 지원, 미만이면 try/except OperationalError 패턴).

| # | 테이블.컬럼 | 타입 | PHASE4 Week | 모듈 | 용도 |
|---|---|---|---|---|---|
| A1 | `gym_member_profiles.preferred_class_time_slot` | VARCHAR(50) | Week 1 | §1.1 예약 | 예약 선호 시간대 (기존 D10 `preferred_time_slot` 과 별도 — 클래스 예약용) |
| A2 | `gyms.group_id` | INT FK → `gym_group.id` | Week 5 | §1.4 다지점 | 다지점 그룹 FK |
| A3 | `gym_memberships.auto_renew_enabled` | BOOLEAN DEFAULT FALSE | Week 2 | §1.5 자동결제 | 자동갱신 토글 |

> A1 주의: 기존 `gym_member_profiles.preferred_time_slot` (D10 여성 전용/심야) 과 **다른 컬럼**. 클래스 예약 전용으로 분리. 이름 충돌 방지를 위해 `preferred_class_time_slot` 사용.

### 11.3. PHASE4 신규 API 엔드포인트 (§13 카탈로그 갱신 예고)

> PHASE4 구현 착수 시 §13.2 에 신규 endpoint 추가 의무. 아래는 예고 목록 (상세: `docs/_archive/PHASE4_ROADMAP.md`(2026-08-13 폐기 이동) 각 §).

| 모듈 | 신규 엔드포인트 수 | 비고 |
|---|---|---|
| §1.1 예약 | 6 | POST·GET·DELETE·noshow·SSE 이벤트 |
| §1.2 알림톡 (D60 → 앱 쪽지) | 2 | dispatch·이력 |
| §1.3 전자계약 | 4 | draft·sign-link·sign·pdf |
| §1.4 다지점 | 4 | group dashboard·gym-switcher·share·cross-gym 출석 |
| §1.5 빌링키 | 5 | key 발급·삭제·schedule·retry·APScheduler |
| §1.6 WOD 캘린더 | 4 | 작성·복사·공유·조회 |
| §1.7 AI 코칭 | 1 | wod-pacing-explain |
| §2.1 페이싱 보강 | 3 | calculate 보강·cp-estimate·pacing-batch |
| §2.2 leaderboard | 3 | leaderboard·tier-distribution·engine-comparison |
| §2.4 듀얼 포지셔닝 | 3 | link-facing-app·class-pacing·push-pacing-card |
| **합계** | **35** | |

### 11.5. facing-app 포지셔닝 전환 (2026-05-24)

> 등록일: 2026-05-24. 사용자 결정: 신규 방문자 페르소나 시뮬레이션 100건 그루밍 결과, facing-app 의 primary value 를 "Games-elite 전용 페이싱 계산기" → **"수업 관리 + 페이싱 (+α)"** 로 전환.
> 상세: `docs/PERSONA_BACKLOG.md` 와 `apps/facing-app/CLAUDE.md` v1.16.2.

| 항목 | Before | After | 영향 범위 |
|---|---|---|---|
| facing-app primary value | "Split defines rank · Games elite" | "수업을 간편하게 — 박스 운영 + 페이싱(+α)" | 모든 화면 카피·온보딩·홈 |
| 타깃 유저층 | Games tier 출전자급 한정 | RX-aspiring ~ Games 까지 폭넓게 | 마케팅·기능 우선순위 |
| 페이싱 엔진 위상 | 메인 기능 | 부가/차별 기능 (Wodify 미보유 hook) | 홈 화면 노출 위계 |
| 톤·V1~V11 어투 | 유지 | 유지 (단, "elite 전용" 문구 제거) | 카피 톤 |
| 금지 용어 (헬스·다이어트·웰니스) | 유지 | 유지 | 카피 |

> §10 결정사항 표에는 D-번호 부여 후 추가 예정.

### 11.6. 박스 프로필 + 코치 프로필 스키마 확장 (2026-05-24)

> 등록일: 2026-05-24. 페르소나 결과 분류 — 박스 운영 정보 18 필드를 `gym_profiles` + 신규 `gym_coach_profiles` 두 테이블로 흡수.
> 상세 DDL: `docs/GYM_PROFILE_SCHEMA.md`.

| 변경 | 대상 | 신규 필드 / 모델 | 비고 |
|---|---|---|---|
| ALTER | `gym_profiles` | +9 필드 (price_summary, payment_methods, receipt_info, parking_info, first_visit_guide, attire_guide, wifi_info, contact_kakao, free_notice) | 기존 7 필드 (phone·coach_*·motto·logo·class_schedule·instagram) 와 합쳐 16 필드 (→ D63 2026-08-27 로 `instagram`·`logo_url` 코드 경로 제거, 노출 **14 필드**. 컬럼만 휴면 존치) |
| 신규 테이블 | `gym_coach_profiles` | coach_user_id, gym_id, name, photo_url, career, certifications, specialty, competition_records, demo_video_url, sns_url, pt_bookable, off_days_json, hired_at | 코치 multi 지원. `gym_managers.role='coach'` 와 1:1 연결 |
| 신규 endpoint | §13 카탈로그 | 6 (GET/PATCH gym profile / GET coach list / GET coach detail / PATCH coach profile / GET coach off-days) | RBAC: 사장 = 전부, 코치 = 본인 only, 회원 = 읽기만 |

> 계약서(`contract_template` / `contract_instance`) 는 **PHASE4 §1.3 으로 이미 등록됨** (위 §11.1). 추가 작업 없음. 박스 프로필 페이지에서 "환불·해지·등록비·보험" 4 항목은 계약서 템플릿 필드로 흡수.

---

### 11.7. D26 소셜 로그인 신규 스키마·엔드포인트 (2026-06-03)

> 등록일: 2026-06-03. 사용자 결정(D26): 회원·코치·사장 전원 소셜 로그인 통일.
> 상태: **설계만 등록 (미구현)**. 앱은 현재 `StubSocialAuthService`. 상세 설계: `services/facing/docs/AUTH_SOCIAL_DESIGN.md`.

| 변경 | 대상 | 신규 필드 / 모델 | 비고 |
|---|---|---|---|
| 신규 테이블 | `social_account` | provider, provider_uid (UNIQUE 복합), email, display_name, created_at, last_login_at | 소셜 계정 ↔ user 매핑 |
| ALTER | `gym_members` · `gym_managers` | +`user_id` (FK, nullable) | device_hash·login_id → user_id 점진 통합 |
| 신규 endpoint | §13.2 카탈로그 | 3 (`/auth/social` · `/auth/logout` · `/auth/me`) | 세션 메커니즘은 admin 동일 재사용 |
| 신규 env | `C:/dev/.env` + Railway | `GOOGLE_CLIENT_ID`/`SECRET` (NAVER_* 는 기존 재사용) | LLM 키(§0-A)와 무관 |

> 마이그레이션은 `models/base.py` `_migrate()` 패턴. 구현 착수 = 네이버·구글 OAuth 키 확보 시점.

---

### 11.4. PHASE5 §2 RBAC 변경 등록 (2026-05-23)

> 등록일: 2026-05-23. 상세 plan: `docs/_archive/PHASE5_ROADMAP.md`(2026-08-13 폐기 이동).
> 사장 폰 보조 운영 가정 추가 — linko 격차 해소 (linko 9 스크린샷 분석에서 격차 발견).

| 변경 항목 | Before | After | 영향 범위 |
|---|---|---|---|
| 사장 클라이언트 | PC 전용 | PC 주 + 폰 보조 (PHASE5) | facing-app 인증·라우팅·UI |
| 매니저 역할 | 미정의 | RBAC 표 추가 — 사장 위임 운영권 | 백엔드 RBAC enum + 미들웨어 |
| 폰 진입 분기 | device_hash 단일 | user_type=`device_hash` (회원·코치) vs `login_id` (사장·매니저) | facing-app 부팅 라우터 |
| 사장 폰 로그인 | 없음 | PC 와 동일 ID/PW | 백엔드 admin login endpoint 확장 |

> §10 결정사항 표에는 PHASE5 착수 시점에 D-번호 부여 후 추가.

### 11.8. D28 쪽지 PC 확장 등록 (2026-08-06)

> 등록일: 2026-08-06. 사용자 지시 — "코치(사장) 중요한 일은 PC 에서 처리".
> 실기 검증 완료: 회원 폰 발송 → PC 토스트·타임라인 즉시 반영, PC 회신 → 회원 폰 대화 반영.

| 변경 항목 | Before | After | 영향 범위 |
|---|---|---|---|
| 코치 클라이언트 (§2) | 폰 | 폰 주 + PC 보조 | 브리프 §2 RBAC 표 |
| 쪽지 조회 로직 | `coach_note` 엔드포인트 안에 인라인 | `build_threads()`·`build_messages()` 공용 함수 (SSOT) | `api/coach_note.py` |
| PC 쪽지 API | 없음 (폰 device_hash 전용) | admin 3 엔드포인트 (§13.2) | `api/admin.py`·`web/facing-admin` |
| SSE 쪽지 이벤트 | PC 가 `message.received` 수신 대기 (백엔드 미발행 = 사문) | `note.new` + `preview`·`sender_name` payload | `api/coach_note.py`·`templates/_layout.html` |

- **스키마 변경 없음** — 기존 `gym_coach_notes` · `gym_coach_note_recipients` 그대로 사용.
- 미해결: 폰 미페어링 코치는 PC 에서 쪽지 열람 불가 (안내문 노출). 페어링 없이도 되게 하려면
  `gym_managers` 에 staff 전용 식별 해시를 부여하는 별도 결정이 필요하다.

### 11.9. 코치 앱 = 간단 3탭 셸 등록 (2026-08-14 사용자 설계 · 같은 날 v2 확정)

- **결정 (v2, 2026-08-14 12:52 사용자 확정)**: 코치는 PC(디테일 운영)와 앱(간단)
  둘 다 쓴다 (§2-0 대전제 ③ 재확인). 앱 쪽 코치 경험은 **CoachShell 3탭** 하나로 고정:
  ① 회원 현황 — 승인 대기·로스터·활동 통계 (기존 CoachDashboardScreen 재사용)
  ② 예약 조회 — 오늘 예약·출석·수업 명단 (기존 BossDashboardScreen 임베드)
  ③ 쪽지 — 핀 공지 + 회원 쪽지 스레드 (기존 MessagingScreen 재사용)
- **v1(예약·수업·내 정보)에서 바뀐 것**: 수업 탭(BoxWodScreen) 삭제 — 수업 안내는
  PC·회원 앱 몫. 내 정보 탭(MyPageScreen) 삭제 — 로그아웃은 예약 조회 AppBar 에
  이미 있다.
- **v2.3(2026-08-12) "코치 진입 숨김" 부분 폐기**: 진입 버튼(`_kShowBossEntry`) 원복.
  "코치 주 창구 = PC" 는 유지 — 앱은 보조·간단 창구다.
- **정리**: 대시보드의 가짜 하단탭(onTap 빈 함수 4개) 삭제 — 실탭은 CoachShell 소유.
- **백엔드 — 코치 기기 폴백 (services/facing, 2026-08-14)**: 회원 현황·쪽지 탭은
  회원 API(X-Device-Id)를 쓰는데, 로그인만 한 코치 기기는 owner_hash 도
  GymMember 도 아니라 "체육관 미가입" 이 났다. admin_login 이 페어링하는
  `GymManager.device_hash`(재직 중)를 스태프 기기 증표로 인정 —
  `api/roles.py is_staff_device()` 하나로 판정하고 `/gyms/mine`·회원 목록/승인·
  WOD 목록·공지(G13 기기판)·coach_note 게이트(`_is_coach_device`, 구 `_is_owner`
  개명)가 이를 쓴다. 회귀 = `tests/test_coach_device_fallback.py`.
- **미해결**: 쪽지 신원은 PC 규약(admin.py `_staff_device_hash`)과 동일하게
  coach 는 본인 페어링 해시다 — 회원이 시작하는 스레드는 owner_hash 로만 가므로
  boss 아닌 코치 기기에는 회원 발신 스레드가 안 보인다 (PC 와 같은 한계).
- **스키마 변경 없음.**
- **v3.3 (2026-08-18 사용자 지시)**: 코치 폰 = **2탭**으로 축소 — "코치는 대부분
  PC. 폰 코치는 진짜 기본만". ① 예약 현황 — BossDashboardScreen 임베드 (오늘
  예약·출석·수업 명단·수업 등록(G24) 포함, 구 예약 조회 탭 그대로) ② 수업 —
  회원 셸과 **동일한 BoxWodScreen 재사용** (variant 신설 없음, 코치 데이터
  접근은 위 코치 기기 폴백이 처리 — 프론트 role 분기 없음). 회원 현황·쪽지
  탭 제거 (숨김 = 코드 보존 — 화면 파일·배선 잔존, 셸에서만 제외). 가입 승인은
  예약 현황 탭 '회원 관리' 버튼 → CoachDashboardScreen push 로 잇고 (구
  '구현 예정' 스낵바 → 실배선), 쪽지는 수업 탭 종(InboxBellAction) →
  MessagingScreen push 로 유지. 백엔드·스키마 변경 없음.

### 11.10. 체육관별 업적(게임) 설정 — PC 코치 설정 → 회원 폰 연동 (2026-08-20 사용자 지시)

- **결정**: 코치가 PC 설정에서 업적(게임 요소)을 체육관 단위로 조절하면 회원
  휴대폰에 그대로 반영된다. 앱은 서버 응답을 그리기만 하므로 **앱 코드 변경 0**.
- **신규 테이블**: `gym_achievement_settings` (gym_id PK·FK, is_active,
  disabled_codes_json, updated_at) — `gym_point_settings` 패턴 (행 없음 = 전부 활성).
- **신규 endpoint 2 (§13 카탈로그 대상)**: GET·PATCH
  `/api/v1/admin/gyms/<gid>/achievement-settings` (`@require_staff` + 감사로그).
- **회원 연동 의미론**: 마스터 off = `/api/v1/achievements` 카탈로그·해금 빈 응답
  + `/check` 신규 해금 중단. 개별 비활성 code = `is_hidden` 과 동일 — 미해금만
  숨고 **기해금 기록은 계속 보인다**. 판독 단일 지점 =
  `services/achievement_checker.py gym_achievement_policy()`.
- **PC**: `/settings/achievements` (settings_points 패턴 — 마스터 토글 + 업적별 토글).
- 회귀 = `tests/test_achievement_settings.py` (7건).

**v2 (같은 날 2차 — 사용자 지시 "engine 이 없는데 왜 있냐 + 픽토그램·희귀도·포인트·비고")**
- **카탈로그 대수술**: Engine 스냅샷·Tier·신체(1RM·체중)·프리셋 기반 등 원천 소멸
  트리거의 업적 ~70종 삭제 — 시드 22종(수업 기록·PR 기반)만 잔존. 목록 정본 =
  `models/base.py DEAD_ACHIEVEMENT_TRIGGERS` (시드 프루닝 + 마이그레이션 동일 목록).
  G19 '숨김' 정책을 '삭제' 로 승격. 해금 기록은 보존 (카탈로그 없으면 화면 미노출).
- **카탈로그 코치 편집 3필드**: `achievements_catalog` +icon(픽토그램 슬러그)·
  +points(달성 시 자동 적립, member_points earn/created_by='achievement')·
  +repeat_kind(1회/반복 — 표기용, 반복 재적립 엔진은 후속). 희귀도(rarity)도 PC
  드롭다운 편집 — 시드는 코치 편집 필드를 덮어쓰지 않는다.
- **신규 endpoint**: PATCH `/api/v1/admin/achievements/<code>` (rarity·icon·points·
  repeat_kind — 카탈로그는 전역 1벌, 1샵 운영 전제).
- **앱**: 업적 카탈로그·희귀도·포인트는 서버 응답 그대로 — 필터 탭에서 빈 그룹
  (Tier·Engine·히든) 삭제만 반영. 회귀 = 백엔드 131 · 앱 167 · 골든 42장.

### 11.11. 리워드 규칙 엔진 — GTM 식 행동/조건/보상 빌더 (2026-08-20 사용자 승인·구현)

- **설계 정본 = `docs/PLAN-reward-rules.md`** (승인 확정: 주=ISO 월요일 · 미소급 ·
  custom 인증 기본 코치 승인 · 카테고리 3분류 ①자동/②기록 로그/③코치 인증).
- **신규 표 3**: `gym_reward_rules`(규칙) · `gym_reward_grants`(지급, UNIQUE
  rule×member×window_key = 반복 재적립 중복 차단) · `gym_action_logs`(custom 인증
  원장, UNIQUE 1일 1회). `achievements_catalog` +gym_id (커스텀 업적 `RULE_{id}`).
- **엔진**: `services/reward_engine.py` 단일 판독 — 훅 3곳(출석 동기화 ·
  `save_wod_history` · custom 승인) + `/achievements/check` 보조 스윕.
  달성 시 member_points earn(created_by='reward_rule') + 업적 해금.
- **API**: admin reward-rules CRUD·grants·action-logs 승인/대리 + member
  `reward-rules/<id>/log`·`me/reward-progress` (§13 카탈로그 대상).
- **PC**: `/settings/achievements` 에 카테고리 3섹션 + 문장형 빌더 + 인증 대기함.
- **앱**: 해금 축하 = 토스트(기본 픽토그램)+컨페티 캐논 2초, 스냅샷 diff 로 서버
  훅 해금도 감지. 완료 기록 시트 v3.3 — 수업 내용 인계·동작별 SCALED/RXD
  (코치 무게 자동)·ELITE 제거.
- **P3 도전 카드 구현 (2026-08-20 밤)**: 홈 마일스톤 아래 도전 섹션 —
  규칙 문장+진행바+달성 ✓+승인 대기 건수, custom 은 [인증하기] 시트(1일 1회,
  409 안내). 자동 인정 즉시 지급 시 업적 diff 로 축하 연동. 규칙 없으면 숨김.
- **P4 트리거 4종 구현 (2026-08-20 저녁 — 설계 = `docs/PLAN-record-structures.md` Part B)**:
  reservation(예약한 날 기준, 취소 제외) · payment(paid, refund 제외) ·
  membership_extend(2번째 발급부터, 누적 조건만) · birthday(당일~+7일 유예,
  연 키 매년 반복, 조건 슬롯 서버 강제). 전부 카테고리 1. 기존 DB 의
  trigger CHECK 는 `_migrate_reward_trigger_enum`(writable_schema)으로 확장.
  훅 +5곳: 예약 확정 3경로·결제 입력·회원권 발급(연장+연동 결제), 생일은
  출석 훅 동승 + 스윕. 앱 변화 없음 (문장·진행률 = 서버 생성).

### 11.12. 수업 유형별 기록 구조 + 발전 측정 (2026-08-20 사용자 승인·Q1+Q2 구현)

- **설계 정본 = `docs/PLAN-record-structures.md` Part A** (확정: EMOM 성공 라운드
  1칸 · Strength 최고 무게+reps 1줄 · AMRAP 라운드 우선, 동라운드면 reps).
- 점수 = 유형별 단위: for_time 시간↓ / amrap 라운드+reps↑ / emom 성공 라운드↑ /
  **strength 무게↑** (`gym_wod_results` +weight_kg·weight_reps·is_pr·signature).
- **비교·PR = 서버 단일 판독** (`services/wod_compare.py`): 시그니처(동작·횟수
  시퀀스 해시, strength 는 동작 단위, 자유 서술 첫 줄 폴백)로 같은 수업 자동
  매칭 → 저장 응답 `comparison`(직전 델타 한국어 메시지 + 역대 최고 PR,
  For Time 0.5% 임계). 첫 기록 = PR 아님. 수업 기록 PR 은 리워드 'pr' 트리거
  원천에 합류 (§11.11).
- 앱: 완료 기록 시트 4분기 + 저장 스낵바 비교 메시지 표시 (계산 0). 코치 등록
  시트 STRENGTH 추가 (백엔드 ALLOWED_WOD_TYPES 정합 — 구 드리프트 정정).
- **실기 결함 6건 수정 (2026-08-20 밤 탐색 테스트)**: ①strength 상세 타이머
  숨김(For Time 스톱워치 오작동·시간 기록 오염 차단) ②인증 승인/거절 →
  회원 쪽지 통지(coach_note) ③히스토리 0초 기록 '-' 표시 ④wods 목록에
  `my_result` 동봉 → 카드 '기록 {값}' 배지·시트 프리필·덮어쓰기 안내
  ⑤요청/댓글 빈 전송 안내(시트는 인라인 — 스낵바는 모달 뒤에 가려짐 실측)
  ⑥`reward_rule.changed` SSE → 도전 카드 자동 갱신. 전부 에뮬레이터 재검증.
- **Q3 구현 (같은 날 저녁)**: `wods/<id>/my-history`(같은 시그니처 내 기록,
  라벨 서버 완성) · `strength-board`(리프트별 역대 최고) → 수업 상세 "내 이전
  기록" 섹션 + 내 정보 메뉴 "최고 기록"(1RM 보드 화면). v3.4 이전 기록은
  signature NULL 이라 이력 미포함 (신규 축적). 기존 표시용 판정기 2종
  (admin_leaderboard For Time is_pr · 앱 PrDetector)은 온존 — 통합 후속 (PLAN A-5).

---

## 12. 참조 study (브리프 보강 근거)

| study 파일 | 적용된 결정사항 | 핵심 인용 |
|---|---|---|
| `reference/study/subscription-fitness.md` | D8 · D9 · D10 · D11 · D13 | §4 retention 벤치 / §5 여성 WTP / §6 group dynamics / §2 multi-gym pricing |
| `reference/study/pricing.md` | D8 · D9 · D21 | §1 charm / §6 tier / §9 bundle / §10 churn (annual vs monthly) / §10.4 cancel flow |
| `reference/study/ux-testing.md` | D12 · D14 | §2 JTBD / §3.3 Nielsen 5-user / §4 10 heuristics / §5 Baymard friction |
| `reference/study/ui-design-fundamentals.md` | (Phase 2 UI 설계 시 참조) | 5 디자인 프리셋 · 21 파라미터 default-deny 룰 |
| `reference/study/fitness.md` (sub-files: cardio·olympic-lifting·power·gymnastics·hyrox) | 기존 engine·grade 산정 로직 | 페이싱 계산·tier 정의의 학술 근거 |
| `reference/payment.md` | D13 · D22 | Toss Payments + webhook 검증 + idempotency |
| `reference/webhook.md` | D13 · D22 | HMAC-SHA256 + timing-safe compare + replay 방어 |
| `reference/security.md` + `reference/authorization.md` | D17 · §7.1 · D3 | 개인정보보호법 §29·§36 · bcrypt · RBAC · 감사로그 |

신규 보강 시 study 인용 우선 — 임의 결정 금지.
