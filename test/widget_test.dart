import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:pharm_admin/l10n/app_localizations.dart';
import 'package:pharm_admin/main.dart';

void main() {
  testWidgets('Counter infiltration test', (WidgetTester tester) async {
    await tester.pumpWidget(PharmacyApp());
  });

  test('management translations are available', () async {
    final fr = await AppLocalizations.delegate.load(const Locale('fr'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    expect(fr.translate('my_officine'), 'Mon officine');
    expect(fr.translate('medicaments'), 'Médicaments');
    expect(fr.translate('mes_pharmacies'), 'Mes Pharmacies');
    expect(fr.translate('visible_on_map'), 'Visible sur la carte');
    expect(en.translate('my_officine'), 'My pharmacy');
    expect(en.translate('medicaments'), 'Medications');
    expect(en.translate('mes_pharmacies'), 'My Pharmacies');
    expect(en.translate('visible_on_map'), 'Visible on the map');
  });
}
