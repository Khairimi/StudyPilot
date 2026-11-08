import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/screens/global/auth_screens.dart';
import 'package:study_app/screens/global/splash_screen.dart';
import 'package:study_app/studypilot/core/design_system.dart';

const signedInStub = Text('Signed-in destination');

Widget app(Future<bool> Function() isSignedIn) => MaterialApp(
  theme: SpTheme.build(Brightness.light, useGoogleFonts: false),
  home: SplashScreen(isSignedInOverride: isSignedIn, signedInDestinationOverride: signedInStub),
);

void main() {
  testWidgets('a signed-in user goes to the app, not Welcome', (tester) async {
    await tester.pumpWidget(app(() async => true));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Signed-in destination'), findsOneWidget);
    expect(find.byType(AuthEntryScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a signed-out user goes to Welcome', (tester) async {
    await tester.pumpWidget(app(() async => false));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(AuthEntryScreen), findsOneWidget);
    expect(find.text('Signed-in destination'), findsNothing);
  });

  testWidgets('stays on the splash until the auth state is known', (tester) async {
    final auth = Completer<bool>();
    await tester.pumpWidget(app(() => auth.future));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(AuthEntryScreen), findsNothing);

    auth.complete(true);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Signed-in destination'), findsOneWidget);
  });

  testWidgets('does not navigate after the splash is disposed', (tester) async {
    final auth = Completer<bool>();
    await tester.pumpWidget(app(() => auth.future));
    await tester.pumpWidget(const MaterialApp(home: Text('Elsewhere')));
    await tester.pump(const Duration(seconds: 4));
    auth.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Elsewhere'), findsOneWidget);
    expect(find.text('Signed-in destination'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
