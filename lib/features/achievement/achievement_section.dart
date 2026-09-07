import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/haptic.dart';
import '../../core/theme.dart';
import '../../models/achievement.dart';
import '../../widgets/hkit.dart';
import 'achievement_card.dart';
import 'achievement_state.dart';
import 'achievements_screen.dart';
import 'hyphen_pictogram.dart';
import '../../core/time_format.dart';

/// 업적 섹션 — 최근 해금 표 (v1.30: 색 타일 3열 그리드 → 한 줄 한 항목).
/// 초과분은 마지막 줄이 "그 외 N개" → 전체 보기.
/// Locked 항목은 이 섹션에서 제거 → AchievementsScreen 전용.
///
/// v3.34 (2026-08-27 · DESIGN-SSOT §레이아웃 안정성): **표 자리를 항상 지킨다.**
/// 전엔 진입 직후 빈 상태 한 줄로 그려졌다가 업적이 도착하면 여러 줄 표로 커지며
/// 아래(마일스톤·도전)를 통째로 밀어냈다. 이제 로딩·빈·데이터 세 상태가 모두
/// [kBodyH] 만큼의 같은 자리를 차지하고, 로딩 중에는 그 자리에 스켈레톤
/// ([HkSkeletonRow]) 을 깐다.
///
/// 자리를 [kRows] 줄로 못 박았으므로 **표시 줄 수도 같은 값으로 묶는다** — 그러지
/// 않으면 해금이 늘어난 사람에게서 다시 밀림이 생긴다. 넘치는 개수는 종전대로
/// 마지막 "그 외 N개" 줄이 받는다 (§7-A). 5줄이 아니라 3줄로 잡은 이유는, 예약한
/// 자리는 업적이 하나도 없는 사람에게도 그대로 비어 있기 때문이다 — 다 보려면
/// 헤더의 '전체 보기'.
class AchievementSection extends StatelessWidget {
  /// 상태와 무관하게 표가 지키는 줄 수.
  ///
  /// 2026-09-07 (D128-b · 사용자 "업적 빈 카드 축소"): 3 → **2**. 업적이 0인 회원에게는
  /// 이 자리가 통째로 빈 채로 서 있어 홈에서 가장 큰 공백이었다. 줄여도 **밀림은 그대로
  /// 막힌다** — 예약 자리와 표시 줄 수를 같은 값으로 묶는 규칙(v3.34)은 유지하고 값만
  /// 내렸다. 대가: 업적이 많은 회원의 홈은 3줄 → 2줄만 보이고 나머지는 "그 외 N개" 와
  /// 헤더 '전체 보기' 가 받는다.
  static const int kRows = 2;

  /// 예약 높이 — [kRows] 줄 + 그 사이 1px 구분선 + 카드 테두리 위아래 1px.
  /// (HkRowCard = HkCard 이므로 테두리 2px 가 바깥 높이에 더해진다.)
  static const double kBodyH =
      kRows * HkSkeletonRow.rowH + (kRows - 1) * 1.0 + 2.0;

  const AchievementSection({super.key});

  void _showDetail(
    BuildContext context,
    AchievementCatalog catalog,
    AchievementUnlock? unlock,
  ) {
    Haptic.light();
    HkSheet.show(
      context,
      builder: (_) => _DetailSheet(
        catalog: catalog,
        unlock: unlock,
        rarityColor: RarityPalette.of(catalog.rarity).light,
      ),
    );
  }

