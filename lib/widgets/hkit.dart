/// HKit — hyphen UI 컴포넌트 SSOT (2026-07-28 사용자 지시).
///
/// 새 화면·기능에서 카드·배지·섹션 라벨·통계 타일·빈/에러/로딩 상태를
/// 그때그때 새로 만들지 않는다 — 여기 있는 것만 쓰고, 없으면 여기에 추가한다
/// (글로벌 §3 코드·클래스 SSOT 의 프로젝트 배선). 참조 관례: workcheck gs_* ·
/// writeplz wp_* — 공통 조상 토큰은 appkit.gen.dart / HyphenTokens.
///
/// 고정 규격 (전 화면 동일 — 전체 양식 = docs/DESIGN-SSOT.md):
/// - 버튼: HkButton 3단(primary 채움 52 / secondary 외곽선 52 / tertiary 글자 48).
///   화면당 primary 는 1개. 새 버튼 모양 신설 금지
/// - 카드: surface 면 + 1px border + r3, 내부 패딩 sp4
/// - 배지: 1px 컬러 보더 + 대문자 + r1 사각 — 완전 원형 pill 금지 (글로벌 design-block)
/// - 섹션 라벨: sectionLabel 토큰 + 대문자 강제 (코드에서 toUpperCase)
/// - 로딩 스피너: 22×22 stroke 2 muted 단일 규격 / 전면 로딩 = HkLoadingScreen
/// - 에러: 본문 메시지 + OutlinedButton "다시 시도" (문구 고정)
/// - 소셜 로그인 버튼: HkSocialButton (높이 52 · r3 · 마크+라벨 중앙)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/exception.dart';
import '../core/theme.dart';
import 'brand_logo.dart';
import 'mascot.dart';
import '../core/appkit.gen.dart';

/// 버튼 위계 3단 — **누르는 것의 유일 규격** (v2.2 · 2026-08-12 가시성 개편 지시).
///
/// 그전까지 화면마다 `ElevatedButton`·`OutlinedButton`·`TextButton`·`InkWell` 을
/// 골라 쓰고 `minimumSize` 도 제각각(36·40·52)이라, 같은 무게의 동작이 화면마다
/// 다르게 보였다. 이제 셋 중 하나를 고르는 것으로 끝낸다.
///
/// - [HkButtonKind.primary] — 이 화면에서 지금 해야 할 **단 하나**. 채움 + 흰 글씨.
///   화면당 1개 원칙 (링코 F1 의 교훈 — 강조가 여섯 번이면 강조가 아니다).
/// - [HkButtonKind.secondary] — 같이 놓이는 대등한 선택지. 외곽선.
/// - [HkButtonKind.tertiary] — 부수 동작·이동. 글자만, 그래도 터치는 48 보장.
enum HkButtonKind { primary, secondary, tertiary }

class HkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final HkButtonKind kind;

  /// 가로를 꽉 채울지. false 면 글자 폭 + 패딩만 차지한다 (행 안에 나란히 둘 때).
  final bool expand;

  /// 되돌릴 수 없는 동작(초기화·삭제·해지)임을 색으로 알린다.
  /// primary 면 danger 채움, secondary 면 danger 테두리+글자.
  /// 파괴적 동작을 그냥 글자 링크로 두면 일반 메뉴와 구분되지 않는다
  /// (링코 S17 — '서비스 탈퇴'가 일반 항목과 같은 비중이던 문제).
  final bool danger;

  /// 잔글씨 — 법적 고지처럼 **읽히되 앞서면 안 되는** 링크. tertiary 에서만 의미가 있다.
  /// 2026-09-07 가시성 점검 §4: 로그인 화면의 '이용약관 · 개인정보처리방침' 이 본문 굵기라
  /// 정작 눌러야 할 '회원 가입 신청'(빨강)보다 무겁게 보였다. 글자만 caption 으로 내리고
  /// 터치 48 은 그대로 둔다 (작아 보여도 누르는 자리는 안 줄인다).
  final bool small;

  /// 글자색을 브랜드색 대신 중립(fgSecondary)으로. tertiary 에서만 의미가 있다.
  /// 한 화면에 브랜드색이 셋을 넘으면 강조가 죽으므로(링코 F1), primary 버튼과
  /// 같이 놓이는 부수 링크는 이쪽. 회색 muted 로 내리면 비활성처럼 보이므로
  /// fgSecondary(7.7:1) + w600 으로 "읽히되 앞서지 않게" 둔다.
  final bool neutral;

  /// 처리 중 — **버튼을 스피너로 갈아 끼우지 않는다**. 자리(높이·폭)를 그대로 둔
  /// 채 글자만 스피너로 바꾸고 눌리지 않게 한다 (v3.33 · 2026-08-27 사용자 지시
  /// "변수가 생길 부분은 변수 자리를 미리 만들고"). 전엔 화면마다
  /// `_busy ? HkLoading() : HkButton(...)` 로 갈아 끼워, 로딩이 시작되는 순간
  /// 버튼 높이(36)와 스피너 높이(22)의 차이만큼 아래 요소가 통째로 밀렸다.
  /// 규격 = DESIGN-SSOT §레이아웃 안정성.
  final bool busy;

  const HkButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = HkButtonKind.primary,
    this.icon,
    this.expand = true,
    this.neutral = false,
    this.small = false,
    this.danger = false,
    this.busy = false,
  });

  const HkButton.primary(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.danger = false,
    this.busy = false,
      this.small = false,
}) : kind = HkButtonKind.primary,
       neutral = false;

  const HkButton.secondary(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.danger = false,
    this.busy = false,
      this.small = false,
}) : kind = HkButtonKind.secondary,
       neutral = false;

  const HkButton.tertiary(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.neutral = false,
    this.busy = false,
      this.small = false,
}) : kind = HkButtonKind.tertiary,
       danger = false;

  @override
  Widget build(BuildContext context) {
    // 전체폭이 아니면 테마의 minimumSize(무한대)를 눌러 글자 폭에 맞춘다.
    final size = WidgetStatePropertyAll<Size>(
      Size(expand ? double.infinity : 0, _height),
    );
    final shrink = expand ? null : MaterialTapTargetSize.shrinkWrap;
    final action = busy ? null : onPressed;

    final Widget face = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: HyphenTokens.sp2),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    // D118 — 전체폭이 아닌 버튼은 **글자가 폭을 정한다**. 스피너로 통째
    // 갈아 끼우면 그 폭이 사라져 버튼이 홀쭉해지거나(폭 0 최소치) 반대로
    // 남는 자리를 다 먹는다 — 실측 49.6 → 360. 그래서 글자를 투명하게
    // 남겨 폭을 붙들고 그 위에 스피너만 얹는다. 높이는 _height 로 이미 고정.
    final Widget child = busy
        ? Stack(
            alignment: Alignment.center,
            children: [
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: face,
              ),
              HkLoading.icon(
                color: kind == HkButtonKind.primary
                    ? HyphenTokens.onColor
                    : HyphenTokens.primary,
              ),
            ],
          )
        : face;

    switch (kind) {
      case HkButtonKind.primary:
        // busy 는 눌리지 않지만 **비활성 회색으로 내리지 않는다** — 색까지 바뀌면
        // 같은 자리에 있어도 "사라진 것"처럼 읽힌다. 면은 그대로, 글자만 스피너.
        final WidgetStatePropertyAll<Color>? bg = danger
            ? const WidgetStatePropertyAll<Color>(HyphenTokens.danger)
            : busy
            ? const WidgetStatePropertyAll<Color>(HyphenTokens.primary)
            : null;
        return ElevatedButton(
          onPressed: action,
          style: ButtonStyle(
            minimumSize: size,
            tapTargetSize: shrink,
            backgroundColor: bg,
          ),
          child: child,
        );
      case HkButtonKind.secondary:
        return OutlinedButton(
          onPressed: action,
          style: ButtonStyle(
            minimumSize: size,
            tapTargetSize: shrink,
            foregroundColor: danger
                ? const WidgetStatePropertyAll<Color>(HyphenTokens.danger)
                : null,
            side: danger
                ? const WidgetStatePropertyAll<BorderSide>(
                    BorderSide(color: HyphenTokens.danger),
                  )
                : busy
                ? const WidgetStatePropertyAll<BorderSide>(
                    BorderSide(color: HyphenTokens.borderStrong),
                  )
                : null,
          ),
          child: child,
        );
      case HkButtonKind.tertiary:
        return TextButton(
          onPressed: action,
          style: ButtonStyle(
            minimumSize: size,
            tapTargetSize: shrink,
            foregroundColor: neutral
                ? const WidgetStatePropertyAll<Color>(HyphenTokens.fgSecondary)
                : null,
            textStyle: small
                ? const WidgetStatePropertyAll<TextStyle>(HyphenTokens.caption)
                : null,
          ),
          child: child,
        );
    }
  }

  /// v2.5 (2026-08-12 사용자 지시): 3종 모두 같은 컴팩트 높이.
  /// 전엔 채움 52 · 글자 48 로 미묘하게 달라 한 줄에 나란히 두면 층이 졌다.
  double get _height => HyphenTokens.buttonHCompact;
}

