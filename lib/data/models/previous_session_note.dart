/// Model for previous session note screenshots and metadata
class PreviousSessionNote {
  final String imageUrl;
  final int sessionNumber;
  final DateTime createdAt;
  final String? fileName;

  PreviousSessionNote({
    required this.imageUrl,
    required this.sessionNumber,
    required this.createdAt,
    this.fileName,
  });

  @override
  String toString() => 'PreviousSessionNote(session: $sessionNumber, date: $createdAt)';
}
