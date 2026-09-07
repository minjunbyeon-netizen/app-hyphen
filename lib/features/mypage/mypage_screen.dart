import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/haptic.dart';
import '../../core/notification_service.dart';
import '../../core/role_labels.dart';
import '../../models/membership.dart';
import '../../core/theme.dart';
import '../../widgets/hkit.dart';
import '../../widgets/inbox_bell.dart';
import '../auth/auth_state.dart';
import '../classes/today_reservations.dart';
import '../contracts/member_contracts_screen.dart';
import 'strength_board_screen.dart';
import '../gym/gym_info_screen.dart';
import '../gym/gym_state.dart';
import 'edit_profile_screen.dart';
import 'privacy_screen.dart';
import 'terms_screen.dart';
import '../../core/app_clock.dart';
import '../../core/time_format.dart';

/// v1.22: Profile = identity + 측정값 편집 진입 + 잘안쓰는 actions.
/// Engine score · Tier · Radar · Category Tier · Trend · Records · RoleModel 등
/// score 관련 컨텐츠는 모두 Home 으로 이동 (중복 제거).
///
/// v2.6 (2026-08-12 사용자 지시 "engine 은 우리가 쓸 데 없다"): ENGINE 섹션을
/// 이 화면에서 내렸다. 코드는 `score_section.dart` 에 보존 — 되돌리려면
/// 아래 children 에 `ScoreSection()` 한 줄을 되살리면 된다.
class MyPageScreen extends StatelessWidget {
  /// 회원 셸에 얹힐 때는 자기 AppBar 를 그리지 않는다 — 상단바는 셸 하나 (v3.24, D47).
  final bool embedded;

  const MyPageScreen({super.key, this.embedded = false});

  // ── 레이아웃 안정성 앵커 (v3.33 · 2026-08-27) ──────────────────────────────
  // 상태(로딩·회원권 유무·일시정지)가 바뀌어도 y 가 움직이면 안 되는 자리들.
  // 회귀 게이트가 이 키로 잰다 (test/golden/stability_mypage_test.dart).
  // 이름을 바꾸면 그 테스트도 같이 바꾼다 (글로벌 §0-B 이름 일원화).
  static const Key kMembership = Key('mypage-membership');
  static const Key kPoints = Key('mypage-points');
  static const Key kNotifications = Key('mypage-notifications');
  static const Key kMenu = Key('mypage-menu');
  static const Key kSignOut = Key('mypage-signout');

  /// 회원권 카드 **안** — 상태 슬롯(비활성·면제·일시정지) 아래가 밀리는지 재는 자리.
  static const Key kMembershipProgress = Key('mypage-membership-progress');
  static const Key kMembershipDates = Key('mypage-membership-dates');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: embedded
          ? null
          : const HkAppBar(title: '내 정보', actions: [InboxBellAction()]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: HyphenTokens.sp3),
          children: const [
            _IdentityCard(),
            _SectionDivider(),
            _MembershipSection(),
            // v3.43 (2026-08-29 사용자 지시): '내 체육관' 섹션 삭제.
            // D83: 그때 남은 구분선 두 겹(굵은 띠로 찍힘)을 한 겹으로.
            _SectionDivider(),
            // v3.1 (2026-08-19 사용자 지시): 신체(체중·키·나이) 아코디언 삭제 —
            // 입력 칸이 v2.3 에서 전부 빠져 영구 '-' 플레이스홀더였다.
            // v3.10 (2026-08-22 사용자 지시 "과한 거 없애라"): 설정 아코디언도
            // 삭제. 단위 토글을 뺀 뒤 남은 건 글자 크기 하나뿐이었고, 그것도
            // 필요 없다는 판단이다 — 아코디언 한 겹이 항목 하나를 감싸고 있었다.
            _ActionsSection(),
          ],
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();
  @override
  // v2.5: 구분선 위아래 24 씩(총 48)이 섹션마다 붙어 화면의 절반이 여백이었다.
  // 아코디언 헤더가 이미 자기 여백을 갖고 있으므로 선만 남긴다 (사용자 지시).
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: HyphenTokens.sp1),
    child: Divider(height: 1, color: HyphenTokens.border),
  );
}

// v2.6 (2026-08-12): ENGINE 섹션(ScoreSection·WeaknessInline)은
// score_section.dart 로 옮겨 보존 — 이 화면에서는 더 이상 그리지 않는다.

// v1.23 Phase 3 (2026-06-02): 출석 캘린더(_AttendanceCompact·_StatBlock)는
// Attend 탭으로 이관됐다가, Attend 탭 자체가 v3.2(2026-08-20)에서 코드까지
// 삭제됨 (README §제거된 기능 대장).

