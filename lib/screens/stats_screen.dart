import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/player.dart';
import '../models/serve_record.dart';
import '../utils/app_theme.dart';
import 'ai_comment_screen.dart';
import 'print_screen.dart';

enum PeriodFilter { today, custom, all }
enum TeamFilter { all, a, b }

// 選手選択モード（チームフィルターがA or Bのとき有効）
// 空セット = 全員選択とみなす

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PeriodFilter _period = PeriodFilter.all;
  TeamFilter _teamFilter = TeamFilter.all;
  DateTimeRange? _customRange;
  // ignore: unused_field
  int _statsTabIndex = 0; // 0=サーブ, 1=レシーブ

  // 選手個別選択（チームフィルター使用時）
  // nullの場合は全員対象、非nullの場合は選択中のIDセット
  Set<String>? _selectedPlayerIds;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _statsTabIndex = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTimeRange? _getDateRange() {
    final now = DateTime.now();
    switch (_period) {
      case PeriodFilter.today:
        // 今日の試合日 00:00:00 〜 翌日 00:00:00
        final start = DateTime(now.year, now.month, now.day);
        final end   = DateTime(now.year, now.month, now.day + 1);
        return DateTimeRange(start: start, end: end);
      case PeriodFilter.custom:
        if (_customRange == null) return null;
        // カスタム: 開始日 00:00:00 〜 終了日の翌日 00:00:00
        final cStart = DateTime(
          _customRange!.start.year,
          _customRange!.start.month,
          _customRange!.start.day,
          0, 0, 0,
        );
        final cEndBase = DateTime(
          _customRange!.end.year,
          _customRange!.end.month,
          _customRange!.end.day,
          0, 0, 0,
        );
        final cEnd = cEndBase.add(const Duration(days: 1));
        return DateTimeRange(start: cStart, end: cEnd);
      case PeriodFilter.all:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterRow(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildServeStats(),
                _buildReceiveStats(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
        border: Border(bottom: BorderSide(color: AppTheme.primaryRed, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 24,
            color: AppTheme.gold,
            margin: const EdgeInsets.only(right: 8),
          ),
          const Text(
            '集計・分析',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // AI講評ボタン
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiCommentScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.psychology, color: Colors.black, size: 14),
                  SizedBox(width: 4),
                  Text('AI講評',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 印刷ボタン
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PrintScreen(
                  teamFilter: _teamFilter == TeamFilter.a
                      ? 'A'
                      : _teamFilter == TeamFilter.b
                          ? 'B'
                          : 'all',
                  selectedPlayerIds: _selectedPlayerIds,
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.cardBg2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF555555)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.print, color: AppTheme.lightGrey, size: 14),
                  SizedBox(width: 4),
                  Text('印刷',
                      style: TextStyle(color: AppTheme.lightGrey, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      color: AppTheme.cardBg,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // 期間フィルター
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _periodChip('今日', PeriodFilter.today),
                const SizedBox(width: 6),
                _periodChip('全期間', PeriodFilter.all),
                const SizedBox(width: 6),
                _customPeriodChip(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // チームフィルター＋選手選択
          Consumer<AppProvider>(
            builder: (context, provider, _) {
              return Row(
                children: [
                  _teamChip('全体', TeamFilter.all),
                  const SizedBox(width: 6),
                  _teamChip('Aチーム', TeamFilter.a),
                  const SizedBox(width: 6),
                  _teamChip('Bチーム', TeamFilter.b),
                  // チームが選択されているとき「選手を選ぶ」ボタンを表示
                  if (_teamFilter != TeamFilter.all) ...([
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showPlayerSelectSheet(provider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedPlayerIds != null
                              ? AppTheme.gold.withValues(alpha: 0.15)
                              : AppTheme.cardBg2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedPlayerIds != null
                                ? AppTheme.gold
                                : const Color(0xFF444444),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_search,
                              size: 13,
                              color: _selectedPlayerIds != null
                                  ? AppTheme.gold
                                  : AppTheme.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedPlayerIds != null
                                  ? '${_selectedPlayerIds!.length}名選択中'
                                  : '選手を選ぶ',
                              style: TextStyle(
                                color: _selectedPlayerIds != null
                                    ? AppTheme.gold
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
                  ]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String label, PeriodFilter filter) {
    final isSelected = _period == filter;
    return GestureDetector(
      onTap: () => setState(() => _period = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryRed : AppTheme.cardBg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryRed : const Color(0xFF444444),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.grey,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _customPeriodChip() {
    final isSelected = _period == PeriodFilter.custom;
    return GestureDetector(
      onTap: () async {
        // 初期表示を「1年前の月初〜今日」にする（過去データを選びやすくするため）
        final now = DateTime.now();
        final oneYearAgo = DateTime(now.year - 1, now.month, 1);
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          // 既に選択済みならそれを初期値に、なければ1年前〜今日
          initialDateRange: _customRange ?? DateTimeRange(
            start: oneYearAgo,
            end: now,
          ),
          builder: (c, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: AppTheme.primaryRed),
            ),
            child: child!,
          ),
        );
        if (range != null) {
          setState(() {
            _customRange = range;
            _period = PeriodFilter.custom;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryRed : AppTheme.cardBg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryRed : const Color(0xFF444444),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range, size: 12,
                color: isSelected ? Colors.white : AppTheme.grey),
            const SizedBox(width: 4),
            Text(
              isSelected && _customRange != null
                  ? '${DateFormat('M/d').format(_customRange!.start)}-${DateFormat('M/d').format(_customRange!.end)}'
                  : '期間指定',
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamChip(String label, TeamFilter filter) {
    final isSelected = _teamFilter == filter;
    Color color = filter == TeamFilter.a
        ? AppTheme.primaryRed
        : filter == TeamFilter.b
            ? Colors.blue
            : AppTheme.gold;
    return GestureDetector(
      onTap: () => _onTeamFilterChanged(filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : AppTheme.cardBg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF444444),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : AppTheme.grey,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.cardBg,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'サーブ分析'),
          Tab(text: 'レシーブ分析'),
        ],
        labelColor: AppTheme.gold,
        unselectedLabelColor: AppTheme.grey,
        indicatorColor: AppTheme.primaryRed,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildServeStats() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final range = _getDateRange();
        final players = _getFilteredPlayers(provider);

        final playerStats = players.map((p) {
          final stats = provider.getServeStatsByPlayer(
            p.id,
            from: range?.start,
            to: range?.end,
          );
          final total = stats.values.fold(0, (a, b) => a + b);
          return _PlayerServeStats(player: p, stats: stats, total: total);
        }).where((s) => s.total > 0).toList();

        playerStats.sort((a, b) => b.total.compareTo(a.total));

        if (playerStats.isEmpty) {
          return _emptyStats('この期間のサーブデータがありません');
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildServeRankings(playerStats),
            const SizedBox(height: 16),
            ...playerStats.map((s) => _buildPlayerServeCard(s)),
          ],
        );
      },
    );
  }

  Widget _buildReceiveStats() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final range = _getDateRange();
        final players = _getFilteredPlayers(provider);

        final playerStats = players.map((p) {
          final stats = provider.getReceiveStatsByPlayer(
            p.id,
            from: range?.start,
            to: range?.end,
          );
          final total = stats.values.fold(0, (a, b) => a + b);
          return _PlayerReceiveStats(player: p, stats: stats, total: total);
        }).where((s) => s.total > 0).toList();

        playerStats.sort((a, b) => b.total.compareTo(a.total));

        if (playerStats.isEmpty) {
          return _emptyStats('この期間のレシーブデータがありません');
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildReceiveRankings(playerStats),
            const SizedBox(height: 16),
            ...playerStats.map((s) => _buildPlayerReceiveCard(s)),
          ],
        );
      },
    );
  }

  List<Player> _getFilteredPlayers(AppProvider provider) {
    List<Player> base;
    switch (_teamFilter) {
      case TeamFilter.a:
        base = provider.teamAPlayers;
      case TeamFilter.b:
        base = provider.teamBPlayers;
      case TeamFilter.all:
        return provider.players; // 全体のときは選手選択なし
    }
    // 選手が個別選択されている場合はフィルター
    if (_selectedPlayerIds != null && _selectedPlayerIds!.isNotEmpty) {
      return base.where((p) => _selectedPlayerIds!.contains(p.id)).toList();
    }
    return base;
  }

  // チームフィルター変更時に選手選択をリセット
  void _onTeamFilterChanged(TeamFilter filter) {
    setState(() {
      _teamFilter = filter;
      _selectedPlayerIds = null; // リセット
    });
  }

  // 選手選択ボトムシートを表示
  void _showPlayerSelectSheet(AppProvider provider) {
    final List<Player> teamPlayers = _teamFilter == TeamFilter.a
        ? provider.teamAPlayers
        : provider.teamBPlayers;

    // 現在の選択状態（nullなら全員選択済みとみなす）
    Set<String> current = _selectedPlayerIds ?? teamPlayers.map((p) => p.id).toSet();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final teamColor = _teamFilter == TeamFilter.a
                ? AppTheme.primaryRed
                : Colors.blue;
            // 画面の最大85%まで使い、内部でスクロール可能にする
            final maxHeight = MediaQuery.of(ctx).size.height * 0.85;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ヘッダー（固定）
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                    child: Row(
                      children: [
                        Icon(Icons.people, color: teamColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${_teamFilter == TeamFilter.a ? 'A' : 'B'}チーム 出場選手を選択',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // 全選択/全解除ボタン
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              if (current.length == teamPlayers.length) {
                                current = {};
                              } else {
                                current = teamPlayers.map((p) => p.id).toSet();
                              }
                            });
                          },
                          child: Text(
                            current.length == teamPlayers.length ? '全解除' : '全選択',
                            style: TextStyle(color: teamColor, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      '選択した選手だけがランキングに表示されます',
                      style: const TextStyle(color: AppTheme.grey, fontSize: 12),
                    ),
                  ),
                  // 選手一覧（スクロール可能）
                  Flexible(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      shrinkWrap: true,
                      itemCount: teamPlayers.length,
                      itemBuilder: (_, i) {
                        final p = teamPlayers[i];
                        final isSelected = current.contains(p.id);
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              if (isSelected) {
                                current = Set.from(current)..remove(p.id);
                              } else {
                                current = Set.from(current)..add(p.id);
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? teamColor.withValues(alpha: 0.12)
                                  : AppTheme.cardBg2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? teamColor.withValues(alpha: 0.6)
                                    : const Color(0xFF444444),
                              ),
                            ),
                            child: Row(
                              children: [
                                // 背番号
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? teamColor.withValues(alpha: 0.25)
                                        : const Color(0xFF2A2A2A),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? teamColor
                                          : const Color(0xFF555555),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      p.number.isNotEmpty ? p.number : '?',
                                      style: TextStyle(
                                        color: isSelected ? teamColor : AppTheme.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 名前
                                Expanded(
                                  child: Text(
                                    p.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.lightGrey,
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                // チェックアイコン
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isSelected ? teamColor : AppTheme.grey,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // 適用ボタン（固定）
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        16, 8, 16, MediaQuery.of(ctx).padding.bottom + 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: teamColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            // 全員選択の場合はnull（デフォルト）に戻す
                            if (current.length == teamPlayers.length) {
                              _selectedPlayerIds = null;
                            } else {
                              _selectedPlayerIds = current;
                            }
                          });
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          current.isEmpty
                              ? '選手を選択してください'
                              : '${current.length}名でランキングを表示',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildServeRankings(List<_PlayerServeStats> stats) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events, color: AppTheme.gold, size: 16),
              SizedBox(width: 6),
              Text('サーブランキング',
                  style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          _rankingRow(
            'エース率ランキング',
            stats.where((s) => s.total > 0).toList()
              ..sort((a, b) => b.aceRate.compareTo(a.aceRate)),
            (s) => '${s.aceRate.toStringAsFixed(1)}%',
            AppTheme.aceColor,
          ),
          const SizedBox(height: 8),
          _rankingRow(
            '崩し率ランキング',
            stats.where((s) => s.total > 0).toList()
              ..sort((a, b) => b.underRate.compareTo(a.underRate)),
            (s) => '${s.underRate.toStringAsFixed(1)}%',
            AppTheme.underColor,
          ),
          const SizedBox(height: 8),
          _rankingRow(
            'ミス率ランキング（低い方が良い）',
            stats.where((s) => s.total > 0).toList()
              ..sort((a, b) => a.missRate.compareTo(b.missRate)),
            (s) => '${s.missRate.toStringAsFixed(1)}%',
            AppTheme.missColor,
          ),
        ],
      ),
    );
  }

  Widget _buildReceiveRankings(List<_PlayerReceiveStats> stats) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events, color: AppTheme.gold, size: 16),
              SizedBox(width: 6),
              Text('レシーブランキング',
                  style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          _rankingRow(
            'オーバー率ランキング',
            stats.where((s) => s.total > 0).toList()
              ..sort((a, b) => b.overRate.compareTo(a.overRate)),
            (s) => '${s.overRate.toStringAsFixed(1)}%',
            AppTheme.overColor,
          ),
          const SizedBox(height: 8),
          _rankingRow(
            'ミス率ランキング（低い方が良い）',
            stats.where((s) => s.total > 0).toList()
              ..sort((a, b) => a.missRate.compareTo(b.missRate)),
            (s) => '${s.missRate.toStringAsFixed(1)}%',
            AppTheme.receiveMissColor,
          ),
        ],
      ),
    );
  }

  Widget _rankingRow<T>(
    String title,
    List<T> sorted,
    String Function(T) valueLabel,
    Color color,
  ) {
    final top3 = sorted.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppTheme.lightGrey, fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          children: top3.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value as dynamic;
            final medals = ['🥇', '🥈', '🥉'];
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: idx == 0 ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: color.withValues(alpha: idx == 0 ? 0.6 : 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Text(medals[idx], style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.player.name,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            valueLabel(item),
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPlayerServeCard(_PlayerServeStats s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          // 選手ヘッダー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.cardBg2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryRed),
                  ),
                  child: Center(
                    child: Text(
                      s.player.number.isNotEmpty ? s.player.number : '?',
                      style: const TextStyle(
                          color: AppTheme.primaryRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.player.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: s.player.team == 'A'
                        ? AppTheme.primaryRed.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${s.player.team}チーム',
                    style: TextStyle(
                      color: s.player.team == 'A' ? AppTheme.primaryRed : Colors.blue,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${s.total}本',
                  style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // 統計バー
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _statBar('決まり（エース）', s.stats[ServeResult.ace] ?? 0, s.total, AppTheme.aceColor),
                const SizedBox(height: 6),
                _statBar('アンダー・二段（崩し）', s.stats[ServeResult.under] ?? 0, s.total, AppTheme.underColor),
                const SizedBox(height: 6),
                _statBar('入っただけ', s.stats[ServeResult.justIn] ?? 0, s.total, AppTheme.justInColor),
                const SizedBox(height: 6),
                _statBar('ミス', s.stats[ServeResult.miss] ?? 0, s.total, AppTheme.missColor),
                const SizedBox(height: 10),
                // 指標サマリー
                Row(
                  children: [
                    _metricBox('エース率', '${s.aceRate.toStringAsFixed(1)}%', AppTheme.aceColor),
                    const SizedBox(width: 6),
                    _metricBox('崩し率', '${s.underRate.toStringAsFixed(1)}%', AppTheme.underColor),
                    const SizedBox(width: 6),
                    _metricBox('ミス率', '${s.missRate.toStringAsFixed(1)}%', AppTheme.missColor),
                    const SizedBox(width: 6),
                    _metricBox('効率', '${s.efficiency.toStringAsFixed(1)}%', AppTheme.gold),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerReceiveCard(_PlayerReceiveStats s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.cardBg2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Center(
                    child: Text(
                      s.player.number.isNotEmpty ? s.player.number : '?',
                      style: const TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.player.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${s.total}本',
                  style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _statBar('オーバー', s.stats[ReceiveResult.over] ?? 0, s.total, AppTheme.overColor),
                const SizedBox(height: 6),
                _statBar('アンダー', s.stats[ReceiveResult.under] ?? 0, s.total, AppTheme.receiveUnderColor),
                const SizedBox(height: 6),
                _statBar('ダイレクト・二段', s.stats[ReceiveResult.direct] ?? 0, s.total, AppTheme.directColor),
                const SizedBox(height: 6),
                _statBar('ミス', s.stats[ReceiveResult.miss] ?? 0, s.total, AppTheme.receiveMissColor),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _metricBox('安定率', '${s.overRate.toStringAsFixed(1)}%', AppTheme.overColor),
                    const SizedBox(width: 6),
                    _metricBox('アンダー率', '${s.underRate.toStringAsFixed(1)}%', AppTheme.receiveUnderColor),
                    const SizedBox(width: 6),
                    _metricBox('ミス率', '${s.missRate.toStringAsFixed(1)}%', AppTheme.receiveMissColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBar(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(color: AppTheme.lightGrey, fontSize: 11)),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '$count (${(pct * 100).toStringAsFixed(0)}%)',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _metricBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(color: AppTheme.grey, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _emptyStats(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, color: AppTheme.grey.withValues(alpha: 0.4), size: 64),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppTheme.grey, fontSize: 14)),
        ],
      ),
    );
  }
}

// データクラス
class _PlayerServeStats {
  final Player player;
  final Map<ServeResult, int> stats;
  final int total;

  _PlayerServeStats({required this.player, required this.stats, required this.total});

  double get aceRate => total > 0 ? (stats[ServeResult.ace] ?? 0) / total * 100 : 0;
  double get underRate => total > 0 ? (stats[ServeResult.under] ?? 0) / total * 100 : 0;
  double get justInRate => total > 0 ? (stats[ServeResult.justIn] ?? 0) / total * 100 : 0;
  double get missRate => total > 0 ? (stats[ServeResult.miss] ?? 0) / total * 100 : 0;
  double get efficiency => total > 0
      ? ((stats[ServeResult.ace] ?? 0) - (stats[ServeResult.miss] ?? 0)) / total * 100
      : 0;
}

class _PlayerReceiveStats {
  final Player player;
  final Map<ReceiveResult, int> stats;
  final int total;

  _PlayerReceiveStats({required this.player, required this.stats, required this.total});

  double get overRate => total > 0 ? (stats[ReceiveResult.over] ?? 0) / total * 100 : 0;
  double get underRate => total > 0 ? (stats[ReceiveResult.under] ?? 0) / total * 100 : 0;
  double get directRate => total > 0 ? (stats[ReceiveResult.direct] ?? 0) / total * 100 : 0;
  double get missRate => total > 0 ? (stats[ReceiveResult.miss] ?? 0) / total * 100 : 0;
}
