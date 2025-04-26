import 'package:auto_size_text/auto_size_text.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/views/panels/manage_transaction.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/validators.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late TransactionDao dao;

  Future<double> getTotal() async {
    final spent = await dao.getTotalAmount(type: TransactionType.expense);
    final earned = await dao.getTotalAmount(type: TransactionType.income);

    return earned - spent;
  }

  @override
  Widget build(BuildContext context) {
    dao = context.watch<TransactionDao>();

    return Scaffold(
      body: SingleChildScrollView(
        // The main content
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          WelcomeHeader(),
          FutureBuilder(
            future: getTotal(),
            initialData: 0.0,
            builder: (context, snapshot) {
              bool isNegative = snapshot.data as double < 0;
              String formattedAmount =
                  formatAmount((snapshot.data as double).abs(), exact: true);

              return AccountsCarousel(items: [
                CarouselCardPair(
                  "Total balance",
                  "${isNegative ? '-' : ''}\$$formattedAmount",
                  isNegative: true,
                ),
                CarouselCardPair("Checking", "\$4,182.33"),
                CarouselCardPair("Cash", "\$130.50"),
              ]);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                Text("Recent activity",
                    style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onSurface)),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.arrow_forward),
                  onPressed: () {},
                )
              ],
            ),
          ),
          SizedBox(
            height: 130,
            child: ListView(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              children: [
                TransactionPreviewCard(),
                TransactionPreviewCard(),
                TransactionPreviewCard(),
                TransactionPreviewCard(),
                TransactionPreviewCard(),
              ],
            ),
          ),
          SizedBox(height: 8),
          GoalPreviewCard(),
        ]),
      ),
    );
  }
}

class TransactionPreviewCard extends StatelessWidget {
  final Transaction? transaction;

  const TransactionPreviewCard({super.key, this.transaction});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12), // To match the card's radius
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ManageTransactionDialog(
                  mode: ObjectManageMode.edit, transaction: transaction)));
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                    "+\$500", // Will be "${transaction.type == TransactionType.expense ? '-' : '+'}\$${formatAmount(transaction.amount)}"
                    style: theme.textTheme.headlineLarge!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onTertiaryContainer)),
                Text("Paycheck",
                    style: theme.textTheme.titleMedium!.copyWith(
                        color: theme.colorScheme.onTertiaryContainer)),
                Text("4/25/25",
                    style: theme.textTheme.bodyLarge!.copyWith(
                        color: theme.colorScheme.onTertiaryContainer
                            .withAlpha(150)))
              ]),
        ),
      ),
    );
  }
}

class GoalPreviewButton extends StatelessWidget {
  final String title;
  final int amount;
  final int maxAmount;

  const GoalPreviewButton(
      {super.key,
      required this.title,
      required this.amount,
      required this.maxAmount});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
          CircularProgressIndicator(
            value: amount / maxAmount,
            backgroundColor: Theme.of(context)
                .colorScheme
                .onSecondaryContainer
                .withAlpha(68),
            strokeCap: StrokeCap.round,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    overflow: TextOverflow.ellipsis,
                    title,
                    style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer)),
                Text("\$$amount of \$$maxAmount",
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer
                            .withAlpha(150)))
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(2.0),
            child: Icon(
                size: 32,
                Icons.keyboard_arrow_right,
                color: Theme.of(context).colorScheme.outline),
          )
        ]),
      ),
    );
  }
}

class GoalPreviewCard extends StatelessWidget {
  const GoalPreviewCard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 4,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Your goals",
                    style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer)),
              ),
              GoalPreviewButton(
                title: "A Puppy",
                amount: 120,
                maxAmount: 200,
              ),
              GoalPreviewButton(
                  title: "Baseball Tickets", amount: 200, maxAmount: 450),
              GoalPreviewButton(
                  title: "Spongebob Toybobson", amount: 13, maxAmount: 15),
            ],
          ),
        ));
  }
}

class WelcomeHeader extends StatelessWidget {
  const WelcomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("Welcome, Noah",
            softWrap: true,
            style: Theme.of(context)
                .textTheme
                .headlineMedium!
                .copyWith(color: Theme.of(context).colorScheme.onSurface)),
        IconButton(
          icon: Icon(Icons.person),
          onPressed: () {},
        )
      ]),
    );
  }
}

class CarouselCardPair {
  final String title;
  final String content;
  final bool isNegative;

  const CarouselCardPair(this.title, this.content, {this.isNegative = false});
}

class AccountsCarousel extends StatefulWidget {
  final List<CarouselCardPair> items;

  const AccountsCarousel({super.key, required this.items});

  @override
  State<AccountsCarousel> createState() => _AccountsCarouselState();
}

class _AccountsCarouselState extends State<AccountsCarousel> {
  int index = 0;
  final _carouselController = CarouselSliderController();

  Widget getCardStack(CarouselCardPair data) => Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(data.title,
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: AutoSizeText(
                maxLines: 1,
                data.content,
                style: Theme.of(context).textTheme.displayLarge!.copyWith(
                    color: data.isNegative
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onPrimaryContainer)),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Card(
        margin: EdgeInsets.all(4),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Stack(children: [
            CarouselSlider(
                carouselController: _carouselController,
                options: CarouselOptions(
                  initialPage: index,
                  viewportFraction: 1,
                  aspectRatio: 2,
                  onPageChanged: (i, reason) => setState(() => index = i),
                ),
                items: widget.items
                    .map(
                      (e) => getCardStack(e),
                    )
                    .toList()),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedSmoothIndicator(
                  activeIndex: index,
                  count: widget.items.length,
                  onDotClicked: (i) => setState(() {
                    index = i;
                    _carouselController.animateToPage(i,
                        curve: Curves.decelerate);
                  }),
                  effect: ExpandingDotsEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      dotColor: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                          .withAlpha(68),
                      activeDotColor:
                          Theme.of(context).colorScheme.onPrimaryContainer),
                ),
              ),
            )
          ]),
        ));
  }
}
