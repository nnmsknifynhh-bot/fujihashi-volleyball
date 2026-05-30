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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateComments());
  }

  Future<void> _generateComments() async {
    setState(() => _isGenerating = true);
    final provider = Provider.of<AppProvider>(context, listen: false);

    final Map<String, String> newComments = {};
    for (final player in provider.players) {
      final serveStats = provider.getServeStatsByPlayer(player.id);
      final receiveStats = provider.getReceiveStatsByPlayer(player.id);
      newComments[player.id] = _generateComment(player, serveStats, receiveStats);
    }

    await Future.delayed(const Duration(milliseconds: 800)); // ローディング演出
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

    // サーブ分析
    if (total > 0) {
      final aceRate = (serveStats[ServeResult.ace] ?? 0) / total * 100;
      final underRate = (serveStats[ServeResult.under] ?? 0) / total * 100;
      final missRate = (serveStats[ServeResult.miss] ?? 0) / total * 100;
      final efficiency = ((serveStats[ServeResult.ace] ?? 0) - (serveStats[ServeResult.miss] ?? 0)) / total * 100;

      // エース率コメント
      if (aceRate >= 20) {
        comments.add('【サーブの特徴】サーブのエース率が${aceRate.toStringAsFixed(1)}%と非常に高く、相手チームにとって大きな脅威になっています。');
      } else if (aceRate >= 10) {
        comments.add('【サーブの特徴】エース率${aceRate.toStringAsFixed(1)}%は安定した水準です。さらなる向上を目指しましょう。');
      } else if (aceRate < 5 && total >= 5) {
        comments.add('【サーブの特徴】エース率${aceRate.toStringAsFixed(1)}%はやや低めです。サーブコースの多様化を練習しましょう。');
      }

      // 崩し率コメント
      if (underRate >= 35) {
        comments.add('【崩し能力】崩し率${underRate.toStringAsFixed(1)}%と高く、相手の攻撃を制限する効果的なサーブができています。組み立て力が光ります。');
      } else if (underRate < 20 && total >= 5) {
        comments.add('【崩し能力】崩し率${underRate.toStringAsFixed(1)}%はまだ改善の余地があります。コースを狙ったサーブを意識してみましょう。');
      }

      // ミス率コメント
      if (missRate >= 20) {
        comments.add('【改善ポイント】ミス率が${missRate.toStringAsFixed(1)}%と高めです。強打とコントロールのバランスを見直し、安定性を高めることが優先課題です。');
      } else if (missRate <= 5 && total >= 5) {
        comments.add('【安定性】ミス率${missRate.toStringAsFixed(1)}%と非常に安定したサーブを打てています。この安定性は試合で大きな武器になります。');
      }

      // 効率コメント
      if (efficiency >= 10) {
        comments.add('【サーブ効率】サーブ効率スコアが${efficiency.toStringAsFixed(1)}%と優秀です。チームへの貢献度が高い選手です。');
      } else if (efficiency < 0) {
        comments.add('【サーブ効率】現在サーブ効率がマイナスです。ミスを減らすことを第一に意識しましょう。');
      }

      // 練習提案（サーブ）
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
        comments.add('【レシーブ安定性】オーバーパス率${overRate.toStringAsFixed(1)}%と安定したレシーブができています。攻撃につながる質の高いパスです。');
      } else if (overRate >= 30) {
        comments.add('【レシーブ安定性】オーバーパス率${overRate.toStringAsFixed(1)}%は平均的な水準です。さらに向上できるよう練習を続けましょう。');
      }

      if (missRate >= 20) {
        comments.add('【レシーブ改善】レシーブミス率が${missRate.toStringAsFixed(1)}%です。落下点への移動を素早く行う練習が効果的です。');
      } else if (missRate <= 5 && rTotal >= 5) {
        comments.add('【レシーブ安定性】ミス率${missRate.toStringAsFixed(1)}%と非常に安定しています。チームの守備の要として活躍できます。');
      }
    }

    if (comments.isEmpty) {
      return '${player.name}選手のデータを分析中です（$total回サーブ、$rTotal回レシーブ）。引き続き記録を続けてください。';
    }

    return comments.join('\n\n');
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
            Text('AI 自動講評', style: TextStyle(color: AppTheme.gold, fontSize: 18)),
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
          if (_isGenerating) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.gold),
                  const SizedBox(height: 16),
                  const Text('AIが講評を生成しています...', style: TextStyle(color: AppTheme.gold)),
                  const SizedBox(height: 8),
                  Text(
                    '選手データを分析中',
                    style: TextStyle(color: AppTheme.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          final players = provider.players;
          if (players.isEmpty) {
            return const Center(
              child: Text('選手が登録されていません', style: TextStyle(color: AppTheme.grey)),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // ヘッダー説明
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.gold.withValues(alpha: 0.15),
                      AppTheme.cardBg,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.gold, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '蓄積されたサーブ・レシーブデータをもとに\nAIが自動で分析講評を生成します',
                        style: TextStyle(color: AppTheme.lightGrey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...players.map((p) => _buildPlayerComment(p)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayerComment(Player player) {
    final comment = _comments[player.id] ?? '分析中...';
    final hasData = !comment.contains('データがまだありません') && !comment.contains('分析中');

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
          // 選手ヘッダー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: hasData
                  ? LinearGradient(
                      colors: [
                        AppTheme.gold.withValues(alpha: 0.2),
                        AppTheme.cardBg2,
                      ],
                    )
                  : null,
              color: hasData ? null : AppTheme.cardBg2,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                      color: hasData ? AppTheme.gold : AppTheme.grey,
                    ),
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
                    Text(
                      player.name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${player.team}チーム',
                      style: const TextStyle(color: AppTheme.grey, fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                if (hasData)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: AppTheme.gold, size: 12),
                        SizedBox(width: 4),
                        Text('AI分析完了', style: TextStyle(color: AppTheme.gold, fontSize: 10)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // コメント内容
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
