import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/player.dart';
import '../models/serve_record.dart';
import '../utils/app_theme.dart';

class AiCommentScreen extends StatefulWidget {
  const AiCommentScreen({super.key});

  @override
  State<AiCommentScreen> createState() => _AiCommentScreenState();
}

class _AiCommentScreenState extends State<AiCommentScreen> {
  bool _isGenerating = false;
  Map<String, String> _comments = {};

  // フィルター状態
  // 'ALL' / 'A' / 'B'
  String _teamFilter = 'ALL';
  // null = 全員, 非null = 選択中IDセット
  Set<String>? _selectedPlayerIds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateComments());
  }

  // チームフィルター変更時に選手選択をリセット
  void _onTeamChanged(String team) {
    setState(() {
      _teamFilter = team;
      _selectedPlayerIds = null;
    });
  }

  // 現在のフィルターに応じた選手リストを返す
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

  Future<void> _generateComments() async {
    setState(() => _isGenerating = true);
    final provider = Provider.of<AppProvider>(context, listen: false);

    final Map<String, String> newComments = {};
    // 全選手分を生成しておく（フィルター変更時に再生成不要）
    for (final player in provider.players) {
      final serveStats = provider.getServeStatsByPlayer(player.id);
      final receiveStats = provider.getReceiveStatsByPlayer(player.id);
      newComments[player.id] = _generateComment(player, serveStats, receiveStats);
    }

    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _comments = newComments;
      _isGenerating = false;
    });
  }

  String _generateComment(
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

    if (total > 0) {
      final aceRate = (serveStats[ServeResult.ace] ?? 0) / total * 100;
      final underRate = (serveStats[ServeResult.under] ?? 0) / total * 100;
      final missRate = (serveStats[ServeResult.miss] ?? 0) / total * 100;
      final efficiency = ((serveStats[ServeResult.ace] ?? 0) -
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
        comments.add('【サーブ効率】現在サーブ効率がマイナスです。ミスを減らすことを第一に意識しましょう。');
      }

      final suggestions = <String>[];
      if (missRate >= 15) suggestions.add('入れることを優先した基礎練習');
      if (aceRate < 8) suggestions.add('コース狙いの練習（ライン際・ショートサーブ）');
      if (underRate < 25) suggestions.add('相手レシーバーを動かすサーブコース練習');
      if (suggestions.isNotEmpty) {
        comments.add('【練習提案】${suggestions.join('、')}を重点的に行うことをお勧めします。');
      }
    }

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

  // 選手選択ボトムシートを表示
  void _showPlayerSelectSheet(AppProvider provider) {
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
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final maxHeight = MediaQuery.of(ctx).size.height * 0.85;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ヘッダー
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                  child: Row(
                    children: [
                      Icon(Icons.people, color: teamColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '講評対象の選手を選択',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            if (current.length == teamPlayers.length) {
                              current = {};
                            } else {
                              current =
                                  teamPlayers.map((p) => p.id).toSet();
                            }
                          });
                        },
                        child: Text(
                          current.length == teamPlayers.length
                              ? '全解除'
                              : '全選択',
                          style: TextStyle(color: teamColor, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text('選択した選手の講評だけが表示されます',
                      style: const TextStyle(
                          color: AppTheme.grey, fontSize: 12)),
                ),
                // 選手リスト（スクロール可能）
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                                      color: isSelected
                                          ? teamColor
                                          : AppTheme.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
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
                // 確定ボタン
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
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedPlayerIds =
                              current.length == teamPlayers.length
                                  ? null
                                  : current;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        current.isEmpty
                            ? '選手を選択してください'
                            : '${current.length}名の講評を表示',
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
            Icon(Icons.psychology, color: AppTheme.gold, size: 20),
            SizedBox(width: 8),
            Text('AI 自動講評',
                style: TextStyle(color: AppTheme.gold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.lightGrey),
            onPressed: _generateComments,
            tooltip: '再生成',
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final filteredPlayers = _getFilteredPlayers(provider);

          return Column(
            children: [
              // ── フィルターバー ──
              _buildFilterBar(provider),
              // ── コンテンツ ──
              Expanded(
                child: _isGenerating
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                                color: AppTheme.gold),
                            const SizedBox(height: 16),
                            const Text('AIが講評を生成しています...',
                                style: TextStyle(color: AppTheme.gold)),
                            const SizedBox(height: 8),
                            Text('選手データを分析中',
                                style: TextStyle(
                                    color: AppTheme.grey, fontSize: 12)),
                          ],
                        ),
                      )
                    : filteredPlayers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_off,
                                    color: AppTheme.grey.withValues(alpha: 0.4),
                                    size: 48),
                                const SizedBox(height: 12),
                                const Text('表示する選手がいません',
                                    style: TextStyle(color: AppTheme.grey)),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              // ヘッダー説明
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    AppTheme.gold.withValues(alpha: 0.15),
                                    AppTheme.cardBg,
                                  ]),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppTheme.gold
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline,
                                        color: AppTheme.gold, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '蓄積されたデータをもとにAIが自動分析（${filteredPlayers.length}名対象）',
                                        style: const TextStyle(
                                            color: AppTheme.lightGrey,
                                            fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...filteredPlayers
                                  .map((p) => _buildPlayerComment(p)),
                            ],
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(AppProvider provider) {
    final hasTeamFilter = _teamFilter != 'ALL';
    final teamColor = _teamFilter == 'A'
        ? AppTheme.primaryRed
        : _teamFilter == 'B'
            ? Colors.blue
            : AppTheme.gold;

    return Container(
      color: AppTheme.cardBg,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // チーム選択チップ
          Row(
            children: [
              _teamChip('全体', 'ALL'),
              const SizedBox(width: 6),
              _teamChip('Aチーム', 'A'),
              const SizedBox(width: 6),
              _teamChip('Bチーム', 'B'),
              if (hasTeamFilter) ...[
                const SizedBox(width: 8),
                // 選手を選ぶボタン
                GestureDetector(
                  onTap: () => _showPlayerSelectSheet(provider),
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
                            : const Color(0xFF444444),
                      ),
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
        ],
      ),
    );
  }

  Widget _teamChip(String label, String value) {
    final isSelected = _teamFilter == value;
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

  Widget _buildPlayerComment(Player player) {
    final comment = _comments[player.id] ?? '分析中...';
    final hasData = !comment.contains('データがまだありません') &&
        !comment.contains('分析中');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasData
              ? AppTheme.gold.withValues(alpha: 0.3)
              : const Color(0xFF333333),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: hasData
                  ? LinearGradient(colors: [
                      AppTheme.gold.withValues(alpha: 0.2),
                      AppTheme.cardBg2,
                    ])
                  : null,
              color: hasData ? null : AppTheme.cardBg2,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hasData
                        ? AppTheme.gold.withValues(alpha: 0.2)
                        : AppTheme.cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: hasData ? AppTheme.gold : AppTheme.grey),
                  ),
                  child: Center(
                    child: Text(
                      player.number.isNotEmpty ? '#${player.number}' : '?',
                      style: TextStyle(
                        color: hasData ? AppTheme.gold : AppTheme.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text('${player.team}チーム',
                        style: const TextStyle(
                            color: AppTheme.grey, fontSize: 11)),
                  ],
                ),
                const Spacer(),
                if (hasData)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            color: AppTheme.gold, size: 12),
                        SizedBox(width: 4),
                        Text('AI分析完了',
                            style: TextStyle(
                                color: AppTheme.gold, fontSize: 10)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              comment,
              style: TextStyle(
                color: hasData ? AppTheme.lightGrey : AppTheme.grey,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
