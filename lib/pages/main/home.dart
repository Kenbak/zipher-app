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
import '../tx.dart' show getShieldAmount;
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

/// Set by submit page when a shield transaction is successfully broadcast.
/// Cleared when transparent balance reaches 0 (shield confirmed).
DateTime? lastShieldSubmit;

/// Set to true when a shield flow is started, so submit page knows to mark it.
bool shieldPending = false;

class _HomeState extends State<HomePageInner> {
  bool _balanceHidden = false;

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
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 420,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -1.0),
                        radius: 1.3,
                        colors: [
                          ZipherColors.purple.withValues(alpha: 0.12),
                          ZipherColors.cyan.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
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
                        ],
                      ),
                    ),
                  ),
                ),

                // Balance breakdown — shielded / transparent split
                if (totalBal > 0 && !_balanceHidden)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Builder(builder: (_) {
                        // Clear shield flag when transparent reaches 0
                        if (transparentBal == 0 && lastShieldSubmit != null) {
                          lastShieldSubmit = null;
                        }
                        final shieldingInProgress = lastShieldSubmit != null &&
                            DateTime.now()
                                    .difference(lastShieldSubmit!)
                                    .inMinutes <
                                10;
                        return _BalanceBreakdown(
                          shieldedBal: shieldedBal,
                          transparentBal: transparentBal,
                          shieldingInProgress: shieldingInProgress,
                          onShield: () => _shield(transparentBal),
                        );
                      }),
                    ),
                  ),

                // Action buttons
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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

    final amtStr = amountToString2(transparentBal);
    logger.i('[Shield] transparent=$transparentBal ($amtStr ZEC), fee=${coinSettings.feeT.fee}');

    try {
      final plan = await WarpApi.transferPools(
        aa.coin,
        aa.id,
        1, // from: transparent (bitmask: 1=t, 2=sapling, 4=orchard)
        4, // to: orchard (most private pool)
        transparentBal,
        true, // includeFee: deduct fee from amount so everything is swept
        'Auto-shield $amtStr ZEC',
        0,
        appSettings.anchorOffset,
        coinSettings.feeT,
      );
      if (!mounted) return;
      shieldPending = true;
      GoRouter.of(context)
          .push('/account/txplan?tab=account&shield=1', extra: plan);
    } on String catch (e) {
      logger.e('[Shield] Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e), duration: const Duration(seconds: 3)),
      );
    }
  }
}

// ─── Balance breakdown (Hybrid: Actionable + Health Meter) ───

class _BalanceBreakdown extends StatelessWidget {
  final int shieldedBal;
  final int transparentBal;
  final bool shieldingInProgress;
  final VoidCallback onShield;

  const _BalanceBreakdown({
    required this.shieldedBal,
    required this.transparentBal,
    required this.shieldingInProgress,
    required this.onShield,
  });

  @override
  Widget build(BuildContext context) {
    final totalBal = shieldedBal + transparentBal;
    final isFullyShielded = transparentBal == 0;
    final pct =
        totalBal > 0 ? (shieldedBal / totalBal).clamp(0.0, 1.0) : 1.0;

    // Consistent purple for bar, button, and shield icons
    const barColor = ZipherColors.purple;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(
              children: [
                // Shielded row
                Row(
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      size: 15,
                      color: isFullyShielded
                          ? ZipherColors.purple.withValues(alpha: 0.7)
                          : ZipherColors.purple.withValues(alpha: 0.5),
                    ),
                    const Gap(8),
                    Text(
                      'Shielded',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${amountToString2(shieldedBal)} ZEC',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isFullyShielded
                            ? ZipherColors.purple.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),

                if (!isFullyShielded) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),

                  // Transparent row with shield action
                  Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 15,
                        color: ZipherColors.orange.withValues(alpha: 0.6),
                      ),
                      const Gap(8),
                      Text(
                        'Transparent',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      const Spacer(),
                      if (shieldingInProgress) ...[
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color:
                                ZipherColors.purple.withValues(alpha: 0.5),
                          ),
                        ),
                        const Gap(8),
                        Text(
                          'Shielding...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: ZipherColors.purple
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ] else ...[
                        Text(
                          '${amountToString2(transparentBal)} ZEC',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                ZipherColors.orange.withValues(alpha: 0.7),
                          ),
                        ),
                        const Gap(10),
                        // Premium Shield button
                        GestureDetector(
                          onTap: onShield,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: ZipherColors.purple
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  size: 12,
                                  color: ZipherColors.purple
                                      .withValues(alpha: 0.85),
                                ),
                                const Gap(5),
                                Text(
                                  'Shield',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: ZipherColors.purple
                                        .withValues(alpha: 0.85),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  // Fully shielded — subtle positive note
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 13,
                          color:
                              ZipherColors.purple.withValues(alpha: 0.45),
                        ),
                        const Gap(6),
                        Text(
                          'Fully private',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: ZipherColors.purple
                                .withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Privacy health bar — thin strip at card bottom
          const Gap(12),
          SizedBox(
            height: 3,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: barColor.withValues(alpha: 0.10),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(2),
                          bottomRight: Radius.circular(2),
                        ),
                      ),
                    ),
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

class _TxRow extends StatefulWidget {
  final Tx tx;
  final int index;
  const _TxRow({required this.tx, required this.index});

  @override
  State<_TxRow> createState() => _TxRowState();
}

class _TxRowState extends State<_TxRow> {
  Tx get tx => widget.tx;
  int get index => widget.index;

  @override
  Widget build(BuildContext context) {
    final isIncoming = tx.value > 0;
    final memo = tx.memo ?? '';
    // Detect shielding: self-transfer (no address) or our auto-shield memo
    final isShielding = (tx.value <= 0 &&
            (tx.address == null || tx.address!.isEmpty)) ||
        memo.contains('Auto-shield');

    final String label;
    if (isShielding) {
      label = 'Shielded';
    } else if (memo.isNotEmpty) {
      label = memo;
    } else if (isIncoming) {
      label = 'Received';
    } else {
      label = 'Sent';
    }

    final timeStr = timeago.format(tx.timestamp);

    // For shielding, try memo first, then CipherScan as fallback
    double? shieldedAmount;
    if (isShielding) {
      final match = RegExp(r'Auto-shield ([\d.,]+) ZEC').firstMatch(memo);
      if (match != null) {
        shieldedAmount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
      }
      shieldedAmount ??= getShieldAmount(tx.fullTxId,
          onLoaded: () { if (mounted) setState(() {}); });
    }

    final String amountStr;
    if (isShielding && shieldedAmount != null) {
      amountStr = '${decimalToString(shieldedAmount)} ZEC';
    } else if (isShielding) {
      amountStr = '···';
    } else {
      amountStr = '${isIncoming ? '+' : ''}${decimalToString(tx.value)} ZEC';
    }

    final amountColor = isIncoming
        ? ZipherColors.green
        : isShielding
            ? ZipherColors.purple.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.6);

    // Fiat
    final price = marketPrice.price;
    final fiatValue = isShielding && shieldedAmount != null
        ? shieldedAmount
        : tx.value.abs();
    final fiat = price != null
        ? '\$${(fiatValue * price).toStringAsFixed(2)}'
        : '';

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
                    color: isShielding
                        ? ZipherColors.purple.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isShielding
                        ? Icons.shield_rounded
                        : isIncoming
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                    size: 16,
                    color: isShielding
                        ? ZipherColors.purple.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.4),
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
                    if (fiat.isNotEmpty) ...[
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
