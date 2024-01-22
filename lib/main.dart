import 'package:flutter/material.dart';
import 'home_card.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        home: const HomePage(),
        theme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFFE0EFDE),
            useMaterial3: true));
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      bottomNavigationBar: BottomAppBar(
          color: Color(0xFFB3F2DD),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(Icons.home),
                onPressed: null,
              ),
              IconButton(
                icon: Icon(Icons.book),
                onPressed: null,
              ),
              IconButton(
                icon: Icon(Icons.person),
                onPressed: null,
              ),
            ],
          )),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: HomeSpread(),
        ),
      ),
    );
  }
}

class HomeSpread extends StatelessWidget {
  const HomeSpread({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(
            height: 200,
            child: HomeCard(title: "Total Balance", content: "\$1,000")),
        SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                  flex: 16,
                  child: HomeCard(title: "Net Gain Today", content: "\$1,000")),
              Spacer(),
              Expanded(
                  flex: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          flex: 8,
                          child: CardButton(content: "Add an\nexpense")),
                      Spacer(),
                      Expanded(
                          flex: 8, child: CardButton(content: "Add income")),
                    ],
                  ))
            ],
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
            height: 70,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 10,
                    child: CardButton(content: "Go to Totals Overview"),
                  ),
                  Spacer(),
                  Expanded(
                    flex: 10,
                    child: CardButton(content: "Go to Budget Overview"),
                  )
                ]))
      ],
    );
  }
}