class _IdentityCard extends StatelessWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final gs = context.watch<GymState>();
    // PC 사장이 등록한 GymMemberProfile.name 우선. 없으면 auth.displayName fallback.
    final mp = gs.membership.memberProfile;
    final boxRegisteredName = (mp?.name ?? '').trim();
    // v1.16.2 — 옛 통문자열 "박지훈 · FACING SEONGSU 코치" 가 SharedPreferences 에
    // 캐시돼 있을 수 있어 ' · ' 첫 부분만 잘라서 진짜 이름만 사용.
    String firstSegment(String s) {
      final i = s.indexOf(' · ');
      return i > 0 ? s.substring(0, i).trim() : s.trim();
    }

    final name = boxRegisteredName.isNotEmpty
        ? boxRegisteredName
        : ((auth.displayName?.trim().isNotEmpty == true)
              ? firstSegment(auth.displayName!)
              : 'Athlete');
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HyphenTokens.sp4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 아바타 — 현재는 첫 글자. 향후 사진 설정 시 Avatar 위젯으로 교체.
              // v2.5: 56 → 40 (사용자 지시 "50% 수준으로 컴팩트").
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: HyphenTokens.accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: HyphenTokens.accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: HyphenTokens.h3.copyWith(color: HyphenTokens.accent),
                ),
              ),
              const SizedBox(width: HyphenTokens.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: HyphenTokens.h3),
                    // v1.16.2 — 체육관명 · 역할 / 위치 (GymState 데이터 소스).
                    // v3.33 (2026-08-27): **두 줄 자리를 항상 예약**한다
                    // (§레이아웃 안정성 · 공간 예약). loadMine() 전에는 gym 이
                    // null 이라 두 줄이 통째로 없다가 응답이 오는 순간 신원
                    // 카드가 두 줄만큼 커지며 그 아래 전부가 밀렸다. 값이 없는
                    // 동안은 공백 한 칸으로 줄 높이만 남긴다.
                    Builder(
                      builder: (_) {
                        final gym = gs.membership.gym;
                        final roleLabel = roleKoLabel(
                          role: gs.membership.role,
                          status: gs.membership.status,
                        );
                        final gymLine = [
                          if (gym?.name != null && gym!.name.isNotEmpty)
                            gym.name,
                          if (roleLabel.isNotEmpty) roleLabel,
                        ].join(' · ');
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // v3.43 (2026-08-29 사용자 지시): 체육관 주소 줄 삭제.
                            _ReservedLine(gymLine),
                          ],
                        );
                      },
                    ),
                    // v2.5: 로그인 수단(NAVER 등) 표기 삭제 — 회원이 이 화면에서
                    // 할 수 있는 일이 없는 정보다 (사용자 지시 "안 쓰는 건 안 보이게").
                  ],
                ),
              ),
              // 수정 진입은 이름 줄 오른쪽 아이콘으로 — 아래 전폭 버튼 한 줄을 없앤다.
              IconButton(
                tooltip: '프로필 수정',
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: HyphenTokens.fgSecondary,
                onPressed: () {
                  Haptic.light();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          // 코치가 남긴 메모가 실제로 있을 때만 카드를 낸다. (등록값만 있고
          // 메모가 없으면 제목만 남은 빈 카드가 돼 자리만 먹는다.)
          //
          // §레이아웃 안정성 **예외** (v3.33 · 사유를 여기 남긴다): 이 카드만은
          // 자리를 예약하지 않는다. 높이가 메모 글자 수에 따라 한 줄~여러 줄로
          // 변해 '가장 긴 경우'가 없고, 메모를 안 받은 대다수 회원에게 100px
          // 가까운 빈 카드를 매번 깔게 된다. 대신 이 블록은 화면 **맨 위**
          // 신원 카드 안에서 loadMine() 한 번에만 붙고, 그 뒤로는 SSE 로도
          // 토글되지 않는다 (코치 메모 변경은 새 loadMine 을 타고 온다).
          // v3.43 (2026-08-29 사용자 지시): '체육관 기록'(주의 사항·메모) 카드 삭제.
        ],
      ),
    );
  }
}

