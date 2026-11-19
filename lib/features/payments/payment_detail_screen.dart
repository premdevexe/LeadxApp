import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/design/native_chrome.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/payment.dart';
import '../../shared/widgets/app_widgets.dart';
import '../customers/customer_detail_screen.dart';
import '../orders/order_detail_screen.dart';

/// A small theme-safe verified / unverified pill.
class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = verified ? StatusPalette.success(cs) : StatusPalette.warning(cs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Text(
        verified ? 'Verified' : 'Unverified',
        style: AppTypography.caption.copyWith(color: c, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Page 4 Detail: `GET /employee/payments/{id}`
class PaymentDetailScreen extends StatefulWidget {
  const PaymentDetailScreen({super.key, required this.paymentId});

  final int paymentId;

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  Payment? _payment;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await services.api.paymentDetail(widget.paymentId);
      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      _payment = Payment.fromJson(data);
      if (!mounted) return;
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();

    if (_loading && _payment == null) {
      return Scaffold(
        body: NativeNavigationBar(
          leading: canPop
              ? NativeBarButton(
                  icon: const NativeIcon.symbol('chevron.left', fallback: Icons.arrow_back),
                  title: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: const NativeBarTitle(
            title: 'Payment Details',
            capsule: true,
            icon: NativeIcon.symbol('creditcard.fill', fallback: Icons.payments),
          ),
          child: const LoadingScreen(),
        ),
      );
    }

    if (_error != null && _payment == null) {
      return Scaffold(
        body: NativeNavigationBar(
          leading: canPop
              ? NativeBarButton(
                  icon: const NativeIcon.symbol('chevron.left', fallback: Icons.arrow_back),
                  title: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: const NativeBarTitle(
            title: 'Payment Details',
            capsule: true,
            icon: NativeIcon.symbol('creditcard.fill', fallback: Icons.payments),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorBanner(message: _error!, onRetry: _load),
            ),
          ),
        ),
      );
    }

    final p = _payment!;

    return Scaffold(
      body: NativeNavigationBar(
        leading: canPop
            ? NativeBarButton(
                icon: const NativeIcon.symbol('chevron.left', fallback: Icons.arrow_back),
                title: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: NativeBarTitle(
          title: 'Payment #${p.id}',
          subtitle: '${Fmt.moneyFor(p.amount, code: p.currency)} · ${p.paymentStatus}',
          capsule: true,
          icon: const NativeIcon.symbol('creditcard.fill', fallback: Icons.payments),
        ),
        trailing: [
          NativeBarButton(
            icon: const NativeIcon.symbol('arrow.clockwise', fallback: Icons.refresh),
            title: 'Refresh',
            onPressed: _load,
          ),
        ],
        child: Builder(
          builder: (context) {
            final pad = MediaQuery.paddingOf(context);
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, pad.top + 12, 16, pad.bottom + 24),
                children: [
            AppCard.surface(
              context,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Payment Amount',
                    style: AppTypography.secondary.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    child: Text(
                      // Resolved through the admin currency catalogue (code -> symbol).
                      Fmt.moneyFor(p.amount, code: p.currency),
                      style: AppTypography.statNumeric.copyWith(color: cs.primary, fontSize: 28),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StatusChip(p.paymentStatus),
                      const SizedBox(width: 8),
                      _VerifiedBadge(verified: p.verified),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard.surface(
              context,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment Details',
                      style: AppTypography.sectionTitle.copyWith(color: cs.onSurface, fontSize: 16)),
                  const SizedBox(height: 12),
                  _row(
                    context,
                    'Payment Method',
                    (p.paymentMethod ?? '—').toUpperCase(),
                  ),
                  if (p.transactionReference != null && p.transactionReference!.isNotEmpty)
                    Row(
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text('Transaction Ref',
                              style: AppTypography.secondary.copyWith(color: cs.onSurfaceVariant)),
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(p.transactionReference!,
                                style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: AppTypography.tabularFigures,
                                    color: cs.onSurface)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () =>
                              _copyToClipboard(p.transactionReference!, 'Transaction Ref'),
                        ),
                      ],
                    )
                  else
                    _row(context, 'Transaction Ref', '—'),
                  _row(context, 'Payment Date', Fmt.dateTime(p.paymentDate ?? p.createdAt)),
                  if (p.source != null) _row(context, 'Source', p.source!),
                  if (p.verifiedAt != null) _row(context, 'Verified At', Fmt.dateTime(p.verifiedAt)),
                  if (p.adminNotes != null && p.adminNotes!.isNotEmpty)
                    _row(context, 'Admin Notes', p.adminNotes!),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard.surface(
              context,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: const Text('Associated Order',
                        style: AppTypography.cardTitle),
                    subtitle: Text('Order #${p.orderId}',
                        style: AppTypography.secondary.copyWith(color: cs.onSurfaceVariant)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: p.orderId > 0
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(orderId: p.orderId),
                              ),
                            );
                          }
                        : null,
                  ),
                  if (p.customerId != null && p.customerId! > 0) ...[
                    const Divider(height: 1, indent: 16),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Associated Customer',
                          style: AppTypography.cardTitle),
                      subtitle: Text('Customer #${p.customerId}',
                          style:
                              AppTypography.secondary.copyWith(color: cs.onSurfaceVariant)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CustomerDetailScreen(customerId: p.customerId!),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  ),
),
);
}

  Widget _row(BuildContext context, String label, String value, {bool tabular = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: AppTypography.secondary.copyWith(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                fontFeatures: tabular ? AppTypography.tabularFigures : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