/// 섹션 구분 라벨 — 대문자 강제.
///
/// [strong] (D125 · 2026-09-06 가시성 점검) — **폼 안 묶음 제목**용 한 단어 상태.
/// 완료 시트의 파트 머리('A 파트 · 15분 · STRENGTH')가 12sp 회색 대문자라 그 안의
/// 항목('Back Squat · 1세트' 17sp 검정)보다 작고 연해 위계가 뒤집혀 있었다. `strong`
/// 은 body 세미볼드 검정, 대문자 강제 없음. 화면 섹션 헤더 규칙(R3)은 그대로 —
/// 화면 섹션 헤더는 기본형을 쓴다. 새 라벨 variant 신설 금지, 이 두 상태뿐이다.
class HkSectionLabel extends StatelessWidget {
  final String text;
  final bool strong;
  const HkSectionLabel(this.text, {super.key, this.strong = false});

  @override
  Widget build(BuildContext context) => strong
      ? Text(
          text,
          style: HyphenTokens.body.copyWith(fontWeight: FontWeight.w600),
        )
      : Text(text.toUpperCase(), style: HyphenTokens.sectionLabel);
}

/// 체크 줄 — 체크박스 + 라벨 한 줄 (v3.18 · 2026-08-25 로그인 '아이디 기억하기').
///
/// Material [Checkbox] 는 원형 리플·둥근 모서리라 이 앱의 사각 규격과 어긋난다.
/// 그래서 배지(HkBadge)와 같은 r1 사각 + 1px 보더로 직접 그린다. 터치 영역은
/// 라벨까지 포함해 48 이상 (글로벌 모바일 룰). 새 체크 variant 신설 금지 —
/// 다른 화면에 체크가 필요하면 이걸 쓴다 (§3 코드·클래스 SSOT).
class HkCheckRow extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  const HkCheckRow({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        constraints: const BoxConstraints(minHeight: HyphenTokens.touchMin),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? HyphenTokens.primary : HyphenTokens.surface,
                border: Border.all(
                  color: value ? HyphenTokens.primary : HyphenTokens.border,
                ),
                borderRadius: BorderRadius.circular(HyphenTokens.r1),
              ),
              child: value
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: HyphenTokens.onColor,
                    )
                  : null,
            ),
            const SizedBox(width: HyphenTokens.sp2),
            Text(
              label,
              style: HyphenTokens.caption.copyWith(color: HyphenTokens.fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// 숫자 전용 칸 — 1~3자리 값을 적는 칸의 유일 규격 (D125 · 2026-09-06 가시성 점검,
/// `docs/audit-visibility-2026-09-06.html`).
///
/// 완료 시트의 점수·세트 칸이 전부 전폭(Expanded) TextField 라 '5' 한 글자가 156~328dp
/// 상자 왼쪽 구석에 묻혔고, 칸 이름은 placeholder 색(#A1A1AA · 2.56:1)으로만 보였다.
/// 그래서 **폭 고정 · 오른쪽 정렬 · 단위는 칸 밖 · 라벨은 항상 보이게** 로 규격을
/// 한 곳에 못 박는다.
///
/// - [fieldKey] 는 안쪽 TextField 에 그대로 단다 — 검사가 `find.byKey` 로 TextField 를 집는다.
/// - [label]: null = 라벨 줄 없음 · '' = 빈 라벨 줄(높이만 예약 — 옆 칸과 상자 y 를 맞춘다)
///   · 글자 = 칸 위에 textSub 세미볼드로. placeholder 가 라벨 노릇을 하지 않는다.
/// - [hint] 는 TextField hintText 그대로 (예시 숫자 '0' 같은 것만).
/// - [unit] 은 칸 오른쪽 바깥 글자('kg' · '회' · '분' · '초') — 칸 안에 넣으면 숫자 폭을 먹는다.
/// - 상자 = [width] × [HyphenTokens.touchMin]. 테두리·힌트 색은 테마 inputDecorationTheme
///   한 벌 (여기서 OutlineInputBorder 를 다시 그리지 않는다 — ssot_lint_test).
/// - 새 숫자 칸 variant 신설 금지 — 필요하면 [width] 만 바꿔 쓴다.
class HkNumberField extends StatelessWidget {
  final Key fieldKey;
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? unit;
  final double width;
  final bool enabled;
  final bool numeric;
  const HkNumberField({
    super.key,
    required this.fieldKey,
    required this.controller,
    this.label,
    this.hint,
    this.unit,
    this.width = 96,
    this.enabled = true,
    this.numeric = true,
  });

  /// 라벨 줄 높이 — 라벨이 있든 비었든 같은 값이라 옆 칸과 상자 y 가 맞는다.
  static const double labelHeight = 18;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          SizedBox(
            height: labelHeight,
            child: Text(
              label!,
              style: HyphenTokens.caption.copyWith(
                color: HyphenTokens.fgSecondary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: HyphenTokens.sp1),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: width,
              height: HyphenTokens.touchMin,
              child: TextField(
                key: fieldKey,
                controller: controller,
                enabled: enabled,
                keyboardType: numeric
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                textAlign: TextAlign.right,
                style: HyphenTokens.h3.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: HyphenTokens.tabular,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: HyphenTokens.sp3,
                    vertical: HyphenTokens.sp2,
                  ),
                ),
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: HyphenTokens.sp1),
              Text(
                unit!,
                style: HyphenTokens.body.copyWith(
                  color: HyphenTokens.fgSecondary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// 켬/끔 토글 — 스위치의 유일 규격 (v3.36 · 2026-08-28 '알림 받기').
///
/// Material [Switch] 는 완전 원형 트랙·원형 썸이라 이 앱의 사각 규격
/// (HkBadge r1 · HkCheckRow r1)과 어긋난다. 그래서 r1 사각 트랙 + 사각 썸으로
/// 직접 그린다. **모양은 상태와 무관하게 같은 크기**다 (켜짐·꺼짐이 같은
/// 44×26) — 표 행 안에 들어가도 행 높이가 상태에 따라 변하지 않는다
/// (DESIGN-SSOT §레이아웃 안정성).
///
/// [activeColor] 는 켜졌을 때 트랙 색이다. 기본은 [HyphenTokens.primary] 지만,
/// **켜 두었어도 실제로는 작동하지 않는 상태**(예: 폰 설정에서 알림 차단)에는
/// 중립색을 넘겨 "켜짐처럼 살아 있다" 고 읽히지 않게 한다.
class HkSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  /// 켜짐 트랙 색. null 이면 [HyphenTokens.primary].
  final Color? activeColor;

  const HkSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  static const double _w = 44;
  static const double _h = 26;
  static const double _pad = 3;

  @override
  Widget build(BuildContext context) {
    final on = activeColor ?? HyphenTokens.primary;
    return Semantics(
      toggled: value,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(HyphenTokens.r1),
        child: SizedBox(
          // 손가락이 닿을 48 은 세로로 확보하되, 눈에 보이는 크기는 그대로.
          height: HyphenTokens.touchMin,
          width: _w,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: _w,
              height: _h,
              padding: const EdgeInsets.all(_pad),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? on : HyphenTokens.surfaceAlt,
                border: Border.all(color: value ? on : HyphenTokens.border),
                borderRadius: BorderRadius.circular(HyphenTokens.r1),
              ),
              child: Container(
                width: _h - _pad * 2 - 2,
                height: _h - _pad * 2 - 2,
                decoration: BoxDecoration(
                  color: value ? HyphenTokens.onColor : HyphenTokens.muted,
                  borderRadius: BorderRadius.circular(HyphenTokens.r1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 표준 카드 — surface + 1px border + 모서리(r3 기본).
///
/// v3.27 (2026-08-25 사용자 지시 "카드 36곳 마저"): 화면마다 Container 로
/// 같은 크롬을 다시 그리던 것을 흡수하려고 네 칸을 열었다 —
/// [radius](r2 카드도 있다) · [borderColor](예약됨=초록 같은 상태 테두리) ·
/// [clipBehavior](안쪽 ExpansionTile 이 모서리를 넘지 않게) · [width].
/// 그 밖의 모양(왼쪽 색띠·말풍선·원형)은 카드가 아니다 — 여기 넣지 않는다.
class HkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double radius;
  final Color borderColor;
  final double borderWidth;
  final Clip clipBehavior;
  final double? width;
  const HkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HyphenTokens.sp4),
    this.margin,
    this.onTap,
    this.radius = HyphenTokens.r3,
    this.borderColor = HyphenTokens.border,
    this.borderWidth = 1,
    this.clipBehavior = Clip.none,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      margin: margin,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: HyphenTokens.surface,
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: card,
    );
  }
}

/// 배지의 무게 3단 (2026-09-07 · 가시성 점검 §2 → 목업 승인).
///
/// 종전에는 채움/외곽선 2단뿐이라 **못 누르는 것이 버튼처럼 보였다** —
/// '수업 시작 전' · '예약 필요' 가 '메시지' · '자세히' 와 같은 외곽선이었다.
enum HkBadgeTier {
  /// 주 행동 — 면 채움. **그 줄에서 제일 하고 싶은 일 하나**에만 쓴다.
  action,

  /// 보조 행동·상태 — 외곽선 (기본값).
  secondary,

  /// 이유 — 테두리 없는 글자. 못 누르는 까닭을 적는 자리라 버튼처럼 보이면 안 된다.
  /// 탭은 그대로 살아 있다 (서버 문구를 스낵바로 알린다).
  reason,
}

/// 배지 — **표시·선택 통합 유일 규격** (v1.32 · 2026-08-07 "1종으로 통합" 지시).
/// r1(4) 사각 + body 15 w600. 원형 pill 금지.
///
/// [onTap] 을 주면 선택 컨트롤로 동작한다 — 터치 최소 48 보장, [selected] 면 면 채움 반전.
/// [tier] 는 무게다 — 채움(action) · 외곽선(secondary, 기본) · 민글자(reason).
/// 화면마다 따로 만들던 `_Pill`·`_MiniPill`·`_StatusChip`·`_CategoryChip`·`_PainChip`·
/// `_chip` 등 11종은 v1.32 에서 전부 이 하나로 흡수했다. 새 variant 신설 금지 —
/// 모양이 다른 배지가 필요하면 여기부터 고친다.
///
/// 글자는 2026-09-07 에 micro 13 w700 자간 +0.8 → **body 15 w600 자간 음수**로 올렸다.
/// 누르는 글자가 같은 줄 제목(17)·캡션(13)보다 작았고, 한글에 양수 트래킹이라
/// 글로벌 §2-B-자간(한글 자간은 항상 음수)에도 어긋났다.
class HkBadge extends StatelessWidget {
  final String text;
  final Color color;

  /// 면 채움(반전) 여부. 선택 컨트롤에서만 의미가 있다
  /// (켜짐/꺼짐이 있는 토글 — 출석·노쇼처럼). 주 행동은 [tier] 로 말한다.
  final bool selected;

  /// 무게. 기본은 외곽선.
  final HkBadgeTier tier;

  /// null 이면 표시 전용 배지, 주면 탭 가능한 선택 컨트롤.
  final VoidCallback? onTap;

  const HkBadge(
    this.text, {
    super.key,
    this.color = HyphenTokens.muted,
    this.selected = false,
    this.tier = HkBadgeTier.secondary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null;
    // 채움 = 선택된 토글이거나 주 행동. 둘은 뜻이 다르지만 그림은 같다.
    final filled = selected || tier == HkBadgeTier.action;
    final bare = tier == HkBadgeTier.reason;
    // 시각 크기는 표시·선택이 완전히 같다 (1종 강제). 다른 건 터치 영역뿐.
    final box = Container(
      padding: EdgeInsets.symmetric(
        // 민글자는 테두리가 없으므로 옆 여백도 줄인다 (글자만 남는다).
        horizontal: bare ? HyphenTokens.sp1 : HyphenTokens.sp3,
        vertical: HyphenTokens.sp1,
      ),
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        border: bare ? null : Border.all(color: color),
        borderRadius: BorderRadius.circular(HyphenTokens.r1),
      ),
      child: Text(
        text.toUpperCase(),
        style: HyphenTokens.body.copyWith(
          color: filled ? HyphenTokens.bg : color,
          fontWeight: bare ? FontWeight.w500 : FontWeight.w600,
        ),
      ),
    );
    if (!tappable) return box;
    return Semantics(
      button: true,
      selected: selected,
      label: text,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HyphenTokens.r1),
        // 배지 자체는 작게 두고 손가락이 닿을 48 을 **가로·세로 둘 다** 확보한다.
        // D113 (2026-09-04 사용자 "폭 48 적용"): 종전엔 세로만 48 이고 가로는 글자 폭을
        // 따라가 '예약' 두 글자가 42 였다 — 기준(DESIGN-SSOT §3 터치 48) 미달.
        // widthFactor: 1 — Row 안에서 남는 폭을 먹지 않게 (그림은 종전 그대로).
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: HyphenTokens.touchMin,
            minHeight: HyphenTokens.touchMin,
          ),
          child: Center(widthFactor: 1, child: box),
        ),
      ),
    );
  }
}

/// 통계 타일 — 라벨(위) + 값(아래). 홈 Milestones · 보스 대시보드 공용 형태.
class HkStatTile extends StatelessWidget {
  final String label;
  final String value;
  const HkStatTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return HkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HkSectionLabel(label),
          const SizedBox(height: HyphenTokens.sp1),
          Text(value, style: HyphenTokens.h3.copyWith(color: HyphenTokens.fg)),
        ],
      ),
    );
  }
}