/// 값이 없어도 **한 줄 높이를 지키는** caption 한 줄 (§레이아웃 안정성 · 공간 예약).
/// 비어 있으면 공백 한 칸을 그려 줄 높이만 남긴다 — 값이 늦게 도착해도
/// 그 아래 요소의 y 가 움직이지 않는다.
class _ReservedLine extends StatelessWidget {
  final String text;
  const _ReservedLine(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      text.isEmpty ? ' ' : text,
      style: HyphenTokens.caption,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}



// v3.1 (2026-08-19 사용자 지시): _BodyStats·_Kv(신체 아코디언) 삭제 —
// 체중·키·나이 입력 경로가 v2.3 온보딩·프로필 수정 개편에서 전부 빠져
// 값이 영구 '-' 인 죽은 표시부였다. 성별은 프로필 수정 화면이 담당.

class _ActionsSection extends StatelessWidget {
  const _ActionsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HyphenTokens.sp4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Consumer<AuthState>(
            builder: (ctx, auth, _) {
              if (!auth.isSignedIn) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: HyphenTokens.sp3),
                child: Row(
                  children: [
                    // v2.6: 앞에 붙던 로그인 수단이 실기에서 'MEMBER_ID' 라는
                    // 내부 코드값 그대로 나왔다. 회원이 이 화면에서 그걸로 할 수
                    // 있는 일이 없다 — 이름만 남긴다 (v2.5 에 IdentityCard 에서
                    // 같은 이유로 지운 표기가 여기 한 줄 남아 있었다).
                    // 2026-09-07 가시성 점검 §4 — 같은 이름이 이 화면에 두 번
                    // 있었다 (위 카드의 h3 이름 + 여기 caption). 한 화면에서 같은
                    // 사실을 두 번 말하지 않는다. 자리는 Spacer 가 그대로 잡는다.
                    const Spacer(),
                    // v2.2 (H18): 계정을 끊는 동작인데 옆 계정 표시와 같은
                    // 글자 덩어리라 눌리는지 보이지 않았다. 테두리를 줘서
                    // "동작"임을 알린다 (파괴적이진 않으므로 danger 는 아니다 —
                    // 확인 다이얼로그가 이미 붙어 있다).
                    HkButton.secondary(
                      '로그아웃',
                      key: MyPageScreen.kSignOut,
                      expand: false,
                      onPressed: () => _confirmSignOut(context),
                    ),
                  ],
                ),
              );
            },
          ),
          // B-5 (2026-06-10) — 회원 포인트 잔액 (적립 토스트 "+NP" 와 신뢰 일치)
          const _PointsBalanceRow(),
          // D83 (2026-08-29 사용자 지시 "내 정보에 메뉴란 항상 펼쳐놓고, 알림 받기도
          // 밑에 메뉴 안에 1곳으로 넣고, 저기에 체육관 정보 새로 만들고"):
          // v1.31 아코디언(기본 접힘)을 폐기하고 **항상 펼친 표 하나**. '알림 받기'
          // (2026-08-28 한 줄 토글)는 별도 카드가 아니라 이 표의 한 줄이다.
          const SizedBox(height: HyphenTokens.sp2),
          const Padding(
            key: MyPageScreen.kMenu,
            padding: EdgeInsets.only(bottom: HyphenTokens.sp2),
            child: HkSectionLabel('메뉴'),
          ),
          HkRowCard(
                rows: [
                  // D83 — 체육관 이름·주소·전화 · 코치 · 수업 종류(이름+설명) ·
                  // 수업 시간 · 모토. D81 로 사라졌던 '수업 종류' 노출 자리가 여기다.
                  HkListRow(
                    icon: Icons.store_outlined,
                    title: '체육관 정보',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GymInfoScreen(),
                      ),
                    ),
                  ),
                  // B-6 (2026-06-10) — 회원 전자계약 목록·상세·서명 진입
                  HkListRow(
                    icon: Icons.assignment_outlined,
                    title: '전자계약서',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MemberContractsScreen(),
                      ),
                    ),
                  ),
                  HkListRow(
                    icon: Icons.history,
                    title: '히스토리',
                    onTap: () => Navigator.of(context).pushNamed('/history'),
                  ),
                  // v3.31 (2026-08-27 사용자 지시): '목표' 행 삭제 — 화면 코드
                  // (lib/features/goals/)까지 제거 (README §제거된 기능 대장 32).
                  // 서버 목표 API·DB 는 그대로 둔다 — 착용 칭호가 같은 GoalsState 를 쓴다.
                  // Q3 (v3.4 2026-08-20 승인) — 리프트별 역대 최고 무게 (1RM 보드).
                  HkListRow(
                    icon: Icons.fitness_center,
                    title: '최고 기록',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StrengthBoardScreen(),
                      ),
                    ),
                  ),
                  // v2.6 (2026-08-13 사용자 지시) — 없는 기능 두 줄 삭제.
                  //  · '데이터 가져오기' = 화면 스스로 "가상 UI" 라고 적어둔 껍데기.
                  //    BTWB·Wodify '지원 예정' 만 늘어놓을 뿐 붙는 데가 없다.
                  //  · '알고리즘' = Engine 점수 6 카테고리·Tier 1~6(Scaled–Games)·
                  //    SPLIT/BURST 산식 설명. 앱에서 D34 로 전부 내린 기능이고,
                  //    회원 레벨은 경력 3단(SCALED/RXD/ELITE)이라 RX+·Games 는 없는 등급이다.
                  // 화면 파일은 v3.2(2026-08-20)에서 코드까지 삭제
                  // (README §제거된 기능 대장 — 복원은 git log).
                  // 2026-08-28 사용자 확정 — '알림 받기' 한 줄. 종류별로 나누지 않는다.
                  // D83 — 메뉴 표 안 한 줄로 이동 (종전엔 포인트 아래 별도 카드).
                  const _NotificationsRow(),
                  // v3.31 (2026-08-27 사용자 지시): 'FAQ'·'고객지원' 행 삭제 —
                  // FAQ 는 화면 코드(faq_screen.dart)까지 제거, 고객지원은
                  // 카카오톡 채널 링크뿐이라 행만 제거 (README §제거된 기능 대장 33·34).
                  // v2.6 (2026-08-12 사용자 지시): '직원 계정 연결' 행 삭제 — 코치가
                  // 곧 본인 한 명이라 연결할 직원이 없다 (BRIEF D37). 화면·라우트는
                  // v3.2(2026-08-20)에서 코드까지 삭제 (README §제거된 기능 대장).
                  HkListRow(
                    icon: Icons.lock_outline,
                    title: '개인정보처리방침',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                    ),
                  ),
                  // P0-1 (2026-06-10): 이용약관 진입 — 가입 화면 외 상시 접근 경로.
                  HkListRow(
                    icon: Icons.article_outlined,
                    title: '이용약관',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TermsScreen()),
                    ),
                  ),
                ],
              ),
              // v3.31 (2026-08-27 사용자 지시): '데이터 초기화' 버튼·확인
              // 다이얼로그(_confirmReset) 삭제 (README §제거된 기능 대장 35).
          // v2.2 (2026-08-12 사용자 지시): DEBUG 블록 전면 삭제.
          // 빠른 전환 아바타 바 · Persona Switcher · 데모 진입은 화면을 어지럽히기만
          // 했다. kDebugMode 가드가 있어도 개발 중 매번 보이는 화면이라 제거한다.
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await HkDialog.confirm(
      context,
      title: '로그아웃',
      message:
          '로그아웃하면 이 기기와 회원 연결이 끊깁니다.\n'
          '같은 아이디로 다시 로그인하면 기록이 그대로 이어집니다.\n'
          '계정 삭제는 내 정보 → 개인정보처리방침 → 계정 삭제.',
      confirmLabel: '로그아웃',
    );
    if (!ok) return;
    if (!context.mounted) return;
    await context.read<AuthState>().signOut();
    if (!context.mounted) return;
    context.read<GymState>().resetLocal();
    // v3.31: 진입 화면이 곧 로그인 화면이다 ('/signup' 갈림길 폐지).
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }
}

