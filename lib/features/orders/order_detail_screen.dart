import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:veneer/veneer.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/order.dart';
import '../../shared/widgets/app_widgets.dart';
import '../auth/auth_controller.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _res;
  bool _loading = true;
  String? _error;
  String? _revealedKey;
  bool _actionBusy = false;

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
      _res = await services.api.orderDetail(widget.orderId);
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

  void _run(String label, Future<void> Function() fn) {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    fn().then((_) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label done')));
      _load();
    }).catchError((Object e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Action failed'),
        ),
      );
    });
  }

  Future<void> _revealKey() async {
    if (_actionBusy) return;
    final services = context.read<AppServices>();
    setState(() => _actionBusy = true);
    try {
      final res = await services.api.revealApiKey(widget.orderId);
      final key = res['data']?['api_key'] ?? res['api_key'] ?? res['key'];
      if (!mounted) return;
      setState(() {
        _revealedKey = key is String ? key : null;
        _actionBusy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _whatsapp() async {
    final services = context.read<AppServices>();
    try {
      final res = await services.api.whatsappShare(widget.orderId);
      final url = res['url'] as String? ?? res['share_url'] as String?;
      if (url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No WhatsApp URL available')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _copyShareLink() async {
    final services = context.read<AppServices>();
    try {
      final res = await services.api.whatsappShare(widget.orderId);
      final url = res['url'] as String? ?? res['share_url'] as String?;
      if (url != null && url.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: url));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Share link copied to clipboard')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No share link available')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showResubmitDialog(Order order) async {
    final valueCtrl = TextEditingController(text: order.closingValue.toStringAsFixed(2));
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: cs.surface,
            title: Text(
              'Resubmit Closing Value',
              style: AppTypography.cardTitle.copyWith(fontWeight: FontWeight.w600),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.orderNumber}',
                    style: AppTypography.secondary.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: valueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'New Closing Value',
                      prefixText: '${Fmt.live.symbol} ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Value is required';
                      final n = num.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Resubmission Notes (optional)',
                      hintText: 'Reason for value adjustment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(false),
                child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSubmitting = true);
                        try {
                          final val = num.parse(valueCtrl.text.trim());
                          await context.read<AppServices>().api.resubmitClosing(
                                order.id,
                                val,
                                notes: notesCtrl.text.trim().isEmpty
                                    ? null
                                    : notesCtrl.text.trim(),
                              );
                          if (ctx.mounted) Navigator.of(ctx).pop(true);
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(e is ApiException
                                    ? e.message
                                    : 'Resubmission failed'),
                              ),
                            );
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Resubmit'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Closing value resubmitted for approval')),
        );
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();
    final auth = context.watch<AuthController>();

    final res = _res;
    final data = (res?['data'] as Map<String, dynamic>?) ?? const {};
    final order = data.isEmpty ? null : Order.fromJson(data);
    final viewOnly = res?['view_only'] == true;

    Widget bodyContent;
    if (_loading && order == null) {
      bodyContent = const LoadingScreen();
    } else if (_error != null && order == null) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(message: _error!, onRetry: _load),
        ),
      );
    } else if (order == null) {
      bodyContent = const EmptyState(title: 'No order data');
    } else {
      bodyContent = Builder(
        builder: (context) {
          final pad = MediaQuery.paddingOf(context);
          final received = order.amountReceived ?? 0.0;
          final due = (order.closingValue - received).clamp(0.0, double.infinity);

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, pad.top + 12, 16, 32),
              children: [
                if (viewOnly)
                  AppCard.surface(
                    context,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    color: cs.tertiaryContainer,
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16,
                            color: cs.onTertiaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text('Read-only (team data)',
                                style: AppTypography.secondary
                                    .copyWith(color: cs.onTertiaryContainer))),
                      ],
                    ),
                  ),

                // ── Customer Card ──
                AppCard.surface(
                  context,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CUSTOMER',
                            style: AppTypography.caption.copyWith(
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          StatusChip(order.orderStatus),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        order.customerName,
                        style: AppTypography.pageTitle.copyWith(
                          fontSize: 18,
                          color: cs.onSurface,
                        ),
                      ),
                      if (order.customerPhone != null && order.customerPhone!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(
                              order.customerPhone!,
                              style: AppTypography.secondary
                                  .copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                      if (order.customerEmail != null && order.customerEmail!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.mail_outline, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(
                              order.customerEmail!,
                              style: AppTypography.secondary
                                  .copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Product & Subscription Card ──
                AppCard.surface(
                  context,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PRODUCT & SERVICE',
                            style: AppTypography.caption.copyWith(
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (order.subscription != null && order.subscription!.status != null)
                            StatusChip(order.subscription!.status!)
                          else
                            StatusChip(order.orderStatus),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        order.productNameSnapshot ?? order.productName ?? '—',
                        style: AppTypography.cardTitle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      if (order.productDurationSnapshot != null || order.duration != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Duration: ${order.productDurationSnapshot ?? order.duration}',
                          style: AppTypography.secondary
                              .copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                      if (order.subscription != null) ...[
                        const Divider(height: 20, thickness: 1),
                        _kv(context, 'Billing cycle', order.subscription!.billingCycle ?? 'Standard'),
                        if (order.subscription!.expiresAt != null)
                          _kv(context, 'Renews / Expires', Fmt.dateTime(order.subscription!.expiresAt)),
                      ],
                      const SizedBox(height: 6),
                      _kv(context, 'Order created', Fmt.dateTime(order.createdAt)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Financial Overview Card ──
                AppCard.surface(
                  context,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PAYMENT SUMMARY',
                            style: AppTypography.caption.copyWith(
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          StatusChip(order.paymentStatus),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _kv(context, 'Closing value', Fmt.money(order.closingValue)),
                      _kv(
                        context,
                        'Amount collected',
                        Fmt.money(received),
                        valueColor: StatusPalette.success(cs),
                      ),
                      _kv(
                        context,
                        'Amount due',
                        Fmt.money(due),
                        valueColor: due > 0 ? StatusPalette.warning(cs) : StatusPalette.success(cs),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Detail Actions ──
                if (!viewOnly) ...[
                  Text(
                    'ACTIONS',
                    style: AppTypography.caption.copyWith(
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Complete Order
                      if (auth.canCompleteOrders && order.orderStatus != 'confirmed' && order.orderStatus != 'completed')
                        AppPrimaryButton(
                          onPressed: () => _run(
                            'Completed',
                            () async => context.read<AppServices>().api.completeOrder(order.id),
                          ),
                          label: 'Complete Order',
                          icon: Icons.check_circle_outline,
                          loading: _actionBusy,
                          expand: false,
                        ),

                      // Activate
                      if (order.orderStatus != 'active')
                        AppOutlinedButton(
                          onPressed: () => _run(
                            'Activated',
                            () async => context.read<AppServices>().api.activateOrder(order.id),
                          ),
                          label: 'Activate',
                          icon: Icons.play_arrow_outlined,
                          loading: _actionBusy,
                          expand: false,
                        ),

                      // Resubmit closing value
                      AppOutlinedButton(
                        onPressed: () => _showResubmitDialog(order),
                        label: 'Resubmit closing value',
                        icon: Icons.edit_outlined,
                        expand: false,
                      ),

                      // WhatsApp Share (deep link)
                      AppOutlinedButton(
                        onPressed: _whatsapp,
                        label: 'WhatsApp share',
                        icon: Icons.chat_outlined,
                        expand: false,
                      ),

                      // Copy public share link
                      AppOutlinedButton(
                        onPressed: _copyShareLink,
                        label: 'Copy share link',
                        icon: Icons.link_outlined,
                        expand: false,
                      ),

                      // Reveal API key
                      AppOutlinedButton(
                        onPressed: _revealKey,
                        label: 'Reveal API key',
                        icon: Icons.key_outlined,
                        loading: _actionBusy,
                        expand: false,
                      ),
                    ],
                  ),
                ],

                // ── Revealed API Key Section (masked by default, one-time reveal, copy button, never persisted) ──
                if (_revealedKey != null) ...[
                  const SizedBox(height: 16),
                  AppCard.surface(
                    context,
                    padding: const EdgeInsets.all(16),
                    color: isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 16, color: cs.onSurface),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'API Key (One-time reveal — never persisted to disk)',
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0xFF404040) : const Color(0xFFE5E5E5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _revealedKey!,
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                tooltip: 'Copy API Key',
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: _revealedKey!));
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('API key copied to clipboard (held in-memory only)'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'For security reasons, this key will not be retained across app restarts or written to persistent storage.',
                          style: AppTypography.caption.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }

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
          title: order?.orderNumber ?? 'Order Details',
          subtitle: order != null ? '${order.customerName} · ${order.orderStatus}' : null,
          capsule: true,
          icon: const NativeIcon.symbol('cart.fill', fallback: Icons.shopping_bag),
        ),
        trailing: [
          NativeBarButton(
            icon: const NativeIcon.symbol('arrow.clockwise', fallback: Icons.refresh),
            title: 'Refresh',
            onPressed: _load,
          ),
          if (order?.customerPhone != null && order!.customerPhone!.isNotEmpty)
            NativeBarButton(
              icon: const NativeIcon.symbol('phone', fallback: Icons.phone),
              title: 'Call',
              onPressed: () async {
                final uri = Uri.parse('tel:${order.customerPhone}');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
        ],
        child: Builder(
          builder: (context) {
            final pad = MediaQuery.paddingOf(context);
            return Padding(
              padding: EdgeInsets.only(top: pad.top),
              child: bodyContent,
            );
          },
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value, {Color? valueColor}) {
    final cs = Theme.of(context).colorScheme;
    final isMoney = value.startsWith(Fmt.live.symbol) ||
        value.contains(',') ||
        label.toLowerCase().contains('value') ||
        label.toLowerCase().contains('collected') ||
        label.toLowerCase().contains('due') ||
        label.toLowerCase().contains('received');
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.secondary.copyWith(color: cs.onSurfaceVariant)),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? cs.onSurface,
                    fontFeatures:
                        isMoney ? AppTypography.tabularFigures : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

