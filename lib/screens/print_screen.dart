import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:js_interop';

import 'package:web/web.dart' as web;
import '../providers/app_provider.dart';
import '../models/player.dart';
import '../models/serve_record.dart';
import '../utils/app_theme.dart';

/// stats画面で選択中のチーム・選手をそのままPDFに反映するため、
/// teamFilter と selectedPlayerIds を受け取る
class PrintScreen extends StatefulWidget {
  /// 'A', 'B', 'all' のいずれか
  final String teamFilter;

  /// null = チーム全員, 非null = 個別選択中の選手IDセット
  final Set<String>? selectedPlayerIds;

  const PrintScreen({
    super.key,
    this.teamFilter = 'all',
    this.selectedPlayerIds,
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

  // 対戦相手別分析の選択状態
  String? _selectedOpponent;

  bool _isGenerating = false;
  String _statusMessage = '';

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
                    if (!v) _selectedOpponent = null;
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
                              const Padding(
                                padding: EdgeInsets.only(top: 8, bottom: 4),
                                child: Text(
                                  '対戦相手を選択（未選択=全対戦相手）',
                                  style: TextStyle(
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
                      _infoRow(
                          Icons.download, 'ダウンロード方式（Safari/Chrome対応）'),
                      const SizedBox(height: 8),
                      _infoRow(Icons.language, '日本語フォント（ローカル処理）'),
                      const SizedBox(height: 8),
                      _infoRow(Icons.family_restroom, '保護者配布向けレイアウト'),
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
                            : const Icon(Icons.download,
                                color: Colors.white),
                        label: Text(
                          _isGenerating ? 'PDF生成中...' : 'PDFをダウンロード',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isGenerating ? null : _generatePdf,
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

  /// 対戦相手選択チップ
  Widget _opponentChip(String? opponent, List<String> allOpponents) {
    final isSelected = opponent == _selectedOpponent;
    final label = opponent ?? '全対戦相手';
    return GestureDetector(
      onTap: () => setState(() {
        _selectedOpponent = isSelected ? null : opponent;
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

  void _setStatus(String msg) {
    if (mounted) setState(() => _statusMessage = msg);
  }

  // ─── PDF 生成メイン ─────────────────────────────────────────

  Future<void> _generatePdf() async {
    setState(() {
      _isGenerating = true;
      _statusMessage = 'フォント読み込み中...';
    });

    final provider = Provider.of<AppProvider>(context, listen: false);

    try {
      await Future.delayed(Duration.zero);

      // ── Step 1: フォント読み込み ──
      pw.Font regularFont;
      pw.Font boldFont;
      try {
        final reg =
            await rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf');
        await Future.delayed(Duration.zero);
        regularFont = pw.Font.ttf(reg);
        await Future.delayed(Duration.zero);
        final bld =
            await rootBundle.load('assets/fonts/NotoSansJP-Bold.ttf');
        await Future.delayed(Duration.zero);
        boldFont = pw.Font.ttf(bld);
        await Future.delayed(Duration.zero);
      } catch (_) {
        regularFont = pw.Font.helvetica();
        boldFont = pw.Font.helveticaBold();
      }

      final theme = pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
        italic: regularFont,
        boldItalic: boldFont,
      );

      final now = DateTime.now();
      final dateStr = DateFormat('yyyy/M/d').format(now);
      final fileName = '藤橋JVC_分析レポート_${DateFormat('yyyyMMdd').format(now)}.pdf';

      // ── Step 2: データ収集 ──
      _setStatus('データ収集中...');
      await Future.delayed(Duration.zero);

      final data = _collectData(provider);
      await Future.delayed(Duration.zero);

      // ── Step 3: PDFドキュメント生成（1ページずつ addPage → yield）──
      final pdf = pw.Document();
      int pageIdx = 0;
      final totalSections = _countSections(data);

      Future<void> addOnePage(List<pw.Widget> widgets) async {
        pageIdx++;
        _setStatus('ページ生成中... ($pageIdx/$totalSections)');
        await Future.delayed(Duration.zero);

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
        await Future.delayed(Duration.zero);
      }

      // ── 選手別成績（選手ごとに1ページ：サーブ＋レシーブ＋AI講評）──
      if (_inclPlayerStats) {
        for (final player in data.players) {
          await addOnePage([
            _buildPlayerDetailPage(player, data, provider),
          ]);
        }
        if (data.players.isEmpty) {
          await addOnePage([
            _buildPlayerDetailPage(null, data, provider),
          ]);
        }
      }

      // ── サーブランキング ──
      if (_inclServeRanking) {
        await addOnePage([_buildServeRankPage(data)]);
      }

      // ── サーブレシーブランキング ──
      if (_inclReceiveRanking) {
        await addOnePage([_buildReceiveRankPage(data)]);
      }

      // ── 対戦相手別分析 ──
      if (_inclOpponentAnalysis) {
        await addOnePage([_buildOpponentPage(data, provider)]);
      }

      // ── Step 4: バイト列に変換 ──
      _setStatus('PDFファイルを生成中...');
      await Future.delayed(Duration.zero);

      final pdfBytes = await pdf.save();
      await Future.delayed(Duration.zero);

      // ── Step 5: ダウンロード ──
      _setStatus('ダウンロード準備中...');
      await Future.delayed(Duration.zero);

      _downloadBytes(pdfBytes, fileName);

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusMessage = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDFを生成しました。ダウンロードを確認してください。'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
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
            content: Text('PDF生成エラー: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  int _countSections(_PdfData data) {
    int n = 0;
    if (_inclPlayerStats) n += data.players.isEmpty ? 1 : data.players.length;
    if (_inclServeRanking) n++;
    if (_inclReceiveRanking) n++;
    if (_inclOpponentAnalysis) n++;
    return n == 0 ? 1 : n;
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

    final allMatches = provider.matches;

    // 対戦相手フィルター適用
    final filteredMatches = _selectedOpponent != null
        ? allMatches.where((m) => m.opponent == _selectedOpponent).toList()
        : allMatches;

    // サーブ統計（全試合分）
    final serveStats = <String, _ServeStats>{};
    for (final p in players) {
      final s = provider.getServeStatsByPlayer(p.id);
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

    // レシーブ統計（全試合分）
    final recvStats = <String, _RecvStats>{};
    for (final p in players) {
      final s = provider.getReceiveStatsByPlayer(p.id);
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
      selectedOpponent: _selectedOpponent,
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
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red900)),
              pw.Text('この一本、この一点',
                  style:
                      pw.TextStyle(fontSize: 9, color: PdfColors.amber800)),
            ],
          ),
          pw.Text(dateStr,
              style:
                  const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
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
              style:
                  const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
          pw.Text('- $pageNum -',
              style:
                  const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
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
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red900)),
    );
  }

  pw.Widget _th(String t) => pw.Container(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
            textAlign: pw.TextAlign.center),
      );

  pw.Widget _td(String t, {bool highlight = false}) => pw.Container(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 8,
                color:
                    highlight ? PdfColors.red900 : PdfColors.black,
                fontWeight: highlight
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal),
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
              style: const pw.TextStyle(
                  color: PdfColors.grey, fontSize: 10)),
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

    // ランキングバッジウィジェット
    pw.Widget rankBadge(String label, int rank, int count, String valueStr) {
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
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                  textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.Text('データなし',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
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
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700),
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
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('$count人中',
                style: const pw.TextStyle(
                    fontSize: 7, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            pw.Text(valueStr,
                style: pw.TextStyle(
                    fontSize: 7.5,
                    color: badgeColor,
                    fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center),
          ],
        ),
      );
    }

    // AI講評生成（providerから統計を取得して生成）
    final serveMap = provider.getServeStatsByPlayer(player.id);
    final recvMap = provider.getReceiveStatsByPlayer(player.id);
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
                    fontSize: 10,
                    color: PdfColors.amber200,
                    fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                player.name,
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white),
              ),
              pw.Spacer(),
              pw.Text(
                '${player.team}チーム  個人成績レポート',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.amber100),
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
                'サーブ効率\n(エース-ミス)',
                serveEffRank,
                serveEffCount,
                'スコア: $serveEff',
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: rankBadge(
                'サービスミス率\n(低い順が優秀)',
                serveMissRank,
                serveMissCount,
                'ミス率: $serveMissPct',
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: rankBadge(
                'サーブレシーブ率\n(オーバー率)',
                recvRank,
                recvCount,
                'オーバー率: $recvPct',
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 10),

        // AI講評
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
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.amber900)),
              pw.SizedBox(height: 4),
              pw.Text(
                aiComment,
                style: const pw.TextStyle(
                    fontSize: 8.5, color: PdfColors.grey800),
              ),
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
              style: const pw.TextStyle(
                  color: PdfColors.grey, fontSize: 10))
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
              style: const pw.TextStyle(
                  color: PdfColors.grey, fontSize: 10))
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
    final opponents = data.opponentServe.keys.toList()..sort();
    final targetLabel = data.selectedOpponent ?? '全対戦相手';

    if (data.filteredMatches.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('対戦相手別分析（$targetLabel）'),
          pw.Text('試合データがありません。',
              style: const pw.TextStyle(
                  color: PdfColors.grey, fontSize: 10)),
        ],
      );
    }

    // 表示する対戦相手一覧
    final displayOpponents =
        data.selectedOpponent != null ? [data.selectedOpponent!] : opponents;

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
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
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
              style: const pw.TextStyle(
                  color: PdfColors.grey, fontSize: 10))
        else
          ...tables,
      ],
    );
  }

  // ─── ダウンロード ─────────────────────────────────────────────

  void _downloadBytes(List<int> bytes, String fileName) {
    final uint8list = Uint8List.fromList(bytes);
    final jsUint8Array = uint8list.toJS;
    final blobParts = [jsUint8Array as JSAny].toJS;
    final blob = web.Blob(
      blobParts,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor =
        web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    Future.delayed(const Duration(seconds: 2), () {
      web.URL.revokeObjectURL(url);
      anchor.remove();
    });
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
  final String? selectedOpponent;

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
    required this.selectedOpponent,
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
