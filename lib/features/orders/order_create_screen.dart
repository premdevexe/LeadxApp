import 'package:flutter/material.dart';

import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/order.dart';
import '../../shared/widgets/app_widgets.dart';

/// Supported subscription durations mirroring `\App\Models\SalesOrder::DURATIONS`.
const Map<String, String> kOrderDurations = {
  '3d': '3 days',
  '7d': '7 days',
  '15d': '15 days',
  '30d': '30 days',
  '3m': '3 months',
  '6m': '6 months',
  '1y': '1 year',
};

/// Supported country codes mirroring `employee/orders/create.blade.php`.
const Map<String, String> kOrderCountryCodes = {
  '+91': '+91 (IN)',
  '+1': '+1 (US/CA)',
  '+44': '+44 (UK)',
  '+61': '+61 (AU)',
  '+971': '+971 (UAE)',
  '+968': '+968 (OM)',
  '+974': '+974 (QA)',
  '+965': '+965 (KW)',
  '+966': '+966 (SA)',
  '+973': '+973 (BH)',
  '+20': '+20 (EG)',
  '+234': '+234 (NG)',
  '+254': '+254 (KE)',
  '+27': '+27 (ZA)',
  '+60': '+60 (MY)',
  '+65': '+65 (SG)',
  '+880': '+880 (BD)',
  '+94': '+94 (LK)',
  '+62': '+62 (ID)',
  '+63': '+63 (PH)',
  '+84': '+84 (VN)',
  '+86': '+86 (CN)',
};

/// Payment methods recognized in LeadX settings and CreateOrderController.
const Map<String, String> kOrderPaymentMethods = {
  'gpay': 'Google Pay',
  'phonepe': 'PhonePe',
  'paytm': 'Paytm',
  'upi': 'UPI Transfer',
  'bank_transfer': 'Bank Transfer / NEFT',
  'cash': 'Cash Payment',
};

/// Dedicated, full-screen Create Order page matching the LeadX Master Design System.
///
/// Designed with:
/// - 4px grid rhythm, structured cards (Customer, Product & Plan, Financials, Notes)
/// - Pure high-contrast neutral theme (#171717 primary, quiet hairlines, semantic alerts)
/// - Real-time auto-calculation of discount & deal approval requirements
/// - Clear keyboard input types and accessibility focus rings
class OrderCreateScreen extends StatefulWidget {
  const OrderCreateScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends State<OrderCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phoneLocal = TextEditingController();
  final _email = TextEditingController();
  final _productName = TextEditingController();
  final _closing = TextEditingController();
  final _received = TextEditingController();
  final _notes = TextEditingController();

