enum PieceType { king, queen, rook, bishop, knight, pawn }

enum Side { white, black }

Side opposite(Side s) => s == Side.white ? Side.black : Side.white;

class Piece {
  final PieceType type;
  final Side side;

  const Piece(this.type, this.side);

  String get symbol => switch (type) {
        PieceType.king => '♚',
        PieceType.queen => '♛',
        PieceType.rook => '♜',
        PieceType.bishop => '♝',
        PieceType.knight => '♞',
        PieceType.pawn => '♟',
      };
}

class Move {
  final int fr, fc; // from row, from col
  final int tr, tc; // to row, to col

  const Move(this.fr, this.fc, this.tr, this.tc);
}

class ChessGame {
  List<List<Piece?>> board = _initialBoard();
  Side turn = Side.white;
  Move? lastMove;

  // ----- حالة اللعبة -----

  bool get isCheck => _isInCheck(board, turn);

  bool get hasLegalMoves => _allLegalMoves().isNotEmpty;

  bool get isCheckmate => isCheck && !hasLegalMoves;

  bool get isStalemate => !isCheck && !hasLegalMoves;

  // ----- الحركات -----

  /// يرجع الحركات القانونية لقطعة معينة (لو دور صاحبها).
  List<Move> legalMovesFrom(int r, int c) {
    final p = board[r][c];
    if (p == null || p.side != turn) return [];
    return _legalMoves(board, r, c);
  }

  void makeMove(Move m) {
    _applyMove(board, m);
    lastMove = m;
    turn = opposite(turn);
  }

  List<Move> _allLegalMoves() {
    final all = <Move>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p != null && p.side == turn) {
          all.addAll(_legalMoves(board, r, c));
        }
      }
    }
    return all;
  }

  // ----- دوال مساعدة (static) -----

  static bool inside(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  static List<List<Piece?>> _initialBoard() {
    final b = List.generate(8, (_) => List<Piece?>.filled(8, null));
    const backRank = [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.queen,
      PieceType.king,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ];
    for (int c = 0; c < 8; c++) {
      b[0][c] = Piece(backRank[c], Side.black);
      b[1][c] = const Piece(PieceType.pawn, Side.black);
      b[6][c] = const Piece(PieceType.pawn, Side.white);
      b[7][c] = Piece(backRank[c], Side.white);
    }
    return b;
  }

  static List<List<Piece?>> _copy(List<List<Piece?>> b) =>
      b.map((row) => List<Piece?>.from(row)).toList();

  static void _applyMove(List<List<Piece?>> b, Move m) {
    var piece = b[m.fr][m.fc]!;
    // الترقية التلقائية للوزير
    if (piece.type == PieceType.pawn && (m.tr == 0 || m.tr == 7)) {
      piece = Piece(PieceType.queen, piece.side);
    }
    b[m.tr][m.tc] = piece;
    b[m.fr][m.fc] = null;
  }

  /// الحركات المتاحة قبل التحقق من الكش (pseudo-legal).
  static List<Move> _pseudoMoves(List<List<Piece?>> b, int r, int c) {
    final p = b[r][c]!;
    final moves = <Move>[];

    void tryAdd(int tr, int tc) {
      if (!inside(tr, tc)) return;
      final t = b[tr][tc];
      if (t == null || t.side != p.side) moves.add(Move(r, c, tr, tc));
    }

    void slide(List<(int, int)> dirs) {
      for (final d in dirs) {
        var tr = r + d.$1, tc = c + d.$2;
        while (inside(tr, tc)) {
          final t = b[tr][tc];
          if (t == null) {
            moves.add(Move(r, c, tr, tc));
          } else {
            if (t.side != p.side) moves.add(Move(r, c, tr, tc));
            break;
          }
          tr += d.$1;
          tc += d.$2;
        }
      }
    }

    const diag = [(1, 1), (1, -1), (-1, 1), (-1, -1)];
    const orth = [(1, 0), (-1, 0), (0, 1), (0, -1)];
    const knightJumps = [
      (1, 2), (2, 1), (-1, 2), (-2, 1),
      (1, -2), (2, -1), (-1, -2), (-2, -1),
    ];
    const kingSteps = [
      (1, 0), (-1, 0), (0, 1), (0, -1),
      (1, 1), (1, -1), (-1, 1), (-1, -1),
    ];

    switch (p.type) {
      case PieceType.pawn:
        final dir = p.side == Side.white ? -1 : 1;
        final startRow = p.side == Side.white ? 6 : 1;
        // التقدم للأمام
        if (inside(r + dir, c) && b[r + dir][c] == null) {
          moves.add(Move(r, c, r + dir, c));
          if (r == startRow && b[r + 2 * dir][c] == null) {
            moves.add(Move(r, c, r + 2 * dir, c));
          }
        }
        // الأكل قطريًا
        for (final dc in [-1, 1]) {
          if (!inside(r + dir, c + dc)) continue;
          final t = b[r + dir][c + dc];
          if (t != null && t.side != p.side) {
            moves.add(Move(r, c, r + dir, c + dc));
          }
        }
        break;

      case PieceType.knight:
        for (final j in knightJumps) {
          tryAdd(r + j.$1, c + j.$2);
        }
        break;

      case PieceType.bishop:
        slide(diag);
        break;

      case PieceType.rook:
        slide(orth);
        break;

      case PieceType.queen:
        slide(diag);
        slide(orth);
        break;

      case PieceType.king:
        for (final s in kingSteps) {
          tryAdd(r + s.$1, c + s.$2);
        }
        break;
    }
    return moves;
  }

  /// الحركات القانونية: اللي متعملش كش على الملك نفسه.
  static List<Move> _legalMoves(List<List<Piece?>> b, int r, int c) {
    final p = b[r][c];
    if (p == null) return [];
    final result = <Move>[];
    for (final m in _pseudoMoves(b, r, c)) {
      final nb = _copy(b);
      _applyMove(nb, m);
      if (!_isInCheck(nb, p.side)) result.add(m);
    }
    return result;
  }

  static (int, int)? _findKing(List<List<Piece?>> b, Side side) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = b[r][c];
        if (p != null && p.type == PieceType.king && p.side == side) {
          return (r, c);
        }
      }
    }
    return null;
  }

  static bool _isInCheck(List<List<Piece?>> b, Side side) {
    final king = _findKing(b, side);
    if (king == null) return false;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = b[r][c];
        if (p != null && p.side != side) {
          for (final m in _pseudoMoves(b, r, c)) {
            if (m.tr == king.$1 && m.tc == king.$2) return true;
          }
        }
      }
    }
    return false;
  }
}
