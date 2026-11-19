import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/design/native_chrome.dart';

import '../../core/design/app_typography.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/customer.dart';
import '../../shared/widgets/app_widgets.dart';
import '../orders/order_detail_screen.dart';

/// Screen 3 Detail: `GET /employee/customers/{id}`.
class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final int customerId;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Customer? _customer;
  List<dynamic> _orders = [];
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
      final res = await services.api.customerDetail(widget.customerId);
      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      _customer = Customer.fromJson(data);
      _orders = (data['orders'] as List<dynamic>?) ?? [];
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

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();

    if (_loading && _customer == null) {
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
            title: 'Customer Details',
            capsule: true,
            icon: NativeIcon.symbol('person.2.fill', fallback: Icons.person),
          ),
          child: const LoadingScreen(),
        ),
      );
    }

    if (_error != null && _customer == null) {
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
            title: 'Customer Details',
            capsule: true,
            icon: NativeIcon.symbol('person.2.fill', fallback: Icons.person),
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

    final c = _customer!;

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
          title: c.name,
          subtitle: '${c.purchasesCount} orders · ${Fmt.money(c.totalPurchased)}',
          capsule: true,
          icon: const NativeIcon.symbol('person.2.fill', fallback: Icons.person),
        ),
        trailing: [
          NativeBarButton(
            icon: const NativeIcon.symbol('arrow.clockwise', fallback: Icons.refresh),
            title: 'Refresh',
            onPressed: _load,
          ),
          if (c.phone != null && c.phone!.isNotEmpty)
            NativeBarButton(
              icon: const NativeIcon.symbol('phone', fallback: Icons.phone),
              title: 'Call',
              onPressed: () => _callPhone(c.phone!),
            ),
        ],
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
            AppCard.surface(
              context,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.person,
                            size: 30, color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name,
                                style: AppTypography.pageTitle
                                    .copyWith(fontSize: 20, color: cs.onSurface),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            StatusChip(c.status ?? 'active'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (c.phone != null && c.phone!.isNotEmpty)
                    _ContactRow(
                      icon: Icons.phone_outlined,
                      label: c.phone!,
                      action: Icons.call,
                      onTap: () => _callPhone(c.phone!),
                    ),
                  if (c.email != null && c.email!.isNotEmpty)
                    _ContactRow(
                      icon: Icons.email_outlined,
                      label: c.email!,
                      action: Icons.mail,
                      onTap: () => _sendEmail(c.email!),
                    ),
                  if (c.lastPurchaseAt != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Last purchase: ${Fmt.dateTime(c.lastPurchaseAt)}',
                        style:
                            AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppCard.stat(
                    context,
                    label: 'Total Orders',
                    value: '${c.purchasesCount}',
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppCard.stat(
                    context,
                    label: 'Total Purchased',
                    value: Fmt.money(c.totalPurchased),
                    icon: Icons.payments_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppCard.section(context, 'Order History'),
            if (_orders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No orders recorded for this customer.',
                    style: AppTypography.secondary,
                  ),
                ),
              )
            else
              ..._orders.map((raw) {
                final o = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
                final orderId = (o['id'] as num?)?.toInt() ?? 0;
                final orderNumber = o['order_number'] as String? ?? 'Order #$orderId';
                final status = o['order_status'] as String? ?? '';
                final closingVal = (o['closing_value'] as num?)?.toDouble() ?? 0.0;
                return AppCard.surface(
                  context,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onTap: orderId > 0
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OrderDetailScreen(orderId: orderId),
                            ),
                          );
                        }
                      : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(orderNumber,
                                style: AppTypography.cardTitle
                                    .copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(Fmt.dateTime(o['created_at'] as String?),
                                style: AppTypography.caption
                                    .copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(Fmt.money(closingVal),
                              style: AppTypography.statNumericSmall
                                  .copyWith(color: cs.onSurface)),
                          const SizedBox(height: 3),
                          StatusChip(status, compact: true),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}
}

/// A compact contact row: icon + label + tap-to-call/email action.
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final IconData action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(color: cs.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(action, color: cs.primary, size: 20),
            tooltip: label,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
