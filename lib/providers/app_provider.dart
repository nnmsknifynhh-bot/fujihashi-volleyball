import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/player.dart';
import '../models/match.dart';
import '../models/serve_record.dart';

class AppProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final _db = FirebaseFirestore.instance;

  List<Player> _players = [];
  List<Match> _matches = [];
  List<ServeRecord> _serveRecords = [];
  List<ReceiveRecord> _receiveRecords = [];

  String _currentTeam = 'A';
  String? _currentMatchId;
  bool _isLoading = true;

  // リアルタイムリスナーのサブスクリプション
  StreamSubscription? _playersSub;
  StreamSubscription? _matchesSub;
  StreamSubscription? _servesSub;
  StreamSubscription? _receivesSub;

  List<Player> get players => _players;
  List<Match> get matches => _matches;
  List<ServeRecord> get serveRecords => _serveRecords;
  List<ReceiveRecord> get receiveRecords => _receiveRecords;
  String get currentTeam => _currentTeam;
  String? get currentMatchId => _currentMatchId;
  bool get isLoading => _isLoading;

  // チーム名を正規化（大文字・半角・トリム）して比較
  static String _normalizeTeam(String t) => t.trim().toUpperCase()
      .replaceAll('Ａ', 'A').replaceAll('Ｂ', 'B'); // 全角対応

  List<Player> get teamAPlayers =>
      _players.where((p) => _normalizeTeam(p.team) == 'A').toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<Player> get teamBPlayers =>
      _players.where((p) => _normalizeTeam(p.team) == 'B').toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<Player> get currentTeamPlayers =>
      _players.where((p) => _normalizeTeam(p.team) == _normalizeTeam(_currentTeam)).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Match? get currentMatch =>
      _currentMatchId != null
          ? _matches.firstWhere((m) => m.id == _currentMatchId,
              orElse: () => _matches.isNotEmpty ? _matches.first : Match(
                id: '', opponent: '', date: DateTime.now(),
                opponentColorValue: 0xFF2196F3,
              ))
          : null;

  AppProvider() {
    _startListening();
  }

  // ── Firestoreリアルタイムリスナーを開始 ──
  void _startListening() {
    // players
    _playersSub = _db.collection('players').snapshots().listen(
      (snap) {
        _players = snap.docs
            .where((d) => d.id != '_placeholder')
            .map((d) {
              try {
                final p = Player.fromJson(d.data());
                // Firestoreのチーム値を正規化（'a'→'A'、全角・スペース除去）
                p.team = _normalizeTeam(p.team);
                return p;
              }
              catch (_) { return null; }
            })
            .whereType<Player>()
            .toList();
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _isLoading = false;
        notifyListeners();
      },
    );

    // matches
    _matchesSub = _db.collection('matches').snapshots().listen(
      (snap) {
        _matches = snap.docs
            .where((d) => d.id != '_placeholder')
            .map((d) {
              try { return Match.fromJson(d.data()); }
              catch (_) { return null; }
            })
            .whereType<Match>()
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        notifyListeners();
      },
      onError: (_) => notifyListeners(),
    );

    // serve_records
    _servesSub = _db.collection('serve_records').snapshots().listen(
      (snap) {
        _serveRecords = snap.docs
            .where((d) => d.id != '_placeholder')
            .map((d) {
              try { return ServeRecord.fromJson(d.data()); }
              catch (_) { return null; }
            })
            .whereType<ServeRecord>()
            .toList();
        notifyListeners();
      },
      onError: (_) => notifyListeners(),
    );

    // receive_records
    _receivesSub = _db.collection('receive_records').snapshots().listen(
      (snap) {
        _receiveRecords = snap.docs
            .where((d) => d.id != '_placeholder')
            .map((d) {
              try { return ReceiveRecord.fromJson(d.data()); }
              catch (_) { return null; }
            })
            .whereType<ReceiveRecord>()
            .toList();
        notifyListeners();
      },
      onError: (_) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _playersSub?.cancel();
    _matchesSub?.cancel();
    _servesSub?.cancel();
    _receivesSub?.cancel();
    super.dispose();
  }

  // ── チーム切り替え ──
  void setCurrentTeam(String team) {
    _currentTeam = team;
    notifyListeners();
  }

  // ── 現在の試合を設定 ──
  void setCurrentMatch(String? matchId) {
    _currentMatchId = matchId;
    notifyListeners();
  }

  // ── 試合を追加 ──
  Future<Match> addMatch({
    required String opponent,
    required String team,
    required DateTime date,
    String matchName = '',
    String memo = '',
    int colorValue = 0xFF2196F3,
  }) async {
    final match = Match(
      id: _uuid.v4(),
      opponent: opponent,
      team: team,
      date: date,
      matchName: matchName,
      memo: memo,
      opponentColorValue: colorValue,
    );
    await _db.collection('matches').doc(match.id).set(match.toJson());
    return match;
  }

  // ── セットスコアを更新 ──
  Future<void> updateSetScore(
      String matchId, int setIndex, int ourScore, int theirScore) async {
    final idx = _matches.indexWhere((m) => m.id == matchId);
    if (idx < 0) return;
    _matches[idx].sets[setIndex].ourScore = ourScore;
    _matches[idx].sets[setIndex].theirScore = theirScore;
    await _db
        .collection('matches')
        .doc(matchId)
        .update({'sets': _matches[idx].sets.map((s) => s.toJson()).toList()});
  }

  // ── 試合を削除 ──
  Future<void> deleteMatch(String matchId) async {
    if (_currentMatchId == matchId) _currentMatchId = null;
    await _db.collection('matches').doc(matchId).delete();
    // 関連する記録も削除
    final serveBatch = _db.batch();
    for (final r in _serveRecords.where((r) => r.matchId == matchId)) {
      serveBatch.delete(_db.collection('serve_records').doc(r.id));
    }
    await serveBatch.commit();
    final receiveBatch = _db.batch();
    for (final r in _receiveRecords.where((r) => r.matchId == matchId)) {
      receiveBatch.delete(_db.collection('receive_records').doc(r.id));
    }
    await receiveBatch.commit();
  }

  // ── サーブ記録を追加 ──
  Future<void> addServeRecord({
    required String matchId,
    required String playerId,
    required ServeResult result,
  }) async {
    final record = ServeRecord(
      id: _uuid.v4(),
      matchId: matchId,
      playerId: playerId,
      result: result,
      timestamp: DateTime.now(),
    );
    await _db.collection('serve_records').doc(record.id).set(record.toJson());
  }

  // ── サーブ記録を取り消し（最後の1件） ──
  Future<void> undoLastServeRecord(String matchId, String playerId) async {
    final records = _serveRecords
        .where((r) => r.matchId == matchId && r.playerId == playerId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (records.isNotEmpty) {
      await _db.collection('serve_records').doc(records.first.id).delete();
    }
  }

  // ── サーブ記録を削除 ──
  Future<void> deleteServeRecord(String recordId) async {
    await _db.collection('serve_records').doc(recordId).delete();
  }

  // ── レシーブ記録を追加 ──
  Future<void> addReceiveRecord({
    required String matchId,
    required String playerId,
    required ReceiveResult result,
  }) async {
    final record = ReceiveRecord(
      id: _uuid.v4(),
      matchId: matchId,
      playerId: playerId,
      result: result,
      timestamp: DateTime.now(),
    );
    await _db.collection('receive_records').doc(record.id).set(record.toJson());
  }

  // ── レシーブ記録を取り消し（最後の1件） ──
  Future<void> undoLastReceiveRecord(String matchId, String playerId) async {
    final records = _receiveRecords
        .where((r) => r.matchId == matchId && r.playerId == playerId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (records.isNotEmpty) {
      await _db.collection('receive_records').doc(records.first.id).delete();
    }
  }

  // ── 選手を追加 ──
  Future<void> addPlayer({
    required String name,
    String number = '',
    String team = 'A',
  }) async {
    final maxOrder = _players.isEmpty
        ? 0
        : _players.map((p) => p.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final player = Player(
      id: _uuid.v4(),
      name: name,
      number: number,
      team: _normalizeTeam(team), // 正規化して保存
      sortOrder: maxOrder,
    );
    await _db.collection('players').doc(player.id).set(player.toJson());
  }

  // ── 選手を更新 ──
  Future<void> updatePlayer(Player player) async {
    player.team = _normalizeTeam(player.team); // 正規化して保存
    await _db.collection('players').doc(player.id).set(player.toJson());
  }

  // ── 選手を削除 ──
  Future<void> deletePlayer(String playerId) async {
    await _db.collection('players').doc(playerId).delete();
  }

  // ── 試合別サーブ記録取得 ──
  List<ServeRecord> getServeRecordsByMatch(String matchId) =>
      _serveRecords.where((r) => r.matchId == matchId).toList();

  // ── 試合別レシーブ記録取得 ──
  List<ReceiveRecord> getReceiveRecordsByMatch(String matchId) =>
      _receiveRecords.where((r) => r.matchId == matchId).toList();

  // ── 選手別サーブ集計 ──
  Map<ServeResult, int> getServeStatsByPlayer(
      String playerId, {String? matchId, DateTime? from, DateTime? to}) {
    var records = _serveRecords.where((r) => r.playerId == playerId);
    if (matchId != null) records = records.where((r) => r.matchId == matchId);
    if (from != null) records = records.where((r) => !r.timestamp.isBefore(from));
    if (to != null) records = records.where((r) => r.timestamp.isBefore(to));
    final result = <ServeResult, int>{};
    for (final r in ServeResult.values) {
      result[r] = records.where((rec) => rec.result == r).length;
    }
    return result;
  }

  // ── 選手別レシーブ集計 ──
  Map<ReceiveResult, int> getReceiveStatsByPlayer(
      String playerId, {String? matchId, DateTime? from, DateTime? to}) {
    var records = _receiveRecords.where((r) => r.playerId == playerId);
    if (matchId != null) records = records.where((r) => r.matchId == matchId);
    if (from != null) records = records.where((r) => !r.timestamp.isBefore(from));
    if (to != null) records = records.where((r) => r.timestamp.isBefore(to));
    final result = <ReceiveResult, int>{};
    for (final r in ReceiveResult.values) {
      result[r] = records.where((rec) => rec.result == r).length;
    }
    return result;
  }

  // ── 今日の試合一覧 ──
  List<Match> get todayMatches {
    final today = DateTime.now();
    return _matches
        .where((m) =>
            m.date.year == today.year &&
            m.date.month == today.month &&
            m.date.day == today.day)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // ── 対戦相手カラー取得 ──
  int getOpponentColor(String opponent) {
    final match = _matches.lastWhere(
      (m) => m.opponent == opponent,
      orElse: () => Match(
        id: '', opponent: '', date: DateTime.now(),
        opponentColorValue: 0xFF2196F3,
      ),
    );
    return match.opponentColorValue;
  }
}
