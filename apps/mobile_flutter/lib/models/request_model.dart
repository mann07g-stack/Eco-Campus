class WasteRequest {
  WasteRequest({
    required this.id,
    required this.description,
    required this.status,
    required this.currentQuote,
    required this.adminQuote,
    required this.adminQuoteMessage,
    required this.lastUserCounterMessage,
    required this.quotePendingForUser,
    required this.agreedQuote,
    required this.imageUrls,
    required this.createdAt,
    this.collectedByMember,
    this.collectedAt,
    this.studentName,
    this.studentPhone,
    this.collectorName,
    this.collectorPhone,
  });

  final String id;
  final String description;
  final String status;
  final double currentQuote;
  final double adminQuote;
  final String adminQuoteMessage;
  final String lastUserCounterMessage;
  final bool quotePendingForUser;
  final double agreedQuote;
  final List<String> imageUrls;
  final String createdAt;
  final String? collectedByMember;
  final String? collectedAt;
  final String? studentName;
  final String? studentPhone;
  final String? collectorName;
  final String? collectorPhone;

  factory WasteRequest.fromJson(Map<String, dynamic> json) {
    return WasteRequest(
      id: json["_id"]?.toString() ?? "",
      description: json["description"]?.toString() ?? "",
      status: json["status"]?.toString() ?? "SUBMITTED",
      currentQuote: (json["currentQuote"] ?? 0).toDouble(),
      adminQuote: (json["adminQuote"] ?? 0).toDouble(),
      adminQuoteMessage: json["adminQuoteMessage"]?.toString() ?? "",
      lastUserCounterMessage: json["lastUserCounterMessage"]?.toString() ?? "",
      quotePendingForUser: (json["quotePendingForUser"] ?? false) as bool,
      agreedQuote: (json["agreedQuote"] ?? 0).toDouble(),
      imageUrls: (json["imageUrls"] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      createdAt: json["createdAt"]?.toString() ?? "",
      collectedByMember: json["collectedByMemberId"]?.toString(),
      collectedAt: json["collectedAt"]?.toString(),
      studentName: json["userId"] is Map<String, dynamic> ? json["userId"]["fullName"]?.toString() : null,
        studentPhone: json["userId"] is Map<String, dynamic> ? json["userId"]["phone"]?.toString() : null,
      collectorName: json["assignedMemberId"] is Map<String, dynamic>
          ? json["assignedMemberId"]["fullName"]?.toString()
          : null,
      collectorPhone: json["assignedMemberId"] is Map<String, dynamic>
          ? json["assignedMemberId"]["phone"]?.toString()
          : null,
    );
  }
}