  void _goAll(BuildContext context) {
    Haptic.light();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AchievementsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AchievementState>();
    final snap = state.snapshot;
    final totalVisible = snap.visibleCount;
    final unlockedCount = snap.unlockedCount;
    // 첫 로드가 끝나기 전 — 카탈로그 자체가 아직 없다. 이때만 스켈레톤을 깐다
    // (이미 받아 둔 표를 새로고침할 때 회색으로 되돌리면 더 어지럽다).
    final loading = state.isLoading && snap.catalog.isEmpty;

    // 최근 해금 순 정렬
    final unlockedList =
        snap.catalog.where((c) => snap.isUnlocked(c.code)).toList()
          ..sort((a, b) {
            final ua = snap.unlocked[a.code]?.unlockedAt;
            final ub = snap.unlocked[b.code]?.unlockedAt;
            if (ua == null && ub == null) return 0;
            if (ua == null) return 1;
            if (ub == null) return -1;
            return ub.compareTo(ua);
          });

    // 예약한 자리(kRows 줄)를 넘지 않게 자른다. 넘치면 마지막 줄이 "그 외 N개".
    final bool hasOverflow = unlockedList.length > kRows;
    final int shown = hasOverflow ? kRows - 1 : unlockedList.length;
    final displayItems = unlockedList.take(shown).toList();
    final overflowCount = unlockedCount - shown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더
        Row(
          children: [
            const Expanded(child: HkSectionLabel('업적')),
            Text('$unlockedCount / $totalVisible', style: HyphenTokens.caption),
            const SizedBox(width: HyphenTokens.sp2),
            HkButton.tertiary('전체 보기', onPressed: () => _goAll(context)),
          ],
        ),
        const SizedBox(height: HyphenTokens.sp2),

        // 예약된 자리 — 세 상태가 같은 높이를 쓴다. 고정 높이가 아니라
        // minHeight 인 이유는, 행 모양이 나중에 바뀌어 예약치를 넘더라도
        // overflow 로 깨지지 않고 늘어나기만 하게 하려는 것이다
        // (그때는 아래 stability_home_test 가 밀림을 잡아 준다).
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kBodyH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loading)
                // 줄 수는 kRows 하나에서 나온다 — 여기 숫자를 따로 적으면
                // 예약 높이(kBodyH)와 스켈레톤이 갈려 그 순간 밀림이 생긴다
                // (2026-09-07: 실제로 3 이 박혀 있어 kRows 를 2 로 내리자 어긋났다).
                HkRowCard(
                  rows: List<Widget>.generate(
                    kRows,
                    (_) => const HkSkeletonRow(leading: true),
                  ),
                )
              else if (unlockedList.isEmpty)
                // 빈 상태 — 아직 해금 없음. 예약한 자리를 그대로 채운다.
                _EmptyState(onTap: () => _goAll(context))
              else
                HkRowCard(
                  rows: [
                    for (final c in displayItems)
                      HkListRow(
                        leadingWidget: AchievementBadge(
                          code: c.code,
                          rarity: c.rarity,
                          icon: c.icon,
                          size: 32,
                          locked: snap.unlocked[c.code] == null,
                          hidden: c.isHidden && snap.unlocked[c.code] == null,
                        ),
                        title: _rowTitle(c),
                        subtitle: c.description,
                        trailing: RarityPalette.of(c.rarity).ko,
                        trailingColor: RarityPalette.of(c.rarity).light,
                        onTap: () =>
                            _showDetail(context, c, snap.unlocked[c.code]),
                      ),
                    if (hasOverflow)
                      HkListRow(
                        icon: Icons.more_horiz,
                        title: '그 외 $overflowCount개',
                        trailing: '전체 보기',
                        trailingColor: HyphenTokens.accent,
                        onTap: () => _goAll(context),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 행 제목 — 한글 칭호 우선, 없으면 업적 고유명(영문). 표기 정본 = AchievementCard.
  static String _rowTitle(AchievementCatalog c) =>
      AchievementCard.displayTitle(c);

  // 부제 = 업적 설명(한글). 해금일은 행에 싣지 않고 상세 시트에서만 노출.
}

// ─── 빈 상태 ─────────────────────────────────────────────────────────────────

/// 빈 상태 — 예약한 자리([AchievementSection.kBodyH])를 그대로 채운다.
/// 한 줄짜리 상자를 위에 붙이고 아래를 비워 두면 "덜 그려진 화면"으로 읽힌다.
class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: AchievementSection.kBodyH,
        padding: const EdgeInsets.symmetric(
          vertical: HyphenTokens.sp2,
          horizontal: HyphenTokens.sp3,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: HyphenTokens.border, width: 0.8),
          borderRadius: BorderRadius.circular(HyphenTokens.r2),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.military_tech_outlined,
              size: 18,
              color: HyphenTokens.muted,
            ),
            SizedBox(height: HyphenTokens.sp2),
            Text(
              '아직 업적 없음',
              style: HyphenTokens.body,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: HyphenTokens.sp1),
            Text(
              '수업 기록을 저장하면 해금됩니다.',
              style: HyphenTokens.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 상세 바텀시트 ────────────────────────────────────────────────────────────

class _DetailSheet extends StatelessWidget {
  final AchievementCatalog catalog;
  final AchievementUnlock? unlock;
  final Color rarityColor;

  const _DetailSheet({
    required this.catalog,
    required this.unlock,
    required this.rarityColor,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = unlock != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          HyphenTokens.sp5,
          HyphenTokens.sp4,
          HyphenTokens.sp5,
          HyphenTokens.sp5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: HyphenTokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: HyphenTokens.sp4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2026-08-21 픽토그램 팩 — AchievementBadge 가 판까지 그린다.
                // 감싸던 원형 컨테이너는 제거 (안 지우면 판이 두 겹).
                AchievementBadge(
                  code: catalog.code,
                  rarity: catalog.rarity,
                  icon: catalog.icon,
                  size: 52,
                  locked: unlock == null,
                  hidden: catalog.isHidden && unlock == null,
                ),
                const SizedBox(width: HyphenTokens.sp3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상세 시트 타이틀 = 선언형 고유명("First Ten.") 유지.
                      Text(
                        catalog.name,
                        style: HyphenTokens.h3.copyWith(
                          color: HyphenTokens.fg,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (AchievementCard.koreanTitle(
                        catalog.code,
                      ).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          AchievementCard.koreanTitle(catalog.code),
                          style: HyphenTokens.caption,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HyphenTokens.sp2,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: rarityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(HyphenTokens.r1),
                  ),
                  child: Text(
                    RarityPalette.of(catalog.rarity).ko,
                    style: HyphenTokens.micro.copyWith(
                      color: rarityColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: HyphenTokens.sp4),
            Container(height: 1, color: HyphenTokens.border),
            const SizedBox(height: HyphenTokens.sp4),
            Text(
              isUnlocked ? catalog.description : _hint(),
              style: HyphenTokens.body,
            ),
            if (isUnlocked) ...[
              const SizedBox(height: HyphenTokens.sp3),
              Text(
                '${ymd(unlock!.unlockedAt.gym())} 해금',
                style: HyphenTokens.caption.copyWith(
                  color: HyphenTokens.accent,
                ),
              ),
            ],
            const SizedBox(height: HyphenTokens.sp2),
          ],
        ),
      ),
    );
  }

  String _hint() => AchievementCard.lockedHint(catalog);
}
