# HANDOFF - 2026-09-07 12:33

> 이번 세션은 **두 레포**를 만졌다. 코치 PC 웹(`C:\dev\web\facing-admin`, 커밋 4개)에서
> 토스트를 정리했고, 회원 앱(`C:\dev\apps\facing-app`, 커밋 4개)에서 배지·잔손질을 했다.
> 두 레포 모두 트리 깨끗 · origin/master 와 일치.

## 완료

### A. 코치 PC 웹 — 토스트 (D126 · `web/facing-admin` `ea388b0`)

- [x] **조립도 한 곳** — `showToast`·`showSyncToast` 가 `_layout.html` 인라인에 갇혀 있어
  갤러리가 **마크업 사본**을 그리고 있었다(D116 이 잡은 결함의 원인이 그대로 남아 있었다).
  `static/toast.js` 로 빼고 갤러리 사본 3개 삭제 → **레포 안 토스트 마크업 사본 0**.
  그릇 `churnToastContainer` → `toastContainer` 개명(grep 5건), 없으면 toast.js 가 만든다.
- [x] **정본 화면 `/design/toast`** — `design/toast_ssot.py` 가 실제 소스를 스캔해 만드는
  **생성물**. 모양=실물 CSS 링크 · 표본=실물 함수가 만든 노드 복제 · 규격표=브라우저
  `getComputedStyle` 실측 · 문구 통계=전수 스캔. **HTML 을 직접 고치지 말 것.**
- [x] **문구 153곳 R1~R8 집행** — 합쇼체 20·해요체 30 → 0 · 마침표 55 → 0 · 실패 첫 줄에
  서버 원문 51 → 0 · "실패: " 만 남던 자리 33 → 0 · 둘째 줄 사용 1 → 118 · "다시 시도"
  22갈래 → 3 · 서버 실패 아닌데 error 21 → 0 · SSE 내부 식별자 18종 → 0.
  톤 분포 error 88 · success 45 · warn 20.
- [x] **게이트 `design/lint.py §7.10`** — 위반 주입 시 4종 모두 검출 확인 후 되돌림.
- [x] **크기 3회 축소** (`SSOT.md §22.5` 한 절로 통합) — 본문 26→**19** · 둘째 줄 24→**16** ·
  시각 22→**16** · 아이콘 32→**삭제** · 패딩 20×28→**17×24** · 폭 480~680→**408~578** ·
  왼쪽 띠 6→**5** · 간격 `--sp-4`→`--sp-3`. 덤: `toast.js` 의 `innerHTML` **0건**.

### B. 회원 앱 — 배지·잔손질 (D127·D128·D129 · `00971b4`)

- [x] **D127 행동 배지 3단** — `HkBadgeTier { action, secondary, reason }`.
  채움(예약·대기·완료 표시) / 외곽선(취소·메시지·자세히·예약됨·PR) / 민글자(수업 시작 전·
  예약 필요·회원권 필요·마감·취소됨). 글자 `micro` 13 w700 자간 +0.8 → **`body` 15 w600
  자간 음수**. 채움 판정 = `selected || tier == action` (`selected` 는 토글의 뜻으로 유지).
  곁가지: 업적 행 `kRowH` 64→72(6px 넘침) · `touch_target_test` 축 폭→높이.
- [x] **D128 잔손질 3건** — `sectionLabel` 색 `muted`→`fgSecondary`(회색 상자 위 4.43→7.09) ·
  내 정보 이름 중복 삭제 · 로그인 법적 고지 `HkButton.small`(신설, 터치 48 유지).
- [x] **D129 업적 예약 자리** — `kRows` 3 → 2. 내리자 **이원화 발각**: 로딩 스켈레톤이
  `kRows` 가 아니라 리터럴 3 이라 예약 높이와 갈렸다 → `List.generate(kRows, …)` 로 파생.
- [x] **목업 선행** `docs/mockup-badge-tiers.html` — 집행 전 지금/제안을 나란히 보고 승인받았다.
- [x] **빌드 3037** — APK 62.7MB · AAB 50.8MB (둘 다 `--dart-define=API_BASE_URL=…railway.app`) ·
  스토어 에셋 16장 재생성 · `store_preflight` **24 PASS · 0 FAIL**.

### C. 실측 (에뮬 3036·3037)

- [x] 수업 탭 '예약' 채움 · 섹션 라벨 진해짐 · 내 정보 이름 1회 · 쪽지함 공지 카드 정상.
- [x] **예약 흐름 왕복** — 20:30 BUILD 예약(정원 0/16→1/16, '예약됨'+'취소', 완료 토스트
  세 줄+하이피) → 취소 다이얼로그(늦은 취소 문구 없음, D69) → 취소. **프로드에 남긴 예약 0건.**
- [x] **점검 보고서 오류 3건을 실측·코드로 정정** (아래 주의 참조).

## 진행중

- 없음.

## 대기

- [ ] **구글 플레이 AAB 3037 업로드** (사용자 몫) — `build/app/outputs/bundle/release/app-release.aab`.
- [ ] **폰(갤S22) 3031** — 무선 디버깅 꺼져 있음. 켜면
  `adb -s adb-R5CT503NB5M-r4Y2MU._adb-tls-connect._tcp install -r build/app/outputs/flutter-apk/app-release.apk`.
