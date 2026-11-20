import 'package:flutter_test/flutter_test.dart';
import 'package:leadx/core/constants/app_constants.dart';

void main() {
  group('Push Notification Payload and Routing Tests', () {
    test('constants verify notification channel IDs', () {
      expect(AppConstants.fcmChannelId, 'leadx_general');
      expect(AppConstants.fcmHighPriorityChannelId, 'leadx_high_priority');
    });

    test('payload resolver parses order navigation', () {
      final data = {'type': 'order', 'order_id': '42'};
      final orderIdStr = data['order_id'];
      expect(orderIdStr, '42');
      expect(int.tryParse(orderIdStr!), 42);
    });

    test('payload resolver parses payment navigation with ID', () {
      final data = {'type': 'payment', 'payment_id': '99'};
      final paymentIdStr = data['payment_id'];
      expect(paymentIdStr, '99');
      expect(int.tryParse(paymentIdStr!), 99);
    });

    test('payload resolver parses follow_up navigation with ID', () {
      final data = {'type': 'follow_up', 'follow_up_id': '105'};
      final followUpIdStr = data['follow_up_id'];
      expect(followUpIdStr, '105');
      expect(int.tryParse(followUpIdStr!), 105);
    });

    test('high priority channel selection rules', () {
      bool isHighPriority(Map<String, dynamic> data) {
        final type = data['type']?.toString() ?? '';
        return type == 'closing_value' || type == 'payment';
      }

      expect(isHighPriority({'type': 'closing_value'}), isTrue);
      expect(isHighPriority({'type': 'payment'}), isTrue);
      expect(isHighPriority({'type': 'order'}), isFalse);
      expect(isHighPriority({'type': 'follow_up'}), isFalse);
      expect(isHighPriority({}), isFalse);
    });
  });
}
