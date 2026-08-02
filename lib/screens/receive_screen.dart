import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/serve_record.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// レシーブ画面（サーブ画面と同じリスト型）
//
// ・currentTeamPlayers を使用 → A/B チーム切り替えで自動的に対応するチームの選手を表示
// ・各選手行に オーバー / アンダー / 二段・ダイレクト / ミス の +ボタン
// ・↩ ボタンで結果別取り消しメニューを展開
// ─────────────────────────────────────────────────────────────────────────────

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  // 取り消しメニューを開いている選手 ID
  String? _undoMenuPlayerId;

  // ─── カラー / ラベルユーティリティ ───────────────────────────────────
  Color _color(ReceiveResult r) {
    switch (r) {
      case ReceiveResult.over:   return AppTheme.overColor;
      case ReceiveResult.under:  return AppTheme.receiveUnderColor;
      case ReceiveResult.direct: return AppTheme.directColor;
      case ReceiveResult.miss:   return AppTheme.receiveMissColor;
    }
  }

  // ─── build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final match = provider.currentMatch;
        // currentTeamPlayers は provider.currentTeam（A or B）に応じた選手リストを返す
        final players = provider.currentTeamPlayers;

        return Scaffold(
          backgroundColor: AppTheme.black,
          body: Column(
            children: [
              _buildHeader(provider, match),
              if (match == null)
                Expanded(child: _buildNoMatch())
              else
                Expanded(
                  child: _buildGrid(provider, match, players),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── ヘッダー ─────────────────────────────────────────────────────────
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('RECEIVE',
                    style: TextStyle(
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
              const SizedBox(width: 8),
              const Text('サーブレシーブ記録',
                  style: TextStyle(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (match != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: provider.currentTeam == 'A'
                        ? AppTheme.primaryRed.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: provider.currentTeam == 'A'
                          ? AppTheme.primaryRed : Colors.blue,
                    ),
                  ),
                  child: Text('${provider.currentTeam}チーム',
                      style: TextStyle(
                          color: provider.currentTeam == 'A'
                              ? AppTheme.primaryRed : Colors.blue,
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (match != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: oc, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('vs ${match.opponent}',
                    style: const TextStyle(
                        color: AppTheme.gold, fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Consumer<AppProvider>(
                  builder: (_, p, __) => Text(
                    '総記録: ${p.getReceiveRecordsByMatch(match.id).length}本',
                    style: const TextStyle(color: AppTheme.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── 試合未選択 ───────────────────────────────────────────────────────
  Widget _buildNoMatch() {
    return Center(
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

  // ─── グリッド全体 ─────────────────────────────────────────────────────
  Widget _buildGrid(AppProvider provider, dynamic match, List players) {
    if (players.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off,
                color: AppTheme.grey.withValues(alpha: 0.4), size: 64),
            const SizedBox(height: 16),
            const Text('選手が登録されていません',
                style: TextStyle(color: AppTheme.grey, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('設定タブから選手を追加してください',
                style: TextStyle(color: AppTheme.grey, fontSize: 13)),
          ],
        ),
      );
    }

    final matchId = match.id;
    final oc = Color(match.opponentColorValue);
    final records = provider.getReceiveRecordsByMatch(matchId);

    return Column(
      children: [
        // ── ヘッダー行 ─────────────────────────────────────────────
        Container(
          color: AppTheme.cardBg,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              const SizedBox(
                width: 80,
                child: Text('選手',
                    style: TextStyle(
                        color: AppTheme.gold, fontSize: 12,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              ),
              ...ReceiveResult.values.map((r) => Expanded(child: _headerCell(r))),
              const SizedBox(
                width: 40,
                child: Text('戻す',
                    style: TextStyle(color: AppTheme.grey, fontSize: 9),
                    textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.cardBg2),

        // ── 選手行リスト ────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            itemCount: players.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppTheme.cardBg2),
            itemBuilder: (context, index) {
              final player = players[index];
              final playerRecords =
                  records.where((r) => r.playerId == player.id).toList();
              return _buildPlayerRow(
                  context, provider, player, matchId, playerRecords, oc);
            },
          ),
        ),

        // ── 合計行 ─────────────────────────────────────────────────
        _buildTotalRow(records, oc),
      ],
    );
  }

  // ─── ヘッダーセル ─────────────────────────────────────────────────────
  Widget _headerCell(ReceiveResult r) {
    final color = _color(r);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 2),
          Text(r.shortLabel,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ─── 選手行 ───────────────────────────────────────────────────────────
  Widget _buildPlayerRow(
    BuildContext context,
    AppProvider provider,
    dynamic player,
    String matchId,
    List<ReceiveRecord> playerRecords,
    Color oc,
  ) {
    final isUndoOpen = _undoMenuPlayerId == player.id;

    final counts = <ReceiveResult, int>{
      for (final r in ReceiveResult.values)
        r: playerRecords.where((rec) => rec.result == r).length,
    };
    final total = playerRecords.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              // ── 選手名セル ──────────────────────────────────────
              SizedBox(
                width: 80,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(player.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis),
                    if (total > 0)
                      Text('$total本',
                          style: const TextStyle(
                              color: AppTheme.grey, fontSize: 10)),
                  ],
                ),
              ),

              // ── 結果別 +ボタン ──────────────────────────────────
              ...ReceiveResult.values.map((r) {
                final count = counts[r] ?? 0;
                return Expanded(
                  child: _countButton(
                    count: count,
                    result: r,
                    onTap: () async {
                      await provider.addReceiveRecord(
                        matchId: matchId,
                        playerId: player.id,
                        result: r,
                      );
                    },
                  ),
                );
              }),

              // ── 取り消しボタン ──────────────────────────────────
              SizedBox(
                width: 40,
                child: GestureDetector(
                  onTap: total > 0
                      ? () {
                          setState(() {
                            _undoMenuPlayerId =
                                isUndoOpen ? null : player.id as String;
                          });
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.all(3),
                    height: 48,
                    decoration: BoxDecoration(
                      color: isUndoOpen
                          ? Colors.blue.withValues(alpha: 0.2)
                          : total > 0
                              ? AppTheme.cardBg2
                              : AppTheme.cardBg2.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isUndoOpen
                            ? Colors.blue.withValues(alpha: 0.6)
                            : total > 0
                                ? const Color(0xFF555555)
                                : const Color(0xFF333333),
                      ),
                    ),
                    child: Icon(
                      isUndoOpen ? Icons.close : Icons.undo,
                      color: isUndoOpen
                          ? Colors.lightBlueAccent
                          : total > 0
                              ? AppTheme.lightGrey
                              : AppTheme.grey.withValues(alpha: 0.3),
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── 取り消しメニュー（展開時のみ）─────────────────────────
        if (isUndoOpen)
          _buildUndoMenu(context, provider, player, matchId, playerRecords, counts),
      ],
    );
  }

  // ─── 取り消しメニュー ─────────────────────────────────────────────────
  Widget _buildUndoMenu(
    BuildContext context,
    AppProvider provider,
    dynamic player,
    String matchId,
    List<ReceiveRecord> playerRecords,
    Map<ReceiveResult, int> counts,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF001A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('取り消す結果を選択：',
                style: TextStyle(color: AppTheme.lightGrey, fontSize: 11)),
          ),
          Row(
            children: ReceiveResult.values.map((r) {
              final count = counts[r] ?? 0;
              final color = _color(r);
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
                          setState(() => _undoMenuPlayerId = null);
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: count > 0
                          ? color.withValues(alpha: 0.2)
                          : AppTheme.cardBg2.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: count > 0
                            ? color.withValues(alpha: 0.7)
                            : const Color(0xFF333333),
                        width: count > 0 ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(count > 0 ? '-1' : '－',
                            style: TextStyle(
                                color: count > 0 ? color : AppTheme.grey,
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(r.shortLabel,
                            style: TextStyle(
                                color: count > 0 ? color : AppTheme.grey,
                                fontSize: 9),
                            textAlign: TextAlign.center),
                        if (count > 0)
                          Text('($count)',
                              style: TextStyle(color: color, fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── +ボタン ─────────────────────────────────────────────────────────
  Widget _countButton({
    required int count,
    required ReceiveResult result,
    required VoidCallback onTap,
  }) {
    final color = _color(result);
    final bgColor = count > 0
        ? color.withValues(alpha: 0.2)
        : AppTheme.cardBg2;
    final borderColor = count > 0 ? color : const Color(0xFF444444);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.all(3),
        height: 52,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: count > 0
              ? [BoxShadow(
                  color: borderColor.withValues(alpha: 0.3), blurRadius: 4)]
              : null,
        ),
        child: Center(
          child: Text(
            count > 0 ? '$count' : '+',
            style: TextStyle(
              color: count > 0 ? Colors.white : AppTheme.grey,
              fontSize: count > 0 ? 20 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ─── 合計行 ───────────────────────────────────────────────────────────
  Widget _buildTotalRow(List<ReceiveRecord> records, Color oc) {
    final totals = <ReceiveResult, int>{
      for (final r in ReceiveResult.values)
        r: records.where((rec) => rec.result == r).length,
    };
    final grand = records.length;

    return Container(
      color: AppTheme.cardBg,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Column(
              children: [
                const Text('合計',
                    style: TextStyle(
                        color: AppTheme.gold, fontSize: 12,
                        fontWeight: FontWeight.bold)),
                Text('$grand本',
                    style: const TextStyle(
                        color: AppTheme.grey, fontSize: 10)),
              ],
            ),
          ),
          ...ReceiveResult.values.map((r) {
            final count = totals[r] ?? 0;
            final pct = grand > 0
                ? (count / grand * 100).toStringAsFixed(0) : '0';
            final color = _color(r);
            return Expanded(
              child: Column(
                children: [
                  Text('$count',
                      style: TextStyle(
                          color: color, fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text('$pct%',
                      style: const TextStyle(
                          color: AppTheme.grey, fontSize: 10)),
                ],
              ),
            );
          }),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
