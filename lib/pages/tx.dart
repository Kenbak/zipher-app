import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:warp_api/warp_api.dart';

import '../accounts.dart';
import '../appsettings.dart';
import '../zipher_theme.dart';
import '../generated/intl/messages.dart';
import '../store2.dart';
import '../tablelist.dart';
import 'utils.dart';

// ─── Helpers ────────────────────────────────────────────────

const _cipherScanBase = 'https://cipherscan.app';

void _openOnCipherScan(String txId) {
  launchUrl(
    Uri.parse('$_cipherScanBase/transaction/$txId'),
    mode: LaunchMode.externalApplication,
  );
}

String _fiatStr(double zecValue) {
  final price = marketPrice.price;
  if (price == null) return '';
  final fiat = zecValue.abs() * price;
  return decimalFormat(fiat, 2, symbol: appSettings.currency);
}

/// Human-readable date like "Dec 5 at 12:49 AM" or "Yesterday"
String _humanDate(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final txDay = DateTime(local.year, local.month, local.day);
  final timeFmt = DateFormat.jm(); // "12:49 AM"

  if (txDay == today) {
    return 'Today at ${timeFmt.format(local)}';
  } else if (txDay == yesterday) {
    return 'Yesterday at ${timeFmt.format(local)}';
  } else if (local.year == now.year) {
    return '${DateFormat.MMMd().format(local)} at ${timeFmt.format(local)}';
  } else {
    return '${DateFormat.yMMMd().format(local)} at ${timeFmt.format(local)}';
  }
}

/// Month group header: "February 2026", "December 2025", etc.
String _monthGroup(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final txDay = DateTime(local.year, local.month, local.day);

  if (txDay == today) return 'Today';
  if (txDay == yesterday) return 'Yesterday';
  return DateFormat.yMMMM().format(local); // "December 2025"
}

// ─── Privacy classification ─────────────────────────────────

enum _TxPrivacy { private, transparent, mixed }

_TxPrivacy _classifyTx(Tx tx) {
  final hasMemo = tx.memo?.isNotEmpty == true || tx.memos.isNotEmpty;
  final addr = tx.address ?? '';
  final isTransparentAddr = addr.startsWith('t');

  if (isTransparentAddr && !hasMemo) return _TxPrivacy.transparent;
  if (!isTransparentAddr && hasMemo) return _TxPrivacy.private;
  if (isTransparentAddr && hasMemo) return _TxPrivacy.mixed;
  return _TxPrivacy.private;
}

String _privacyLabel(_TxPrivacy p) {
  switch (p) {
    case _TxPrivacy.private:
      return 'Private';
    case _TxPrivacy.transparent:
      return 'Transparent';
    case _TxPrivacy.mixed:
      return 'Mixed';
  }
}

Color _privacyColor(_TxPrivacy p) {
  switch (p) {
    case _TxPrivacy.private:
      return ZipherColors.purple;
    case _TxPrivacy.transparent:
      return ZipherColors.cyan;
    case _TxPrivacy.mixed:
      return ZipherColors.orange;
  }
}

IconData _privacyIcon(_TxPrivacy p) {
  switch (p) {
    case _TxPrivacy.private:
      return Icons.shield_rounded;
    case _TxPrivacy.transparent:
      return Icons.visibility_outlined;
    case _TxPrivacy.mixed:
      return Icons.swap_vert_rounded;
  }
}

// ─── Invoice detection ──────────────────────────────────────

class _InvoiceData {
  final String reference;
  final String description;
  _InvoiceData({required this.reference, required this.description});
}

_InvoiceData? _parseInvoice(String? memo) {
  if (memo == null || memo.isEmpty) return null;
  final pattern = RegExp(r'^\[zipher:inv:([^\]]+)\]\s*(.*)$', dotAll: true);
  final match = pattern.firstMatch(memo);
  if (match == null) return null;
  return _InvoiceData(
    reference: match.group(1)!.trim(),
    description: match.group(2)?.trim() ?? '',
  );
}

// ─── Activity page ──────────────────────────────────────────

class TxPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => TxPageState();
}

