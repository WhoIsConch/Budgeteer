import 'package:auto_size_text/auto_size_text.dart';
import 'package:budget/database/app_database.dart';
import 'package:budget/dialogs/manage_transaction.dart';
import 'package:budget/tools/enums.dart';
import 'package:budget/tools/validators.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
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
          IconButton(
            iconSize: 32,
            icon: Icon(Icons.keyboard_arrow_right),
            onPressed: () {},
          )
        ]),
      ),
    );
  }
}

class _HomePageState extends State<HomePage> {
  // Goal Card is used when the user has goals. If the user has no goals,
  // this panel will not show up.
  // TODO: Sort goals by how close they are to being completed
  // Paginate the goals view to show all of the user's goals
  Widget get goalCard => Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Your Goals",
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium!
                          .copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer)),
                  IconButton(
                    iconSize: 32,
                    icon: Icon(Icons.settings),
                    onPressed: () {},
                  )
                ],
              ),
            ),
            Divider(color: Theme.of(context).colorScheme.outline),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionDao>();

    final totalBalance = provider.getTotalAmount();

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        WelcomeHeader(),
        FutureBuilder(
          future: totalBalance,
          initialData: 0.0,
          builder: (context, snapshot) => AccountsCarousel(items: [
            CarouselCardPair("Total Balance",
                "\$${formatAmount(snapshot.data as double, exact: true)}"),
            CarouselCardPair("Checking", "\$4,182.33"),
            CarouselCardPair("Cash", "\$130.50"),
          ]),
        ),
        QuickActions(),
        goalCard,
      ]),
    );
  }
}

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  TextButton textButton(
          BuildContext context, String text, void Function() callback) =>
      TextButton(
        style: TextButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary),
        onPressed: callback,
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(color: Theme.of(context).colorScheme.onSecondary)),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Row(spacing: 12, children: [
        Expanded(
          child: textButton(
            context,
            "Manage Accounts ",
            () {},
          ),
        ),
        Expanded(
          child: textButton(
            context,
            "Add Transaction",
            () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    const ManageTransactionDialog(mode: ObjectManageMode.add))),
          ),
        ),
      ]),
    );
  }
}

class WelcomeHeader extends StatelessWidget {
  const WelcomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("Welcome, Noah.",
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

  const CarouselCardPair(this.title, this.content);
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
                    color: Theme.of(context).colorScheme.onPrimaryContainer)),
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
