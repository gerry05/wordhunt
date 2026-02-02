import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../wordsearch_maker.dart';
import 'package:wordhunt/globals.dart' as globals;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wordhunt/data/data_storage.dart';
import 'package:confetti/confetti.dart';

class WordSearchScreen extends StatefulWidget {
  final Map<String, String> category;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  const WordSearchScreen({
    super.key,
    required this.category,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  _WordSearchScreenState createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends State<WordSearchScreen> {
  final List<List<String>> grid = [];
  final Set<Offset> selectedCells = {};
  Set<Offset> foundCells = {}; // New: Keep track of correctly found words
  List<String> wordsToFind = [];
  final List<String> foundWords = []; // New: Keep track of found words
  Offset? startCell;
  Offset? lastCell;
  Direction? direction;
  int remainingWords = 6;
  String selectedLetters = "";

  late ConfettiController _confettiController;

  final correctAudio = AudioPlayer();
  final wrongAudio = AudioPlayer();
  final congratsAudio = AudioPlayer();

  bool isLoading = true;
  bool hasError = false;

  final storage = const FlutterSecureStorage();

  @override
  initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 10));
    configureAudio();
    fetchGameDataFromGemini(); // Call to fetch data
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> fetchGameDataFromGemini() async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: globals.geminiApiKey, // Replace with your actual API key
      );
      final prompt =
          "Generate a JSON OBJECT for 6 english words related to ${widget.category['description']}. The maximum word length is 10 characters. "
          "Exclude these words ${globals.storeWordsFound.join(", ")} "
          "The JSON object should have the following structure: "
          "{"
          "  \"wordsToFind\": ["
          "    \"DATA\","
          "    \"LEGEND\","
          "    \"TITLE\","
          "    \"BARGRAPH\","
          "    \"SCALE\""
          "  ]"
          "} "
          "Think about random words related to technology that you can use in a word search puzzle."
          "The word must be unique and not repeated in each prompt. ";

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      // Handle potential empty response
      if (response.text == null || response.text!.isEmpty) {
        hasError = true;
        setState(() {
          isLoading = false;
        });
        throw Exception("Gemini API returned an empty response.");
      }

      final gameData = parseGameDataFromResponse(response.text!.trim());

      debugPrint("gameData: $gameData", wrapWidth: 1024);
      if (gameData.isEmpty) {
        hasError = true;
        setState(() {
          isLoading = false;
        });
      }