class TxPageState extends State<TxPage> {
  @override
  void initState() {
    super.initState();
    syncStatus2.latestHeight?.let((height) {
      Future(() async {
        final txListUpdated =
            await WarpApi.transparentSync(aa.coin, aa.id, height);
        if (txListUpdated) aa.update(height);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: ZipherColors.bg,
      body: SortSetting(
        child: Observer(
          builder: (context) {
            aaSequence.seqno;
            aaSequence.settingsSeqno;
            syncStatus2.changed;
            final txs = aa.txs.items;

            if (txs.isEmpty) return _EmptyActivity();

            // Group txs by month
            final groups = <String, List<_IndexedTx>>{};
            for (var i = 0; i < txs.length; i++) {
              final key = _monthGroup(txs[i].timestamp);
              groups.putIfAbsent(key, () => []);
              groups[key]!.add(_IndexedTx(i, txs[i]));
            }

            return ListView.builder(
              padding: EdgeInsets.fromLTRB(0, topPad + 8, 0, 24),
              itemCount: _countItems(groups),
              itemBuilder: (context, i) =>
                  _buildGroupedItem(context, groups, i),
            );
          },
        ),
      ),
    );
  }

  int _countItems(Map<String, List<_IndexedTx>> groups) {
    int count = 0;
    for (final g in groups.values) {
      count += 1 + g.length; // header + items
    }
    return count;
  }

  Widget _buildGroupedItem(
      BuildContext context, Map<String, List<_IndexedTx>> groups, int index) {
    int cursor = 0;
    for (final entry in groups.entries) {
      if (index == cursor) {
        // Month header
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            entry.key,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 0.3,
            ),
          ),
        );
      }
      cursor++;
      if (index < cursor + entry.value.length) {
        final itx = entry.value[index - cursor];
        ZMessage? message;
        try {
          message =
              aa.messages.items.firstWhere((m) => m.txId == itx.tx.id);
        } on StateError {
          message = null;
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _TxRow(tx: itx.tx, message: message, index: itx.index),
        );
      }
      cursor += entry.value.length;
    }
    return const SizedBox.shrink();
  }
}

class _IndexedTx {
  final int index;
  final Tx tx;
  _IndexedTx(this.index, this.tx);
}

// ─── Empty state ────────────────────────────────────────────