/// 표 행 — 좌 아이콘(선택) · 제목/부제 · 우 값. "한 줄에 한 항목" 표기의 유일 규격.
/// 홈 업적·마일스톤처럼 나열형 데이터는 그리드 타일 대신 이 행으로 쌓는다
/// (v1.30 — 색 타일 그리드가 산만하다는 사용자 지시로 표 형태 전환).
class HkListRow extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;

  /// 부제 글자색. 기본은 caption(흐림). 상태가 나빠 **읽어야 하는 부제**
  /// (예: '폰 설정에서 알림 차단됨')일 때만 `danger` 등으로 올린다 —
  /// 읽어야 하는 값에 muted 금지 (DESIGN-SSOT §7-D 4).
  final Color? subtitleColor;
  final String? trailing;
  final Color? trailingColor;

  /// 우측 슬롯을 위젯으로 — 출석 체크 배지처럼 값이 아니라 조작이 붙을 때.
  /// [trailing] 과 동시 사용 금지 (둘 다 오른쪽 자리를 쓴다).
  final Widget? trailingWidget;

  /// 행 하단 슬롯 — 진행바 등. 없으면 생략.
  final Widget? below;

  /// 제목 **옆** 작은 배지 — 업적 행의 확인 방식 태그처럼 제목과 한 줄에 붙는
  /// 보조 표시 (v3.35 · 2026-08-28 업적 E 안). 줄을 하나 더 쓰지 않으므로 행 높이가
  /// 그대로다. 제목이 길면 제목이 먼저 줄고(말줄임) 배지는 남는다.
  final Widget? titleBadge;

  /// 좌측 슬롯을 위젯으로 — 업적 배지처럼 아이콘 하나로 안 끝날 때
  /// (2026-08-21 픽토그램 팩). [icon] 과 동시 사용 금지.
  final Widget? leadingWidget;
  final VoidCallback? onTap;

  const HkListRow({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.leadingWidget,
    this.subtitle,
    this.subtitleColor,
    this.titleBadge,
    this.trailing,
    this.trailingColor,
    this.trailingWidget,
    this.below,
    this.onTap,
  }) : assert(
         trailing == null || trailingWidget == null,
         'trailing 과 trailingWidget 은 같은 자리다 — 하나만 쓴다',
       ),
       assert(
         icon == null || leadingWidget == null,
         'icon 과 leadingWidget 은 같은 자리다 — 하나만 쓴다',
       );

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HyphenTokens.sp3,
        // v2.5 (2026-08-12 사용자 지시): 위아래 12 씩이면 두 줄짜리 행 하나가
        // 70 을 넘어 업적·마일스톤 표가 화면을 다 먹었다. 8 로 내린다.
        vertical: HyphenTokens.sp2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leadingWidget != null) ...[
                leadingWidget!,
                const SizedBox(width: HyphenTokens.sp3),
              ] else if (icon != null) ...[
                Icon(icon, size: 20, color: iconColor ?? HyphenTokens.muted),
                const SizedBox(width: HyphenTokens.sp3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: HyphenTokens.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (titleBadge != null) ...[
                          const SizedBox(width: HyphenTokens.sp2),
                          titleBadge!,
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: subtitleColor == null
                            ? HyphenTokens.caption
                            : HyphenTokens.caption.copyWith(
                                color: subtitleColor,
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: HyphenTokens.sp3),
                Text(
                  trailing!,
                  style: HyphenTokens.micro.copyWith(
                    color: trailingColor ?? HyphenTokens.muted,
                    fontWeight: FontWeight.w600,
                    fontFeatures: HyphenTokens.tabular,
                  ),
                ),
              ],
              if (trailingWidget != null) ...[
                const SizedBox(width: HyphenTokens.sp3),
                trailingWidget!,
              ],
              // v2.2 (H8): 누를 수 있는 행에 오른쪽 화살표를 붙인다. 그전엔
              // 아이콘 + 제목만 있어 프로필 메뉴 10줄이 "읽는 목록"인지
              // "누르는 목록"인지 구분되지 않았다. 우측에 값이 이미 있는 행은
              // 자리를 다투므로 붙이지 않는다.
              if (onTap != null &&
                  trailing == null &&
                  trailingWidget == null) ...[
                const SizedBox(width: HyphenTokens.sp2),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: HyphenTokens.muted,
                ),
              ],
            ],
          ),
          if (below != null) ...[
            const SizedBox(height: HyphenTokens.sp1),
            below!,
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// 표 카드 — HkListRow 들을 1px 구분선으로 쌓는다 (카드 1개 = 표 1개).
class HkRowCard extends StatelessWidget {
  final List<Widget> rows;
  final EdgeInsetsGeometry? margin;
  const HkRowCard({super.key, required this.rows, this.margin});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(
          const Divider(
            height: 1,
            thickness: 1,
            color: HyphenTokens.border,
            indent: HyphenTokens.sp4,
            endIndent: HyphenTokens.sp4,
          ),
        );
      }
      children.add(rows[i]);
    }
    return HkCard(
      margin: margin,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HyphenTokens.r3),
        child: Column(children: children),
      ),
    );
  }
}

