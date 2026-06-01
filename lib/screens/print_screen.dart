import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/player.dart';
import '../models/serve_record.dart';
import '../utils/app_theme.dart';

class PrintScreen extends StatefulWidget {
  const PrintScreen({super.key});

  @override
  State<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends State<PrintScreen> {
  // ── 出力項目フラグ ──
  bool _inclPlayerStats    = true;   // 選手別成績（全体集計表）
  bool _inclServeRanking   = true;   // サーブランキング
  bool _inclReceiveRanking = true;   // レシーブランキング
  bool _inclPercentage     = true;   // 割合（%）表示
  bool _inclPlayerReport   = false;  // 選手個別結果表（1ページ/選手）
  bool _inclAiComment      = false;  // AI講評

  // ── 選手フィルター ──
  String _teamFilter = 'ALL';      // 'ALL' / 'A' / 'B'
  Set<String>? _selectedPlayerIds; // null=全員

  // ── 期間フィルター ──
  // 0=全期間, 1=今月, 2=カスタム
  int _periodMode = 0;
  DateTime? _customFrom;
  DateTime? _customTo;

  bool _isGenerating = false;

  // ────────────────────────────────────────────
  // 期間フィルター from/to の計算
  // ────────────────────────────────────────────
  DateTime? get _periodFrom {
    switch (_periodMode) {
      case 1: // 今月
        final now = DateTime.now();
        return DateTime(now.year, now.month, 1);
      case 2: // カスタム
        return _customFrom;
      default:
        return null; // 全期間
    }
  }

  DateTime? get _periodTo {
    switch (_periodMode) {
      case 1: // 今月（翌月1日 = 今月末まで）
        final now = DateTime.now();
        return DateTime(now.year, now.month + 1, 1);
      case 2:
        return _customTo?.add(const Duration(days: 1));
      default:
        return null;
    }
  }

  String get _periodLabel {
    switch (_periodMode) {
      case 1:
        return '今月';
      case 2:
        if (_customFrom != null && _customTo != null) {
          return '${DateFormat('M/d').format(_customFrom!)}〜${DateFormat('M/d').format(_customTo!)}';
        } else if (_customFrom != null) {
          return '${DateFormat('M/d').format(_customFrom!)}〜';
        }
        return 'カスタム';
      default:
        return '全期間';
    }
  }

  // ────────────────────────────────────────────
  // 選手フィルター
  // ────────────────────────────────────────────
  void _onTeamChanged(String team) {
    setState(() {
      _teamFilter = team;
      _selectedPlayerIds = null;
    });
  }

  List<Player> _getFilteredPlayers(AppProvider provider) {
    List<Player> base;
    switch (_teamFilter) {
      case 'A':
        base = provider.teamAPlayers;
      case 'B':
        base = provider.teamBPlayers;
      default:
        base = provider.players;
    }
    if (_selectedPlayerIds != null && _selectedPlayerIds!.isNotEmpty) {
      return base.where((p) => _selectedPlayerIds!.contains(p.id)).toList();
    }
    return base;
  }

  // ────────────────────────────────────────────
  // 選手選択ボトムシート
  // ────────────────────────────────────────────
  void _showPlayerSelectSheet(BuildContext ctx, AppProvider provider) {
    final List<Player> teamPlayers = _teamFilter == 'A'
        ? provider.teamAPlayers
        : _teamFilter == 'B'
            ? provider.teamBPlayers
            : provider.players;
    Set<String> current =
        _selectedPlayerIds ?? teamPlayers.map((p) => p.id).toSet();
    final teamColor = _teamFilter == 'A'
        ? AppTheme.primaryRed
        : _teamFilter == 'B'
            ? Colors.blue
            : AppTheme.gold;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSt) {
          final maxH = MediaQuery.of(sheetCtx).size.height * 0.85;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                  child: Row(
                    children: [
                      Icon(Icons.people, color: teamColor, size: 18),
                      const SizedBox(width: 8),
                      const Text('PDF出力対象の選手を選択',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setSt(() {
                          current = current.length == teamPlayers.length
                              ? {}
                              : teamPlayers.map((p) => p.id).toSet();
                        }),
                        child: Text(
                            current.length == teamPlayers.length
                                ? '全解除'
                                : '全選択',
                            style:
                                TextStyle(color: teamColor, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text('選択した選手だけがPDFに出力されます',
                      style:
                          TextStyle(color: AppTheme.grey, fontSize: 12)),
                ),
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: teamPlayers.length,
                    itemBuilder: (_, i) {
                      final p = teamPlayers[i];
                      final isSel = current.contains(p.id);
                      return GestureDetector(
                        onTap: () => setSt(() {
                          if (isSel) {
                            current = Set.from(current)..remove(p.id);
                          } else {
                            current = Set.from(current)..add(p.id);
                          }
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSel
                                ? teamColor.withValues(alpha: 0.12)
                                : AppTheme.cardBg2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isSel
                                    ? teamColor.withValues(alpha: 0.6)
                                    : const Color(0xFF444444)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? teamColor.withValues(alpha: 0.25)
                                      : const Color(0xFF2A2A2A),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: isSel
                                          ? teamColor
                                          : const Color(0xFF555555)),
                                ),
                                child: Center(
                                  child: Text(
                                    p.number.isNotEmpty ? p.number : '?',
                                    style: TextStyle(
                                        color:
                                            isSel ? teamColor : AppTheme.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(p.name,
                                    style: TextStyle(
                                        color: isSel
                                            ? Colors.white
                                            : AppTheme.lightGrey,
                                        fontSize: 14,
                                        fontWeight: isSel
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ),
                              Icon(
                                isSel
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isSel ? teamColor : AppTheme.grey,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16,
                      MediaQuery.of(sheetCtx).padding.bottom + 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teamColor,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedPlayerIds =
                              current.length == teamPlayers.length
                                  ? null
                                  : current;
                        });
                        Navigator.pop(sheetCtx);
                      },
                      child: Text(
                        current.isEmpty
                            ? '選手を選択してください'
                            : '${current.length}名をPDFに出力',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ────────────────────────────────────────────
  // 期間選択ダイアログ（カスタム）
  // ────────────────────────────────────────────
  Future<void> _pickCustomDateRange(BuildContext context) async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: (_customFrom != null && _customTo != null)
          ? DateTimeRange(start: _customFrom!, end: _customTo!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now()),
      // locale 指定を外す（Webでは白画面バグの原因になる）
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primaryRed,
            onPrimary: Colors.white,
            surface: Color(0xFF1E1E1E),
            onSurface: Colors.white,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF1E1E1E),
          ),
        ),
        child: child!,
      ),
    );
    if (result != null) {
      setState(() {
        _customFrom = result.start;
        _customTo = result.end;
        _periodMode = 2;
      });
    }
  }

  // ────────────────────────────────────────────
  // build
  // ────────────────────────────────────────────
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
            Text('印刷・PDF出力',
                style: TextStyle(color: AppTheme.gold, fontSize: 18)),
          ],
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) => Column(
          children: [
            // ── 選手フィルターバー ──
            _buildFilterBar(context, provider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── 期間フィルター ──
                  _buildSectionHeader('集計期間', Icons.date_range),
                  const SizedBox(height: 10),
                  _buildPeriodSelector(context),
                  const SizedBox(height: 20),

                  // ── 出力内容 ──
                  _buildSectionHeader('出力内容を選択', Icons.checklist),
                  const SizedBox(height: 12),
                  _buildCheckTile(
                    '選手別成績',
                    '選手ごとの全集計データ（サーブ成績一覧）',
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
                    '選手個別結果表',
                    '1選手につきA4 1枚：サーブ・レシーブ成績＋ランキング順位＋AI講評',
                    Icons.assignment_ind,
                    _inclPlayerReport,
                    (v) => setState(() => _inclPlayerReport = v),
                  ),
                  _buildCheckTile(
                    'AI講評（全体サマリー）',
                    '選手ごとのAI自動分析コメントを末尾にまとめて出力',
                    Icons.psychology,
                    _inclAiComment,
                    (v) => setState(() => _inclAiComment = v),
                  ),
                  const SizedBox(height: 20),

                  // ── 出力形式 ──
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
                      const SizedBox(height: 8),
                      _infoRow(Icons.assignment_ind, '選手個別表はA4 1枚/選手で出力'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),

            // ── 生成ボタン ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.cardBg,
                border: Border(top: BorderSide(color: Color(0xFF333333))),
              ),
              child: SizedBox(
                width: double.infinity,
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
                  onPressed: _isGenerating
                      ? null
                      : () => _generateAndPrint(context, provider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  // 期間セレクター UI
  // ────────────────────────────────────────────
  Widget _buildPeriodSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _periodChip('全期間', 0),
              const SizedBox(width: 8),
              _periodChip('今月', 1),
              const SizedBox(width: 8),
              _periodChip('カスタム', 2, onTap: () async {
                await _pickCustomDateRange(context);
              }),
            ],
          ),
          if (_periodMode != 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 13, color: AppTheme.grey),
                const SizedBox(width: 4),
                Text(
                  '集計対象: $_periodLabel',
                  style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _periodChip(String label, int mode, {VoidCallback? onTap}) {
    final isSel = _periodMode == mode;
    return GestureDetector(
      onTap: onTap ??
          () {
            setState(() => _periodMode = mode);
          },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSel
              ? AppTheme.primaryRed.withValues(alpha: 0.2)
              : AppTheme.cardBg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSel ? AppTheme.primaryRed : const Color(0xFF444444)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: isSel ? AppTheme.primaryRed : AppTheme.grey,
              fontSize: 12,
              fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  // フィルターバー
  // ────────────────────────────────────────────
  Widget _buildFilterBar(BuildContext ctx, AppProvider provider) {
    final hasTeam = _teamFilter != 'ALL';
    final teamColor = _teamFilter == 'A'
        ? AppTheme.primaryRed
        : _teamFilter == 'B'
            ? Colors.blue
            : AppTheme.gold;
    final cnt = _getFilteredPlayers(provider).length;
    return Container(
      color: AppTheme.cardBg,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _teamChip('全体', 'ALL'),
              const SizedBox(width: 6),
              _teamChip('Aチーム', 'A'),
              const SizedBox(width: 6),
              _teamChip('Bチーム', 'B'),
              if (hasTeam) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showPlayerSelectSheet(ctx, provider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedPlayerIds != null
                          ? teamColor.withValues(alpha: 0.15)
                          : AppTheme.cardBg2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _selectedPlayerIds != null
                              ? teamColor
                              : const Color(0xFF444444)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search,
                            size: 13,
                            color: _selectedPlayerIds != null
                                ? teamColor
                                : AppTheme.grey),
                        const SizedBox(width: 4),
                        Text(
                          _selectedPlayerIds != null
                              ? '${_selectedPlayerIds!.length}名選択中'
                              : '選手を選ぶ',
                          style: TextStyle(
                            color: _selectedPlayerIds != null
                                ? teamColor
                                : AppTheme.grey,
                            fontSize: 12,
                            fontWeight: _selectedPlayerIds != null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text('PDF出力対象: $cnt名',
              style: TextStyle(
                  color: teamColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _teamChip(String label, String value) {
    final isSel = _teamFilter == value;
    final color = value == 'A'
        ? AppTheme.primaryRed
        : value == 'B'
            ? Colors.blue
            : AppTheme.gold;
    return GestureDetector(
      onTap: () => _onTeamChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? color.withValues(alpha: 0.2) : AppTheme.cardBg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSel ? color : const Color(0xFF444444)),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSel ? color : AppTheme.grey,
                fontSize: 12,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  // ────────────────────────────────────────────
  // セクションヘッダー
  // ────────────────────────────────────────────
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
              letterSpacing: 1,
            )),
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
                fontWeight: value ? FontWeight.bold : FontWeight.normal,
                fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppTheme.grey, fontSize: 11)),
        secondary: Icon(icon,
            color: value ? AppTheme.primaryRed : AppTheme.grey, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.gold, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style:
                  const TextStyle(color: AppTheme.lightGrey, fontSize: 13)),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────
  // PDF生成 & 印刷
  // ────────────────────────────────────────────
  Future<void> _generateAndPrint(
      BuildContext context, AppProvider provider) async {
    setState(() => _isGenerating = true);
    final messenger = ScaffoldMessenger.of(context);
    String? errorMsg;
    try {
      final pdf = await _buildPdf(provider);
      await Printing.layoutPdf(
        onLayout: (_) => pdf.save(),
        name:
            '藤橋JVC_バレーボール分析_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      errorMsg = 'PDF生成エラー: $e';
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        if (errorMsg != null) {
          messenger.showSnackBar(
            SnackBar(
                content: Text(errorMsg),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ────────────────────────────────────────────
  // PDFドキュメント構築
  // ────────────────────────────────────────────
  Future<pw.Document> _buildPdf(AppProvider provider) async {
    final filteredPlayers = _getFilteredPlayers(provider);
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy年M月d日').format(now);

    // 期間
    final from = _periodFrom;
    final to = _periodTo;

    // 日本語フォント
    final pw.Font regularFont;
    final pw.Font boldFont;
    try {
      regularFont = await PdfGoogleFonts.notoSansJPRegular();
      boldFont = await PdfGoogleFonts.notoSansJPBold();
    } catch (e) {
      throw Exception(
          '日本語フォントの読み込みに失敗しました。\nインターネット接続を確認してください。\n詳細: $e');
    }
    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
      italic: regularFont,
      boldItalic: boldFont,
    );

    // ── ページ1: 全体サマリー（選択項目に応じて）──
    final bool hasSummaryContent = _inclPlayerStats ||
        _inclServeRanking ||
        _inclReceiveRanking ||
        _inclAiComment;

    if (hasSummaryContent) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          margin: const pw.EdgeInsets.all(30),
          header: (ctx) => _buildPdfHeader(dateStr, _periodLabel),
          footer: (ctx) => _buildPdfFooter(ctx),
          build: (ctx) {
            final List<pw.Widget> content = [];

            if (_inclPlayerStats) {
              content.add(
                  _buildPdfPlayerStats(provider, filteredPlayers, from, to));
              content.add(pw.SizedBox(height: 16));
            }

            if (_inclServeRanking) {
              content.add(_buildPdfServeRanking(
                  provider, filteredPlayers, from, to));
              content.add(pw.SizedBox(height: 16));
            }

            if (_inclReceiveRanking) {
              content.add(_buildPdfReceiveRanking(
                  provider, filteredPlayers, from, to));
              content.add(pw.SizedBox(height: 16));
            }

            // ── AI講評（全体サマリー末尾） ──
            if (_inclAiComment) {
              content.add(_buildPdfAiCommentSection(
                  provider, filteredPlayers, from, to));
              content.add(pw.SizedBox(height: 16));
            }

            if (content.isEmpty) {
              content.add(pw.Text('出力項目が選択されていません'));
            }
            return content;
          },
        ),
      );
    }

    // ── 選手個別結果表（1選手 = 1 MultiPage）──
    if (_inclPlayerReport) {
      for (final player in filteredPlayers) {
        final aiText = _inclAiComment || _inclPlayerReport
            ? _generateAiComment(provider, player, from, to)
            : null;
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            theme: theme,
            margin: const pw.EdgeInsets.all(30),
            header: (ctx) => _buildPdfHeader(dateStr, _periodLabel),
            footer: (ctx) => _buildPdfFooter(ctx),
            build: (ctx) => _buildPdfPlayerReport(
                provider, player, filteredPlayers, from, to, aiText),
          ),
        );
      }
    }

    return pdf;
  }

  // ────────────────────────────────────────────
  // PDF共通ヘッダー・フッター
  // ────────────────────────────────────────────
  pw.Widget _buildPdfHeader(String dateStr, String periodLabel) {
    return pw.Container(
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
              pw.Text(
                '藤橋JVC男子 バレーボール分析レポート',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red900),
              ),
              pw.Text(
                'この一本、この一点　【集計期間: $periodLabel】',
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.amber800),
              ),
            ],
          ),
          pw.Text(dateStr,
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border:
            pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('藤橋JVC男子 バレーボール分析アプリ',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey)),
          pw.Text('${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey)),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // 選手別成績（全体集計表）
  // ────────────────────────────────────────────
  pw.Widget _buildPdfPlayerStats(AppProvider provider, List<Player> players,
      DateTime? from, DateTime? to) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionTitle('選手別成績（サーブ）'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.red900),
              children: [
                _pdfTh('選手名'),
                _pdfTh('チーム'),
                _pdfTh('エース'),
                _pdfTh('崩し'),
                _pdfTh('入っただけ'),
                _pdfTh('ミス'),
                _pdfTh('合計'),
                if (_inclPercentage) _pdfTh('エース率'),
                if (_inclPercentage) _pdfTh('ミス率'),
              ],
            ),
            ...players.map((p) {
              final s = provider.getServeStatsByPlayer(p.id,
                  from: from, to: to);
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
                _pdfTd(p.name),
                _pdfTd(p.team),
                _pdfTd('$ace'),
                _pdfTd('$under'),
                _pdfTd('$justIn'),
                _pdfTd('$miss'),
                _pdfTd('$total'),
                if (_inclPercentage) _pdfTd('$aceRate%'),
                if (_inclPercentage) _pdfTd('$missRate%'),
              ]);
            }),
          ],
        ),
        pw.SizedBox(height: 12),
        _pdfSectionTitle('選手別成績（レシーブ）'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.red900),
              children: [
                _pdfTh('選手名'),
                _pdfTh('チーム'),
                _pdfTh('オーバー'),
                _pdfTh('アンダー'),
                _pdfTh('ダイレクト\n二段'),
                _pdfTh('ミス'),
                _pdfTh('合計'),
                if (_inclPercentage) _pdfTh('オーバー率'),
                if (_inclPercentage) _pdfTh('ミス率'),
              ],
            ),
            ...players.map((p) {
              final r = provider.getReceiveStatsByPlayer(p.id,
                  from: from, to: to);
              final total = r.values.fold(0, (a, b) => a + b);
              final over = r[ReceiveResult.over] ?? 0;
              final under = r[ReceiveResult.under] ?? 0;
              final direct = r[ReceiveResult.direct] ?? 0;
              final miss = r[ReceiveResult.miss] ?? 0;
              final overRate = total > 0
                  ? (over / total * 100).toStringAsFixed(1)
                  : '-';
              final missRate = total > 0
                  ? (miss / total * 100).toStringAsFixed(1)
                  : '-';
              return pw.TableRow(children: [
                _pdfTd(p.name),
                _pdfTd(p.team),
                _pdfTd('$over'),
                _pdfTd('$under'),
                _pdfTd('$direct'),
                _pdfTd('$miss'),
                _pdfTd('$total'),
                if (_inclPercentage) _pdfTd('$overRate%'),
                if (_inclPercentage) _pdfTd('$missRate%'),
              ]);
            }),
          ],
        ),
      ],
    );
  }

  // ────────────────────────────────────────────
  // サーブランキング
  // ────────────────────────────────────────────
  pw.Widget _buildPdfServeRanking(AppProvider provider, List<Player> players,
      DateTime? from, DateTime? to) {
    final stats = players.map((p) {
      final s = provider.getServeStatsByPlayer(p.id, from: from, to: to);
      final total = s.values.fold(0, (a, b) => a + b);
      final ace = s[ServeResult.ace] ?? 0;
      final miss = s[ServeResult.miss] ?? 0;
      final aceRate = total > 0 ? ace / total * 100 : 0.0;
      final missRate = total > 0 ? miss / total * 100 : 0.0;
      return {
        'player': p,
        'total': total,
        'aceRate': aceRate,
        'missRate': missRate
      };
    }).where((s) => (s['total'] as int) > 0).toList();

    stats.sort((a, b) =>
        (b['aceRate'] as double).compareTo(a['aceRate'] as double));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionTitle('サーブランキング（エース率順）'),
        pw.SizedBox(height: 8),
        if (stats.isEmpty)
          pw.Text('データなし',
              style: const pw.TextStyle(color: PdfColors.grey))
        else
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.red900),
                children: [
                  _pdfTh('順位'),
                  _pdfTh('選手名'),
                  _pdfTh('サーブ数'),
                  _pdfTh('エース率'),
                  _pdfTh('ミス率')
                ],
              ),
              ...stats.asMap().entries.map((e) {
                final idx = e.key;
                final s = e.value;
                final p = s['player'] as Player;
                return pw.TableRow(
                  decoration: idx == 0
                      ? const pw.BoxDecoration(
                          color: PdfColors.amber50)
                      : null,
                  children: [
                    _pdfTd('${idx + 1}位'),
                    _pdfTd(p.name),
                    _pdfTd('${s['total']}本'),
                    _pdfTd(
                        '${(s['aceRate'] as double).toStringAsFixed(1)}%'),
                    _pdfTd(
                        '${(s['missRate'] as double).toStringAsFixed(1)}%'),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  // ────────────────────────────────────────────
  // レシーブランキング
  // ────────────────────────────────────────────
  pw.Widget _buildPdfReceiveRanking(AppProvider provider,
      List<Player> players, DateTime? from, DateTime? to) {
    final stats = players.map((p) {
      final s =
          provider.getReceiveStatsByPlayer(p.id, from: from, to: to);
      final total = s.values.fold(0, (a, b) => a + b);
      final over = s[ReceiveResult.over] ?? 0;
      final miss = s[ReceiveResult.miss] ?? 0;
      final overRate = total > 0 ? over / total * 100 : 0.0;
      final missRate = total > 0 ? miss / total * 100 : 0.0;
      return {
        'player': p,
        'total': total,
        'overRate': overRate,
        'missRate': missRate
      };
    }).where((s) => (s['total'] as int) > 0).toList();

    stats.sort((a, b) =>
        (b['overRate'] as double).compareTo(a['overRate'] as double));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionTitle('レシーブランキング（オーバー率順）'),
        pw.SizedBox(height: 8),
        if (stats.isEmpty)
          pw.Text('データなし',
              style: const pw.TextStyle(color: PdfColors.grey))
        else
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.red900),
                children: [
                  _pdfTh('順位'),
                  _pdfTh('選手名'),
                  _pdfTh('レシーブ数'),
                  _pdfTh('オーバー率'),
                  _pdfTh('ミス率')
                ],
              ),
              ...stats.asMap().entries.map((e) {
                final idx = e.key;
                final s = e.value;
                final p = s['player'] as Player;
                return pw.TableRow(
                  decoration: idx == 0
                      ? const pw.BoxDecoration(
                          color: PdfColors.amber50)
                      : null,
                  children: [
                    _pdfTd('${idx + 1}位'),
                    _pdfTd(p.name),
                    _pdfTd('${s['total']}本'),
                    _pdfTd(
                        '${(s['overRate'] as double).toStringAsFixed(1)}%'),
                    _pdfTd(
                        '${(s['missRate'] as double).toStringAsFixed(1)}%'),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  // ────────────────────────────────────────────
  // AI講評セクション（全体サマリー末尾用）
  // ────────────────────────────────────────────
  pw.Widget _buildPdfAiCommentSection(AppProvider provider,
      List<Player> players, DateTime? from, DateTime? to) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionTitle('AI講評'),
        pw.SizedBox(height: 8),
        ...players.map((p) {
          final comment = _generateAiComment(provider, p, from, to);
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                  color: PdfColors.grey300, width: 0.5),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${p.number.isNotEmpty ? "#${p.number} " : ""}${p.name}（${p.team}）',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red900),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  comment,
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.black),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ────────────────────────────────────────────
  // 選手個別結果表（A4 1枚/選手）
  // ────────────────────────────────────────────
  List<pw.Widget> _buildPdfPlayerReport(AppProvider provider, Player player,
      List<Player> filteredPlayers, DateTime? from, DateTime? to, String? aiText) {
    final serveStats =
        provider.getServeStatsByPlayer(player.id, from: from, to: to);
    final receiveStats =
        provider.getReceiveStatsByPlayer(player.id, from: from, to: to);

    final sTotal = serveStats.values.fold(0, (a, b) => a + b);
    final rTotal = receiveStats.values.fold(0, (a, b) => a + b);

    final sAce = serveStats[ServeResult.ace] ?? 0;
    final sUnder = serveStats[ServeResult.under] ?? 0;
    final sJustIn = serveStats[ServeResult.justIn] ?? 0;
    final sMiss = serveStats[ServeResult.miss] ?? 0;

    final rOver = receiveStats[ReceiveResult.over] ?? 0;
    final rUnder = receiveStats[ReceiveResult.under] ?? 0;
    final rDirect = receiveStats[ReceiveResult.direct] ?? 0;
    final rMiss = receiveStats[ReceiveResult.miss] ?? 0;

    // サーブランキング（filteredPlayers = PDF出力対象選手のみ）
    final serveRankData = filteredPlayers.map((p) {
      final s = provider.getServeStatsByPlayer(p.id, from: from, to: to);
      final t = s.values.fold(0, (a, b) => a + b);
      final a = s[ServeResult.ace] ?? 0;
      return {'player': p, 'total': t, 'aceRate': t > 0 ? a / t * 100 : 0.0};
    }).where((s) => (s['total'] as int) > 0).toList();
    serveRankData.sort(
        (a, b) => (b['aceRate'] as double).compareTo(a['aceRate'] as double));
    final serveRank = serveRankData
        .indexWhere((s) => (s['player'] as Player).id == player.id);

    // レシーブランキング（filteredPlayers = PDF出力対象選手のみ）
    final receiveRankData = filteredPlayers.map((p) {
      final s =
          provider.getReceiveStatsByPlayer(p.id, from: from, to: to);
      final t = s.values.fold(0, (a, b) => a + b);
      final o = s[ReceiveResult.over] ?? 0;
      return {
        'player': p,
        'total': t,
        'overRate': t > 0 ? o / t * 100 : 0.0
      };
    }).where((s) => (s['total'] as int) > 0).toList();
    receiveRankData.sort((a, b) =>
        (b['overRate'] as double).compareTo(a['overRate'] as double));
    final receiveRank = receiveRankData
        .indexWhere((s) => (s['player'] as Player).id == player.id);

    return [
      // ── 選手名ヘッダー ──
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: const pw.BoxDecoration(
          color: PdfColors.red900,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (player.number.isNotEmpty)
              pw.Container(
                width: 40,
                height: 40,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.amber800,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text(
                    '#${player.number}',
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white),
                  ),
                ),
              ),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(player.name,
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                pw.Text(
                  '${player.team}チーム　個人成績レポート',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.amber100),
                ),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 14),

      // ── サーブ成績表 ──
      _pdfSectionTitle('サーブ成績'),
      pw.SizedBox(height: 6),
      pw.Table(
        border:
            pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.red900),
            children: [
              _pdfTh('エース'),
              _pdfTh('崩し\n(アンダー・二段)'),
              _pdfTh('入っただけ'),
              _pdfTh('ミス'),
              _pdfTh('合計'),
              _pdfTh('エース率'),
              _pdfTh('ミス率'),
            ],
          ),
          pw.TableRow(children: [
            _pdfTd('$sAce'),
            _pdfTd('$sUnder'),
            _pdfTd('$sJustIn'),
            _pdfTd('$sMiss'),
            _pdfTd('$sTotal'),
            _pdfTd(sTotal > 0
                ? '${(sAce / sTotal * 100).toStringAsFixed(1)}%'
                : '-'),
            _pdfTd(sTotal > 0
                ? '${(sMiss / sTotal * 100).toStringAsFixed(1)}%'
                : '-'),
          ]),
        ],
      ),
      pw.SizedBox(height: 12),

      // ── レシーブ成績表 ──
      _pdfSectionTitle('レシーブ成績'),
      pw.SizedBox(height: 6),
      pw.Table(
        border:
            pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.red900),
            children: [
              _pdfTh('オーバー'),
              _pdfTh('アンダー'),
              _pdfTh('ダイレクト\n二段'),
              _pdfTh('ミス'),
              _pdfTh('合計'),
              _pdfTh('オーバー率'),
              _pdfTh('ミス率'),
            ],
          ),
          pw.TableRow(children: [
            _pdfTd('$rOver'),
            _pdfTd('$rUnder'),
            _pdfTd('$rDirect'),
            _pdfTd('$rMiss'),
            _pdfTd('$rTotal'),
            _pdfTd(rTotal > 0
                ? '${(rOver / rTotal * 100).toStringAsFixed(1)}%'
                : '-'),
            _pdfTd(rTotal > 0
                ? '${(rMiss / rTotal * 100).toStringAsFixed(1)}%'
                : '-'),
          ]),
        ],
      ),
      pw.SizedBox(height: 12),

      // ── ランキング（この選手の順位のみ） ──
      _pdfSectionTitle('ランキング'),
      pw.SizedBox(height: 6),
      pw.Row(
        children: [
          // サーブ順位
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                    color: PdfColors.grey300, width: 0.5),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('サーブ（エース率）',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red900)),
                  pw.SizedBox(height: 4),
                  if (serveRank >= 0) ...[
                    pw.Text(
                      '${serveRank + 1}位',
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: serveRank == 0
                              ? PdfColors.amber700
                              : PdfColors.red800),
                    ),
                    pw.Text(
                      '/ ${serveRankData.length}人中',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey),
                    ),
                    pw.Text(
                      'エース率: ${(serveRankData[serveRank]['aceRate'] as double).toStringAsFixed(1)}%',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey700),
                    ),
                  ] else
                    pw.Text('記録なし',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey)),
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          // レシーブ順位
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                    color: PdfColors.grey300, width: 0.5),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('レシーブ（オーバー率）',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red900)),
                  pw.SizedBox(height: 4),
                  if (receiveRank >= 0) ...[
                    pw.Text(
                      '${receiveRank + 1}位',
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: receiveRank == 0
                              ? PdfColors.amber700
                              : PdfColors.red800),
                    ),
                    pw.Text(
                      '/ ${receiveRankData.length}人中',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey),
                    ),
                    pw.Text(
                      'オーバー率: ${(receiveRankData[receiveRank]['overRate'] as double).toStringAsFixed(1)}%',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey700),
                    ),
                  ] else
                    pw.Text('記録なし',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 12),

      // ── AI講評 ──
      if (aiText != null) ...[
        _pdfSectionTitle('AI講評'),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.red50,
            border:
                pw.Border.all(color: PdfColors.red200, width: 0.5),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            aiText,
            style:
                const pw.TextStyle(fontSize: 9, color: PdfColors.black),
          ),
        ),
      ],
    ];
  }

  // ────────────────────────────────────────────
  // AI講評テキスト生成（期間フィルター対応）
  // ────────────────────────────────────────────
  String _generateAiComment(AppProvider provider, Player player,
      DateTime? from, DateTime? to) {
    final serveStats =
        provider.getServeStatsByPlayer(player.id, from: from, to: to);
    final receiveStats =
        provider.getReceiveStatsByPlayer(player.id, from: from, to: to);

    final total = serveStats.values.fold(0, (a, b) => a + b);
    final rTotal = receiveStats.values.fold(0, (a, b) => a + b);

    if (total == 0 && rTotal == 0) {
      return '${player.name}選手のデータがまだありません。試合での記録を蓄積してください。';
    }

    final List<String> comments = [];

    if (total > 0) {
      final aceRate =
          (serveStats[ServeResult.ace] ?? 0) / total * 100;
      final underRate =
          (serveStats[ServeResult.under] ?? 0) / total * 100;
      final missRate =
          (serveStats[ServeResult.miss] ?? 0) / total * 100;
      final efficiency =
          ((serveStats[ServeResult.ace] ?? 0) -
                  (serveStats[ServeResult.miss] ?? 0)) /
              total *
              100;

      if (aceRate >= 20) {
        comments.add(
            '【サーブの特徴】サーブのエース率が${aceRate.toStringAsFixed(1)}%と非常に高く、相手チームにとって大きな脅威になっています。');
      } else if (aceRate >= 10) {
        comments.add(
            '【サーブの特徴】エース率${aceRate.toStringAsFixed(1)}%は安定した水準です。さらなる向上を目指しましょう。');
      } else if (aceRate < 5 && total >= 5) {
        comments.add(
            '【サーブの特徴】エース率${aceRate.toStringAsFixed(1)}%はやや低めです。サーブコースの多様化を練習しましょう。');
      }

      if (underRate >= 35) {
        comments.add(
            '【崩し能力】崩し率${underRate.toStringAsFixed(1)}%と高く、相手の攻撃を制限する効果的なサーブができています。');
      } else if (underRate < 20 && total >= 5) {
        comments.add(
            '【崩し能力】崩し率${underRate.toStringAsFixed(1)}%はまだ改善の余地があります。コースを狙ったサーブを意識してみましょう。');
      }

      if (missRate >= 20) {
        comments.add(
            '【改善ポイント】ミス率が${missRate.toStringAsFixed(1)}%と高めです。強打とコントロールのバランスを見直し、安定性を高めることが優先課題です。');
      } else if (missRate <= 5 && total >= 5) {
        comments.add(
            '【安定性】ミス率${missRate.toStringAsFixed(1)}%と非常に安定したサーブを打てています。この安定性は試合で大きな武器になります。');
      }

      if (efficiency >= 10) {
        comments.add(
            '【サーブ効率】サーブ効率スコアが${efficiency.toStringAsFixed(1)}%と優秀です。チームへの貢献度が高い選手です。');
      } else if (efficiency < 0) {
        comments.add(
            '【サーブ効率】現在サーブ効率がマイナスです。ミスを減らすことを第一に意識しましょう。');
      }

      final suggestions = <String>[];
      if (missRate >= 15) suggestions.add('入れることを優先した基礎練習');
      if (aceRate < 8) {
        suggestions.add('コース狙いの練習（ライン際・ショートサーブ）');
      }
      if (underRate < 25) {
        suggestions.add('相手レシーバーを動かすサーブコース練習');
      }
      if (suggestions.isNotEmpty) {
        comments.add(
            '【練習提案】${suggestions.join('、')}を重点的に行うことをお勧めします。');
      }
    }

    if (rTotal > 0) {
      final overRate =
          (receiveStats[ReceiveResult.over] ?? 0) / rTotal * 100;
      final missRate =
          (receiveStats[ReceiveResult.miss] ?? 0) / rTotal * 100;

      if (overRate >= 50) {
        comments.add(
            '【レシーブ安定性】オーバーパス率${overRate.toStringAsFixed(1)}%と安定したレシーブができています。攻撃につながる質の高いパスです。');
      } else if (overRate >= 30) {
        comments.add(
            '【レシーブ安定性】オーバーパス率${overRate.toStringAsFixed(1)}%は平均的な水準です。さらに向上できるよう練習を続けましょう。');
      }

      if (missRate >= 20) {
        comments.add(
            '【レシーブ改善】レシーブミス率が${missRate.toStringAsFixed(1)}%です。落下点への移動を素早く行う練習が効果的です。');
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

  // ────────────────────────────────────────────
  // PDF共通ウィジェット
  // ────────────────────────────────────────────
  pw.Widget _pdfSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const pw.BoxDecoration(
        color: PdfColors.red50,
        border:
            pw.Border(left: pw.BorderSide(color: PdfColors.red800, width: 3)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.red900),
      ),
    );
  }

  pw.Widget _pdfTh(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white),
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
