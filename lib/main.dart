import 'package:flutter/material.dart';
import 'chess_logic.dart';

void main() => runApp(const ChessApp());

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.brown),
      home: const ChessPage(),
    );
  }
}

class ChessPage extends StatefulWidget {
  const ChessPage({super.key});

  @override
  State<ChessPage> createState() => _ChessPageState();
}

class _ChessPageState extends State<ChessPage> {
  ChessGame game = ChessGame();

  int? _selR;
  int? _selC;
  List<Move> _targets = [];

  void _clearSelection() {
    _selR = null;
    _selC = null;
    _targets = [];
  }

  void _onTap(int r, int c) {
    if (game.isCheckmate || game.isStalemate) return;

    setState(() {
      // 1) لو في قطعة متحددة والمربع ده هدف لحركة قانونية، نفذ الحركة
      if (_selR != null) {
        for (final m in _targets) {
          if (m.tr == r && m.tc == c) {
            game.makeMove(m);
            _clearSelection();
            return;
          }
        }
      }

      // 2) لو المربع فيه قطعة تبع اللاعب اللي دوره، حددها
      final p = game.board[r][c];
      if (p != null && p.side == game.turn) {
        _selR = r;
        _selC = c;
        _targets = game.legalMovesFrom(r, c);
      } else {
        // 3) غير كده ألغي التحديد
        _clearSelection();
      }
    });
  }

  void _reset() {
    setState(() {
      game = ChessGame();
      _clearSelection();
    });
  }

  String get _turnName => game.turn == Side.white ? 'الأبيض' : 'الأسود';

  String get _statusText {
    if (game.isCheckmate) {
      final winner = game.turn == Side.white ? 'الأسود' : 'الأبيض';
      return '🏆 كش مات! الفائز: $winner';
    }
    if (game.isStalemate) return '🤝 تعادل (باتّ)!';
    if (game.isCheck) return '⚠️ كش! دور $_turnName';
    return 'دور $_turnName';
  }

  Widget _buildSquare(int r, int c) {
    final isLight = (r + c) % 2 == 0;
    Color color = isLight ? const Color(0xFFF0D9B5) : const Color(0xFFB58863);

    // تمييز آخر حركة
    final last = game.lastMove;
    if (last != null &&
        ((last.fr == r && last.fc == c) || (last.tr == r && last.tc == c))) {
      color = isLight ? const Color(0xFFCDD26A) : const Color(0xFFAAA23A);
    }

    // تمييز المربع المحدد
    if (_selR == r && _selC == c) {
      color = const Color(0xFF7FC97F);
    }

    final isTarget = _targets.any((m) => m.tr == r && m.tc == c);
    final piece = game.board[r][c];

    return GestureDetector(
      onTap: () => _onTap(r, c),
      child: Container(
        color: color,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            alignment: Alignment.center,
            children: [
              // نقطة توضح المربعات المتاحة للحركة
              if (isTarget)
                Container(
                  width: constraints.maxWidth * 0.25,
                  height: constraints.maxWidth * 0.25,
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                ),
              // القطعة نفسها
              if (piece != null)
                Text(
                  piece.symbol,
                  style: TextStyle(
                    fontSize: constraints.maxWidth * 0.8,
                    height: 1.0,
                    color: piece.side == Side.white ? Colors.white : Colors.black,
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('♟ لعبة شطرنج'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'لعبة جديدة',
            onPressed: _reset,
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
                  _statusText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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
                          for (int c = 0; c < 8; c++) _buildSquare(r, c),
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
}