class _MembershipSection extends StatelessWidget {
  const _MembershipSection();

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GymState>();
    final ms = gs.currentMembership;
    final lk = gs.myLocker;

    // v3.33 (2026-08-27) — **아직 모르는 것(로딩)과 정말 없는 것(미보유)을
    // 가른다** (§레이아웃 안정성 · 공간 예약). 둘 다 화면에서 지워 버리면
    // loadMine() 이 끝나는 순간 섹션이 통째로 생겨나며 아래 전부가 밀렸다
    // (로그인 화면이 미리 불러오므로 평소엔 안 보이지만, 느린 망·셸 재진입
    // 에서 드러난다). 접힌 아코디언 헤더는 어느 경우에나 같은 높이라
    // 이 자리 자체가 예약 자리 역할을 한다 — 헤더 한 줄은 늘 서 있다.
    if (ms == null && lk == null) {
      final loading = gs.isLoading;
      return Padding(
        key: MyPageScreen.kMembership,
        padding: const EdgeInsets.symmetric(horizontal: HyphenTokens.sp4),
        child: HkAccordion(
          title: '회원권',
          subtitle: loading ? '불러오는 중' : '회원권 없음',
          children: [
            const SizedBox(height: HyphenTokens.sp2),
            if (loading)
              const HkLoading()
            else
              const Text('등록된 회원권 없음.', style: HyphenTokens.caption),
            const SizedBox(height: HyphenTokens.sp2),
          ],
        ),
      );
    }

    final parts = <String>[];
    if (ms != null && !ms.isActive) {
      // D57 PC 실주행 (2026-08-26): 해지된 회원권이 "3회 남음" 으로 남아 보이던 갭 —
      // active 가 아니면 잔여·기한 대신 상태 한 단어. (활성권이 하나라도 있으면
      // currentMembership 이 그쪽을 고르므로 여기는 전부 비활성일 때만 온다.)
      parts.add(ms.status == 'expired' ? '만료됨' : '해지됨');
    } else if (ms != null) {
      final days = ms.daysUntilExpiry;
      // D57 횟수권 — 잔여 횟수가 먼저, 기한은 뒤에.
      if (ms.isSessionPass) {
        parts.add('${ms.sessionRemaining ?? 0}회 남음');
      }
      if (days == null) {
        parts.add('기간 정보 없음');
      } else if (days < 0) {
        parts.add('만료됨');
      } else {
        parts.add(ms.isSessionPass ? '$days일 후 만료' : '$days일 남음');
      }
      if (ms.isPausedNow) parts.add('일시정지 중');
    }
    if (lk != null) parts.add('락커 ${lk.lockerNo}');

