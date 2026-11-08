import 'package:flutter/material.dart';
import 'package:study_app/services/data_export_service.dart';

/// Shows what really happened to a backup export: success, cancelled or an
/// error with a reason.
void showExportResult(BuildContext context, ExportResult result) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          result.message,
          style: result.isError ? TextStyle(color: scheme.onError) : null,
        ),
        backgroundColor: result.isError ? scheme.error : null,
        duration: Duration(seconds: result.isSuccess ? 4 : 6),
      ),
    );
}
