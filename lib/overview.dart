import 'package:budget/home_card.dart';
import 'tools.dart' as tools;
import 'package:flutter/material.dart';

class Overview extends StatelessWidget {
  const Overview({super.key, required this.swapCallback});

  final Function swapCallback;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(
            height: 200,
            child: HomeCard(title: "Total Balance", content: "\$1,000")),
        const SizedBox(height: 16),
        const SizedBox(
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
        const SizedBox(height: 16),
        SizedBox(
            height: 70,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 10,
                    child: CardButton(
                        content: "Go to Totals\nOverview",
                        callback: () => swapCallback(tools.Page.transactions)),
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 10,
                    child: CardButton(
                        content: "Go to Budget\nOverview",
                        callback: () => swapCallback(tools.Page.transactions)),
                  )
                ]))
      ],
    );
  }
}
