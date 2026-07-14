import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/serve_record.dart';
import '../models/player.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// レシーブ画面
//   バレーボールのレシーブ隊形でコート上に選手を配置し、
//   各選手をタップ＆フリックして結果入力する。
//
// 画面レイアウト（上=ネット）:
//   [前衛中]          ← sortOrder=0 or 先頭
//   [中衛左] [中衛中] [中衛右]
//   [後衛左]          [後衛右]
//
// ポジション割り当て: sortOrder の順番で 0〜5 に対応
//   index 0 → 前衛中央
//   index 1 → 中衛左
//   index 2 → 中衛中央
//   index 3 → 中衛右
//   index 4 → 後衛左
//   index 5 → 後衛右
// ─────────────────────────────────────────────────────────────────────────────

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen>
    with TickerProviderStateMixin {
  // フリック状態（選手IDごと）
  final Map<String, Offset?> _flickStarts = {};
  final Map<String, ReceiveResult?> _previews = {};

  // フラッシュアニメーション（選手IDごと）
  final Map<String, AnimationController> _flashCtrls = {};
  final Map<String, ReceiveResult?> _flashResults = {};

  // 修正パネルを開いている選手ID
  String? _editPlayerId;

  @override
  void dispose() {
    for (final c in _flashCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // AnimationController を選手ごとに遅延生成
  AnimationController _ctrl(String playerId) {
    return _flashCtrls.putIfAbsent(
      playerId,
      () => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  // ─── ユーティリティ ───────────────────────────────────────────────
  Color _color(ReceiveResult r) {
    switch (r) {
      case ReceiveResult.over:   return AppTheme.overColor;
      case ReceiveResult.under:  return AppTheme.receiveUnderColor;
      case ReceiveResult.direct: return AppTheme.directColor;
      case ReceiveResult.miss:   return AppTheme.receiveMissColor;
    }
  }

  String _label(ReceiveResult r) {
    switch (r) {
      case ReceiveResult.over:   return 'オーバー';
      case ReceiveResult.under:  return 'アンダー';
      case ReceiveResult.direct: return '二段・ダイレクト';
      case ReceiveResult.miss:   return 'ミス';
    }
  }

  String _shortLabel(ReceiveResult r) {
    switch (r) {
      case ReceiveResult.over:   return 'オーバー';
      case ReceiveResult.under:  return 'アンダー';
      case ReceiveResult.direct: return '二段\nダイレクト';
      case ReceiveResult.miss:   return 'ミス';
    }
  }

  IconData _icon(ReceiveResult r) {
    switch (r) {
      case ReceiveResult.over:   return Icons.arrow_upward;
      case ReceiveResult.under:  return Icons.arrow_back;
      case ReceiveResult.direct: return Icons.arrow_forward;
      case ReceiveResult.miss:   return Icons.close;
    }
  }

  // フリック方向判定（threshold=18px）
  ReceiveResult? _detect(Offset delta) {
    const t = 18.0;
    if (delta.distance < t) return null;
    final a = delta.direction;
    if (a > -3 * 3.14159 / 4 && a < -3.14159 / 4) return ReceiveResult.over;
    if (a >  3.14159 / 4 && a <  3 * 3.14159 / 4) return ReceiveResult.miss;
    if (a > -3.14159 / 4 && a <  3.14159 / 4)     return ReceiveResult.direct;
    return ReceiveResult.under;
  }

  void _triggerFlash(String playerId, ReceiveResult r) {
    setState(() => _flashResults[playerId] = r);
    _ctrl(playerId).forward(from: 0);
  }

  // ─── ポジション割り当て ───────────────────────────────────────────
  // players を sortOrder でソート済みと仮定し、index で位置を決める
  // 6ポジション定義（フレックスグリッドで配置）
  // row0: [_, p0, _]   前衛中
  // row1: [p1, p2, p3] 中衛
  // row2: [p4, _, p5]  後衛

  // ─── build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final match = provider.currentMatch;
        final players = provider.currentTeamPlayers; // sortOrder順

        return Scaffold(
          backgroundColor: AppTheme.black,
          body: Column(
            children: [
              _buildHeader(provider, match),
              if (match == null)
                const Expanded(child: _NoMatch())
              else if (players.isEmpty)
                const Expanded(child: _NoPlayers())
              else
                Expanded(
                  child: _buildCourt(context, provider, match, players),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── ヘッダー ─────────────────────────────────────────────────────
  Widget _buildHeader(AppProvider provider, dynamic match) {
    final oc = match != null ? Color(match.opponentColorValue) : Colors.blue;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF001A2A),
            oc.withValues(alpha: 0.15),
            const Color(0xFF0A0A0A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(bottom: BorderSide(color: oc, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('RECEIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
              ),
              const SizedBox(width: 8),
              const Text('サーブレシーブ記録',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (match != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: provider.currentTeam == 'A'
                        ? AppTheme.primaryRed.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: provider.currentTeam == 'A'
                          ? AppTheme.primaryRed
                          : Colors.blue,
                    ),
                  ),
                  child: Text('${provider.currentTeam}チーム',
                      style: TextStyle(
                          color: provider.currentTeam == 'A'
                              ? AppTheme.primaryRed
                              : Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (match != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Container(
                  width: 7, height: 7,
                  decoration:
                      BoxDecoration(color: oc, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('vs ${match.opponent}',
                  style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Consumer<AppProvider>(
                builder: (_, p, __) => Text(
                  '総記録: ${p.getReceiveRecordsByMatch(match.id).length}本',
                  style:
                      const TextStyle(color: AppTheme.grey, fontSize: 12)),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  // ─── コート全体 ───────────────────────────────────────────────────
  Widget _buildCourt(BuildContext context, AppProvider provider,
      dynamic match, List<Player> players) {
    final matchId = match.id;
    final records = provider.getReceiveRecordsByMatch(matchId);

    // 最大6名まで使用（足りない場合はその分だけ表示）
    final p = players.take(6).toList();

    // 選手を取得するヘルパー（インデックス越えは null）
    Player? at(int i) => i < p.length ? p[i] : null;

    return Column(
      children: [
        // ネットライン
        _netBar(),

        // コートエリア（Expanded で残り高さをすべて使う）
        Expanded(
          child: Container(
            color: const Color(0xFF0D1A0D), // 暗い緑
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Column(
              children: [
                // 前衛行：中央1人
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      const Expanded(flex: 1, child: SizedBox()),
                      Expanded(
                        flex: 2,
                        child: at(0) != null
                            ? _playerCell(
                                context, provider, matchId, at(0)!, records)
                            : const SizedBox(),
                      ),
                      const Expanded(flex: 1, child: SizedBox()),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // 中衛行：左・中・右 3人
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Expanded(
                        child: at(1) != null
                            ? _playerCell(
                                context, provider, matchId, at(1)!, records)
                            : const SizedBox(),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: at(2) != null
                            ? _playerCell(
                                context, provider, matchId, at(2)!, records)
                            : const SizedBox(),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: at(3) != null
                            ? _playerCell(
                                context, provider, matchId, at(3)!, records)
                            : const SizedBox(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // 後衛行：左・右 2人（中央は空白）
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Expanded(
                        child: at(4) != null
                            ? _playerCell(
                                context, provider, matchId, at(4)!, records)
                            : const SizedBox(),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(child: SizedBox()), // 中央空白
                      const SizedBox(width: 6),
                      Expanded(
                        child: at(5) != null
                            ? _playerCell(
                                context, provider, matchId, at(5)!, records)
                            : const SizedBox(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),
                // 下部：凡例 + 合計
                _buildLegendBar(records),
              ],
            ),
          ),
        ),

        // 修正パネル（展開式）
        _buildEditSection(provider, matchId, players, records),
      ],
    );
  }

  // ネットバー
  Widget _netBar() {
    return Container(
      width: double.infinity,
      height: 28,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF001133), Color(0xFF002266), Color(0xFF001133)],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFF4488FF), width: 2),
        ),
      ),
      child: const Center(
        child: Text(
          '━━━━━  N E T  ━━━━━',
          style: TextStyle(
            color: Color(0xFF6699FF),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }

  // ─── 選手セル（フリック入力エリア）────────────────────────────────
  Widget _playerCell(
    BuildContext context,
    AppProvider provider,
    String matchId,
    Player player,
    List<ReceiveRecord> allRecords,
  ) {
    final pid = player.id;
    final playerRecords = allRecords.where((r) => r.playerId == pid).toList();
    final counts = <ReceiveResult, int>{
      for (final r in ReceiveResult.values)
        r: playerRecords.where((rec) => rec.result == r).length,
    };
    final total = playerRecords.length;
    final preview = _previews[pid];
    final flashResult = _flashResults[pid];
    final ctrl = _ctrl(pid);

    return GestureDetector(
      onPanStart: (d) {
        setState(() {
          _flickStarts[pid] = d.localPosition;
          _previews[pid] = null;
          _editPlayerId = null; // 入力開始したら修正パネルを閉じる
        });
      },
      onPanUpdate: (d) {
        final start = _flickStarts[pid];
        if (start == null) return;
        final detected = _detect(d.localPosition - start);
        if (detected != _previews[pid]) {
          setState(() => _previews[pid] = detected);
        }
      },
      onPanEnd: (d) async {
        final result = _previews[pid];
        setState(() {
          _flickStarts.remove(pid);
          _previews[pid] = null;
        });
        if (result != null) {
          _triggerFlash(pid, result);
          await provider.addReceiveRecord(
            matchId: matchId,
            playerId: pid,
            result: result,
          );
        }
      },
      onPanCancel: () {
        setState(() {
          _flickStarts.remove(pid);
          _previews[pid] = null;
        });
      },
      // 長押しで修正パネルを開く
      onLongPress: () {
        setState(() {
          _editPlayerId = _editPlayerId == pid ? null : pid;
        });
      },
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (context, child) {
          final flashOpacity = flashResult != null
              ? (1 - ctrl.value).clamp(0.0, 1.0)
              : 0.0;
          return Stack(
            children: [
              // 本体
              child!,
              // フラッシュオーバーレイ
              if (flashOpacity > 0.01 && flashResult != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _color(flashResult)
                            .withValues(alpha: flashOpacity * 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Opacity(
                          opacity: flashOpacity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_icon(flashResult),
                                  color: _color(flashResult), size: 28),
                              Text(
                                _label(flashResult),
                                style: TextStyle(
                                  color: _color(flashResult),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        child: _playerCellBody(player, counts, total, preview),
      ),
    );
  }

  Widget _playerCellBody(
    Player player,
    Map<ReceiveResult, int> counts,
    int total,
    ReceiveResult? preview,
  ) {
    final borderColor = preview != null
        ? _color(preview)
        : _editPlayerId == player.id
            ? Colors.lightBlueAccent
            : const Color(0xFF2A4A2A);

    final bgColor = preview != null
        ? _color(preview).withValues(alpha: 0.18)
        : _editPlayerId == player.id
            ? Colors.blue.withValues(alpha: 0.12)
            : const Color(0xFF152015);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: preview != null ? 2.0 : 1.0,
        ),
        boxShadow: preview != null
            ? [BoxShadow(
                color: _color(preview).withValues(alpha: 0.4),
                blurRadius: 12,
              )]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── 上部：フリックヒント（上=オーバー）
          _flickHintTop(counts[ReceiveResult.over] ?? 0,
              preview == ReceiveResult.over),

          // ── 中央：左右ヒント + 選手名
          Row(
            children: [
              // 左（アンダー）
              _flickHintSide(
                  counts[ReceiveResult.under] ?? 0,
                  preview == ReceiveResult.under,
                  ReceiveResult.under,
                  isLeft: true),
              // 中央：選手名
              Expanded(child: _playerNameArea(player, total, preview)),
              // 右（二段・ダイレクト）
              _flickHintSide(
                  counts[ReceiveResult.direct] ?? 0,
                  preview == ReceiveResult.direct,
                  ReceiveResult.direct,
                  isLeft: false),
            ],
          ),

          // ── 下部：フリックヒント（下=ミス）
          _flickHintBottom(counts[ReceiveResult.miss] ?? 0,
              preview == ReceiveResult.miss),
        ],
      ),
    );
  }

  // 上フリックヒント（オーバー）
  Widget _flickHintTop(int count, bool active) {
    const r = ReceiveResult.over;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: active
            ? _color(r).withValues(alpha: 0.3)
            : Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_upward,
              color: active ? _color(r) : _color(r).withValues(alpha: 0.4),
              size: active ? 14 : 11),
          Text(
            count > 0 ? '$count' : 'オーバー',
            style: TextStyle(
              color: active ? _color(r) : _color(r).withValues(alpha: 0.5),
              fontSize: count > 0 ? 11 : 9,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // 下フリックヒント（ミス）
  Widget _flickHintBottom(int count, bool active) {
    const r = ReceiveResult.miss;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: active
            ? _color(r).withValues(alpha: 0.3)
            : Colors.transparent,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count > 0 ? '$count' : 'ミス',
            style: TextStyle(
              color: active ? _color(r) : _color(r).withValues(alpha: 0.5),
              fontSize: count > 0 ? 11 : 9,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Icon(Icons.arrow_downward,
              color: active ? _color(r) : _color(r).withValues(alpha: 0.4),
              size: active ? 14 : 11),
        ],
      ),
    );
  }

  // 左右フリックヒント
  Widget _flickHintSide(int count, bool active, ReceiveResult r,
      {required bool isLeft}) {
    final label = isLeft ? 'ア\nン\nダ\nー' : '二\n段\n・\nDirect';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 22,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: active ? _color(r).withValues(alpha: 0.3) : Colors.transparent,
        borderRadius: isLeft
            ? const BorderRadius.horizontal(left: Radius.circular(10))
            : const BorderRadius.horizontal(right: Radius.circular(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLeft)
            Icon(Icons.arrow_back,
                color: active ? _color(r) : _color(r).withValues(alpha: 0.4),
                size: active ? 12 : 10)
          else
            Icon(Icons.arrow_forward,
                color: active ? _color(r) : _color(r).withValues(alpha: 0.4),
                size: active ? 12 : 10),
          if (count > 0)
            Text(
              '$count',
              style: TextStyle(
                color: active ? _color(r) : _color(r).withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              label,
              style: TextStyle(
                color: active ? _color(r) : _color(r).withValues(alpha: 0.4),
                fontSize: 7,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  // 選手名エリア（中央）
  Widget _playerNameArea(Player player, int total, ReceiveResult? preview) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (player.number.isNotEmpty)
          Text(
            '#${player.number}',
            style: const TextStyle(
              color: AppTheme.gold,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        Text(
          player.name,
          style: TextStyle(
            color: preview != null ? Colors.white : const Color(0xFFDDFFDD),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        if (total > 0)
          Text(
            '$total本',
            style: TextStyle(
              color: preview != null
                  ? _color(preview).withValues(alpha: 0.9)
                  : Colors.lightBlueAccent.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        // 長押しヒント（記録がある場合）
        if (total > 0 && preview == null)
          const Text(
            '長押し=修正',
            style: TextStyle(color: Color(0xFF446644), fontSize: 7),
          ),
      ],
    );
  }

  // ─── 凡例バー ─────────────────────────────────────────────────────
  Widget _buildLegendBar(List<ReceiveRecord> records) {
    final total = records.length;
    final counts = <ReceiveResult, int>{
      for (final r in ReceiveResult.values)
        r: records.where((rec) => rec.result == r).length,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardBg.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('合計 $total本',
              style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          ...ReceiveResult.values.map((r) {
            final c = counts[r] ?? 0;
            final pct = total > 0
                ? '${(c / total * 100).toStringAsFixed(0)}%'
                : '-';
            return Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_icon(r), color: _color(r), size: 10),
                  const SizedBox(width: 2),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$c',
                          style: TextStyle(
                              color: _color(r),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      Text(pct,
                          style: const TextStyle(
                              color: AppTheme.grey, fontSize: 9)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 修正パネル（長押しで展開）──────────────────────────────────
  Widget _buildEditSection(AppProvider provider, String matchId,
      List<Player> players, List<ReceiveRecord> allRecords) {
    if (_editPlayerId == null) return const SizedBox.shrink();

    final player = players.firstWhere(
      (p) => p.id == _editPlayerId,
      orElse: () => players.first,
    );
    final playerRecords =
        allRecords.where((r) => r.playerId == player.id).toList();
    final counts = <ReceiveResult, int>{
      for (final r in ReceiveResult.values)
        r: playerRecords.where((rec) => rec.result == r).length,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF001A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${player.name} の記録を修正',
                style: const TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _editPlayerId = null),
                child: const Icon(Icons.close,
                    color: AppTheme.grey, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('▼ 1本取り消す（最新の記録を削除）',
              style: TextStyle(color: AppTheme.grey, fontSize: 10)),
          const SizedBox(height: 6),
          Row(
            children: ReceiveResult.values.map((r) {
              final count = counts[r] ?? 0;
              return Expanded(
                child: GestureDetector(
                  onTap: count > 0
                      ? () async {
                          final toDelete = playerRecords
                              .where((rec) => rec.result == r)
                              .toList()
                            ..sort((a, b) =>
                                b.timestamp.compareTo(a.timestamp));
                          if (toDelete.isNotEmpty) {
                            await provider
                                .deleteReceiveRecord(toDelete.first.id);
                          }
                          if ((count - 1) <= 0 &&
                              counts.values
                                      .fold(0, (a, b) => a + b) -
                                  1 <=
                              0) {
                            setState(() => _editPlayerId = null);
                          }
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: count > 0
                          ? _color(r).withValues(alpha: 0.2)
                          : AppTheme.cardBg2.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: count > 0
                            ? _color(r).withValues(alpha: 0.7)
                            : const Color(0xFF333333),
                        width: count > 0 ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          count > 0 ? '-1' : '－',
                          style: TextStyle(
                              color: count > 0 ? _color(r) : AppTheme.grey,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _shortLabel(r),
                          style: TextStyle(
                              color: count > 0 ? _color(r) : AppTheme.grey,
                              fontSize: 8),
                          textAlign: TextAlign.center,
                        ),
                        if (count > 0)
                          Text(
                            '($count)',
                            style: TextStyle(color: _color(r), fontSize: 9),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          // 全削除ボタン
          if (playerRecords.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.cardBg,
                    title: const Text('全記録を削除',
                        style: TextStyle(color: Colors.white)),
                    content: Text(
                      '${player.name} の全レシーブ記録 (${playerRecords.length}本) を削除しますか？',
                      style: const TextStyle(color: AppTheme.lightGrey),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('キャンセル',
                              style: TextStyle(color: AppTheme.grey))),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('削除',
                              style: TextStyle(
                                  color: AppTheme.receiveMissColor))),
                    ],
                  ),
                );
                if (ok == true) {
                  for (final rec in playerRecords) {
                    await provider.deleteReceiveRecord(rec.id);
                  }
                  setState(() => _editPlayerId = null);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color:
                      AppTheme.receiveMissColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.receiveMissColor
                          .withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_sweep,
                        color: AppTheme.receiveMissColor, size: 14),
                    SizedBox(width: 6),
                    Text('全記録を削除',
                        style: TextStyle(
                            color: AppTheme.receiveMissColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── エラー表示ウィジェット ───────────────────────────────────────────
class _NoMatch extends StatelessWidget {
  const _NoMatch();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_volleyball,
                color: AppTheme.grey.withValues(alpha: 0.4), size: 64),
            const SizedBox(height: 16),
            const Text('試合が選択されていません',
                style: TextStyle(color: AppTheme.grey, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('ホームタブから試合を選択してください',
                style: TextStyle(color: AppTheme.grey, fontSize: 13)),
          ],
        ),
      );
}

class _NoPlayers extends StatelessWidget {
  const _NoPlayers();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off,
                color: AppTheme.grey.withValues(alpha: 0.4), size: 64),
            const SizedBox(height: 16),
            const Text('選手が登録されていません',
                style: TextStyle(color: AppTheme.grey, fontSize: 16)),
          ],
        ),
      );
}
