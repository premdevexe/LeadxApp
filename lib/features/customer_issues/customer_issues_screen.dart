import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/design/native_chrome.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/lead_glass.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/customer_issue.dart';
import '../../shared/widgets/app_widgets.dart';

class CustomerIssuesScreen extends StatefulWidget {
  const CustomerIssuesScreen({super.key});

  @override
  State<CustomerIssuesScreen> createState() => _CustomerIssuesScreenState();
}

class _CustomerIssuesScreenState extends State<CustomerIssuesScreen> {
  List<CustomerIssue> _issues = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  String _statusFilter = '';
  int _totalCount = 0;
  int _stillFacingCount = 0;
  int _fixedCount = 0;

  // Create form state.
  final _customerIds = <int>[];
  final _customerNames = <int, String>{};
  int? _selectedCustomer;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final services = context.read<AppServices>();
    try {
      final res = await services.api.verifiedCustomers();
      final data = (res['data'] as List<dynamic>?) ?? const [];
      for (var e in data) {
        final m = e as Map;
        _customerIds.add(m['id'] as int);
        _customerNames[m['id'] as int] = m['name'] as String? ?? '';
      }
      if (mounted) setState(() {});
    } on ApiException {
      // Picker empty: create will be blocked gracefully.
    }
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    setState(() {
      _loading = _issues.isEmpty;
      _error = null;
    });
    try {
      final res = await services.api.customerIssues(
        status: _statusFilter.isEmpty ? null : _statusFilter,
        page: _page,
      );
      final data = (res['data'] as List<dynamic>?) ?? const [];
      _issues = data
          .map((e) => CustomerIssue.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = (res['meta'] as Map<String, dynamic>?) ?? const {};
      _lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
      _totalCount = (meta['total_issues'] as num?)?.toInt() ??
          (_statusFilter.isEmpty ? _issues.length : _totalCount);
      _stillFacingCount = (meta['still_facing_issues'] as num?)?.toInt() ??
          (_statusFilter.isEmpty
              ? _issues.where((i) => i.status.toLowerCase() != 'fixed').length
              : _stillFacingCount);
      _fixedCount = (meta['fixed_issues'] as num?)?.toInt() ??
          (_statusFilter.isEmpty
              ? _issues.where((i) => i.status.toLowerCase() == 'fixed').length
              : _fixedCount);
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

  Future<void> _loadMore() async {
    if (_page >= _lastPage) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final services = context.read<AppServices>();
    try {
      final res = await services.api.customerIssues(
        status: _statusFilter.isEmpty ? null : _statusFilter,
        page: nextPage,
      );
      final data = (res['data'] as List<dynamic>?) ?? const [];
      final more = data
          .map((e) => CustomerIssue.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _issues.addAll(more);
        _page = nextPage;
        _loadingMore = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _create() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a customer')));
      return;
    }
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and description required')),
      );
      return;
    }

    setState(() => _busy = true);
    final services = context.read<AppServices>();
    try {
      await services.api.createCustomerIssue({
        'customer_id': _selectedCustomer,
        'issue_title': _titleCtrl.text.trim(),
        'issue_description': _descCtrl.text.trim(),
      });
      _titleCtrl.clear();
      _descCtrl.clear();
      if (mounted) setState(() => _busy = false);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Issue reported')));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.isValidation
                ? (e.fieldErrors.values.isNotEmpty
                      ? e.fieldErrors.values.first.first
                      : 'Validation failed')
                : e.message,
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _markFixed(CustomerIssue issue) async {
    final services = context.read<AppServices>();
    try {
      await services.api.updateCustomerIssue(issue.id, {'status': 'fixed'});
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Marked as fixed')));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final filterOptions = const ['', 'still_facing', 'fixed'];
    final selectedFilterIndex = filterOptions.indexOf(_statusFilter);
    final validIndex = selectedFilterIndex >= 0 ? selectedFilterIndex : 0;

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: LeadGlass.segmentBar(
            context,
            const ['All', 'Still facing', 'Fixed'],
            validIndex,
            (i) {
              setState(() {
                _statusFilter = filterOptions[i];
                _page = 1;
              });
              _load();
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading && _issues.isEmpty
              ? const LoadingScreen()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _error != null && _issues.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            ErrorBanner(message: _error!, onRetry: _load),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          children: [
                            // Summary Cards mirroring customer_issues/index.blade.php
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  _IssueSummaryCard(
                                    title: 'Total',
                                    count: _totalCount,
                                    subtitle: 'All logged',
                                    accentColor: const Color(0xFF64748B),
                                    isSelected: _statusFilter.isEmpty,
                                    onTap: () {
                                      setState(() {
                                        _statusFilter = '';
                                        _page = 1;
                                      });
                                      _load();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _IssueSummaryCard(
                                    title: 'Still Facing',
                                    count: _stillFacingCount,
                                    subtitle: 'Pending',
                                    accentColor: const Color(0xFFD97706),
                                    isSelected: _statusFilter == 'still_facing',
                                    onTap: () {
                                      setState(() {
                                        _statusFilter = 'still_facing';
                                        _page = 1;
                                      });
                                      _load();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _IssueSummaryCard(
                                    title: 'Fixed',
                                    count: _fixedCount,
                                    subtitle: 'Resolved',
                                    accentColor: const Color(0xFF059669),
                                    isSelected: _statusFilter == 'fixed',
                                    onTap: () {
                                      setState(() {
                                        _statusFilter = 'fixed';
                                        _page = 1;
                                      });
                                      _load();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (_issues.isEmpty)
                              const EmptyState(
                                title: 'No issues yet',
                                subtitle:
                                    'Report customer issues from the + button.',
                                icon: Icons.support_agent_outlined,
                              )
                            else
                              ..._issues.map(
                                (i) => _IssueCard(
                                  issue: i,
                                  onMarkFixed: () => _markFixed(i),
                                ),
                              ),
                            if (_loadingMore)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_page < _lastPage)
                              Center(
                                child: TextButton(
                                  onPressed: _loadMore,
                                  child: const Text('Load more'),
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],
                        ),
                ),
        ),
      ],
    );

    return Scaffold(
      body: NativeNavigationBar(
        leading: canPop
            ? NativeBarButton(
                icon: const NativeIcon.symbol(
                  'chevron.left',
                  fallback: Icons.arrow_back,
                ),
                title: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: NativeBarTitle(
          title: 'Customer Issues',
          subtitle: '${_issues.length} tickets',
          capsule: true,
          icon: const NativeIcon.symbol(
            'exclamationmark.bubble',
            fallback: Icons.report_problem_outlined,
          ),
        ),
        trailing: [
          NativeBarButton(
            icon: const NativeIcon.symbol('plus', fallback: Icons.add),
            title: 'Report',
            prominent: true,
            group: 1,
            onPressed: () => _showCreate(context),
          ),
          NativeBarButton(
            icon: const NativeIcon.symbol(
              'arrow.clockwise',
              fallback: Icons.refresh,
            ),
            title: 'Refresh',
            group: 0,
            onPressed: _load,
          ),
        ],
        child: content,
      ),
    );
  }

  /// Public wrapper so the (Stateless) [_ReportIssueForm] can update the
  /// selected customer without reaching into the protected [State.setState].
  void selectCustomer(int? id) => setState(() => _selectedCustomer = id);

  void _showCreate(BuildContext context) {
    showNativeSheet(
      context: context,
      detents: const [
        NativeSheetDetent.fraction(0.72),
        NativeSheetDetent.large,
      ],
      initialDetent: const NativeSheetDetent.fraction(0.72),
      showGrabber: true,
      builder: (_) => _ReportIssueForm(state: this),
    );
  }
}

/// "Report an issue" form — the same solid content whether it presents in a
/// glass modal sheet or a plain Material bottom sheet.
class _ReportIssueForm extends StatelessWidget {
  const _ReportIssueForm({required this.state});

  final _CustomerIssuesScreenState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Report an issue',
                  style: AppTypography.sectionTitle.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                LeadGlass.field(
                  context,
                  DropdownButtonFormField<int>(
                    initialValue: s._selectedCustomer,
                    isExpanded: true,
                    decoration: LeadGlass.fieldDecoration(
                      context,
                      label: 'Customer *',
                    ),
                    // Each row shows *its own* customer's name.
                    items: s._customerIds
                        .map(
                          (id) => DropdownMenuItem(
                            value: id,
                            child: Text(
                              s._customerNames[id]?.isNotEmpty == true
                                  ? s._customerNames[id]!
                                  : 'Customer $id',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) => s.selectCustomer(id),
                  ),
                ),
                const SizedBox(height: 12),
                LeadGlass.field(
                  context,
                  TextFormField(
                    controller: s._titleCtrl,
                    decoration: LeadGlass.fieldDecoration(
                      context,
                      label: 'Issue title *',
                    ),
                    maxLength: 255,
                  ),
                ),
                const SizedBox(height: 12),
                LeadGlass.field(
                  context,
                  TextFormField(
                    controller: s._descCtrl,
                    decoration: LeadGlass.fieldDecoration(
                      context,
                      label: 'Description *',
                    ),
                    maxLength: 5000,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(height: 20),
                AppPrimaryButton(
                  onPressed: s._busy ? null : s._create,
                  label: 'Report issue',
                  loading: s._busy,
                  height: 50,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue, required this.onMarkFixed});

  final CustomerIssue issue;
  final VoidCallback onMarkFixed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final fixed = issue.status.toLowerCase() == 'fixed';
    return NativeContextMenu(
      borderRadius: BorderRadius.circular(14),
      items: [
        if (!fixed)
          NativeMenuItem(
            title: 'Mark as Resolved',
            icon: const NativeIcon.symbol(
              'checkmark.circle',
              fallback: Icons.check_circle_outline,
            ),
            onSelected: onMarkFixed,
          ),
        NativeMenuItem(
          title: 'Copy Issue Details',
          icon: const NativeIcon.symbol('doc.on.doc', fallback: Icons.copy),
          onSelected: () {
            final text =
                '${issue.issueTitle} - ${issue.customerName ?? 'Customer'}';
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Copied "$text" to clipboard')),
            );
          },
        ),
      ],
      child: AppCard.surface(
        context,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    issue.issueTitle,
                    style: AppTypography.cardTitle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(
                  fixed ? 'Resolved' : 'Active',
                  color: fixed
                      ? StatusPalette.success(cs)
                      : StatusPalette.warning(cs),
                ),
              ],
            ),
            if (issue.issueDescription != null &&
                issue.issueDescription!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                issue.issueDescription!,
                style: AppTypography.secondary.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '${issue.customerName ?? 'Customer'} · ${Fmt.date(issue.issueDate)}',
              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
            ),
            if (!fixed) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFBBF7D0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: isDark
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFF166534),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mark as Resolved',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFF166534),
                        ),
                      ),
                    ),
                    Material(
                      color: isDark
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: onMarkFixed,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Resolve',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IssueSummaryCard extends StatelessWidget {
  const _IssueSummaryCard({
    required this.title,
    required this.count,
    required this.subtitle,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final int count;
  final String subtitle;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final border = isSelected
        ? Border.all(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            width: 1.5,
          )
        : Border.all(
            color: isDark ? const Color(0xFF2E2E34) : const Color(0xFFE2E8F0),
            width: 1,
          );

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: border,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
