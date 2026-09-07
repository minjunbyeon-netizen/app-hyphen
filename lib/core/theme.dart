import 'package:flutter/material.dart';

import 'appkit.gen.dart';

/// hyphen 디자인 토큰 (v2.1.0 — appkit 공통 조상 배선, 2026-07-03).
/// 공유 토큰(뉴트럴·상태색·타이포 스케일·간격·모서리·크기·모션)은 AppKit 재수출,
/// hyphen 고유(HWPO 임팩트·tier 색·quote)만 이 파일에 남는다.
/// 마스터: C:/dev/tools/appkit/master/appkit.json → python sync.py
///
/// (구 v2.0.0 — 라이트 톤 전면 개편, PC hyphen-admin 팔레트 통합.)
/// 컬러: 라이트 배경 + CrossFit red 액센트 (WCAG AA 보장).
/// 폰트: 이중 모드 — HWPO 임팩트(영혼 숫자 1~2회/화면) + Strava 본문(나머지 전체).
/// 규칙: ~/.claude/reference/{mobile,ux,design}.md + 프로젝트 CLAUDE.md.
///
/// v2.0.0 BREAKING — 라이트 톤 전환 (2026-05-24):
///   - bg #0A0A0A → #FAFAFA, surface 흑색 → 흰색
///   - fg #FFFFFF → #18181B (검정 텍스트)
///   - HWPO/NOBULL 강한 톤은 weight + uppercase + letterSpacing으로 유지
///   - 다크 대비 잃지 않도록 tierRx #EE2B2B → #CC1F1F (라이트 배경 4.5:1)
class HyphenTokens {
  HyphenTokens._();

  // ==== 컬러 팔레트 (v2.1.0 — appkit 공통 조상 재수출) ====
  /// 기본 배경 (라이트).
  static const Color bg = AppKit.bg;
  /// 카드·시트 배경 (순백).
  static const Color surface = AppKit.surface;
  /// 카드 보조 표면 (intro·hover 기반).
  static const Color surfaceAlt = AppKit.surfaceAlt;
  /// hover/pressed 상태 표면.
  static const Color surfaceHover = AppKit.surfaceHover;
  /// 호환 alias — surfaceAlt 사용 권장.
  static const Color surfaceHigh = surfaceAlt;
  static const Color surfaceMax = surfaceHover;
  /// @deprecated v2.1에서 제거 — surfaceAlt 사용.
  static const Color surfaceOverlay = surfaceAlt;

  /// 본문 텍스트 (zinc-900).
  static const Color fg = AppKit.text;
  /// 보조 텍스트 (zinc-600).
  static const Color fgSecondary = AppKit.textSub;
  /// 흐린 텍스트 (zinc-500).
  static const Color muted = AppKit.muted;
  /// 더 강한 muted (zinc-700) — hyphen 고유 (조상에 없음).
  static const Color mutedStrong = Color(0xFF3F3F46);
  /// 구분선 (zinc-200).
  static const Color border = AppKit.border;
  /// 강조 구분선 (zinc-300).
  static const Color borderStrong = AppKit.borderStrong;

  /// 입력 안내 문구(placeholder) — hyphen 고유.
  /// 조상 `AppKit.placeholder`(#A1A1AA)는 흰 배경 2.56:1 로 읽기 어려워 한 단 내렸다
  /// (3.71:1). 입력값이 아니라 안내라 본문 4.5 기준 대상은 아니지만, 노안·야외
  /// 가독성 확보용. v2.2 가시성 개편.
  static const Color placeholder = Color(0xFF84848D);

  /// v2.0: accent = primary CrossFit red 통합.
  /// @deprecated v2.1에서 제거 — primary 사용.
  static const Color accent = AppKit.accent;
  static const Color accentPressed = AppKit.accentPressed;
  /// 탠 어두운 배경 → 라이트에서 red-50 으로 대체.
  static const Color accentSoft = AppKit.accentSoft;

