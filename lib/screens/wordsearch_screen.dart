import 'package:flutter/material.dart';
import 'package:wordhunt/widgets/wordsearch_widget.dart';

class WordSearchGameScreen extends StatefulWidget {
  final Map<String, String> category;
  const WordSearchGameScreen({super.key, required this.category});

  @override
  State<WordSearchGameScreen> createState() => _WordSearchGameScreenState();
}

class _WordSearchGameScreenState extends State<WordSearchGameScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: const BackButton(),
        title: Hero(
          tag: 'category_name_${widget.category['name']}',
          child: Text(
            widget.category['name']!,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: WordSearchScreen(
                      category: widget.category,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
