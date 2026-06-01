import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/player.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPlayerList(context, 'A'),
                _buildPlayerList(context, 'B'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPlayerDialog(context),
        backgroundColor: AppTheme.primaryRed,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('選手を追加',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
        border: Border(bottom: BorderSide(color: AppTheme.gold, width: 1)),
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
            '設定・選手管理',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          // 全選手確認ボタン（デバッグ用）
          Consumer<AppProvider>(
            builder: (context, provider, _) => GestureDetector(
              onTap: () => _showAllPlayersDebug(context, provider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.manage_search, color: Colors.orange, size: 13),
                    SizedBox(width: 4),
                    Text('全選手確認',
                        style: TextStyle(color: Colors.orange, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // リアルタイム同期インジケーター
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done, color: Colors.green, size: 13),
                SizedBox(width: 4),
                Text('リアルタイム同期中',
                    style: TextStyle(color: Colors.green, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final aCount = provider.teamAPlayers.length;
        final bCount = provider.teamBPlayers.length;
        final allCount = provider.players.length;
        final unassignedCount = allCount - aCount - bCount;
        return Container(
          color: AppTheme.cardBg,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'Aチーム ($aCount名)'),
                  Tab(text: 'Bチーム ($bCount名)'),
                ],
                labelColor: AppTheme.gold,
                unselectedLabelColor: AppTheme.grey,
                indicatorColor: AppTheme.primaryRed,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              // 取得総数・未割り当て数を表示
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: AppTheme.cardBg2,
                child: Row(
                  children: [
                    Icon(Icons.people, color: AppTheme.grey, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      'Firestore取得: 計$allCount名  '
                      '(A:$aCount  B:$bCount'
                      '${unassignedCount > 0 ? "  未設定:$unassignedCount" : ""})',
                      style: TextStyle(
                        color: unassignedCount > 0
                            ? Colors.orange
                            : AppTheme.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerList(BuildContext context, String team) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final players =
            team == 'A' ? provider.teamAPlayers : provider.teamBPlayers;

        // A/B どちらにも属さない「未割り当て」選手（Aタブにのみ表示）
        final knownIds = {
          ...provider.teamAPlayers.map((p) => p.id),
          ...provider.teamBPlayers.map((p) => p.id),
        };
        final unassigned = team == 'A'
            ? provider.players.where((p) => !knownIds.contains(p.id)).toList()
            : <Player>[];

        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryRed),
          );
        }

        if (players.isEmpty && unassigned.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline,
                    color: AppTheme.grey.withValues(alpha: 0.4), size: 64),
                const SizedBox(height: 16),
                Text('${team}チームの選手がいません',
                    style: const TextStyle(color: AppTheme.grey, fontSize: 15)),
                const SizedBox(height: 8),
                const Text('右下の「＋選手を追加」から追加してください',
                    style: TextStyle(color: AppTheme.grey, fontSize: 12)),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            // 通常の選手リスト（並び替え可能）
            SliverReorderableList(
              itemCount: players.length,
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex--;
                final reordered = List<Player>.from(players);
                final item = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, item);
                for (int i = 0; i < reordered.length; i++) {
                  reordered[i].sortOrder = i;
                  await provider.updatePlayer(reordered[i]);
                }
              },
              itemBuilder: (context, index) {
                final player = players[index];
                return ReorderableDragStartListener(
                  key: ValueKey(player.id),
                  index: index,
                  child: _buildPlayerCard(context, player, provider,
                      key: ValueKey('card_${player.id}')),
                );
              },
            ),
            // 未割り当て選手セクション（Aタブのみ）
            if (unassigned.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'チーム未設定の選手（タップしてチームを割り当て）',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final player = unassigned[index];
                    return Container(
                      key: ValueKey('unassigned_${player.id}'),
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Center(
                            child: Text(
                              player.number.isNotEmpty ? '#${player.number}' : '?',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          player.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'チーム未設定 (保存値: "${player.team}")',
                          style: const TextStyle(
                              color: Colors.orange, fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Aチームに移動
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryRed,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                player.team = 'A';
                                await provider.updatePlayer(player);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${player.name} をAチームに移動しました'),
                                      backgroundColor: AppTheme.primaryRed,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Aへ',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            // Bチームに移動
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                player.team = 'B';
                                await provider.updatePlayer(player);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${player.name} をBチームに移動しました'),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Bへ',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: unassigned.length,
                ),
              ),
            ],
            // 下部余白
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }

  Widget _buildPlayerCard(
      BuildContext context, Player player, AppProvider provider,
      {required Key key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: player.team == 'A'
                ? AppTheme.primaryRed.withValues(alpha: 0.15)
                : Colors.blue.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: player.team == 'A' ? AppTheme.primaryRed : Colors.blue,
            ),
          ),
          child: Center(
            child: Text(
              player.number.isNotEmpty ? '#${player.number}' : '?',
              style: TextStyle(
                color: player.team == 'A' ? AppTheme.primaryRed : Colors.blue,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          player.name,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${player.team}チーム'
          '${player.number.isNotEmpty ? " ・背番号 ${player.number}" : ""}',
          style: const TextStyle(color: AppTheme.grey, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.gold, size: 20),
              onPressed: () =>
                  _showEditPlayerDialog(context, player, provider),
              tooltip: '編集',
            ),
            IconButton(
              icon: const Icon(Icons.delete,
                  color: AppTheme.primaryRed, size: 20),
              onPressed: () async {
                final confirm = await _confirmDelete(context, player.name);
                if (confirm == true) {
                  await provider.deletePlayer(player.id);
                }
              },
              tooltip: '削除',
            ),
            const Icon(Icons.drag_handle, color: AppTheme.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('選手を削除',
            style: TextStyle(color: Colors.white)),
        content: Text('$name 選手を削除しますか？\nこの選手の記録データは保持されます。',
            style: const TextStyle(color: AppTheme.lightGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル',
                style: TextStyle(color: AppTheme.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddPlayerDialog(BuildContext context) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final nameCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    String team = _tabController.index == 0 ? 'A' : 'B';

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
                  margin: const EdgeInsets.only(right: 8)),
              const Text('選手を追加',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '選手名（必須）',
                  prefixIcon: Icon(Icons.person,
                      color: AppTheme.primaryRed, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numberCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '背番号（任意）',
                  prefixIcon:
                      Icon(Icons.tag, color: AppTheme.grey, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('チーム：',
                      style: TextStyle(color: AppTheme.lightGrey)),
                  const SizedBox(width: 8),
                  _teamBtn(
                      'A', team, (v) => setDialogState(() => team = v)),
                  const SizedBox(width: 8),
                  _teamBtn(
                      'B', team, (v) => setDialogState(() => team = v)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル',
                  style: TextStyle(color: AppTheme.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await provider.addPlayer(
                  name: nameCtrl.text.trim(),
                  number: numberCtrl.text.trim(),
                  team: team,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('追加',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditPlayerDialog(
      BuildContext context, Player player, AppProvider provider) async {
    final nameCtrl = TextEditingController(text: player.name);
    final numberCtrl = TextEditingController(text: player.number);
    String team = player.team;

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
                  color: AppTheme.gold,
                  margin: const EdgeInsets.only(right: 8)),
              const Text('選手を編集',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '選手名',
                  prefixIcon: Icon(Icons.person,
                      color: AppTheme.primaryRed, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numberCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '背番号',
                  prefixIcon:
                      Icon(Icons.tag, color: AppTheme.grey, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('チーム：',
                      style: TextStyle(color: AppTheme.lightGrey)),
                  const SizedBox(width: 8),
                  _teamBtn(
                      'A', team, (v) => setDialogState(() => team = v)),
                  const SizedBox(width: 8),
                  _teamBtn(
                      'B', team, (v) => setDialogState(() => team = v)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル',
                  style: TextStyle(color: AppTheme.grey)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                player.name = nameCtrl.text.trim();
                player.number = numberCtrl.text.trim();
                player.team = team;
                await provider.updatePlayer(player);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('保存',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // 全選手の生データを表示（デバッグ用）
  void _showAllPlayersDebug(BuildContext context, AppProvider provider) {
    final orphanIds = provider.orphanPlayerIds;
    final orphanCounts = provider.orphanRecordCounts;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Row(
          children: [
            const Icon(Icons.manage_search, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text('全選手確認（${provider.players.length}名登録）',
                style: const TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 450,
          child: ListView(
            children: [
              // 孤立記録セクション（記録あり・選手登録なし）
              if (orphanIds.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red, size: 14),
                          SizedBox(width: 4),
                          Text('記録はあるが選手未登録のID',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '→ これらのIDに名前を付けて登録することで\n  集計に反映されます',
                        style: TextStyle(color: Colors.orange, fontSize: 10),
                      ),
                      const SizedBox(height: 8),
                      ...orphanIds.map((pid) {
                        final count = orphanCounts[pid] ?? 0;
                        final nameCtrl = TextEditingController();
                        final numberCtrl = TextEditingController();
                        return StatefulBuilder(
                          builder: (ctx, setSt) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg2,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ID: ${pid.substring(0, 8)}...  記録${count}件',
                                  style: const TextStyle(
                                      color: AppTheme.grey, fontSize: 10),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: nameCtrl,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                        decoration: const InputDecoration(
                                          hintText: '名前を入力',
                                          hintStyle: TextStyle(
                                              color: AppTheme.grey,
                                              fontSize: 12),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 6),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 60,
                                      child: TextField(
                                        controller: numberCtrl,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          hintText: '番号',
                                          hintStyle: TextStyle(
                                              color: AppTheme.grey,
                                              fontSize: 12),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 6),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryRed,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () async {
                                        if (nameCtrl.text.trim().isEmpty) return;
                                        // 既存IDで選手を登録（記録と紐づく）
                                        await provider.addPlayerWithId(
                                          id: pid,
                                          name: nameCtrl.text.trim(),
                                          number: numberCtrl.text.trim(),
                                          team: 'A',
                                        );
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: Text(
                                                '${nameCtrl.text.trim()} をAチームに登録しました（記録${count}件が紐づきました）'),
                                            backgroundColor: Colors.green,
                                          ));
                                        }
                                      },
                                      child: const Text('A登録',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF444444)),
                const SizedBox(height: 4),
              ],
              // 通常の登録済み選手一覧
              ...provider.players.map((p) {

              final teamNorm = AppProvider.normalizeTeamPublic(p.team);
              final isOk = teamNorm == 'A' || teamNorm == 'B';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isOk ? AppTheme.cardBg2 : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOk ? const Color(0xFF444444) : Colors.orange,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          Text(
                            'team="${p.team}"  正規化後="$teamNorm"',
                            style: TextStyle(
                              color: isOk ? AppTheme.grey : Colors.orange,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isOk) ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          p.team = 'A';
                          await provider.updatePlayer(p);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Aへ',
                            style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          p.team = 'B';
                          await provider.updatePlayer(p);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Bへ',
                            style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.team == 'A'
                              ? AppTheme.primaryRed.withValues(alpha: 0.2)
                              : Colors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${p.team}チーム',
                          style: TextStyle(
                            color: p.team == 'A'
                                ? AppTheme.primaryRed
                                : Colors.blue,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            ], // ListView children の閉じ
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる', style: TextStyle(color: AppTheme.grey)),
          ),
        ],
      ),
    );
  }

  Widget _teamBtn(
      String team, String selected, ValueChanged<String> onTap) {
    final isSelected = team == selected;
    return GestureDetector(
      onTap: () => onTap(team),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
