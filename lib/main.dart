import 'package:flutter/material.dart';
import 'chess_logic.dart';
import 'bot.dart';
import 'sound.dart';

// ----- الإعدادات -----

class BoardTheme {
  final String name;
  final Color light;
  final Color dark;
  const BoardTheme(this.name, this.light, this.dark);
}

const List<BoardTheme> boardThemes = [
  BoardTheme('كلاسيك', Color(0xFFF0D9B5), Color(0xFFB58863)),
  BoardTheme('أخضر', Color(0xFFEEEED2), Color(0xFF769656)),
  BoardTheme('أزرق', Color(0xFFDEE3E6), Color(0xFF8CA2AD)),
  BoardTheme('بنفسجي', Color(0xFFE8E0F0), Color(0xFF8E7CC3)),
];

final ValueNotifier<int> boardThemeIndex = ValueNotifier(0);
final ValueNotifier<bool> darkMode = ValueNotifier(false);

void main() => runApp(const ChessApp());

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkMode,
      builder: (context, isDark, child) => MaterialApp(
        title: 'الشطرنج',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.brown,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        home: const HomePage(),
      ),
    );
  }
}

// ----- الصفحة الرئيسية -----

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Widget _menuButton(IconData icon, String text, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: SizedBox(
        width: 280,
        height: 56,
        child: FilledButton.icon(
          icon: Icon(icon),
          label: Text(text, style: const TextStyle(fontSize: 16)),
          onPressed: onTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('♟ الشطرنج'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'الإعدادات',
            onPressed: () => _open(context, const SettingsPage()),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuButton(Icons.smart_toy, 'لعب ضد روبوت',
                () => _open(context, const BotSelectPage())),
            _menuButton(Icons.people, 'لعب على نفس الجهاز',
                () => _open(context, const GamePage())),
            _menuButton(Icons.public, 'لعب أونلاين (قريبًا)', null),
          ],
        ),
      ),
    );
  }
}

// ----- اختيار الروبوت -----

class BotSelectPage extends StatelessWidget {
  const BotSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختار الروبوت'), centerTitle: true),
      body: ListView.builder(
        itemCount: botLevels.length,
        itemBuilder: (context, i) {
          final bot = botLevels[i];
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.smart_toy)),
            title: Text(bot.name),
            subtitle: Text('التقييم: ${bot.rating}'),
            trailing: const Icon(Icons.play_arrow),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GamePage(bot: bot)),
            ),
          );
        },
      ),
    );
  }
}

// ----- الإعدادات -----

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات'), centerTitle: true),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('شكل الرقعة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          ValueListenableBuilder<int>(
            valueListenable: boardThemeIndex,
            builder: (context, selected, child) => Column(
              children: [
                for (int i = 0; i < boardThemes.length; i++)
                  RadioListTile<int>(
                    value: i,
                    groupValue: selected,
                    onChanged: (v) {
                      if (v != null) boardThemeIndex.value = v;
                    },
                    title: Text(boardThemes[i].name),
                    secondary: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 24, height: 24, color: boardThemes[i].light),
                        Container(
                            width: 24, height: 24, color: boardThemes[i].dark),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          ValueListenableBuilder<bool>(
            valueListenable: darkMode,
            builder: (context, isDark, child) => SwitchListTile(
              title: const Text('الوضع الداكن'),
              value: isDark,
              onChanged: (v) => darkMode.value = v,
            ),
          ),
        ],
      ),
    );
  }
}

// ----- صفحة اللعب -----

class GamePage extends StatefulWidget {
  final BotLevel? bot; // لو null يبقى لعب على نفس الجهاز
  const GamePage({super.key, this.bot});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  ChessGame game = ChessGame();
  ChessBot? _bot;

  int? _selR;
  int? _selC;
  List<Move> _targets = [];
  bool _thinking = false;
  bool _dialogShown = false;

  static const Side _human = Side.white;

  @override
  void initState() {
    super.initState();
    final b = widget.bot;
    _bot = b == null ? null : ChessBot(b);
  }

  bool get _over => game.isCheckmate || game.isStalemate;
  bool get _botTurn => _bot != null && game.turn != _human;

  void _clearSelection() {
    _selR = null;
    _selC = null;
    _targets = [];
  }

  void _onTap(int r, int c) {
    if (_over || _thinking || _botTurn) return;

    // لو المربع ده هدف لقطعة متحددة، نفذ الحركة
    if (_selR != null) {
      for (final m in _targets) {
        if (m.tr == r && m.tc == c) {
          _applyMove(m);
          return;
        }
      }
    }

    final p = game.board[r][c];
    setState(() {
      if (p != null && p.side == game.turn) {
        _selR = r;
        _selC = c;
        _targets = game.legalMovesFrom(r, c);
      } else {
        _clearSelection();
      }
    });
  }

  void _applyMove(Move m) {
    final isCapture = game.board[m.tr][m.tc] != null;

    setState(() {
      game.makeMove(m);
      _clearSelection();
    });

    if (game.isCheckmate || game.isStalemate) {
      SoundFx.play(Sfx.gameOver);
      _showGameOver();
    } else if (game.isCheck) {
      SoundFx.play(Sfx.check);
    } else {
      SoundFx.play(isCapture ? Sfx.capture : Sfx.move);
    }

    if (!_over && _botTurn) _botMove();
  }

