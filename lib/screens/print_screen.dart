import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';

import 'package:web/web.dart' as web;
import '../providers/app_provider.dart';
import '../models/player.dart';
import '../models/serve_record.dart';
import '../utils/app_theme.dart';

/// stats画面で選択中のチーム・選手・期間をそのままPDFに反映するため、
/// teamFilter と selectedPlayerIds と dateRange を受け取る
class PrintScreen extends StatefulWidget {
  /// 'A', 'B', 'all' のいずれか
  final String teamFilter;

  /// null = チーム全員, 非null = 個別選択中の選手IDセット
  final Set<String>? selectedPlayerIds;

  /// null = 全期間, 非null = 指定期間（start〜end）
  final DateTimeRange? dateRange;

  const PrintScreen({
    super.key,
    this.teamFilter = 'all',
    this.selectedPlayerIds,
    this.dateRange,
  });

  @override
  State<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends State<PrintScreen> {
  // ─── チェックボックス（削除3件・修正2件後の最終構成）──────────────
  bool _inclPlayerStats = true;      // 選手別成績（サーブ+レシーブ+AI講評）
  bool _inclServeRanking = true;     // サーブランキング
  bool _inclReceiveRanking = true;   // サーブレシーブランキング
  bool _inclPercentage = true;       // 割合（%）表示
  bool _inclOpponentAnalysis = true; // 対戦相手別分析

  // 対戦相手別分析の選択状態（複数選択対応・空=全対戦相手）
  Set<String> _selectedOpponents = {};

  bool _isGenerating = false;
  String _statusMessage = '';

  // フォントをフィールドに保持（全pw.TextStyleで明示的に使用）
  pw.Font? _regularFont;
  pw.Font? _boldFont;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    // 対戦相手一覧（試合から抽出・重複除去・ソート済み）
    final opponents = provider.matches
        .map((m) => m.opponent)
        .toSet()
        .toList()
      ..sort();

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.print, color: AppTheme.gold, size: 20),
            SizedBox(width: 8),
            Text('印刷・PDF出力',
                style: TextStyle(color: AppTheme.gold, fontSize: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('出力内容を選択', Icons.checklist),
                const SizedBox(height: 12),

                // 選手別成績（サーブ+レシーブ+AI講評 統合）
                _buildCheckTile(
                  '選手別成績',
                  '選手ごとのサーブ・レシーブ統計とAI講評',
                  Icons.person,
                  _inclPlayerStats,
                  (v) => setState(() => _inclPlayerStats = v),
                ),

                // サーブランキング
                _buildCheckTile(
                  'サーブランキング',
                  'エース率・崩し率・ミス率順位',
                  Icons.military_tech,
                  _inclServeRanking,
                  (v) => setState(() => _inclServeRanking = v),
                ),

                // サーブレシーブランキング
                _buildCheckTile(
                  'サーブレシーブランキング',
                  'オーバー率・ミス率順位',
                  Icons.leaderboard,
                  _inclReceiveRanking,
                  (v) => setState(() => _inclReceiveRanking = v),
                ),

                // 割合（%）表示
                _buildCheckTile(
                  '割合（%）表示',
                  '各項目のパーセンテージ',
                  Icons.percent,
                  _inclPercentage,
                  (v) => setState(() => _inclPercentage = v),
                ),

                // 対戦相手別分析（対戦相手選択UI付き）
                _buildCheckTile(
                  '対戦相手別分析',
                  '選択した相手チームごとの成績',
                  Icons.groups,
                  _inclOpponentAnalysis,
                  (v) => setState(() {
                    _inclOpponentAnalysis = v;
                    if (!v) _selectedOpponents = {};
                  }),
                ),

                // 対戦相手選択ドロップダウン（_inclOpponentAnalysisがtrueの時のみ表示）
                if (_inclOpponentAnalysis) ...[
                  Container(
                    margin: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryRed.withValues(alpha: 0.4),
                      ),
                    ),
                    child: opponents.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              '試合データがありません。先に試合を登録してください。',
                              style: TextStyle(
                                  color: AppTheme.grey, fontSize: 12),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 8, bottom: 4),
                                child: Text(
                                  _selectedOpponents.isEmpty
                                      ? '対戦相手を選択（複数選択可・未選択=全対戦相手）'
                                      : '${_selectedOpponents.length}件選択中（タップで選択/解除）',
                                  style: const TextStyle(
                                      color: AppTheme.gold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  // 「全対戦相手」チップ
                                  _opponentChip(null, opponents),
                                  // 個別の対戦相手チップ
                                  ...opponents.map(
                                    (opp) => _opponentChip(opp, opponents),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                  ),
                ],

                const SizedBox(height: 20),
                _buildSectionHeader('出力形式', Icons.picture_as_pdf),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Column(
                    children: [
                      _infoRow(Icons.description, 'A4サイズ対応PDF'),
                      const SizedBox(height: 8),
                      _infoRow(Icons.preview, 'アプリ内プレビュー（スクロール表示）'),
                      const SizedBox(height: 8),
                      _infoRow(Icons.print, '印刷ダイアログから直接印刷可能'),
                      const SizedBox(height: 8),
                      _infoRow(Icons.language, '日本語フォント（ローカル処理）'),
                      const SizedBox(height: 8),
                      _infoRow(Icons.family_restroom, '保護者配布向けレイアウト'),
                      const SizedBox(height: 8),
                      _infoRow(Icons.download, 'PDFダウンロードも可能'),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.cardBg,
              border: Border(top: BorderSide(color: Color(0xFF333333))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isGenerating && _statusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                          color: AppTheme.gold, fontSize: 12),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isGenerating
                              ? AppTheme.primaryRed.withValues(alpha: 0.5)
                              : AppTheme.primaryRed,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.preview,
                                color: Colors.white),
                        label: Text(
                          _isGenerating ? 'PDF生成中...' : 'プレビュー・印刷',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isGenerating ? null : _openPreview,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── UI ヘルパー ───────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.gold, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: Color(0xFF333333))),
      ],
    );
  }

  Widget _buildCheckTile(String title, String subtitle, IconData icon,
      bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            value ? AppTheme.primaryRed.withValues(alpha: 0.08) : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value
              ? AppTheme.primaryRed.withValues(alpha: 0.4)
              : const Color(0xFF333333),
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        activeColor: AppTheme.primaryRed,
        checkColor: Colors.white,
        title: Text(title,
            style: TextStyle(
                color: value ? Colors.white : AppTheme.lightGrey,
                fontWeight:
                    value ? FontWeight.bold : FontWeight.normal,
                fontSize: 14)),
        subtitle: Text(subtitle,
            style:
                const TextStyle(color: AppTheme.grey, fontSize: 11)),
        secondary: Icon(icon,
            color: value ? AppTheme.primaryRed : AppTheme.grey, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// 対戦相手選択チップ（複数選択対応）
  Widget _opponentChip(String? opponent, List<String> allOpponents) {
    // nullは「全対戦相手」ボタン（全選択解除）
    final isAllButton = opponent == null;
    final isSelected = isAllButton
        ? _selectedOpponents.isEmpty
        : _selectedOpponents.contains(opponent);
    final label = opponent ?? '全対戦相手';
    return GestureDetector(
      onTap: () => setState(() {
        if (isAllButton) {
          _selectedOpponents = {};
        } else {
          if (_selectedOpponents.contains(opponent)) {
            _selectedOpponents = Set.from(_selectedOpponents)..remove(opponent);
          } else {
            _selectedOpponents = Set.from(_selectedOpponents)..add(opponent);
          }
        }
      }),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryRed
              : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryRed
                : const Color(0xFF555555),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.lightGrey,
            fontSize: 12,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.gold, size: 16),
        const SizedBox(width: 10),
        Text(text,
            style: const TextStyle(
                color: AppTheme.lightGrey, fontSize: 13)),
      ],
    );
  }

  // ─── プレビュー画面を開く ──────────────────────────────────────

  Future<void> _openPreview() async {
    setState(() {
      _isGenerating = true;
      _statusMessage = 'PDF生成中...';
    });

    final provider = Provider.of<AppProvider>(context, listen: false);

    try {
      await Future.delayed(Duration.zero);

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusMessage = '';
        });
        // ファイル名に期間情報を含める
        final periodSuffix = widget.dateRange != null
            ? '_${DateFormat('yyyyMMdd').format(widget.dateRange!.start)}-'
                '${DateFormat('yyyyMMdd').format(widget.dateRange!.end.subtract(const Duration(days: 1)))}'
            : '_全期間';
        final fileName =
            '藤橋JVC_分析レポート${periodSuffix}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              buildDocument: () => _buildPdfBytes(provider),
              fileName: fileName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusMessage = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  // ─── PDF バイト列生成（PdfPreviewウィジェットに渡すコールバック）──

  Future<Uint8List> _buildPdfBytes(AppProvider provider) async {
    final reg = await rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf');
    final regularFont = pw.Font.ttf(reg);
    final bld = await rootBundle.load('assets/fonts/NotoSansJP-Bold.ttf');
    final boldFont = pw.Font.ttf(bld);

    _regularFont = regularFont;
    _boldFont = boldFont;

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
      italic: regularFont,
      boldItalic: boldFont,
    );

    // 期間文字列：期間指定ありなら「YYYY/M/D 〜 YYYY/M/D」、なければ「全期間」
    final String periodStr;
    if (widget.dateRange != null) {
      final s = DateFormat('yyyy/M/d').format(widget.dateRange!.start);
      // endは「翁日 00:00」なので展示用に1日引く
      final eDate = widget.dateRange!.end.subtract(const Duration(days: 1));
      final e = DateFormat('yyyy/M/d').format(eDate);
      periodStr = '$s 〜 $e';
    } else {
      periodStr = '全期間';
    }
    final dateStr = '${DateFormat('yyyy/M/d').format(DateTime.now())} 出力  対象期間: $periodStr';
    final data = _collectData(provider);
    final pdf = pw.Document();
    int pageIdx = 0;

    void addOnePage(List<pw.Widget> widgets) {
      pageIdx++;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          margin: const pw.EdgeInsets.all(30),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfHeader(dateStr),
              pw.SizedBox(height: 12),
              ...widgets,
              pw.Spacer(),
              _pdfFooter(pageIdx),
            ],
          ),
        ),
      );
    }

    // 選手別成績
    if (_inclPlayerStats) {
      if (data.players.isEmpty) {
        addOnePage([_buildPlayerDetailPage(null, data, provider)]);
      } else {
        for (final player in data.players) {
          addOnePage([_buildPlayerDetailPage(player, data, provider)]);
        }
      }
    }
    // サーブランキング
    if (_inclServeRanking) {
      addOnePage([_buildServeRankPage(data)]);
    }
    // サーブレシーブランキング
    if (_inclReceiveRanking) {
      addOnePage([_buildReceiveRankPage(data)]);
    }
    // 対戦相手別分析
    if (_inclOpponentAnalysis) {
      addOnePage([_buildOpponentPage(data, provider)]);
    }

    if (pageIdx == 0) {
      addOnePage([
        pw.Text('出力項目を1つ以上選択してください。',
            style: pw.TextStyle(font: regularFont, fontSize: 14))
      ]);
    }

    return pdf.save();
  }

  // ─── データ収集 ──────────────────────────────────────────────

  _PdfData _collectData(AppProvider provider) {
    // stats画面と同じフィルタリングロジック
    List<Player> players;
    switch (widget.teamFilter) {
      case 'A':
        players = provider.teamAPlayers;
      case 'B':
        players = provider.teamBPlayers;
      default:
        players = provider.players;
    }
    if (widget.selectedPlayerIds != null &&
        widget.selectedPlayerIds!.isNotEmpty) {
      players = players
          .where((p) => widget.selectedPlayerIds!.contains(p.id))
          .toList();
    }

    // 期間フィルター用ショートカット
    final from = widget.dateRange?.start;
    final to = widget.dateRange?.end;

    // allMatches：期間指定がある場合は試合日で絞り込む
    final allMatches = (from != null || to != null)
        ? provider.matches.where((m) {
            if (from != null && m.date.isBefore(from)) return false;
            if (to != null && !m.date.isBefore(to)) return false;
            return true;
          }).toList()
        : provider.matches;

    // 対戦相手フィルター適用（複数選択対応・空=全対戦相手）
    final filteredMatches = _selectedOpponents.isNotEmpty
        ? allMatches.where((m) => _selectedOpponents.contains(m.opponent)).toList()
        : allMatches;

    // サーブ統計（期間フィルター適用）
    final serveStats = <String, _ServeStats>{};
    for (final p in players) {
      final s = provider.getServeStatsByPlayer(p.id, from: from, to: to);
      final total = s.values.fold(0, (a, b) => a + b);
      final ace = s[ServeResult.ace] ?? 0;
      final under = s[ServeResult.under] ?? 0;
      final justIn = s[ServeResult.justIn] ?? 0;
      final miss = s[ServeResult.miss] ?? 0;
      serveStats[p.id] = _ServeStats(
        total: total,
        ace: ace,
        under: under,
        justIn: justIn,
        miss: miss,
      );
    }

    // レシーブ統計（期間フィルター適用）
    final recvStats = <String, _RecvStats>{};
    for (final p in players) {
      final s = provider.getReceiveStatsByPlayer(p.id, from: from, to: to);
      final total = s.values.fold(0, (a, b) => a + b);
      final over = s[ReceiveResult.over] ?? 0;
      final under = s[ReceiveResult.under] ?? 0;
      final direct = s[ReceiveResult.direct] ?? 0;
      final miss = s[ReceiveResult.miss] ?? 0;
      recvStats[p.id] = _RecvStats(
        total: total,
        over: over,
        under: under,
        direct: direct,
        miss: miss,
      );
    }

    // 試合ごとのカウント
    final matchServe = <String, int>{};
    final matchRecv = <String, int>{};
    for (final m in allMatches) {
      matchServe[m.id] = provider.getServeRecordsByMatch(m.id).length;
      matchRecv[m.id] = provider.getReceiveRecordsByMatch(m.id).length;
    }

    // 対戦相手別の集計（選手ごと × 対戦相手ごと）
    final opponentServe = <String, Map<String, _ServeStats>>{};
    final opponentRecv = <String, Map<String, _RecvStats>>{};

    for (final m in filteredMatches) {
      final opp = m.opponent;
      opponentServe[opp] ??= {};
      opponentRecv[opp] ??= {};

      for (final p in players) {
        final sRecords = provider
            .getServeRecordsByMatch(m.id)
            .where((r) => r.playerId == p.id)
            .toList();
        final rRecords = provider
            .getReceiveRecordsByMatch(m.id)
            .where((r) => r.playerId == p.id)
            .toList();

        // サーブ集計
        final prevS = opponentServe[opp]![p.id];
        int sAce = (prevS?.ace ?? 0);
        int sUnder = (prevS?.under ?? 0);
        int sJustIn = (prevS?.justIn ?? 0);
        int sMiss = (prevS?.miss ?? 0);
        for (final r in sRecords) {
          switch (r.result) {
            case ServeResult.ace:
              sAce++;
            case ServeResult.under:
              sUnder++;
            case ServeResult.justIn:
              sJustIn++;
            case ServeResult.miss:
              sMiss++;
          }
        }
        opponentServe[opp]![p.id] = _ServeStats(
          total: sAce + sUnder + sJustIn + sMiss,
          ace: sAce,
          under: sUnder,
          justIn: sJustIn,
          miss: sMiss,
        );

        // レシーブ集計
        final prevR = opponentRecv[opp]![p.id];
        int rOver = (prevR?.over ?? 0);
        int rUnder = (prevR?.under ?? 0);
        int rDirect = (prevR?.direct ?? 0);
        int rMiss = (prevR?.miss ?? 0);
        for (final r in rRecords) {
          switch (r.result) {
            case ReceiveResult.over:
              rOver++;
            case ReceiveResult.under:
              rUnder++;
            case ReceiveResult.direct:
              rDirect++;
            case ReceiveResult.miss:
              rMiss++;
          }
        }
        opponentRecv[opp]![p.id] = _RecvStats(
          total: rOver + rUnder + rDirect + rMiss,
          over: rOver,
          under: rUnder,
          direct: rDirect,
          miss: rMiss,
        );
      }
    }

    return _PdfData(
      players: players,
      allMatches: allMatches,
      filteredMatches: filteredMatches,
      serveStats: serveStats,
      recvStats: recvStats,
      matchServe: matchServe,
      matchRecv: matchRecv,
      opponentServe: opponentServe,
      opponentRecv: opponentRecv,
      selectedOpponents: _selectedOpponents,
    );
  }

  // ─── AI講評生成（純粋計算） ──────────────────────────────────

  String _generateAiComment(
    Player player,
    Map<ServeResult, int> serveStats,
    Map<ReceiveResult, int> receiveStats,
  ) {
    final total = serveStats.values.fold(0, (a, b) => a + b);
    final rTotal = receiveStats.values.fold(0, (a, b) => a + b);

    if (total == 0 && rTotal == 0) {
      return '${player.name}選手のデータがまだありません。試合での記録を蓄積してください。';
    }

    final List<String> comments = [];

    // サーブ分析
    if (total > 0) {
      final aceRate = (serveStats[ServeResult.ace] ?? 0) / total * 100;
      final underRate = (serveStats[ServeResult.under] ?? 0) / total * 100;
      final missRate = (serveStats[ServeResult.miss] ?? 0) / total * 100;
      final efficiency =
          ((serveStats[ServeResult.ace] ?? 0) - (serveStats[ServeResult.miss] ?? 0)) /
              total *
              100;

      if (aceRate >= 20) {
        comments.add(
            '【サーブの特徴】エース率${aceRate.toStringAsFixed(1)}%と非常に高く、相手チームにとって大きな脅威です。');
      } else if (aceRate >= 10) {
        comments.add(
            '【サーブの特徴】エース率${aceRate.toStringAsFixed(1)}%は安定した水準です。さらなる向上を目指しましょう。');
      } else if (aceRate < 5 && total >= 5) {
        comments.add(
            '【サーブの特徴】エース率${aceRate.toStringAsFixed(1)}%はやや低めです。サーブコースの多様化を練習しましょう。');
      }

      if (underRate >= 35) {
        comments.add(
            '【崩し能力】崩し率${underRate.toStringAsFixed(1)}%と高く、相手の攻撃を制限するサーブができています。');
      } else if (underRate < 20 && total >= 5) {
        comments.add(
            '【崩し能力】崩し率${underRate.toStringAsFixed(1)}%はまだ改善の余地があります。コースを狙ったサーブを意識しましょう。');
      }

      if (missRate >= 20) {
        comments.add(
            '【改善ポイント】ミス率${missRate.toStringAsFixed(1)}%は高めです。強打とコントロールのバランスを見直し、安定性を高めることが優先課題です。');
      } else if (missRate <= 5 && total >= 5) {
        comments.add(
            '【安定性】ミス率${missRate.toStringAsFixed(1)}%と非常に安定したサーブを打てています。この安定性は試合で大きな武器になります。');
      }

      if (efficiency >= 10) {
        comments.add(
            '【サーブ成績】サーブスコア${efficiency.toStringAsFixed(1)}%と優秀です。チームへの貢献度が高い選手です。');
      } else if (efficiency < 0) {
        comments.add('【サーブ成績】現在サーブスコアがマイナスです。まずミスを減らすことを意識しましょう。');
      }

      final suggestions = <String>[];
      if (missRate >= 15) suggestions.add('入れることを優先した基礎練習');
      if (aceRate < 8) suggestions.add('コース狙いの練習（ライン際・ショートサーブ）');
      if (underRate < 25) suggestions.add('相手レシーバーを動かすサーブコース練習');
      if (suggestions.isNotEmpty) {
        comments.add('【練習提案】${suggestions.join('、')}を重点的に行うことをお勧めします。');
      }
    }

    // レシーブ分析
    if (rTotal > 0) {
      final overRate = (receiveStats[ReceiveResult.over] ?? 0) / rTotal * 100;
      final missRate = (receiveStats[ReceiveResult.miss] ?? 0) / rTotal * 100;

      if (overRate >= 50) {
        comments.add(
            '【レシーブ安定性】オーバーパス率${overRate.toStringAsFixed(1)}%と安定したレシーブができています。攻撃につながる質の高いパスです。');
      } else if (overRate >= 30) {
        comments.add(
            '【レシーブ安定性】オーバーパス率${overRate.toStringAsFixed(1)}%は平均的な水準です。さらに向上できるよう練習を続けましょう。');
      }

      if (missRate >= 20) {
        comments.add(
            '【レシーブ改善】レシーブミス率${missRate.toStringAsFixed(1)}%です。落下点への移動を素早く行う練習が大切です。');
      } else if (missRate <= 5 && rTotal >= 5) {
        comments.add(
            '【レシーブ安定性】ミス率${missRate.toStringAsFixed(1)}%と非常に安定しています。チームの守備の要として活躍できます。');
      }
    }

    if (comments.isEmpty) {
      return '${player.name}選手のデータを分析中です（$total回サーブ、$rTotal回レシーブ）。引き続き記録を続けてください。';
    }

    return comments.join('\n\n');
  }

  // ─── PDFページ構築 ────────────────────────────────────────────

  pw.Widget _pdfHeader(String dateStr) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.red800, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('藤橋JVC男子 バレーボール分析レポート',
                  style: pw.TextStyle(
                      fontNormal: _regularFont, fontBold: _boldFont,
                      fontSize: 15,
                      color: PdfColors.red900)),
              pw.Text('この一本、この一点',
                  style: pw.TextStyle(
                      fontNormal: _regularFont, fontBold: _boldFont,
                      fontSize: 9,
                      color: PdfColors.amber800)),
            ],
          ),
          pw.Text(dateStr,
              style: pw.TextStyle(
                  fontNormal: _regularFont, fontBold: _boldFont,
                  fontSize: 9,
                  color: PdfColors.grey)),
        ],
      ),
    );
  }

  pw.Widget _pdfFooter(int pageNum) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('藤橋JVC男子 バレーボール分析アプリ',
              style: pw.TextStyle(
                  fontNormal: _regularFont, fontBold: _boldFont,
                  fontSize: 7,
                  color: PdfColors.grey)),
          pw.Text('- $pageNum -',
              style: pw.TextStyle(
                  fontNormal: _regularFont, fontBold: _boldFont,
                  fontSize: 7,
                  color: PdfColors.grey)),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        color: PdfColors.red50,
        border: pw.Border(
            left: pw.BorderSide(color: PdfColors.red800, width: 3)),
      ),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontNormal: _regularFont, fontBold: _boldFont,
              fontSize: 12,
              color: PdfColors.red900)),
    );
  }

  pw.Widget _th(String t) => pw.Container(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontNormal: _regularFont, fontBold: _boldFont,
                fontSize: 8,
                color: PdfColors.white),
            textAlign: pw.TextAlign.center),
      );

  pw.Widget _td(String t, {bool highlight = false}) => pw.Container(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t,
            style: pw.TextStyle(
                font: highlight ? _boldFont : _regularFont,
                fontSize: 8,
                color:
                    highlight ? PdfColors.red900 : PdfColors.black),
            textAlign: pw.TextAlign.center),
      );

  // ── 選手別成績ページ（1選手ごと：サーブ+レシーブ+ランキング+AI講評） ──────
  pw.Widget _buildPlayerDetailPage(
    Player? player,
    _PdfData data,
    AppProvider provider,
  ) {
    if (player == null || data.players.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('選手別成績'),
          pw.Text('選手データがありません。',
              style: pw.TextStyle(
                  fontNormal: _regularFont, fontBold: _boldFont,
                  color: PdfColors.grey,
                  fontSize: 10)),
        ],
      );
    }

    final s = data.serveStats[player.id] ??
        _ServeStats(total: 0, ace: 0, under: 0, justIn: 0, miss: 0);
    final r = data.recvStats[player.id] ??
        _RecvStats(total: 0, over: 0, under: 0, direct: 0, miss: 0);

    // パーセント表示ヘルパー
    String pct(int n, int total) =>
        total > 0 ? '${(n / total * 100).toStringAsFixed(1)}%' : '-';

    // ── ランキング計算（3指標：サーブ効率・サービスミス率・サーブレシーブ率）──
    final activePlayers = data.players
        .where((p) => (data.serveStats[p.id]?.total ?? 0) > 0 ||
            (data.recvStats[p.id]?.total ?? 0) > 0)
        .toList();
    // totalCount は今後の拡張用（現在未使用）
    // final totalCount = activePlayers.length;

    // サーブ効率ランキング（(エース-ミス)/総数 の高い順）
    final serveEffRanked = activePlayers
        .where((p) => (data.serveStats[p.id]?.total ?? 0) > 0)
        .toList()
      ..sort((a, b) {
        final sa = data.serveStats[a.id]!;
        final sb = data.serveStats[b.id]!;
        final effA = (sa.ace - sa.miss) / sa.total;
        final effB = (sb.ace - sb.miss) / sb.total;
        return effB.compareTo(effA);
      });
    final serveEffRank = serveEffRanked.indexWhere((p) => p.id == player.id);
    final serveEff = s.total > 0
        ? '${((s.ace - s.miss) / s.total * 100).toStringAsFixed(1)}%'
        : '-';

    // サービスミス率ランキング（低い順 = 良い順）
    final serveMissRanked = activePlayers
        .where((p) => (data.serveStats[p.id]?.total ?? 0) > 0)
        .toList()
      ..sort((a, b) {
        final sa = data.serveStats[a.id]!;
        final sb = data.serveStats[b.id]!;
        final mA = sa.miss / sa.total;
        final mB = sb.miss / sb.total;
        return mA.compareTo(mB); // 低い順
      });
    final serveMissRank = serveMissRanked.indexWhere((p) => p.id == player.id);
    final serveMissPct = pct(s.miss, s.total);

    // サーブレシーブ率ランキング（オーバー率の高い順）
    final recvRanked = activePlayers
        .where((p) => (data.recvStats[p.id]?.total ?? 0) > 0)
        .toList()
      ..sort((a, b) {
        final ra = data.recvStats[a.id]!;
        final rb = data.recvStats[b.id]!;
        final ovA = ra.over / ra.total;
        final ovB = rb.over / rb.total;
        return ovB.compareTo(ovA);
      });
    final recvRank = recvRanked.indexWhere((p) => p.id == player.id);
    final recvPct = pct(r.over, r.total);
    final recvCount = recvRanked.length;
    final serveEffCount = serveEffRanked.length;
    final serveMissCount = serveMissRanked.length;

    // ランキングバッジウィジェット（\n禁止のためlabel2を別引数に）
    pw.Widget rankBadge(String label, String label2, int rank, int count, String valueStr) {
      if (rank < 0 || count == 0) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontNormal: _regularFont, fontBold: _boldFont,
                      fontSize: 8,
                      color: PdfColors.grey),
                  textAlign: pw.TextAlign.center),
              pw.Text(label2,
                  style: pw.TextStyle(
                      fontNormal: _regularFont, fontBold: _boldFont,
                      fontSize: 7,
                      color: PdfColors.grey),
                  textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.Text('データなし',
                  style: pw.TextStyle(
                      fontNormal: _regularFont, fontBold: _boldFont,
                      fontSize: 9,
                      color: PdfColors.grey),
                  textAlign: pw.TextAlign.center),
            ],
          ),
        );
      }
      final rankNum = rank + 1;
      final PdfColor badgeColor = rankNum == 1
          ? PdfColors.amber700
          : rankNum == 2
              ? PdfColors.blueGrey400
              : rankNum == 3
                  ? PdfColors.brown400
                  : PdfColors.red900;
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: PdfColors.grey50,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontNormal: _regularFont, fontBold: _boldFont,
                    fontSize: 7.5,
                    color: PdfColors.grey700),
                textAlign: pw.TextAlign.center),
            pw.Text(label2,
                style: pw.TextStyle(
                    fontNormal: _regularFont, fontBold: _boldFont,
                    fontSize: 6.5,
                    color: PdfColors.grey500),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 6),
            pw.Container(
              width: 38,
              height: 38,
              decoration: pw.BoxDecoration(
                color: badgeColor,
                shape: pw.BoxShape.circle,
              ),
              child: pw.Center(
                child: pw.Text(
                  '$rankNum位',
                  style: pw.TextStyle(
                      fontNormal: _regularFont, fontBold: _boldFont,
                      fontSize: 11,
                      color: PdfColors.white),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('$count人中',
                style: pw.TextStyle(
                    fontNormal: _regularFont, fontBold: _boldFont,
                    fontSize: 7,
                    color: PdfColors.grey600),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            pw.Text(valueStr,
                style: pw.TextStyle(
                    fontNormal: _regularFont, fontBold: _boldFont,
                    fontSize: 7.5,
                    color: badgeColor),
                textAlign: pw.TextAlign.center),
          ],
        ),
      );
    }

    // AI講評生成（providerから統計を取得して生成・期間フィルター適用）
    final serveMap = provider.getServeStatsByPlayer(
      player.id,
      from: widget.dateRange?.start,
      to: widget.dateRange?.end,
    );
    final recvMap = provider.getReceiveStatsByPlayer(
      player.id,
      from: widget.dateRange?.start,
      to: widget.dateRange?.end,
    );
    final aiComment = _generateAiComment(player, serveMap, recvMap);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // 選手名ヘッダー
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            color: PdfColors.red900,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                player.number.isNotEmpty ? '#${player.number}  ' : '',
                style: pw.TextStyle(
                    fontNormal: _regularFont, fontBold: _boldFont,
                    fontSize: 10,
                    color: PdfColors.amber200),
              ),
              pw.Text(
                player.name,
                style: pw.TextStyle(
                    fontNormal: _regularFont, fontBold: _boldFont,
                    fontSize: 13,
                    color: PdfColors.white),
              ),
              pw.Spacer(),
              pw.Text(
                '${player.team}チーム  個人成績レポート',
                style: pw.TextStyle(
                    fontNormal: _regularFont, fontBold: _boldFont,
                    fontSize: 9,
                    color: PdfColors.amber100),
              ),
            ],
          ),
        ),

        // サーブ統計テーブル
        _sectionTitle('サーブ成績'),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.red900),
              children: [
                _th('サーブ数'),
                _th('エース'),
                _th('崩し'),
                _th('入り'),
                _th('ミス'),
                if (_inclPercentage) _th('エース率'),
                if (_inclPercentage) _th('崩し率'),
                if (_inclPercentage) _th('ミス率'),
              ],
            ),
            pw.TableRow(children: [
              _td('${s.total}'),
              _td('${s.ace}', highlight: s.total > 0 && s.ace / s.total >= 0.15),
              _td('${s.under}'),
              _td('${s.justIn}'),
              _td('${s.miss}'),
              if (_inclPercentage)
                _td(pct(s.ace, s.total), highlight: s.total > 0 && s.ace / s.total >= 0.15),
              if (_inclPercentage) _td(pct(s.under, s.total)),
              if (_inclPercentage) _td(pct(s.miss, s.total)),
            ]),
          ],
        ),

        pw.SizedBox(height: 10),

        // レシーブ統計テーブル
        _sectionTitle('レシーブ成績'),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.red900),
              children: [
                _th('レシーブ数'),
                _th('オーバー'),
                _th('アンダー'),
                _th('ダイレクト'),
                _th('ミス'),
                if (_inclPercentage) _th('オーバー率'),
                if (_inclPercentage) _th('ミス率'),
              ],
            ),
            pw.TableRow(children: [
              _td('${r.total}'),
              _td('${r.over}', highlight: r.total > 0 && r.over / r.total >= 0.5),
              _td('${r.under}'),
              _td('${r.direct}'),
              _td('${r.miss}'),
              if (_inclPercentage)
                _td(pct(r.over, r.total), highlight: r.total > 0 && r.over / r.total >= 0.5),
              if (_inclPercentage) _td(pct(r.miss, r.total)),
            ]),
          ],
        ),

        pw.SizedBox(height: 10),

        // ランキング（3指標：サーブ効率・サービスミス率・サーブレシーブ率）
        _sectionTitle('ランキング'),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            pw.Expanded(
              child: rankBadge(
                'サーブ効率',
                'エース-ミス',
                serveEffRank,
                serveEffCount,
                'スコア: $serveEff',
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: rankBadge(
                'サービスミス率',
                '低い順が優秀',
                serveMissRank,
                serveMissCount,
                'ミス率: $serveMissPct',
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: rankBadge(
                'サーブレシーブ率',
                'オーバー率',
                recvRank,
                recvCount,
                'オーバー率: $recvPct',
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 10),

        // AI講評（\n禁止のため段落ごとに分割して表示）
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.amber50,
            border: pw.Border.all(color: PdfColors.amber200, width: 0.5),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('AI講評',
                  style: pw.TextStyle(
                      fontNormal: _regularFont, fontBold: _boldFont,
                      fontSize: 9,
                      color: PdfColors.amber900)),
              pw.SizedBox(height: 4),
              // 改行で分割して段落ごとにTextウィジェット化
              ...aiComment.split('\n\n').where((p) => p.trim().isNotEmpty).expand((para) => [
                pw.Text(
                  para.trim(),
                  style: pw.TextStyle(
                      fontNormal: _regularFont, fontBold: _boldFont,
                      fontSize: 8.5,
                      color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 3),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  // ── サーブランキングページ ──────────────────────────────────────
  pw.Widget _buildServeRankPage(_PdfData data) {
    final ranked = data.players
        .where((p) => (data.serveStats[p.id]?.total ?? 0) > 0)
        .toList()
      ..sort((a, b) {
        final rA = data.serveStats[a.id]!;
        final rB = data.serveStats[b.id]!;
        final aceA = rA.total > 0 ? rA.ace / rA.total : 0.0;
        final aceB = rB.total > 0 ? rB.ace / rB.total : 0.0;
        return aceB.compareTo(aceA);
      });

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('サーブランキング（エース率順）'),
        if (ranked.isEmpty)
          pw.Text('データなし',
              style: pw.TextStyle(
                  fontNormal: _regularFont, fontBold: _boldFont,
                  color: PdfColors.grey,
                  fontSize: 10))
        else
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.red900),
                children: [
                  _th('順位'),
                  _th('選手名'),
                  _th('チーム'),
                  _th('サーブ数'),
                  _th('エース'),
                  _th('崩し'),
                  _th('ミス'),
                  if (_inclPercentage) _th('エース率'),
                  if (_inclPercentage) _th('ミス率'),
                ],
              ),
              ...ranked.asMap().entries.map((e) {
                final idx = e.key;
                final p = e.value;
                final s = data.serveStats[p.id]!;
                final aceR = s.total > 0
                    ? '${(s.ace / s.total * 100).toStringAsFixed(1)}%'
                    : '-';
                final missR = s.total > 0
                    ? '${(s.miss / s.total * 100).toStringAsFixed(1)}%'
                    : '-';
                return pw.TableRow(
                  decoration: idx == 0
                      ? const pw.BoxDecoration(color: PdfColors.amber50)
                      : null,
                  children: [
                    _td('${idx + 1}位'),
                    _td(p.name),
                    _td(p.team),
                    _td('${s.total}'),
                    _td('${s.ace}', highlight: idx == 0),
                    _td('${s.under}'),
                    _td('${s.miss}'),
                    if (_inclPercentage)
                      _td(aceR, highlight: idx == 0),
                    if (_inclPercentage) _td(missR),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  // ── レシーブランキングページ ────────────────────────────────────
  pw.Widget _buildReceiveRankPage(_PdfData data) {
    final ranked = data.players
        .where((p) => (data.recvStats[p.id]?.total ?? 0) > 0)
        .toList()
      ..sort((a, b) {
        final rA = data.recvStats[a.id]!;
        final rB = data.recvStats[b.id]!;
        final ovA = rA.total > 0 ? rA.over / rA.total : 0.0;
        final ovB = rB.total > 0 ? rB.over / rB.total : 0.0;
        return ovB.compareTo(ovA);
      });

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('サーブレシーブランキング（オーバー率順）'),
        if (ranked.isEmpty)
          pw.Text('データなし',
              style: pw.TextStyle(
                  fontNormal: _regularFont, fontBold: _boldFont,
                  color: PdfColors.grey,
                  fontSize: 10))
        else
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.red900),
                children: [
                  _th('順位'),
                  _th('選手名'),
                  _th('チーム'),
                  _th('レシーブ数'),
                  _th('オーバー'),
                  _th('アンダー'),
                  _th('ミス'),
                  if (_inclPercentage) _th('オーバー率'),
                  if (_inclPercentage) _th('ミス率'),
                ],
              ),
              ...ranked.asMap().entries.map((e) {
                final idx = e.key;
                final p = e.value;
                final s = data.recvStats[p.id]!;
                final ovR = s.total > 0
                    ? '${(s.over / s.total * 100).toStringAsFixed(1)}%'
                    : '-';
                final missR = s.total > 0
                    ? '${(s.miss / s.total * 100).toStringAsFixed(1)}%'
                    : '-';
                return pw.TableRow(
                  decoration: idx == 0
                      ? const pw.BoxDecoration(color: PdfColors.amber50)
                      : null,
                  children: [
                    _td('${idx + 1}位'),
                    _td(p.name),
                    _td(p.team),
                    _td('${s.total}'),
                    _td('${s.over}', highlight: idx == 0),
                    _td('${s.under}'),
                    _td('${s.miss}'),
                    if (_inclPercentage)
                      _td(ovR, highlight: idx == 0),
                    if (_inclPercentage) _td(missR),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  // ── 対戦相手別分析ページ ────────────────────────────────────────
  pw.Widget _buildOpponentPage(_PdfData data, AppProvider provider) {
    final allOpponents = data.opponentServe.keys.toList()..sort();
    // 複数選択対応
    final hasFilter = data.selectedOpponents.isNotEmpty;
    final selectedSorted = data.selectedOpponents.toList()..sort();
    final targetLabel = hasFilter ? selectedSorted.join(', ') : '全対戦相手';

    if (data.filteredMatches.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('対戦相手別分析（$targetLabel）'),
          pw.Text('試合データがありません。',
              style: pw.TextStyle(
                  fontNormal: _regularFont, fontBold: _boldFont,
                  color: PdfColors.grey,
                  fontSize: 10)),
        ],
      );
    }

    // 表示する対戦相手一覧（複数選択対応）
    final displayOpponents = hasFilter ? selectedSorted : allOpponents;

    final List<pw.Widget> tables = [];
    for (final opp in displayOpponents) {
      final oppServe = data.opponentServe[opp] ?? {};
      final oppRecv = data.opponentRecv[opp] ?? {};
      final matchCount = data.filteredMatches
          .where((m) => m.opponent == opp)
          .length;

      tables.add(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            margin: const pw.EdgeInsets.only(bottom: 4),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
              border: pw.Border(
                  left: pw.BorderSide(
                      color: PdfColors.red700, width: 2)),
            ),
            child: pw.Text(
              '対戦相手: $opp  （$matchCount試合）',
              style: pw.TextStyle(
                  fontNormal: _regularFont, fontBold: _boldFont,
                  fontSize: 10,
                  color: PdfColors.red900),
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.red900),
                children: [
                  _th('選手名'),
                  _th('サーブ'),
                  _th('エース'),
                  _th('崩し'),
                  _th('ミス'),
                  if (_inclPercentage) _th('エース率'),
                  _th('レシーブ'),
                  _th('オーバー'),
                  _th('ミス'),
                  if (_inclPercentage) _th('オーバー率'),
                ],
              ),
              ...data.players.map((p) {
                final s = oppServe[p.id] ??
                    _ServeStats(
                        total: 0,
                        ace: 0,
                        under: 0,
                        justIn: 0,
                        miss: 0);
                final r = oppRecv[p.id] ??
                    _RecvStats(
                        total: 0,
                        over: 0,
                        under: 0,
                        direct: 0,
                        miss: 0);
                final aceR = s.total > 0
                    ? '${(s.ace / s.total * 100).toStringAsFixed(1)}%'
                    : '-';
                final ovR = r.total > 0
                    ? '${(r.over / r.total * 100).toStringAsFixed(1)}%'
                    : '-';
                return pw.TableRow(children: [
                  _td(p.name),
                  _td('${s.total}'),
                  _td('${s.ace}'),
                  _td('${s.under}'),
                  _td('${s.miss}'),
                  if (_inclPercentage) _td(aceR),
                  _td('${r.total}'),
                  _td('${r.over}'),
                  _td('${r.miss}'),
                  if (_inclPercentage) _td(ovR),
                ]);
              }),
            ],
          ),
          pw.SizedBox(height: 10),
        ],
      ));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('対戦相手別分析（$targetLabel）'),
        if (tables.isEmpty)
          pw.Text('対戦相手データなし',
              style: pw.TextStyle(
                  fontNormal: _regularFont, fontBold: _boldFont,
                  color: PdfColors.grey,
                  fontSize: 10))
        else
          ...tables,
      ],
    );
  }

}

// ─── データクラス ─────────────────────────────────────────────────

class _PdfData {
  final List<Player> players;
  final List allMatches;
  final List filteredMatches;
  final Map<String, _ServeStats> serveStats;
  final Map<String, _RecvStats> recvStats;
  final Map<String, int> matchServe;
  final Map<String, int> matchRecv;
  // 対戦相手別：opponent -> playerId -> stats
  final Map<String, Map<String, _ServeStats>> opponentServe;
  final Map<String, Map<String, _RecvStats>> opponentRecv;
  final Set<String> selectedOpponents; // 空=全対戦相手

  const _PdfData({
    required this.players,
    required this.allMatches,
    required this.filteredMatches,
    required this.serveStats,
    required this.recvStats,
    required this.matchServe,
    required this.matchRecv,
    required this.opponentServe,
    required this.opponentRecv,
    required this.selectedOpponents,
  });
}

class _ServeStats {
  final int total, ace, under, justIn, miss;
  const _ServeStats({
    required this.total,
    required this.ace,
    required this.under,
    required this.justIn,
    required this.miss,
  });
}

class _RecvStats {
  final int total, over, under, direct, miss;
  const _RecvStats({
    required this.total,
    required this.over,
    required this.under,
    required this.direct,
    required this.miss,
  });
}

// ══════════════════════════════════════════════════════════════════════════
// PDF 出力画面
// - PDF生成後、<a download> でファイルをダウンロード（iOS Safari含む全環境対応）
// - iOS Safari: window.open(blob/data:) は白紙になるため <a download> が唯一の確実な方法
// - Android/PC: 追加で「PDFを開く」ボタンからbase64 Data URI方式で新タブ表示可
// ══════════════════════════════════════════════════════════════════════════

class PdfPreviewScreen extends StatefulWidget {
  final Future<Uint8List> Function() buildDocument;
  final String fileName;

  const PdfPreviewScreen({
    super.key,
    required this.buildDocument,
    required this.fileName,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _generatePdf();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _generatePdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final bytes = await widget.buildDocument();
      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
        // 生成完了後、自動的にダウンロード開始（iOS Safari含む全環境で動作）
        _downloadPdf(bytes);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// PDFをダウンロード（iOS Safari対応・<a download>方式）
  /// iOS 13+: ダウンロード後にファイルアプリ or 共有→プリントで印刷可能
  void _downloadPdf([Uint8List? bytes]) {
    final data = bytes ?? _pdfBytes;
    if (data == null) return;
    final jsUint8Array = data.toJS;
    final blobParts = [jsUint8Array as JSAny].toJS;
    final blob = web.Blob(
      blobParts,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = widget.fileName;
    anchor.style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    Future.delayed(const Duration(seconds: 3), () {
      web.URL.revokeObjectURL(url);
      anchor.remove();
    });
  }

  /// Androidなど非iOS環境向け：新しいタブでPDFを開く（base64 Data URI方式）
  void _openInNewTab() {
    if (_pdfBytes == null) return;
    final base64Str = base64Encode(_pdfBytes!);
    final dataUri = 'data:application/pdf;base64,$base64Str';
    web.window.open(dataUri, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf, color: AppTheme.gold, size: 20),
            SizedBox(width: 8),
            Text('PDF 出力',
                style: TextStyle(color: AppTheme.gold, fontSize: 18)),
          ],
        ),
        actions: [
          if (!_isLoading && _errorMessage == null) ...[
            IconButton(
              icon: const Icon(Icons.download, color: AppTheme.gold),
              tooltip: 'PDFをダウンロード',
              onPressed: () => _downloadPdf(),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, color: AppTheme.gold),
              tooltip: 'PDFを開く（Android/PC）',
              onPressed: _openInNewTab,
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // ── ローディング中 ──
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.gold),
            SizedBox(height: 20),
            Text('PDF生成中...',
                style: TextStyle(color: AppTheme.gold, fontSize: 16)),
            SizedBox(height: 8),
            Text('しばらくお待ちください',
                style: TextStyle(color: AppTheme.grey, fontSize: 13)),
          ],
        ),
      );
    }

    // ── エラー ──
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 56),
              const SizedBox(height: 16),
              const Text('PDF生成に失敗しました',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!,
                  style: const TextStyle(
                      color: AppTheme.grey, fontSize: 12),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('再試行',
                    style: TextStyle(color: Colors.white)),
                onPressed: _generatePdf,
              ),
            ],
          ),
        ),
      );
    }

    // ── PDF生成完了 → 操作ガイド画面 ──
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const Center(
            child: Icon(Icons.check_circle_outline,
                color: AppTheme.gold, size: 72),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('PDF生成完了',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('PDFのダウンロードが始まりました',
                style: TextStyle(color: AppTheme.grey, fontSize: 14)),
          ),
          const SizedBox(height: 32),

          // ── ダウンロードボタン（メイン・iOS Safari対応） ──
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.download, size: 22),
            label: const Text('PDFをダウンロード',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: () => _downloadPdf(),
          ),
          const SizedBox(height: 12),

          // ── 新しいタブで開くボタン（Android/PC向け） ──
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.open_in_new,
                color: Colors.white, size: 22),
            label: const Text('PDFを開く（印刷・保存）',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            onPressed: _openInNewTab,
          ),
          const SizedBox(height: 32),

          // ── 使い方ガイド ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF444444)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.info_outline, color: AppTheme.gold, size: 18),
                  SizedBox(width: 8),
                  Text('使い方',
                      style: TextStyle(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ]),
                const SizedBox(height: 12),
                _guideRow(Icons.download, '「PDFをダウンロード」',
                    'PDFファイルを保存します。保存後にPDFアプリや「ファイル」アプリで開けます。'),
                const SizedBox(height: 10),
                _guideRow(Icons.open_in_new, '「PDFを開く」',
                    'Android/PCでブラウザのPDFビューアで表示できます。印刷ダイアログを開けます。'),
                const SizedBox(height: 10),
                _guideRow(Icons.phone_iphone, 'iPhoneでの印刷方法',
                    'ダウンロード後 → 「ファイル」アプリでPDFを開く → 共有ボタン →「プリント」をタップ'),
                const SizedBox(height: 10),
                _guideRow(Icons.android, 'Androidでの印刷方法',
                    '「PDFを開く」→ ブラウザ右上メニュー →「印刷」をタップ'),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _guideRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.lightGrey, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(
                      color: AppTheme.grey, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
