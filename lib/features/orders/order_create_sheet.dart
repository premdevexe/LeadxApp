import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:veneer/veneer.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/lead_glass.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../core/design/theme_controller.dart';
import '../../shared/format.dart';
import '../../shared/models/order.dart';
import '../../shared/widgets/app_widgets.dart';

/// Opens the "New order" bottom sheet and performs the create call.
///
/// With the "Liquid Glass" preference on the form presents in a native
/// [showNativeSheet] (real `UIPresentationController` on iOS 26+; a Flutter
/// replica elsewhere); with it off the standard Material bottom sheet is
/// used. The form's fields and call to action are kit Liquid Glass surfaces
/// that follow the same toggle.
///
/// Idempotency: the order is submitted once; a double-tap during the request
/// is blocked by the in-flight flag, and the API client can carry an
/// Idempotency-Key header on retry.
Future<void> showOrderCreateSheet(
  BuildContext context,
  AppServices services,
) async {
  if (!context.mounted) return;
  final useGlass = context.read<ThemeController>().glassEnabled;
  if (useGlass) {
    await showNativeSheet<void>(
      context: context,
      detents: const [
        NativeSheetDetent.fraction(0.65),
        NativeSheetDetent.large,
      ],
      initialDetent: const NativeSheetDetent.fraction(0.65),
      showGrabber: true,
      builder: (_) => _CreateOrderForm(services: services),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreateOrderForm(services: services),
    );
  }
}

class _CreateOrderForm extends StatefulWidget {
  const _CreateOrderForm({required this.services});

  final AppServices services;

  @override
  State<_CreateOrderForm> createState() => _CreateOrderFormState();
}

class _CreateOrderFormState extends State<_CreateOrderForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _closing = TextEditingController();
  final _received = TextEditingController();
  Product? _product;
  final Set<String> _methods = {
    'cash',
    'upi',
    'card',
    'bank_transfer',
    'crypto',
    'other',
  };
  String? _method;
  bool _loadingProducts = true;
  List<Product> _products = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final res = await widget.services.api.products();
      final data = (res['data'] as List<dynamic>?) ?? const [];
      _products = data
          .where((e) => (e as Map)['status'] == 'active')
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() => _loadingProducts = false);
    } on ApiException {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'customer_name': _name.text.trim(),
      if (_phone.text.trim().isNotEmpty)
        'customer_phone': _phone.text.trim()
      else if (_email.text.trim().isNotEmpty)
        'customer_email': _email.text.trim(),
      if (_product != null) 'product_id': _product!.id,
      'closing_value': double.tryParse(_closing.text.trim()) ?? 0,
      'amount_received': double.tryParse(_received.text.trim()) ?? 0,
      if (_method != null) 'payment_method': _method,
    };

    try {
      await widget.services.api.createOrder(payload);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        // Native sheets (iOS 26+) live on their own navigator — pop through
        // NativeSheet.close so it works in both native and fallback mode.
        await NativeSheet.close(context);
        messenger.showSnackBar(const SnackBar(content: Text('Order created')));
        _name.clear();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.isValidation
              ? (e.fieldErrors.values.isNotEmpty
                    ? e.fieldErrors.values.first.first
                    : 'Validation failed')
              : e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _closing.dispose();
    _received.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'New order',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  if (_loadingProducts)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_products.isNotEmpty)
                    LeadGlass.field(
                      context,
                      DropdownButtonFormField<Product>(
                        initialValue: _product,
                        isExpanded: true,
                        decoration: LeadGlass.fieldDecoration(
                            context, label: 'Product'),
                        items: _products
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                // Catalog prices are in the admin's active currency.
                                child: Text('${p.name} · ${Fmt.money(p.price)}'),
                              ),
                            )
                            .toList(),
                        onChanged: (p) => setState(() => _product = p),
                      ),
                    ),
                  const SizedBox(height: 12),
                  LeadGlass.field(
                    context,
                    TextFormField(
                      controller: _name,
                      decoration: LeadGlass.fieldDecoration(
                          context, label: 'Customer name *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LeadGlass.field(
                          context,
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration:
                                LeadGlass.fieldDecoration(context, label: 'Phone'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LeadGlass.field(
                          context,
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration:
                                LeadGlass.fieldDecoration(context, label: 'Email'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LeadGlass.field(
                          context,
                          TextFormField(
                            controller: _closing,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                            // Show the live admin currency unit in the label.
                            decoration: LeadGlass.fieldDecoration(
                              context,
                              label: 'Closing value (${Fmt.live.symbol})',
                            ),
                            onFieldSubmitted: (_) =>
                                _closing.text.isEmpty ? null : _submit(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LeadGlass.field(
                          context,
                          TextFormField(
                            controller: _received,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                            decoration: LeadGlass.fieldDecoration(
                              context,
                              label: 'Amount received',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LeadGlass.field(
                    context,
                    DropdownButtonFormField<String>(
                      initialValue: _method,
                      isExpanded: true,
                      decoration: LeadGlass.fieldDecoration(
                          context, label: 'Payment method'),
                      items: _methods
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(m.replaceAll('_', ' ')),
                            ),
                          )
                          .toList(),
                      onChanged: (m) => setState(() => _method = m),
                    ),
                  ),
                  if (_product != null && _product!.minimumClosingPrice > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Minimum closing for this product: ${Fmt.money(_product!.minimumClosingPrice)}',
                        style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: StatusPalette.danger(cs),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  AppPrimaryButton(
                    onPressed: _busy ? null : _submit,
                    label: 'Create order',
                    loading: _busy,
                    height: 50,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
