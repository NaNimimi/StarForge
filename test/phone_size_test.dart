import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ceo_manager/theme.dart';
import 'package:ceo_manager/settings.dart';
import 'package:ceo_manager/store.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/screens.dart';
import 'package:ceo_manager/widgets.dart';

// Regression for the "blank page" bug: a Scaffold whose bottomNavigationBar held
// an aligned Container (SfButton / export button) ballooned to full screen
// height, collapsing the body to h=0 so the ListView built no children. These
// tests pin a phone-sized surface and assert each pushed screen's body renders
// real content AND its bottom button is a sane height.
Widget _host(AppStore store, AppSettings settings, Widget child) => SettingsScope(
      settings: settings,
      child: AppScope(
        store: store,
        child: MaterialApp(home: Builder(builder: (_) => child)),
      ),
    );

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.625;
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
}

// Assert no descendant button balloons — the body must keep real height.
void _bodyNotCollapsed(WidgetTester t, Finder listView) {
  final box = listView.evaluate().first.renderObject as RenderBox;
  expect(box.size.height, greaterThan(100),
      reason: 'body ListView collapsed to ${box.size.height}px — greedy bottom bar');
}

void main() {
  final c = SfColors.light;

  for (final role in SfRole.values) {
    final store = AppStore.seed(role);

    testWidgets('EditProfileScreen body renders · $role', (t) async {
      _phone(t);
      await t.pumpWidget(_host(store, AppSettings(), EditProfileScreen(cfg: kRoleConfigs[role]!, colors: c)));
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(TextField), findsAtLeastNWidgets(2));
      _bodyNotCollapsed(t, find.byType(ListView));
      expect(t.takeException(), isNull);
    });

    testWidgets('ReportScreen body renders · $role', (t) async {
      _phone(t);
      await t.pumpWidget(_host(store, AppSettings(), ReportScreen(colors: c, role: role)));
      await t.pump(const Duration(seconds: 1));
      _bodyNotCollapsed(t, find.byType(ListView));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('NotificationsScreen body renders', (t) async {
    _phone(t);
    await t.pumpWidget(_host(AppStore.seed(SfRole.ceo), AppSettings(), NotificationsScreen(colors: c)));
    await t.pump(const Duration(seconds: 1));
    _bodyNotCollapsed(t, find.byType(ListView));
    expect(t.takeException(), isNull);
  });

  // SfButton must never balloon vertically when given loose full height.
  testWidgets('SfButton stays content-height under loose constraints', (t) async {
    _phone(t);
    await t.pumpWidget(_host(
      AppStore.seed(SfRole.ceo),
      AppSettings(),
      Scaffold(
        body: const SizedBox.shrink(),
        bottomNavigationBar: SfTheme(
          colors: c,
          child: SfButton(label: 'X', primary: true, onTap: () {}),
        ),
      ),
    ));
    await t.pump();
    final box = find.byType(SfButton).evaluate().first.renderObject as RenderBox;
    expect(box.size.height, lessThan(100), reason: 'SfButton ballooned to ${box.size.height}px');
  });
}
