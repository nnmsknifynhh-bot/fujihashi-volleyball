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
// ポジション（6マス）:
//   pos 0: 前衛中央
//   pos 1: 中衛左   pos 2: 中衛中央   pos 3: 中衛右
//   pos 4: 後衛左                     pos 5: 後衛右
//
// 各ポジションはAチームの選手から自由に割り当て可能。
// ─────────────────────────────────────────────────────────────────────────────

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen>
    with TickerProviderStateMixin {

  // ポジション割り当て（index 0〜5 → Player?）
  // null = 未割り当て（空きスロット）
  final List<Player?> _posPlayers = List.filled(6, null);

  // ポジション名ラベル
  static const _posLabels = [
    '前衛中', '中衛左', '中衛中', '中衛右', '後衛左', '後衛右',
  ];

  // フリック状態（ポジションindexごと）
  final Map<int, Offset?> _flickStarts = {};
  final Map<int, ReceiveResult?> _previews = {};

  // フラッシュアニメーション（ポジションindexごと）
  final Map<int, AnimationController> _flashCtrls = {};
  final Map<int, ReceiveResult?> _flashResults = {};

  // 修正パネルを開いているポジションindex
  int? _editPosIdx;

  // 初回ロード時に自動割り当て済みか
  bool _autoAssigned = false;

  @override
  void dispose() {
    for (final c in _flashCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // AnimationController を遅延生成
  AnimationController _ctrl(int posIdx) {
    return _flashCtrls.putIfAbsent(
      posIdx,
      () => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  // Aチームの選手リストが来たとき、初回のみ自動割り当て
  void _autoAssignIfNeeded(List<Player> teamPlayers) {
    if (_autoAssigned) return;
    _autoAssigned = true;
    for (int i = 0; i < 6 && i < teamPlayers.length; i++) {
      _posPlayers[i] = teamPlayers[i];
    }
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
      case ReceiveResult.direct: return '二段\nDirect';
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

  ReceiveResult? _detect(Offset delta) {
    const t = 18.0;
    if (delta.distance < t) return null;
    final a = delta.direction;
    if (a > -3 * 3.14159 / 4 && a < -3.14159 / 4) return ReceiveResult.over;
    if (a >  3.14159 / 4 && a <  3 * 3.14159 / 4) return ReceiveResult.miss;
    if (a > -3.14159 / 4 && a <  3.14159 / 4)     return ReceiveResult.direct;
    return ReceiveResult.under;
  }

  void _triggerFlash(int posIdx, ReceiveResult r) {
    setState(() => _flashResults[posIdx] = r);
    _ctrl(posIdx).forward(from: 0);
  }

  // ─── build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final match = provider.currentMatch;
        final teamPlayers = provider.currentTeamPlayers;

        // 初回のみ自動割り当て
        _autoAssignIfNeeded(teamPlayers);

        return Scaffold(
          backgroundColor: AppTheme.black,
          body: Column(
            children: [
              _buildHeader(provider, match),
              if (match == null)
                const Expanded(child: _NoMatch())
              else if (teamPlayers.isEmpty)
                const Expanded(child: _NoPlayers())
              else
                Expanded(
                  child: _buildCourt(context, provider, match, teamPlayers),
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
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
              const SizedBox(width: 8),
              const Text('サーブレシーブ記録',
                  style: TextStyle(color: Colors.white, fontSize: 18,
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
            const SizedBox(height: 4),
            Row(children: [
              Container(width: 7, height: 7,
                  decoration: BoxDecoration(color: oc, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('vs ${match.opponent}',
                  style: const TextStyle(color: AppTheme.gold, fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Consumer<AppProvider>(
                builder: (_, p, __) => Text(
                  '総記録: ${p.getReceiveRecordsByMatch(match.id).length}本',
                  style: const TextStyle(color: AppTheme.grey, fontSize: 12)),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  // ─── コート全体 ───────────────────────────────────────────────────
  Widget _buildCourt(BuildContext context, AppProvider provider,
      dynamic match, List<Player> teamPlayers) {
    final matchId = match.id;
    final records = provider.getReceiveRecordsByMatch(matchId);

    return Column(
      children: [
        // ネットライン
        _netBar(),

        // コートエリア
        Expanded(
          child: Container(
            color: const Color(0xFF0D1A0D),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Column(
              children: [
                // 前衛行：中央1人（小さめ表示）
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      const Expanded(flex: 3, child: SizedBox()),
                      Expanded(
                        flex: 4,
                        child: _posCell(context, provider, matchId,
                            posIdx: 0, teamPlayers: teamPlayers, records: records),
                      ),
                      const Expanded(flex: 3, child: SizedBox()),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // 中衛行：3人
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Expanded(child: _posCell(context, provider, matchId,
                          posIdx: 1, teamPlayers: teamPlayers, records: records)),
                      const SizedBox(width: 6),
                      Expanded(child: _posCell(context, provider, matchId,
                          posIdx: 2, teamPlayers: teamPlayers, records: records)),
                      const SizedBox(width: 6),
                      Expanded(child: _posCell(context, provider, matchId,
                          posIdx: 3, teamPlayers: teamPlayers, records: records)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // 後衛行：左右2人（中央空白）
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Expanded(child: _posCell(context, provider, matchId,
                          posIdx: 4, teamPlayers: teamPlayers, records: records)),
                      const SizedBox(width: 6),
                      const Expanded(child: SizedBox()),
                      const SizedBox(width: 6),
                      Expanded(child: _posCell(context, provider, matchId,
                          posIdx: 5, teamPlayers: teamPlayers, records: records)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                _buildLegendBar(records),
              ],
            ),
          ),
        ),

        // 修正パネル
        _buildEditSection(context, provider, matchId, teamPlayers, records),
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
        border: Border(bottom: BorderSide(color: Color(0xFF4488FF), width: 2)),
      ),
      child: const Center(
        child: Text('━━━━━  N E T  ━━━━━',
            style: TextStyle(color: Color(0xFF6699FF), fontSize: 11,
                fontWeight: FontWeight.bold, letterSpacing: 3)),
      ),
    );
  }

  // ─── 1ポジション分のセル ──────────────────────────────────────────
  Widget _posCell(
    BuildContext context,
    AppProvider provider,
    String matchId, {
    required int posIdx,
    required List<Player> teamPlayers,
    required List<ReceiveRecord> records,
  }) {
    final player = _posPlayers[posIdx];

    // 選手未割り当て → 「選手を選択」ボタン
    if (player == null) {
      return _emptyCell(context, posIdx, teamPlayers);
    }

    final playerRecords = records.where((r) => r.playerId == player.id).toList();
    final counts = <ReceiveResult, int>{
      for (final r in ReceiveResult.values)
        r: playerRecords.where((rec) => rec.result == r).length,
    };
    final total = playerRecords.length;
    final preview = _previews[posIdx];
    final flashResult = _flashResults[posIdx];
    final ctrl = _ctrl(posIdx);

    return GestureDetector(
      onPanStart: (d) {
        setState(() {
          _flickStarts[posIdx] = d.localPosition;
          _previews[posIdx] = null;
          _editPosIdx = null;
        });
      },
      onPanUpdate: (d) {
        final start = _flickStarts[posIdx];
        if (start == null) return;
        final detected = _detect(d.localPosition - start);
        if (detected != _previews[posIdx]) {
          setState(() => _previews[posIdx] = detected);
        }
      },
      onPanEnd: (d) async {
        final result = _previews[posIdx];
        setState(() {
          _flickStarts.remove(posIdx);
          _previews[posIdx] = null;
        });
        if (result != null) {
          _triggerFlash(posIdx, result);
          await provider.addReceiveRecord(
            matchId: matchId,
            playerId: player.id,
            result: result,
          );
        }
      },
      onPanCancel: () {
        setState(() {
          _flickStarts.remove(posIdx);
          _previews[posIdx] = null;
        });
      },
      // 長押しで修正パネルを開く
      onLongPress: () {
        setState(() {
          _editPosIdx = _editPosIdx == posIdx ? null : posIdx;
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
              child!,
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
                              Text(_label(flashResult),
                                  style: TextStyle(
                                      color: _color(flashResult),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center),
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
        child: _cellBody(posIdx, player, counts, total, preview),
      ),
    );
  }

  // 未割り当てセル（選手選択ボタン）
  Widget _emptyCell(BuildContext context, int posIdx, List<Player> teamPlayers) {
    return GestureDetector(
      onTap: () => _showPlayerPicker(context, posIdx, teamPlayers),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A120A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF2A4A2A),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add,
                color: AppTheme.grey.withValues(alpha: 0.5), size: 20),
            const SizedBox(height: 4),
            Text(_posLabels[posIdx],
                style: TextStyle(
                    color: AppTheme.grey.withValues(alpha: 0.5), fontSize: 9)),
            const SizedBox(height: 2),
            Text('タップして選択',
                style: TextStyle(
                    color: AppTheme.grey.withValues(alpha: 0.4), fontSize: 8)),
          ],
        ),
      ),
    );
  }

  // セル本体（選手割り当て済み）
  Widget _cellBody(
    int posIdx,
    Player player,
    Map<ReceiveResult, int> counts,
    int total,
    ReceiveResult? preview,
  ) {
    final isEditOpen = _editPosIdx == posIdx;
    final borderColor = preview != null
        ? _color(preview)
        : isEditOpen
            ? Colors.lightBlueAccent
            : const Color(0xFF2A4A2A);

    final bgColor = preview != null
        ? _color(preview).withValues(alpha: 0.18)
        : isEditOpen
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
                blurRadius: 12)]
            : null,
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _flickHintTop(counts[ReceiveResult.over] ?? 0,
                  preview == ReceiveResult.over),
              Row(
                children: [
                  _flickHintSide(counts[ReceiveResult.under] ?? 0,
                      preview == ReceiveResult.under,
                      ReceiveResult.under, isLeft: true),
                  Expanded(child: _playerNameArea(player, total, preview)),
                  _flickHintSide(counts[ReceiveResult.direct] ?? 0,
                      preview == ReceiveResult.direct,
                      ReceiveResult.direct, isLeft: false),
                ],
              ),
              _flickHintBottom(counts[ReceiveResult.miss] ?? 0,
                  preview == ReceiveResult.miss),
            ],
          ),
          // 長押しヒントアイコン（右上）
          if (preview == null)
            Positioned(
              top: 3,
              right: 3,
              child: Icon(Icons.more_vert,
                  color: AppTheme.grey.withValues(alpha: 0.35), size: 12),
            ),
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
        color: active ? _color(r).withValues(alpha: 0.3) : Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.arrow_upward,
            color: active ? _color(r) : _color(r).withValues(alpha: 0.4),
            size: active ? 14 : 11),
        Text(count > 0 ? '$count' : 'オーバー',
            style: TextStyle(
              color: active ? _color(r) : _color(r).withValues(alpha: 0.5),
              fontSize: count > 0 ? 15 : 9,
              fontWeight: FontWeight.bold,
            )),
      ]),
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
        color: active ? _color(r).withValues(alpha: 0.3) : Colors.transparent,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(count > 0 ? '$count' : 'ミス',
            style: TextStyle(
              color: active ? _color(r) : _color(r).withValues(alpha: 0.5),
              fontSize: count > 0 ? 15 : 9,
              fontWeight: FontWeight.bold,
            )),
        Icon(Icons.arrow_downward,
            color: active ? _color(r) : _color(r).withValues(alpha: 0.4),
            size: active ? 14 : 11),
      ]),
    );
  }

  // 左右フリックヒント
  Widget _flickHintSide(int count, bool active, ReceiveResult r,
      {required bool isLeft}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 26,
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
          Icon(isLeft ? Icons.arrow_back : Icons.arrow_forward,
              color: active ? _color(r) : _color(r).withValues(alpha: 0.4),
              size: active ? 12 : 10),
          if (count > 0)
            Text('$count',
                style: TextStyle(
                    color: active ? _color(r) : _color(r).withValues(alpha: 0.7),
                    fontSize: 14, fontWeight: FontWeight.bold))
          else
            Text(isLeft ? 'ア\nン\nダ' : '二\n段',
                style: TextStyle(
                    color: active ? _color(r) : _color(r).withValues(alpha: 0.4),
                    fontSize: 7),
                textAlign: TextAlign.center),
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
          Text('#${player.number}',
              style: const TextStyle(
                  color: AppTheme.gold, fontSize: 9, fontWeight: FontWeight.bold)),
        Text(player.name,
            style: TextStyle(
                color: preview != null ? Colors.white : const Color(0xFFDDFFDD),
                fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis),
        if (total > 0)
          Text('$total本',
              style: TextStyle(
                  color: preview != null
                      ? _color(preview).withValues(alpha: 0.9)
                      : Colors.lightBlueAccent.withValues(alpha: 0.8),
                  fontSize: 11, fontWeight: FontWeight.bold)),
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
                  color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          ...ReceiveResult.values.map((r) {
            final c = counts[r] ?? 0;
            final pct = total > 0
                ? '${(c / total * 100).toStringAsFixed(0)}%' : '-';
            return Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_icon(r), color: _color(r), size: 10),
                  const SizedBox(width: 2),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$c',
                        style: TextStyle(color: _color(r), fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    Text(pct,
                        style: const TextStyle(color: AppTheme.grey, fontSize: 9)),
                  ]),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 選手選択ピッカー（BottomSheet・スクロール対応）──────────────
  void _showPlayerPicker(
      BuildContext context, int posIdx, List<Player> teamPlayers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      // 画面の最大90%まで高さを使えるようにする（スクロール必須）
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        // 画面高さの最大90%に制限
        final maxHeight = MediaQuery.of(ctx).size.height * 0.9;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── ヘッダー（固定） ──────────────────────────────
                // ハンドル
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.sports_volleyball,
                          color: AppTheme.gold, size: 18),
                      const SizedBox(width: 8),
                      Text('${_posLabels[posIdx]} の選手を選択',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF333333), height: 1),

                // ── スクロール可能なリスト ────────────────────────
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // 空き（未割り当て）
                      ListTile(
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg2,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.grey),
                          ),
                          child: const Icon(Icons.person_off,
                              color: AppTheme.grey, size: 18),
                        ),
                        title: const Text('空き（未割り当て）',
                            style: TextStyle(color: AppTheme.grey, fontSize: 14)),
                        onTap: () {
                          setState(() => _posPlayers[posIdx] = null);
                          Navigator.pop(ctx);
                        },
                      ),
                      const Divider(color: Color(0xFF222222), height: 1),

                      // Aチームの選手一覧
                      ...teamPlayers.map((player) {
                        final isCurrentlyAssigned =
                            _posPlayers[posIdx]?.id == player.id;
                        final usedAtPos = _posPlayers.indexWhere(
                            (p) => p?.id == player.id);
                        final isUsedElsewhere =
                            usedAtPos != -1 && usedAtPos != posIdx;

                        return ListTile(
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: isCurrentlyAssigned
                                  ? AppTheme.gold.withValues(alpha: 0.2)
                                  : isUsedElsewhere
                                      ? AppTheme.primaryRed.withValues(alpha: 0.1)
                                      : AppTheme.primaryRed.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isCurrentlyAssigned
                                    ? AppTheme.gold
                                    : isUsedElsewhere
                                        ? AppTheme.grey
                                        : AppTheme.primaryRed,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                player.number.isNotEmpty
                                    ? '#${player.number}' : '?',
                                style: TextStyle(
                                  color: isCurrentlyAssigned
                                      ? AppTheme.gold
                                      : isUsedElsewhere
                                          ? AppTheme.grey
                                          : AppTheme.primaryRed,
                                  fontSize: 11, fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          title: Text(player.name,
                              style: TextStyle(
                                color: isUsedElsewhere
                                    ? AppTheme.grey : Colors.white,
                                fontSize: 15, fontWeight: FontWeight.bold,
                              )),
                          subtitle: isUsedElsewhere
                              ? Text(
                                  '${_posLabels[usedAtPos]} に配置中',
                                  style: const TextStyle(
                                      color: AppTheme.grey, fontSize: 11))
                              : null,
                          trailing: isCurrentlyAssigned
                              ? const Icon(Icons.check_circle,
                                  color: AppTheme.gold, size: 20)
                              : null,
                          onTap: () {
                            setState(() {
                              if (isUsedElsewhere) {
                                final currentPlayer = _posPlayers[posIdx];
                                _posPlayers[usedAtPos] = currentPlayer;
                              }
                              _posPlayers[posIdx] = player;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 修正パネル（長押しで展開）──────────────────────────────────
  Widget _buildEditSection(BuildContext context, AppProvider provider,
      String matchId, List<Player> teamPlayers, List<ReceiveRecord> allRecords) {
    if (_editPosIdx == null) return const SizedBox.shrink();

    final posIdx = _editPosIdx!;
    final player = _posPlayers[posIdx];
    if (player == null) return const SizedBox.shrink();

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
          // ヘッダー
          Row(
            children: [
              Text('${player.name} （${_posLabels[posIdx]}）',
                  style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              // 選手変更ボタン
              GestureDetector(
                onTap: () {
                  setState(() => _editPosIdx = null);
                  _showPlayerPicker(context, posIdx, teamPlayers);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz, color: AppTheme.gold, size: 13),
                      SizedBox(width: 4),
                      Text('選手変更',
                          style: TextStyle(
                              color: AppTheme.gold, fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _editPosIdx = null),
                child: const Icon(Icons.close, color: AppTheme.grey, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('▼ 1本取り消す（最新の記録を削除）',
              style: TextStyle(color: AppTheme.grey, fontSize: 10)),
          const SizedBox(height: 6),
          // 結果別取り消しボタン
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
                            await provider.deleteReceiveRecord(
                                toDelete.first.id);
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
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(count > 0 ? '-1' : '－',
                          style: TextStyle(
                              color: count > 0 ? _color(r) : AppTheme.grey,
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(_shortLabel(r),
                          style: TextStyle(
                              color: count > 0 ? _color(r) : AppTheme.grey,
                              fontSize: 8),
                          textAlign: TextAlign.center),
                      if (count > 0)
                        Text('($count)',
                            style: TextStyle(color: _color(r), fontSize: 9)),
                    ]),
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
                  setState(() => _editPosIdx = null);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.receiveMissColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.receiveMissColor.withValues(alpha: 0.4)),
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
                            fontSize: 12, fontWeight: FontWeight.bold)),
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
