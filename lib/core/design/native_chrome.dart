import 'package:flutter/material.dart';

/// Solid Material 3 stand-ins for the retired veneer chrome engine.
///
/// The restored feature screens were written against the `veneer` package's
/// `Native*` widgets (native bars, sheets, context menus, search toolbar,
/// prompt composer). The glass/native layer is out of this build, so this
/// module re-implements exactly that API surface with plain, solid Material
/// — same class names, same parameters, no glass, no native bridge.
///
/// Import this instead of `package:veneer/veneer.dart`.

// ── Icons ────────────────────────────────────────────────────────────────────

/// A native icon descriptor. Only the [NativeIcon.symbol] factory is used in
/// the app — every call site supplies a Material [fallback], which is what
/// actually renders.
sealed class NativeIcon {
  const NativeIcon();
  const factory NativeIcon.symbol(String name, {IconData? fallback}) =
      NativeSymbolIcon;
}

final class NativeSymbolIcon extends NativeIcon {
  const NativeSymbolIcon(this.name, {this.fallback});
  final String name;
  final IconData? fallback;
}

IconData nativeIconData(NativeIcon icon, {double size = 18, Color? color}) =>
    (icon as NativeSymbolIcon).fallback ?? Icons.circle_outlined;

// ── Menu items ───────────────────────────────────────────────────────────────

class NativeMenuItem {
  const NativeMenuItem({
    required this.title,
    this.subtitle,
    this.icon,
    this.onSelected,
    this.destructive = false,
    this.checked = false,
    this.enabled = true,
    this.iconSize,
  }) : isDivider = false;

  /// Separates the items before it from those after.
  const NativeMenuItem.divider()
      : title = '',
        subtitle = null,
        icon = null,
        onSelected = null,
        destructive = false,
        checked = false,
        enabled = true,
        iconSize = null,
        isDivider = true;

  final String title;
  final String? subtitle;
  final NativeIcon? icon;
  final VoidCallback? onSelected;
  final bool destructive;
  final bool checked;
  final bool enabled;
  final double? iconSize;
  final bool isDivider;
}

/// Builds [PopupMenuEntry]s from [NativeMenuItem]s (icon + optional
/// subtitle; destructive items render in the error colour; checked items
/// get a leading check mark).
List<PopupMenuEntry<String>> nativeMenuEntries(
  BuildContext context,
  List<NativeMenuItem> items, {
  required ColorScheme cs,
}) {
  return [
    for (var i = 0; i < items.length; i++)
      if (items[i].isDivider)
        const PopupMenuDivider()
      else
        PopupMenuItem<String>(
          value: 'i$i',
          enabled: items[i].enabled,
          child: _NativeMenuItemRow(
            context: context,
            item: items[i],
            cs: cs,
          ),
        ),
  ];
}

class _NativeMenuItemRow extends StatelessWidget {
  const _NativeMenuItemRow({
    required this.context,
    required this.item,
    required this.cs,
  });

