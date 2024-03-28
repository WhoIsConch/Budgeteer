import 'package:budget/components/home_card.dart';
import 'package:budget/tools/enums.dart' as tools;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/api.dart';

class Overview extends StatelessWidget {
  const Overview({super.key, required this.swapCallback});

  final Function swapCallback;

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, transactionProvider, child) {
        var total = transactionProvider.getTotal(
            DateTimeRange(start: DateTime.now(), end: DateTime.now()));

        return ListView(
          children: [
            SizedBox(
                height: 200,
                child: HomeCard(
                    title: "Total Balance",
                    content:
                        "\$${transactionProvider.getTotal(null).toStringAsFixed(2)}")),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      flex: 16,
                      child: HomeCard(
                        title: "Net Gain Today",
                        content: "\$${total.toStringAsFixed(2)}",
                      )),
                  const Spacer(),
                  Expanded(
                      flex: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                              flex: 8,
                              child: CardButton(
                                content: "Add a Transaction",
                                textSize: 15,
                                callback: () {},
                              )),
                          // Spacer(),
                          // Expanded(
                          //     flex: 8,
                          //     child: CardButton(content: "Add income")),
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
                            callback: () =>
                                swapCallback(tools.PageType.transactions)),
                      ),
                      const Spacer(),
                      Expanded(
                        flex: 10,
                        child: CardButton(
                            content: "Go to Budget\nOverview",
                            callback: () =>
                                swapCallback(tools.PageType.transactions)),
                      )
                    ]))
          ],
        );
      },
    );
  }
}