    return Padding(
      key: MyPageScreen.kMembership,
      padding: const EdgeInsets.symmetric(horizontal: HyphenTokens.sp4),
      child: HkAccordion(
        title: '회원권',
        subtitle: parts.join(' · '),
        children: const [
          SizedBox(height: HyphenTokens.sp2),
          _MembershipCard(),
          _LockerCard(),
          SizedBox(height: HyphenTokens.sp2),
        ],
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard();

  @override
  Widget build(BuildContext context) {
    final ms = context.watch<GymState>().currentMembership;
    if (ms == null) return const SizedBox.shrink();
    final days = ms.daysUntilExpiry;
    // D57 횟수권 — 막대는 사용 횟수 비율, 기간제는 기간 경과 비율.
    final progress = ms.isSessionPass ? ms.sessionProgress : (ms.progress ?? 0);
    final isExpiringSoon = days != null && days <= 14 && days >= 0;
    final isExpired = days != null && days < 0;
    Color accentColor;
    if (isExpired) {
      accentColor = HyphenTokens.danger;
    } else if (isExpiringSoon) {
      accentColor = HyphenTokens.warning;
    } else {
      accentColor = HyphenTokens.primary;
    }

    DateTime? start;
    DateTime? end;
    try {
      if (ms.startDate != null) start = DateTime.parse(ms.startDate!);
      if (ms.endDate != null) end = DateTime.parse(ms.endDate!);
    } catch (_) {}

    return Padding(
      // 가로 여백은 감싸는 _MembershipSection 아코디언이 준다.
      padding: EdgeInsets.zero,
      child: HkCard(
        padding: const EdgeInsets.all(HyphenTokens.sp4),
        radius: HyphenTokens.r2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ms.planName ?? '이용중',
                  style: HyphenTokens.h3.copyWith(color: HyphenTokens.fg),
                ),
                const Spacer(),
                if (days != null)
                  Text(
                    isExpired ? '만료' : 'D-${days.abs()}',
                    style: HyphenTokens.h3.copyWith(color: accentColor),
                  ),
              ],
            ),
            // 상태 줄 — 비활성 안내 · 횟수권 면제 잔여 · 일시정지가
            // **하나의 예약된 자리**를 나눠 쓴다 (§레이아웃 안정성).
            _MembershipStatusSlot(ms),
            // 진행 막대 — 사용 비율 = progress, 남은 비율 = 1-progress
            TweenAnimationBuilder<double>(
              key: MyPageScreen.kMembershipProgress,
              tween: Tween(begin: 0, end: progress.clamp(0, 1)),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, value, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 8, color: HyphenTokens.surfaceMax),
                      FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: HyphenTokens.mutedStrong,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  ms.isSessionPass
                      ? '${ms.sessionUsed ?? 0}회 사용'
                      : '${(progress * 100).toStringAsFixed(0)}% 사용',
                  style: HyphenTokens.caption,
                ),
                const Spacer(),
                Text(
                  ms.isSessionPass
                      ? '${ms.sessionRemaining ?? 0}회 남음'
                      : '${((1 - progress) * 100).toStringAsFixed(0)}% 남음',
                  style: HyphenTokens.caption.copyWith(color: accentColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 월별 타임라인
            if (start != null && end != null)
              _MembershipTimeline(start: start, end: end, accent: accentColor),
            const SizedBox(height: 6),
            Row(
              key: MyPageScreen.kMembershipDates,
              children: [
                Text(ms.startDate ?? '', style: HyphenTokens.caption),
                const Spacer(),
                Text(ms.endDate ?? '', style: HyphenTokens.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 회원권 카드 상태 줄 — **배너 3종이 하나의 예약된 자리를 나눠 쓴다**
/// (v3.33 · 2026-08-27 · §레이아웃 안정성 · 공간 예약).
///
/// 전엔 (1) 비활성(해지·만료) 안내 (2) 횟수권 면제 잔여 (3) 일시정지 배너가
/// 각각 `if (…) …[]` 로 쌓여 있었다. 코치가 PC 에서 상태를 바꾸면 SSE 로
/// 화면이 열려 있는 동안 줄이 생겼다 사라지며 진행 막대·사용률·시작/종료일이
/// 통째로 밀렸다.
///
/// **동시 표시 가능성 (코드 확인)**: (1) 은 `!isActive`, (2) 는 `isActive` 라
/// 서로 배타적이다. 반면 (3) 은 status 를 보지 않고 정지 창
/// (`pause_start ≤ 오늘 < pause_end`) 만 보므로 (1)+(3)·(2)+(3) 은 **같이 뜬다**
/// (models/membership.dart isPausedNow·isPauseScheduled). 그래서 자리는
/// 최악인 **두 줄**(배지 줄 + caption 줄) 기준으로 잡고, 안내·에러 예약 자리의
/// 정본 높이 [HyphenTokens.noticeSlotH] 를 그대로 쓴다.
///
/// 내용이 0줄이어도 자리는 그대로 남는다 — 색을 지우거나 회색으로 내리지 않는다.
class _MembershipStatusSlot extends StatelessWidget {
  final Membership ms;
  const _MembershipStatusSlot(this.ms);

  @override
  Widget build(BuildContext context) {
    final lines = <Widget>[];
    // 일시정지 상태 (2026-08-24 갭 해소 — PC 만 알던 정지 창 표시).
    if (ms.isPausedNow || ms.isPauseScheduled) {
      lines.add(
        Row(
          children: [
            HkBadge(
              ms.isPausedNow ? '일시정지 중' : '일시정지 예정',
              color: HyphenTokens.warning,
            ),
            const SizedBox(width: HyphenTokens.sp2),
            Expanded(
              child: Text(
                '${ms.pauseStart ?? ''} ~ ${ms.pauseEnd ?? ''}',
                style: HyphenTokens.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    if (!ms.isActive) {
      // 비활성(해지·환불·만료) 회원권 — 예약에 못 쓴다는 한 줄.
      lines.add(
        Text(
          ms.status == 'expired'
              ? '만료된 회원권 — 예약에 쓸 수 없습니다.'
              : '해지된 회원권 — 예약에 쓸 수 없습니다.',
          style: HyphenTokens.caption.copyWith(color: HyphenTokens.danger),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else if (ms.isSessionPass) {
      // D57 (2026-08-26) 횟수권 — 면제 잔여 (노쇼·늦은 취소 각 1회).
      lines.add(
        Text(
          '노쇼 면제 ${ms.freeNoShowLeft}회 · 늦은 취소 면제 ${ms.freeLateCancelLeft}회 남음',
          style: HyphenTokens.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return SizedBox(
      height: HyphenTokens.noticeSlotH,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: lines,
      ),
    );
  }
}

/// v1.16.2 — 회원권 월별 타임라인.
/// start ~ end 범위를 6 ~ 12 칸 셀로 분할해서 가로 띠로 렌더.
/// 셀 색: 지난 구간 = mutedStrong / 미래 구간 = accent (primary).
/// today 위치에 ▲ 마커, 위쪽에 월 라벨.
class _MembershipTimeline extends StatelessWidget {
  const _MembershipTimeline({
    required this.start,
    required this.end,
    required this.accent,
  });
  final DateTime start;
  final DateTime end;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final totalDays = end.difference(start).inDays.clamp(1, 9999);
    final now = appClock.now();
    final today = now.gymDay();
    final elapsedDays = today
        .difference(start)
        .inDays
        .clamp(0, totalDays)
        .toInt();
    final todayFraction = elapsedDays / totalDays;

    // 월 단위 라벨 — 시작 월부터 끝 월까지.
    final monthLabels = <DateTime>[];
    DateTime cursor = DateTime(start.year, start.month, 1);
    final endMonth = DateTime(end.year, end.month, 1);
    while (!cursor.isAfter(endMonth)) {
      monthLabels.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final todayX = (width * todayFraction).clamp(0, width).toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 월 라벨 줄
            SizedBox(
              height: 14,
              child: Stack(
                clipBehavior: Clip.none,
                children: monthLabels.map((m) {
                  final monthFrac = m.difference(start).inDays / totalDays;
                  final clamped = monthFrac.clamp(0, 1).toDouble();
                  final x = (width * clamped).clamp(0, width - 22).toDouble();
                  return Positioned(
                    left: x,
                    top: 0,
                    child: Text(
                      '${m.month}월',
                      style: HyphenTokens.caption.copyWith(
                        color: m.month == now.month && m.year == now.year
                            ? accent
                            : HyphenTokens.muted,
                        fontWeight: m.month == now.month && m.year == now.year
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            // 타임라인 바 (왼쪽=과거 mutedStrong / 오른쪽=미래 accent)
            SizedBox(
              height: 18,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 전체 배경
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: HyphenTokens.surfaceMax,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // 지난 구간
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: todayX,
                    child: Container(
                      decoration: BoxDecoration(
                        color: HyphenTokens.mutedStrong,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // 미래 구간 (남은 회원권)
                  Positioned(
                    left: todayX,
                    top: 0,
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // today 마커
                  Positioned(
                    left: todayX - 1,
                    top: -2,
                    bottom: -2,
                    width: 2,
                    child: Container(color: HyphenTokens.fg),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 오늘 표식. clamp 상한이 라벨 실폭(약 30)이 아니라 24 로 잡혀 있어
            // 만료 직전(todayX 가 오른쪽 끝)이면 글자가 잘렸다 — v1.31 정정.
            SizedBox(
              height: 14,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: (todayX - 15)
                        .clamp(0, (width - 30).clamp(0, double.infinity))
                        .toDouble(),
                    top: 0,
                    child: Text(
                      '오늘',
                      style: HyphenTokens.caption.copyWith(
                        color: HyphenTokens.fg,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// v1.16.2 (2026-05-24) — 내 락커 카드.
/// GymState.myLocker 에서 fetch. 배정된 락커 없으면 안 그림.
class _LockerCard extends StatelessWidget {
  const _LockerCard();

  @override
  Widget build(BuildContext context) {
    final lk = context.watch<GymState>().myLocker;
    if (lk == null) return const SizedBox.shrink();
    final days = lk.daysUntilExpiry;
    return Padding(
      // 가로 여백은 감싸는 _MembershipSection 아코디언이 준다.
      padding: const EdgeInsets.only(top: HyphenTokens.sp3),
      child: HkCard(
        padding: const EdgeInsets.all(HyphenTokens.sp4),
        radius: HyphenTokens.r2,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: HyphenTokens.surfaceMax,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                lk.lockerNo,
                style: HyphenTokens.h3.copyWith(color: HyphenTokens.fg),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HkSectionLabel('내 락커'),
                  const SizedBox(height: 4),
                  Text(
                    lk.endDate != null && lk.endDate!.isNotEmpty
                        ? '${lk.endDate} 까지'
                        : '회원권 만료일 자동',
                    style: HyphenTokens.body.copyWith(color: HyphenTokens.fg),
                  ),
                  if (lk.memo != null && lk.memo!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(lk.memo!, style: HyphenTokens.caption),
                    ),
                ],
              ),
            ),
            // 라벨은 서버 d_day_label 그대로 (2026-09-02 — 'D-0' 대신 서버 'D-day').
            // 14일 표시 창은 회원권 카드와 같은 앱 표시 규약.
            if (days != null && days >= 0 && days <= 14 && lk.dDayLabel != null)
              Text(
                lk.dDayLabel!,
                style: HyphenTokens.h3.copyWith(color: HyphenTokens.warning),
              ),
          ],
        ),
      ),
    );
  }
}

/// B-5 (2026-06-10) — 회원 포인트 잔액 행.
///
/// v3.33 (2026-08-27 · §레이아웃 안정성 · 공간 예약): 전엔 `_balance == null`
/// 이면 `SizedBox.shrink()` 라, 응답이 오는 순간 카드가 통째로 생겨나며 바로
/// 아래 '메뉴' 아코디언과 위쪽 로그아웃 줄 주변이 흔들렸다. 이제 **카드는
/// 처음부터 서 있고 숫자만** 갈린다 — 값을 모르는 동안은 `--`.
/// (서버는 미소속이어도 `balance: 0` 을 준다. `--` 가 남는 경우는 응답 전이거나
///  네트워크가 끊긴 때뿐이다.)
/// 내 정보 '알림 받기' 한 줄 — 켜거나 끄거나 **하나**다 (2026-08-28 사용자 확정
/// "일괄로 처리"). 종류별로 나누지 않는다.
///
/// 값은 기기에만 둔다 ([NotificationService.prefsKey]). 서버로 보내지 않는 이유는
/// 지금 알림을 서버가 보내지 않기 때문이다 — 앱이 살아 있을 때 SSE 로 받아 폰에
/// 띄우거나, 예약해 둔 수업 알림이 기기에서 울린다. 둘 다 이 기기의 일이다.
///
/// **막는 자리는 여기가 아니다.** 껐을 때 실제로 알림을 막는 관문은
/// [NotificationService] 안 두 곳(`showFromSseEvent`·`scheduleClassReminder`)
/// 뿐이다 — 화면마다 검사하면 언젠가 한 곳이 빠진다.
///
/// **레이아웃 안정성 (DESIGN-SSOT §레이아웃 안정성)**: 이 행은 자리를 비워 두는
/// 방식(HkNoticeSlot)을 쓰지 않는다. 부제(subtitle)를 **상태와 무관하게 항상 한 줄**
/// 두고 글자만 갈아 끼우므로 행 높이가 처음부터 끝까지 같다. 빈 띠가 남는 D69 의
/// 실패도 없고, 안내가 붙었다 빠지며 아래가 밀리는 일도 없다.
class _NotificationsRow extends StatefulWidget {
  const _NotificationsRow();

  @override
  State<_NotificationsRow> createState() => _NotificationsRowState();
}

class _NotificationsRowState extends State<_NotificationsRow>
    with WidgetsBindingObserver {
  /// 앱 설정 — 첫 프레임은 이미 읽어 둔 값으로 그린다 (main.dart 가 미리 읽는다).
  bool _on = NotificationService.instance.enabledNow;

  /// 폰 설정(OS) 권한. 알림을 못 다루는 기기(데스크톱)는 막힌 것이 아니므로 true.
  bool _granted = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 폰 설정에서 허용하고 돌아왔는데도 '차단됨' 이 남아 있으면 그것도 거짓말이다
  /// — 앱으로 돌아올 때마다 권한을 다시 읽는다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final svc = NotificationService.instance;
    final on = await svc.isEnabled();
    final granted = svc.supported ? await svc.isPermissionGranted() : true;
    if (!mounted) return;
    setState(() {
      _on = on;
      _granted = granted;
    });
  }

  Future<void> _toggle(bool next) async {
    if (_busy) return;
    _busy = true;
    Haptic.light();
    final svc = NotificationService.instance;
    final api = context.read<ApiClient>();
    // 끄면 걸어 둔 예약분까지 지운다 (setEnabled 안에서).
    await svc.setEnabled(next);
    var granted = _granted;
    if (next && svc.supported) {
      // 켤 때만 권한을 묻는다. 폰 설정에서 막아 뒀으면 앱이 아무리 켜도 안 뜬다.
      granted = await svc.isPermissionGranted();
      if (!granted) granted = await svc.requestPermission();
    }
    if (!mounted) {
      _busy = false;
      return;
    }
    setState(() {
      _on = next;
      _granted = granted;
      _busy = false;
    });
    if (next && granted) {
      // 껐을 때 지운 예약분을 그 자리에서 되돌린다 — 셸이 탭을 살려 두므로
      // 홈이 다시 뜨기를 기다리면 이번 세션 내내 알림이 안 걸린다.
      await refetchAndRestoreClassReminders(api);
    }
    if (next && svc.supported && !granted && mounted) {
      await HkDialog.info(
        context,
        title: '폰에서 알림이 차단되어 있습니다',
        message: '폰 설정 → 앱 → HYPHEN → 알림 에서 허용해야 알림이 옵니다.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _on && !_granted;
    // D83 — 메뉴 표(HkRowCard)의 한 줄. 카드 껍데기는 표가 가진다.
    return HkListRow(
      key: MyPageScreen.kNotifications,
      icon: Icons.notifications_none,
      iconColor: blocked ? HyphenTokens.danger : null,
      title: '알림 받기',
      // 세 상태 모두 한 줄 — 행 높이가 변하지 않는다.
      subtitle: blocked
          ? '폰 설정에서 알림이 차단되어 있습니다.'
          : _on
          ? '쪽지 · 수업 시작 1시간 전 알림을 받습니다.'
          : '알림을 받지 않습니다.',
      subtitleColor: blocked ? HyphenTokens.danger : null,
      // 켜 두었어도 폰이 막고 있으면 트랙을 중립색으로 — 위치는 내 설정,
      // 색은 실제로 오고 있는지. 둘 다 드러난다.
      trailingWidget: HkSwitch(
        value: _on,
        activeColor: blocked ? HyphenTokens.muted : null,
        onChanged: _toggle,
      ),
      onTap: () => _toggle(!_on),
    );
  }
}

class _PointsBalanceRow extends StatefulWidget {
  const _PointsBalanceRow();

  @override
  State<_PointsBalanceRow> createState() => _PointsBalanceRowState();
}

class _PointsBalanceRowState extends State<_PointsBalanceRow> {
  int? _balance;
  GymState? _gymState;

  @override
  void initState() {
    super.initState();
    _load();
    // 2026-08-24 — 적립·SSE 후에도 800P 고착되던 갱신 배선 (challenge_section
    // 결함 수정 6 과 동일 패턴: GymState notify 를 듣고 재조회).
    _gymState = context.read<GymState>();
    _gymState?.addListener(_load);
  }

  @override
  void dispose() {
    _gymState?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    try {
      final api = context.read<ApiClient>();
      final res = await api.get('/api/v1/member/points');
      if (!mounted) return;
      final balance = (res['balance'] as num?)?.toInt();
      setState(() => _balance = balance);
    } catch (_) {
      // 미소속·네트워크 실패 → 숫자는 '--' 로 남는다. 카드는 자리를 지킨다
      // (§레이아웃 안정성 — 없어졌다 생기는 쪽이 더 나쁘다).
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _balance;
    return Padding(
      key: MyPageScreen.kPoints,
      padding: const EdgeInsets.only(bottom: HyphenTokens.sp3),
      child: HkCard(
        padding: const EdgeInsets.symmetric(
          horizontal: HyphenTokens.sp4,
          vertical: HyphenTokens.sp3,
        ),
        radius: HyphenTokens.r2,
        child: Row(
          children: [
            const Expanded(child: HkSectionLabel('포인트')),
            Text(
              balance == null ? '-- P' : '$balance P',
              style: HyphenTokens.h3.copyWith(color: HyphenTokens.primary),
            ),
          ],
        ),
      ),
    );
  }
}
