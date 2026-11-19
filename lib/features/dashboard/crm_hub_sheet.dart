import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design/native_chrome.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/services/app_services.dart';
import '../../core/utils/native_banner_helper.dart';
import '../auth/auth_controller.dart';
import '../notifications/notifications_screen.dart';
import '../search/global_search_screen.dart';
import '../customer_issues/customer_issues_screen.dart';
import '../follow_ups/follow_up_create_sheet.dart';
import '../orders/order_create_sheet.dart';
import '../payments/payments_screen.dart';
import '../subscriptions/expiring_subscriptions_screen.dart';
import '../subscriptions/subscriptions_screen.dart';

/// Opens the **LeadX Executive Hub & Assistant** in a native UIKit sheet
/// (`showNativeSheet` with medium + large detents).
Future<void> showCrmHubSheet(BuildContext context) {
  return showNativeSheet<void>(
    context: context,
    detents: const [
      NativeSheetDetent.fraction(0.65),
      NativeSheetDetent.large,
    ],
    initialDetent: const NativeSheetDetent.fraction(0.65),
    showGrabber: true,
    builder: (ctx) => const _CrmHubView(),
  );
}

class _CrmHubView extends StatefulWidget {
  const _CrmHubView();

  @override
  State<_CrmHubView> createState() => _CrmHubViewState();
}

class _CrmHubViewState extends State<_CrmHubView> {
  final _composerCtrl = NativeComposerController();
  final List<_AssistantMessage> _messages = [
    const _AssistantMessage(
      isUser: false,
      text: 'Good day! I am your LeadX Sales Assistant. How can I assist your pipeline today?',
      timestamp: 'Just now',
    ),
  ];

