import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/serve_record.dart';
import '../utils/app_theme.dart';

class PrintScreen extends StatefulWidget {
  const PrintScreen({super.key});

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
                _buildCheckTile(
                  '試合別結果',
                  '各試合のサーブ・レシーブ記録',
                  Icons.sports_volleyball,
                  _inclMatchResult,
                  (v) => setState(() => _inclMatchResult = v),
                ),
                _buildCheckTile(
                  '選手別成績',
                  '選手ごとの全集計データ',
                  Icons.person,
                  _inclPlayerStats,
                  (v) => setState(() => _inclPlayerStats = v),
                ),
                _buildCheckTile(
                  'サーブランキング',
                  'エース率・崩し率・ミス率順位',
                  Icons.military_tech,
                  _inclServeRanking,
                  (v) => setState(() => _inclServeRanking = v),
                ),
                _buildCheckTile(
                  'サーブレシーブランキング',
                  'オーバー率・ミス率順位',
                  Icons.leaderboard,
                  _inclReceiveRanking,
                  (v) => setState(() => _inclReceiveRanking = v),
                ),
                _buildCheckTile(
                  '割合（%）表示',
                  '各項目のパーセンテージ',
                  Icons.percent,
                  _inclPercentage,
                  (v) => setState(() => _inclPercentage = v),
                ),
                _buildCheckTile(
                  'AI講評',
                  '各選手のAI自動分析コメント',
                  Icons.psychology,
                  _inclAiComment,
                  (v) => setState(() => _inclAiComment = v),
                ),
                _buildCheckTile(
                  '対戦相手別分析',
                  '相手チームごとの成績比較',
                  Icons.groups,
                  _inclOpponentAnalysis,
                  (v) => setState(() => _inclOpponentAnalysis = v),
                ),
                _buildCheckTile(
                  '期間集計',
                  '選択した期間の集計データ',
                  Icons.date_range,
                  _inclPeriodSummary,
                  (v) => setState(() => _inclPeriodSummary = v),
                ),
                _buildCheckTile(
                  'A/Bチーム比較',
                  'チーム間の成績比較',
                  Icons.compare_arrows,
                  _inclTeamComparison,
                  (v) => setState(() => _inclTeamComparison = v),
                ),
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
                      _infoRow(Icons.smartphone, 'スマホから直接印刷可能'),
                      const SizedBox(height: 8),
                      _infoRow(Icons.palette, '赤・黒・金デザイン（白黒印刷対応）'),
                      const SizedBox(height: 8),
                      _infoRow(Icons.family_restroom, '保護者配布向けレイアウト'),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          // 生成ボタン
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.cardBg,
              border: Border(top: BorderSide(color: Color(0xFF333333))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
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
                        : const Icon(Icons.print, color: Colors.white),
                    label: Text(
                      _isGenerating ? 'PDF生成中...' : '印刷・PDF保存',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isGenerating ? null : _generateAndPrint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.gold, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.gold,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: Color(0xFF333333))),
      ],
    );
  }

  Widget _buildCheckTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: value ? AppTheme.primaryRed.withValues(alpha: 0.08) : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? AppTheme.primaryRed.withValues(alpha: 0.4) : const Color(0xFF333333),
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
                fontWeight: value ? FontWeight.bold : FontWeight.normal,
                fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppTheme.grey, fontSize: 11)),
        secondary: Icon(icon,
            color: value ? AppTheme.primaryRed : AppTheme.grey, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.gold, size: 16),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(color: AppTheme.lightGrey, fontSize: 13)),
      ],
    );
  }

  Future<void> _generateAndPrint() async {
    setState(() => _isGenerating = true);
    final provider = Provider.of<AppProvider>(context, listen: false);

    try {
      final pdf = await _buildPdf(provider);
      final bytes = await pdf.save();
      // Web: Blobを使って直接ダウンロード（Printing.layoutPdfのASCII制限を回避）
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'application/pdf'),
      );
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download = 'volleyball_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      anchor.click();
      web.URL.revokeObjectURL(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDFをダウンロードしました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stack) {
      if (mounted) {
        // エラー詳細をダイアログで表示
        final errMsg = e.toString();
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('PDF生成エラー', style: TextStyle(color: Colors.red)),
            content: SingleChildScrollView(
              child: Text(errMsg, style: const TextStyle(fontSize: 12)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
        debugPrint('PDF Error: $errMsg\n$stack');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<pw.Document> _buildPdf(AppProvider provider) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy/MM/dd').format(now);

    // 日本語フォントをローカルから読み込み
    final pw.Font regularFont;
    final pw.Font boldFont;
    try {
      final regularData = await rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/NotoSansJP-Bold.ttf');
      regularFont = pw.Font.ttf(regularData);
      boldFont = pw.Font.ttf(boldData);
    } catch (e) {
      throw Exception('フォント読み込み失敗: $e');
    }

    // スタイルヘルパー（フォントを直接受け取る）
    pw.TextStyle style({
      double fontSize = 10,
      bool bold = false,
      PdfColor color = PdfColors.black,
    }) {
      return pw.TextStyle(
        font: bold ? boldFont : regularFont,
        fontSize: fontSize,
        color: color,
      );
    }

    // セルウィジェット（フォント直接適用）
    pw.Widget th(String text) => pw.Container(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(text,
              style: style(fontSize: 9, bold: true, color: PdfColors.white),
              textAlign: pw.TextAlign.center),
        );

    pw.Widget td(String text) => pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(text,
              style: style(fontSize: 9, color: PdfColors.black),
              textAlign: pw.TextAlign.center),
        );

    pw.Widget sectionTitle(String title) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const pw.BoxDecoration(
            color: PdfColors.red50,
            border: pw.Border(
                left: pw.BorderSide(color: PdfColors.red800, width: 3)),
          ),
          child: pw.Text(title,
              style: style(fontSize: 13, bold: true, color: PdfColors.red900)),
        );

    // ヘッダー
    pw.Widget header() => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
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
                  pw.Text('Fujihashi JVC - Volleyball Analysis Report',
                      style: style(
                          fontSize: 16,
                          bold: true,
                          color: PdfColors.red900)),
                  pw.Text('Kono ippon, kono itten',
                      style: style(fontSize: 10, color: PdfColors.amber800)),
                ],
              ),
              pw.Text(dateStr,
                  style: style(fontSize: 10, color: PdfColors.grey)),
            ],
          ),
        );

    // 試合別結果セクション
    pw.Widget matchSection() {
      final matches = provider.matches;
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          sectionTitle('Match Results'),
          pw.SizedBox(height: 8),
          if (matches.isEmpty)
            pw.Text('No match data',
                style: style(color: PdfColors.grey))
          else
            pw.Table(
              border:
                  pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.red900),
                  children: [
                    th('Date'), th('Team'), th('Opponent'),
                    th('Serves'), th('Receives'),
                  ],
                ),
                ...matches.map((m) {
                  final s = provider.getServeRecordsByMatch(m.id).length;
                  final r = provider.getReceiveRecordsByMatch(m.id).length;
                  return pw.TableRow(children: [
                    td(DateFormat('M/d').format(m.date)),
                    td(m.team),
                    td(m.opponent),
                    td('$s'),
                    td('$r'),
                  ]);
                }),
              ],
            ),
        ],
      );
    }

    // 選手別成績セクション
    pw.Widget playerStatsSection() {
      final players = provider.players;
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          sectionTitle('Player Stats'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red900),
                children: [
                  th('Name'), th('Team'),
                  th('Ace'), th('2nd'), th('In'), th('Miss'), th('Total'),
                  if (_inclPercentage) th('Ace%') else pw.SizedBox(),
                  if (_inclPercentage) th('Miss%') else pw.SizedBox(),
                ],
              ),
              ...players.map((p) {
                final s = provider.getServeStatsByPlayer(p.id);
                final total = s.values.fold(0, (a, b) => a + b);
                final ace = s[ServeResult.ace] ?? 0;
                final under = s[ServeResult.under] ?? 0;
                final justIn = s[ServeResult.justIn] ?? 0;
                final miss = s[ServeResult.miss] ?? 0;
                final aceRate = total > 0
                    ? (ace / total * 100).toStringAsFixed(1)
                    : '-';
                final missRate = total > 0
                    ? (miss / total * 100).toStringAsFixed(1)
                    : '-';
                return pw.TableRow(children: [
                  td(p.name), td(p.team),
                  td('$ace'), td('$under'), td('$justIn'),
                  td('$miss'), td('$total'),
                  if (_inclPercentage) td('$aceRate%') else pw.SizedBox(),
                  if (_inclPercentage) td('$missRate%') else pw.SizedBox(),
                ]);
              }),
            ],
          ),
        ],
      );
    }

    // サーブランキングセクション
    pw.Widget serveRankingSection() {
      final players = provider.players;
      final stats = players.map((p) {
        final s = provider.getServeStatsByPlayer(p.id);
        final total = s.values.fold(0, (a, b) => a + b);
        final ace = s[ServeResult.ace] ?? 0;
        final miss = s[ServeResult.miss] ?? 0;
        return {
          'player': p,
          'total': total,
          'aceRate': total > 0 ? ace / total * 100 : 0.0,
          'missRate': total > 0 ? miss / total * 100 : 0.0,
        };
      }).where((s) => (s['total'] as int) > 0).toList();
      stats.sort((a, b) =>
          (b['aceRate'] as double).compareTo(a['aceRate'] as double));

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          sectionTitle('Serve Ranking (Ace%)'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red900),
                children: [
                  th('Rank'), th('Name'), th('Serves'),
                  th('Ace%'), th('Miss%')
                ],
              ),
              ...stats.asMap().entries.map((e) {
                final idx = e.key;
                final s = e.value;
                final p = s['player'] as dynamic;
                return pw.TableRow(
                  decoration: idx == 0
                      ? const pw.BoxDecoration(color: PdfColors.amber50)
                      : null,
                  children: [
                    td('${idx + 1}'), td(p.name), td('${s['total']}'),
                    td('${(s['aceRate'] as double).toStringAsFixed(1)}%'),
                    td('${(s['missRate'] as double).toStringAsFixed(1)}%'),
                  ],
                );
              }),
            ],
          ),
        ],
      );
    }

    // レシーブランキングセクション
    pw.Widget receiveRankingSection() {
      final players = provider.players;
      final stats = players.map((p) {
        final s = provider.getReceiveStatsByPlayer(p.id);
        final total = s.values.fold(0, (a, b) => a + b);
        final over = s[ReceiveResult.over] ?? 0;
        final miss = s[ReceiveResult.miss] ?? 0;
        return {
          'player': p,
          'total': total,
          'overRate': total > 0 ? over / total * 100 : 0.0,
          'missRate': total > 0 ? miss / total * 100 : 0.0,
        };
      }).where((s) => (s['total'] as int) > 0).toList();
      stats.sort((a, b) =>
          (b['overRate'] as double).compareTo(a['overRate'] as double));

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          sectionTitle('Receive Ranking (Over%)'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red900),
                children: [
                  th('Rank'), th('Name'), th('Receives'),
                  th('Over%'), th('Miss%')
                ],
              ),
              ...stats.asMap().entries.map((e) {
                final idx = e.key;
                final s = e.value;
                final p = s['player'] as dynamic;
                return pw.TableRow(
                  decoration: idx == 0
                      ? const pw.BoxDecoration(color: PdfColors.amber50)
                      : null,
                  children: [
                    td('${idx + 1}'), td(p.name), td('${s['total']}'),
                    td('${(s['overRate'] as double).toStringAsFixed(1)}%'),
                    td('${(s['missRate'] as double).toStringAsFixed(1)}%'),
                  ],
                );
              }),
            ],
          ),
        ],
      );
    }

    // チーム比較セクション
    pw.Widget teamComparisonSection() {
      final teamA = provider.teamAPlayers;
      final teamB = provider.teamBPlayers;
      int sumServe(List ps) => ps.fold(
          0,
          (sum, p) =>
              sum +
              provider.getServeStatsByPlayer(p.id).values.fold(0, (a, b) => a + b));
      int sumAce(List ps) => ps.fold(
          0,
          (sum, p) =>
              sum + (provider.getServeStatsByPlayer(p.id)[ServeResult.ace] ?? 0));
      int sumMiss(List ps) => ps.fold(
          0,
          (sum, p) =>
              sum + (provider.getServeStatsByPlayer(p.id)[ServeResult.miss] ?? 0));
      final aTotal = sumServe(teamA);
      final bTotal = sumServe(teamB);
      final aAce = aTotal > 0 ? sumAce(teamA) / aTotal * 100 : 0.0;
      final bAce = bTotal > 0 ? sumAce(teamB) / bTotal * 100 : 0.0;
      final aMiss = aTotal > 0 ? sumMiss(teamA) / aTotal * 100 : 0.0;
      final bMiss = bTotal > 0 ? sumMiss(teamB) / bTotal * 100 : 0.0;

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          sectionTitle('A/B Team Comparison'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red900),
                children: [th(''), th('Team A'), th('Team B')],
              ),
              pw.TableRow(children: [
                td('Total Serves'), td('$aTotal'), td('$bTotal')
              ]),
              pw.TableRow(children: [
                td('Ace%'),
                td('${aAce.toStringAsFixed(1)}%'),
                td('${bAce.toStringAsFixed(1)}%')
              ]),
              pw.TableRow(children: [
                td('Miss%'),
                td('${aMiss.toStringAsFixed(1)}%'),
                td('${bMiss.toStringAsFixed(1)}%')
              ]),
            ],
          ),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => header(),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Fujihashi JVC Volleyball Analysis',
                  style: style(fontSize: 8, color: PdfColors.grey)),
              pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: style(fontSize: 8, color: PdfColors.grey)),
            ],
          ),
        ),
        build: (_) {
          final List<pw.Widget> content = [];
          if (_inclMatchResult) {
            content.add(matchSection());
            content.add(pw.SizedBox(height: 16));
          }
          if (_inclPlayerStats) {
            content.add(playerStatsSection());
            content.add(pw.SizedBox(height: 16));
          }
          if (_inclServeRanking) {
            content.add(serveRankingSection());
            content.add(pw.SizedBox(height: 16));
          }
          if (_inclReceiveRanking) {
            content.add(receiveRankingSection());
            content.add(pw.SizedBox(height: 16));
          }
          if (_inclTeamComparison) {
            content.add(teamComparisonSection());
            content.add(pw.SizedBox(height: 16));
          }
          if (content.isEmpty) {
            content.add(pw.Text('No items selected',
                style: style(fontSize: 12)));
          }
          return content;
        },
      ),
    );

    return pdf;
  }

}
