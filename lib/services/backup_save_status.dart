/// What happened to a backup file handed to the platform.
enum BackupSaveStatus {
  /// The browser was asked to download the file.
  downloaded,

  /// The share sheet was opened with the file (the target app can't always
  /// be confirmed).
  shared,

  /// The user closed the share sheet without choosing a target.
  cancelled,
}
