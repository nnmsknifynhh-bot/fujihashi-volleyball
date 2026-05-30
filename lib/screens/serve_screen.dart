import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/serve_record.dart';
import '../utils/app_theme.dart';

class ServeScreen extends StatefulWidget {
  const ServeScreen({super.key});

  @override
  State<ServeScreen> createState() => _ServeScreenState();
}

class _ServeScreenState extends State<ServeScreen> {
  String? _lastUndoPlayerId;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final currentMatch = provider.currentMatch;
        final players = provider.currentTeamPlayers;

        return Scaffold(
          backgroundColor: AppTheme.black,
          body: Column(
            children: [
              _buildHeader(provider, currentMatch),
              if (currentMatch == null)
                Expanded(child: _buildNoMatchSelected())
              else
                Expanded(
                  child: _buildServeGrid(provider, currentMatch, players),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(AppProvider provider, dynamic currentMatch) {
    final opponentColor = currentMatch != null
        ? Color(currentMatch.opponentColorValue)
        : AppTheme.primaryRed;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A0000),
            opponentColor.withValues(alpha: 0.15),
            const Color(0xFF0A0A0A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: opponentColor, width: 2),
        ),
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
                  color: AppTheme.primaryRed,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'SERVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'サーブ記録',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (currentMatch != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: provider.currentTeam == 'A'
                        ? AppTheme.primaryRed.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: provider.currentTeam == 'A' ? AppTheme.primaryRed : Colors.blue,
                    ),
                  ),
                  child: Text(
                    '${provider.currentTeam}チーム',
                    style: TextStyle(
                      color: provider.currentTeam == 'A' ? AppTheme.primaryRed : Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (currentMatch != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: opponentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'vs ${currentMatch.opponent}',
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '総記録: ${provider.getServeRecordsByMatch(currentMatch.id).length}本',
                  style: const TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoMatchSelected() {
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

  Widget _buildServeGrid(AppProvider provider, dynamic currentMatch, List players) {
    if (players.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, color: AppTheme.grey.withValues(alpha: 0.4), size: 64),
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

    final matchId = currentMatch.id;
    final opponentColor = Color(currentMatch.opponentColorValue);
    final records = provider.getServeRecordsByMatch(matchId);

    // 列ヘッダー
    final headers = ServeResult.values;

    return Column(
      children: [
        // グリッドヘッダー行
        Container(
          color: AppTheme.cardBg,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              // 選手名列ヘッダー
              SizedBox(
                width: 80,
                child: Text(
                  '選手',
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              ...headers.map((h) => Expanded(
                    child: _headerCell(h),
                  )),
              const SizedBox(width: 36), // 取り消しボタン用スペース
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.cardBg2),
        // 選手行
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
                  context, provider, player, matchId, playerRecords, opponentColor);
            },
          ),
        ),
        // 合計行
        _buildTotalRow(records, opponentColor),
      ],
    );
  }

  Widget _headerCell(ServeResult result) {
    Color color;
    switch (result) {
      case ServeResult.ace:
        color = AppTheme.aceColor;
      case ServeResult.under:
        color = AppTheme.underColor;
      case ServeResult.justIn:
        color = AppTheme.justInColor;
      case ServeResult.miss:
        color = AppTheme.missColor;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 2),
          Text(
            result.shortLabel,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(
    BuildContext context,
    AppProvider provider,
    dynamic player,
    String matchId,
    List<ServeRecord> playerRecords,
    Color opponentColor,
  ) {
    Map<ServeResult, int> counts = {};
    for (final r in ServeResult.values) {
      counts[r] = playerRecords.where((rec) => rec.result == r).length;
    }
    final total = playerRecords.length;

    return Container(
      color: _lastUndoPlayerId == player.id
          ? AppTheme.primaryRed.withValues(alpha: 0.05)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            // 選手名
            SizedBox(
              width: 80,
              child: Column(
                children: [
                  Text(
                    player.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (total > 0)
                    Text(
                      '$total本',
                      style: const TextStyle(color: AppTheme.grey, fontSize: 10),
                    ),
                ],
              ),
            ),
            // 各結果ボタン
            ...ServeResult.values.map((result) {
              final count = counts[result] ?? 0;
              return Expanded(
                child: _countButton(
                  count: count,
                  result: result,
                  onTap: () async {
                    await provider.addServeRecord(
                      matchId: matchId,
                      playerId: player.id,
                      result: result,
                    );
                  },
                ),
              );
            }),
            // 取り消しボタン
            SizedBox(
              width: 36,
              child: GestureDetector(
                onTap: total > 0
                    ? () async {
                        setState(() => _lastUndoPlayerId = player.id);
                        await provider.undoLastServeRecord(matchId, player.id);
                        Future.delayed(const Duration(milliseconds: 500),
                            () => setState(() => _lastUndoPlayerId = null));
                      }
                    : null,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  height: 48,
                  decoration: BoxDecoration(
                    color: total > 0
                        ? AppTheme.cardBg2
                        : AppTheme.cardBg2.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: total > 0
                          ? const Color(0xFF555555)
                          : const Color(0xFF333333),
                    ),
                  ),
                  child: Icon(
                    Icons.undo,
                    color: total > 0 ? AppTheme.lightGrey : AppTheme.grey.withValues(alpha: 0.3),
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countButton({
    required int count,
    required ServeResult result,
    required VoidCallback onTap,
  }) {
    Color bgColor;
    Color borderColor;
    switch (result) {
      case ServeResult.ace:
        bgColor = count > 0
            ? AppTheme.aceColor.withValues(alpha: 0.2)
            : AppTheme.cardBg2;
        borderColor = count > 0 ? AppTheme.aceColor : const Color(0xFF444444);
      case ServeResult.under:
        bgColor = count > 0
            ? AppTheme.underColor.withValues(alpha: 0.15)
            : AppTheme.cardBg2;
        borderColor = count > 0 ? AppTheme.underColor : const Color(0xFF444444);
      case ServeResult.justIn:
        bgColor = count > 0
            ? AppTheme.justInColor.withValues(alpha: 0.15)
            : AppTheme.cardBg2;
        borderColor = count > 0 ? AppTheme.justInColor : const Color(0xFF444444);
      case ServeResult.miss:
        bgColor = count > 0
            ? AppTheme.missColor.withValues(alpha: 0.2)
            : AppTheme.cardBg2;
        borderColor = count > 0 ? AppTheme.missColor : const Color(0xFF444444);
    }

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
              ? [BoxShadow(color: borderColor.withValues(alpha: 0.3), blurRadius: 4)]
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

  Widget _buildTotalRow(List<ServeRecord> records, Color opponentColor) {
    Map<ServeResult, int> totals = {};
    for (final r in ServeResult.values) {
      totals[r] = records.where((rec) => rec.result == r).length;
    }
    final grandTotal = records.length;

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
                        color: AppTheme.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                Text('$grandTotal本',
                    style: const TextStyle(color: AppTheme.grey, fontSize: 10)),
              ],
            ),
          ),
          ...ServeResult.values.map((r) {
            final count = totals[r] ?? 0;
            final pct = grandTotal > 0 ? (count / grandTotal * 100).toStringAsFixed(0) : '0';
            Color color;
            switch (r) {
              case ServeResult.ace: color = AppTheme.aceColor;
              case ServeResult.under: color = AppTheme.underColor;
              case ServeResult.justIn: color = AppTheme.justInColor;
              case ServeResult.miss: color = AppTheme.missColor;
            }
            return Expanded(
              child: Column(
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$pct%',
                    style: const TextStyle(color: AppTheme.grey, fontSize: 10),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}
