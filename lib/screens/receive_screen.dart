import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/serve_record.dart';
import '../utils/app_theme.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
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
                  child: _buildReceiveGrid(provider, currentMatch, players),
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
        : Colors.blue;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF001A2A),
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
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'RECEIVE',
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
                'サーブレシーブ記録',
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
                  '総記録: ${provider.getReceiveRecordsByMatch(currentMatch.id).length}本',
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

  Widget _buildReceiveGrid(AppProvider provider, dynamic currentMatch, List players) {
    if (players.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, color: AppTheme.grey.withValues(alpha: 0.4), size: 64),
            const SizedBox(height: 16),
            const Text('選手が登録されていません',
                style: TextStyle(color: AppTheme.grey, fontSize: 16)),
          ],
        ),
      );
    }

    final matchId = currentMatch.id;
    final opponentColor = Color(currentMatch.opponentColorValue);
    final records = provider.getReceiveRecordsByMatch(matchId);

    return Column(
      children: [
        // グリッドヘッダー行
        Container(
          color: AppTheme.cardBg,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: const Text(
                  '選手',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              ...ReceiveResult.values.map((h) => Expanded(
                    child: _headerCell(h),
                  )),
              const SizedBox(width: 36),
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
        _buildTotalRow(records, opponentColor),
      ],
    );
  }

  Widget _headerCell(ReceiveResult result) {
    Color color;
    switch (result) {
      case ReceiveResult.over:
        color = AppTheme.overColor;
      case ReceiveResult.under:
        color = AppTheme.receiveUnderColor;
      case ReceiveResult.direct:
        color = AppTheme.directColor;
      case ReceiveResult.miss:
        color = AppTheme.receiveMissColor;
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
    List<ReceiveRecord> playerRecords,
    Color opponentColor,
  ) {
    Map<ReceiveResult, int> counts = {};
    for (final r in ReceiveResult.values) {
      counts[r] = playerRecords.where((rec) => rec.result == r).length;
    }
    final total = playerRecords.length;

    return Container(
      color: _lastUndoPlayerId == player.id
          ? Colors.blue.withValues(alpha: 0.05)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
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
            ...ReceiveResult.values.map((result) {
              final count = counts[result] ?? 0;
              return Expanded(
                child: _countButton(
                  count: count,
                  result: result,
                  onTap: () async {
                    await provider.addReceiveRecord(
                      matchId: matchId,
                      playerId: player.id,
                      result: result,
                    );
                  },
                ),
              );
            }),
            SizedBox(
              width: 36,
              child: GestureDetector(
                onTap: total > 0
                    ? () async {
                        setState(() => _lastUndoPlayerId = player.id);
                        await provider.undoLastReceiveRecord(matchId, player.id);
                        Future.delayed(const Duration(milliseconds: 500),
                            () => setState(() => _lastUndoPlayerId = null));
                      }
                    : null,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  height: 48,
                  decoration: BoxDecoration(
                    color: total > 0 ? AppTheme.cardBg2 : AppTheme.cardBg2.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: total > 0 ? const Color(0xFF555555) : const Color(0xFF333333),
                    ),
                  ),
                  child: Icon(
                    Icons.undo,
                    color: total > 0
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
    );
  }

  Widget _countButton({
    required int count,
    required ReceiveResult result,
    required VoidCallback onTap,
  }) {
    Color bgColor;
    Color borderColor;
    switch (result) {
      case ReceiveResult.over:
        bgColor = count > 0 ? AppTheme.overColor.withValues(alpha: 0.2) : AppTheme.cardBg2;
        borderColor = count > 0 ? AppTheme.overColor : const Color(0xFF444444);
      case ReceiveResult.under:
        bgColor = count > 0
            ? AppTheme.receiveUnderColor.withValues(alpha: 0.15)
            : AppTheme.cardBg2;
        borderColor = count > 0 ? AppTheme.receiveUnderColor : const Color(0xFF444444);
      case ReceiveResult.direct:
        bgColor = count > 0
            ? AppTheme.directColor.withValues(alpha: 0.15)
            : AppTheme.cardBg2;
        borderColor = count > 0 ? AppTheme.directColor : const Color(0xFF444444);
      case ReceiveResult.miss:
        bgColor = count > 0
            ? AppTheme.receiveMissColor.withValues(alpha: 0.2)
            : AppTheme.cardBg2;
        borderColor = count > 0 ? AppTheme.receiveMissColor : const Color(0xFF444444);
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

  Widget _buildTotalRow(List<ReceiveRecord> records, Color opponentColor) {
    Map<ReceiveResult, int> totals = {};
    for (final r in ReceiveResult.values) {
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
          ...ReceiveResult.values.map((r) {
            final count = totals[r] ?? 0;
            final pct = grandTotal > 0 ? (count / grandTotal * 100).toStringAsFixed(0) : '0';
            Color color;
            switch (r) {
              case ReceiveResult.over: color = AppTheme.overColor;
              case ReceiveResult.under: color = AppTheme.receiveUnderColor;
              case ReceiveResult.direct: color = AppTheme.directColor;
              case ReceiveResult.miss: color = AppTheme.receiveMissColor;
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