  Future<void> _botMove() async {
    setState(() => _thinking = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || !_botTurn || _over) return;

    final m = _bot!.chooseMove(game);
    setState(() => _thinking = false);
    if (m != null) _applyMove(m);
  }

  void _newGame() {
    setState(() {
      game = ChessGame();
      _clearSelection();
      _thinking = false;
      _dialogShown = false;
    });
  }

  void _showGameOver() {
    if (_dialogShown) return;
    _dialogShown = true;

    final mate = game.isCheckmate;
    final winner = game.turn == Side.white ? Side.black : Side.white;
    final winnerName = winner == Side.white ? 'الأبيض' : 'الأسود';

    final title = mate ? '🏆 كش مات!' : '🤝 تعادل!';
    final body = !mate
        ? 'انتهت المباراة بالتعادل (باتّ).'
        : (_bot != null && winner != _human)
            ? 'الروبوت فاز 🤖'
            : 'مبروك! الفائز: $winnerName';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _newGame();
            },
            child: const Text('مباراة جديدة'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('الصفحة الرئيسية'),
          ),
        ],
      ),
    );
  }

  String _status() {
    if (game.isCheckmate) return '🏆 كش مات!';
    if (game.isStalemate) return '🤝 تعادل (باتّ)';
    if (_thinking) return '🤖 الروبوت بيفكر...';
    final turnName = game.turn == Side.white ? 'الأبيض' : 'الأسود';
    return game.isCheck ? '⚠️ كش! دور $turnName' : 'دور $turnName';
  }

  Widget _buildSquare(
      int r, int c, BoardTheme theme, (int, int)? checkedKing) {
    final isLight = (r + c) % 2 == 0;
    Color base = isLight ? theme.light : theme.dark;

    // تمييز آخر حركة
    final last = game.lastMove;
    if (last != null &&
        ((last.fr == r && last.fc == c) || (last.tr == r && last.tc == c))) {
      base = Color.alphaBlend(const Color(0x88CDD26A), base);
    }

    // تمييز المربع المحدد
    if (_selR == r && _selC == c) {
      base = Color.alphaBlend(const Color(0xAA7FC97F), base);
    }

    final isTarget = _targets.any((m) => m.tr == r && m.tc == c);
    final piece = game.board[r][c];
    final isCheckSquare =
        checkedKing != null && checkedKing.$1 == r && checkedKing.$2 == c;

    return GestureDetector(
      onTap: () => _onTap(r, c),
      child: Container(
        color: base,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth;
            final labelColor = isLight ? theme.dark : theme.light;

            return Stack(
              alignment: Alignment.center,
              children: [
                // توهج أحمر على الملك اللي في كش
                if (isCheckSquare)
                  Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0xFFFF1744), Color(0x00FF1744)],
                        stops: [0.2, 1.0],
                      ),
                    ),
                  ),
                // نقطة توضح الحركات المتاحة
                if (isTarget)
                  Container(
                    width: size * 0.28,
                    height: size * 0.28,
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                  ),
                // القطعة
                if (piece != null)
                  Text(
                    piece.symbol,
                    style: TextStyle(
                      fontSize: size * 0.8,
                      height: 1.0,
                      color: piece.side == Side.white
                          ? Colors.white
                          : Colors.black,
                      shadows: [
                        Shadow(
                          blurRadius: 2,
                          color: piece.side == Side.white
                              ? Colors.black87
                              : Colors.white70,
                        ),
                      ],
                    ),
                  ),
                // الرقم (على العمود الأيسر)
                if (c == 0)
                  Positioned(
                    top: 2,
                    left: 4,
                    child: Text(
                      '${8 - r}',
                      style: TextStyle(
                        fontSize: size * 0.17,
                        fontWeight: FontWeight.bold,
                        color: labelColor,
                      ),
                    ),
                  ),
                // الحرف (على الصف السفلي)
                if (r == 7)
                  Positioned(
                    bottom: 1,
                    right: 4,
                    child: Text(
                      String.fromCharCode(97 + c),
                      style: TextStyle(
                        fontSize: size * 0.17,
                        fontWeight: FontWeight.bold,
                        color: labelColor,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _scaffold(BoardTheme theme) {
    // نحدد مكان الملك اللي في كش
    (int, int)? checkedKing;
    if (game.isCheck) {
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          final p = game.board[r][c];
          if (p != null && p.type == PieceType.king && p.side == game.turn) {
            checkedKing = (r, c);
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bot?.name ?? 'لعب على نفس الجهاز'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home),
          tooltip: 'الصفحة الرئيسية',
          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'مباراة جديدة',
            onPressed: _newGame,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _status(),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GridView.count(
                      crossAxisCount: 8,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (int r = 0; r < 8; r++)
                          for (int c = 0; c < 8; c++)
                            _buildSquare(r, c, theme, checkedKing),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: boardThemeIndex,
      builder: (context, idx, child) => _scaffold(boardThemes[idx]),
    );
  }
}