  String _countryCode = '+91';
  String _duration = '1y';
  String? _paymentMethod;
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
      final dynamic raw = res['data'] ?? res['products'];
      final List<dynamic> list = raw is List ? raw : const [];
      _products = list
          .whereType<Map>()
          .where((e) {
            final status = e['status']?.toString().toLowerCase();
            return status == null || status.isEmpty || status == 'active';
          })
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (mounted) setState(() => _loadingProducts = false);
    } catch (_) {
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
          _closing.text = p.price > 0
              ? (p.price == p.price.roundToDouble()
                  ? p.price.toInt().toString()
                  : p.price.toStringAsFixed(2))
              : '';
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
    final receivedVal = double.tryParse(_received.text.trim());

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
      if (receivedVal != null && receivedVal > 0)
        'amount_received': receivedVal,
      if (_paymentMethod != null && _paymentMethod!.isNotEmpty)
        'payment_method': _paymentMethod,
      if (_notes.text.trim().isNotEmpty) 'order_notes': _notes.text.trim(),
    };

    try {
      await widget.services.api.createOrder(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order created successfully')),
        );
        Navigator.of(context).pop(true);
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
    _received.dispose();
    _notes.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco(
    BuildContext context, {
    required String label,
    String? hint,
    Widget? prefix,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5);
    final fillColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefix: prefix,
      filled: true,
      fillColor: fillColor,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant,
      ),
      hintStyle: TextStyle(
        fontSize: 13,
        color: isDark ? const Color(0xFF666666) : const Color(0xFFA3A3A3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cs.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5);
    final cardBg = isDark ? const Color(0xFF171717) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final productPrice = _product?.price ?? 0.0;
    final closingVal = double.tryParse(_closing.text.trim()) ?? 0.0;
    final discount = (productPrice - closingVal).clamp(0.0, double.infinity);
    final needsApproval = _product != null && closingVal < productPrice;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF171717) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Order',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              'New sales invoice & customer plan',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // ── Preview banner ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tag_outlined,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Order Number:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                        ),
                      ),
                      child: const Text(
                        'AUTO-GENERATED',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Per team sequence',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Section 1: Customer Details ──
              _sectionCard(
                context,
                title: 'Customer Details',
                subtitle: 'Buyer contact and billing identity',
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: _inputDeco(
                      context,
                      label: 'Customer Name *',
                      hint: 'Full name or company name',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Customer name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 125,
                        child: DropdownButtonFormField<String>(
                          initialValue: _countryCode,
                          isExpanded: true,
                          decoration: _inputDeco(context, label: 'Country'),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneLocal,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDeco(
                            context,
                            label: 'Phone Number',
                            hint: '9876543210',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDeco(
                      context,
                      label: 'Customer Email',
                      hint: 'name@example.com',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Section 2: Product & Subscription ──
              _sectionCard(
                context,
                title: 'Product & Duration',
                subtitle: 'Select from catalog or configure manually',
                children: [
                  if (_loadingProducts)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: LeadxFlickrLoading(size: 28),
                      ),
                    )
                  else
                    DropdownButtonFormField<Product?>(
                      initialValue: _product,
                      isExpanded: true,
                      decoration: _inputDeco(context, label: 'Product Catalog'),
                      items: [
                        const DropdownMenuItem<Product?>(
                          value: null,
                          child: Text(
                            '— none (enter manually) —',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        ..._products.map(
                          (p) => DropdownMenuItem<Product?>(
                            value: p,
                            child: Text(
                              '${p.name} (${Fmt.money(p.price)} — ${kOrderDurations[p.duration] ?? p.duration})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: _onProductSelected,
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _productName,
                    decoration: _inputDeco(
                      context,
                      label: 'Product Name',
                      hint: 'Plan title or license type',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _duration,
                    isExpanded: true,
                    decoration: _inputDeco(context, label: 'Subscription Duration *'),
                    items: kOrderDurations.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _duration = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Section 3: Financials & Pricing ──
              _sectionCard(
                context,
                title: 'Deal Financials',
                subtitle: 'Closing value and discount approval rules',
                children: [
                  TextFormField(
                    controller: _closing,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDeco(
                      context,
                      label: 'Closing Value (${Fmt.live.symbol}) *',
                      hint: '0.00',
                    ),
                    onChanged: (_) {
                      _closingWasAutoSet = false;
                      setState(() {});
                    },
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
                  if (_product != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        children: [
                          _summaryRow(
                            'Catalog Price',
                            Fmt.money(_product!.price),
                            isDark: isDark,
                          ),
                          if (_product!.minimumClosingPrice > 0) ...[
                            const SizedBox(height: 6),
                            _summaryRow(
                              'Minimum Price Floor',
                              Fmt.money(_product!.minimumClosingPrice),
                              isDark: isDark,
                            ),
                          ],
                          if (discount > 0) ...[
                            const SizedBox(height: 6),
                            _summaryRow(
                              'Offered Discount',
                              '- ${Fmt.money(discount)}',
                              isDark: isDark,
                              color: const Color(0xFFD97706),
                            ),
                          ],
                          const Divider(height: 16, thickness: 1),
                          _summaryRow(
                            'Final Deal Value',
                            Fmt.money(closingVal),
                            isDark: isDark,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    if (needsApproval) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 16,
                              color: Color(0xFFB45309),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Discounted deal: Order will be submitted for Super Admin closing approval.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ── Section 4: Initial Payment (Optional) ──
              _sectionCard(
                context,
                title: 'Initial Payment (Optional)',
                subtitle: 'Record an upfront deposit or full settlement',
                children: [
                  TextFormField(
                    controller: _received,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDeco(
                      context,
                      label: 'Amount Collected (${Fmt.live.symbol})',
                      hint: '0.00',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _paymentMethod,
                    isExpanded: true,
                    decoration: _inputDeco(context, label: 'Payment Method'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('— Not collected upfront —', style: TextStyle(fontSize: 13)),
                      ),
                      ...kOrderPaymentMethods.entries.map(
                        (e) => DropdownMenuItem<String?>(
                          value: e.key,
                          child: Text(e.value, style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _paymentMethod = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Section 5: Order Notes ──
              _sectionCard(
                context,
                title: 'Order Notes',
                subtitle: 'Internal remarks or fulfillment instructions',
                children: [
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: _inputDeco(
                      context,
                      label: 'Notes (Optional)',
                      hint: 'Special requests, terms agreed, or installation notes…',
                    ),
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Action Buttons ──
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : const Color(0xFF171717),
                    foregroundColor: isDark ? const Color(0xFF171717) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _busy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? const Color(0xFF171717) : Colors.white,
                          ),
                        )
                      : const Text(
                          'Create Order',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onSurface,
                    side: BorderSide(
                      color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    required bool isDark,
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            fontFamily: 'Courier',
            color: color ?? (isDark ? Colors.white : const Color(0xFF111827)),
          ),
        ),
      ],
    );
  }
}
