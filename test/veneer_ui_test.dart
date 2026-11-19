import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart' as fbi_test;
import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_kit/flutter_liquid_glass_kit.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:veneer/veneer.dart';

import 'package:leadx/core/design/app_colors.dart';
import 'package:leadx/core/design/lead_glass.dart';
import 'package:leadx/core/design/app_theme.dart';
import 'package:leadx/core/design/theme_controller.dart';
import 'package:leadx/core/network/api_client.dart';
import 'package:leadx/core/network/services.dart';
import 'package:leadx/core/services/app_config_service.dart';
import 'package:leadx/core/services/app_services.dart';
import 'package:leadx/core/utils/native_banner_helper.dart';
import 'package:leadx/features/auth/auth_controller.dart';
import 'package:leadx/features/calendar/calendar_screen.dart';
import 'package:leadx/features/customer_issues/customer_issues_screen.dart';
import 'package:leadx/features/dashboard/crm_hub_sheet.dart';
import 'package:leadx/features/dashboard/dashboard_screen.dart';
import 'package:leadx/features/dashboard/glass_shell.dart';
import 'package:leadx/features/dashboard/home_shell.dart';
import 'package:leadx/features/orders/orders_screen.dart';
import 'package:leadx/features/payments/payments_screen.dart';
import 'package:leadx/features/performance/performance_screen.dart';
import 'package:leadx/features/profile/profile_screen.dart';
import 'package:leadx/features/search/global_search_screen.dart';
import 'package:leadx/features/subscriptions/subscriptions_screen.dart';

class FakeLeadxApi extends LeadxApi {
  FakeLeadxApi() : super(ApiClient.shared);

  @override
  Future<Map<String, dynamic>> orders({String view = 'my_data', int page = 1, int perPage = 20}) async {
    return {
      'data': [
        {
          'id': 101,
          'order_number': 'ORD-2026-001',
          'customer_name': 'Acme Corp',
          'customer_phone': '+1234567890',
          'customer_email': 'acme@example.com',
          'closing_value': 1500.0,
          'amount_received': 1500.0,
          'payment_status': 'completed',
          'order_status': 'confirmed',
          'created_at': '2026-11-17T10:00:00Z',
        }
      ],
      'meta': {'current_page': 1, 'last_page': 1, 'total': 1}
    };
  }

  @override
  Future<Map<String, dynamic>> dashboard({String view = 'my_data'}) async {
    return {
      'summary': {
        'verified_revenue': 125000.0,
        'closing_value': 150000.0,
        'total_orders': 45,
        'monthly_orders': 12,
        'pending_payments_count': 3,
        'customers_count': 28,
        'active_subscriptions': 19,
      },
      'monthly_sales_chart': [],
      'recent_follow_ups': [],
      'recent_orders': [],
      'recent_notifications': [],
      'expiring_subscriptions': [],
    };
  }

  @override
  Future<Map<String, dynamic>> customers({String view = 'my_data', int page = 1, int perPage = 20}) async {
    return {
      'data': [
        {
          'id': 1,
          'name': 'John Doe',
          'phone': '+1234567890',
          'email': 'john@example.com',
          'status': 'active',
          'total_purchased': 2500.0,
          'purchases_count': 2,
        }
      ],
      'meta': {'current_page': 1, 'last_page': 1, 'total': 1}
    };
  }

  @override
  Future<Map<String, dynamic>> followUps({
    String? status,
    int? customerId,
    String? followUpType,
    int page = 1,
    int perPage = 20,
  }) async {
    return {
      'data': [
        {
          'id': 1,
          'title': 'Contract Renewal Discussion',
          'customer_name': 'John Doe',
          'follow_up_type': 'call',
          'status': 'pending',
          'scheduled_at': '2026-11-20T10:00:00Z',
        }
      ],
      'meta': {'current_page': 1, 'last_page': 1, 'total': 1}
    };
  }

