import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart' as fbi_test;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leadx/core/services/app_services.dart';
import 'package:leadx/features/orders/order_create_sheet.dart';

/// Regression test for the `Container(color:, decoration:)` runtime assert in
/// the "New order" sheet.
///
/// Flutter forbids passing both `color:` and `decoration:` to a [Container]
/// — `color` is a shorthand for `BoxDecoration(color: color)`. Supplying
/// both throws on the widget's first build (the route builder rethrows it),
/// producing the red error screen. This test opens the real sheet via
/// [showOrderCreateSheet] and verifies:
///
/// 1. no Flutter exception is raised while the sheet builds, and
/// 2. the 36x4 drag handle keeps its exact visual spec: the outline color
///    lives *inside* the [BoxDecoration] (which also carries the radius)
///    and the [Container] carries no separate `color:` argument.
///
/// The test is self-contained: [fbi_test.setupFirebaseCoreMocks] mocks the
/// Firebase pigeon host API (AppServices constructs PushService ->
/// FirebaseMessaging.instance eagerly), and
/// [FlutterSecureStorage.setMockInitialValues] gives SecureTokenStorage an
/// in-memory store. The sheet's product-list fetch fails or succeeds
/// against the real API off-band; it is fully handled (ApiException) and
/// does not affect the assertions below.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    fbi_test.setupFirebaseCoreMocks();
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('new order sheet builds without a color+decoration assert',
      (tester) async {
    // Default app comes from the mocked initializeCore(); passing options
    // would trip the "duplicate app" soft-check against the mock options.
    await Firebase.initializeApp();

    final services = AppServices();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showOrderCreateSheet(context, services),
                child: const Text('Open new order sheet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(ElevatedButton));
    // First frame of the sheet (route push + animation). The assert from the
    // bug would be raised on exactly this build.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    // 1) The red-screen assert must be gone.
    expect(tester.takeException(), isNull,
        reason: 'The sheet raised a Flutter error while building');

    // 2) The sheet content actually rendered.
    expect(find.text('New order'), findsOneWidget);

    // 3) The drag handle keeps its design. Container does not expose
    //    width/height getters (they fold into `constraints`), so match on
    //    the tight 36x4 constraint.
    final handle = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere(
          (c) => c.constraints == BoxConstraints.tightFor(width: 36, height: 4),
          orElse: () =>
              throw TestFailure('drag handle Container (36x4) not found'),
        );
    expect(handle.color, isNull,
        reason: 'Container still passes color: alongside decoration:');
    final boxDeco = handle.decoration as BoxDecoration;
    expect(
      boxDeco.color,
      Theme.of(tester.element(find.text('New order')))
          .colorScheme
          .outline,
      reason: 'drag handle color was lost from the BoxDecoration',
    );
    expect(boxDeco.borderRadius, BorderRadius.circular(2),
        reason: 'drag handle border radius changed');

    // 4) Contains a Material ancestor and SingleChildScrollView so form
    //    inputs work in glass modals without "No Material widget found"
    //    or RenderFlex bottom overflows.
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(Material), findsWidgets);
  });
}
