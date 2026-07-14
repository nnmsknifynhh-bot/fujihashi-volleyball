import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/serve_record.dart';
import '../models/player.dart';
import '../utils/app_theme.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen>
    with SingleTickerProviderStateMixin {
  // 選択中の選手ID
  String? _selectedPlayerId;

  // フリック検出用
  Offset? _flickStart;
  ReceiveResult? _previewResult; // フリック中にプレビュー表示する結果

  // フラッシュアニメーション
  late AnimationController _flashCtrl;
  late Animation<double> _flashAnim;
  ReceiveResult? _flashResult;

  // 修正パネル表示フラグ
  bool _showEditPanel = false;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flashAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    super.dispose();
  }

  // フリック方向 → ReceiveResult
  ReceiveResult? _detectFlick(Offset delta) {
    const threshold = 20.0;
    if (delta.distance < threshold) return null;
    final angle = delta.direction; // ラジアン (-π ～ π)
    // 上: -π/2, 下: π/2, 右: 0, 左: ±π
    if (angle > -3 * 3.14159 / 4 && angle < -3.14159 / 4) {
      return ReceiveResult.over; // 上フリック
    } else if (angle > 3.14159 / 4 && angle < 3 * 3.14159 / 4) {
      return ReceiveResult.miss; // 下フリック
    } else if (angle > -3.14159 / 4 && angle < 3.14159 / 4) {
      return ReceiveResult.direct; // 右フリック（二段・ダイレクト）
    } else {
      return ReceiveResult.under; // 左フリック（アンダー）
    }
  }

  void _triggerFlash(ReceiveResult result) {
    setState(() {
      _flashResult = result;
    });
    _flashCtrl.forward(from: 0);
  }

  Color _resultColor(ReceiveResult r) {
    switch (r) {
      case ReceiveResult.over:
        return AppTheme.overColor;
      case ReceiveResult.under:
        return AppTheme.receiveUnderColor;
      case ReceiveResult.direct:
        return AppTheme.directColor;
      case ReceiveResult.miss:
        return AppTheme.receiveMissColor;
    }
  }

  String _resultLabel(ReceiveResult r) {
    switch (r) {
      case ReceiveResult.over:
        return 'オーバー';
      case ReceiveResult.under:
        return 'アンダー';
      case ReceiveResult.direct:
        return '二段・ダイレクト';
      case ReceiveResult.miss:
        return 'ミス';
    }
  }

  IconData _resultIcon(ReceiveResult r) {
    switch (r) {
      case ReceiveResult.over:
        return Icons.arrow_upward;
      case ReceiveResult.under:
        return Icons.arrow_downward;
      case ReceiveResult.direct:
        return Icons.arrow_forward;
      case ReceiveResult.miss:
        return Icons.close;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final currentMatch = provider.currentMatch;
        final players = provider.currentTeamPlayers;

        // 選手リストが変わったとき、選択中IDが無効なら先頭に戻す
        if (players.isNotEmpty &&
            !players.any((p) => p.id == _selectedPlayerId)) {
          _selectedPlayerId = players.first.id;
        }

        return Scaffold(
          backgroundColor: AppTheme.black,
          body: Column(
            children: [
              _buildHeader(provider, currentMatch),
              if (currentMatch == null)
                Expanded(child: _buildNoMatchSelected())
              else if (players.isEmpty)
                Expanded(child: _buildNoPlayers())
              else
                Expanded(
                  child: _buildBody(provider, currentMatch, players),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── ヘッダー ─────────────────────────────────────────────────────
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
        border: Border(bottom: BorderSide(color: opponentColor, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  child: Text(
                    '${provider.currentTeam}チーム',
                    style: TextStyle(
                      color: provider.currentTeam == 'A'
                          ? AppTheme.primaryRed
                          : Colors.blue,
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

  // ─── メインボディ ─────────────────────────────────────────────────
  Widget _buildBody(
      AppProvider provider, dynamic currentMatch, List<Player> players) {
    final matchId = currentMatch.id;
    final records = provider.getReceiveRecordsByMatch(matchId);
    final selectedPlayer = players.firstWhere(
      (p) => p.id == _selectedPlayerId,
      orElse: () => players.first,
    );
    final playerRecords =
        records.where((r) => r.playerId == selectedPlayer.id).toList();

    // 結果別カウント
    final counts = <ReceiveResult, int>{};
    for (final r in ReceiveResult.values) {
      counts[r] = playerRecords.where((rec) => rec.result == r).length;
    }
    final total = playerRecords.length;

    return Column(
      children: [
        // 選手セレクタ
        _buildPlayerSelector(players, records),
        const SizedBox(height: 4),
        // フリック入力パッド（メイン）
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildFlickPad(
                provider, matchId, selectedPlayer, counts, total),
          ),
        ),
        // 集計バー
        _buildSummaryBar(counts, total),
        // 修正パネル（トグル）
        _buildEditSection(
            provider, matchId, selectedPlayer, playerRecords, counts),
      ],
    );
  }

  // ─── 選手セレクタ ─────────────────────────────────────────────────
  Widget _buildPlayerSelector(List<Player> players, List<ReceiveRecord> allRecords) {
    return Container(
      height: 60,
      color: AppTheme.cardBg,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: players.length,
        itemBuilder: (context, i) {
          final player = players[i];
          final isSelected = player.id == _selectedPlayerId;
          final playerTotal =
              allRecords.where((r) => r.playerId == player.id).length;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPlayerId = player.id;
                _showEditPanel = false;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withValues(alpha: 0.25)
                    : AppTheme.cardBg2,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? Colors.blue
                      : const Color(0xFF444444),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (player.number.isNotEmpty) ...[
                    Text(
                      '#${player.number}',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.lightBlueAccent
                            : AppTheme.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    player.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.lightGrey,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (playerTotal > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue.withValues(alpha: 0.4)
                            : AppTheme.cardBg2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$playerTotal',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.lightBlueAccent
                              : AppTheme.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── フリック入力パッド ────────────────────────────────────────────
  Widget _buildFlickPad(
    AppProvider provider,
    String matchId,
    Player player,
    Map<ReceiveResult, int> counts,
    int total,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;

        return Stack(
          alignment: Alignment.center,
          children: [
            // 背景：フリック方向ゾーン（四象限）
            _buildFlickZones(size),

            // フリック検出レイヤー
            GestureDetector(
              onPanStart: (d) {
                setState(() {
                  _flickStart = d.localPosition;
                  _previewResult = null;
                });
              },
              onPanUpdate: (d) {
                if (_flickStart != null) {
                  final delta = d.localPosition - _flickStart!;
                  final detected = _detectFlick(delta);
                  if (detected != _previewResult) {
                    setState(() {
                      _previewResult = detected;
                    });
                  }
                }
              },
              onPanEnd: (d) async {
                final result = _previewResult;
                setState(() {
                  _flickStart = null;
                  _previewResult = null;
                });
                if (result != null) {
                  _triggerFlash(result);
                  await provider.addReceiveRecord(
                    matchId: matchId,
                    playerId: player.id,
                    result: result,
                  );
                }
              },
              onPanCancel: () {
                setState(() {
                  _flickStart = null;
                  _previewResult = null;
                });
              },
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
            ),

            // 上ラベル（オーバー）
            Positioned(
              top: 12,
              child: _flickLabel(
                ReceiveResult.over,
                counts[ReceiveResult.over] ?? 0,
                isActive: _previewResult == ReceiveResult.over,
              ),
            ),

            // 左ラベル（アンダー）
            Positioned(
              left: 12,
              child: _flickLabel(
                ReceiveResult.under,
                counts[ReceiveResult.under] ?? 0,
                isActive: _previewResult == ReceiveResult.under,
              ),
            ),

            // 右ラベル（二段・ダイレクト）
            Positioned(
              right: 12,
              child: _flickLabel(
                ReceiveResult.direct,
                counts[ReceiveResult.direct] ?? 0,
                isActive: _previewResult == ReceiveResult.direct,
              ),
            ),

            // 下ラベル（ミス）
            Positioned(
              bottom: 12,
              child: _flickLabel(
                ReceiveResult.miss,
                counts[ReceiveResult.miss] ?? 0,
                isActive: _previewResult == ReceiveResult.miss,
              ),
            ),

            // 中央の選手名サークル
            _buildCenterCircle(player, total),

            // フラッシュオーバーレイ
            if (_flashResult != null)
              AnimatedBuilder(
                animation: _flashAnim,
                builder: (context, _) {
                  final opacity = (1 - _flashAnim.value).clamp(0.0, 1.0);
                  return IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _resultColor(_flashResult!)
                            .withValues(alpha: opacity * 0.35),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Opacity(
                          opacity: opacity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _resultIcon(_flashResult!),
                                color: _resultColor(_flashResult!),
                                size: 64,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _resultLabel(_flashResult!),
                                style: TextStyle(
                                  color: _resultColor(_flashResult!),
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // フリック四象限の背景ゾーン
  Widget _buildFlickZones(Size size) {
    final w = size.width;
    final h = size.height;
    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: _FlickZonePainter(
          previewResult: _previewResult,
          overColor: AppTheme.overColor,
          underColor: AppTheme.receiveUnderColor,
          directColor: AppTheme.directColor,
          missColor: AppTheme.receiveMissColor,
        ),
      ),
    );
  }

  // フリック方向ラベル
  Widget _flickLabel(ReceiveResult result, int count,
      {bool isActive = false}) {
    final color = _resultColor(result);
    final label = _resultLabel(result);
    final icon = _resultIcon(result);

    return AnimatedScale(
      scale: isActive ? 1.2 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.35)
              : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? color
                : color.withValues(alpha: 0.4),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: isActive ? 22 : 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
            if (count > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '$count本',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 中央の選手名サークル
  Widget _buildCenterCircle(Player player, int total) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: _previewResult != null ? 90 : 100,
      height: _previewResult != null ? 90 : 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.cardBg2,
        border: Border.all(
          color: _previewResult != null
              ? _resultColor(_previewResult!)
              : Colors.blue.withValues(alpha: 0.6),
          width: _previewResult != null ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_previewResult != null
                    ? _resultColor(_previewResult!)
                    : Colors.blue)
                .withValues(alpha: _previewResult != null ? 0.6 : 0.25),
            blurRadius: _previewResult != null ? 20 : 10,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (player.number.isNotEmpty)
            Text(
              '#${player.number}',
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          Text(
            player.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (total > 0)
            Text(
              '$total本',
              style: const TextStyle(
                color: Colors.lightBlueAccent,
                fontSize: 11,
              ),
            ),
          if (_previewResult != null)
            Text(
              '↑ フリック中',
              style: TextStyle(
                color: _resultColor(_previewResult!),
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }

  // ─── 集計バー ────────────────────────────────────────────────────
  Widget _buildSummaryBar(Map<ReceiveResult, int> counts, int total) {
    return Container(
      color: AppTheme.cardBg,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          const Text('合計:',
              style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text('$total本',
              style: const TextStyle(
                  color: AppTheme.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          ...ReceiveResult.values.map((r) {
            final count = counts[r] ?? 0;
            final pct = total > 0
                ? '${(count / total * 100).toStringAsFixed(0)}%'
                : '-';
            final color = _resultColor(r);
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: count > 0
                      ? color.withValues(alpha: 0.15)
                      : AppTheme.cardBg2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: count > 0
                        ? color.withValues(alpha: 0.6)
                        : const Color(0xFF333333),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(_resultIcon(r), color: color, size: 12),
                    Text(
                      '$count',
                      style: TextStyle(
                        color: count > 0 ? color : AppTheme.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      pct,
                      style: const TextStyle(
                          color: AppTheme.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 修正セクション ───────────────────────────────────────────────
  Widget _buildEditSection(
    AppProvider provider,
    String matchId,
    Player player,
    List<ReceiveRecord> playerRecords,
    Map<ReceiveResult, int> counts,
  ) {
    final total = playerRecords.length;

    return Column(
      children: [
        // 修正パネルのトグルボタン
        GestureDetector(
          onTap: () {
            setState(() {
              _showEditPanel = !_showEditPanel;
            });
          },
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppTheme.cardBg2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _showEditPanel
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  color: total > 0
                      ? Colors.lightBlueAccent
                      : AppTheme.grey,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  total > 0 ? '修正・取り消し ($total本)' : '修正・取り消し',
                  style: TextStyle(
                    color: total > 0
                        ? Colors.lightBlueAccent
                        : AppTheme.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 修正パネル本体
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _showEditPanel
              ? _buildEditPanel(
                  provider, matchId, player, playerRecords, counts)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildEditPanel(
    AppProvider provider,
    String matchId,
    Player player,
    List<ReceiveRecord> playerRecords,
    Map<ReceiveResult, int> counts,
  ) {
    return Container(
      key: const ValueKey('editPanel'),
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF001A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${player.name} の記録を修正',
            style: const TextStyle(
              color: AppTheme.lightGrey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '▼ 1本取り消す（最新の記録が削除されます）',
            style: TextStyle(color: AppTheme.grey, fontSize: 11),
          ),
          const SizedBox(height: 8),
          // 各結果ごとの取り消しボタン
          Row(
            children: ReceiveResult.values.map((result) {
              final count = counts[result] ?? 0;
              final color = _resultColor(result);
              return Expanded(
                child: GestureDetector(
                  onTap: count > 0
                      ? () async {
                          final toDelete = playerRecords
                              .where((r) => r.result == result)
                              .toList()
                            ..sort((a, b) =>
                                b.timestamp.compareTo(a.timestamp));
                          if (toDelete.isNotEmpty) {
                            await provider
                                .deleteReceiveRecord(toDelete.first.id);
                          }
                          // カウントが0になったら閉じる
                          final newTotal = playerRecords.length - 1;
                          if (newTotal <= 0) {
                            setState(() {
                              _showEditPanel = false;
                            });
                          }
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: count > 0
                          ? color.withValues(alpha: 0.2)
                          : AppTheme.cardBg2.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: count > 0
                            ? color.withValues(alpha: 0.7)
                            : const Color(0xFF333333),
                        width: count > 0 ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          count > 0 ? '-1' : '－',
                          style: TextStyle(
                            color: count > 0 ? color : AppTheme.grey,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _resultLabel(result),
                          style: TextStyle(
                            color: count > 0 ? color : AppTheme.grey,
                            fontSize: 9,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (count > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '($count本)',
                              style:
                                  TextStyle(color: color, fontSize: 9),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFF1A3A4A)),
          const SizedBox(height: 6),
          const Text(
            '▼ 全記録を一括削除',
            style: TextStyle(color: AppTheme.grey, fontSize: 11),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: playerRecords.isEmpty
                ? null
                : () async {
                    // 確認ダイアログ
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.cardBg,
                        title: const Text(
                          '全記録を削除',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: Text(
                          '${player.name} の全レシーブ記録 (${playerRecords.length}本) を削除しますか？',
                          style: const TextStyle(
                              color: AppTheme.lightGrey),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, false),
                            child: const Text('キャンセル',
                                style:
                                    TextStyle(color: AppTheme.grey)),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, true),
                            child: const Text('削除',
                                style: TextStyle(
                                    color: AppTheme.receiveMissColor)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      for (final rec in playerRecords) {
                        await provider.deleteReceiveRecord(rec.id);
                      }
                      setState(() {
                        _showEditPanel = false;
                      });
                    }
                  },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: playerRecords.isEmpty
                    ? AppTheme.cardBg2.withValues(alpha: 0.5)
                    : AppTheme.receiveMissColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: playerRecords.isEmpty
                      ? const Color(0xFF333333)
                      : AppTheme.receiveMissColor.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_sweep,
                      color: playerRecords.isEmpty
                          ? AppTheme.grey
                          : AppTheme.receiveMissColor,
                      size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${player.name} の全記録を削除',
                    style: TextStyle(
                      color: playerRecords.isEmpty
                          ? AppTheme.grey
                          : AppTheme.receiveMissColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── エラー表示 ───────────────────────────────────────────────────
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

  Widget _buildNoPlayers() {
    return Center(
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
}

// ─── フリックゾーン背景描画 ───────────────────────────────────────────
class _FlickZonePainter extends CustomPainter {
  final ReceiveResult? previewResult;
  final Color overColor;
  final Color underColor;
  final Color directColor;
  final Color missColor;

  _FlickZonePainter({
    required this.previewResult,
    required this.overColor,
    required this.underColor,
    required this.directColor,
    required this.missColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    void drawZone(ReceiveResult result, Path path) {
      final color = _colorFor(result);
      final isActive = previewResult == result;
      final paint = Paint()
        ..color = isActive
            ? color.withValues(alpha: 0.22)
            : color.withValues(alpha: 0.06)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, paint);

      // ゾーン境界線
      final borderPaint = Paint()
        ..color = isActive
            ? color.withValues(alpha: 0.5)
            : color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 1.5 : 0.8;
      canvas.drawPath(path, borderPaint);
    }

    // 上ゾーン（オーバー）
    final topPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(cx, cy)
      ..close();
    drawZone(ReceiveResult.over, topPath);

    // 下ゾーン（ミス）
    final bottomPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(cx, cy)
      ..close();
    drawZone(ReceiveResult.miss, bottomPath);

    // 左ゾーン（アンダー）
    final leftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(cx, cy)
      ..close();
    drawZone(ReceiveResult.under, leftPath);

    // 右ゾーン（ダイレクト）
    final rightPath = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(cx, cy)
      ..close();
    drawZone(ReceiveResult.direct, rightPath);

    // 中央の十字ガイドライン
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;
    canvas.drawLine(
        Offset(cx, 0), Offset(cx, size.height), guidePaint);
    canvas.drawLine(
        Offset(0, cy), Offset(size.width, cy), guidePaint);
  }

  Color _colorFor(ReceiveResult r) {
    switch (r) {
      case ReceiveResult.over:
        return overColor;
      case ReceiveResult.under:
        return underColor;
      case ReceiveResult.direct:
        return directColor;
      case ReceiveResult.miss:
        return missColor;
    }
  }

  @override
  bool shouldRepaint(_FlickZonePainter old) =>
      old.previewResult != previewResult;
}
