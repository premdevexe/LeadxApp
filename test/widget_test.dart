import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leadx/features/dashboard/home_shell.dart';
import 'package:leadx/shared/format.dart';
import 'package:leadx/shared/models/currency.dart';
import 'package:leadx/shared/models/customer.dart';
import 'package:leadx/shared/models/dashboard.dart' as m;
import 'package:leadx/shared/models/employee.dart';
import 'package:leadx/shared/models/follow_up.dart';
import 'package:leadx/shared/models/order.dart';
import 'package:leadx/shared/models/payment.dart';
import 'package:leadx/shared/models/subscription.dart';

/// Pure model serialization tests (no Firebase / no network needed).
void main() {
  group('Order.fromJson', () {
    test('maps the backend OrderResource fields', () {
      final o = Order.fromJson({
        'id': 41,
        'order_number': 'GEM-2026-000041',
        'customer_name': 'Grace',
        'closing_value': 90.5,
        'payment_status': 'pending',
        'order_status': 'pending',
        'product_name_snapshot': 'Plan A',
        'product_price_snapshot': 100,
        'created_at': '2026-11-16T10:00:00+00:00',
        'updated_at': '2026-11-16T10:00:00+00:00',
      });

      expect(o.id, 41);
      expect(o.orderNumber, 'GEM-2026-000041');
      expect(o.closingValue, 90.5);
      expect(o.paymentStatus, 'pending');
      expect(o.productPriceSnapshot, 100);
      expect(o.legacyFlag, false);
    });

    test('nested subscription is parsed when present', () {
      final o = Order.fromJson({
        'id': 1,
        'order_number': 'X-1',
        'customer_name': 'C',
        'closing_value': 1,
        'payment_status': 'pending',
        'order_status': 'pending',
        'created_at': '',
        'updated_at': '',
        'subscription': {
          'id': 9,
          'status': 'active',
          'expires_at': '2026-12-01T00:00:00+00:00',
        },
      });
      expect(o.subscription?.id, 9);
      expect(o.subscription?.status, 'active');
    });

    test('missing optional fields do not crash', () {
      final o = Order.fromJson({
        'id': 2,
        'order_number': 'X-2',
        'customer_name': '',
        'closing_value': null,
        'payment_status': null,
        'order_status': null,
        'created_at': null,
        'updated_at': null,
      });
      expect(o.closingValue, 0);
      expect(o.paymentStatus, '');
    });
  });

  group('Payment.fromJson', () {
    test('parses PaymentResource accurately', () {
      final p = Payment.fromJson({
        'id': 101,
        'order_id': 41,
        'customer_id': 7,
        'payment_method': 'upi',
        'transaction_reference': 'UPI-REF-9988',
        'amount': 2500.5,
        'currency': 'USD', // payment rows carry the currency *code*, not the symbol
        'payment_status': 'completed',
        'verified': true,
        'verified_at': '2026-11-16T12:00:00Z',
      });
      expect(p.id, 101);
      expect(p.orderId, 41);
      expect(p.customerId, 7);
      expect(p.amount, 2500.5);
      expect(p.verified, true);
      expect(p.paymentMethod, 'upi');
      expect(p.transactionReference, 'UPI-REF-9988');
    });
  });

  group('Subscription.fromJson', () {
    test('parses SubscriptionResource with nested order data', () {
      final s = Subscription.fromJson({
        'id': 8,
        'order_id': 41,
        'status': 'active',
        'plan_snapshot': 'Enterprise Pro',
        'price_snapshot': 999.0,
        'amount_paid': 999.0,
        'expires_at': '2026-12-31T23:59:59Z',
        'order': {
          'order_number': 'GEM-2026-000041',
          'order_status': 'completed',
          'customer': {'name': 'Acme Corp'},
        },
      });
      expect(s.id, 8);
      expect(s.orderId, 41);
      expect(s.status, 'active');
      expect(s.planSnapshot, 'Enterprise Pro');
      expect(s.orderNumber, 'GEM-2026-000041');
      expect(s.customerName, 'Acme Corp');
    });
  });

  group('FollowUp.fromJson and Action Requests', () {
    test('parses FollowUp resource', () {
      final f = FollowUp.fromJson({
        'id': 5,
        'customer_id': 12,
        'title': 'Renewal follow-up',
        'follow_up_type': 'call',
        'status': 'pending',
        'scheduled_at': '2026-12-01T10:00:00Z',
        'calendar_sync_status': 'synced',
        'customer': {'name': 'Jane Doe'},
      });
      expect(f.id, 5);
      expect(f.title, 'Renewal follow-up');
      expect(f.followUpType, 'call');
      expect(f.customerName, 'Jane Doe');
      expect(f.calendarSyncStatus, 'synced');
    });

    test('FollowUpActionRequest formats json commands correctly', () {
      final reschedule = FollowUpActionRequest.reschedule(
        scheduledAt: '2026-12-05T15:00:00Z',
        notes: 'Moved by client request',
      );
      expect(reschedule.toJson(), {
        'action': 'reschedule',
        'notes': 'Moved by client request',
        'scheduled_at': '2026-12-05T15:00:00Z',
      });

      final complete = FollowUpActionRequest.complete(outcome: 'renewed');
      expect(complete.toJson(), {
        'action': 'complete',
        'outcome': 'renewed',
      });

      final cancel = FollowUpActionRequest.cancel(notes: 'Customer unreachable');
      expect(cancel.toJson(), {
        'action': 'cancel',
        'notes': 'Customer unreachable',
      });
    });
  });

  group('Customer.fromJson', () {
    test('parses Customer resource', () {
      final c = Customer.fromJson({
        'id': 12,
        'name': 'Grace Hooper',
        'email': 'grace@example.com',
        'phone': '+15551234567',
        'status': 'active',
        'purchases_count': 3,
        'total_purchased': 270.0,
      });
      expect(c.id, 12);
      expect(c.name, 'Grace Hooper');
      expect(c.purchasesCount, 3);
      expect(c.totalPurchased, 270.0);
    });
  });

  group('ListMeta.fromJson', () {
    test('parses pagination and view warning metadata', () {
      final m = ListMeta.fromJson({
        'view': 'my_data',
        'warning': 'Team data access grant expired',
        'current_page': 1,
        'last_page': 5,
        'per_page': 20,
        'total': 95,
      });
      expect(m.view, 'my_data');
      expect(m.warning, 'Team data access grant expired');
      expect(m.currentPage, 1);
      expect(m.lastPage, 5);
      expect(m.total, 95);
    });
  });

  group('MeResponse.permissions', () {
    test('booleans map correctly', () {
      final r = MeResponse.fromJson({
        'data': {'id': 7, 'name': 'Jane'},
        'has_team_data_access': true,
        'permissions': {
          'orders.view': true,
          'orders.create': false,
        },
      });
      expect(r.data.id, 7);
      expect(r.hasTeamDataAccess, true);
      expect(r.canViewOrders(), true);
      expect(r.canCreateOrders(), false);
      expect(r.canViewPayments(), false);
    });
  });

  group('Dashboard.fromJson', () {
    test('parses summary, chart, and collections', () {
      final d = m.Dashboard.fromJson({
        'meta': {'currency_symbol': '₹', 'view': 'my_data', 'warning': null},
        'summary': {
          'total_orders': 3,
          'closing_value': 100,
          'verified_revenue': 50,
          'customers_count': 2,
          'active_subscriptions': 1,
          'pending_payments_count': 0,
          'pending_amount': 0,
          'expiring_subscriptions': 0,
          'follow_ups': 0,
          'monthly_orders': 0,
          'monthly_closing_value': 0,
        },
        'recent_orders': {'data': <Map<String, dynamic>>[]},
        'recent_follow_ups': {'data': <Map<String, dynamic>>[]},
        'expiring_subscriptions': {'data': <Map<String, dynamic>>[]},
        'recent_notifications': <Map<String, dynamic>>[],
        'monthly_sales_chart': [
          {'month': 'Jun 2026', 'orders': 1, 'closing_value': 10}
        ],
      });
      expect(d.summary.totalOrders, 3);
      expect(d.currencySymbol, '₹');
      expect(d.monthlySalesChart.single.orders, 1);
    });

    test('tolerates an empty document', () {
      final d = m.Dashboard.fromJson({});
      expect(d.summary.totalOrders, 0);
      expect(d.monthlySalesChart, isEmpty);
    });
  });

  group('Money formatting (centralized CurrencyConfig)', () {
    // The app-wide default is the neutral USD fallback so the app never
    // invents a symbol; the live admin currency is bound at runtime.
    test('groups thousands with the fallback USD config', () {
      Fmt.bindLiveCurrency(CurrencyConfig.fallback);
      expect(Fmt.money('12345.6'), r'$12,345.60');
      expect(Fmt.money(12345.6), r'$12,345.60');
    });

    test('follows an admin-bound config (INR)', () {
      final inr = CurrencyConfig.fromJson({
        'currency': {
          'code': 'INR',
          'symbol': r'₹',
          'decimal_places': 2,
          'symbol_position': 'before',
          'thousands_separator': ',',
          'decimal_separator': '.',
        },
        'currencies': {'INR': r'₹', 'USD': r'$'},
      });
      Fmt.bindLiveCurrency(inr);
      expect(Fmt.money(12345.6), '₹12,345.60');
    });

    test('moneyFor resolves a per-row currency code via the catalogue', () {
      final cfg = CurrencyConfig.fromJson({
        'currency': {
          'code': 'USD',
          'symbol': r'$',
          'decimal_places': 2,
          'symbol_position': 'before',
          'thousands_separator': ',',
          'decimal_separator': '.',
        },
        'currencies': {'INR': r'₹', 'USD': r'$'},
      });
      Fmt.bindLiveCurrency(cfg);
      expect(Fmt.moneyFor(99.9, code: 'INR'), '₹99.90');
    });

    test('negative amounts carry the sign before the symbol', () {
      Fmt.bindLiveCurrency(CurrencyConfig.fallback);
      expect(Fmt.money(-5), r'-$5.00');
    });
  });

  group('CurrencyConfig.fromJson', () {
    test('returns the neutral USD fallback for an empty document', () {
      final c = CurrencyConfig.fromJson(null);
      expect(c.code, 'USD');
      expect(c.symbol, r'$');
      expect(c.decimalPlaces, 2);
    });
  });

  group('AnimatedIndexedStack', () {
    testWidgets('animates and displays correct indexed child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedIndexedStack(
              index: 0,
              children: [
                Text('Page 0'),
                Text('Page 1'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Page 0'), findsOneWidget);
      expect(find.text('Page 1'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedIndexedStack(
              index: 1,
              children: [
                Text('Page 0'),
                Text('Page 1'),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Page 0'), findsNothing);
      expect(find.text('Page 1'), findsOneWidget);
    });
  });
}