/// 아코디언 — 기본 접힘 묶음 구획. ExpansionTile 반복 배선(기본 divider 제거 ·
/// muted 화살표 · sectionLabel 제목 · 부제 preview)의 유일 규격.
/// 자주 쓰지 않는 항목 다발은 펼치기 전까지 헤더 한 줄만 차지한다
/// (v1.31 — 프로필 메뉴가 세로로 주렁주렁 길다는 사용자 지시로 도입).
/// [inset] = 카드 안에 넣을 때 true (좌우 여백을 카드 내부에 맞춤).
class HkAccordion extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;
  final bool inset;

  const HkAccordion({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.initiallyExpanded = false,
    this.inset = false,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      // ExpansionTile 기본 상·하단 divider 제거.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        // v2.5 (2026-08-12 사용자 지시 "50% 수준으로"): 기본 ExpansionTile 은
        // 제목+부제면 헤더 한 줄이 72 를 넘어 프로필 한 화면에 네 항목도 안 들어갔다.
        // dense + compact + 최소 높이 44 로 절반 가까이 내린다.
        dense: true,
        visualDensity: VisualDensity.compact,
        minTileHeight: 44,
        tilePadding: EdgeInsets.symmetric(
          horizontal: inset ? HyphenTokens.sp3 : 2,
          vertical: 0,
        ),
        childrenPadding: inset
            ? const EdgeInsets.fromLTRB(
                HyphenTokens.sp3,
                0,
                HyphenTokens.sp3,
                HyphenTokens.sp3,
              )
            : EdgeInsets.zero,
        collapsedIconColor: HyphenTokens.muted,
        iconColor: HyphenTokens.muted,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: HkSectionLabel(title),
        subtitle: subtitle == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: HyphenTokens.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        children: children,
      ),
    );
  }
}

/// 빈 상태 — h3 제목(영문 헤드라인) + 한글 캡션 수직 스택 (V10 패턴).
class HkEmptyState extends StatelessWidget {
  final String title;
  final String? caption;
  const HkEmptyState({super.key, required this.title, this.caption});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // D115 — 로딩·빈·에러가 같은 바닥(stateSlotH)을 갖는다. 셋의 실측 높이가
      // 22 / 70·97 / 131 로 달라 갈아 끼울 때마다 최대 109px 밀렸다.
      constraints: const BoxConstraints(minHeight: HyphenTokens.stateSlotH),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(HyphenTokens.sp5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: HyphenTokens.h3, textAlign: TextAlign.center),
              if (caption != null) ...[
                const SizedBox(height: HyphenTokens.sp2),
                Text(
                  caption!,
                  style: HyphenTokens.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 에러 상태 — 메시지 + Retry. 전 화면 문구·간격 고정.
/// AppException 이면 messageKo, 그 외 '로딩 실패.' — fromError 로 통일 매핑.
class HkErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const HkErrorState({super.key, required this.message, required this.onRetry});

  HkErrorState.fromError(Object? error, {super.key, required this.onRetry})
    : message = error is AppException ? error.messageKo : '로딩 실패.';

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // D115 — 빈·로딩과 같은 바닥. 셋 중 가장 큰 것이라 실제로는 이 값에 딱 맞는다.
      constraints: const BoxConstraints(minHeight: HyphenTokens.stateSlotH),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(HyphenTokens.sp5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: HyphenTokens.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HyphenTokens.sp3),
              HkButton.secondary('다시 시도', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}

/// 로딩 스피너 — 22×22 stroke 2 muted 단일 규격.
/// [color] 는 색 있는 면 위에 얹을 때만 (버튼 안 = onColor). 크기는 바꾸지 않는다.
///
/// **자리를 차지하는 로딩은 `HkLoading.slot()`** (D115 · 2026-09-04).
/// 기본 생성자는 22×22 그대로다 — 버튼 안처럼 이미 자리가 있는 곳에서 쓴다.
/// `loading ? HkLoading() : ... HkEmptyState()` 처럼 **빈·에러와 같은 자리에서
/// 갈아 끼울 때는 반드시 `.slot()`** 을 쓴다. 그러지 않으면 22 ↔ 132 로 밀린다.
class HkLoading extends StatelessWidget {
  final Color? color;

  /// 자리를 차지하지 않는 스피너 (버튼 안·줄 안).
  const HkLoading({super.key, this.color}) : _fit = _HkLoadingFit.center;

  /// 빈·에러와 **같은 바닥**(`stateSlotH`)을 갖는 로딩 자리.
  const HkLoading.slot({super.key, this.color}) : _fit = _HkLoadingFit.slot;

  /// 아이콘 한 칸에 그대로 끼우는 스피너 — **옆으로 번지지 않는다** (D118 ·
  /// 2026-09-05).
  ///
  /// 기본 생성자는 [Center] 라 남는 가로폭을 전부 먹는다. 버튼 안처럼 자리가
  /// 이미 정해진 곳에선 그게 맞지만, 입력칸 `suffixIcon` 처럼 **옆에 글자가
  /// 있는** 자리에 끼우면 글자 칸이 0 으로 눌려 줄이 접힌다 — 채팅 입력바가
  /// 그 때문에 65 → 129 로 부풀었다. 그런 자리엔 이 생성자를 쓴다.
  const HkLoading.icon({super.key, this.color}) : _fit = _HkLoadingFit.icon;

  final _HkLoadingFit _fit;

  @override
  Widget build(BuildContext context) {
    final dot = SizedBox(
      width: _spinnerSize,
      height: _spinnerSize,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? HyphenTokens.muted,
      ),
    );
    if (_fit == _HkLoadingFit.icon) return dot;
    final spinner = Center(child: dot);
    if (_fit == _HkLoadingFit.center) return spinner;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: HyphenTokens.stateSlotH),
      child: spinner,
    );
  }

  /// 22×22 stroke 2 — 세 생성자가 같은 원을 그린다 (크기는 여기 한 곳).
  static const double _spinnerSize = 22;
}

/// [HkLoading] 이 자리를 어떻게 차지하는가 — 셋뿐이다.
enum _HkLoadingFit {
  /// 가운데 정렬로 남는 자리를 채운다 (버튼 안).
  center,

  /// 빈·에러와 같은 바닥(`stateSlotH`).
  slot,

  /// 원 크기 그대로 — 옆 칸을 밀지 않는다 (아이콘 자리).
  icon,
}

/// 고정 높이 상단 띠 — **뒤로가기가 있든 없든 높이가 같다** (v3.33 · 2026-08-27
/// 사용자 지시 "고정 같은 자리").
///
/// 전엔 화면이 `appBar: Navigator.canPop(context) ? HkAppBar() : null` 로
/// 상단바 자체를 달았다 뗐다 했다 — 같은 화면인데 들어온 경로에 따라 본문 전체가
/// [HyphenTokens.appBarH] 만큼 위아래로 뛰었다. 이제 띠는 항상 있고, **안에 든
/// 화살표만** 조건부다. 구분선은 두지 않는다 (돌아갈 곳이 없을 때 빈 띠가
/// '죽은 줄'로 보이던 이유).
///
/// 제목·actions 가 필요한 밀어 넣은 화면은 종전대로 [HkAppBar] 를 쓴다.
class HkBackBar extends StatelessWidget {
  /// 화살표를 눌렀을 때. 기본은 [Navigator.maybePop].
  final VoidCallback? onBack;
  const HkBackBar({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return SizedBox(
      height: HyphenTokens.appBarH,
      width: double.infinity,
      child: canPop
          ? Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '뒤로',
                onPressed: onBack ?? () => Navigator.maybePop(context),
              ),
            )
          : null,
    );
  }
}

/// 안내·에러 한 줄이 들어올 **예약된 자리** (공간 예약 / space reservation).
///
/// v3.33 (2026-08-27 사용자 지시): `if (_error != null) ...[HkInlineError(...)]`
/// 로 블록이 생겼다 사라지면 그 아래가 통째로 밀린다. 이 위젯은 메시지가 없어도
/// [HyphenTokens.noticeSlotH] 만큼 자리를 지키고, 내용만 갈아 끼운다.
/// 규격·적용 대상 = DESIGN-SSOT §레이아웃 안정성.
class HkNoticeSlot extends StatelessWidget {
  /// null 이면 빈 자리만 남긴다.
  final String? message;

  /// 있으면 배너 우측에 '다시 시도' — 목록 위 실패 배너로 쓸 때 (v3.34).
  /// 자리 높이는 그대로다 (버튼이 붙어도 [HyphenTokens.noticeSlotH] 안).
  final VoidCallback? onRetry;
  const HkNoticeSlot(this.message, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HyphenTokens.noticeSlotH,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null) HkInlineError(message!, onRetry: onRetry),
        ],
      ),
    );
  }
}

/// 비동기 구역이 미리 잡아 두는 **예약된 자리** (공간 예약 / space reservation).
///
/// v3.34 (2026-08-27): 목록 구역을 `snap.data ?? []` 로 그리면 로딩 중에도
/// '없음' 문구가 먼저 뜨고, 응답이 도착하는 순간 내용이 튀어나오며 그 아래가
/// 통째로 밀린다. 한 화면에 그런 구역이 넷이면 도착 순서대로 네 번 밀린다.
///
/// 이 위젯은 셋을 **같은 자리**에 놓는다 — 로딩(스켈레톤) · 없음(문구) · 내용.
/// **로딩과 없음은 반드시 구분한다**: 아직 모르는 것과 없는 것은 다른 사실이다.
/// [minHeight] 는 그 구역의 한 줄 높이(평균 내용)로 잡는다 — 과하게 크면 빈
/// 화면이 허전해지고, 작으면 도착할 때 밀린다.
/// 규격·적용 대상 = DESIGN-SSOT §레이아웃 안정성.
class HkSectionSlot extends StatelessWidget {
  /// 항상 지키는 최소 높이. 내용이 이보다 길면 자연히 늘어난다.
  final double minHeight;

  /// 아직 도착하지 않았다 — 스켈레톤. ([child] 유무와 무관하게 우선한다.)
  final bool loading;

  /// 도착했는데 비어 있을 때의 한 줄 문구.
  final String empty;

  /// 도착한 내용. null 이면 [empty].
  final Widget? child;

