import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../wordsearch_maker.dart';
import 'package:wordhunt/globals.dart' as globals;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wordhunt/data/data_storage.dart';

class WordSearchScreen extends StatefulWidget {
  final Map<String, String> category;
  const WordSearchScreen({super.key, required this.category});

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

  final correctAudio = AudioPlayer();
  final wrongAudio = AudioPlayer();
  final congratsAudio = AudioPlayer();

  bool isLoading = true;
  bool hasError = false;

  final storage = const FlutterSecureStorage();

  @override
  initState() {
    super.initState();

    configureAudio();
    fetchGameDataFromGemini(); // Call to fetch data
  }

  Future<void> fetchGameDataFromGemini() async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash-exp',
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
          // content: Text("Error loading game data. Please try again later."),
          content: Text("${e.toString()}"),
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
      playAudio(type: "congrats");
      globals.storeWordsFound.addAll(foundWords);
      try {
        DataStorage().gameStoreWords(globals.storeWordsFound);
      } catch (e) {
        debugPrint("Error storing words: $e");
      }
    }
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
    return isLoading
        ? Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(
                  height: 20,
                ),
                Text("Loading game data..."),
              ],
            ),
          )
        : Visibility(
            visible: !hasError,
            replacement: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 50,
                ),
                SizedBox(
                  height: 20,
                ),
                Text("Error loading game data. Please try again later."),
                SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                  onPressed: () {
                    hasError = false;
                    reloadGame();
                  },
                  child: Text(
                    "Try Again",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: selectedLetters.isEmpty
                          ? Colors.transparent
                          : Colors.blueAccent),
                  child: Text("$selectedLetters",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
                SizedBox(
                  height: 20,
                ),
                wordHuntBoard(),
                SizedBox(
                  height: 10,
                ),
                totalWordsRemaining(),
                SizedBox(
                  height: 10,
                ),
                remainingWordsWidget(),
                Visibility(
                  visible: remainingWords == 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.all<Color>(Colors.blue),
                          foregroundColor:
                              MaterialStateProperty.all<Color>(Colors.white),
                        ),
                        onPressed: () {
                          reloadGame();
                        },
                        child: Text("Play Again"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
  }

  Widget remainingWordsWidget() {
    return Wrap(
      children: [
        for (var word in wordsToFind) remainingWordWidget(word),
      ],
    );
  }

  Widget remainingWordWidget(String word) {
    bool isFound = foundWords.contains(word);
    return Container(
      padding: const EdgeInsets.all(4),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: isFound ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(15)),
      child: Text(
        word,
        style: TextStyle(
            color: isFound ? Colors.white : Colors.black, fontSize: 12),
      ),
    );
  }

  Widget totalWordsRemaining() {
    String displayRemaining = "Total Words Remaining: $remainingWords";
    if (remainingWords == 0) {
      displayRemaining = "Congratulations! 🎉🎉";
    }
    return Text(
      displayRemaining,
    );
  }

  Widget wordHuntBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double gridWidth = constraints.maxWidth * 0.8;
        if (constraints.maxWidth < 600) {
          gridWidth = constraints.maxWidth * 0.8;
        } else if (constraints.maxWidth < 800) {
          gridWidth = constraints.maxWidth * 0.7;
        } else {
          gridWidth = constraints.maxWidth * 0.3;
        }
        double cellSize = gridWidth / grid[0].length;
        double gridHeight = cellSize * grid.length; // Calculate total height

        return GestureDetector(
          onPanStart: (details) {
            if (remainingWords == 0) {
              return; // disable dragging if already answered
            }

            final cell = _getCellFromOffset(details.localPosition, context,
                cellSize, gridWidth, gridHeight);
            if (cell != null) {
              setState(() {
                startCell = cell;
                lastCell = cell;
                selectedCells.clear();
                selectedCells.add(cell);
                selectedLetters = "";
                //debugPrint("letter: ${grid[cell.dy.toInt()][cell.dx.toInt()]}");
                selectedLetters += grid[cell.dy.toInt()][cell.dx.toInt()];
                direction = null;
              });
            }
          },
          onPanUpdate: (details) {
            if (remainingWords == 0) {
              return; // disable dragging if already answered
            }
            final cell = _getCellFromOffset(details.localPosition, context,
                cellSize, gridWidth, gridHeight);
            if (cell != null && startCell != null) {
              setState(() {
                if (_isValidCell(cell)) {
                  selectedCells.add(cell);
                  lastCell = cell;
                  //debugPrint("letter: ${grid[cell.dy.toInt()][cell.dx.toInt()]}");
                  selectedLetters += grid[cell.dy.toInt()][cell.dx.toInt()];
                }
              });
            }
          },
          onPanEnd: (details) {
            if (remainingWords == 0) {
              return; // disable dragging if already answered
            }
            // Print the selected word before clearing
            String selectedWord = getSelectedWord();
            //debugPrint('Selected word: $selectedWord'); // Print to console
            selectedLetters = selectedWord;
            checkWord(selectedWord);

            setState(() {
              if (!foundCells.containsAll(selectedCells)) {
                selectedCells.clear();
              }
              startCell = null;
              lastCell = null;
              direction = null;
            });
          },
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
                  Offset currentCell = Offset(col.toDouble(), row.toDouble());
                  bool isSelected = selectedCells
                      .contains(Offset(col.toDouble(), row.toDouble()));
                  bool isFound = foundCells.contains(currentCell);
                  Color cellColor = Colors.blueAccent;
                  if (isFound) {
                    cellColor = Colors.green;
                  }
                  if (isSelected) {
                    cellColor = Colors.orange;
                  }

                  return Container(
                    width: cellSize,
                    height: cellSize,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: cellColor,
                      border: Border.all(color: Colors.black),
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: cellSize * 0.5,
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Offset? _getCellFromOffset(Offset offset, BuildContext context,
      double cellSize, double gridWidth, double gridHeight) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final size = box.size;

    // Calculate grid position
    final gridStartX = (size.width - gridWidth) / 2;
    final gridStartY = (size.height - gridHeight) / 2;

    // Get position relative to grid
    final relativeX = offset.dx - gridStartX;
    final relativeY = offset.dy - gridStartY;

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

enum Direction {
  horizontal,
  vertical,
  diagonal,
}
