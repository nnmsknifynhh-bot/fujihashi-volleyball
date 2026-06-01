import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/match.dart';
import '../utils/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Color> _opponentColors = [
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.cyan,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Column(
        children: [
          _buildTeamHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMatchList(context, 'A'),
                _buildMatchList(context, 'B'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMatchDialog(context),
        backgroundColor: AppTheme.primaryRed,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('試合を追加', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTeamHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
        border: Border(bottom: BorderSide(color: AppTheme.gold, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '藤橋JVC男子',
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 3,
                height: 24,
                color: AppTheme.primaryRed,
                margin: const EdgeInsets.only(right: 8),
              ),
              const Text(
                'ホーム',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateFormat('yyyy/MM/dd').format(DateTime.now()),
                  style: const TextStyle(color: AppTheme.gold, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.cardBg,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_volleyball, size: 16),
                SizedBox(width: 6),
                Text('Aチーム', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_volleyball, size: 16),
                SizedBox(width: 6),
                Text('Bチーム', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
        labelColor: AppTheme.gold,
        unselectedLabelColor: AppTheme.grey,
        indicatorColor: AppTheme.primaryRed,
        indicatorWeight: 3,
      ),
    );
  }

  Widget _buildMatchList(BuildContext context, String team) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final today = DateTime.now();
        final todayMatches = provider.matches
            .where((m) =>
                m.team == team &&
                m.date.year == today.year &&
                m.date.month == today.month &&
                m.date.day == today.day)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final pastMatches = provider.matches
            .where((m) =>
                m.team == team &&
                !(m.date.year == today.year &&
                    m.date.month == today.month &&
                    m.date.day == today.day))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (todayMatches.isNotEmpty) ...[
              _sectionHeader('今日の試合', Icons.today, AppTheme.gold),
              const SizedBox(height: 8),
              ...todayMatches.map((m) => _buildMatchCard(context, m, provider, isToday: true)),
              const SizedBox(height: 16),
            ],
            _sectionHeader('過去の試合', Icons.history, AppTheme.grey),
            const SizedBox(height: 8),
            if (pastMatches.isEmpty)
              _emptyState('まだ試合がありません')
            else
              ...pastMatches.map((m) => _buildMatchCard(context, m, provider, isToday: false)),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: color.withValues(alpha: 0.3))),
      ],
    );
  }

  Widget _buildMatchCard(BuildContext context, Match match, AppProvider provider, {required bool isToday}) {
    final opponentColor = Color(match.opponentColorValue);
    final isSelected = provider.currentMatchId == match.id;
    final serveCount = provider.getServeRecordsByMatch(match.id).length;
    final receiveCount = provider.getReceiveRecordsByMatch(match.id).length;

    return GestureDetector(
      onTap: () {
        provider.setCurrentMatch(match.id);
        provider.setCurrentTeam(match.team);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${match.team}チーム「${match.opponent}」を選択',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2A2A2A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.6)),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.gold : opponentColor.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.gold.withValues(alpha: 0.2), blurRadius: 8)]
              : null,
        ),
        child: Column(
          children: [
            // カラーバー
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: opponentColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // チーム表示
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: match.team == 'A'
                          ? AppTheme.primaryRed.withValues(alpha: 0.2)
                          : Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: match.team == 'A' ? AppTheme.primaryRed : Colors.blue,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        match.team,
                        style: TextStyle(
                          color: match.team == 'A' ? AppTheme.primaryRed : Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'vs ${match.opponent}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.gold,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '入力中',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('M/d (E)', 'ja').format(match.date) +
                              (match.matchName.isNotEmpty ? ' ${match.matchName}' : ''),
                          style: const TextStyle(color: AppTheme.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statBadge('S', serveCount, AppTheme.primaryRed),
                      const SizedBox(height: 4),
                      _statBadge('R', receiveCount, Colors.blue),
                    ],
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    color: AppTheme.cardBg2,
                    icon: const Icon(Icons.more_vert, color: AppTheme.grey, size: 20),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirm = await _confirmDelete(context);
                        if (confirm == true) {
                          await provider.deleteMatch(match.id);
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: AppTheme.primaryRed, size: 16),
                            SizedBox(width: 8),
                            Text('削除', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── セットスコアエリア ──
            _buildScoreArea(context, match, provider, opponentColor),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // セットスコア表示・入力エリア
  // ─────────────────────────────────────────
  Widget _buildScoreArea(
    BuildContext context,
    Match match,
    AppProvider provider,
    Color opponentColor,
  ) {
    final ourWon = match.ourWonSets;
    final theirWon = match.theirWonSets;
    final played = match.playedSets;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(
          top: BorderSide(color: opponentColor.withValues(alpha: 0.3)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー行
          Row(
            children: [
              const Icon(Icons.scoreboard, color: AppTheme.gold, size: 14),
              const SizedBox(width: 5),
              const Text(
                'セットスコア',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (played > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: ourWon > theirWon
                        ? AppTheme.primaryRed.withValues(alpha: 0.2)
                        : AppTheme.cardBg2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ourWon > theirWon
                          ? AppTheme.primaryRed.withValues(alpha: 0.6)
                          : const Color(0xFF444444),
                    ),
                  ),
                  child: Text(
                    '藤橋 $ourWon - $theirWon ${match.opponent}',
                    style: TextStyle(
                      color: ourWon > theirWon
                          ? AppTheme.primaryRed
                          : AppTheme.lightGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showScoreInputDialog(context, match, provider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppTheme.primaryRed.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, color: AppTheme.primaryRed, size: 12),
                      SizedBox(width: 4),
                      Text('スコア入力',
                          style: TextStyle(
                            color: AppTheme.primaryRed,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // セットカード一覧（横スクロール）
          if (played == 0)
            const Text('まだスコアが入力されていません',
                style: TextStyle(color: AppTheme.grey, fontSize: 11))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: match.sets
                    .asMap()
                    .entries
                    .where((e) => e.value.isPlayed)
                    .map((e) {
                  final i = e.key;
                  final s = e.value;
                  final weWon = s.isOurWin;
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 54,
                    decoration: BoxDecoration(
                      color: weWon
                          ? AppTheme.primaryRed.withValues(alpha: 0.15)
                          : AppTheme.cardBg2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: weWon
                            ? AppTheme.primaryRed.withValues(alpha: 0.6)
                            : const Color(0xFF444444),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                    child: Column(
                      children: [
                        Text('第${i + 1}S',
                            style: const TextStyle(
                                color: AppTheme.grey, fontSize: 9)),
                        const SizedBox(height: 2),
                        Text('${s.ourScore}',
                            style: TextStyle(
                              color: weWon
                                  ? AppTheme.primaryRed
                                  : AppTheme.lightGrey,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            )),
                        Container(height: 1, color: const Color(0xFF444444)),
                        Text('${s.theirScore}',
                            style: TextStyle(
                              color: weWon ? AppTheme.grey : opponentColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            )),
                        const SizedBox(height: 2),
                        Icon(
                          weWon
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: weWon ? AppTheme.primaryRed : opponentColor,
                          size: 14,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // スコア入力ダイアログ（10セット分）
  // ─────────────────────────────────────────
  Future<void> _showScoreInputDialog(
    BuildContext context,
    Match match,
    AppProvider provider,
  ) async {
    final ourControllers = List.generate(
      10,
      (i) => TextEditingController(
        text: match.sets[i].isPlayed ? '${match.sets[i].ourScore}' : '',
      ),
    );
    final theirControllers = List.generate(
      10,
      (i) => TextEditingController(
        text: match.sets[i].isPlayed ? '${match.sets[i].theirScore}' : '',
      ),
    );
    final opponentColor = Color(match.opponentColorValue);

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ダイアログヘッダー
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.primaryRed.withValues(alpha: 0.3),
                  AppTheme.cardBg2,
                ]),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                    bottom: BorderSide(
                        color: opponentColor.withValues(alpha: 0.4))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.scoreboard,
                      color: AppTheme.gold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('セットスコア入力',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        Text('vs ${match.opponent}',
                            style: const TextStyle(
                                color: AppTheme.gold, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppTheme.grey, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            // 列ラベル
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                children: [
                  const SizedBox(width: 44),
                  Expanded(
                    child: Center(
                      child: Text('藤橋JVC',
                          style: const TextStyle(
                            color: AppTheme.primaryRed,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                  ),
                  const SizedBox(width: 36),
                  Expanded(
                    child: Center(
                      child: Text(
                        match.opponent,
                        style: TextStyle(
                          color: opponentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 34),
                ],
              ),
            ),
            // セット入力リスト
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  children: List.generate(10, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          // セット番号
                          SizedBox(
                            width: 44,
                            child: Text(
                              '第${i + 1}S',
                              style: const TextStyle(
                                  color: AppTheme.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // 藤橋スコア
                          Expanded(
                            child: _scoreInputField(
                                ourControllers[i], AppTheme.primaryRed),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('－',
                                style: TextStyle(
                                    color: AppTheme.grey,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                          ),
                          // 相手スコア
                          Expanded(
                            child: _scoreInputField(
                                theirControllers[i], opponentColor),
                          ),
                          // クリアボタン
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              ourControllers[i].clear();
                              theirControllers[i].clear();
                            },
                            child: Container(
                              width: 28,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.cardBg2,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.close,
                                  color: AppTheme.grey, size: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
            // 保存・キャンセルボタン
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.grey,
                        side: const BorderSide(color: Color(0xFF555555)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('キャンセル'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        for (int i = 0; i < 10; i++) {
                          final our =
                              int.tryParse(ourControllers[i].text) ?? 0;
                          final their =
                              int.tryParse(theirControllers[i].text) ?? 0;
                          await provider.updateSetScore(
                              match.id, i, our, their);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('保存',
                          style: TextStyle(
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    for (final c in ourControllers) c.dispose();
    for (final c in theirControllers) c.dispose();
  }

  Widget _scoreInputField(TextEditingController ctrl, Color color) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.cardBg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: '0',
          hintStyle: TextStyle(color: Color(0xFF555555), fontSize: 20),
        ),
        maxLength: 2,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      ),
    );
  }

  Widget _statBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.sports_volleyball, color: AppTheme.grey.withValues(alpha: 0.5), size: 48),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppTheme.grey, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('右下の「＋試合を追加」から追加してください',
              style: TextStyle(color: AppTheme.grey, fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('試合を削除', style: TextStyle(color: Colors.white)),
        content: const Text('この試合のすべての記録が削除されます。\nよろしいですか？',
            style: TextStyle(color: AppTheme.lightGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(color: AppTheme.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMatchDialog(BuildContext context) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final opponentController = TextEditingController();
    final matchNameController = TextEditingController();
    final memoController = TextEditingController();
    String team = 'A';
    DateTime selectedDate = DateTime.now();
    int selectedColorIndex = 0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                color: AppTheme.primaryRed,
                margin: const EdgeInsets.only(right: 8),
              ),
              const Text('試合を追加', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // チーム選択
                Row(
                  children: [
                    const Text('チーム：', style: TextStyle(color: AppTheme.lightGrey)),
                    const SizedBox(width: 8),
                    _teamSelector('A', team, (v) => setDialogState(() => team = v)),
                    const SizedBox(width: 8),
                    _teamSelector('B', team, (v) => setDialogState(() => team = v)),
                  ],
                ),
                const SizedBox(height: 12),
                // 日付
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(primary: AppTheme.primaryRed),
                        ),
                        child: child!,
                      ),
                    );
                    if (d != null) setDialogState(() => selectedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF444444)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppTheme.gold, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('yyyy年M月d日 (E)', 'ja').format(selectedDate),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: opponentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '対戦相手（必須）',
                    prefixIcon: Icon(Icons.group, color: AppTheme.primaryRed, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: matchNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '試合名（任意）',
                    prefixIcon: Icon(Icons.event_note, color: AppTheme.grey, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: memoController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'メモ（任意）',
                    prefixIcon: Icon(Icons.note, color: AppTheme.grey, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                // チームカラー選択
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('対戦相手カラー', style: TextStyle(color: AppTheme.lightGrey, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _opponentColors.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final color = entry.value;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColorIndex = idx),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColorIndex == idx ? AppTheme.gold : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: selectedColorIndex == idx
                                ? const Icon(Icons.check, color: Colors.white, size: 16)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル', style: TextStyle(color: AppTheme.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
              onPressed: () async {
                if (opponentController.text.trim().isEmpty) return;
                final match = await provider.addMatch(
                  opponent: opponentController.text.trim(),
                  team: team,
                  date: selectedDate,
                  matchName: matchNameController.text.trim(),
                  memo: memoController.text.trim(),
                  colorValue: _opponentColors[selectedColorIndex].toARGB32(),
                );
                provider.setCurrentMatch(match.id);
                provider.setCurrentTeam(team);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('追加', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamSelector(String team, String selected, ValueChanged<String> onTap) {
    final isSelected = team == selected;
    return GestureDetector(
      onTap: () => onTap(team),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (team == 'A' ? AppTheme.primaryRed : Colors.blue)
              : AppTheme.cardBg2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (team == 'A' ? AppTheme.primaryRed : Colors.blue)
                : const Color(0xFF444444),
          ),
        ),
        child: Text(
          '${team}チーム',
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
