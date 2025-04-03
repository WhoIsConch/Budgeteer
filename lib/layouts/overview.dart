import 'package:budget/components/cards.dart';
import 'package:budget/components/transaction_form.dart';
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
        return ListView(
          children: [
            SizedBox(
                height: 200,
                child: AsyncOverviewCard(
                  title: "Total Balance",
                  amountCalculator: (provider) => provider.getTotal(null),
                  textStyle: CardTextStyle.major,
                )),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 16,
                    child: AsyncOverviewCard(
                      title: "Net Gain Today",
                      amountCalculator: (provider) => (provider.getTotal(
                          tools.RelativeTimeRange.today.getRange())),
                      textStyle: CardTextStyle.major,
                    ),
                  ),
                  const Spacer(),
                  Expanded(
                      flex: 8,
                      child: CardButton(
                          content: "Add a transaction",
                          callback: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TransactionManageScreen(
                                        mode: tools.ObjectManageMode.add),
                              ),
                            );
                          }))
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
                            content: "Go to Totals Overview",
                            callback: () =>
                                swapCallback(tools.PageType.transactions)),
                      ),
                      const Spacer(),
                      Expanded(
                        flex: 10,
                        child: CardButton(
                            content: "Go to Budget Overview",
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