      setState(() {
        if (gameData.isNotEmpty) {
          grid.clear();
          wordsToFind.clear();
          wordsToFind.addAll(List<String>.from(gameData["wordsToFind"]));
          List<List<String>> initGrid =
              List.generate(10, (i) => List.generate(10, (j) => ' '));

          // Step 1: Place words in the grid
          placeWordsInGrid(initGrid, wordsToFind);

          // Step 2: Fill remaining spaces with random letters
          fillRandomLetters(initGrid);

          // Step 3: Print the grid
          //printGrid(initGrid);
          grid.addAll(initGrid);
          remainingWords = wordsToFind.length;
          isLoading = false;
        }
      });
    } catch (e) {
      debugPrint("Error fetching game data from Gemini: $e");
      // Handle errors appropriately, e.g., show an error message to the user
      hasError = true;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading game data. Please try again later."),
          // content: Text("${e.toString()}"),
        ),
      );
    }
  }

  Map<String, dynamic> parseGameDataFromResponse(String response) {
    try {
      // Attempt to extract the JSON string using a regex
      RegExp jsonRegex =
          RegExp(r'\{.*\}', dotAll: true); // Get the entire object
      final match = jsonRegex.firstMatch(response);
      if (match == null) {
        debugPrint('Could not find json using regex');
        return {};
      }
      String jsonString = match.group(0)!;

      return jsonDecode(jsonString);
    } catch (e) {
      debugPrint("Error parsing Gemini response: $e");
      debugPrint(
          "Response: $response"); // Log the actual response for debugging
      return {};
    }
  }

  configureAudio() async {
    try {
      await correctAudio.setAsset('assets/audio/correct.wav');
      await wrongAudio.setAsset('assets/audio/wrong.wav');
      await congratsAudio.setAsset('assets/audio/win.wav');
      //   debugPrint("Audio assets loaded");
    } catch (e) {
      debugPrint("Error loading audio assets: $e");
    }
  }

  playAudio({required String type}) async {
    try {
      switch (type) {
        case "correct":
          await correctAudio.stop();
          await correctAudio.seek(Duration.zero);
          await correctAudio.play();

          break;
        case "wrong":
          await wrongAudio.stop();
          await wrongAudio.seek(Duration.zero);
          await wrongAudio.play();

          break;
        case "congrats":
          await congratsAudio.stop();
          await congratsAudio.seek(Duration.zero);
          await congratsAudio.play();

          break;
      }
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  // Add this method to get the selected word
  String getSelectedWord() {
    if (selectedCells.isEmpty) return '';

    // Convert selected cells to a list and sort them
    List<Offset> sortedCells = selectedCells.toList()
      ..sort((a, b) {
        // Sort based on direction
        switch (direction) {
          case Direction.horizontal:
            return a.dx.compareTo(b.dx);
          case Direction.vertical:
            return a.dy.compareTo(b.dy);
          case Direction.diagonal:
            return a.dx.compareTo(b.dx); // For diagonal, sort by x coordinate
          default:
            return 0;
        }
      });

    // Build the word from sorted cells
    String word = '';
    //debugPrint("$sortedCells");
    for (var cell in sortedCells) {
      int row = cell.dy.toInt();
      int col = cell.dx.toInt();
      word += grid[row][col];
    }
    return word;
  }

  void checkWord(String selectedWord) {
    // Check forward and backward
    String reversedWord =
        String.fromCharCodes(selectedWord.runes.toList().reversed);

    if (wordsToFind.contains(selectedWord) &&
        !foundWords.contains(selectedWord)) {
      // Word found
      foundWords.add(selectedWord);
      foundCells.addAll(selectedCells);
      playAudio(type: "correct");
    } else if (wordsToFind.contains(reversedWord) &&
        !foundWords.contains(reversedWord)) {
      // Reversed word found
      foundWords.add(reversedWord);

      foundCells.addAll(selectedCells);
      playAudio(type: "correct");
    } else {
      playAudio(type: "wrong");
    }
    //debugPrint("foundCells: $foundCells", wrapWidth: 1024);
    remainingWords = wordsToFind.length - foundWords.length;
    if (remainingWords == 0) {
      _confettiController.play();
      playAudio(type: "congrats");
      globals.storeWordsFound.addAll(foundWords);
      try {
        DataStorage().gameStoreWords(globals.storeWordsFound);
      } catch (e) {
        debugPrint("Error storing words: $e");
      }
      _showWinDialog();
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WinDialog(
        foundWords: foundWords,
        onPlayAgain: () {
          Navigator.of(context).pop();
          reloadGame();
        },
      ),
    );
  }

  reloadGame() {
    setState(() {
      isLoading = true;
      selectedCells.clear();
      selectedLetters = "";
      startCell = null;
      lastCell = null;
      direction = null;
      foundCells.clear();
      foundWords.clear();
      remainingWords = 6;

      fetchGameDataFromGemini();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 900;

    if (isLoading) {
      return const _GamifiedLoadingScreen();
    }

    if (hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: colorScheme.error,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                "Oops! Something went wrong.",
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "We couldn't load the game data. Please check your connection and try again.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    hasError = false;
                  });
                  reloadGame();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Try Again"),
              ),
            ],
          ),
        ),
      );
    }

    final gameContent = isLargeScreen
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left side: Game Board
              Flexible(
                flex: 3,
                child: Column(
                  children: [
                    wordHuntBoard(),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              // Right side: Info and Controls
              Flexible(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSelectedLettersDisplay(colorScheme, theme),
                    const SizedBox(height: 32),
                    _buildProgressSection(colorScheme, theme),
                    const SizedBox(height: 32),
                    if (remainingWords == 0) _buildPlayAgainButton(),
                  ],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildSelectedLettersDisplay(colorScheme, theme),
              const SizedBox(height: 32),
              wordHuntBoard(),
              const SizedBox(height: 32),
              _buildProgressSection(colorScheme, theme),
              const SizedBox(height: 24),
              if (remainingWords == 0) _buildPlayAgainButton(),
            ],
          );

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: gameContent,
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [
            Colors.green,
            Colors.blue,
            Colors.pink,
            Colors.orange,
            Colors.purple
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedLettersDisplay(
      ColorScheme colorScheme, ThemeData theme) {
    return AnimatedOpacity(
      opacity: selectedLetters.isEmpty ? 0 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          selectedLetters.isEmpty ? " " : selectedLetters,
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          totalWordsRemainingWidget(),
          const SizedBox(height: 16),
          remainingWordsWidget(),
        ],
      ),
    );
  }

  Widget _buildPlayAgainButton() {
    return Center(
      child: FilledButton.tonalIcon(
        onPressed: reloadGame,
        icon: const Icon(Icons.replay_rounded),
        label: const Text("Play Again"),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
    );
  }

  Widget remainingWordsWidget() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (var word in wordsToFind) remainingWordWidget(word),
      ],
    );
  }

  Widget remainingWordWidget(String word) {
    final colorScheme = Theme.of(context).colorScheme;
    bool isFound = foundWords.contains(word);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isFound ? colorScheme.primary : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFound ? Colors.transparent : colorScheme.outlineVariant,
        ),
        boxShadow: isFound
            ? [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
            : [],
      ),
      child: Text(
        word,
        style: TextStyle(
          color: isFound ? colorScheme.onPrimary : colorScheme.onSurface,
          fontSize: 14,
          fontWeight: isFound ? FontWeight.bold : FontWeight.normal,
          decoration: isFound ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }

  Widget totalWordsRemainingWidget() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Words Remaining: ",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          "$remainingWords",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget wordHuntBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colorScheme = Theme.of(context).colorScheme;
        final size = MediaQuery.of(context).size;
        final isLargeScreen = size.width > 900;

        // Calculate available height (Viewport height - AppBar - Padding - Other UI elements)
        // We subtract a safe margin (approx 250-300px) for the other UI elements
        double availableHeight = size.height - 250;
        if (!isLargeScreen) {
          // In column layout, we need more space for selected letters and word list
          availableHeight = size.height - 400;
        }

        double gridWidth = constraints.maxWidth * 0.95;
        if (isLargeScreen) {
          gridWidth = constraints.maxWidth * 0.9;
        }

        // The board should be square, so take the minimum of width and available height
        double boardDimension =
            gridWidth < availableHeight ? gridWidth : availableHeight;

        // Caps to prevent it from getting too large or too small
        boardDimension = boardDimension.clamp(280.0, 600.0);

        double cellSize =
            (boardDimension - (grid[0].length * 2)) / grid[0].length;

        return Listener(
          onPointerDown: (_) {
            if (remainingWords > 0) {
              widget.onInteractionStart?.call();
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onPanStart: (details) {
              if (remainingWords == 0) return;
              final cell =
                  _getCellFromOffset(details.localPosition, cellSize + 2);
              if (cell != null) {
                setState(() {
                  startCell = cell;
                  lastCell = cell;
                  selectedCells.clear();
                  selectedCells.add(cell);
                  selectedLetters = grid[cell.dy.toInt()][cell.dx.toInt()];
                  direction = null;
                });
              }
            },
            onPanUpdate: (details) {
              if (remainingWords == 0 || startCell == null) return;
              final cell =
                  _getCellFromOffset(details.localPosition, cellSize + 2);
              if (cell != null && _isValidCell(cell)) {
                setState(() {
                  selectedCells.add(cell);
                  lastCell = cell;
                  selectedLetters = getSelectedWord();
                });
              }
            },
            onPanEnd: (details) {
              if (remainingWords == 0) {
                widget.onInteractionEnd?.call();
                return;
              }
              String selectedWord = getSelectedWord();
              checkWord(selectedWord);

              setState(() {
                if (!foundCells.containsAll(selectedCells)) {
                  selectedCells.clear();
                  selectedLetters = "";
                }
                startCell = null;
                lastCell = null;
                direction = null;
              });
              widget.onInteractionEnd?.call();
            },
            onPanCancel: () {
              widget.onInteractionEnd?.call();
              setState(() {
                selectedCells.clear();
                selectedLetters = "";
                startCell = null;
                lastCell = null;
                direction = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: grid.asMap().entries.map((entry) {
                  int row = entry.key;
                  List<String> cols = entry.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: cols.asMap().entries.map((entry) {
                      int col = entry.key;
                      String letter = entry.value;
                      Offset currentCell =
                          Offset(col.toDouble(), row.toDouble());
                      bool isSelected = selectedCells.contains(currentCell);
                      bool isFound = foundCells.contains(currentCell);

                      Color cellColor = Colors.transparent;
                      Color textColor = colorScheme.onSurface;

                      if (isFound) {
                        cellColor = colorScheme.primaryContainer;
                        textColor = colorScheme.onPrimaryContainer;
                      }
                      if (isSelected) {
                        cellColor = colorScheme.secondary;
                        textColor = colorScheme.onSecondary;
                      }

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: cellSize,
                        height: cellSize,
                        alignment: Alignment.center,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: cellColor,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected || isFound
                              ? null
                              : Border.all(
                                  color: colorScheme.outlineVariant
                                      .withOpacity(0.5)),
                        ),
                        child: Text(
                          letter,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: isSelected || isFound
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: cellSize * 0.45,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Offset? _getCellFromOffset(Offset localPosition, double cellSize) {
    // localPosition is relative to the GestureDetector which has a Container with 4px padding
    final relativeX = localPosition.dx - 4;
    final relativeY = localPosition.dy - 4;

    // Calculate row and column
    final col = (relativeX / cellSize).floor();
    final row = (relativeY / cellSize).floor();

    // Check if within bounds
    if (row >= 0 && row < grid.length && col >= 0 && col < grid[0].length) {
      return Offset(col.toDouble(), row.toDouble());
    }
    return null;
  }

  bool _isValidCell(Offset cell) {
    if (selectedCells.contains(cell)) return false;

    if (selectedCells.length < 2) {
      return true;
    }

    if (direction == null) {
      final firstCell = selectedCells.elementAt(0);
      final secondCell = selectedCells.elementAt(1);
      final dx = secondCell.dx - firstCell.dx;
      final dy = secondCell.dy - firstCell.dy;

      if (dx == 0 && dy == 0) return false;

      if (dx == 0) {
        direction = Direction.vertical;
      } else if (dy == 0) {
        direction = Direction.horizontal;
      } else if (dx.abs() == dy.abs()) {
        direction = Direction.diagonal;
      } else {
        return false;
      }
    }

    final dx = cell.dx - lastCell!.dx;
    final dy = cell.dy - lastCell!.dy;

    switch (direction) {
      case Direction.horizontal:
        return dy == 0 && (dx == 1 || dx == -1);
      case Direction.vertical:
        return dx == 0 && (dy == 1 || dy == -1);
      case Direction.diagonal:
        return dx.abs() == 1 && dy.abs() == 1;
      default:
        return false;
    }
  }
}

class _GamifiedLoadingScreen extends StatefulWidget {
  const _GamifiedLoadingScreen();

  @override
  State<_GamifiedLoadingScreen> createState() => _GamifiedLoadingScreenState();
}

class _GamifiedLoadingScreenState extends State<_GamifiedLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _messageIndex = 0;
  final List<String> _messages = [
    "AI is hunting for words...",
    "AI is thinking...",
    "Sharpening the pencils...",
    "Generating the grid...",
    "Hiding the secrets...",
    "Almost there...",
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _cycleMessages();
  }

  void _cycleMessages() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _messages.length;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                ),
                RotationTransition(
                  turns: _controller,
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                ),
                Icon(
                  Icons.search_rounded,
                  size: 40,
                  color: colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 40),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _messages[_messageIndex],
                key: ValueKey(_messages[_messageIndex]),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Preparing your Word Hunt adventure",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => _LoadingDot(index: index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingDot extends StatefulWidget {
  final int index;
  const _LoadingDot({required this.index});

  @override
  State<_LoadingDot> createState() => _LoadingDotState();
}

class _LoadingDotState extends State<_LoadingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          widget.index * 0.2,
          0.6 + (widget.index * 0.2),
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _WinDialog extends StatelessWidget {
  final List<String> foundWords;
  final VoidCallback onPlayAgain;

  const _WinDialog({
    required this.foundWords,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "VICTORY!",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Masterfully solved!",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              // Word Stats
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      "FOUND WORDS",
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: foundWords.asMap().entries.map((entry) {
                        final index = entry.key;
                        final word = entry.value;
                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 400 + (index * 100)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              word,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Actions
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onPlayAgain,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text(
                        "PLAY AGAIN",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: colorScheme.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        "MAIN MENU",
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum Direction {
  horizontal,
  vertical,
  diagonal,
}
