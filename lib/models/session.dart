class Session {
  final String id;
  final String campaignId;
  final String title;
  final DateTime date;
  final String rawNotes;
  final String? summary;
  final String? imagePath;

  final String? playerNarrativeRecap;
  final String? dmNarrativeRecap;

  Session({
    required this.id,
    required this.campaignId,
    required this.title,
    required this.date,
    required this.rawNotes,
    this.summary,
    this.imagePath,
    this.playerNarrativeRecap,
    this.dmNarrativeRecap,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'],
      campaignId: json['campaignId'],
      title: json['title'],
      date: DateTime.parse(json['date']),
      rawNotes: json['rawNotes'],
      summary: json['summary'],
      imagePath: json['imagePath']?.toString(),
      playerNarrativeRecap: json['playerNarrativeRecap'],
      dmNarrativeRecap: json['dmNarrativeRecap'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaignId': campaignId,
      'title': title,
      'date': date.toIso8601String(),
      'rawNotes': rawNotes,
      'summary': summary,
      'imagePath': imagePath,
      'playerNarrativeRecap': playerNarrativeRecap,
      'dmNarrativeRecap': dmNarrativeRecap,
    };
  }

  Session copyWith({
    String? id,
    String? campaignId,
    String? title,
    DateTime? date,
    String? rawNotes,
    String? summary,
    String? imagePath,
    String? playerNarrativeRecap,
    String? dmNarrativeRecap,
  }) {
    return Session(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      title: title ?? this.title,
      date: date ?? this.date,
      rawNotes: rawNotes ?? this.rawNotes,
      summary: summary ?? this.summary,
      imagePath: imagePath ?? this.imagePath,
      playerNarrativeRecap: playerNarrativeRecap ?? this.playerNarrativeRecap,
      dmNarrativeRecap: dmNarrativeRecap ?? this.dmNarrativeRecap,
    );
  }
}
