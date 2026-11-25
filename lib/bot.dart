import 'dart:math';
import 'chess_logic.dart';

class BotLevel {
  final String name;
  final int rating;
  final int depth;    // عمق التفكير (أكبر = أذكى وأبطأ)
  final double noise; // قد إيه بيغلط (أكبر = أضعف)

  const BotLevel({
    required this.name,
    required this.rating,
    required this.depth,
    required this.noise,
  });
}

const List<BotLevel> botLevels = [
  BotLevel(name: 'روبوت مبتدئ', rating: 400, depth: 1, noise: 3.0),
  BotLevel(name: 'روبوت هاوي', rating: 800, depth: 1, noise: 1.5),
  BotLevel(name: 'روبوت متوسط', rating: 1200, depth: 2, noise: 0.8),
  BotLevel(name: 'روبوت قوي', rating: 1600, depth: 2, noise: 0.3),
  BotLevel(name: 'روبوت خبير', rating: 2000, depth: 3, noise: 0.05),
];

class ChessBot {
  final BotLevel level;
  final Random _rnd = Random();

  ChessBot(this.level);

  /// بيختار الحركة الأحسن حسب تقييم الروبوت.
  Move? chooseMove(ChessGame game) {
    final moves = _allMoves(game);
    if (moves.isEmpty) return null;

    Move? best;
    double bestScore = double.negativeInfinity;
    for (final m in moves) {
      final child = _clone(game)..makeMove(m);
      final score = -_search(
              child, level.depth - 1, double.negativeInfinity, double.infinity) +
          (_rnd.nextDouble() - 0.5) * 2 * level.noise;
      if (score > bestScore) {
        bestScore = score;
        best = m;
      }
    }
    return best;
  }

  /// Negamax مع Alpha-Beta
  double _search(ChessGame g, int depth, double alpha, double beta) {
    final moves = _allMoves(g);
    if (moves.isEmpty) return g.isCheck ? -1000 : 0; // كش مات أو باتّ
    if (depth == 0) return _evaluate(g);

    double best = double.negativeInfinity;
    for (final m in moves) {
      final child = _clone(g)..makeMove(m);
      final score = -_search(child, depth - 1, -beta, -alpha);
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  /// تقييم الوضع من ناحية اللاعب اللي دوره (المادة + قرب من المركز)
  double _evaluate(ChessGame g) {
    double score = 0;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = g.board[r][c];
        if (p == null) continue;
        final centre = 7 - ((r - 3.5).abs() + (c - 3.5).abs());
        final v = _value(p.type) + centre * 0.02;
        score += p.side == g.turn ? v : -v;
      }
    }
    return score;
  }

  static double _value(PieceType t) => switch (t) {
        PieceType.pawn => 1.0,
        PieceType.knight => 3.0,
        PieceType.bishop => 3.1,
        PieceType.rook => 5.0,
        PieceType.queen => 9.0,
        PieceType.king => 0.0,
      };

  static List<Move> _allMoves(ChessGame g) {
    final moves = <Move>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        moves.addAll(g.legalMovesFrom(r, c));
      }
    }
    return moves;
  }

  static ChessGame _clone(ChessGame g) => ChessGame()
    ..board = g.board.map((row) => List<Piece?>.from(row)).toList()
    ..turn = g.turn;
}
