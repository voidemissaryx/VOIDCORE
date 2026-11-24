import 'package:bpb/state/app_state.dart';
import 'package:bpb/ui/setup_wizard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpWizard(WidgetTester tester) async {
    // A small phone (360×800 dp) to catch layout overflows.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: AppState(),
        child: const MaterialApp(home: SetupWizard()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first setup step presents VOIDCORE account creation', (tester) async {
    await pumpWizard(tester);

    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('YOUR VOIDCORE ID'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('sign-in mode hides username and keeps email and password fields', (tester) async {
    await pumpWizard(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('YOUR VOIDCORE ID'), findsOneWidget);
    expect(find.text('Username'), findsNothing);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