  @override
  Future<Map<String, dynamic>> subscriptions({
    String view = 'my_data',
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    return {
      'data': [
        {
          'id': 1,
          'product_name': 'Enterprise Plan',
          'customer_name': 'John Doe',
          'plan_name': 'Annual',
          'status': 'active',
          'order_id': 101,
          'expires_at': '2027-11-17T10:00:00Z',
        }
      ],
      'meta': {'current_page': 1, 'last_page': 1, 'total': 1}
    };
  }

  @override
  Future<Map<String, dynamic>> analytics({String? range}) async {
    return {
      'employee': {'id': 1, 'username': 'john', 'name': 'John Doe'},
      'overview': {
        'verified_revenue': '12345.67',
        'total_orders': 42,
        'total_paying_customers': 18,
        'active_subscriptions': 12,
        'expired_subscriptions': 3,
        'pending_collections': '2500.00',
        'total_closing_value': '15000.00',
        'total_discounts': '300.00',
        'total_product_value': '15300.00',
        'total_refunds': '150.00',
      },
      'products': [
        {
          'product_id': 1,
          'product': 'Enterprise Plan',
          'orders': 30,
          'collected_revenue': '10000.00',
          'active_subscriptions': 9,
          'active_customers': 8,
          'pending_collection': '2000.00',
        },
        {
          'product_id': null,
          'product': 'Uncataloged',
          'orders': 12,
          'collected_revenue': '2345.67',
          'active_subscriptions': 3,
          'active_customers': 4,
          'pending_collection': '500.00',
        },
      ],
      'monthly': [
        {'month': '2026-06', 'label': 'Jun 2026', 'revenue': '500.00', 'orders': 3, 'subscriptions': 2},
        {'month': '2026-07', 'label': 'Jul 2026', 'revenue': '1200.50', 'orders': 7, 'subscriptions': 2},
        {'month': '2026-08', 'label': 'Aug 2026', 'revenue': '800.00', 'orders': 5, 'subscriptions': 1},
        {'month': '2026-09', 'label': 'Sep 2026', 'revenue': '2400.00', 'orders': 10, 'subscriptions': 3},
        {'month': '2026-10', 'label': 'Oct 2026', 'revenue': '3100.00', 'orders': 9, 'subscriptions': 2},
        {'month': '2026-11', 'label': 'Nov 2026', 'revenue': '4345.17', 'orders': 8, 'subscriptions': 2},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> payments({String view = 'my_data', String filter = 'all', int page = 1, int perPage = 20}) async {
    return {
      'data': [
        {
          'id': 1,
          'order_id': 101,
          'amount': 1500.0,
          'currency': 'USD',
          'payment_method': 'card',
          'payment_status': 'completed',
          'verified': true,
          'created_at': '2026-11-17T10:00:00Z',
        }
      ],
      'meta': {'current_page': 1, 'last_page': 1, 'total': 1}
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    fbi_test.setupFirebaseCoreMocks();
    FlutterSecureStorage.setMockInitialValues({});
    await Firebase.initializeApp();
  });

  group('Veneer Theme & Extensions', () {
    test('AppTheme.light includes VeneerFallbackStyle with LeadX brand tokens', () {
      final theme = AppTheme.light();
      final veneerStyle = theme.extension<VeneerFallbackStyle>();
      expect(veneerStyle, isNotNull);
      expect(veneerStyle!.dark, isFalse);
      expect(veneerStyle.accent, equals(AppColors.brand));
      expect(veneerStyle.surface, equals(AppColors.surfaceElevatedLight));
    });

    test('AppTheme.dark includes VeneerFallbackStyle with dark tokens', () {
      final theme = AppTheme.dark();
      final veneerStyle = theme.extension<VeneerFallbackStyle>();
      expect(veneerStyle, isNotNull);
      expect(veneerStyle!.dark, isTrue);
      expect(veneerStyle.accent, equals(AppColors.brandDark));
      expect(veneerStyle.surface, equals(AppColors.surfaceElevatedDark));
    });
  });

  group('Shell & Navigation Scope', () {
    testWidgets('GlassShell renders the solid NavigationBar fallback (gate off), no kit surfaces',
        (tester) async {
      final services = AppServices();
      final auth = AuthController(services);
      final theme = ThemeController()..glassEnabled = true;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppServices>.value(value: services),
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<ThemeController>.value(value: theme),
            ChangeNotifierProvider<AppConfigService>.value(value: AppConfigService()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            scrollBehavior: const LiquidGlassScrollBehavior(),
            navigatorObservers: [
              VeneerNavigatorObserver(),
              LiquidGlassRouteObserver(),
            ],
            home: const LiquidGlassSettingsScope(
              settings: LeadGlass.defaultSettings,
              child: GlassShell(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Glass gate is forced off: LeadGlass.navBar resolves to a solid
      // Material NavigationBar (same four destinations), and there are no
      // kit chrome widgets anywhere in the tree — no glass dock, no
      // backdrop groups, no floating Executive Hub pill.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(LiquidGlassNavBar), findsNothing);
      expect(find.byType(LiquidGlassBackdropGroup), findsNothing);
      expect(find.byType(LiquidGlassButton), findsNothing);
      // Tab labels come from the solid dock (offstage tab pages are
      // skipped, so each label appears exactly once).
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('People'), findsOneWidget);
      // Selecting a destination drives the same onSelected callback.
      await tester.tap(find.text('People'));
      await tester.pump();
      expect(find.byType(NavigationBar), findsOneWidget);
      // The newly-selected destination keeps its label.
      expect(find.text('People'), findsOneWidget);
    });

    testWidgets('DashboardScreen renders NativeNavigationBar and the solid action dock',
        (tester) async {
      final services = AppServices(customApi: FakeLeadxApi());
      final auth = AuthController(services);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppServices>.value(value: services),
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<AppConfigService>.value(value: AppConfigService()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(NativeNavigationBar), findsOneWidget);
      // With the glass gate forced off there is no kit glass chrome: the
      // floating search / new-order dock is a plain solid surface instead.
      expect(find.byType(LiquidGlassCard), findsNothing);
    });

    testWidgets('ProfileScreen renders NativeSegmentedControl theme rows',
        (tester) async {
      final services = AppServices();
      final auth = AuthController(services);
      final theme = ThemeController()..glassEnabled = true;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppServices>.value(value: services),
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<ThemeController>.value(value: theme),
            ChangeNotifierProvider<AppConfigService>.value(value: AppConfigService()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            navigatorObservers: [VeneerNavigatorObserver()],
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(NativeSegmentedControl), findsOneWidget);
      expect(find.byType(NativeSwitch), findsNothing);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Liquid Glass Navigation'), findsNothing);
    });

    testWidgets('OrdersScreen renders NativeNavigationBar, solid search field and segment bar below bar',
        (tester) async {
      final services = AppServices(customApi: FakeLeadxApi());
      final auth = AuthController(services);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppServices>.value(value: services),
            ChangeNotifierProvider<AuthController>.value(value: auth),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const OrdersScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(NativeNavigationBar), findsOneWidget);
      // Solid fallback chrome: the search capsule and the filter bar are
      // plain solid surfaces (no kit glass cards anywhere in the tree).
      expect(find.byType(LeadGlassSearchField), findsOneWidget);
      expect(find.byType(LiquidGlassCard), findsNothing);
      expect(find.byType(NativeContextMenu), findsWidgets);
      // The solid segment bar shows its status labels.
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Process'), findsOneWidget);

      // Verify the search field sits below the navigation bar.
      final searchTop = tester.getTopLeft(find.byType(LeadGlassSearchField)).dy;
      expect(searchTop, greaterThanOrEqualTo(50.0),
          reason: 'The search field must be padded below the navigation bar to prevent overlap');
    });

    testWidgets('GlobalSearchScreen renders NativeSearchToolbar and the solid segment bar',
        (tester) async {
      final services = AppServices(customApi: FakeLeadxApi());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppServices>.value(value: services),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const GlobalSearchScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(NativeSearchToolbar), findsOneWidget);
      // Solid fallback: no kit glass cards; the segment bar is the solid
      // pill track with its category labels.
      expect(find.byType(LiquidGlassCard), findsNothing);
      expect(find.text('Search LeadX'), findsOneWidget);
      expect(find.text('Plans'), findsOneWidget);
    });

    testWidgets('showCrmHubSheet opens Executive Hub with NativePromptComposer',
        (tester) async {
      final services = AppServices(customApi: FakeLeadxApi());
      final auth = AuthController(services);
      final theme = ThemeController()..glassEnabled = true;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppServices>.value(value: services),
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<ThemeController>.value(value: theme),
            ChangeNotifierProvider<AppConfigService>.value(value: AppConfigService()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            navigatorObservers: [VeneerNavigatorObserver()],
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showCrmHubSheet(context),
                    child: const Text('Open Hub'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Open Hub'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(NativePromptComposer), findsOneWidget);
      expect(find.text('CRM directory & panels'), findsOneWidget);
    });

    testWidgets('SubscriptionsScreen renders NativeNavigationBar, solid search and segment bar',
        (tester) async {
      final services = AppServices();
      final auth = AuthController(services);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppServices>.value(value: services),
            ChangeNotifierProvider<AuthController>.value(value: auth),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SubscriptionsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(NativeNavigationBar), findsOneWidget);
      expect(find.byType(LeadGlassSearchField), findsOneWidget);
      // Solid fallback: no kit glass cards; the solid segment bar carries
      // its status labels ('Expiring' would double-count the top-bar
      // button, so assert two unambiguous segment labels).
      expect(find.byType(LiquidGlassCard), findsNothing);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('PaymentsScreen renders NativeNavigationBar, solid search and segment bar',
        (tester) async {
      final services = AppServices();
      final auth = AuthController(services);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppServices>.value(value: services),
            ChangeNotifierProvider<AuthController>.value(value: auth),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const PaymentsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(NativeNavigationBar), findsOneWidget);
      expect(find.byType(LeadGlassSearchField), findsOneWidget);
      // Solid fallback: no kit glass cards; the solid segment bar shows
      // 'Verified' and 'Pending' status labels.
      expect(find.byType(LiquidGlassCard), findsNothing);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('CustomerIssuesScreen renders NativeNavigationBar and the solid segment bar',
        (tester) async {
      final services = AppServices();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppServices>.value(value: services),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const CustomerIssuesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(NativeNavigationBar), findsOneWidget);
      // Solid fallback: no kit glass cards; the solid segment bar carries
      // its status labels.
      expect(find.byType(LiquidGlassCard), findsNothing);
      expect(find.text('Still facing'), findsOneWidget);
      expect(find.text('Fixed'), findsOneWidget);
    });

    testWidgets('PerformanceScreen renders KPI tiles, revenue chart and product breakdown',
        (tester) async {
      final services = AppServices(customApi: FakeLeadxApi());
      final auth = AuthController(services);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppServices>.value(value: services),
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<AppConfigService>.value(value: AppConfigService()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const PerformanceScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NativeNavigationBar), findsOneWidget);
      expect(find.text('Verified revenue'), findsOneWidget);
      expect(find.text('12345.67'), findsOneWidget);
      expect(find.text('Active subscriptions'), findsOneWidget);
      expect(find.text('Revenue · last 6 months'), findsOneWidget);

      // The product breakdown sits below the fold; scroll it into view.
      await tester.fling(find.byType(ListView), const Offset(0, -500), 400);
      await tester.pumpAndSettle();
      expect(find.text('Product breakdown'), findsOneWidget);
      expect(find.text('Enterprise Plan'), findsOneWidget);
    });

    testWidgets('CalendarScreen renders NativeNavigationBar',
        (tester) async {
      final services = AppServices();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppServices>.value(value: services),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const CalendarScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(NativeNavigationBar), findsOneWidget);
    });

    testWidgets('showLeadxBanner triggers notification fallback cleanly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showLeadxBanner(
                  ctx,
                  title: 'Test Notification',
                  body: 'Operation completed successfully',
                ),
                child: const Text('Show Banner'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Show Banner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Test Notification'), findsOneWidget);
      expect(find.text('Operation completed successfully'), findsOneWidget);
    });

    testWidgets('HomeShell renders with single navigation chrome (no duplicate AppBar)',
        (tester) async {
      final services = AppServices();
      final auth = AuthController(services);
      final theme = ThemeController()..glassEnabled = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppServices>.value(value: services),
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<ThemeController>.value(value: theme),
            ChangeNotifierProvider<AppConfigService>.value(value: AppConfigService()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const HomeShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(NativeNavigationBar), findsWidgets);
    });

    testWidgets('GlobalSearchScreen renders NativeSearchToolbar and the solid segment bar',
        (tester) async {
      final services = AppServices();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppServices>.value(value: services),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const GlobalSearchScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NativeSearchToolbar), findsOneWidget);
      // Solid fallback: no kit glass cards; the solid segment bar carries
      // the unambiguous 'Tasks' category label.
      expect(find.byType(LiquidGlassCard), findsNothing);
      expect(find.text('Quick suggestions'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
    });
  });
}
