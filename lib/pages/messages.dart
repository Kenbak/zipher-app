import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../zipher_theme.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:warp_api/warp_api.dart';

import '../store2.dart';
import '../accounts.dart';
import '../appsettings.dart';
import '../generated/intl/messages.dart';
import '../tablelist.dart';
import '../../pages/accounts/send.dart';
import 'avatar.dart';
import 'utils.dart';

// ─── Messages list page ─────────────────────────────────────

class MessagePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        aaSequence.seqno;
        aaSequence.settingsSeqno;
        syncStatus2.changed;
        final items = aa.messages.items;

        if (items.isEmpty) {
          return _EmptyMessages();
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.04),
            indent: 64,
          ),
          itemBuilder: (context, index) {
            final msg = items[index];
            return _MessageRow(msg, index: index);
          },
        );
      },
    );
  }
}

// ─── Empty state ────────────────────────────────────────────

class _EmptyMessages extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mail_outline_rounded,
              size: 56,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const Gap(16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const Gap(8),
            Text(
              'Encrypted memos attached to\nshielded transactions appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.25),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Message row ────────────────────────────────────────────

class _MessageRow extends StatelessWidget {
  final ZMessage message;
  final int index;

  const _MessageRow(this.message, {required this.index});

  @override
  Widget build(BuildContext context) {
    final contact = message.incoming ? message.sender : message.recipient;
    final initial =
        (contact == null || contact.isEmpty) ? '?' : contact[0].toUpperCase();
    final date = humanizeDateTime(context, message.timestamp);
    final isUnread = !message.read;

    return GestureDetector(
      onTap: () =>
          GoRouter.of(context).push('/messages/details?index=$index'),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: initialToColor(initial).withValues(alpha: 0.15),
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: initialToColor(initial),
                ),
              ),
            ),
            const Gap(12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: address + date
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          centerTrim(contact ?? '?', length: 10),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isUnread ? FontWeight.w600 : FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.incoming)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.arrow_downward_rounded,
                                  size: 12, color: ZipherColors.green),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.arrow_upward_rounded,
                                  size: 12, color: ZipherColors.cyan),
                            ),
                          Text(
                            date,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Subject
                  if (message.subject.isNotEmpty) ...[
                    const Gap(3),
                    Text(
                      message.subject,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isUnread ? FontWeight.w600 : FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Body preview
                  if (message.body.isNotEmpty) ...[
                    const Gap(3),
                    Text(
                      message.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Unread dot
            if (isUnread)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: ZipherColors.cyan,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Message detail page ────────────────────────────────────

class MessageItemPage extends StatefulWidget {
  final int index;
  MessageItemPage(this.index);

  @override
  State<StatefulWidget> createState() => _MessageItemState();
}

class _MessageItemState extends State<MessageItemPage> {
  late int idx;
  late final n;

  ZMessage get message => aa.messages.items[idx];

  void initState() {
    n = aa.messages.items.length;
    idx = widget.index;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ts = msgDateFormatFull.format(message.timestamp);
    final contact = message.incoming ? message.sender : message.recipient;
    final initial =
        (contact == null || contact.isEmpty) ? '?' : contact[0].toUpperCase();

    return Scaffold(
      backgroundColor: ZipherColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          message.subject.isNotEmpty ? message.subject : 'Message',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ZipherColors.textPrimary,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: ZipherColors.textSecondary),
        actions: [
          // Thread navigation
          IconButton(
            onPressed: prevInThread,
            icon: Icon(Icons.chevron_left_rounded,
                size: 22, color: Colors.white.withValues(alpha: 0.3)),
          ),
          IconButton(
            onPressed: nextInThread,
            icon: Icon(Icons.chevron_right_rounded,
                size: 22, color: Colors.white.withValues(alpha: 0.3)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Gap(8),

                  // ── Sender info card ─────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ZipherColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              initialToColor(initial).withValues(alpha: 0.15),
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: initialToColor(initial),
                            ),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    message.incoming
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    size: 14,
                                    color: message.incoming
                                        ? ZipherColors.green
                                        : ZipherColors.cyan,
                                  ),
                                  const Gap(4),
                                  Text(
                                    message.incoming ? 'From' : 'To',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.35),
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(2),
                              Text(
                                centerTrim(contact ?? '?', length: 16),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              ts,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            const Gap(4),
                            GestureDetector(
                              onTap: () => _openTx(context),
                              child: Text(
                                'View tx',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      ZipherColors.cyan.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Gap(20),

                  // ── Subject ──────────────────────────
                  if (message.subject.isNotEmpty) ...[
                    Text(
                      message.subject,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const Gap(16),
                  ],

                  // ── Message body ─────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: message.incoming
                          ? ZipherColors.surface
                          : ZipherColors.cyan.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: message.incoming
                            ? Colors.white.withValues(alpha: 0.05)
                            : ZipherColors.cyan.withValues(alpha: 0.1),
                      ),
                    ),
                    child: SelectableText(
                      message.body,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),

                  const Gap(12),

                  // ── Copy body button ─────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: message.body));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.25)),
                          const Gap(4),
                          Text(
                            'Copy message',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Gap(24),

                  // ── Nav: prev/next messages ──────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _NavButton(
                        icon: Icons.chevron_left_rounded,
                        label: 'Prev',
                        onTap: idx > 0 ? prev : null,
                      ),
                      const Gap(16),
                      Text(
                        '${idx + 1} / $n',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      const Gap(16),
                      _NavButton(
                        icon: Icons.chevron_right_rounded,
                        label: 'Next',
                        onTap: idx < n - 1 ? next : null,
                      ),
                    ],
                  ),

                  const Gap(24),
                ],
              ),
            ),
          ),

          // ── Reply button ─────────────────────────
          if (message.fromAddress?.isNotEmpty == true)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _reply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZipherColors.cyan,
                      foregroundColor: ZipherColors.bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.reply_rounded, size: 18),
                        Gap(8),
                        Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────

  prev() {
    if (idx > 0) idx -= 1;
    setState(() {});
  }

  next() {
    if (idx < n - 1) idx += 1;
    setState(() {});
  }

  prevInThread() {
    final pn = WarpApi.getPrevNextMessage(
        aa.coin, aa.id, message.subject, message.height);
    final id = pn.prev;
    if (id != 0) idx = aa.messages.items.indexWhere((m) => m.id == id);
    setState(() {});
  }

  nextInThread() {
    final pn = WarpApi.getPrevNextMessage(
        aa.coin, aa.id, message.subject, message.height);
    final id = pn.next;
    if (id != 0) idx = aa.messages.items.indexWhere((m) => m.id == id);
    setState(() {});
  }

  _reply() {
    final memo = MemoData(true, message.subject, '');
    final sc = SendContext(message.fromAddress!, 7, Amount(0, false), memo);
    GoRouter.of(context).go('/account/quick_send', extra: sc);
  }

  _openTx(BuildContext context) {
    final index = aa.txs.items.indexWhere((tx) => tx.id == message.txId);
    if (index >= 0) {
      GoRouter.of(context).push('/history/details?index=$index');
    }
  }
}

// ─── Small nav button ───────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.white.withValues(alpha: enabled ? 0.4 : 0.1),
            ),
            const Gap(4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: enabled ? 0.4 : 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Legacy widgets kept for compatibility ──────────────────

class MessageBubble extends StatelessWidget {
  final ZMessage message;
  final int index;
  MessageBubble(this.message, {required this.index});

  @override
  Widget build(BuildContext context) {
    return _MessageRow(message, index: index);
  }

  select(BuildContext context) {
    GoRouter.of(context).push('/messages/details?index=$index');
  }
}

class MessageTile extends StatelessWidget {
  final ZMessage message;
  final int index;
  final double? width;

  MessageTile(this.message, this.index, {this.width});

  @override
  Widget build(BuildContext context) {
    return _MessageRow(message, index: index);
  }
}

class TableListMessageMetadata extends TableListItemMetadata<ZMessage> {
  @override
  List<Widget>? actions(BuildContext context) => null;

  @override
  Text? headerText(BuildContext context) => null;

  @override
  void inverseSelection() {}

  @override
  Widget toListTile(BuildContext context, int index, ZMessage message,
      {void Function(void Function())? setState}) {
    return _MessageRow(message, index: index);
  }

  @override
  List<ColumnDefinition> columns(BuildContext context) {
    final s = S.of(context);
    return [
      ColumnDefinition(label: s.datetime),
      ColumnDefinition(label: s.fromto),
      ColumnDefinition(label: s.subject),
      ColumnDefinition(label: s.body),
    ];
  }

  @override
  DataRow toRow(BuildContext context, int index, ZMessage message) {
    final t = Theme.of(context);
    var style = t.textTheme.bodyMedium!;
    if (!message.read) style = style.copyWith(fontWeight: FontWeight.bold);
    final addressStyle = message.incoming
        ? style.apply(color: ZipherColors.green)
        : style.apply(color: ZipherColors.red);
    return DataRow.byIndex(
        index: index,
        cells: [
          DataCell(
              Text("${msgDateFormat.format(message.timestamp)}", style: style)),
          DataCell(Text("${message.fromto()}", style: addressStyle)),
          DataCell(Text("${message.subject}", style: style)),
          DataCell(Text("${message.body}", style: style)),
        ],
        onSelectChanged: (_) {
          GoRouter.of(context).push('/messages/details?index=$index');
        });
  }

  @override
  SortConfig2? sortBy(String field) {
    aa.messages.setSortOrder(field);
    return aa.messages.order;
  }

  @override
  Widget? header(BuildContext context) => null;
}
