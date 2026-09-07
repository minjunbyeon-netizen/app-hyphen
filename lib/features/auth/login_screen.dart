import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/device_id.dart';
import '../../core/exception.dart';
import '../../core/haptic.dart';
import '../../core/remembered_login.dart';
import '../../core/theme.dart';
import '../../widgets/hkit.dart';
import '../boss/boss_api_client.dart';
import '../boss/boss_auth_state.dart';
import '../gym/gym_state.dart';
import '../mypage/privacy_screen.dart';
import '../mypage/terms_screen.dart';
import '../profile/profile_state.dart';
import 'auth_state.dart';

/// 로그인 — **창구는 하나다** (v3.19 · 2026-08-25 사용자 지시).
///
/// v3.31 (2026-08-27 사용자 지시): 앱을 열면 곧바로 이 화면이다. 로그인·가입을
/// 고르게 하던 갈림길 화면(구 `SignupScreen`)은 삭제했고, 그 화면이 갖고 있던
/// '회원 가입 신청' 줄과 약관·개인정보처리방침 링크를 이 화면 아래로 옮겼다.
///
/// 사람이 '회원 로그인 / 코치 로그인' 을 골라 들어가는 구조 자체를 없앴다.
/// 아이디·비밀번호만 받고 계정 유형 판정은 **서버**가 한다:
/// `POST /api/v1/auth/login` 이 `kind: coach|member` 를 내려주고, 이 화면은
/// 그 값만 보고 코치 셸(`/boss/dashboard`) 과 회원 셸(`/shell`) 로 가른다.
///
/// - 코치: 응답의 세션 쿠키·CSRF 를 [BossAuthState] 에 저장 (구 BossLoginScreen 몫).
/// - 회원: 응답의 device_id 를 [DeviceIdService.adopt] 로 채택 — 이후 모든 회원
///   API 는 종전대로 X-Device-Id 헤더로 동작한다. 폰이 바뀌어도 같은 기록으로 들어온다.
///
/// 사용자 지시로 이 화면에는 브랜드 로고를 넣지 않는다 (스플래시·진입 화면과 구분).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  /// 라우트 인자 키 — 이 화면에 온 사유를 한 줄 띄울 때 (`{argNotice: 문구}`).
  /// D59 (2026-08-26): 코치 세션 만료 → CoachShell 이 이 인자로 보낸다.
  static const String argNotice = 'notice';
  static const String noticeSessionExpired = '로그인이 만료되었습니다. 다시 로그인해 주세요.';

  // ── 레이아웃 안정성 앵커 (v3.33 · 2026-08-27) ──────────────────────────────
  // 상태가 바뀌어도 y 가 움직이면 안 되는 요소들. 회귀 게이트가 이 키로 잰다
  // (test/golden/layout_stability_test.dart). 이름을 바꾸면 그 테스트도 같이
  // 바꾼다 (글로벌 §0-B 이름 일원화).
  static const Key kIdField = Key('login-id-field');
  static const Key kPwField = Key('login-pw-field');
  static const Key kSubmit = Key('login-submit');
  static const Key kSignup = Key('login-signup');
  static const Key kLegal = Key('login-legal');

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _busy = false;
  bool _pwVisible = false;
  bool _remember = false;
  String? _error;
  bool _noticeApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 라우트 인자로 온 사유(세션 만료 등)는 에러 줄 자리에 한 번만 띄운다 —
    // 다음 로그인 시도에서 _error 가 비워지며 같이 사라진다.
    if (_noticeApplied) return;
    _noticeApplied = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args[LoginScreen.argNotice] is String) {
      _error = args[LoginScreen.argNotice] as String;
    }
  }

  @override
  void initState() {
    super.initState();
    // 30일 안에 로그인한 적이 있으면 아이디를 채워 둔다 (비밀번호는 저장 안 함).
    RememberedLogin.load().then((id) {
      if (!mounted || id == null) return;
      setState(() {
        _idCtrl.text = id;
        _remember = true;
      });
    });
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    Haptic.medium();

    final loginId = _idCtrl.text.trim();
    final bossApi = context.read<BossApiClient>();
    final bossAuth = context.read<BossAuthState>();
    final auth = context.read<AuthState>();
    final profile = context.read<ProfileState>();
    final navigator = Navigator.of(context);
    GymState? gymState;
    try {
      gymState = context.read<GymState>();
    } catch (_) {}

    try {
      final result = await bossApi.unifiedLogin(loginId, _pwCtrl.text);
      final data = result['data'] as Map<String, dynamic>;
      // 판정은 서버가 한다. 앱은 kind 만 보고 갈라 준다.
      final isCoach = data['kind']?.toString() == 'coach';

      if (isCoach) {
        final gym = data['active_gym'] as Map<String, dynamic>? ?? {};
        await bossAuth.save(
          loginId: data['login_id']?.toString() ?? loginId,
          name: data['name']?.toString() ?? '',
          role: data['role']?.toString() ?? 'coach',
          gymId: (gym['gym_id'] as num?)?.toInt() ?? 0,
          gymName: gym['gym_name']?.toString() ?? '',
          csrfToken: data['csrf_token']?.toString() ?? '',
          sessionCookie: result['session_cookie'] as String? ?? '',
        );
      } else {
        // 창구가 하나가 되면서 같은 폰에서 코치 → 회원 전환이 흔해졌다.
        // 코치 세션(secure storage)을 안 지우면 main.dart 의 staffPush 리스너가
        // 계속 살아 회원이 스태프 알림을 받는다 — 회원으로 들어올 땐 먼저 끊는다.
        if (bossAuth.isLoggedIn) await bossAuth.clear();

        final deviceId = data['device_id']?.toString() ?? '';
        if (deviceId.isEmpty) {
          throw AppException('로그인 응답이 올바르지 않습니다.', code: 'NO_DEVICE_ID');
        }
        // 이 기기의 신원을 로그인한 회원으로 교체.
        await DeviceIdService.adopt(deviceId);
        await auth.signIn(
          'member_id',
          displayName: data['name']?.toString() ?? loginId,
        );

        // 체육관 소속·프로필 미리 불러오기 (실패해도 진입은 막지 않는다).
        try {
          await gymState?.loadMine();
        } catch (_) {}
        try {
          await profile.load();
        } catch (_) {}
      }

      if (_remember) {
        await RememberedLogin.save(loginId);
      } else {
        await RememberedLogin.clear();
      }

      if (!mounted) return;
      Haptic.heavy();
      // 회원: 승인 대기든 활성이든 홈으로. 온보딩(성별·경력)은 가입 직후 한 번만
      // 묻는다 — 로그인한 사람을 다시 붙잡아 두지 않는다 (v2.3).
      navigator.pushNamedAndRemoveUntil(
        isCoach ? '/boss/dashboard' : '/shell',
        (_) => false,
      );
    } on AppException catch (e) {
      setState(() => _error = e.messageKo);
    } catch (_) {
      setState(() => _error = '연결 실패. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HyphenTokens.bg,
      // v3.33 (2026-08-27 사용자 지시 "네이버 로그인이나 다른 SaaS 처럼 통일된 화면"):
      // 이 화면은 **레이아웃 안정성(layout stability)** 을 지키는 고정 레이아웃이다.
      // 상태(안내·에러·검증 실패·로딩)가 어떻게 바뀌어도 아이디칸·비밀번호칸·
      // 로그인 버튼·회원 가입 신청·약관의 y 좌표가 움직이지 않는다.
      // 변하는 것은 전부 **미리 잡아 둔 자리**(공간 예약 / space reservation) 안에서만
      // 바뀐다 — 규격 정본 = docs/DESIGN-SSOT.md §레이아웃 안정성.
      // 회귀 게이트 = test/golden/layout_stability_test.dart (6 상태 y 동일성).
      //
      // Scaffold.appBar 를 쓰지 않는 이유: 상단바는 있고 없고가 곧 52px 밀림이다
      // (구 `appBar: Navigator.canPop(context) ? HkAppBar() : null`). 띠는 항상
      // 있고 화살표만 조건부인 HkBackBar 로 바꿨다.
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // SaaS 로그인처럼 좁은 폭 중앙 정렬 — 폰(360)에서는 무영향,
            // 태블릿·큰 화면에서만 입력칸이 늘어지는 것을 막는다.
            constraints: const BoxConstraints(maxWidth: HyphenTokens.formMaxW),
            child: Column(
              children: [
                const HkBackBar(),
                Expanded(child: _form(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 본문 — 작은 화면·키보드에서만 스크롤되고, 그 밖에는 위에서부터 고정이다.
  Widget _form(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: HyphenTokens.sp5,
        vertical: HyphenTokens.sp4,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: HyphenTokens.sp5),
            // v3.19 사용자 지시 — 이 화면에 브랜드 로고를 넣지 않는다.
            Text('로그인', style: HyphenTokens.h1),
            const SizedBox(height: HyphenTokens.sp1),
            // 역할을 고르게 하지 않는다. 어느 화면으로 갈지는 서버가 판정한다.
            Text('체육관에서 받은 아이디로 로그인합니다.', style: HyphenTokens.caption),
            const SizedBox(height: HyphenTokens.sp3),

            // 안내·에러 자리 — 세션 만료 안내(D59)와 로그인 실패가 같은 칸을 쓴다.
            // 비어 있어도 자리를 지킨다.
            HkNoticeSlot(_error),
            const SizedBox(height: HyphenTokens.sp3),

            HkSectionLabel('아이디'),
            const SizedBox(height: HyphenTokens.sp1),
            TextFormField(
              key: LoginScreen.kIdField,
              controller: _idCtrl,
              style: HyphenTokens.body.copyWith(color: HyphenTokens.fg),
              // helperText 공백 한 칸 = 에러 문구 줄을 **항상 예약**한다
              // (Flutter 표준 공간 예약). 검증 에러가 떠도 아래가 밀리지 않는다.
              // helper·error 의 글꼴 높이는 theme.dart 가 같게 맞춰 둔다.
              decoration: const InputDecoration(
                hintText: '아이디',
                helperText: ' ',
                errorMaxLines: 1,
              ),
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '아이디를 입력해 주세요.' : null,
            ),
            const SizedBox(height: HyphenTokens.sp2),

            HkSectionLabel('비밀번호'),
            const SizedBox(height: HyphenTokens.sp1),
            TextFormField(
              key: LoginScreen.kPwField,
              controller: _pwCtrl,
              style: HyphenTokens.body.copyWith(color: HyphenTokens.fg),
              decoration: InputDecoration(
                hintText: '비밀번호',
                helperText: ' ',
                errorMaxLines: 1,
                suffixIcon: IconButton(
                  icon: Icon(
                    _pwVisible ? Icons.visibility_off : Icons.visibility,
                    color: HyphenTokens.muted,
                    size: 20,
                  ),
                  tooltip: _pwVisible ? '비밀번호 숨기기' : '비밀번호 보기',
                  onPressed: () => setState(() => _pwVisible = !_pwVisible),
                ),
              ),
              obscureText: !_pwVisible,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              validator: (v) =>
                  (v == null || v.isEmpty) ? '비밀번호를 입력해 주세요.' : null,
            ),

            // 아이디 기억 (2026-08-25 사용자 요청) — 비밀번호는 저장 안 함.
            Align(
              alignment: Alignment.centerLeft,
              child: HkCheckRow(
                value: _remember,
                label: '아이디 기억하기 (${RememberedLogin.days}일)',
                onChanged: (v) => setState(() => _remember = v),
              ),
            ),

            const SizedBox(height: HyphenTokens.sp5),
            // 로딩은 버튼을 **치우지 않는다** — 같은 자리에서 스피너만 돈다.
            HkButton.primary(
              '로그인',
              key: LoginScreen.kSubmit,
              onPressed: _login,
              busy: _busy,
            ),

            // v3.31 (2026-08-27 사용자 지시): 갈림길 화면을 없애고 이 화면
            // 하나로 합쳤다. 아이디가 아직 없는 사람이 갈 길은 큰 버튼이
            // 아니라 아래 한 줄로 둔다 — 주 동선은 로그인이다.
            const SizedBox(height: HyphenTokens.sp2),
            Center(
              child: HkButton.tertiary(
                '회원 가입 신청',
                key: LoginScreen.kSignup,
                onPressed: _busy
                    ? null
                    : () {
                        Haptic.light();
                        Navigator.of(context).pushNamed('/signup/self');
                      },
              ),
            ),

            // 법적 고지 — 구 진입 화면에 있던 두 링크를 그대로 옮겨 왔다.
            const SizedBox(height: HyphenTokens.sp2),
            Row(
              key: LoginScreen.kLegal,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HkButton.tertiary(
                  '이용약관',
                  neutral: true,
                  small: true,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsScreen()),
                  ),
                ),
                const Text(
                  ' · ',
                  style: TextStyle(color: HyphenTokens.muted),
                ),
                HkButton.tertiary(
                  '개인정보처리방침',
                  neutral: true,
                  small: true,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