  final BuildContext context;
  final NativeMenuItem item;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final color = item.destructive
        ? cs.error
        : item.enabled
            ? cs.onSurface
            : cs.onSurfaceVariant.withValues(alpha: 0.4);
    return Row(
      children: [
        if (item.checked)
          Icon(Icons.check_rounded, size: item.iconSize ?? 18, color: color)
        else if (item.icon != null)
          Icon(nativeIconData(item.icon!),
              size: item.iconSize ?? 18,
              color: item.destructive ? cs.error : cs.onSurfaceVariant),
        if ((item.checked || item.icon != null) && item.title.isNotEmpty)
          const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: item.checked ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
              if (item.subtitle != null && item.subtitle!.isNotEmpty)
                Text(
                  item.subtitle!,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A long-press context menu: the solid cousin of the native `UIMenu`.
class NativeContextMenu extends StatelessWidget {
  const NativeContextMenu({
    super.key,
    required this.items,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final List<NativeMenuItem> items;
  final Widget child;
  final BorderRadius borderRadius;

  Future<void> _show(BuildContext context, Offset position) async {
    final cs = Theme.of(context).colorScheme;
    // Open the menu at the long-press point; `showMenu` clamps it to stay
    // on screen. This Flutter version's `showMenu` answers with the chosen
    // value (no `onSelected` parameter) and takes a [RelativeRect].
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Offset(position.dx, position.dy) & const Size(1, 1),
        Rect.fromLTWH(0, 0, context.size?.width ?? 360, 1000),
      ),
      items: nativeMenuEntries(context, items, cs: cs),
    );
    if (picked != null) {
      final i = int.parse(picked.substring(1));
      if (i < items.length) items[i].onSelected?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return child;
    return GestureDetector(
      onLongPressStart: (d) => _show(context, d.globalPosition),
      child: child,
    );
  }
}

// ── Navigation bar ───────────────────────────────────────────────────────────

class NativeBarTitle {
  const NativeBarTitle({
    required this.title,
    this.subtitle,
    this.icon,
    this.capsule = false,
    this.onPressed,
  });

  final String title;
  final String? subtitle;
  final NativeIcon? icon;
  final bool capsule;
  final VoidCallback? onPressed;
}

class NativeBarButton {
  const NativeBarButton({
    this.icon,
    this.title,
    this.onPressed,
    this.menu,
    this.badge,
    this.prominent = false,
    this.group = 0,
    this.showsTitle = false,
  }) : assert(icon != null || title != null);

  final NativeIcon? icon;
  final String? title;
  final VoidCallback? onPressed;
  final List<NativeMenuItem>? menu;
  final String? badge;
  final bool prominent;
  final int group;
  final bool showsTitle;
}

/// A solid top navigation bar: back button (or an auto drawer toggle when
/// the surrounding [Scaffold] owns a drawer), a title (plain or in a quiet
/// capsule), and trailing icon actions with optional badges and menus.
class NativeNavigationBar extends StatelessWidget {
  const NativeNavigationBar({
    super.key,
    this.leading,
    this.title,
    this.trailing = const [],
    required this.child,
  });

  final NativeBarButton? leading;
  final NativeBarTitle? title;
  final List<NativeBarButton> trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hairline = cs.outlineVariant.withValues(alpha: 0.5);
    final topInset = MediaQuery.paddingOf(context).top;

    // No explicit leading and an ancestor scaffold owns a drawer → the bar
    // grows a hamburger that opens it (tab pages under HomeShell).
    final scaffold = Scaffold.maybeOf(context);
    NativeBarButton? lead = leading;
    if (lead == null && (scaffold?.hasDrawer ?? false)) {
      lead = NativeBarButton(
        icon: NativeIcon.symbol('line.3.horizontal', fallback: Icons.menu_rounded),
        title: 'Menu',
        onPressed: () => scaffold!.openDrawer(),
      );
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.only(top: topInset),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              bottom: BorderSide(color: hairline, width: 1),
            ),
          ),
          height: topInset + 56,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  if (lead != null)
                    _LeadingButton(button: lead)
                  else
                    const SizedBox(width: 32),
                  const SizedBox(width: 8),
                  Expanded(child: _BarTitle(title: title)),
                  ...[
                    for (final b in trailing)
                      _TrailingButton(button: b, cs: cs),
                  ],
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _LeadingButton extends StatelessWidget {
  const _LeadingButton({required this.button});

  final NativeBarButton button;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (button.menu != null && button.menu!.isNotEmpty) {
      return PopupMenuButton<String>(
        tooltip: button.title,
        padding: const EdgeInsets.all(4),
        icon: Icon(
          nativeIconData(button.icon!),
          size: 20,
          color: cs.onSurface,
        ),
        itemBuilder: (_) => nativeMenuEntries(context, button.menu!, cs: cs),
        onSelected: (v) {
          button.menu![int.parse(v.substring(1))].onSelected?.call();
        },
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: button.onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            nativeIconData(button.icon ?? const NativeIcon.symbol('', fallback: Icons.menu_rounded)),
            size: 20,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _BarTitle extends StatelessWidget {
  const _BarTitle({required this.title});

  final NativeBarTitle? title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (title == null || title!.title.isEmpty) return const SizedBox.shrink();
    final t = title!;
    final inner = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (t.icon != null) ...[
          Icon(nativeIconData(t.icon!), size: 18, color: cs.onSurface),
          const SizedBox(width: 6),
        ],
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            if (t.subtitle != null && t.subtitle!.isNotEmpty)
              Text(
                t.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ],
    );
    if (!t.capsule) {
      return Center(child: inner);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: inner,
        ),
      ),
    );
  }
}

class _TrailingButton extends StatelessWidget {
  const _TrailingButton({required this.button, required this.cs});

  final NativeBarButton button;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final iconData = nativeIconData(
      button.icon ?? const NativeIcon.symbol('', fallback: Icons.more_vert),
    );
    final badge = button.badge;

    Widget badgeChip(Widget child) => badge == null
        ? child
        : Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badge,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          );

    if (button.menu != null && button.menu!.isNotEmpty) {
      return badgeChip(
        PopupMenuButton<String>(
          tooltip: button.title,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          icon: Icon(iconData, size: 20, color: cs.onSurface),
          itemBuilder: (_) => nativeMenuEntries(context, button.menu!, cs: cs),
          onSelected: (v) {
            button.menu![int.parse(v.substring(1))].onSelected?.call();
          },
        ),
      );
    }

    if (button.prominent) {
      return badgeChip(
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: button.onPressed,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconData, size: 16, color: cs.onPrimary),
                  if (button.showsTitle && button.title != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      button.title!,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return badgeChip(
      Material(
        type: MaterialType.transparency,
        child: Tooltip(
          message: button.title ?? '',
          child: InkWell(
            onTap: button.onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(iconData, size: 20, color: cs.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sheets ───────────────────────────────────────────────────────────────────

class NativeSheetDetent {
  const NativeSheetDetent.fraction(double fraction)
      : _fraction = fraction,
        _height = null;
  const NativeSheetDetent.height(double height)
      : _fraction = null,
        _height = height;
  const NativeSheetDetent.content()
      : _fraction = null,
        _height = null;

  static const large = NativeSheetDetent.fraction(1.0);
  static const medium = NativeSheetDetent.fraction(0.5);

  final double? _fraction;
  final double? _height;

  double? get fraction => _fraction;
  double? get height => _height;
}

/// Presents [builder] in a draggable bottom sheet that rests at the given
/// detents (the solid stand-in for the native `UISheetPresentationController`).
Future<T?> showNativeSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  List<NativeSheetDetent> detents = const [NativeSheetDetent.large],
  NativeSheetDetent? initialDetent,
  bool? showGrabber,
  bool isDismissible = true,
  Color? backgroundColor,
  String? entrypoint,
}) {
  final fractions = [
    for (final d in detents) d.fraction ?? 1.0,
  ];
  double minF = 1.0;
  double maxF = 0.0;
  for (final f in fractions) {
    if (f < minF) minF = f;
    if (f > maxF) maxF = f;
  }
  final initial =
      detents.isEmpty ? 0.65 : (initialDetent?.fraction ?? fractions.last);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final grabber = showGrabber ?? (detents.length > 1);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: initial.clamp(0.2, 1.0),
        minChildSize: minF.clamp(0.2, 1.0),
        maxChildSize: maxF.clamp(minF, 1.0),
        builder: (_, scrollController) {
          final cs = Theme.of(context).colorScheme;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor ?? cs.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (grabber)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  // The content screens own their own scroll views; the
                  // sheet's controller is only needed when the child wants
                  // it, so a plain expanded slot is the safe default.
                  child: builder(ctx),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Handle to dismiss an open solid sheet from inside it.
abstract final class NativeSheet {
  static Future<void> close(BuildContext context, [Object? result]) async {
    Navigator.of(context).maybePop(result);
  }
}

// ── Alerts ───────────────────────────────────────────────────────────────────

enum NativeAlertActionStyle { normal, cancel, destructive }

class NativeAlertAction {
  const NativeAlertAction({
    required this.title,
    this.style = NativeAlertActionStyle.normal,
    this.preferred = false,
  });

  final String title;
  final NativeAlertActionStyle style;
  final bool preferred;
}

/// Solid [AlertDialog] stand-in; answers with the picked action's index
/// (null when dismissed by barrier).
Future<int?> showNativeAlert({
  required BuildContext context,
  required String title,
  String? message,
  Color? tint,
  List<NativeAlertAction> actions = const [],
  bool barrierDismissible = true,
}) {
  return showDialog<int>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      final cs = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: [
          for (var i = 0; i < actions.length; i++)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(i),
              child: Text(
                actions[i].title,
                style: TextStyle(
                  fontWeight:
                      actions[i].preferred ? FontWeight.w600 : FontWeight.w500,
                  color: actions[i].style == NativeAlertActionStyle.destructive
                      ? cs.error
                      : actions[i].preferred
                          ? (tint ?? cs.primary)
                          : cs.onSurface,
                ),
              ),
            ),
        ],
      );
    },
  );
}

// ── Search toolbar ───────────────────────────────────────────────────────────

/// A bottom-anchored search field riding above its content (the solid
/// stand-in for the system search bar).
class NativeSearchToolbar extends StatefulWidget {
  const NativeSearchToolbar({
    super.key,
    required this.placeholder,
    required this.child,
    this.controller,
    this.autofocus = true,
    this.onChanged,
    this.onSubmitted,
    this.onFocusChanged,
    this.onClose,
    this.closeLabel,
  });

  final String placeholder;
  final Widget child;
  final TextEditingController? controller;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback? onClose;
  final String? closeLabel;

  @override
  State<NativeSearchToolbar> createState() => NativeSearchToolbarState();
}

class NativeSearchToolbarState extends State<NativeSearchToolbar> {
  final _focus = FocusNode();
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _controller.addListener(() => widget.onChanged?.call(_controller.text));
    }
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(_focus);
      });
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hairline = cs.outlineVariant.withValues(alpha: 0.5);
    return Column(
      children: [
        Expanded(child: widget.child),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: hairline, width: 1)),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(fontSize: 15, color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: widget.placeholder,
                      hintStyle: TextStyle(color: cs.onSurfaceVariant),
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      errorStyle: const TextStyle(height: 0),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: widget.closeLabel ?? 'Close search',
                  onPressed: widget.onClose,
                  icon: Icon(Icons.close, size: 20, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Prompt composer ──────────────────────────────────────────────────────────

/// Text state shared with a [NativePromptComposer].
class NativeComposerController extends ChangeNotifier {
  NativeComposerController({String text = ''})
      : _text = text; // ignore: prefer_initializing_formals

  String _text;

  String get text => _text;

  set text(String value) => setText(value);

  void setText(String value) {
    if (value == _text) return;
    _text = value;
    notifyListeners();
  }
}

class NativeComposerButton {
  const NativeComposerButton({
    required this.icon,
    this.title,
    this.onPressed,
    this.menu,
    this.prominent = false,
  });

  final NativeIcon icon;
  final String? title;
  final VoidCallback? onPressed;
  final List<NativeMenuItem>? menu;
  final bool prominent;
}

/// A bottom composer bar (field + action buttons) above its [child].
class NativePromptComposer extends StatefulWidget {
  const NativePromptComposer({
    super.key,
    this.controller,
    this.placeholder,
    this.leading,
    this.actions = const [],
    this.primaryAction,
    this.stopAction,
    this.onSend,
    this.onChanged,
    required this.child,
  });

  final NativeComposerController? controller;
  final String? placeholder;
  final NativeComposerButton? leading;
  final List<NativeComposerButton> actions;
  final NativeComposerButton? primaryAction;
  final NativeComposerButton? stopAction;
  final ValueChanged<String>? onSend;
  final ValueChanged<String>? onChanged;
  final Widget child;

  @override
  State<NativePromptComposer> createState() => _NativePromptComposerState();
}

class _NativePromptComposerState extends State<NativePromptComposer> {
  final _fieldCtrl = TextEditingController();

  @override
  void dispose() {
    _fieldCtrl.dispose();
    super.dispose();
  }

  void _send(String text) => widget.onSend?.call(text);

  Widget _composerButton(NativeComposerButton b) {
    final cs = Theme.of(context).colorScheme;
    final icon = nativeIconData(b.icon, size: 20);
    if (b.menu != null && b.menu!.isNotEmpty) {
      return PopupMenuButton<String>(
        tooltip: b.title,
        padding: const EdgeInsets.all(4),
        icon: Icon(icon, color: cs.onSurfaceVariant),
        itemBuilder: (_) => nativeMenuEntries(context, b.menu!, cs: cs),
        onSelected: (v) {
          b.menu![int.parse(v.substring(1))].onSelected?.call();
        },
      );
    }
    if (b.prominent || b == widget.primaryAction) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.primary,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _send(_fieldCtrl.text),
            child: Center(
              child: Icon(icon, color: cs.onPrimary, size: 20),
            ),
          ),
        ),
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: Tooltip(
        message: b.title ?? '',
        child: InkWell(
          onTap: b.onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hairline = cs.outlineVariant.withValues(alpha: 0.5);
    return Column(
      children: [
        Expanded(child: widget.child),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: hairline, width: 1)),
            ),
            child: Row(
              children: [
                if (widget.leading != null) _composerButton(widget.leading!),
                ...widget.actions.map(_composerButton),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: TextField(
                      controller: _fieldCtrl,
                      onChanged: widget.onChanged,
                      onSubmitted: _send,
                      maxLines: 1,
                      style: TextStyle(fontSize: 14, color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        hintStyle:
                            TextStyle(color: cs.onSurfaceVariant),
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 10),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                if (widget.primaryAction != null) ...[
                  const SizedBox(width: 8),
                  _composerButton(widget.primaryAction!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Segmented control ────────────────────────────────────────────────────────

/// A solid pill segment bar (the stand-in for the native segmented control).
class NativeSegmentedControl extends StatelessWidget {
  const NativeSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onValueChanged,
    this.selectedColor,
    this.selectedTextColor,
    this.height = 44,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onValueChanged;
  final Color? selectedColor;
  final Color? selectedTextColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = selectedColor ?? cs.primary;
    final activeInk = selectedTextColor ?? cs.onPrimary;
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => onValueChanged(i),
                  borderRadius: BorderRadius.circular(height / 2 - 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: i == selectedIndex
                          ? active
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(height / 2 - 8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            i == selectedIndex ? FontWeight.w600 : FontWeight.w500,
                        color: i == selectedIndex
                            ? activeInk
                            : cs.onSurfaceVariant,
                      ),
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

// ── Banners ──────────────────────────────────────────────────────────────────

enum NativeBannerStyle { standard }