  // ==== 액센트 4색 ====
  /// CrossFit Red — 기본 CTA·강조 (appkit.config.json 브랜드 스킨).
  static const Color primary = AppKit.accent;
  static const Color primaryPressed = AppKit.accentPressed;
  /// v2.0 신규 — primary/danger 등 컬러 배경 위 텍스트 (항상 흰색).
  /// 라이트 톤 전환 시 fg(=검정) 사용하면 콘트라스트 미달 → 이 토큰 사용 강제.
  static const Color onColor = AppKit.onAccent;
  /// PR 달성·성공 (조상: 흰 배경 AA).
  static const Color success = AppKit.success;
  /// 만료 임박·주의 (조상: 흰 배경 AA).
  static const Color warning = AppKit.warning;
  /// 정보·툴팁·링크 (조상: 흰 배경 AA).
  static const Color info = AppKit.info;
  /// 해지·에러 (조상: 흰 배경 AA).
  static const Color danger = AppKit.danger;

  /// @deprecated v2.1에서 제거 — danger 사용.
  static const Color error = danger;
  /// @deprecated v2.1에서 제거 — warning 사용.
  static const Color overdue = warning;

  // ==== 외부 브랜드 색 (소셜 로그인 전용) ====
  static const Color naverGreen = Color(0xFF03C75A);
  static const Color kakaoYellow = Color(0xFFFEE500);
  /// Google 버튼 — 흰 배경 + 어두운 텍스트 (Google 브랜드 가이드). G 마크 파랑.
  static const Color googleSurface = Color(0xFFFFFFFF);
  static const Color googleBlue = Color(0xFF4285F4);

  // ==== Tier 색상 (라이트 배경에서 WCAG AA, PC hyphen-admin 동기화) ====
  /// Scaled — neutral zinc-600.
  static const Color tierScaled = Color(0xFF52525B);
  /// RX — CrossFit red 어둡게 (라이트 배경 4.5:1).
  static const Color tierRx = Color(0xFFCC1F1F);
  /// RX+ — orange-700.
  static const Color tierRxPlus = Color(0xFFC05000);
  /// Elite — amber-700 (gold tone darker).
  static const Color tierElite = Color(0xFF92700A);
  /// Games — neutral gray darker.
  static const Color tierGames = Color(0xFF606060);

  static const String fontFamily = 'Pretendard';
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  // =========================================================
  //   HWPO 임팩트 모드 — 페이지의 "영혼 숫자" 전용
  //   화면당 등장 ≤ 1~2회. 텍스트 X, 숫자/등급명 O.
  //   v2.0: 검정 텍스트 (fg=#18181B). weight·letterSpacing 으로 임팩트 유지.
  // =========================================================

