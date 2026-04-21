class CampaignEvent {
  final String id;
  final String campaignId;
  final String? sessionId;
  final String title;
  final String description;
  final DateTime date;
  final String type;

  CampaignEvent({
    required this.id,
    required this.campaignId,
    this.sessionId,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
  });

  factory CampaignEvent.fromJson(Map<String, dynamic> json) {
    return CampaignEvent(
      id: json['id'],
      campaignId: json['campaignId'],
      sessionId: json['sessionId'],
      title: json['title'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaignId': campaignId,
      'sessionId': sessionId,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'type': type,
    };
  }

  CampaignEvent copyWith({
    String? id,
    String? campaignId,
    String? sessionId,
    String? title,
    String? description,
    DateTime? date,
    String? type,
  }) {
    return CampaignEvent(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      type: type ?? this.type,
    );
  }
}
