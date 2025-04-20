import 'package:budget/components/cards.dart';
import 'package:budget/dialogs/manage_transaction.dart';
import 'package:budget/tools/enums.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/transaction_provider.dart';

class Overview extends StatelessWidget {
  const Overview({super.key, required this.swapCallback});

  final Function swapCallback;

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, transactionProvider, child) {
        return ListView(
          children: [
            // SizedBox(
            //     height: 200,
            //     child: AsyncOverviewCard(
            //       title: "Total Balance",
            //       amountCalculator: (provider) => provider.getTotalAmount(),
            //       textStyle: CardTextStyle.major,
            //     )),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Expanded(
                  //   flex: 16,
                  //   child: AsyncOverviewCard(
                  //     title: "Net Gain Today",
                  //     amountCalculator: (provider) =>
                  //         provider.getTotal(RelativeDateRange.today.getRange()),
                  //     textStyle: CardTextStyle.major,
                  //   ),
                  // ),
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
                                    const ManageTransactionDialog(
                                        mode: ObjectManageMode.add),
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
                                swapCallback(PageType.transactions)),
                      ),
                      const Spacer(),
                      Expanded(
                        flex: 10,
                        child: CardButton(
                            content: "Go to Budget Overview",
                            callback: () =>
                                swapCallback(PageType.transactions)),
                      )
                    ]))
          ],
        );
      },
    );
  }
}
