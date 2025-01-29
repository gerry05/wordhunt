import 'dart:math';

import 'package:flutter/material.dart';

void placeWordsInGrid(List<List<String>> grid, List<String> words) {
  Random rand = Random();

  for (String word in words) {
    bool placed = false;
    while (!placed) {
      int direction = rand.nextInt(2); // 0 for horizontal, 1 for vertical
      int row = rand.nextInt(10);
      int col = rand.nextInt(10);

      if (direction == 0) {
        // Horizontal placement
        if (col + word.length <= 10 &&
            canPlaceHorizontally(grid, row, col, word)) {
          for (int i = 0; i < word.length; i++) {
            grid[row][col + i] = word[i];
          }
          placed = true;
        }
      } else {
        // Vertical placement
        if (row + word.length <= 10 &&
            canPlaceVertically(grid, row, col, word)) {
          for (int i = 0; i < word.length; i++) {
            grid[row + i][col] = word[i];
          }
          placed = true;
        }
      }
    }
  }
}

bool canPlaceHorizontally(
    List<List<String>> grid, int row, int col, String word) {
  for (int i = 0; i < word.length; i++) {
    if (grid[row][col + i] != ' ') {
      return false;
    }
  }
  return true;
}

bool canPlaceVertically(
    List<List<String>> grid, int row, int col, String word) {
  for (int i = 0; i < word.length; i++) {
    if (grid[row + i][col] != ' ') {
      return false;
    }
  }
  return true;
}

void fillRandomLetters(List<List<String>> grid) {
  Random rand = Random();
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  for (int i = 0; i < 10; i++) {
    for (int j = 0; j < 10; j++) {
      if (grid[i][j] == ' ') {
        grid[i][j] = letters[rand.nextInt(letters.length)];
      }
    }
  }
}

void printGrid(List<List<String>> grid) {
  for (List<String> row in grid) {
    debugPrint("$row");
  }
}
