import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warp_api/warp_api.dart';

import '../../accounts.dart';
import '../../coin/coins.dart';
import '../../store2.dart';
import '../../zipher_theme.dart';

/// Seed phrase restore — single-page flow with optional wallet birthday.
class RestoreAccountPage extends StatefulWidget {
  @override
  State<RestoreAccountPage> createState() => _RestoreAccountPageState();
}

class _RestoreAccountPageState extends State<RestoreAccountPage> {
  final _seedController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  // Wallet birthday
  DateTime? _selectedDate;
  bool _showDatePicker = false;

  static final _sapling = activationDate; // Oct 2018

  @override
  void dispose() {
    _seedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZipherColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Gap(16),
                    // Back
                    IconButton(
                      onPressed: () => GoRouter.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: ZipherColors.cyan, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: ZipherColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const Gap(32),
                    // Icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: ZipherColors.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.restore_outlined,
                          color: ZipherColors.cyan, size: 28),
                    ),
                    const Gap(20),
                    // Title
                    const Text(
                      'Restore Wallet',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: ZipherColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      'Enter your seed phrase to restore an existing Zcash wallet.',
                      style: TextStyle(
                        fontSize: 15,
                        color: ZipherColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const Gap(28),

                    // ── Seed input ──
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _seedController,
                        maxLines: 4,
                        style: const TextStyle(
                          fontSize: 16,
                          color: ZipherColors.textPrimary,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'word1 word2 word3 ...',
                          hintStyle: TextStyle(
                            color:
                                ZipherColors.textMuted.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: ZipherColors.surface,
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(ZipherRadius.md),
                            borderSide:
                                const BorderSide(color: ZipherColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(ZipherRadius.md),
                            borderSide:
                                const BorderSide(color: ZipherColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(ZipherRadius.md),
                            borderSide:
                                const BorderSide(color: ZipherColors.cyan),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(ZipherRadius.md),
                            borderSide:
                                const BorderSide(color: ZipherColors.red),
                          ),
                        ),
                        validator: _validateSeed,
                      ),
                    ),

                    if (_error != null) ...[
                      const Gap(12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: ZipherColors.red,
                          fontSize: 13,
                        ),
                      ),
                    ],

                    const Gap(8),
                    // Seed hint
                    Text(
                      'Supports 12, 15, 18, 21, or 24 word seed phrases.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),

                    const Gap(24),

                    // ── Wallet birthday section ──
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showDatePicker = !_showDatePicker),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: ZipherColors.surface,
                          borderRadius:
                              BorderRadius.circular(ZipherRadius.md),
                          border: Border.all(color: ZipherColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: _selectedDate != null
                                  ? ZipherColors.cyan
                                  : Colors.white.withValues(alpha: 0.35),
                            ),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Wallet birthday',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const Gap(2),
                                  Text(
                                    _selectedDate != null
                                        ? DateFormat.yMMMd()
                                            .format(_selectedDate!)
                                        : 'Optional — speeds up scanning',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedDate != null
                                          ? ZipherColors.cyan
                                              .withValues(alpha: 0.7)
                                          : Colors.white
                                              .withValues(alpha: 0.25),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _showDatePicker
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Date picker (collapsible)
                    if (_showDatePicker) ...[
                      const Gap(8),
                      Container(
                        decoration: BoxDecoration(
                          color: ZipherColors.surface,
                          borderRadius:
                              BorderRadius.circular(ZipherRadius.md),
                          border: Border.all(color: ZipherColors.border),
                        ),
                        child: Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: ZipherColors.cyan,
                              onPrimary: Colors.white,
                              surface: ZipherColors.surface,
                              onSurface: ZipherColors.textPrimary,
                            ),
                          ),
                          child: CalendarDatePicker(
                            initialDate: _selectedDate ?? DateTime(2022),
                            firstDate: _sapling,
                            lastDate: DateTime.now(),
                            onDateChanged: (date) {
                              setState(() {
                                _selectedDate = date;
                                _showDatePicker = false;
                              });
                            },
                          ),
                        ),
                      ),
                      // Quick year shortcuts
                      const Gap(8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final year in [2019, 2020, 2021, 2022, 2023, 2024, 2025])
                            if (DateTime(year).isBefore(DateTime.now()))
                              _YearChip(
                                year: year,
                                selected: _selectedDate?.year == year,
                                onTap: () => setState(() {
                                  _selectedDate = DateTime(year);
                                  _showDatePicker = false;
                                }),
                              ),
                        ],
                      ),
                    ],

                    if (_selectedDate != null && !_showDatePicker) ...[
                      const Gap(8),
                      GestureDetector(
                        onTap: () => setState(() => _selectedDate = null),
                        child: Text(
                          'Clear date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.25),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],

                    const Gap(16),

                    // Info box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ZipherColors.cyan.withValues(alpha: 0.06),
                        borderRadius:
                            BorderRadius.circular(ZipherRadius.sm),
                        border: Border.all(
                          color: ZipherColors.cyan.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Icons.info_outline,
                                color: ZipherColors.cyan, size: 16),
                          ),
                          const Gap(10),
                          Expanded(
                            child: Text(
                              _selectedDate != null
                                  ? 'We\'ll scan from ${DateFormat.yMMMd().format(_selectedDate!)}. '
                                    'This is faster but won\'t find transactions before this date.'
                                  : 'Without a date, we\'ll scan from the beginning of the Zcash shielded chain. '
                                    'This is thorough but may take a while.',
                              style: TextStyle(
                                fontSize: 12,
                                color: ZipherColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(24),
                  ],
                ),
              ),
            ),

            // Restore button (pinned at bottom)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            color: ZipherColors.cyan,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : ZipherWidgets.gradientButton(
                        label: _selectedDate != null
                            ? 'Restore from ${_selectedDate!.year}'
                            : 'Restore (full scan)',
                        icon: Icons.download_done,
                        onPressed: _restore,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateSeed(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your seed phrase';
    }
    if (WarpApi.isValidTransparentKey(value.trim())) {
      return 'Transparent keys are not supported';
    }
    const coin = 0;
    final keyType = WarpApi.validKey(coin, value.trim());
    if (keyType < 0) {
      return 'Invalid seed phrase or key';
    }
    return null;
  }

  Future<void> _restore() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      const coin = 0;
      final seed = _seedController.text.trim();
      final account = await WarpApi.newAccount(coin, 'Main', seed, 0);
      if (account < 0) {
        setState(() {
          _error = 'This account already exists';
          _loading = false;
        });
        return;
      }
      setActiveAccount(coin, account);
      final prefs = await SharedPreferences.getInstance();
      await aa.save(prefs);

      // Determine scan height
      int scanHeight;
      if (_selectedDate != null) {
        scanHeight =
            await WarpApi.getBlockHeightByTime(coin, _selectedDate!);
      } else {
        scanHeight = 419200; // Sapling activation
      }

      // Start rescan from the determined height
      aa.reset(scanHeight);
      Future(() => syncStatus2.rescan(scanHeight));

      if (mounted) GoRouter.of(context).go('/account');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── Year shortcut chip ─────────────────────────────────────

class _YearChip extends StatelessWidget {
  final int year;
  final bool selected;
  final VoidCallback onTap;

  const _YearChip({
    required this.year,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? ZipherColors.cyan.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? ZipherColors.cyan.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Text(
          '$year',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected
                ? ZipherColors.cyan
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
