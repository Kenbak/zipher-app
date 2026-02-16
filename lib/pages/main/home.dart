import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:warp_api/data_fb_generated.dart';
import 'package:warp_api/warp_api.dart';

import '../../generated/intl/messages.dart';
import '../../appsettings.dart';
import '../../store2.dart';
import '../../accounts.dart';
import '../../zipher_theme.dart';
import '../accounts/send.dart';
import '../scan.dart';
import '../utils.dart';
import 'sync_status.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      final key = ValueKey(aaSequence.seqno);
      return HomePageInner(key: key);
    });
  }
}

class HomePageInner extends StatefulWidget {
  HomePageInner({super.key});
  @override
  State<StatefulWidget> createState() => _HomeState();
}

class _HomeState extends State<HomePageInner> {
  bool _balanceHidden = false;

  // Track when a shield was last submitted (persists across rebuilds)
  static DateTime? _lastShieldSubmit;

  @override
  void initState() {
    super.initState();
    syncStatus2.update();
    Future(marketPrice.update);
  }

  String _formatFiat(double x) => '\$${x.toStringAsFixed(2)}';

  void _showAccountSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AccountSwitcherSheet(
        onAccountChanged: () => setState(() {}),
      ),
    );
  }

  Future<void> _onRefresh() async {
    if (syncStatus2.syncing) return;
    if (syncStatus2.paused) syncStatus2.setPause(false);
    syncStatus2.sync(false);
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: ZipherColors.bg,
      body: Observer(
        builder: (context) {
          aaSequence.seqno;
          aa.poolBalances;
          syncStatus2.changed;

          final totalBal = aa.poolBalances.transparent +
              aa.poolBalances.sapling +
              aa.poolBalances.orchard;
          final shieldedBal =
              aa.poolBalances.sapling + aa.poolBalances.orchard;
          final transparentBal = aa.poolBalances.transparent;

          final fiatPrice = marketPrice.price;
          final fiatBalance =
              fiatPrice != null ? totalBal * fiatPrice / ZECUNIT : null;
          final fiatStr =
              fiatBalance != null ? _formatFiat(fiatBalance) : null;

          final txs = aa.txs.items;
          final recentTxs = txs.length > 5 ? txs.sublist(0, 5) : txs;

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: ZipherColors.cyan,
            backgroundColor: ZipherColors.surface,
            child: Stack(
              children: [
                // Radial gradient glow behind balance (Jupiter-style)
                Positioned(
                  top: -80,
                  left: 0,
                  right: 0,
                  height: 380,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.3),
                        radius: 1.2,
                        colors: [
                          ZipherColors.cyan.withValues(alpha: 0.08),
                          ZipherColors.purple.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header: logo + "Main" … QR scan
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 0),
                    child: Row(
                      children: [
                        // Zipher logo
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: ZipherColors.cyan.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/zipher_logo.png',
                              width: 20,
                              height: 20,
                            ),
                          ),
                        ),
                        const Gap(10),
                        GestureDetector(
                          onTap: () => _showAccountSwitcher(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                aa.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const Gap(4),
                              Icon(
                                Icons.expand_more_rounded,
                                size: 20,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // QR scan shortcut
                        GestureDetector(
                          onTap: () => GoRouter.of(context).push(
                            '/scan',
                            extra: ScanQRContext((code) {
                              try {
                                final sc = SendContext.fromPaymentURI(code);
                                GoRouter.of(context).push(
                                  '/account/quick_send',
                                  extra: sc,
                                );
                              } catch (_) {
                                GoRouter.of(context).push(
                                  '/account/quick_send',
                                );
                              }
                              return true;
                            }),
                          ),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sync banner — only during active sync
                SliverToBoxAdapter(child: SyncStatusWidget()),

                // Balance area (tappable to toggle visibility)
                SliverToBoxAdapter(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _balanceHidden = !_balanceHidden),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                      child: Column(
                        children: [
                          // Balance display
                          _balanceHidden
                              ? const Text(
                                  '••••••',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 4,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Image.asset(
                                          'assets/zcash_logo.png',
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const Gap(10),
                                    Text(
                                      amountToString2(totalBal),
                                      style: const TextStyle(
                                        fontSize: 38,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    const Gap(8),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'ZEC',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                          // Fiat value
                          if (fiatStr != null && !_balanceHidden) ...[
                            const Gap(4),
                            Text(
                              fiatStr,
                              style: TextStyle(
                                fontSize: 15,
                                color:
                                    Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                          if (_balanceHidden) ...[
                            const Gap(6),
                            Text(
                              'Tap to reveal',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                          ],

                          // (privacy info moved to shield banner below)
                        ],
                      ),
                    ),
                  ),
                ),

                // Action buttons
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.move_to_inbox_rounded,
                            label: 'Receive',
                            onTap: () => GoRouter.of(context)
                                .push('/account/pay_uri'),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.send_rounded,
                            label: 'Send',
                            onTap: () => _send(false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Privacy banner — contextual
                if (totalBal > 0 && transparentBal > 0) ...[
                  // Check if a shield was recently submitted (< 10 min)
                  if (_lastShieldSubmit != null &&
                      DateTime.now().difference(_lastShieldSubmit!).inMinutes < 10)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: _ShieldingInProgress(),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: _ShieldNudge(
                          transparentBal: transparentBal,
                          shieldedBal: shieldedBal,
                          totalBal: totalBal,
                          onShield: () => _shield(transparentBal),
                        ),
                      ),
                    ),
                ] else if (totalBal > 0 && transparentBal == 0) ...[
                  // Transparent is zero — clear any pending shield flag
                  if (_lastShieldSubmit != null)
                    SliverToBoxAdapter(child: Builder(builder: (_) {
                      _lastShieldSubmit = null;
                      return const SizedBox.shrink();
                    })),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: _FullyPrivateBadge(),
                    ),
                  ),
                ],

                // Backup warning
                if (!aa.saved)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _buildBackupReminder(s),
                    ),
                  ),

                // Activity header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Activity',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        if (recentTxs.isNotEmpty)
                          GestureDetector(
                            onTap: () =>
                                GoRouter.of(context).go('/history'),
                            child: Text(
                              'See all',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Transaction list or empty state
                if (recentTxs.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 28,
                                color: Colors.white
                                    .withValues(alpha: 0.12)),
                            const Gap(8),
                            Text(
                              'No transactions yet',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _TxRow(tx: recentTxs[index], index: index),
                        childCount: recentTxs.length,
                      ),
                    ),
                  ),
              ],
            ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackupReminder(S s) {
    return GestureDetector(
      onTap: _backup,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: ZipherColors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.shield_outlined,
                size: 18,
                color: ZipherColors.orange.withValues(alpha: 0.8)),
            const Gap(12),
            Expanded(
              child: Text(
                'Back up your wallet',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: ZipherColors.orange.withValues(alpha: 0.9),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: ZipherColors.orange.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  void _send(bool custom) async {
    final protectSend = appSettings.protectSend;
    if (protectSend) {
      final authed = await authBarrier(context, dismissable: true);
      if (!authed) return;
    }
    final c = custom ? 1 : 0;
    GoRouter.of(context).push('/account/quick_send?custom=$c');
  }

  void _backup() {
    GoRouter.of(context).push('/more/backup');
  }

  void _shield(int transparentBal) async {
    final protectSend = appSettings.protectSend;
    if (protectSend) {
      final authed = await authBarrier(context, dismissable: true);
      if (!authed) return;
    }

    // Deduct a generous fee buffer (20000 zatoshi = 0.0002 ZEC) so we
    // don't try to shield more than we can afford after ZIP-317 fees.
    const feeBuf = 20000;
    final amountToShield = transparentBal > feeBuf
        ? transparentBal - feeBuf
        : transparentBal;

    logger.i('[Shield] transparent=$transparentBal, '
        'amountToShield=$amountToShield, fee=${coinSettings.feeT.fee}');

    try {
      final plan = await WarpApi.transferPools(
        aa.coin,
        aa.id,
        1, // from: transparent (bitmask: 1=t, 2=sapling, 4=orchard)
        4, // to: orchard (most private pool)
        amountToShield,
        false,
        'Auto-shield via Zipher',
        0,
        appSettings.anchorOffset,
        coinSettings.feeT,
      );
      if (!mounted) return;
      await GoRouter.of(context)
          .push('/account/txplan?tab=account&shield=1', extra: plan);
      // User returned from shield flow — mark as submitted
      _lastShieldSubmit = DateTime.now();
      if (mounted) setState(() {});
    } on String catch (e) {
      logger.e('[Shield] Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e), duration: const Duration(seconds: 3)),
      );
    }
  }
}

// ─── Privacy meter ──────────────────────────────────────────

// ─── Shield nudge banner ────────────────────────────────────

class _ShieldNudge extends StatelessWidget {
  final int transparentBal;
  final int shieldedBal;
  final int totalBal;
  final VoidCallback onShield;

  const _ShieldNudge({
    required this.transparentBal,
    required this.shieldedBal,
    required this.totalBal,
    required this.onShield,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalBal > 0 ? (shieldedBal / totalBal).clamp(0.0, 1.0) : 1.0;
    final pctInt = (pct * 100).round();

    // Accent color shifts from red (0%) → orange (50%) → purple (near 100%)
    final Color accentColor;
    if (pct >= 0.8) {
      accentColor = ZipherColors.purple;
    } else if (pct >= 0.5) {
      accentColor = Color.lerp(
          ZipherColors.orange, ZipherColors.purple, (pct - 0.5) / 0.3)!;
    } else {
      accentColor =
          Color.lerp(const Color(0xFFEF4444), ZipherColors.orange, pct / 0.5)!;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onShield,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Shield icon
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      size: 17,
                      color: accentColor.withValues(alpha: 0.85),
                    ),
                  ),
                  const Gap(12),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shield your funds',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const Gap(2),
                        Text(
                          '${amountToString2(transparentBal)} ZEC exposed  ·  $pctInt% shielded',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Shield action
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Shield',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              // Mini progress bar
              const Gap(10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2.5),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                            color: accentColor.withValues(alpha: 0.20)),
                      ),
                      if (pct > 0)
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: pct,
                          child: Container(
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Fully Private badge (positive reinforcement) ───────────

class _FullyPrivateBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ZipherColors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ZipherColors.purple.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_rounded,
            size: 15,
            color: ZipherColors.purple.withValues(alpha: 0.7),
          ),
          const Gap(8),
          Text(
            'Fully private',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ZipherColors.purple.withValues(alpha: 0.7),
            ),
          ),
          const Gap(6),
          Text(
            '·  100% shielded',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shielding in progress banner ────────────────────────────

class _ShieldingInProgress extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ZipherColors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ZipherColors.purple.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ZipherColors.purple.withValues(alpha: 0.6),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shielding in progress',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ZipherColors.purple.withValues(alpha: 0.7),
                  ),
                ),
                const Gap(2),
                Text(
                  'Waiting for confirmation...',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action button (rounded rectangle) ──────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.8)),
              const Gap(8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Transaction row (home page — compact) ──────────────────

class _TxRow extends StatelessWidget {
  final Tx tx;
  final int index;
  const _TxRow({required this.tx, required this.index});

  @override
  Widget build(BuildContext context) {
    final isIncoming = tx.value > 0;
    final isShielding = tx.value <= 0 && (tx.address == null || tx.address!.isEmpty);
    final memo = tx.memo ?? '';
    final label = memo.isNotEmpty
        ? memo
        : isShielding
            ? 'Shielded'
            : isIncoming
                ? 'Received'
                : 'Sent';
    final timeStr = timeago.format(tx.timestamp);
    final amountStr = isShielding
        ? '${decimalToString(tx.value.abs())} ZEC'
        : '${isIncoming ? '+' : ''}${decimalToString(tx.value)} ZEC';
    final amountColor = isIncoming
        ? ZipherColors.green
        : isShielding
            ? ZipherColors.purple.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.6);

    // Fiat
    final price = marketPrice.price;
    final fiat = price != null ? '\$${(tx.value.abs() * price).toStringAsFixed(2)}' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => GoRouter.of(context).push('/history/details?index=$index'),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isShielding
                        ? Icons.shield_rounded
                        : isIncoming
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const Gap(2),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountStr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: amountColor,
                      ),
                    ),
                    if (fiat.isNotEmpty && !isShielding) ...[
                      const Gap(1),
                      Text(
                        fiat,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ACCOUNT SWITCHER BOTTOM SHEET
// ═══════════════════════════════════════════════════════════

class _AccountSwitcherSheet extends StatefulWidget {
  final VoidCallback onAccountChanged;
  const _AccountSwitcherSheet({required this.onAccountChanged});

  @override
  State<_AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends State<_AccountSwitcherSheet> {
  late List<Account> accounts;
  int? _editingIndex;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    accounts = getAllAccounts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: ZipherColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Gap(10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Accounts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _addAccount,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: ZipherColors.cyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 14,
                            color: ZipherColors.cyan.withValues(alpha: 0.7)),
                        const Gap(4),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ZipherColors.cyan.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.04)),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final a = accounts[index];
                final isActive = a.coin == aa.coin && a.id == aa.id;
                final isEditing = _editingIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isEditing ? null : () => _switchTo(a),
                      onLongPress: () => _startEditing(index, a),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? ZipherColors.cyan.withValues(alpha: 0.06)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isActive
                              ? Border.all(
                                  color: ZipherColors.cyan
                                      .withValues(alpha: 0.12))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? ZipherColors.cyan
                                        .withValues(alpha: 0.12)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  (a.name ?? '?')[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isActive
                                        ? ZipherColors.cyan
                                            .withValues(alpha: 0.8)
                                        : Colors.white
                                            .withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            ),
                            const Gap(12),
                            Expanded(
                              child: isEditing
                                  ? TextField(
                                      controller: _nameController,
                                      autofocus: true,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        filled: false,
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onSubmitted: (v) => _rename(a, v),
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a.name ?? 'Account',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white
                                                .withValues(alpha: 0.85),
                                          ),
                                        ),
                                        if (isActive)
                                          Text(
                                            'Active',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: ZipherColors.green
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                            Text(
                              '${_accountBalance(a)} ZEC',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            if (isEditing) ...[
                              const Gap(8),
                              GestureDetector(
                                onTap: () => _delete(a, index),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color:
                                      ZipherColors.red.withValues(alpha: 0.5),
                                ),
                              ),
                              const Gap(4),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _editingIndex = null),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color:
                                      Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Gap(12),
        ],
      ),
    );
  }

  String _accountBalance(Account a) {
    // For the active account, use live synced balance
    if (a.coin == aa.coin && a.id == aa.id) {
      final total = aa.poolBalances.transparent +
          aa.poolBalances.sapling +
          aa.poolBalances.orchard;
      return amountToString2(total);
    }
    return amountToString2(a.balance);
  }

  void _switchTo(Account a) {
    setActiveAccount(a.coin, a.id);
    Future(() async {
      final prefs = await SharedPreferences.getInstance();
      await aa.save(prefs);
    });
    aa.update(null);
    widget.onAccountChanged();
    Navigator.of(context).pop();
  }

  void _addAccount() async {
    Navigator.of(context).pop();
    await GoRouter.of(context).push('/more/account_manager/new');
    widget.onAccountChanged();
  }

  void _startEditing(int index, Account a) {
    _nameController.text = a.name ?? '';
    setState(() => _editingIndex = index);
  }

  void _rename(Account a, String name) {
    if (name.isNotEmpty) {
      WarpApi.updateAccountName(a.coin, a.id, name);
    }
    setState(() {
      _editingIndex = null;
      accounts = getAllAccounts();
    });
    if (a.coin == aa.coin && a.id == aa.id) {
      widget.onAccountChanged();
    }
  }

  void _delete(Account a, int index) async {
    final s = S.of(context);
    if (accounts.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete the only account'),
          backgroundColor: ZipherColors.surface,
        ),
      );
      return;
    }
    if (a.coin == aa.coin && a.id == aa.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.cannotDeleteActive),
          backgroundColor: ZipherColors.surface,
        ),
      );
      return;
    }
    final confirmed = await showConfirmDialog(
        context, s.deleteAccount(a.name!), s.confirmDeleteAccount);
    if (confirmed) {
      WarpApi.deleteAccount(a.coin, a.id);
      setState(() {
        _editingIndex = null;
        accounts = getAllAccounts();
      });
    }
  }
}
