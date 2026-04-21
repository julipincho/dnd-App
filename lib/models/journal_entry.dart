class JournalEntry {
  final String id;
  final String campaignId;
  final String? sessionId;

  final String authorRole; // 'dm' | 'player'
  final String authorName;
  final String? authorCharacterName;
  final String? authorCharacterPortraitPath;
  final String? authorCharacterId;

  final String content;
  final String? imagePath;

  final DateTime createdAt;

  JournalEntry({
    required this.id,
    required this.campaignId,
    this.sessionId,
    required this.authorRole,
    required this.authorName,
    this.authorCharacterName,
    this.authorCharacterPortraitPath,
    this.authorCharacterId,
    required this.content,
    this.imagePath,
    required this.createdAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'],
      campaignId: json['campaignId'],
      sessionId: json['sessionId'],
      authorRole: json['authorRole'],
      authorName: json['authorName'],
      authorCharacterName: json['authorCharacterName'],
      authorCharacterPortraitPath: json['authorCharacterPortraitPath'],
      authorCharacterId: json['authorCharacterId'],
      content: json['content'],
      imagePath: json['imagePath'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaignId': campaignId,
      'sessionId': sessionId,
      'authorRole': authorRole,
      'authorName': authorName,
      'authorCharacterName': authorCharacterName,
      'authorCharacterPortraitPath': authorCharacterPortraitPath,
      'authorCharacterId': authorCharacterId,
      'content': content,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
