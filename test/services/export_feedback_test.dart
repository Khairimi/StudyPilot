import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/screens/global/export_feedback.dart';
import 'package:study_app/services/data_export_service.dart';

Future<void> show(WidgetTester tester, ExportResult result) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => showExportResult(context, result), child: const Text('go')),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
}

Color? snackColor(WidgetTester tester) => tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor;

void main() {
  testWidgets('success shows the file name with the normal snackbar colour', (tester) async {
    await show(
      tester,
      const ExportResult(ExportOutcome.downloaded, 'Backup downloaded as x.json.', fileName: 'x.json'),
    );
    expect(find.text('Backup downloaded as x.json.'), findsOneWidget);
    expect(snackColor(tester), isNull);
  });

  testWidgets('failure is shown in the error colour with its reason', (tester) async {
    await show(tester, const ExportResult(ExportOutcome.failed, 'Export failed: the backup file could not be saved.'));
    expect(find.textContaining('could not be saved'), findsOneWidget);
    expect(snackColor(tester), isNotNull);
  });

  testWidgets('cancelled is neutral, not an error', (tester) async {
    await show(tester, const ExportResult(ExportOutcome.cancelled, 'Export cancelled. No backup was saved.'));
    expect(find.textContaining('No backup was saved'), findsOneWidget);
    expect(snackColor(tester), isNull);
  });
}