  /// HWPO #1 — Engine Score, 총 시간 등 페이지 핵심 숫자.
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 72,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: -2.4,
    fontFeatures: tabular,
    color: fg,
  );

  /// HWPO #2 — Tier 배지 내 숫자, LEVEL 숫자 (= 조상 display 56).
  static const TextStyle displayCompact = TextStyle(
    fontFamily: fontFamily,
    fontSize: AppKit.displaySize,
    fontWeight: AppKit.displayWeight,
    height: AppKit.displayLh,
    letterSpacing: AppKit.displayLs,
    fontFeatures: tabular,
    color: fg,
  );

  /// HWPO #3 — Splash "HYPHEN" 브랜드 로고 전용.
  static const TextStyle brandLogo = TextStyle(
    fontFamily: fontFamily,
    fontSize: 80,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: -2.8,
    color: fg,
  );

  /// HWPO #4 — Tier 등급명 ALLCAPS.
  static const TextStyle tierLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: 1.6,
    color: fg,
  );

  /// HWPO #5 — PR 신기록 표시.
  static const TextStyle pr = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: -0.4,
    fontFeatures: tabular,
    color: fg,
  );

  // =========================================================
  //   Strava 차분 모드 — 본문 전체
  // =========================================================

  /// 화면 헤드라인 (조상 h1 28 — 자간 음수 §2-B).
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: AppKit.h1Size,
    fontWeight: AppKit.h1Weight,
    height: AppKit.h1Lh,
    letterSpacing: AppKit.h1Ls,
    color: fg,
  );

  /// 섹션 타이틀 (조상 h2 22).
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: AppKit.h2Size,
    fontWeight: AppKit.h2Weight,
    height: AppKit.h2Lh,
    letterSpacing: AppKit.h2Ls,
    color: fg,
  );

  /// 카드 타이틀, AppBar title (theme 기본) (조상 h3 17).
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: AppKit.h3Size,
    fontWeight: AppKit.h3Weight,
    height: AppKit.h3Lh,
    letterSpacing: AppKit.h3Ls,
    color: fg,
  );

  /// Intro body 등 큰 본문 (조상 lead 18).
  static const TextStyle lead = TextStyle(
    fontFamily: fontFamily,
    fontSize: AppKit.leadSize,
    fontWeight: AppKit.leadWeight,
    height: AppKit.leadLh,
    letterSpacing: AppKit.leadLs,
    color: fg,
  );

  /// 본문 (조상 body 15 — 자간 음수 §2-B, 구 +0.3 폐기).
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: AppKit.bodySize,
    fontWeight: AppKit.bodyWeight,
    height: AppKit.bodyLh,
    letterSpacing: AppKit.bodyLs,
    color: fg,
  );

  /// 부연 설명 (조상 caption 13).
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: AppKit.captionSize,
    fontWeight: AppKit.captionWeight,
    height: AppKit.captionLh,
    letterSpacing: AppKit.captionLs,
    color: muted,
  );

  /// 수치 보조 (조상 micro 13 — v1.19 P0-8 노안 가독성 유지).
  static const TextStyle micro = TextStyle(
    fontFamily: fontFamily,
    fontSize: AppKit.microSize,
    fontWeight: AppKit.microWeight,
    height: AppKit.microLh,
    letterSpacing: AppKit.microLs,
    color: muted,
  );

  /// 섹션 구분 라벨 ALLCAPS. 코드에서 toUpperCase 필수 (조상 label 12 — 대문자 영문이라 양수 자간 예외).
  /// 2026-09-07 가시성 점검 §3 — 색은 `muted`(#71717A) 였는데 흰 바탕 4.83 은 통과해도
  /// **회색 상자(#F5F5F5) 위에서 4.43** 으로 기준(4.5)에 못 미쳤다. 수업 탭 펼침 상자의
  /// 파트 라벨이 정확히 그 자리다. `fgSecondary`(= AppKit.textSub #52525B) 는 같은 자리에서 7.09 라 여유가 있다.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: AppKit.labelSize,
    fontWeight: AppKit.labelWeight,
    height: AppKit.labelLh,
    letterSpacing: AppKit.labelLs,
    color: fgSecondary,   // = AppKit.textSub #52525B
  );

  /// Offline 등 단어 라벨.
  static const TextStyle bannerLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: 1.0,
    color: fg,
  );

  /// 영어 명언용 italic.
  static const TextStyle quote = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
    height: 1.50,
    letterSpacing: 0.1,
    color: muted,
  );

  /// micro 강조 변형.
  static const TextStyle microLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.40,
    letterSpacing: 1.2,
    color: muted,
  );

  /// 수식·코드 블록 (§2-B-모노: 모노스페이스 전면 금지 — Pretendard + tabular-nums 로 정렬).
  static const TextStyle codeBlock = TextStyle(
    fontFamily: fontFamily,
    fontSize: AppKit.captionSize,
    fontWeight: FontWeight.w400,
    height: 1.45,
    fontFeatures: tabular,
    color: muted,
  );

  // ==== 스페이싱 (조상) ====
  static const double sp1 = AppKit.sp1;
  static const double sp2 = AppKit.sp2;
  static const double sp3 = AppKit.sp3;
  static const double sp4 = AppKit.sp4;
  static const double sp5 = AppKit.sp5;
  static const double sp6 = AppKit.sp6;
  static const double sp7 = AppKit.sp7;
  static const double sp8 = AppKit.sp8;

  // ==== 모서리 (조상) ====
  static const double r1 = AppKit.r1;
  static const double r2 = AppKit.r2;
  static const double r3 = AppKit.r3;
  static const double r4 = AppKit.r4;
  static const double r5 = AppKit.r5;

  static const double touchMin = AppKit.touchMin;
  static const double buttonH = AppKit.buttonH;

  /// v2.5 (2026-08-12 사용자 지시): 앱 전체 버튼 높이 — appkit 상속값 52 는
  /// 폰 화면에서 한 줄이 너무 두꺼워 카드 하나가 화면 절반을 먹었다.
  /// "모든 버튼을 컴팩트하게 통일" 지시로 hyphen 앱만 36 으로 내린다.
  /// (appkit 마스터 값은 건드리지 않는다 — 다른 앱까지 따라 내려가면 안 된다.)
  static const double buttonHCompact = 36;
  static const double appBarH = AppKit.appBarH;

  /// 폼 화면 콘텐츠 최대 폭 (v3.33 · 2026-08-27 사용자 지시 "SaaS 처럼 통일된 화면").
  /// 폰 기준 폭 360 + 여유 60. 태블릿·큰 화면에서 입력칸이 화면 폭만큼
  /// 늘어지지 않도록 이 폭에서 멈추고 가운데 정렬한다 (폰에서는 무영향).
  static const double formMaxW = 420;

  /// 안내·에러 한 줄이 들어올 **예약된 자리**의 높이 (공간 예약 / space reservation).
  /// caption 2줄(13×1.45×2 = 37.7) + 상하 sp2(8+8) + 1px 보더 둘 = 55.7 → 56.
  /// DESIGN-SSOT §레이아웃 안정성 — 값을 바꾸면 HkInlineError 규격도 같이 본다.
  static const double noticeSlotH = 56;

  /// 로딩·빈·에러가 **같은 자리**를 쓰게 하는 최소 높이 (D115 · 2026-09-04).
  ///
  /// 셋을 같은 자리에서 갈아 끼우는데 실측 높이가 22 / 70·97 / 131 로 달라
  /// **최대 109px** 밀렸다. 지금까지는 호출부가 `HkSectionSlot(minHeight:)` 로
  /// 감싸 준 곳만 안전했고 그 값도 호출부마다 각자 정했다 — 규격이 부품에 없었다.
  /// 값 = 가장 큰 `HkErrorState`(패딩 24×2 + 본문 22.5 + sp3 12 + 버튼 48 = 130.5)를
  /// 담는 높이. 셋 다 이 바닥을 갖고, 내용이 더 크면 그 위로 자란다.
  /// DESIGN-SSOT §레이아웃 안정성 · 게이트 `test/state_slot_test.dart`.
  static const double stateSlotH = 132;
}

