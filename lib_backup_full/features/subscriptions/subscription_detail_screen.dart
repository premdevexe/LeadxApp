import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:veneer/veneer.dart';

import '../../core/design/app_typography.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/subscription.dart';
import '../../shared/widgets/app_widgets.dart';
import '../customers/customer_detail_screen.dart';
import '../orders/order_detail_screen.dart';

/// Screen 5 Detail: `GET /employee/subscriptions/{id}`
class SubscriptionDetailScreen extends StatefulWidget {
  const SubscriptionDetailScreen({super.key, required this.subscriptionId});

  final int subscriptionId;

  @override
  State<SubscriptionDetailScreen> createState() =>
      _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState extends State<SubscriptionDetailScreen> {
  Subscription? _sub;
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
      final res = await services.api.subscriptionDetail(widget.subscriptionId);
      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      _sub = Subscription.fromJson(data);
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();

    if (_loading && _sub == null) {
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
            title: 'Subscription Details',
            capsule: true,
            icon: NativeIcon.symbol('arrow.triangle.2.circlepath', fallback: Icons.repeat),
          ),
          child: const LoadingScreen(),
        ),
      );
    }

    if (_error != null && _sub == null) {
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
            title: 'Subscription Details',
            capsule: true,
            icon: NativeIcon.symbol('arrow.triangle.2.circlepath', fallback: Icons.repeat),
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

    final s = _sub!;

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
          title: s.planSnapshot ?? 'Subscription #${s.id}',
          subtitle: '${s.customerName ?? 'Customer'} · ${s.status}',
          capsule: true,
          icon: const NativeIcon.symbol('arrow.triangle.2.circlepath', fallback: Icons.repeat),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.credit_card,
                            color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.planSnapshot ?? 'Plan',
                              style: AppTypography.pageTitle
                                  .copyWith(fontSize: 18, color: cs.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            StatusChip(s.status),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DetailRow(label: 'Subscription ID', value: '#${s.id}', tabular: true),
                  if (s.billingCycle != null)
                    DetailRow(
                        label: 'Billing Cycle',
                        value: s.billingCycle!.toUpperCase()),
                  if (s.priceSnapshot != null)
                    DetailRow(
                        label: 'Price Snapshot',
                        value: Fmt.money(s.priceSnapshot),
                        tabular: true),
                  if (s.amountPaid != null)
                    DetailRow(label: 'Amount Paid', value: Fmt.money(s.amountPaid), tabular: true),
                  DetailRow(label: 'Started At', value: Fmt.date(s.startedAt)),
                  if (s.renewalDate != null)
                    DetailRow(label: 'Renewal Date', value: Fmt.date(s.renewalDate)),
                  DetailRow(
                      label: 'Expires At',
                      value:
                          '${Fmt.date(s.expiresAt)} (${Fmt.relative(s.expiresAt)})'),
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
                    title: const Text(
                        'Associated Order',
                        style: AppTypography.cardTitle),
                    subtitle: Text(s.orderNumber ?? 'Order #${s.orderId}',
                        style:
                            AppTypography.secondary.copyWith(color: cs.onSurfaceVariant)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: s.orderId > 0
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(orderId: s.orderId),
                              ),
                            );
                          }
                        : null,
                  ),
                  if (s.customerId != null && s.customerId! > 0) ...[
                    const Divider(height: 1, indent: 16),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text(
                          'Associated Customer',
                          style: AppTypography.cardTitle),
                      subtitle: Text(s.customerName ?? 'Customer #${s.customerId}',
                          style: AppTypography.secondary
                              .copyWith(color: cs.onSurfaceVariant)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CustomerDetailScreen(customerId: s.customerId!),
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
}