  /// 스켈레톤 줄 수 — 그 구역의 한 줄 모양에 맞춘다.
  final int skeletonRows;

  const HkSectionSlot({
    super.key,
    required this.minHeight,
    required this.loading,
    required this.empty,
    this.child,
    this.skeletonRows = 1,
  });

  @override
  Widget build(BuildContext context) {
    final Widget inner;
    if (loading) {
      inner = _skeleton();
    } else if (child == null) {
      inner = Align(
        alignment: Alignment.topLeft,
        child: Text(empty, style: HyphenTokens.caption),
      );
    } else {
      inner = child!;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: SizedBox(width: double.infinity, child: inner),
    );
  }

  /// 정적 스켈레톤 — 반짝이는 애니메이션을 쓰지 않는다 (골든·pumpAndSettle 이
  /// 영원히 안 끝난다. 움직임은 스피너 하나로 충분하다).
  Widget _skeleton() {
    final rows = skeletonRows < 1 ? 1 : skeletonRows;
    final rowH = (minHeight - HyphenTokens.sp2 * (rows - 1)) / rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows; i++) ...[
          if (i > 0) const SizedBox(height: HyphenTokens.sp2),
          _HkSkeletonBar(height: rowH),
        ],
      ],
    );
  }
}

/// 스켈레톤 한 줄 — 내용이 들어올 면의 크기만 미리 보여 준다.
class _HkSkeletonBar extends StatelessWidget {
  final double height;
  const _HkSkeletonBar({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: HyphenTokens.surfaceAlt,
        borderRadius: BorderRadius.circular(HyphenTokens.r2),
      ),
    );
  }
}

/// 고른 값에 따라 나타나는 **미리보기 한 줄**의 예약된 자리 (공간 예약).
///
/// v3.33 (2026-08-27): [HkNoticeSlot] 이 에러·안내 전용이라면 이쪽은 일반
/// 미리보기용이다. `if (_x != null) ...[Row(...)]` 로 블록이 생겼다 사라지면
/// 그 아래 섹션이 통째로 밀린다 — 아직 고르지 않았을 때는 [placeholder] 한 줄이
/// 자리를 지키고, 고르면 [child] 로 갈아 끼운다. 바깥 높이는 어느 쪽이든 같다.
/// 규격·적용 대상 = DESIGN-SSOT §레이아웃 안정성.
class HkPreviewSlot extends StatelessWidget {
  /// 보여 줄 내용. null 이면 [placeholder] 한 줄이 대신 선다.
  final Widget? child;

  /// 아직 고르지 않았을 때 그 자리에 서는 안내 한 줄.
  final String placeholder;

  /// 슬롯 높이 — 들어올 수 있는 것 중 **가장 높은 것**(배지 26.2)에 맞춘다.
  final double height;

  const HkPreviewSlot({
    super.key,
    this.child,
    required this.placeholder,
    this.height = HyphenTokens.sp6,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerLeft,
        child:
            child ??
            Text(
              placeholder,
              style: HyphenTokens.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      ),
    );
  }
}

/// 스켈레톤 행 — 로딩 중 **모양만** 보여 주는 회색 자리 (skeleton screen).
///
/// v3.34 (2026-08-27 · DESIGN-SSOT §레이아웃 안정성). 목록이 로딩 → 완료로 바뀌면
/// 표가 한 줄에서 여러 줄로 커지며 그 아래를 통째로 밀어냈다. 이 행은 [HkListRow]
/// 한 줄과 **같은 높이**([rowH])를 차지해, 데이터가 도착해도 표 높이가 그대로다.
///
/// 공간 예약(space reservation)과는 다른 기법이다 — 자리를 잡는 것은 부모가 하고,
/// 이 위젯은 그 자리에 **무엇이 올지**를 미리 보여 준다. 둘을 같이 쓴다.
/// 깜빡이는 애니메이션은 두지 않는다 (무한 애니메이션은 골든·접근성 양쪽에 손해).
class HkSkeletonRow extends StatelessWidget {
  /// [HkListRow] 한 줄의 자연 높이 — 상하 sp2(8+8) + 제목(15×1.5=22.5) + 2 +
  /// 부제(13×1.45=18.85) = 59.35 → 60. 목록 자리는 이 값으로 예약한다.
  /// 앱이 글자 배율을 1.0 으로 고정하므로(main.dart `TextScaler.noScaling`)
  /// 이 값은 기기와 무관하게 성립한다.
  static const double rowH = 60;

  /// 좌측 배지(32) 자리를 함께 그릴지 — 업적 표처럼 아이콘이 붙는 목록용.
  final bool leading;

