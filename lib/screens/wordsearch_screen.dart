import 'package:flutter/material.dart';
import 'package:wordhunt/widgets/backbutton.dart';
import 'package:wordhunt/widgets/wordsearch_widget.dart';

class WordSearchGameScreen extends StatefulWidget {
  final Map<String, String> category;
  const WordSearchGameScreen({super.key, required this.category});

  @override
  State<WordSearchGameScreen> createState() => _WordSearchGameScreenState();
}

class _WordSearchGameScreenState extends State<WordSearchGameScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BackButtonWidget(),
            Center(
                child: WordSearchScreen(
              category: widget.category,
            )),
          ],
        ),
      ),
    );
  }
}
