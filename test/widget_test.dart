// Dans test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharm_admin/main.dart'; // Vérifiez que le nom du package correspond au vôtre

void main() {
  testWidgets('Counter infiltration test', (WidgetTester tester) async {
    // Remplacez MyApp() par PharmacyApp()
    await tester.pumpWidget(PharmacyApp());
  });
}