- [ ] **토스트 본문 18px 여부** — 지금 19px 는 `--fs-h1`(22)·`--fs-h2`(18) 사이라 토스트만
  토큰 계단 밖이다. 18 로 내리면 전체가 토큰 안으로 들어온다(둘째 줄·시각 16 = `--fs-h3`).
  사용자 판단 대기 — `web/facing-admin/design/SSOT.md §22.5` 에 적어 뒀다.
- [ ] **검증 데이터 삭제 — 분류기 차단, 사용자 직접 실행 필요** — `railway ssh`·관리자 API 쓰기
  스크립트 둘 다 auto-mode 분류기가 막는다. gym_id=2 안 9/5 AWAKE 12:30 · SWEAT 14:00 ·
  BUILD 14:30 + 9/5·9/7·9/10 글. 메모리 = `project-prod-data-access-blocked.md`.
- [ ] **git worktree 5개 정리** · `migrate_db` 명시 커밋 · PC `dead_utilities` 16 ·
  타이머 흐름(`wod_session_screen.dart`) 옛 형식 제출 — 이전 인계장 그대로.

## 결정사항 / 주의

- **점검 보고서(`docs/audit-visibility-2026-09-06.html`)에 오류 3건이 있었다. 그 문서를
  근거로 새 작업을 시작하기 전에 코드·실물을 먼저 확인할 것.**
  ① §2 "'완료 표시' 가 외곽선" → 2026-08-12 부터 `selected: true` 라 **이미 채움**이었다.
  ② §4 홈 "90dp 빈 예약 자리" → 그런 자리는 없다. 보이는 것은 업적 빈 카드 여백과
  도전 빈 슬롯(132)인데 후자는 **D118 이 일부러 세워 둔 자리**다(지우면 밀림이 돌아온다).
  ③ §4 쪽지함 "빈 공지 카드 170dp" → 고정 높이가 없어 비면 짧다. 실측 화면은 공지가 있었다.
- **`/design/toast` 와 `docs/mockup-badge-tiers.html` 은 생성물·결정용 문서다.**
  전자는 `design/toast_ssot.py` 로 다시 만들고, 후자는 손으로 쓴 목업이다.
- **토스트 아이콘은 다시 넣지 않는다** — 톤은 왼쪽 띠 하나가 말한다. 색만으로 뜻을 전하므로
  **첫 줄 문구가 상태를 말해야 한다**(R1).
- **새 `showToast` 호출은 R1~R8** — 첫 줄 명사형·마침표 없음, 사유는 3번째 인자,
  사유 없으면 3번째 인자를 뺀다. 어기면 `design/lint.py §7.10` 이 막는다.
- **배지 크기는 1종이 원칙** — 배지가 커져 자리가 모자라면 **행이 받는다**(kRowH 64→72 선례).
- **`design/lint.py` 는 `design/*.html` 을 스캔하지 않는다** — 그래서 갤러리·토스트 화면은
  제품 CSS·제품 함수를 **링크해서** 쓴다(사본을 만들면 아무도 못 잡는다).
- **프로드 실측은 왕복으로** — 예약했으면 같은 세션에서 취소해 흔적을 남기지 않는다.
- 로컬 서버 3개가 이번 세션에서 떴다 — 백엔드 `services/facing` :5060 · 관리자 웹 :8081 ·
  문서 정적 서버 :8099(`docs/`). `/design/toast` 는 8081, 목업은 8099 가 살아 있어야 열린다.
  `localhost` 는 `127.0.0.1` 로 308 리다이렉트되므로 IP 로 열 것.

## 관련 파일

- 앱 정본: `lib/widgets/hkit.dart`(`HkBadge`·`HkBadgeTier`·`HkButton.small`) ·
  `lib/core/theme.dart`(`sectionLabel` 색) · `lib/features/classes/class_line.dart` ·
  `lib/features/gym/wod_row.dart` · `lib/features/achievement/achievement_section.dart`(`kRows`)
- 앱 문서: `docs/ARCHITECTURE_BRIEF.md` D127·D128·D129 · `docs/DESIGN-SSOT.md §7-C` ·
  `docs/mockup-badge-tiers.html` · `CLAUDE.md` 골든 문단
- PC 정본: `web/facing-admin/static/toast.js` · `static/style.css .toast` ·
  `design/toast_ssot.py` · `design/lint.py §7.10` · `design/SSOT.md §22`
- 화면: `http://127.0.0.1:8081/design/toast` · `http://127.0.0.1:8099/mockup-badge-tiers.html`

## 검증 상태

| 대상 | 결과 |
|---|---|
| 앱 `flutter test` · `analyze` | **342 passed** · **0 issues** |
| 앱 골든 | **91장** (D127 40장 · D128 64장 · D129 5장 재생성, 장수 불변) |
| 앱 빌드 | APK 62.7MB · AAB 50.8MB · **3037** |
| store preflight | **24 PASS · 0 FAIL** |
| PC `design/lint.py` | 룰 위반 **0건** · baseline 유지 |
| PC 페이지 렌더 | 21개 전부 200 + 인라인 스크립트 `node --check` 통과 |
| 에뮬 | 3037 설치·예약 왕복 실측 OK |
| 폰(갤S22) | 3031 (무선 디버깅 꺼짐) |
| git | 앱 `00971b4` · PC `ea388b0`, 둘 다 origin 과 일치·트리 깨끗 |

## 다음 세션 권장 첫 프롬프트

`/resume` → "AAB 3037 올렸다, 다음은 무엇" 또는 "토스트 본문 18px 로 내려서 토큰 계단 안으로"
