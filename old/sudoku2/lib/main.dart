import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sudoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent.withOpacity(0.5)),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Times New Roman'),
          bodyMedium: TextStyle(fontFamily: 'Times New Roman'),
          titleLarge: TextStyle(fontFamily: 'Times New Roman'),
        ),
      ),
      home: const SudokuGame(),
    );
  }
}

class SudokuGame extends StatefulWidget {
  const SudokuGame({super.key});

  @override
  State<SudokuGame> createState() => _SudokuGameState();
}

class _SudokuGameState extends State<SudokuGame> {
  late List<List<int>> board;
  late List<List<bool>> fixedNumbers;
  int? selectedRow;
  int? selectedCol;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    initializeBoard();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void initializeBoard() {
    board = List.generate(9, (_) => List.filled(9, 0));
    fixedNumbers = List.generate(9, (_) => List.filled(9, false));
    
    // Example fixed numbers for 9x9 board
    board[0][0] = 5; fixedNumbers[0][0] = true;
    board[0][4] = 3; fixedNumbers[0][4] = true;
    board[1][1] = 7; fixedNumbers[1][1] = true;
    board[2][2] = 9; fixedNumbers[2][2] = true;
    board[3][3] = 1; fixedNumbers[3][3] = true;
    board[4][4] = 4; fixedNumbers[4][4] = true;
    board[5][5] = 6; fixedNumbers[5][5] = true;
    board[6][6] = 8; fixedNumbers[6][6] = true;
    board[7][7] = 2; fixedNumbers[7][7] = true;
    board[8][8] = 3; fixedNumbers[8][8] = true;
  }

  void selectCell(int row, int col) {
    if (!fixedNumbers[row][col]) {
      setState(() {
        selectedRow = row;
        selectedCol = col;
      });
      _focusNode.requestFocus();
    }
  }

  void handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent && selectedRow != null && selectedCol != null) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.digit1 ||
          key == LogicalKeyboardKey.digit2 ||
          key == LogicalKeyboardKey.digit3 ||
          key == LogicalKeyboardKey.digit4 ||
          key == LogicalKeyboardKey.digit5 ||
          key == LogicalKeyboardKey.digit6 ||
          key == LogicalKeyboardKey.digit7 ||
          key == LogicalKeyboardKey.digit8 ||
          key == LogicalKeyboardKey.digit9) {
        final number = int.parse(key.keyLabel);
        if (!fixedNumbers[selectedRow!][selectedCol!]) {
          setState(() {
            board[selectedRow!][selectedCol!] = number;
          });
        }
      } else if (key == LogicalKeyboardKey.backspace || 
                 key == LogicalKeyboardKey.delete) {
        if (!fixedNumbers[selectedRow!][selectedCol!]) {
          setState(() {
            board[selectedRow!][selectedCol!] = 0;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: handleKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'sudoku',
            style: TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 24,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Stack(
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(2.0),
                constraints: const BoxConstraints(maxWidth: 400),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 9,
                    childAspectRatio: 1.0,
                    mainAxisSpacing: 0.5,
                    crossAxisSpacing: 0.5,
                  ),
                  itemCount: 81,
                  itemBuilder: (context, index) {
                    final row = index ~/ 9;
                    final col = index % 9;
                    final isSelected = row == selectedRow && col == selectedCol;
                    final isFixed = fixedNumbers[row][col];
                    
                    return GestureDetector(
                      onTap: () => selectCell(row, col),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.redAccent.withOpacity(0.2) : Colors.white,
                          border: Border.all(color: Colors.black, width: 0.5),
                        ),
                        child: Center(
                          child: Text(
                            board[row][col] == 0 ? '' : board[row][col].toString(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontFamily: 'Times New Roman',
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: 20,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    initializeBoard();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text(
                  'New Game',
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: ElevatedButton(
                onPressed: () {
                  exit(0);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text(
                  'Quit',
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
