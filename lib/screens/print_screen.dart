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
          // 生成ボタン
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

  void _setStatus(String msg) {
    if (mounted) setState(() => _statusMessage = msg);
  }

  /// メインのPDF生成処理
  /// - フォント：ローカルTTFアセット（ネットワーク不要）
  /// - 出力：web.Blob + createObjectURL（iOS Safari対応）
  /// - 非同期チャンク：各セクション間でFuture.delayed(Duration.zero)を挿入
  Future<void> _generatePdf() async {
    setState(() {
      _isGenerating = true;
      _statusMessage = 'フォント読み込み中...';
    });

    final provider = Provider.of<AppProvider>(context, listen: false);

    try {
      // UIスレッドに制御を返す
      await Future.delayed(Duration.zero);

      // ── Step 1: フォント読み込み（ローカルアセット）──
      _setStatus('フォント読み込み中...');
      await Future.delayed(Duration.zero);

      pw.Font regularFont;
      pw.Font boldFont;
      try {
        final regularData = await rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf');
        await Future.delayed(Duration.zero); // UIスレッドに制御を返す
        regularFont = pw.Font.ttf(regularData);
        await Future.delayed(Duration.zero);

        final boldData = await rootBundle.load('assets/fonts/NotoSansJP-Bold.ttf');
        await Future.delayed(Duration.zero);
        boldFont = pw.Font.ttf(boldData);
        await Future.delayed(Duration.zero);
      } catch (e) {
        // フォント読み込み失敗時はHelveticaにフォールバック
        regularFont = pw.Font.helvetica();
        boldFont = pw.Font.helveticaBold();
      }

      _setStatus('PDFドキュメント作成中...');
      await Future.delayed(Duration.zero);

      // ── Step 2: PDFドキュメント構築 ──
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy/M/d').format(now);
      final fileName = '藤橋JVC_分析レポート_${DateFormat('yyyyMMdd').format(now)}.pdf';

      final theme = pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
        italic: regularFont,
        boldItalic: boldFont,
      );

      // ── Step 3: セクション毎にチャンク処理 ──
      _setStatus('コンテンツ生成中...');
      await Future.delayed(Duration.zero);

      final List<pw.Widget> content = [];

      if (_inclMatchResult) {
        _setStatus('試合別結果を生成中...');
        await Future.delayed(Duration.zero);
        content.add(_buildPdfMatchSection(provider));
        content.add(pw.SizedBox(height: 16));
      }

      await Future.delayed(Duration.zero);

      if (_inclPlayerStats) {
        _setStatus('選手別成績を生成中...');
        await Future.delayed(Duration.zero);
        content.add(_buildPdfPlayerStats(provider));
        content.add(pw.SizedBox(height: 16));
      }

      await Future.delayed(Duration.zero);

      if (_inclServeRanking) {
        _setStatus('サーブランキングを生成中...');
        await Future.delayed(Duration.zero);
        content.add(_buildPdfServeRanking(provider));
        content.add(pw.SizedBox(height: 16));
      }

      await Future.delayed(Duration.zero);

      if (_inclReceiveRanking) {
        _setStatus('レシーブランキングを生成中...');
        await Future.delayed(Duration.zero);
        content.add(_buildPdfReceiveRanking(provider));
        content.add(pw.SizedBox(height: 16));
      }

      await Future.delayed(Duration.zero);

      if (_inclTeamComparison) {
        _setStatus('チーム比較を生成中...');
        await Future.delayed(Duration.zero);
        content.add(_buildPdfTeamComparison(provider));
        content.add(pw.SizedBox(height: 16));
      }

      if (content.isEmpty) {
        content.add(pw.Center(
          child: pw.Text('出力項目が選択されていません',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
        ));
      }

      _setStatus('ページレイアウト処理中...');
      await Future.delayed(Duration.zero);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          margin: const pw.EdgeInsets.all(30),
          header: (context) => _buildPdfHeader(dateStr),
          footer: (context) => _buildPdfFooter(context),
          build: (context) => content,
        ),
      );

      // ── Step 4: PDF バイト列生成 ──
      _setStatus('PDFファイルを生成中...');
      await Future.delayed(Duration.zero);

      final pdfBytes = await pdf.save();
      await Future.delayed(Duration.zero);

      // ── Step 5: web.Blob + createObjectURL でダウンロード ──
      _setStatus('ダウンロード準備中...');
      await Future.delayed(Duration.zero);

      _downloadPdfBytes(pdfBytes, fileName);

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
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// web.Blob + createObjectURL を使ったPDFダウンロード
  /// iOS Safari でも動作する方式
  void _downloadPdfBytes(List<int> bytes, String fileName) {
    // Uint8List → JSUint8Array に変換してBlobを作成
    final uint8list = Uint8List.fromList(bytes);
    final jsUint8Array = uint8list.toJS;

    // JSArray<BlobPart> を作成（JSAnyとしてキャスト）
    final blobParts = [jsUint8Array as JSAny].toJS;

    final blob = web.Blob(
      blobParts,
      web.BlobPropertyBag(type: 'application/pdf'),
    );

    final url = web.URL.createObjectURL(blob);

    // <a>タグを作成してクリックシミュレート
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();

    // iOS対応：少し遅延してからURLを解放
    Future.delayed(const Duration(seconds: 2), () {
      web.URL.revokeObjectURL(url);
      anchor.remove();
    });
  }

  // ── PDF コンテンツ構築ヘルパー ──

  pw.Widget _buildPdfHeader(String dateStr) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.red800, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '藤橋JVC男子 バレーボール分析レポート',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red900,
                ),
              ),
              pw.Text(
                'この一本、この一点',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.amber800),
              ),
            ],
          ),
          pw.Text(dateStr, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('藤橋JVC男子 バレーボール分析アプリ',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          pw.Text('${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfMatchSection(AppProvider provider) {
    final matches = provider.matches;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionTitle('試合別結果'),
        pw.SizedBox(height: 8),
        if (matches.isEmpty)
          pw.Text('試合データなし', style: const pw.TextStyle(color: PdfColors.grey))
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red900),
                children: [
                  _pdfTh('日付'), _pdfTh('チーム'), _pdfTh('対戦相手'),
                  _pdfTh('サーブ数'), _pdfTh('レシーブ数'),
                ],
              ),
              ...matches.map((m) {
                final s = provider.getServeRecordsByMatch(m.id).length;
                final r = provider.getReceiveRecordsByMatch(m.id).length;
                return pw.TableRow(
                  children: [
                    _pdfTd(DateFormat('M/d').format(m.date)),
                    _pdfTd(m.team),
                    _pdfTd(m.opponent),
                    _pdfTd('$s'),
                    _pdfTd('$r'),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildPdfPlayerStats(AppProvider provider) {
    final players = provider.players;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionTitle('選手別成績'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: _inclPercentage
              ? {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1.2),
                  5: const pw.FlexColumnWidth(1),
                  6: const pw.FlexColumnWidth(1),
                  7: const pw.FlexColumnWidth(1.2),
                  8: const pw.FlexColumnWidth(1.2),
                }
              : {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1.2),
                  5: const pw.FlexColumnWidth(1),
                  6: const pw.FlexColumnWidth(1),
                },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.red900),
              children: [
                _pdfTh('選手名'), _pdfTh('チーム'),
                _pdfTh('エース'), _pdfTh('崩し'), _pdfTh('入っただけ'), _pdfTh('ミス'), _pdfTh('合計'),
                if (_inclPercentage) _pdfTh('エース率'),
                if (_inclPercentage) _pdfTh('ミス率'),
              ],
            ),
            ...players.map((p) {
              final s = provider.getServeStatsByPlayer(p.id);
              final total = s.values.fold(0, (a, b) => a + b);
              final ace = s[ServeResult.ace] ?? 0;
              final under = s[ServeResult.under] ?? 0;
              final justIn = s[ServeResult.justIn] ?? 0;
              final miss = s[ServeResult.miss] ?? 0;
              final aceRate = total > 0 ? '${(ace / total * 100).toStringAsFixed(1)}%' : '-';
              final missRate = total > 0 ? '${(miss / total * 100).toStringAsFixed(1)}%' : '-';
              return pw.TableRow(
                children: [
                  _pdfTd(p.name), _pdfTd(p.team),
                  _pdfTd('$ace'), _pdfTd('$under'), _pdfTd('$justIn'), _pdfTd('$miss'), _pdfTd('$total'),
                  if (_inclPercentage) _pdfTd(aceRate),
                  if (_inclPercentage) _pdfTd(missRate),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfServeRanking(AppProvider provider) {
    final players = provider.players;
    final stats = players.map((p) {
      final s = provider.getServeStatsByPlayer(p.id);
      final total = s.values.fold(0, (a, b) => a + b);
      final ace = s[ServeResult.ace] ?? 0;
      final miss = s[ServeResult.miss] ?? 0;
      final aceRate = total > 0 ? ace / total * 100 : 0.0;
      final missRate = total > 0 ? miss / total * 100 : 0.0;
      return {'player': p, 'total': total, 'aceRate': aceRate, 'missRate': missRate};
    }).where((s) => (s['total'] as int) > 0).toList();

    stats.sort((a, b) => (b['aceRate'] as double).compareTo(a['aceRate'] as double));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionTitle('サーブランキング（エース率順）'),
        pw.SizedBox(height: 8),
        if (stats.isEmpty)
          pw.Text('サーブデータなし', style: const pw.TextStyle(color: PdfColors.grey))
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red900),
                children: [_pdfTh('順位'), _pdfTh('選手名'), _pdfTh('サーブ数'), _pdfTh('エース率'), _pdfTh('ミス率')],
              ),
              ...stats.asMap().entries.map((e) {
                final idx = e.key;
                final s = e.value;
                final p = s['player'] as dynamic;
                return pw.TableRow(
                  decoration: idx == 0 ? const pw.BoxDecoration(color: PdfColors.amber50) : null,
                  children: [
                    _pdfTd('${idx + 1}位'), _pdfTd(p.name),
                    _pdfTd('${s['total']}本'),
                    _pdfTd('${(s['aceRate'] as double).toStringAsFixed(1)}%'),
                    _pdfTd('${(s['missRate'] as double).toStringAsFixed(1)}%'),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildPdfReceiveRanking(AppProvider provider) {
    final players = provider.players;
    final stats = players.map((p) {
      final s = provider.getReceiveStatsByPlayer(p.id);
      final total = s.values.fold(0, (a, b) => a + b);
      final over = s[ReceiveResult.over] ?? 0;
      final miss = s[ReceiveResult.miss] ?? 0;
      final overRate = total > 0 ? over / total * 100 : 0.0;
      final missRate = total > 0 ? miss / total * 100 : 0.0;
      return {'player': p, 'total': total, 'overRate': overRate, 'missRate': missRate};
    }).where((s) => (s['total'] as int) > 0).toList();

    stats.sort((a, b) => (b['overRate'] as double).compareTo(a['overRate'] as double));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionTitle('レシーブランキング（オーバー率順）'),
        pw.SizedBox(height: 8),
        if (stats.isEmpty)
          pw.Text('レシーブデータなし', style: const pw.TextStyle(color: PdfColors.grey))
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red900),
                children: [_pdfTh('順位'), _pdfTh('選手名'), _pdfTh('レシーブ数'), _pdfTh('オーバー率'), _pdfTh('ミス率')],
              ),
              ...stats.asMap().entries.map((e) {
                final idx = e.key;
                final s = e.value;
                final p = s['player'] as dynamic;
                return pw.TableRow(
                  decoration: idx == 0 ? const pw.BoxDecoration(color: PdfColors.amber50) : null,
                  children: [
                    _pdfTd('${idx + 1}位'), _pdfTd(p.name),
                    _pdfTd('${s['total']}本'),
                    _pdfTd('${(s['overRate'] as double).toStringAsFixed(1)}%'),
                    _pdfTd('${(s['missRate'] as double).toStringAsFixed(1)}%'),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildPdfTeamComparison(AppProvider provider) {
    final teamA = provider.teamAPlayers;
    final teamB = provider.teamBPlayers;

    int sumServe(List players) {
      return players.fold(0, (sum, p) {
        final s = provider.getServeStatsByPlayer(p.id);
        return sum + s.values.fold(0, (a, b) => a + b);
      });
    }

    int sumAce(List players) {
      return players.fold(0, (sum, p) {
        final s = provider.getServeStatsByPlayer(p.id);
        return sum + (s[ServeResult.ace] ?? 0);
      });
    }

    int sumMiss(List players) {
      return players.fold(0, (sum, p) {
        final s = provider.getServeStatsByPlayer(p.id);
        return sum + (s[ServeResult.miss] ?? 0);
      });
    }

    final aTotal = sumServe(teamA);
    final bTotal = sumServe(teamB);
    final aAce = aTotal > 0 ? sumAce(teamA) / aTotal * 100 : 0.0;
    final bAce = bTotal > 0 ? sumAce(teamB) / bTotal * 100 : 0.0;
    final aMiss = aTotal > 0 ? sumMiss(teamA) / aTotal * 100 : 0.0;
    final bMiss = bTotal > 0 ? sumMiss(teamB) / bTotal * 100 : 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionTitle('A/Bチーム比較'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.red900),
              children: [_pdfTh(''), _pdfTh('Aチーム'), _pdfTh('Bチーム')],
            ),
            pw.TableRow(children: [_pdfTd('サーブ総数'), _pdfTd('$aTotal'), _pdfTd('$bTotal')]),
            pw.TableRow(children: [_pdfTd('エース率'), _pdfTd('${aAce.toStringAsFixed(1)}%'), _pdfTd('${bAce.toStringAsFixed(1)}%')]),
            pw.TableRow(children: [_pdfTd('ミス率'), _pdfTd('${aMiss.toStringAsFixed(1)}%'), _pdfTd('${bMiss.toStringAsFixed(1)}%')]),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const pw.BoxDecoration(
        color: PdfColors.red50,
        border: pw.Border(left: pw.BorderSide(color: PdfColors.red800, width: 3)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.red900),
      ),
    );
  }

  pw.Widget _pdfTh(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfTd(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}
