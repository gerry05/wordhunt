import 'package:flutter/material.dart';
import 'package:wordhunt/data/data_storage.dart';
import '../utils/categories.dart' as categories;
import 'wordsearch_screen.dart';
import 'package:wordhunt/globals.dart' as globals;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    DataStorage().storeKey('AIzaSyDChWq9EEhc0yuCtF464Zxit0GPz2burcM');
    DataStorage().gameGetWords();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double itemWidth = 70;
    double iconSize = 50;
    if (screenWidth < 600) {
      iconSize = 50;
      itemWidth = 150;
    } else if (screenWidth < 800) {
      iconSize = 75;
      itemWidth = 150;
    } else {
      iconSize = 100;
      itemWidth = 200;
    }
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 20,
          ),
          child: Center(
            child: Column(
              children: [
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  direction: Axis.horizontal,
                  children: [
                    for (var category in categories.categories)
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/wordsearch', // Using the route name
                            arguments:
                                category, // Pass the category if necessary
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(10),
                          width: itemWidth,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Image.asset(
                                category['icon']!,
                                width: iconSize,
                                height: iconSize,
                              ),
                              SizedBox(height: 10),
                              Text(
                                category['name']!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    overflow: TextOverflow.ellipsis,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  "Developed by G.A Buala",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
