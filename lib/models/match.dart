class SetScore {
  int ourScore;
  int theirScore;

  SetScore({this.ourScore = 0, this.theirScore = 0});

  Map<String, dynamic> toJson() => {
        'ourScore': ourScore,
        'theirScore': theirScore,
      };

  factory SetScore.fromJson(Map<String, dynamic> json) => SetScore(
        ourScore: json['ourScore'] ?? 0,
        theirScore: json['theirScore'] ?? 0,
      );

  bool get isOurWin => ourScore > theirScore;
  bool get isPlayed => ourScore > 0 || theirScore > 0;
}

class Match {
  final String id;
  String opponent;
  String team; // 'A' or 'B'
  DateTime date;
  String matchName;
  String memo;
  int opponentColorValue;
  List<SetScore> sets; // 最大10セット

  Match({
    required this.id,
    required this.opponent,
    this.team = 'A',
    required this.date,
    this.matchName = '',
    this.memo = '',
    this.opponentColorValue = 0xFF2196F3,
    List<SetScore>? sets,
  }) : sets = sets ?? List.generate(10, (_) => SetScore());

  // 勝利セット数
  int get ourWonSets =>
      sets.where((s) => s.isPlayed && s.isOurWin).length;
  // 相手勝利セット数
  int get theirWonSets =>
      sets.where((s) => s.isPlayed && !s.isOurWin).length;
  // プレイ済みセット数
  int get playedSets => sets.where((s) => s.isPlayed).length;
  // 総得点
  int get ourTotalPoints =>
      sets.fold(0, (sum, s) => sum + s.ourScore);
  int get theirTotalPoints =>
      sets.fold(0, (sum, s) => sum + s.theirScore);

  Map<String, dynamic> toJson() => {
        'id': id,
        'opponent': opponent,
        'team': team,
        'date': date.toIso8601String(),
        'matchName': matchName,
        'memo': memo,
        'opponentColorValue': opponentColorValue,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory Match.fromJson(Map<String, dynamic> json) {
    List<SetScore> sets;
    if (json['sets'] != null) {
      final rawSets = json['sets'] as List<dynamic>;
      sets = rawSets.map((s) => SetScore.fromJson(s)).toList();
      // 10セット分に足りなければ補完
      while (sets.length < 10) {
        sets.add(SetScore());
      }
    } else {
      sets = List.generate(10, (_) => SetScore());
    }
    return Match(
      id: json['id'],
      opponent: json['opponent'],
      team: json['team'] ?? 'A',
      date: DateTime.parse(json['date']).toLocal(),
      matchName: json['matchName'] ?? '',
      memo: json['memo'] ?? '',
      opponentColorValue: json['opponentColorValue'] ?? 0xFF2196F3,
      sets: sets,
    );
  }
}