class HyphenTheme {
  HyphenTheme._();

  /// v2.0: dark 는 light alias (라이트 톤 전면 전환).
  static ThemeData get dark => light;

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: HyphenTokens.bg,
    colorScheme: const ColorScheme.light(
      surface: HyphenTokens.surface,
      onSurface: HyphenTokens.fg,
      surfaceContainer: HyphenTokens.surface,
      surfaceContainerHigh: HyphenTokens.surfaceAlt,
      surfaceContainerHighest: HyphenTokens.surfaceHover,
      primary: HyphenTokens.primary,
      onPrimary: Color(0xFFFFFFFF),
      secondary: HyphenTokens.primary,
      onSecondary: Color(0xFFFFFFFF),
      tertiary: HyphenTokens.info,
      onTertiary: Color(0xFFFFFFFF),
      outline: HyphenTokens.border,
      outlineVariant: HyphenTokens.borderStrong,
      onSurfaceVariant: HyphenTokens.muted,
      error: HyphenTokens.danger,
      onError: Color(0xFFFFFFFF),
    ),
    fontFamily: HyphenTokens.fontFamily,
    textTheme: const TextTheme(
      displayLarge: HyphenTokens.display,
      headlineLarge: HyphenTokens.h1,
      headlineMedium: HyphenTokens.h2,
      headlineSmall: HyphenTokens.h3,
      titleLarge: HyphenTokens.lead,
      bodyMedium: HyphenTokens.body,
      labelMedium: HyphenTokens.caption,
      labelSmall: HyphenTokens.micro,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: HyphenTokens.bg,
      foregroundColor: HyphenTokens.fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: HyphenTokens.appBarH,
      titleTextStyle: HyphenTokens.h3,
      shape: Border(
        bottom: BorderSide(color: HyphenTokens.border, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(
          const Size(double.infinity, HyphenTokens.buttonHCompact),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return HyphenTokens.surfaceHover;
          if (states.contains(WidgetState.pressed)) return HyphenTokens.primaryPressed;
          return HyphenTokens.primary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return HyphenTokens.muted;
          return const Color(0xFFFFFFFF);
        }),
        textStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: HyphenTokens.fontFamily,
            fontSize: AppKit.bodySize,
            fontWeight: FontWeight.w600,
            letterSpacing: AppKit.bodyLs,
            height: AppKit.bodyLh,
            color: AppKit.onAccent,
          ),
        ),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        // 높이가 36 으로 내려온 뒤 r4(16) 은 사실상 완전 원형 pill 이 된다
        // (글로벌 design-block 차단 대상). r3 으로 낮춰 모서리만 둥근 사각 유지.
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HyphenTokens.r3),
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: HyphenTokens.sp4,
            vertical: HyphenTokens.sp1,
          ),
        ),
        elevation: WidgetStateProperty.all(0),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(
          const Size(double.infinity, HyphenTokens.buttonHCompact),
        ),
        foregroundColor: WidgetStateProperty.all(HyphenTokens.fg),
        side: WidgetStateProperty.all(
          const BorderSide(color: HyphenTokens.borderStrong, width: 1),
        ),
        textStyle: WidgetStateProperty.all(
          HyphenTokens.body.copyWith(fontWeight: FontWeight.w600),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: HyphenTokens.sp4,
            vertical: HyphenTokens.sp1,
          ),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HyphenTokens.r3),
          ),
        ),
      ),
    ),
    // v2.2 가시성 개편 — 텍스트 버튼도 손가락이 닿는 크기로.
    // 기존엔 화면마다 minimumSize 를 제각각(36·0) 주어 "눌리는 것"이 글자 높이만
    // 했다. 여기서 한 번 잡으면 앱 전체 TextButton 이 같이 올라간다.
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(
          const Size(0, HyphenTokens.buttonHCompact),
        ),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return HyphenTokens.muted;
          return HyphenTokens.primary;
        }),
        textStyle: WidgetStateProperty.all(
          HyphenTokens.body.copyWith(fontWeight: FontWeight.w600),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: HyphenTokens.sp3),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HyphenTokens.r2),
          ),
        ),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
    ),
    // 아이콘 버튼 터치 48 보장 (앱바 종·새로고침, 행 끝 아이콘 등).
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(
          const Size(HyphenTokens.touchMin, HyphenTokens.touchMin),
        ),
        foregroundColor: WidgetStateProperty.all(HyphenTokens.fg),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
    ),
    // 입력칸 — 안내 문구 대비 상향 + 포커스 테두리를 브랜드색으로 명확히.
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: HyphenTokens.body.copyWith(color: HyphenTokens.placeholder),
      labelStyle: HyphenTokens.caption,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: HyphenTokens.sp4,
        vertical: HyphenTokens.sp3,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HyphenTokens.r3),
        borderSide: const BorderSide(color: HyphenTokens.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HyphenTokens.r3),
        borderSide: const BorderSide(color: HyphenTokens.primary, width: 2),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HyphenTokens.r3),
        borderSide: const BorderSide(color: HyphenTokens.borderStrong),
      ),
      // v3.24 (2026-08-25 SSOT 통일): 에러 상태도 테마가 갖는다 — 로그인·가입
      // 화면이 각자 _inputDeco 를 들고 있던 이유가 이 셋의 부재였다.
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HyphenTokens.r3),
        borderSide: const BorderSide(color: HyphenTokens.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HyphenTokens.r3),
        borderSide: const BorderSide(color: HyphenTokens.danger, width: 2),
      ),
      errorStyle: HyphenTokens.micro.copyWith(color: HyphenTokens.danger),
      // v3.33 (2026-08-27): helper 줄과 error 줄의 **글자 크기·행간을 같게** 둔다.
      // 화면이 `helperText: ' '` 로 에러 줄 자리를 미리 잡아 두는데(공간 예약),
      // 두 style 의 높이가 다르면 에러가 뜨는 순간 그 차이만큼 아래가 밀린다.
      helperStyle: HyphenTokens.micro.copyWith(color: HyphenTokens.muted),
    ),
    // v3.24: 다이얼로그·바텀시트 모양은 여기 한 곳 — 화면마다 backgroundColor·
    // shape 를 인라인으로 적던 것(11+13곳) 을 전부 걷어냈다. 호출은 HkDialog·HkSheet.
    dialogTheme: DialogThemeData(
      backgroundColor: HyphenTokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HyphenTokens.r4),
      ),
      titleTextStyle: HyphenTokens.h3.copyWith(color: HyphenTokens.fg),
      contentTextStyle: HyphenTokens.caption,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: HyphenTokens.surface,
      surfaceTintColor: Colors.transparent,
      // DESIGN-SSOT §모서리: r5(28) 시트.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HyphenTokens.r5)),
      ),
      showDragHandle: false,
    ),
    cardTheme: CardThemeData(
      color: HyphenTokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      // 라이트 단일 box-shadow (design-block.md 다중 금지).
      shadowColor: const Color(0x14000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HyphenTokens.r3),
        side: const BorderSide(color: HyphenTokens.border, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: HyphenTokens.border,
      thickness: 1,
      space: 0,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
