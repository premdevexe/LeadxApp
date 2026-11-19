import 'package:flutter/material.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/lead_glass.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/order.dart';
import '../../shared/widgets/app_widgets.dart';
import 'order_create_screen.dart';

/// Opens the "New order" bottom sheet and performs the create call.
Future<void> showOrderCreateSheet(
  BuildContext context,
  AppServices services,
) async {
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CreateOrderSheet(services: services),
  );
}

class _CreateOrderSheet extends StatelessWidget {
  const _CreateOrderSheet({required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
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
            child: _OrderSheetForm(services: services),
          ),
        ),
      ),
    );
  }
}

class _OrderSheetForm extends StatefulWidget {
  const _OrderSheetForm({required this.services});

  final AppServices services;

  @override
  State<_OrderSheetForm> createState() => _OrderSheetFormState();
}

class _OrderSheetFormState extends State<_OrderSheetForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phoneLocal = TextEditingController();
  final _email = TextEditingController();
  final _productName = TextEditingController();
  final _closing = TextEditingController();
  final _notes = TextEditingController();

  String _countryCode = '+91';
  String _duration = '1y';
  Product? _product;
  bool _closingWasAutoSet = false;

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

  void _onProductSelected(Product? p) {
    setState(() {
      _product = p;
      if (p != null) {
        _productName.text = p.name;
        if (kOrderDurations.containsKey(p.duration)) {
          _duration = p.duration;
        }
        if (_closing.text.isEmpty || _closingWasAutoSet) {
          _closing.text = p.price.toStringAsFixed(2);
          _closingWasAutoSet = true;
        }
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final phoneLocal = _phoneLocal.text.trim();
    String? normalizedPhone;
    if (phoneLocal.isNotEmpty) {
      final digits = phoneLocal.replaceAll(RegExp(r'\D'), '');
      final cleanCc = _countryCode.replaceAll(RegExp(r'\D'), '');
      normalizedPhone = '+$cleanCc${digits.replaceFirst(RegExp(r'^0+'), '')}';
    }

    final closingVal = double.tryParse(_closing.text.trim()) ?? 0;

    final payload = <String, dynamic>{
      'customer_name': _name.text.trim(),
      'customer_phone': ?normalizedPhone,
      'customer_country_code': _countryCode,
      if (phoneLocal.isNotEmpty) 'customer_phone_local': phoneLocal,
      if (_email.text.trim().isNotEmpty) 'customer_email': _email.text.trim(),
      'product_id': ?_product?.id,
      if (_productName.text.trim().isNotEmpty)
        'product_name': _productName.text.trim(),
      'duration': _duration,
      'closing_value': closingVal,
      if (_notes.text.trim().isNotEmpty) 'order_notes': _notes.text.trim(),
    };

    try {
      await widget.services.api.createOrder(payload);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order created successfully')),
        );
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
    _phoneLocal.dispose();
    _email.dispose();
    _productName.dispose();
    _closing.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints.tightFor(width: 36, height: 4),
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'New order',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                'Auto Order #',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Customer Name
          LeadGlass.field(
            context,
            TextFormField(
              controller: _name,
              decoration: LeadGlass.fieldDecoration(
                context,
                label: 'Customer name *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Customer name is required' : null,
            ),
          ),
          const SizedBox(height: 12),

          // Phone
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: LeadGlass.field(
                  context,
                  DropdownButtonFormField<String>(
                    initialValue: _countryCode,
                    isExpanded: true,
                    decoration: LeadGlass.fieldDecoration(context, label: 'Code'),
                    items: kOrderCountryCodes.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _countryCode = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LeadGlass.field(
                  context,
                  TextFormField(
                    controller: _phoneLocal,
                    keyboardType: TextInputType.phone,
                    decoration: LeadGlass.fieldDecoration(
                      context,
                      label: 'Phone number',
                      hint: '9876543210',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Email
          LeadGlass.field(
            context,
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: LeadGlass.fieldDecoration(
                context,
                label: 'Customer email',
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Product Select
          if (_loadingProducts)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: LeadxFlickrLoading(size: 28)),
            )
          else
            LeadGlass.field(
              context,
              DropdownButtonFormField<Product?>(
                initialValue: _product,
                isExpanded: true,
                decoration: LeadGlass.fieldDecoration(
                  context,
                  label: 'Product',
                ),
                items: [
                  const DropdownMenuItem<Product?>(
                    value: null,
                    child: Text('— none (enter manually) —'),
                  ),
                  ..._products.map(
                    (p) => DropdownMenuItem<Product?>(
                      value: p,
                      child: Text(
                        '${p.name} (${Fmt.money(p.price)} — ${kOrderDurations[p.duration] ?? p.duration})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: _onProductSelected,
              ),
            ),
          const SizedBox(height: 12),

          // Product Name
          LeadGlass.field(
            context,
            TextFormField(
              controller: _productName,
              decoration: LeadGlass.fieldDecoration(
                context,
                label: 'Product name',
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Duration
          LeadGlass.field(
            context,
            DropdownButtonFormField<String>(
              initialValue: _duration,
              isExpanded: true,
              decoration: LeadGlass.fieldDecoration(
                context,
                label: 'Subscription duration',
              ),
              items: kOrderDurations.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _duration = val);
              },
            ),
          ),
          const SizedBox(height: 12),

          // Closing Value
          LeadGlass.field(
            context,
            TextFormField(
              controller: _closing,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: LeadGlass.fieldDecoration(
                context,
                label: 'Closing value (${Fmt.live.symbol}) *',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Closing value is required';
                final n = num.tryParse(v.trim());
                if (n == null || n < 0) return 'Enter a valid amount';
                if (_product != null &&
                    _product!.minimumClosingPrice > 0 &&
                    n < _product!.minimumClosingPrice) {
                  return 'Cannot be less than floor of ${Fmt.money(_product!.minimumClosingPrice)}';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),

          // Notes
          LeadGlass.field(
            context,
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: LeadGlass.fieldDecoration(
                context,
                label: 'Order notes',
                hint: 'Optional notes…',
              ),
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
            height: 48,
          ),
        ],
      ),
    );
  }
}
