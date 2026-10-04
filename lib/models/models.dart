import 'dart:convert';

/// Parses an ISO date from the API. Strings without a zone are treated as UTC
/// (matching how the website compared token expiry against UtcNow).
DateTime parseUtc(String s) {
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(s);
  return DateTime.parse(hasZone ? s : '${s}Z');
}

/// Parses a calendar date/time without converting time zones.
DateTime parseLocalDate(String s) {
  var t = s;
  if (t.endsWith('Z')) t = t.substring(0, t.length - 1);
  return DateTime.parse(t);
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December'
];

/// "MMM d, yyyy"
String fmtMmmDYyyy(DateTime d) => '${_months[d.month - 1].substring(0, 3)} ${d.day}, ${d.year}';

/// "MMMM d, yyyy"
String fmtMmmmDYyyy(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// "MMM yyyy"
String fmtMmmYyyy(DateTime d) => '${_months[d.month - 1].substring(0, 3)} ${d.year}';

String monthName(int month) => _months[month - 1];

/// Formats a decimal score the way the website prints it (6.45, 7 -> "7").
String numText(num v) {
  if (v is int) return v.toString();
  final d = v.toDouble();
  if (d == d.roundToDouble()) return d.toInt().toString();
  return d.toString();
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final String username;
  final String displayName;
  final String role;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.username,
    required this.displayName,
    required this.role,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        accessToken: (j['accessToken'] ?? '') as String,
        refreshToken: (j['refreshToken'] ?? '') as String,
        accessTokenExpiresAt: parseUtc((j['accessTokenExpiresAt'] ?? '1970-01-01T00:00:00Z') as String),
        username: (j['username'] ?? '') as String,
        displayName: (j['displayName'] ?? '') as String,
        role: (j['role'] ?? '') as String,
      );
}

class PlaceDto {
  final int placeId;
  final String psgcCode;
  final String name;
  final String level;
  final int? parentPlaceId;
  final String? incomeClass;
  final String? cityType;
  final bool isCapital;
  final String? urbanRural;
  final String? oldName;
  final String? clientGuid;

  PlaceDto({
    required this.placeId,
    required this.psgcCode,
    required this.name,
    required this.level,
    this.parentPlaceId,
    this.incomeClass,
    this.cityType,
    this.isCapital = false,
    this.urbanRural,
    this.oldName,
    this.clientGuid,
  });

