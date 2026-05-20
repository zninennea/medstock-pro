import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medstock_pro/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MedStock Pro app test', (WidgetTester tester) async {
    // Create mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame
    await tester.pumpWidget(MedStockPro(prefs: prefs));

    // Verify that the app starts
    expect(find.text('MedStock Pro'), findsOneWidget);
  });
}
