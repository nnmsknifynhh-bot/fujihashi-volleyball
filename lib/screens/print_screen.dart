import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;
import '../providers/app_provider.dart';
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
  bool _inclMatchResult = true;
  bool _inclPlayerStats = true;
  bool _inclServeRanking = true;
  bool _inclReceiveRanking = true;
  bool _inclPercentage = true;
  bool _inclAiComment = false;
  bool _inclOpponentAnalysis = false;
  bool _inclPeriodSummary = true;
  bool _inclTeamComparison = false;

  bool _isGenerating = false;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
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
            Text('印刷・PDF出力', style: TextStyle(color: AppTheme.gold, fontSize: 18)),
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
                _buildCheckTile('試合別結果', '各試合のサーブ・レシーブ記録',
                    Icons.sports_volleyball, _inclMatchResult,
                    (v) => setState(() => _inclMatchResult = v)),
                _buildCheckTile('選手別成績', '選手ごとの全集計データ',
                    Icons.person, _inclPlayerStats,
                    (v) => setState(() => _inclPlayerStats = v)),
                _buildCheckTile('サーブランキング', 'エース率・崩し率・ミス率順位',
                    Icons.military_tech, _inclServeRanking,
                    (v) => setState(() => _inclServeRanking = v)),
                _buildCheckTile('サーブレシーブランキング', 'オーバー率・ミス率順位',
                    Icons.leaderboard, _inclReceiveRanking,
                    (v) => setState(() => _inclReceiveRanking = v)),
                _buildCheckTile('割合（%）表示', '各項目のパーセンテージ',
                    Icons.percent, _inclPercentage,
                    (v) => setState(() => _inclPercentage = v)),
                _buildCheckTile('AI講評', '各選手のAI自動分析コメント',
                    Icons.psychology, _inclAiComment,
                    (v) => setState(() => _inclAiComment = v)),
                _buildCheckTile('対戦相手別分析', '相手チームごとの成績比較',
                    Icons.groups, _inclOpponentAnalysis,
                    (v) => setState(() => _inclOpponentAnalysis = v)),
                _buildCheckTile('期間集計', '選択した期間の集計データ',
                    Icons.date_range, _inclPeriodSummary,
                    (v) => setState(() => _inclPeriodSummary = v)),
                _buildCheckTile('A/Bチーム比較', 'チーム間の成績比較',
                    Icons.compare_arrows, _inclTeamComparison,
                    (v) => setState(() => _inclTeamComparison = v)),
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
                      _infoRow(Icons.download, 'ダウンロード方式（Safari/Chrome対応）'),
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
                      style: const TextStyle(color: AppTheme.gold, fontSize: 12),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.download, color: Colors.white),
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
        color: value
            ? AppTheme.primaryRed.withValues(alpha: 0.08)
            : AppTheme.cardBg,
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
            style: const TextStyle(color: AppTheme.grey, fontSize: 11)),
        secondary:
            Icon(icon, color: value ? AppTheme.primaryRed : AppTheme.grey, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.gold, size: 16),
        const SizedBox(width: 10),
        Text(text,
            style: const TextStyle(color: AppTheme.lightGrey, fontSize: 13)),
      ],
    );
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _statusMessage = msg);
  }

  // ─── PDF 生成メイン ─────────────────────────────────────────

  /// ポイント：
  ///   1. フォントはローカルTTF（144KB）を非同期ロード
  ///   2. セクションデータはDartオブジェクトとして先に全部収集（同期・軽量）
  ///   3. pw.Page（固定ページ）を1枚ずつaddPage → awaitでyield
  ///   4. pdf.save() は非同期なので問題なし
  ///   5. web.Blob + createObjectURL でダウンロード（iOS Safari対応）
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
        final reg = await rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf');
        await Future.delayed(Duration.zero);
        regularFont = pw.Font.ttf(reg);
        await Future.delayed(Duration.zero);
        final bld = await rootBundle.load('assets/fonts/NotoSansJP-Bold.ttf');
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
      final fileName =
          '藤橋JVC_分析レポート_${DateFormat('yyyyMMdd').format(now)}.pdf';

      // ── Step 2: データ収集（Dartオブジェクト、純粋計算）──
      _setStatus('データ収集中...');
      await Future.delayed(Duration.zero);

      final _PdfData data = _collectData(provider);
      await Future.delayed(Duration.zero);

      // ── Step 3: PDFドキュメント生成（1ページずつ addPage → yield）──
      final pdf = pw.Document();
      int pageIdx = 0;
      final totalSections = _countSections();

      // ページ追加ヘルパー（毎回yieldして画面更新を許可）
      Future<void> addOnePage(List<pw.Widget> widgets) async {
        pageIdx++;
        _setStatus('ページ生成中... ($pageIdx/$totalSections)');
        await Future.delayed(Duration.zero); // ← UIに制御を返す

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
        await Future.delayed(Duration.zero); // ← addPage後もyield
      }

      // 試合別結果
      if (_inclMatchResult) {
        await addOnePage([_buildMatchPage(data, theme)]);
      }

      // 選手別成績（選手数が多い場合は分割）
      if (_inclPlayerStats) {
        final chunks = _chunkPlayers(data.players, 10);
        for (final chunk in chunks) {
          await addOnePage([_buildPlayerPage(chunk, data, theme)]);
        }
      }

      // サーブランキング
      if (_inclServeRanking) {
        await addOnePage([_buildServeRankPage(data, theme)]);
      }

      // レシーブランキング
      if (_inclReceiveRanking) {
        await addOnePage([_buildReceiveRankPage(data, theme)]);
      }

      // A/Bチーム比較
      if (_inclTeamComparison) {
        await addOnePage([_buildTeamCompPage(data, theme)]);
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

  int _countSections() {
    int n = 0;
    if (_inclMatchResult) n++;
    if (_inclPlayerStats) n++;
    if (_inclServeRanking) n++;
    if (_inclReceiveRanking) n++;
    if (_inclTeamComparison) n++;
    return n == 0 ? 1 : n;
  }

  // ─── データ収集（純粋Dartオブジェクト） ──────────────────────

  _PdfData _collectData(AppProvider provider) {
    // stats画面と同じフィルタリングロジックを適用
    List players;
    switch (widget.teamFilter) {
      case 'A':
        players = provider.teamAPlayers;
      case 'B':
        players = provider.teamBPlayers;
      default:
        players = provider.players;
    }
    // 個別選手選択が有効な場合はさらに絞り込む
    if (widget.selectedPlayerIds != null && widget.selectedPlayerIds!.isNotEmpty) {
      players = players.where((p) => widget.selectedPlayerIds!.contains(p.id)).toList();
    }

    final matches = provider.matches;

    // サーブ統計
    final serveStats = <String, _ServeStats>{};
    for (final p in players) {
      final s = provider.getServeStatsByPlayer(p.id);
      final total = s.values.fold(0, (a, b) => a + b);
      final ace = s[ServeResult.ace] ?? 0;
      final under = s[ServeResult.under] ?? 0;
      final justIn = s[ServeResult.justIn] ?? 0;
      final miss = s[ServeResult.miss] ?? 0;
      serveStats[p.id] = _ServeStats(
        total: total, ace: ace, under: under, justIn: justIn, miss: miss,
      );
    }

    // レシーブ統計
    final recvStats = <String, _RecvStats>{};
    for (final p in players) {
      final s = provider.getReceiveStatsByPlayer(p.id);
      final total = s.values.fold(0, (a, b) => a + b);
      final over = s[ReceiveResult.over] ?? 0;
      final miss = s[ReceiveResult.miss] ?? 0;
      recvStats[p.id] = _RecvStats(total: total, over: over, miss: miss);
    }

    // 試合ごとのカウント
    final matchServe = <String, int>{};
    final matchRecv = <String, int>{};
    for (final m in matches) {
      matchServe[m.id] = provider.getServeRecordsByMatch(m.id).length;
      matchRecv[m.id] = provider.getReceiveRecordsByMatch(m.id).length;
    }

    return _PdfData(
      players: players,
      matches: matches,
      serveStats: serveStats,
      recvStats: recvStats,
      matchServe: matchServe,
      matchRecv: matchRecv,
      teamA: provider.teamAPlayers,
      teamB: provider.teamBPlayers,
    );
  }

  List<List<dynamic>> _chunkPlayers(List players, int size) {
    final result = <List<dynamic>>[];
    for (int i = 0; i < players.length; i += size) {
      result.add(players.sublist(i, (i + size).clamp(0, players.length)));
    }
    if (result.isEmpty) result.add([]);
    return result;
  }

  // ─── PDFページ構築（pw.Widget返し） ───────────────────────────

  pw.Widget _pdfHeader(String dateStr) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.red800, width: 2)),
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
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.amber800)),
            ],
          ),
          pw.Text(dateStr,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
        ],
      ),
    );
  }

  pw.Widget _pdfFooter(int pageNum) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('藤橋JVC男子 バレーボール分析アプリ',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
          pw.Text('- $pageNum -',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
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
        border: pw.Border(left: pw.BorderSide(color: PdfColors.red800, width: 3)),
      ),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
    );
  }

  pw.Widget _th(String t) => pw.Container(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            textAlign: pw.TextAlign.center),
      );

  pw.Widget _td(String t, {bool highlight = false}) => pw.Container(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 8,
                color: highlight ? PdfColors.red900 : PdfColors.black,
                fontWeight: highlight ? pw.FontWeight.bold : pw.FontWeight.normal),
            textAlign: pw.TextAlign.center),
      );

  // 試合別結果ページ
  pw.Widget _buildMatchPage(_PdfData data, pw.ThemeData theme) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('試合別結果'),
        if (data.matches.isEmpty)
          pw.Text('試合データなし',
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10))
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red900),
                children: [
                  _th('日付'), _th('チーム'), _th('対戦相手'),
                  _th('サーブ数'), _th('レシーブ数'),
                ],
              ),
              ...data.matches.map((m) => pw.TableRow(
                    children: [
                      _td(DateFormat('M/d').format(m.date)),
                      _td(m.team),
                      _td(m.opponent),
                      _td('${data.matchServe[m.id] ?? 0}'),
                      _td('${data.matchRecv[m.id] ?? 0}'),
                    ],
                  )),
            ],
          ),
      ],
    );
  }

  // 選手別成績ページ（chunk単位）
  pw.Widget _buildPlayerPage(
      List chunk, _PdfData data, pw.ThemeData theme) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('選手別成績'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.red900),
              children: [
                _th('選手名'), _th('チーム'),
                _th('エース'), _th('崩し'), _th('入り'), _th('ミス'), _th('計'),
                if (_inclPercentage) _th('エース率'),
                if (_inclPercentage) _th('ミス率'),
              ],
            ),
            ...chunk.map((p) {
              final s = data.serveStats[p.id]!;
              final aceR = s.total > 0
                  ? '${(s.ace / s.total * 100).toStringAsFixed(1)}%'
                  : '-';
              final missR = s.total > 0
                  ? '${(s.miss / s.total * 100).toStringAsFixed(1)}%'
                  : '-';
              return pw.TableRow(children: [
                _td(p.name), _td(p.team),
                _td('${s.ace}'), _td('${s.under}'),
                _td('${s.justIn}'), _td('${s.miss}'), _td('${s.total}'),
                if (_inclPercentage) _td(aceR),
                if (_inclPercentage) _td(missR),
              ]);
            }),
          ],
        ),
      ],
    );
  }

  // サーブランキングページ
  pw.Widget _buildServeRankPage(_PdfData data, pw.ThemeData theme) {
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
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10))
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red900),
                children: [
                  _th('順位'), _th('選手名'), _th('サーブ数'),
                  _th('エース率'), _th('ミス率'),
                ],
              ),
              ...ranked.asMap().entries.map((e) {
                final idx = e.key;
                final p = e.value;
                final s = data.serveStats[p.id]!;
                final aceR =
                    s.total > 0 ? '${(s.ace / s.total * 100).toStringAsFixed(1)}%' : '-';
                final missR =
                    s.total > 0 ? '${(s.miss / s.total * 100).toStringAsFixed(1)}%' : '-';
                return pw.TableRow(
                  decoration: idx == 0
                      ? const pw.BoxDecoration(color: PdfColors.amber50)
                      : null,
                  children: [
                    _td('${idx + 1}位'), _td(p.name),
                    _td('${s.total}本'), _td(aceR, highlight: idx == 0),
                    _td(missR),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  // レシーブランキングページ
  pw.Widget _buildReceiveRankPage(_PdfData data, pw.ThemeData theme) {
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
        _sectionTitle('レシーブランキング（オーバー率順）'),
        if (ranked.isEmpty)
          pw.Text('データなし',
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10))
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red900),
                children: [
                  _th('順位'), _th('選手名'), _th('レシーブ数'),
                  _th('オーバー率'), _th('ミス率'),
                ],
              ),
              ...ranked.asMap().entries.map((e) {
                final idx = e.key;
                final p = e.value;
                final s = data.recvStats[p.id]!;
                final ovR =
                    s.total > 0 ? '${(s.over / s.total * 100).toStringAsFixed(1)}%' : '-';
                final missR =
                    s.total > 0 ? '${(s.miss / s.total * 100).toStringAsFixed(1)}%' : '-';
                return pw.TableRow(
                  decoration: idx == 0
                      ? const pw.BoxDecoration(color: PdfColors.amber50)
                      : null,
                  children: [
                    _td('${idx + 1}位'), _td(p.name),
                    _td('${s.total}本'), _td(ovR, highlight: idx == 0),
                    _td(missR),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  // A/Bチーム比較ページ
  pw.Widget _buildTeamCompPage(_PdfData data, pw.ThemeData theme) {
    int sumStat(List players, int Function(_ServeStats) fn) =>
        players.fold(0, (s, p) => s + fn(data.serveStats[p.id]!));

    final aTotal = sumStat(data.teamA, (s) => s.total);
    final bTotal = sumStat(data.teamB, (s) => s.total);
    final aAce = aTotal > 0 ? sumStat(data.teamA, (s) => s.ace) / aTotal * 100 : 0.0;
    final bAce = bTotal > 0 ? sumStat(data.teamB, (s) => s.ace) / bTotal * 100 : 0.0;
    final aMiss = aTotal > 0 ? sumStat(data.teamA, (s) => s.miss) / aTotal * 100 : 0.0;
    final bMiss = bTotal > 0 ? sumStat(data.teamB, (s) => s.miss) / bTotal * 100 : 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('A/Bチーム比較'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.red900),
              children: [_th(''), _th('Aチーム'), _th('Bチーム')],
            ),
            pw.TableRow(children: [
              _td('サーブ総数'), _td('$aTotal'), _td('$bTotal')
            ]),
            pw.TableRow(children: [
              _td('エース率'),
              _td('${aAce.toStringAsFixed(1)}%', highlight: aAce > bAce),
              _td('${bAce.toStringAsFixed(1)}%', highlight: bAce > aAce),
            ]),
            pw.TableRow(children: [
              _td('ミス率'),
              _td('${aMiss.toStringAsFixed(1)}%'),
              _td('${bMiss.toStringAsFixed(1)}%'),
            ]),
          ],
        ),
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
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
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

// ─── データクラス（軽量Dartオブジェクト） ──────────────────────────

class _PdfData {
  final List players;
  final List matches;
  final Map<String, _ServeStats> serveStats;
  final Map<String, _RecvStats> recvStats;
  final Map<String, int> matchServe;
  final Map<String, int> matchRecv;
  final List teamA;
  final List teamB;

  const _PdfData({
    required this.players,
    required this.matches,
    required this.serveStats,
    required this.recvStats,
    required this.matchServe,
    required this.matchRecv,
    required this.teamA,
    required this.teamB,
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
  final int total, over, miss;
  const _RecvStats({
    required this.total,
    required this.over,
    required this.miss,
  });
}