  factory PlaceDto.fromJson(Map<String, dynamic> j) => PlaceDto(
        placeId: (j['placeId'] as num).toInt(),
        psgcCode: (j['psgcCode'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        level: (j['level'] ?? '') as String,
        parentPlaceId: (j['parentPlaceId'] as num?)?.toInt(),
        incomeClass: j['incomeClass'] as String?,
        cityType: j['cityType'] as String?,
        isCapital: (j['isCapital'] ?? false) as bool,
        urbanRural: j['urbanRural'] as String?,
        oldName: j['oldName'] as String?,
        clientGuid: j['clientGuid'] as String?,
      );

  String get label => '$psgcCode \u2014 $name';
}

class PagedResult<T> {
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;
  PagedResult(this.items, this.totalCount, this.page, this.pageSize);

  static PagedResult<PlaceDto> places(dynamic json, {int page = 1, int pageSize = 15}) {
    if (json is! Map<String, dynamic>) return PagedResult(<PlaceDto>[], 0, page, pageSize);
    final items = ((json['items'] ?? []) as List)
        .map((e) => PlaceDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return PagedResult(
      items,
      (json['totalCount'] as num?)?.toInt() ?? 0,
      (json['page'] as num?)?.toInt() ?? page,
      (json['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }
}

class PlaceUpsert {
  String psgcCode;
  String name;
  String level;
  int? parentPlaceId;
  String? incomeClass;
  String? cityType;
  bool isCapital;
  String? urbanRural;
  String? oldName;
  String? clientGuid;

  PlaceUpsert({
    this.psgcCode = '',
    this.name = '',
    this.level = 'province',
    this.parentPlaceId,
    this.incomeClass,
    this.cityType,
    this.isCapital = false,
    this.urbanRural,
    this.oldName,
    this.clientGuid,
  });

  factory PlaceUpsert.fromPlace(PlaceDto p) => PlaceUpsert(
        psgcCode: p.psgcCode,
        name: p.name,
        level: p.level,
        parentPlaceId: p.parentPlaceId,
        incomeClass: p.incomeClass,
        cityType: p.cityType,
        isCapital: p.isCapital,
        urbanRural: p.urbanRural,
        oldName: p.oldName,
        clientGuid: p.clientGuid,
      );

  Map<String, dynamic> toJson() => {
        'psgcCode': psgcCode,
        'name': name,
        'level': level,
        'parentPlaceId': parentPlaceId,
        'incomeClass': incomeClass,
        'cityType': cityType,
        'isCapital': isCapital,
        'urbanRural': urbanRural,
        'oldName': oldName,
        'clientGuid': clientGuid,
      };
}

const kDomainFields = <String>[
  'spiritual',
  'family',
  'health',
  'financial',
  'intellectual',
  'leadership',
  'ministry',
  'organization',
  'community',
  'nationalContribution',
  'internationalEngagement',
];

const kDomainLabels = <String>[
  'Spiritual',
  'Family',
  'Health',
  'Financial',
  'Intellectual',
  'Leadership',
  'Ministry',
  'Organization',
  'Community',
  'National Contribution',
  'International Engagement',
];

String shortDomain(String key) {
  switch (key) {
    case 'Spiritual':
      return 'Spirit';
    case 'Financial':
      return 'Fin';
    case 'Intellectual':
      return 'Intel';
    case 'Leadership':
      return 'Lead';
    case 'Ministry':
      return 'Min';
    case 'Organization':
      return 'Org';
    case 'Community':
      return 'Comm';
    case 'National Contribution':
      return 'Nation';
    case 'International Engagement':
      return 'Intl';
    default:
      return key;
  }
}

class AssessmentDto {
  final int assessmentId;
  final int placeId;
  final String placeName;
  final String psgcCode;
  final DateTime assessmentDate;
  final List<int> scores; // 11 domain scores, in kDomainFields order
  final num overallScore;
  final String overallStatus;
  final String weakestDomain;
  final int weakestScore;
  final String strongestDomain;
  final int strongestScore;
  final String priorityLevel;
  final String? automatedAdvice;
  final String? northStarStatement;
  final String? topPriority1;
  final String? topPriority2;
  final String? topPriority3;
  final String? stopReduce;
  final DateTime? nextReviewDate;
  final String? reviewFrequency;
  final String? notes;

  AssessmentDto({
    required this.assessmentId,
    required this.placeId,
    required this.placeName,
    required this.psgcCode,
    required this.assessmentDate,
    required this.scores,
    required this.overallScore,
    required this.overallStatus,
    required this.weakestDomain,
    required this.weakestScore,
    required this.strongestDomain,
    required this.strongestScore,
    required this.priorityLevel,
    this.automatedAdvice,
    this.northStarStatement,
    this.topPriority1,
    this.topPriority2,
    this.topPriority3,
    this.stopReduce,
    this.nextReviewDate,
    this.reviewFrequency,
    this.notes,
  });

  factory AssessmentDto.fromJson(Map<String, dynamic> j) => AssessmentDto(
        assessmentId: (j['assessmentId'] as num?)?.toInt() ?? 0,
        placeId: (j['placeId'] as num).toInt(),
        placeName: (j['placeName'] ?? '') as String,
        psgcCode: (j['psgcCode'] ?? '') as String,
        assessmentDate: parseLocalDate(j['assessmentDate'] as String),
        scores: [for (final f in kDomainFields) (j[f] as num?)?.toInt() ?? 0],
        overallScore: (j['overallScore'] as num?) ?? 0,
        overallStatus: (j['overallStatus'] ?? '') as String,
        weakestDomain: (j['weakestDomain'] ?? '') as String,
        weakestScore: (j['weakestScore'] as num?)?.toInt() ?? 0,
        strongestDomain: (j['strongestDomain'] ?? '') as String,
        strongestScore: (j['strongestScore'] as num?)?.toInt() ?? 0,
        priorityLevel: (j['priorityLevel'] ?? '') as String,
        automatedAdvice: j['automatedAdvice'] as String?,
        northStarStatement: j['northStarStatement'] as String?,
        topPriority1: j['topPriority1'] as String?,
        topPriority2: j['topPriority2'] as String?,
        topPriority3: j['topPriority3'] as String?,
        stopReduce: j['stopReduce'] as String?,
        nextReviewDate:
            j['nextReviewDate'] == null ? null : parseLocalDate(j['nextReviewDate'] as String),
        reviewFrequency: j['reviewFrequency'] as String?,
        notes: j['notes'] as String?,
      );

  /// (label, score) pairs, same order as the website's DomainScores.
  List<(String, int)> get domainScores =>
      [for (var i = 0; i < 11; i++) (kDomainLabels[i], scores[i])];
}

class AssessmentUpsert {
  int placeId;
  DateTime assessmentDate;
  List<int> scores;
  String? northStarStatement;
  String? topPriority1;
  String? topPriority2;
  String? topPriority3;
  String? stopReduce;
  DateTime? nextReviewDate;
  String? reviewFrequency;
  String? notes;

  AssessmentUpsert({
    required this.placeId,
    required this.assessmentDate,
    List<int>? scores,
    this.northStarStatement,
    this.topPriority1,
    this.topPriority2,
    this.topPriority3,
    this.stopReduce,
    this.nextReviewDate,
    this.reviewFrequency = 'Monthly',
    this.notes,
  }) : scores = scores ?? List<int>.filled(11, 5);

  Map<String, dynamic> toJson() {
    String iso(DateTime d) => '${ymd(d)}T00:00:00';
    return {
      'placeId': placeId,
      'assessmentDate': iso(assessmentDate),
      for (var i = 0; i < 11; i++) kDomainFields[i]: scores[i],
      'northStarStatement': northStarStatement,
      'topPriority1': topPriority1,
      'topPriority2': topPriority2,
      'topPriority3': topPriority3,
      'stopReduce': stopReduce,
      'nextReviewDate': nextReviewDate == null ? null : iso(nextReviewDate!),
      'reviewFrequency': reviewFrequency,
      'notes': notes,
      'clientGuid': null,
    };
  }
}

class FrameworkDomainAdvice {
  final String domain;
  final Map<String, String> byLevel;
  FrameworkDomainAdvice(this.domain, this.byLevel);
}

class FrameworkData {
  final Map<String, String> levels; // ordered
  final List<FrameworkDomainAdvice> domains;
  FrameworkData(this.levels, this.domains);

  factory FrameworkData.empty() => FrameworkData({}, []);

  factory FrameworkData.parse(String jsonText) {
    final j = jsonDecode(jsonText) as Map<String, dynamic>;
    final levels = <String, String>{};
    (j['levels'] as Map<String, dynamic>? ?? {}).forEach((k, v) => levels[k] = v as String);
    final domains = <FrameworkDomainAdvice>[];
    for (final d in (j['domains'] as List? ?? [])) {
      final m = d as Map<String, dynamic>;
      domains.add(FrameworkDomainAdvice(
        (m['domain'] ?? '') as String,
        {
          'critical_1_2': (m['critical_1_2'] ?? '') as String,
          'struggling_3_4': (m['struggling_3_4'] ?? '') as String,
          'balancing_5_7': (m['balancing_5_7'] ?? '') as String,
          'thriving_8_10': (m['thriving_8_10'] ?? '') as String,
        },
      ));
    }
    return FrameworkData(levels, domains);
  }
}

/// One plottable Area for the Area Map.
class AreaMapPoint {
  final int placeId;
  final String psgcCode;
  final String name;
  final String? level;
  final String? urbanRural;
  final String geocodeQuery;
  final bool hasAssessment;
  final String? overallStatus;
  final double? overallScore;
  final String? priorityLevel;
  final String? weakestDomain;
  final int? weakestScore;
  final String? strongestDomain;
  final int? strongestScore;
  final String? lastAssessmentDate;
  double? lat;
  double? lng;

  AreaMapPoint({
    required this.placeId,
    required this.psgcCode,
    required this.name,
    this.level,
    this.urbanRural,
    required this.geocodeQuery,
    required this.hasAssessment,
    this.overallStatus,
    this.overallScore,
    this.priorityLevel,
    this.weakestDomain,
    this.weakestScore,
    this.strongestDomain,
    this.strongestScore,
    this.lastAssessmentDate,
    this.lat,
    this.lng,
  });

  factory AreaMapPoint.fromAssessment(AssessmentDto a) => AreaMapPoint(
        placeId: a.placeId,
        psgcCode: a.psgcCode,
        name: a.placeName,
        geocodeQuery: '${a.placeName}, Philippines',
        hasAssessment: true,
        overallStatus: a.overallStatus,
        overallScore: a.overallScore.toDouble(),
        priorityLevel: a.priorityLevel,
        weakestDomain: a.weakestDomain,
        weakestScore: a.weakestScore,
        strongestDomain: a.strongestDomain,
        strongestScore: a.strongestScore,
        lastAssessmentDate: ymd(a.assessmentDate),
      );

  factory AreaMapPoint.fromPlace(PlaceDto p, AssessmentDto? latest) => AreaMapPoint(
        placeId: p.placeId,
        psgcCode: p.psgcCode,
        name: p.name,
        level: p.level,
        urbanRural: p.urbanRural,
        geocodeQuery: '${p.name}, Philippines',
        hasAssessment: latest != null,
        overallStatus: latest?.overallStatus,
        overallScore: latest?.overallScore.toDouble(),
        priorityLevel: latest?.priorityLevel,
        weakestDomain: latest?.weakestDomain,
        weakestScore: latest?.weakestScore,
        strongestDomain: latest?.strongestDomain,
        strongestScore: latest?.strongestScore,
        lastAssessmentDate: latest == null ? null : ymd(latest.assessmentDate),
      );
}
