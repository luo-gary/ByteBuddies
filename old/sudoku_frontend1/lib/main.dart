import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SudokuService {
  static const String baseUrl =
      'http://localhost:8000'; // Change this to your backend URL

  // Get a new puzzle
  static Future<List<List<int?>>> getNewPuzzle() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/puzzle'));
      if (response.statusCode == 200) {
        final List<List<dynamic>> data = json.decode(response.body);
        return data
            .map((row) => row.map((cell) => cell as int?).toList())
            .toList();
      } else {
        throw Exception('Failed to load puzzle');
      }
    } catch (e) {
      // Return a default puzzle if the server is not available
      return [
        [5, 3, null, null, 7, null, null, null, null],
        [6, null, null, 1, 9, 5, null, null, null],
        [null, 9, 8, null, null, null, null, 6, null],
        [8, null, null, null, 6, null, null, null, 3],
        [4, null, null, 8, null, 3, null, null, 1],
        [7, null, null, null, 2, null, null, null, 6],
        [null, 6, null, null, null, null, 2, 8, null],
        [null, null, null, 4, 1, 9, null, null, 5],
        [null, null, null, null, 8, null, null, 7, 9],
      ];
    }
  }

  // Validate the entire puzzle
  static Future<bool> validatePuzzle(List<List<int?>> puzzle) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/validate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(puzzle),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['valid'] as bool;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get a hint for the current puzzle state
  static Future<Map<String, dynamic>?> getHint(
      List<List<int?>> currentPuzzle) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/hint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(currentPuzzle),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

// Custom painter for the grid lines
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final greenPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final blackPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw main green lines
    // Horizontal green lines
    final oneThird = size.height / 3;
    canvas.drawLine(
      Offset(0, oneThird),
      Offset(size.width, oneThird),
      greenPaint,
    );
    canvas.drawLine(
      Offset(0, oneThird * 2),
      Offset(size.width, oneThird * 2),
      greenPaint,
    );

    // Vertical green lines
    final oneThirdWidth = size.width / 3;
    canvas.drawLine(
      Offset(oneThirdWidth, 0),
      Offset(oneThirdWidth, size.height),
      greenPaint,
    );
    canvas.drawLine(
      Offset(oneThirdWidth * 2, 0),
      Offset(oneThirdWidth * 2, size.height),
      greenPaint,
    );

    // Draw smaller black lines in each section
    final smallSection = size.width / 9; // Since we want 9x9 grid

    // Draw vertical black lines
    for (var i = 1; i < 9; i++) {
      if (i % 3 != 0) {
        // Skip where green lines are
        canvas.drawLine(
          Offset(smallSection * i, 0),
          Offset(smallSection * i, size.height),
          blackPaint,
        );
      }
    }

    // Draw horizontal black lines
    for (var i = 1; i < 9; i++) {
      if (i % 3 != 0) {
        // Skip where green lines are
        canvas.drawLine(
          Offset(0, smallSection * i),
          Offset(size.width, smallSection * i),
          blackPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class SudokuGrid extends StatelessWidget {
  final Function(int, int) onCellTap;
  final List<List<int?>> board;
  final List<List<int?>> initialBoard;
  final List<List<bool>> invalidCells;
  final int? selectedRow;
  final int? selectedCol;

  const SudokuGrid({
    super.key,
    required this.onCellTap,
    required this.board,
    required this.initialBoard,
    required this.invalidCells,
    required this.selectedRow,
    required this.selectedCol,
  });

  bool isInitialValue(int row, int col) {
    return initialBoard[row][col] != null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          painter: GridPainter(),
          child: Container(),
        ),
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
          ),
          itemCount: 81,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final row = index ~/ 9;
            final col = index % 9;
            final isSelected = row == selectedRow && col == selectedCol;
            final isInitial = isInitialValue(row, col);

            return GestureDetector(
              onTap: isInitial ? null : () => onCellTap(row, col),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected && !isInitial
                      ? Colors.white
                      : Colors.transparent,
                  border: isSelected && !isInitial
                      ? Border.all(color: Colors.blue.shade200, width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    board[row][col]?.toString() ?? '',
                    style: TextStyle(
                      fontSize: isSelected ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: isInitial ? Colors.grey[600] : Colors.black,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

void main() {
  runApp(const MyApp());
}

// Custom TextInputFormatter for numbers 1-9
class OneToNineInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // If the new value is empty, allow it
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Try to parse the number
    final int? number = int.tryParse(newValue.text);

    // Only allow if the number is between 1 and 9
    if (number != null && number >= 1 && number <= 9) {
      return newValue;
    }

    // If invalid, return the old value
    return oldValue;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ByteBuddies',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final TextEditingController textController = TextEditingController();
  int? selectedRow;
  int? selectedCol;
  String statusMessage = '';
  late List<List<int?>> sudokuBoard;
  late List<List<bool>> invalidCells;
  late final List<List<int?>> initialBoard;

  @override
  void initState() {
    super.initState();
    _initializeBoard();
  }

  Future<void> _initializeBoard() async {
    try {
      final newPuzzle = await SudokuService.getNewPuzzle();
      setState(() {
        initialBoard = newPuzzle;
        sudokuBoard = List.generate(
          9,
          (i) => List.generate(9, (j) => initialBoard[i][j]),
        );
        invalidCells = List.generate(
          9,
          (_) => List.generate(9, (_) => false),
        );
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Failed to load puzzle';
      });
    }
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  void onCellTap(int row, int col) {
    // Only allow selecting cells that weren't initially filled
    if (initialBoard[row][col] == null) {
      setState(() {
        selectedRow = row;
        selectedCol = col;
        statusMessage = '';
      });
    }
  }

  void onNumberSubmit() {
    setState(() {
      if (selectedRow == null || selectedCol == null) {
        statusMessage = 'Please choose a cell first';
        return;
      }

      if (textController.text.isEmpty) {
        statusMessage = 'Please input a number';
        return;
      }

      if (initialBoard[selectedRow!][selectedCol!] != null) {
        statusMessage = 'Cannot modify initial values';
        return;
      }

      // All validation passed, update the grid
      sudokuBoard[selectedRow!][selectedCol!] = int.parse(textController.text);
      statusMessage = '';
      textController.clear();
    });
  }

  // Add a method to handle hint requests
  Future<void> _getHint() async {
    final hint = await SudokuService.getHint(sudokuBoard);
    if (hint != null) {
      setState(() {
        final row = hint['row'] as int;
        final col = hint['col'] as int;
        final value = hint['value'] as int;
        final message =
            hint['message'] as String; // Get the message from the hint
        statusMessage = message; // Display the message directly

        // Highlight the suggested cell
        selectedRow = row;
        selectedCol = col;
      });
    } else {
      setState(() {
        statusMessage = 'No hint available';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.375,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 2),
                          color: Colors.grey[200],
                        ),
                        child: SudokuGrid(
                          onCellTap: onCellTap,
                          board: sudokuBoard,
                          initialBoard: initialBoard,
                          invalidCells: invalidCells,
                          selectedRow: selectedRow,
                          selectedCol: selectedCol,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                FractionallySizedBox(
                  widthFactor: 0.375,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width / 3,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _getHint,
                      child: const Text(
                        '?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                if (statusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      statusMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  ),
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: textController,
                    maxLines: 1,
                    maxLength: 1,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => onNumberSubmit(),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      OneToNineInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter a number (1-9)',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      counterText: '',
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
