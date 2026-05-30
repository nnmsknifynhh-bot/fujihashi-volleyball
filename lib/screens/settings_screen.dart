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
    return Container(
      color: AppTheme.cardBg,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Aチーム'),
          Tab(text: 'Bチーム'),
        ],
        labelColor: AppTheme.gold,
        unselectedLabelColor: AppTheme.grey,
        indicatorColor: AppTheme.primaryRed,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPlayerList(BuildContext context, String team) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final players =
            team == 'A' ? provider.teamAPlayers : provider.teamBPlayers;

        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryRed),
          );
        }

        if (players.isEmpty) {
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

        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
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
            return _buildPlayerCard(context, player, provider,
                key: ValueKey(player.id));
          },
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
