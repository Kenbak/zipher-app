import 'dart:async';

import 'package:YWallet/appsettings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../accounts.dart';
import '../../zipher_theme.dart';
import '../../coin/coins.dart';
import '../../generated/intl/messages.dart';
import '../../src/version.dart';
import '../utils.dart';

// ═══════════════════════════════════════════════════════════
// SETTINGS HUB (bottom tab)
// ═══════════════════════════════════════════════════════════

class MorePage extends StatefulWidget {
  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: ZipherColors.bg,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(topPad + 20),

              // Title
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const Gap(24),

              // ── General ──
              _sectionLabel('General'),
              const Gap(8),
              _card([
                _SettingsItem(
                  icon: Icons.tune_rounded,
                  label: 'Preferences',
                  subtitle: 'Currency, memo, server, sync',
                  onTap: () => GoRouter.of(context).push('/settings'),
                ),
              ]),
              const Gap(16),

              // ── Contacts ──
              _sectionLabel('Address Book'),
              const Gap(8),
              _card([
                _SettingsItem(
                  icon: Icons.people_outline_rounded,
                  iconColor: ZipherColors.cyan,
                  label: s.contacts,
                  subtitle: 'Manage saved addresses',
                  onTap: () => _nav('/more/contacts'),
                ),
              ]),
              const Gap(16),

              // ── Advanced ──
              _sectionLabel('Advanced'),
              const Gap(8),
              _card([
                _SettingsItem(
                  icon: Icons.build_outlined,
                  label: 'Advanced Settings',
                  subtitle: 'Keys, accounts, sync tools',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _AdvancedSettingsPage(),
                    ),
                  ),
                ),
              ]),
              const Gap(16),

              // ── About ──
              _sectionLabel('About'),
              const Gap(8),
              _card([
                _SettingsItem(
                  icon: Icons.info_outline_rounded,
                  label: 'About Zipher',
                  subtitle: 'Version & disclaimer',
                  onTap: () async {
                    final content =
                        await rootBundle.loadString('assets/about.md');
                    if (!mounted) return;
                    GoRouter.of(context)
                        .push('/more/about', extra: content);
                  },
                ),
              ]),

              // Version footer
              const Gap(32),
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/zipher_logo.png',
                      width: 28,
                      height: 28,
                      opacity: const AlwaysStoppedAnimation(0.15),
                    ),
                    const Gap(8),
                    Text(
                      'Zipher',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    const Gap(2),
                    Text(
                      'by CipherScan',
                      style: TextStyle(
                        fontSize: 11,
                        color: ZipherColors.cyan.withValues(alpha: 0.12),
                      ),
                    ),
                    const Gap(2),
                    Text(
                      'v$packageVersion',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Colors.white.withValues(alpha: 0.25),
      ),
    );
  }

  Widget _card(List<_SettingsItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.04),
                indent: 52,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }

  void _nav(String url) async {
    await GoRouter.of(context).push(url);
  }
}

// ═══════════════════════════════════════════════════════════
// ADVANCED SETTINGS PAGE
// ═══════════════════════════════════════════════════════════

class _AdvancedSettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Scaffold(
      backgroundColor: ZipherColors.bg,
      appBar: AppBar(
        backgroundColor: ZipherColors.bg,
        elevation: 0,
        title: Text(
          'ADVANCED',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: Colors.white.withValues(alpha: 0.5)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Security ──
            _sectionLabel('Security'),
            const Gap(8),
            _card(context, [
              _SettingsItem(
                icon: Icons.key_rounded,
                iconColor: ZipherColors.orange,
                label: s.seedKeys,
                subtitle: 'Export seed phrase & keys',
                onTap: () => _navSecured(context, '/more/backup'),
              ),
            ]),
            const Gap(16),

            // ── Tools ──
            _sectionLabel('Tools'),
            const Gap(8),
            _card(context, [
              _SettingsItem(
                icon: Icons.cleaning_services_outlined,
                label: s.sweep,
                subtitle: 'Import funds from a key',
                onTap: () => GoRouter.of(context).push('/more/sweep'),
              ),
              _SettingsItem(
                icon: Icons.sync_rounded,
                label: 'Recover Transactions',
                subtitle: 'Re-sync if balance looks wrong',
                onTap: () => GoRouter.of(context).push('/more/rescan'),
              ),
              _SettingsItem(
                icon: Icons.cloud_download_outlined,
                label: s.appData,
                subtitle: 'Backup & restore app data',
                onTap: () => _navSecured(context, '/more/batch_backup'),
              ),
            ]),

            const Gap(28),

            // ── Danger Zone ──
            _sectionLabel('Danger Zone'),
            const Gap(8),
            InkWell(
              onTap: () => _resetApp(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: ZipherColors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: ZipherColors.red.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded,
                        size: 18,
                        color: ZipherColors.red.withValues(alpha: 0.5)),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reset App',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: ZipherColors.red
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                          const Gap(1),
                          Text(
                            'Delete all data and start fresh',
                            style: TextStyle(
                              fontSize: 11,
                              color: ZipherColors.red
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Gap(40),
          ],
        ),
      ),
    );
  }

  void _resetApp(BuildContext context) async {
    final s = S.of(context);
    // First confirmation
    final confirm1 = await showConfirmDialog(
      context,
      'Reset App',
      'This will delete ALL accounts, keys, and settings. '
          'Make sure you have backed up your seed phrase before continuing.',
    );
    if (!confirm1) return;

    // Second confirmation
    final confirm2 = await showConfirmDialog(
      context,
      'Are you sure?',
      'This action is permanent and cannot be undone. '
          'All your data will be erased.',
    );
    if (!confirm2) return;

    // Wipe everything
    try {
      for (final c in coins) {
        await c.delete();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    // Go back to welcome screen
    if (context.mounted) {
      GoRouter.of(context).go('/welcome');
    }
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Colors.white.withValues(alpha: 0.25),
      ),
    );
  }

  Widget _card(BuildContext context, List<_SettingsItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.04),
                indent: 52,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }

  void _navSecured(BuildContext context, String url) async {
    final s = S.of(context);
    final auth = await authenticate(context, s.secured);
    if (!auth) return;
    GoRouter.of(context).push(url);
  }

}

// ═══════════════════════════════════════════════════════════
// SETTINGS ITEM WIDGET
// ═══════════════════════════════════════════════════════════

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    this.iconColor = const Color(0x66FFFFFF),
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const Gap(1),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.12)),
            ],
          ),
        ),
      ),
    );
  }
}
