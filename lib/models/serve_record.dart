// サーブ結果の種類
enum ServeResult {
  ace,      // 決まり（エース）
  under,    // アンダー・二段トス（崩し）
  justIn,   // 入っただけ
  miss,     // ミス
}

extension ServeResultExtension on ServeResult {
  String get label {
    switch (this) {
      case ServeResult.ace:
        return '決まり';
      case ServeResult.under:
        return '二段チャンス';
      case ServeResult.justIn:
        return '入っただけ';
      case ServeResult.miss:
        return 'ミス';
    }
  }

  String get shortLabel {
    switch (this) {
      case ServeResult.ace:
        return '決まり';
      case ServeResult.under:
        return '二段\nチャンス';
      case ServeResult.justIn:
        return '入っただけ';
      case ServeResult.miss:
        return 'ミス';
    }
  }
}

class ServeRecord {
  final String id;
  final String matchId;
  final String playerId;
  final ServeResult result;
  final DateTime timestamp;

  ServeRecord({
    required this.id,
    required this.matchId,
    required this.playerId,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'matchId': matchId,
        'playerId': playerId,
        'result': result.index,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ServeRecord.fromJson(Map<String, dynamic> json) {
    // FirestoreのTimestamp型と文字列型の両方に対応
    DateTime ts;
    final rawTs = json['timestamp'];
    if (rawTs == null) {
      ts = DateTime.now();
    } else if (rawTs is String) {
      // タイムゾーン情報なし文字列はローカル時間として扱う
      // （DateTime.parse()はタイムゾーンなし文字列をUTCと解釈するため
      //   .toLocal()すると+9時間されて翌日扱いになるバグを修正）
      final parsed = DateTime.parse(rawTs);
      // isUtc==trueなら明示的にUTC文字列（末尾Z付き）なのでtoLocal()する
      // isUtc==falseならタイムゾーンなし＝保存時のローカル時間そのままで使う
      ts = parsed.isUtc ? parsed.toLocal() : parsed;
    } else {
      // Firestore Timestamp型 → .toDate()でUTC DateTimeを取得してローカル変換
      try {
        ts = ((rawTs as dynamic).toDate() as DateTime).toLocal();
      } catch (_) {
        ts = DateTime.now();
      }
    }
    return ServeRecord(
      id: json['id'] as String,
      matchId: json['matchId'] as String,
      playerId: json['playerId'] as String,
      result: ServeResult.values[json['result'] as int],
      timestamp: ts,
    );
  }
}

// サーブレシーブ結果の種類
enum ReceiveResult {
  over,     // オーバー
  under,    // アンダー
  direct,   // ダイレクト・二段トス
  miss,     // ミス
}

extension ReceiveResultExtension on ReceiveResult {
  String get label {
    switch (this) {
      case ReceiveResult.over:
        return 'オーバー';
      case ReceiveResult.under:
        return 'アンダー';
      case ReceiveResult.direct:
        return 'ダイレクト・二段';
      case ReceiveResult.miss:
        return 'ミス';
    }
  }

  String get shortLabel {
    switch (this) {
      case ReceiveResult.over:
        return 'オーバー';
      case ReceiveResult.under:
        return 'アンダー';
      case ReceiveResult.direct:
        return 'ダイレクト\n二段';
      case ReceiveResult.miss:
        return 'ミス';
    }
  }
}

class ReceiveRecord {
  final String id;
  final String matchId;
  final String playerId;
  final ReceiveResult result;
  final DateTime timestamp;

  ReceiveRecord({
    required this.id,
    required this.matchId,
    required this.playerId,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'matchId': matchId,
        'playerId': playerId,
        'result': result.index,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ReceiveRecord.fromJson(Map<String, dynamic> json) {
    // FirestoreのTimestamp型と文字列型の両方に対応
    DateTime ts;
    final rawTs = json['timestamp'];
    if (rawTs == null) {
      ts = DateTime.now();
    } else if (rawTs is String) {
      // タイムゾーン情報なし文字列はローカル時間として扱う
      // （DateTime.parse()はタイムゾーンなし文字列をUTCと解釈するため
      //   .toLocal()すると+9時間されて翌日扱いになるバグを修正）
      final parsed = DateTime.parse(rawTs);
      // isUtc==trueなら明示的にUTC文字列（末尾Z付き）なのでtoLocal()する
      // isUtc==falseならタイムゾーンなし＝保存時のローカル時間そのままで使う
      ts = parsed.isUtc ? parsed.toLocal() : parsed;
    } else {
      // Firestore Timestamp型 → .toDate()でUTC DateTimeを取得してローカル変換
      try {
        ts = ((rawTs as dynamic).toDate() as DateTime).toLocal();
      } catch (_) {
        ts = DateTime.now();
      }
    }
    return ReceiveRecord(
      id: json['id'] as String,
      matchId: json['matchId'] as String,
      playerId: json['playerId'] as String,
      result: ReceiveResult.values[json['result'] as int],
      timestamp: ts,
    );
  }
}