class _EmptyActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 28,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            const Gap(16),
            Text(
              'No activity yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const Gap(6),
            Text(
              'Your transactions will appear here',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Transaction row (Zashi-inspired) ───────────────────────

class _TxRow extends StatelessWidget {
  final Tx tx;
  final ZMessage? message;
  final int index;

  const _TxRow(
      {required this.tx, required this.message, required this.index});

  @override
  Widget build(BuildContext context) {
    final isReceive = tx.value > 0;
    final privacy = _classifyTx(tx);
    final pColor = _privacyColor(privacy);

    // Label: "Received", "Sent", "Shielded" (for self-transfers)
    final String label;
    if (tx.value == 0) {
      label = 'Shielded';
    } else if (isReceive) {
      label = 'Received';
    } else {
      label = 'Sent';
    }

    final dateStr = _humanDate(tx.timestamp);
    final amountStr =
        '${isReceive ? '+' : ''}${decimalToString(tx.value)} ZEC';
    final amountColor = isReceive
        ? ZipherColors.green
        : Colors.white.withValues(alpha: 0.6);
    final fiat = _fiatStr(tx.value);

    return GestureDetector(
      onTap: () => gotoTx(context, index),
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            // Direction icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isReceive
                    ? Icons.arrow_downward_rounded
                    : tx.value == 0
                        ? Icons.shield_rounded
                        : Icons.arrow_upward_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const Gap(12),

            // Label + privacy badge + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const Gap(6),
                      // Privacy indicator (small dot + label)
                      Icon(
                        _privacyIcon(privacy),
                        size: 12,
                        color: pColor.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  const Gap(2),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
            ),

            // Amount + fiat
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountStr,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
                if (fiat.isNotEmpty)
                  Text(
                    fiat,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.2),
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

// ─── TableList metadata (kept for data table view) ──────────

class TableListTxMetadata extends TableListItemMetadata<Tx> {
  @override
  List<Widget>? actions(BuildContext context) => null;

  @override
  Text? headerText(BuildContext context) => null;

  @override
  void inverseSelection() {}

  @override
  Widget toListTile(BuildContext context, int index, Tx tx,
      {void Function(void Function())? setState}) {
    ZMessage? message;
    try {
      message = aa.messages.items.firstWhere((m) => m.txId == tx.id);
    } on StateError {
      message = null;
    }
    return _TxRow(tx: tx, message: message, index: index);
  }

  @override
  List<ColumnDefinition> columns(BuildContext context) {
    final s = S.of(context);
    return [
      ColumnDefinition(field: 'height', label: s.height, numeric: true),
      ColumnDefinition(
          field: 'confirmations', label: s.confs, numeric: true),
      ColumnDefinition(field: 'timestamp', label: s.datetime),
      ColumnDefinition(field: 'value', label: s.amount),
      ColumnDefinition(field: 'fullTxId', label: s.txID),
      ColumnDefinition(field: 'address', label: s.address),
      ColumnDefinition(field: 'memo', label: s.memo),
    ];
  }

  @override
  DataRow toRow(BuildContext context, int index, Tx tx) {
    final t = Theme.of(context);
    final color = amountColor(context, tx.value);
    var style = t.textTheme.bodyMedium!.copyWith(color: color);
    style = weightFromAmount(style, tx.value);
    final a = tx.contact ?? centerTrim(tx.address ?? '');
    final m = tx.memo?.let((m) => m.substring(0, min(m.length, 32))) ?? '';

    return DataRow.byIndex(
        index: index,
        cells: [
          DataCell(Text("${tx.height}")),
          DataCell(Text("${tx.confirmations}")),
          DataCell(Text("${txDateFormat.format(tx.timestamp)}")),
          DataCell(Text(decimalToString(tx.value),
              style: style, textAlign: TextAlign.left)),
          DataCell(Text("${tx.txId}")),
          DataCell(Text("$a")),
          DataCell(Text("$m")),
        ],
        onSelectChanged: (_) => gotoTx(context, index));
  }

  @override
  SortConfig2? sortBy(String field) {
    aa.txs.setSortOrder(field);
    return aa.txs.order;
  }

  @override
  Widget? header(BuildContext context) => null;
}

// ─── Transaction detail page ────────────────────────────────

class TransactionPage extends StatefulWidget {
  final int txIndex;
  TransactionPage(this.txIndex);

  @override
  State<StatefulWidget> createState() => TransactionState();
}

class TransactionState extends State<TransactionPage> {
  late final s = S.of(context);
  late int idx;

  @override
  void initState() {
    super.initState();
    idx = widget.txIndex;
  }

  Tx get tx => aa.txs.items[idx];

  @override
  Widget build(BuildContext context) {
    final isReceive = tx.value > 0;
    final isSelfTransfer = tx.value == 0;
    final privacy = _classifyTx(tx);
    final pColor = _privacyColor(privacy);
    final amountColor =
        isReceive ? ZipherColors.green : Colors.white.withValues(alpha: 0.85);
    final invoice = _parseInvoice(tx.memo);
    final fiat = _fiatStr(tx.value);

    final String directionLabel;
    if (isSelfTransfer) {
      directionLabel = 'Shielded';
    } else if (isReceive) {
      directionLabel = 'Received';
    } else {
      directionLabel = 'Sent';
    }

    return Scaffold(
      backgroundColor: ZipherColors.bg,
      appBar: AppBar(
        backgroundColor: ZipherColors.bg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => GoRouter.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(8),

              // ── Hero: direction label + arrow with amount ──
              Center(
                child: Column(
                  children: [
                    Text(
                      directionLabel,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const Gap(8),
                    // Arrow + amount on same line
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSelfTransfer
                                ? Icons.shield_rounded
                                : isReceive
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        const Gap(12),
                        Text(
                          '${isReceive ? '' : '- '}${decimalToString(tx.value.abs())} ZEC',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: amountColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    if (fiat.isNotEmpty) ...[
                      const Gap(4),
                      Text(
                        fiat,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Gap(28),

              // ── Memo / Message section ──
              if (invoice != null) ...[
                _SectionHeader(label: 'Invoice'),
                const Gap(8),
                _InvoiceCard(invoice: invoice),
                const Gap(20),
              ] else if (tx.memo?.isNotEmpty ?? false) ...[
                _SectionHeader(label: 'Message'),
                const Gap(8),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tx.memo!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                ),
                const Gap(20),
              ],

              // ── Transaction Details (always visible) ──
              _SectionHeader(label: 'Transaction Details'),
              const Gap(8),
              _buildDetails(isReceive, privacy, pColor),

              // Additional memos
              ..._memos(),

              const Gap(24),

              // ── View on CipherScan ──
              SizedBox(
                width: double.infinity,
                child: _BottomAction(
                  label: 'View on CipherScan',
                  icon: Icons.open_in_new_rounded,
                  onTap: () => _openOnCipherScan(tx.fullTxId),
                ),
              ),

              const Gap(32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(
      bool isReceive, _TxPrivacy privacy, Color pColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _DetailRow(
            label: 'Privacy',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_privacyIcon(privacy),
                    size: 13, color: pColor.withValues(alpha: 0.7)),
                const Gap(4),
                Text(
                  _privacyLabel(privacy),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: pColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          _detailDivider(),

          if (tx.confirmations != null) ...[
            _DetailRow(
              label: 'Status',
              child: Text(
                tx.confirmations! >= 10
                    ? 'Confirmed'
                    : '${tx.confirmations} confirmations',
                style: TextStyle(
                  fontSize: 13,
                  color: tx.confirmations! >= 10
                      ? ZipherColors.green.withValues(alpha: 0.8)
                      : ZipherColors.orange.withValues(alpha: 0.8),
                ),
              ),
            ),
            _detailDivider(),
          ],

          if (tx.address?.isNotEmpty ?? false) ...[
            _DetailRow(
              label: isReceive ? 'From' : 'Sent to',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      isReceive
                          ? (tx.address!.startsWith('t')
                              ? centerTrim(tx.address!)
                              : 'Shielded sender')
                          : (tx.contact ?? centerTrim(tx.address!)),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const Gap(6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: tx.address!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Address copied'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Icon(Icons.copy_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.2)),
                  ),
                ],
              ),
            ),
            _detailDivider(),
          ],

          _DetailRow(
            label: 'Transaction ID',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    centerTrim(tx.fullTxId, length: 16),
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const Gap(6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: tx.fullTxId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('TX ID copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Icon(Icons.copy_rounded,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.2)),
                ),
              ],
            ),
          ),
          _detailDivider(),

          _DetailRow(
            label: 'Timestamp',
            child: Text(
              _humanDate(tx.timestamp),
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Divider(
            height: 1, color: Colors.white.withValues(alpha: 0.04)),
      );

  List<Widget> _memos() {
    List<Widget> ms = [];
    for (var txm in tx.memos) {
      ms.add(const Gap(8));
      ms.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              centerTrim(txm.address),
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            const Gap(4),
            Text(
              txm.memo,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ],
        ),
      ));
    }
    return ms;
  }
}

// ─── Shared widgets ─────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.4),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _DetailRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          const Spacer(),
          child,
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _BottomAction(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: ZipherColors.cyan.withValues(alpha: 0.7)),
              const Gap(8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: ZipherColors.cyan.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final _InvoiceData invoice;
  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZipherColors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: ZipherColors.purple.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: ZipherColors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.receipt_outlined,
                size: 15,
                color: ZipherColors.purple.withValues(alpha: 0.8)),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Invoice',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ZipherColors.purple.withValues(alpha: 0.7),
                      ),
                    ),
                    const Gap(6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: ZipherColors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '#${invoice.reference}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'monospace',
                          color: ZipherColors.purple
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                if (invoice.description.isNotEmpty) ...[
                  const Gap(2),
                  Text(
                    invoice.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void gotoTx(BuildContext context, int index) {
  GoRouter.of(context).push('/history/details?index=$index');
}
