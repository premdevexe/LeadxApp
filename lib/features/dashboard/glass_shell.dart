import 'package:flutter/material.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/lead_glass.dart';
import '../customers/customers_screen.dart';
import '../follow_ups/follow_ups_screen.dart';
import '../orders/orders_screen.dart';
import 'crm_hub_sheet.dart';
import 'dashboard_screen.dart';

/// The (retired) authenticated shell kept behind the solid [HomeShell]
/// routing. Its navigation chrome now resolves through the gated
/// [LeadGlass] helpers: with the glass gate forced off (today, always),
/// [LeadGlass.navBar] renders a solid Material [NavigationBar] and each
/// tab page draws its own top chrome via Veneer's `NativeNavigationBar`
/// — no per-page backdrop groups. The kit glass dock and floating
/// "Executive Hub" pill remain reachable behind the [LeadGlass.enabled]
/// gate for a future back-out.
class GlassShell extends StatefulWidget {
  const GlassShell({super.key});

  @override
  State<GlassShell> createState() => _GlassShellState();
}

class _GlassShellState extends State<GlassShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final screens = <Widget>[
      const DashboardScreen(),
      const OrdersScreen(),
      const FollowUpsScreen(),
      const CustomersScreen(),
    ];

    // Quiet neutral backdrop that the glass surfaces refract. Each tab
    // screen owns its own top-inset handling (Veneer top bars), so no
    // extra SafeArea here.
    final background = Container(
      color: isDark
          ? AppColors.neutralBgDark
          : AppColors.neutralBgLight,
    );

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          Positioned.fill(child: background),
          // Each tab screen draws its own top chrome (Veneer native bars);
          // no per-page backdrop groups. The solid Material stack keeps the
          // offstage screens warm the way the old glass groups did.
          IndexedStack(index: _index, children: screens),
          // ── Kit glass dock + floating Executive Hub action ─────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Builder(
              builder: (context) {
                final isGlass = LeadGlass.enabled(context);
                final labelColor = isDark ? Colors.white : cs.primary;
                return SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Stack(
                    children: [
                      LeadGlass.navBar(
                        context,
                        _index,
                        (i) => setState(() => _index = i),
                      ),
                      if (isGlass)
                        Positioned(
                          top: -4,
                          right: 0,
                          child: LeadGlass.button(
                            context,
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome,
                                    size: 17, color: labelColor),
                                const SizedBox(width: 6),
                                Text(
                                  'Executive Hub',
                                  style: TextStyle(
                                    color: labelColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                            onPressed: () => showCrmHubSheet(context),
                            primary: true,
                            radius: 22,
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