  void _handleSend(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _messages.add(_AssistantMessage(
        isUser: true,
        text: trimmed,
        timestamp: 'Just now',
      ));
    });

    _composerCtrl.text = '';

    // Smart simulated CRM assistant response
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      String reply = 'Note logged into your employee activity feed.';
      final lower = trimmed.toLowerCase();
      if (lower.contains('order') || lower.contains('sale')) {
        reply = 'You can create an order directly with the "+ New Order" quick action above or review pending orders under the Orders tab.';
      } else if (lower.contains('follow') || lower.contains('call') || lower.contains('task')) {
        reply = 'I noted your follow-up reminder. You can also sync it directly with the Calendar view.';
      } else if (lower.contains('customer') || lower.contains('client')) {
        reply = 'Customer records can be reviewed under the People tab with complete lifetime purchase values.';
      } else if (lower.contains('subscript') || lower.contains('renew')) {
        reply = 'Tip: Check the "Expiring Soon" panel to proactively retain accounts renewing within 30 days.';
      }

      setState(() {
        _messages.add(_AssistantMessage(
          isUser: false,
          text: reply,
          timestamp: 'Just now',
        ));
      });
      showLeadxBanner(
        context,
        title: 'LeadX Sales Assistant',
        body: reply,
        icon: const NativeIcon.symbol('sparkles', fallback: Icons.auto_awesome),
      );
    });
  }

  void _push(Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final services = context.read<AppServices>();
    final cs = Theme.of(context).colorScheme;

    final employeeName = auth.me?.data.name ?? 'Employee';
    final teamName = auth.me?.data.team?.teamName ?? 'Sales Team';
    final email = auth.me?.data.email ?? auth.me?.data.username ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: NativePromptComposer(
        controller: _composerCtrl,
        placeholder: 'Ask LeadX Assistant or log quick note…',
        leading: NativeComposerButton(
          icon: const NativeIcon.symbol('sparkles', fallback: Icons.auto_awesome),
          title: 'Actions',
          menu: [
            NativeMenuItem(
              title: 'Global Search',
              icon: const NativeIcon.symbol('magnifyingglass', fallback: Icons.search),
              onSelected: () => _push(const GlobalSearchScreen()),
            ),
            NativeMenuItem(
              title: 'Draft Client Note',
              icon: const NativeIcon.symbol('note.text', fallback: Icons.edit_note),
              onSelected: () => _handleSend('Draft a client meeting summary'),
            ),
            NativeMenuItem(
              title: 'Review Expiring Subscriptions',
              icon: const NativeIcon.symbol('clock.badge.exclamationmark', fallback: Icons.timer_outlined),
              onSelected: () => _push(const ExpiringSubscriptionsScreen()),
            ),
            NativeMenuItem(
              title: 'Open Notifications',
              icon: const NativeIcon.symbol('bell', fallback: Icons.notifications),
              onSelected: () => _push(const NotificationsScreen()),
            ),
          ],
        ),
        actions: [
          NativeComposerButton(
            icon: const NativeIcon.symbol('mic', fallback: Icons.mic),
            title: 'Voice note',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Listening for voice memo… (dictation ready)')),
              );
            },
          ),
        ],
        primaryAction: NativeComposerButton(
          icon: const NativeIcon.symbol('arrow.up', fallback: Icons.arrow_upward),
          title: 'Send',
          prominent: true,
          onPressed: () => _handleSend(_composerCtrl.text),
        ),
        onSend: _handleSend,
        child: Builder(
          builder: (context) {
            final pad = MediaQuery.paddingOf(context);
            return ListView(
              padding: EdgeInsets.fromLTRB(16, pad.top + 16, 16, pad.bottom + 80),
              children: [
            // ── Top identity pill ──────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                  child: Text(
                    employeeName.isNotEmpty ? employeeName[0].toUpperCase() : 'E',
                    style: AppTypography.cardTitle.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              employeeName,
                              style: AppTypography.sectionTitle.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: StatusPalette.success(cs).withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppColors.radiusSm),
                            ),
                            child: Text(
                              'Active',
                              style: AppTypography.caption.copyWith(
                                color: StatusPalette.success(cs),
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$teamName · $email',
                        style: AppTypography.caption.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Dismiss',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Quick action pills ─────────────────────────────────────
            Row(
              children: [
                if (auth.canCreateOrders)
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                      ),
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('New Order'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        showOrderCreateSheet(context, services);
                      },
                    ),
                  ),
                if (auth.canCreateOrders) const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                    ),
                    icon: const Icon(Icons.add_task, size: 18),
                    label: const Text('Schedule Task'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      showFollowUpCreateSheet(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Grid of CRM panels ─────────────────────────────────────
            Text(
              'CRM directory & panels',
              style: AppTypography.caption.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                _ModuleCard(
                  icon: Icons.search_rounded,
                  symbol: 'magnifyingglass',
                  title: 'Global Search',
                  subtitle: 'Omni CRM lookup',
                  color: cs.onSurfaceVariant,
                  onTap: () => _push(const GlobalSearchScreen()),
                ),
                _ModuleCard(
                  icon: Icons.payments_outlined,
                  symbol: 'creditcard',
                  title: 'Payments',
                  subtitle: 'Invoices & revenue',
                  color: cs.onSurfaceVariant,
                  onTap: () => _push(const PaymentsScreen()),
                ),
                _ModuleCard(
                  icon: Icons.report_problem_outlined,
                  symbol: 'exclamationmark.bubble',
                  title: 'Issues',
                  subtitle: 'Client support tickets',
                  color: cs.onSurfaceVariant,
                  onTap: () => _push(const CustomerIssuesScreen()),
                ),
                _ModuleCard(
                  icon: Icons.repeat_outlined,
                  symbol: 'arrow.triangle.2.circlepath',
                  title: 'Subscriptions',
                  subtitle: 'Active recurring plans',
                  color: cs.onSurfaceVariant,
                  onTap: () => _push(const SubscriptionsScreen()),
                ),
                _ModuleCard(
                  icon: Icons.hourglass_top_outlined,
                  symbol: 'clock.badge.exclamationmark',
                  title: 'Expiring Soon',
                  subtitle: 'Due within 30 days',
                  color: cs.onSurfaceVariant,
                  onTap: () => _push(const ExpiringSubscriptionsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── AI Lead Assistant Conversation Log ────────────────────
            Text(
              'Assistant & quick notes',
              style: AppTypography.caption.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppColors.radiusXl),
                border: Border.all(color: cs.surfaceContainerHighest),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final msg in _messages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            msg.isUser ? Icons.person_pin : Icons.auto_awesome,
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.text,
                                  style: AppTypography.body.copyWith(
                                    color: cs.onSurface,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  msg.timestamp,
                                  style: AppTypography.caption.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _QuickChip(
                        label: 'Check expiring subscriptions',
                        onTap: () => _handleSend('Check expiring subscriptions'),
                      ),
                      _QuickChip(
                        label: 'Show order summary',
                        onTap: () => _handleSend('Show order summary'),
                      ),
                      _QuickChip(
                        label: 'Draft meeting notes',
                        onTap: () => _handleSend('Draft meeting notes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  ),
);
}
}

class _AssistantMessage {
  const _AssistantMessage({
    required this.isUser,
    required this.text,
    required this.timestamp,
  });

  final bool isUser;
  final String text;
  final String timestamp;
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          border: Border.all(color: cs.surfaceContainerHighest),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.icon,
    required this.symbol,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String symbol;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppColors.radiusXl),
            border: Border.all(color: cs.surfaceContainerHighest),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                    child: Center(
                      child: Icon(icon, color: cs.onSurfaceVariant, size: 18),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: AppTypography.cardTitle.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
