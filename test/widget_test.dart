import 'package:flutter_test/flutter_test.dart';
import 'package:mother_mobile/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MotherMobileApp());

    // Verify the app launches (basic smoke test)
    expect(find.byType(MotherMobileApp), findsOneWidget);
  });
}