  /// 행 높이·배지 크기 — 기본은 [HkListRow] 한 줄([rowH]·32). 업적 전체 목록처럼
  /// 행이 더 큰 배지(44)를 싣는 표는 그 행과 **같은 값**을 넘긴다 (v3.35).
  final double height;
  final double leadingSize;
  const HkSkeletonRow({
    super.key,
    this.leading = false,
    this.height = rowH,
    this.leadingSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HyphenTokens.sp3),
        child: Row(
          children: [
            if (leading) ...[
              HkSkeletonBar(
                width: leadingSize,
                height: leadingSize,
                radius: leadingSize / 2,
              ),
              const SizedBox(width: HyphenTokens.sp3),
            ],
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HkSkeletonBar(width: 116, height: 12),
                SizedBox(height: HyphenTokens.sp2),
                HkSkeletonBar(width: 172, height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 스켈레톤 조각 — 글자·배지가 앉을 자리를 나타내는 회색 막대. 면은 border 1색.
class HkSkeletonBar extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const HkSkeletonBar({
    super.key,
    required this.width,
    required this.height,
    this.radius = HyphenTokens.r1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: HyphenTokens.border,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 한 줄 **전광판** — 글이 칸보다 길면 오른쪽에서 왼쪽으로 천천히 흐르고,
/// 칸에 다 들어가면 그냥 서 있다 (v3.42 · 2026-08-29 사용자 지시 "공지 칸만 좌에서
/// 우로 안에 내용이 TEXT 가 슬라이드 돌아가게").
///
/// 어디에 쓰나: 공지 접힌 줄처럼 **한 줄만 허락된 자리**에서 `…` 로 잘라 버리면
/// 뒷말이 영영 안 보인다. 펼치면 다 보이지만 "펼쳐야 보인다"는 것 자체가 안 읽히는
/// 이유다. 흐르게 하면 자리를 안 늘리고도 끝까지 보인다.
///
/// 규칙:
/// - **넘칠 때만 움직인다.** 짧은 글까지 흔들면 시선만 뺏는다. 넘치는지는 실제
///   레이아웃 폭으로 잰다 (글자 수 추정 금지 — 한글·영문 폭이 다르다).
/// - 속도는 초당 [pixelsPerSecond] — 글 길이에 비례해 한 바퀴 시간이 정해진다.
///   시작 전 [pauseAtStart] 만큼 멈춰 첫머리를 읽을 시간을 준다.
/// - 한 바퀴 돌면 처음으로 되감아 반복. 두 벌을 이어 붙여 끊김 없이 돈다.
/// - 접근성: 시스템 '애니메이션 줄이기'(`disableAnimations`) 면 움직이지 않고 `…` 처리.
/// - 세 노출 자리(수업 탭 공지 아코디언·홈 공지 카드·쪽지함 핀)가 **이 위젯 하나**를 쓴다
///   (§3 코드·클래스 SSOT — 화면마다 애니메이션을 따로 두지 않는다).
class HkMarquee extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double pixelsPerSecond;
  final Duration pauseAtStart;
  /// 두 벌 사이 간격 — 끝과 처음이 붙어 읽히지 않게.
  final double gap;

  /// **채워 흐름** (v3.43 · 2026-08-29 사용자 "짧은 글도 꽉 채워서 흐르게").
  /// true 면 짧은 글도 같은 글을 이어 붙여 줄을 꽉 채운 뒤 **항상** 흐른다 —
  /// 실제 전광판이 짧은 문구를 처리하는 방식. false 면 넘칠 때만 흐른다(기본).
  /// 접근성('애니메이션 줄이기')은 두 모드 모두 존중한다.
  final bool fill;

  const HkMarquee(
    this.text, {
    super.key,
    this.style,
    this.pixelsPerSecond = 32,
    this.pauseAtStart = const Duration(milliseconds: 1200),
    this.gap = 48,
    this.fill = false,
  });

  @override
  State<HkMarquee> createState() => _HkMarqueeState();
}

class _HkMarqueeState extends State<HkMarquee>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  double _textW = 0;
  double _boxW = 0;

  bool get _overflows => _textW > _boxW + 0.5;
  bool get _shouldScroll =>
      widget.fill ? widget.text.trim().isNotEmpty : _overflows;

  /// fill 모드에서 한 벌(글 + 간격)을 몇 번 이어야 칸을 넘기는가.
  int get _repeats {
    if (!widget.fill) return 1;
    final unit = _textW + widget.gap;
    if (unit <= 0) return 1;
    return (_boxW / unit).ceil() + 1;
  }

  void _measure(BuildContext context, double boxW) {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: _style(context)),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    _textW = tp.width;
    _boxW = boxW;
  }

  TextStyle _style(BuildContext context) =>
      widget.style ?? DefaultTextStyle.of(context).style;

  void _syncAnimation(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!_shouldScroll || reduce) {
      _ctrl?.stop();
      return;
    }
    final distance = _textW + widget.gap;
    final travel = Duration(
      milliseconds: (distance / widget.pixelsPerSecond * 1000).round(),
    );
    final total = widget.pauseAtStart + travel;
    if (_ctrl == null || _ctrl!.duration != total) {
      _ctrl?.dispose();
      _ctrl = AnimationController(vsync: this, duration: total)
        ..addListener(() => setState(() {}));
    }
    if (!_ctrl!.isAnimating) _ctrl!.repeat();
  }

  @override
  void didUpdateWidget(covariant HkMarquee old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _textW = 0; // 다시 잰다
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    return LayoutBuilder(
      builder: (ctx, c) {
        if (_boxW != c.maxWidth || _textW == 0) _measure(ctx, c.maxWidth);
        _syncAnimation(ctx);
        final reduce = MediaQuery.maybeOf(ctx)?.disableAnimations ?? false;
        if (!_shouldScroll || reduce) {
          return Text(
            widget.text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          );
        }
        // 진행률 → 픽셀 오프셋. 시작 멈춤 구간은 0 에 머문다.
        final total = _ctrl!.duration!.inMilliseconds.toDouble();
        final pause = widget.pauseAtStart.inMilliseconds.toDouble();
        final t = (_ctrl!.value * total - pause).clamp(0.0, total - pause);
        final distance = _textW + widget.gap;
        final dx = -(t / (total - pause)) * distance;
        return ClipRect(
          child: SizedBox(
            height: (style.fontSize ?? 14) * (style.height ?? 1.4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: dx,
                  top: 0,
                  child: Row(
                    children: [
                      // 기본: 두 벌. fill: 칸을 넘길 만큼 + 되감기용 한 벌 더.
                      for (var i = 0; i < _repeats + 1; i++) ...[
                        Text(widget.text,
                            style: style, maxLines: 1, softWrap: false),
                        SizedBox(width: widget.gap),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 높이가 오락가락하는 영역의 **자리를 미리 잡아 두는 슬롯** (공간 예약 /
/// space reservation).
///
/// [HkNoticeSlot] 이 안내 한 줄 전용 고정 높이라면, 이쪽은 내용을 가리지 않는
/// 범용 자리다. 로딩 스피너 → 목록, 공지 없음 → 공지 배너, 버튼 묶음 → 상태
/// 박스처럼 **상태에 따라 높이가 갈리는 곳**에 씌우면 아래 요소가 밀리지 않는다.
/// 규격·적용 대상 = DESIGN-SSOT §레이아웃 안정성.
///
/// - [minHeight] 는 그 자리가 가질 수 있는 **가장 긴 경우**로 잡는다. 내용이
///   그보다 짧아도 자리는 남고, 길면 그만큼만 늘어난다.
/// - [child] 가 null 이면 빈 자리만 남긴다 (내용이 아직·영영 없을 때).
class HkReservedSlot extends StatelessWidget {
  final double minHeight;
  final Widget? child;
  const HkReservedSlot({super.key, required this.minHeight, this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

/// 진입 계열 화면(스플래시·로그인·전면 로딩)의 로고 위 고정 간격 (DESIGN-SSOT §6).
///
/// v3.3 (2026-08-21 사용자 지시 "로고 위치 고정"): 스플래시는 로고를 세로 중앙에,
/// 로그인은 콘텐츠 블록째 중앙에 놓아 화면이 넘어갈 때마다 로고가 위아래로 뛰었다.
/// 콘텐츠 높이와 무관하게 로고가 같은 자리에 서도록, 화면 높이의 24% 를
/// 로고 위에 고정으로 깐다 (sp5 패딩 안 기준 — 진입 화면은 전부 sp5 패딩).
class HkEntryLogoGap extends StatelessWidget {
  static const double fraction = 0.24;
  const HkEntryLogoGap({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: MediaQuery.sizeOf(context).height * fraction);
  }
}

/// 전면 로딩 — 진입·전환 화면 유일 규격 (DESIGN-SSOT §6).
/// BrandLogo(기본 폭 220) + HkLoading + 선택 캡션. Scaffold body 로 그대로 끼운다.
/// v3.3: 세로 중앙 → HkEntryLogoGap 고정 오프셋 — 로그인 화면과 로고 자리가 같아
/// 버튼을 누르고 로딩으로 넘어가도 로고가 움직이지 않는다.
class HkLoadingScreen extends StatelessWidget {
  final String? caption;
  const HkLoadingScreen({super.key, this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HyphenTokens.bg,
      padding: const EdgeInsets.all(HyphenTokens.sp5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HkEntryLogoGap(),
          const Center(child: BrandLogo()),
          const SizedBox(height: HyphenTokens.sp6),
          const HkLoading(),
          if (caption != null) ...[
            const SizedBox(height: HyphenTokens.sp3),
            Text(
              caption!,
              style: HyphenTokens.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// 소셜 로그인 버튼 — 유일 규격 (높이 52 · r3 · 마크+라벨 중앙, DESIGN-SSOT §6).
/// 색은 HyphenTokens 외부 브랜드 색(naverGreen·googleSurface)만 사용.
class HkSocialButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final String markText;
  final Color? markColor;
  final VoidCallback? onPressed;

  const HkSocialButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.markText,
    required this.onPressed,
    this.markColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: HyphenTokens.buttonH,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(HyphenTokens.r3),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(HyphenTokens.r3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                markText,
                style: HyphenTokens.h3.copyWith(
                  color: markColor ?? foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: HyphenTokens.body.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: HyphenTokens.touchMin),
            ],
          ),
        ),
      ),
    );
  }
}

/// 스낵바 SSOT — 앱의 짧은 알림은 전부 이 창구로 낸다 (2026-08-21 신설).
///
/// 왜 필요했나: 스낵바가 화면마다 `ScaffoldMessenger...showSnackBar(SnackBar(...))`
/// 로 흩어져 있어(24개 파일) 모양·노출시간이 제각각이고, 캐릭터를 넣으려면
/// 전부를 따로 고쳐야 했다. 여기 하나로 모아 캐릭터 슬롯도 한 곳에만 둔다.
///
/// 캐릭터는 표정 3종(happy·sad·neutral)을 성격별로 돌려 쓴다 — 완료는 happy,
/// 실패는 sad, 안내는 neutral. 경로·존재 판단은 [HyphenMascot] SSOT 가 한다.
class HkSnack {
  const HkSnack._(this._messenger);

  final ScaffoldMessengerState _messenger;

  /// 비동기 작업 **전에** 미리 잡아 두는 손잡이. `await` 뒤에 context 를 다시
  /// 쓰면 위험하므로(화면이 이미 닫혔을 수 있다) 기존 코드가
  /// `final messenger = ScaffoldMessenger.of(context)` 로 잡아 두던 자리를
  /// 이것으로 바꾼다 — 같은 안전성에 캐릭터 슬롯만 얹힌다.
  static HkSnack of(BuildContext context) =>
      HkSnack._(ScaffoldMessenger.of(context));

  /// 손잡이로 내는 일반 알림. [detail] 을 주면 굵은 제목 아래 안내 줄(들)이 붙는다
  /// (D86 예약 완료 — 세 줄 토스트). 줄이 늘면 읽을 시간도 늘려 기본 5초.
  void info(
    String message, {
    MascotMood? mood,
    Duration? duration,
    List<String> detail = const [],
  }) => _emit(
    _messenger,
    message,
    mood: mood,
    detail: detail,
    duration:
        duration ??
        (detail.isEmpty
            ? const Duration(seconds: 2)
            : const Duration(seconds: 5)),
  );

  /// 손잡이로 내는 실패 알림.
  void fail(String message) => _emit(
    _messenger,
    message,
    mood: MascotMood.sad,
    duration: const Duration(seconds: 3),
    danger: true,
  );

  static void _emit(
    ScaffoldMessengerState messenger,
    String message, {
    MascotMood? mood,
    required Duration duration,
    bool danger = false,
    List<String> detail = const [],
  }) {
    final showMascot = mood != null && HyphenMascot.has(mood);
    final hasDetail = detail.isNotEmpty;
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: HyphenTokens.surface,
        behavior: SnackBarBehavior.floating,
        // 2026-08-21 — M3 기본 그림자가 골든에서 검은 띠로 찍힌다. 이 앱은
        // 면+1px 테두리로 층을 표현하므로(글로벌 design-block 다중 그림자 금지)
        // 그림자를 끈다.
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HyphenTokens.r2),
          side: BorderSide(
            color: danger ? HyphenTokens.danger : HyphenTokens.border,
            width: 1,
          ),
        ),
        content: Row(
          children: [
            if (showMascot) ...[
              HyphenMascot(mood: mood, size: 32),
              const SizedBox(width: HyphenTokens.sp3),
            ],
            Expanded(
              child: hasDetail
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message,
                          style: HyphenTokens.body.copyWith(
                            color: HyphenTokens.fg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: HyphenTokens.sp1),
                        for (final line in detail)
                          Text(
                            line,
                            style: HyphenTokens.caption.copyWith(
                              color: HyphenTokens.fgSecondary,
                            ),
                          ),
                      ],
                    )
                  : Text(
                      message,
                      style: HyphenTokens.body.copyWith(color: HyphenTokens.fg),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 일반 알림. [mood] 를 주면 캐릭터가 준비된 순간부터 함께 뜬다.
  static void show(
    BuildContext context,
    String message, {
    MascotMood? mood,
    Duration duration = const Duration(seconds: 2),
    List<String> detail = const [],
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    _emit(messenger, message, mood: mood, duration: duration, detail: detail);
  }

  /// 실패 알림 — 우는 표정(sad)을 쓴다. 웃는 캐릭터는 절대 붙이지 않는다.
  static void error(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    _emit(
      messenger,
      message,
      mood: MascotMood.sad,
      duration: const Duration(seconds: 3),
      danger: true,
    );
  }

  /// 진행 중 알림 — 굵은 제목 아래 가로 로딩바 (2026-08-30 사용자 "수업을 저장중이에요
  /// 로딩바 두두둥"). 스스로 사라지지 않는다 — 끝나면 [dismiss] 로 걷고 결과 알림을
  /// 낸다. 캐릭터는 붙이지 않는다(아직 결과가 아니다). 골든 `snack_06` · `state_29`.
  void progress(String message) {
    _messenger.showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 1),
        backgroundColor: HyphenTokens.surface,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HyphenTokens.r2),
          side: const BorderSide(color: HyphenTokens.border, width: 1),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: HyphenTokens.body.copyWith(
                color: HyphenTokens.fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: HyphenTokens.sp2),
            ClipRRect(
              borderRadius: BorderRadius.circular(HyphenTokens.r1),
              child: const LinearProgressIndicator(
                minHeight: 4,
                color: HyphenTokens.primary,
                backgroundColor: HyphenTokens.border,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 떠 있는 알림을 즉시 걷는다 — [progress] 뒤 결과 알림 직전에 부른다.
  void dismiss() => _messenger.removeCurrentSnackBar();
}

/// 폭죽 — 화면 중앙에서 잠깐 터지는 종이 조각 (D86 · 2026-08-29 사용자 "화면 중앙에
/// 폭죽 잠깐 쏴지는 애니메이션"). 예약 완료처럼 **성사된 순간** 한 번만 쏜다.
///
/// Overlay 하나를 얹고 1.1초 뒤 스스로 걷는다 — 터치를 막지 않고, 레이아웃에 끼어들지
/// 않는다(아래 화면은 한 픽셀도 안 밀린다). 조각은 고정 시드라 같은 모양으로 터진다 —
/// 골든이 잡을 수 있고, 매번 다를 이유도 없다. 시스템 '애니메이션 줄이기' 면 안 쏜다.
class HkConfetti {
  HkConfetti._();

  static const Duration duration = Duration(milliseconds: 1100);

  static void burst(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: _ConfettiBurst(onDone: () => entry.remove()),
      ),
    );
    overlay.insert(entry);
  }
}

class _ConfettiBurst extends StatefulWidget {
  final VoidCallback onDone;
  const _ConfettiBurst({required this.onDone});

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: HkConfetti.duration,
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_c.value),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);

  static const int _count = 56;
  static const List<Color> _palette = [
    HyphenTokens.primary,
    HyphenTokens.fg,
    HyphenTokens.success,
    HyphenTokens.warning,
    HyphenTokens.info,
  ];

  /// 조각의 초기값 — 고정 시드(같은 모양으로 터진다).
  static final List<_Piece> _pieces = () {
    final r = math.Random(7);
    return List.generate(_count, (i) {
      final angle = r.nextDouble() * math.pi * 2;
      final speed = 220 + r.nextDouble() * 260; // px/s
      return _Piece(
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 120,
        size: 5 + r.nextDouble() * 5,
        spin: (r.nextDouble() - 0.5) * 12,
        color: _palette[i % _palette.length],
      );
    });
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // 0.55 부터 옅어져 1.0 에 사라진다.
    final alpha = t < 0.55 ? 1.0 : (1 - (t - 0.55) / 0.45).clamp(0.0, 1.0);
    const g = 900.0; // px/s²
    final paint = Paint();
    for (final p in _pieces) {
      final x = cx + p.vx * t;
      final y = cy + p.vy * t + 0.5 * g * t * t;
      paint.color = p.color.withValues(alpha: alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _Piece {
  final double vx, vy, size, spin;
  final Color color;
  const _Piece({
    required this.vx,
    required this.vy,
    required this.size,
    required this.spin,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────
// v3.24 (2026-08-25 사용자 지시 "인라인·이원화 전부 통일") — 아래 4종은
// 화면마다 흩어져 있던 것을 HKit 으로 끌어올린 정본이다. 화면 코드에서
// AppBar( · AlertDialog( · showModalBottomSheet( · 에러 박스 Container 를
// 직접 쓰면 §3 코드·클래스 SSOT 위반 — 여기 것을 쓴다.
// ─────────────────────────────────────────────────────────────────────────

/// 상단바 정본. 모양은 테마(appBarTheme)가, **무엇을 싣는지**는 여기가 정한다.
///
/// - [HkAppBar] — 밀어 넣은(push) 화면: 뒤로가기 + 제목 (+ 선택 actions).
/// - [HkAppBar.identity] — 셸 상단바: 체육관명 + 역할 두 줄. 회원 셸·코치 셸이
///   같은 것을 쓴다 — 탭이 바뀌어도 상단바는 안 바뀐다 (브리프 D46·D47).
class HkAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? identityName;
  final String? identityRole;
  final List<Widget>? actions;
  final bool implyLeading;

  const HkAppBar({
    super.key,
    this.title,
    this.actions,
    this.implyLeading = true,
  }) : identityName = null,
       identityRole = null;

  const HkAppBar.identity({
    super.key,
    required String name,
    required String role,
    this.actions,
  }) : title = null,
       identityName = name,
       identityRole = role,
       implyLeading = false;

  @override
  Size get preferredSize => const Size.fromHeight(HyphenTokens.appBarH);

  @override
  Widget build(BuildContext context) {
    if (identityName != null) {
      return AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              identityName!,
              style: HyphenTokens.h3.copyWith(color: HyphenTokens.fg),
            ),
            Text(
              identityRole!,
              style: HyphenTokens.micro.copyWith(color: HyphenTokens.primary),
            ),
          ],
        ),
        actions: actions,
      );
    }
    return AppBar(
      automaticallyImplyLeading: implyLeading,
      title: title == null ? null : Text(title!),
      actions: actions,
    );
  }
}

/// 다이얼로그 정본 — 모양은 테마(dialogTheme), 버튼은 [HkButton] 만.
///
/// 확인형은 [confirm] (되돌릴 수 없는 동작은 `danger: true`), 알림형은 [info],
/// 입력칸 등 자유 내용은 [custom]. 화면에서 AlertDialog 를 직접 만들지 않는다.
class HkDialog {
  HkDialog._();

  static const EdgeInsets _actionsPad = EdgeInsets.fromLTRB(
    HyphenTokens.sp3,
    0,
    HyphenTokens.sp3,
    HyphenTokens.sp3,
  );

  /// 두 버튼의 앵커 — 레이아웃 안정성 좌표 검사가 이 키로 버튼 자리를 잰다
  /// (`test/golden/layout_stability.dart`).
  static const Key kCancelButton = Key('hk_dialog_cancel');
  static const Key kConfirmButton = Key('hk_dialog_confirm');

  /// 취소/확정 두 버튼. 확정이면 true.
  ///
  /// [notice] 는 상황이 부르면 본문 아래 붙는 안내 한 줄이다 (예: 늦은 취소
  /// 차감). 다이얼로그가 열린 뒤 붙거나 빠지지 않으므로 자리를 미리 잡지
  /// 않는다 — 안내 없는 다이얼로그는 빈 띠 없이 본문 바로 아래가 버튼이다.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String? notice,
    String confirmLabel = '확인',
    String cancelLabel = '취소',
    bool danger = false,
  }) async {
    // 안내가 붙으면 폭을 슬롯(전체)에 맞추고, 없으면 종전처럼 글자 폭에 맞춘다.
    final Widget? content = notice != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message != null) ...[
                Text(message),
                const SizedBox(height: HyphenTokens.sp2),
              ],
              HkInlineError(notice),
            ],
          )
        : message == null
        ? null
        : Text(message);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: content,
        actionsPadding: _actionsPad,
        actions: [
          HkButton.tertiary(
            cancelLabel,
            key: kCancelButton,
            neutral: true,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          danger
              ? HkButton.primary(
                  confirmLabel,
                  key: kConfirmButton,
                  expand: false,
                  danger: true,
                  onPressed: () => Navigator.pop(ctx, true),
                )
              : HkButton.tertiary(
                  confirmLabel,
                  key: kConfirmButton,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
        ],
      ),
    );
    return ok == true;
  }

  /// 확인 버튼 하나.
  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    String label = '확인',
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actionsPadding: _actionsPad,
        actions: [
          HkButton.tertiary(label, onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  /// 자유 내용 (입력칸 등). actions 는 [HkButton] 으로 만든다.
  static Future<T?> custom<T>(
    BuildContext context, {
    required String title,
    required Widget content,
    required List<Widget> Function(BuildContext ctx) actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: content,
        actionsPadding: _actionsPad,
        actions: actions(ctx),
      ),
    );
  }
}

/// 바텀시트 정본 — 모양은 테마(bottomSheetTheme). 항상 isScrollControlled.
/// 시트 안에서 자기 배경을 그리는 위젯(WodResultSheet)만 `transparent: true`.
class HkSheet {
  HkSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool transparent = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: transparent ? Colors.transparent : null,
      builder: builder,
    );
  }
}

/// 폼 안 인라인 에러 박스 (로그인 실패 등 — 화면을 갈아엎지 않고 그 자리에 알림).
/// 전면 에러는 [HkErrorState], 스낵은 [HkSnack.error] — 셋은 자리가 다르다.
class HkInlineError extends StatelessWidget {
  final String message;

  /// 있으면 우측에 '다시 시도' — 목록 위 한 줄 배너로 쓸 때 (v3.25).
  final VoidCallback? onRetry;
  const HkInlineError(this.message, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final text = Text(
      message,
      style: HyphenTokens.caption.copyWith(color: HyphenTokens.danger),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: HyphenTokens.sp3,
        vertical: onRetry == null ? HyphenTokens.sp2 : 0,
      ),
      decoration: BoxDecoration(
        color: HyphenTokens.danger.withValues(alpha: 0.12),
        border: Border.all(color: HyphenTokens.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(HyphenTokens.r2),
      ),
      child: onRetry == null
          ? text
          : Row(
              children: [
                Expanded(child: text),
                HkButton.tertiary('다시 시도', neutral: true, onPressed: onRetry),
              ],
            ),
    );
  }
}

/// n칸 전환 — 같은 목록을 다른 기준으로 보는 **상호 배타 선택** (v3.35 ·
/// 2026-08-28 사용자 확정 업적 E 안 "전체 / 진행 중 / 완료").
///
/// 배지([HkBadge])를 여럿 나열하는 필터 칩과 다르다 — 이건 한 줄을 n 등분하는
/// 한 덩어리다. r1 사각 + 1px fg 테두리, 켜진 칸은 면 반전. 높이는 [height] 고정 —
/// 자리 예약·스켈레톤이 같은 값을 쓴다. 새 전환 variant 신설 금지.
class HkSegment extends StatelessWidget {
  static const double height = 40;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  const HkSegment({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HyphenTokens.surface,
        border: Border.all(color: HyphenTokens.fg),
        borderRadius: BorderRadius.circular(HyphenTokens.r1),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) Container(width: 1, color: HyphenTokens.fg),
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                label: labels[i],
                child: InkWell(
                  onTap: () => onSelected(i),
                  child: Container(
                    color: i == selected
                        ? HyphenTokens.fg
                        : Colors.transparent,
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      style: HyphenTokens.micro.copyWith(
                        color: i == selected
                            ? HyphenTokens.bg
                            : HyphenTokens.fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 하단 탭바 정본 — 회원 셸·코치 셸이 같은 것을 쓴다 (v3.25 · 두 벌 → 하나).
/// 테마(색·인디케이터·라벨)·상단 구분선·SafeArea 까지 여기.
class HkTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavigationDestination> destinations;

  const HkTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: HyphenTokens.bg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: HyphenTokens.accent.withValues(alpha: 0.18),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HyphenTokens.r2),
        ),
        // v2.2: 켜진 탭을 브랜드색으로 — 인디케이터 면 하나로만 구분되면 흐리다.
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return HyphenTokens.micro.copyWith(
            color: selected ? HyphenTokens.primary : HyphenTokens.muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.1,
          );
        }),
      ),
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: HyphenTokens.border, width: 1),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            height: AppKit.tabbarH,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 전화 걸기 (2026-08-28 테스터 요청 9 — "전화번호를 눌러서 바로 걸리게").
// 번호를 화면에 적어 두는 것으로 끝내지 않는다. 회원은 체육관에 전화를 걸려고
// 그 줄을 보고, 코치는 신청자에게 전화를 걸려고 그 줄을 본다.
// ─────────────────────────────────────────────────────────────────────────

/// 전화 동작 정본 — 번호를 다듬고, 걸고, 못 걸면 복사한다.
///
/// `tel:` 은 숫자와 `+` 만 받는다 (하이픈·괄호·공백이 섞이면 전화 앱이 번호를
/// 잘못 읽는다). 안드로이드 11+ 는 매니페스트 `<queries>` 에 `tel` 인텐트가
/// 선언돼 있어야 조회가 통과한다 (android/app/src/main/AndroidManifest.xml).
class HkPhone {
  const HkPhone._();

  /// `tel:` 에 넘길 형태 — 숫자와 `+` 만. 걸 수 없는 값이면 null.
  static String? number(String? raw) {
    final digits = (raw ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    return digits.length < 3 ? null : digits;
  }

  /// 이 값으로 전화를 걸 수 있는가 — 빈 값·기호뿐인 값이면 탭 자체를 만들지 않는다.
  static bool canDial(String? raw) => number(raw) != null;

  /// 전화 앱 열기. **통화 앱이 없는 기기(태블릿 등)에서는 조용히 끝내지 않는다** —
  /// 번호를 복사하고 그 사실을 알린다 (아무 일도 안 일어나면 고장으로 읽힌다).
  static Future<void> dial(BuildContext context, String raw) async {
    final n = number(raw);
    if (n == null) return;
    // await 뒤에 context 를 다시 쓰지 않도록 손잡이를 먼저 잡는다.
    final snack = HkSnack.of(context);
    var ok = false;
    try {
      ok = await launchUrl(Uri(scheme: 'tel', path: n));
    } catch (_) {
      ok = false;
    }
    if (ok) return;
    await Clipboard.setData(ClipboardData(text: n));
    snack.info('전화 앱을 열지 못했습니다. 번호를 복사했습니다.');
  }
}

/// 전화번호 한 줄 — 걸 수 있으면 브랜드색 + 탭, 아니면 평범한 글자.
///
/// 번호를 노출하는 자리는 전부 이것을 쓴다 (§3 코드·클래스 SSOT). 색이 곧
/// "누를 수 있다" 는 신호라, 탭이 없는 값에는 색도 주지 않는다.
class HkPhoneText extends StatelessWidget {
  const HkPhoneText(this.phone, {super.key, this.style});

  final String phone;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? HyphenTokens.body;
    if (!HkPhone.canDial(phone)) return Text(phone, style: base);
    // 글자 높이(약 22)로만 잡으면 손가락이 자주 빗나간다. 집 규칙인 터치 48 을
    // 세로로 확보한다 — 폭은 부모가 이미 줄 전체를 준다.
    return InkWell(
      onTap: () => HkPhone.dial(context, phone),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: HyphenTokens.touchMin),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            phone,
            style: base.copyWith(color: HyphenTokens.primary),
          ),
        ),
      ),
    );
  }
}

// ─── 요일 띠 (D111 · 2026-09-04) ──────────────────────────────────────────────

/// 요일 칸 아래 점의 뜻 — 정의는 호출부 한 곳(`week_board.dart dayMark`)이 정한다.
enum HkDayMark { none, hasClass, reserved }

/// 요일 띠의 칸 하나 — 요일 글자 · 날짜 숫자 · 오늘 여부 · 점.
class HkDayCell {
  final String weekday;
  final int day;
  final bool isToday;
  final HkDayMark mark;
  const HkDayCell({
    required this.weekday,
    required this.day,
    this.isToday = false,
    this.mark = HkDayMark.none,
  });
}

/// 요일 띠 — 한 주 7칸, 고른 날 하나만 아래에 편다 (회원 수업 탭 · D111).
///
/// 사용자 결정(2026-09-04 목업 1안): 요일 아코디언(하루 = 접힌 줄) 대신 **띠**.
/// '수업 없음' 요일 줄이 오늘 내용 위에 쌓이던 세로 낭비가 사라지고, 어느 날을
/// 골라도 띠·그 위 줄의 y 는 그대로다 (높이 고정 [height]).
/// - 오늘 = 면 채움(fg) · 고른 날 = 테두리 · 점 = 주색(내 예약) / 회색(수업 있음) / 없음.
/// - 점 자리는 항상 잡는다 — 예약이 생겨도 칸 높이가 안 변한다.
class HkDayStrip extends StatelessWidget {
  static const double height = 58;
  final List<HkDayCell> cells;
  final int selected;
  final ValueChanged<int> onSelected;

  /// 칸마다 붙일 키 — 안정성 검사가 칸의 y 를 잰다 (`WeekBoard.dayKey`).
  final Key Function(int index)? cellKey;

  const HkDayStrip({
    super.key,
    required this.cells,
    required this.selected,
    required this.onSelected,
    this.cellKey,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            // D113 — 칸 사이 간격을 없애 7칸이 각자 48 을 갖는다 (336 / 7 = 48).
            // 칸끼리 붙어도 오늘·고른 날 표시가 배경·테두리라 경계는 그대로 읽힌다.
            Expanded(child: _cell(i)),
          ],
        ],
      ),
    );
  }

  Widget _cell(int i) {
    final c = cells[i];
    final on = i == selected;
    final fg = c.isToday ? HyphenTokens.bg : HyphenTokens.fg;
    final sub = c.isToday ? HyphenTokens.bg : HyphenTokens.muted;
    final Color dot;
    switch (c.mark) {
      case HkDayMark.reserved:
        dot = c.isToday ? HyphenTokens.bg : HyphenTokens.primary;
      case HkDayMark.hasClass:
        dot = c.isToday ? HyphenTokens.bg : HyphenTokens.muted;
      case HkDayMark.none:
        dot = Colors.transparent;
    }
    return Semantics(
      button: true,
      selected: on,
      label: '${c.weekday} ${c.day}',
      child: InkWell(
        key: cellKey?.call(i),
        onTap: () => onSelected(i),
        borderRadius: BorderRadius.circular(HyphenTokens.r1),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: c.isToday ? HyphenTokens.fg : Colors.transparent,
            border: Border.all(
              color: on && !c.isToday ? HyphenTokens.fg : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(HyphenTokens.r1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                c.weekday,
                style: HyphenTokens.caption.copyWith(
                  color: sub,
                  fontWeight: on || c.isToday ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${c.day}',
                style: HyphenTokens.body.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontFeatures: HyphenTokens.tabular,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
