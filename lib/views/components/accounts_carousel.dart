import 'package:auto_size_text/auto_size_text.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/views/panels/manage_account.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class CarouselCardPair {
  final AccountWithTotal account;
  final String title;
  final String content;
  final bool isNegative;

  const CarouselCardPair(
    this.account,
    this.title,
    this.content, {
    this.isNegative = false,
  });
}

class AccountsCarousel extends StatefulWidget {
  const AccountsCarousel({super.key});

  @override
  State<AccountsCarousel> createState() => _AccountsCarouselState();
}

class _AccountsCarouselState extends State<AccountsCarousel> {
  int index = 0;
  final _carouselController = CarouselSliderController();

  Widget _getCardStack(CarouselCardPair data) => Stack(
    children: [
      Align(
        alignment: Alignment.topLeft,
        child: Text(
          data.title,
          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: AutoSizeText(
          maxLines: 1,
          data.content,
          style: Theme.of(context).textTheme.displayLarge!.copyWith(
            color:
                data.isNegative
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      Align(
        alignment: Alignment.topRight,
        child: IconButton(
          icon: Icon(Icons.settings),
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ManageAccountForm(initialAccount: data.account),
              ),
            );
          },
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AccountWithTotal>>(
      stream: context.read<AppDatabase>().accountDao.watchAccounts(),
      builder: (context, snapshot) {
        if (snapshot.data == null || snapshot.data!.isEmpty) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return LinearProgressIndicator();
          } else {
            return Text('No accounts'); // Should never happen
          }
        }

        List<CarouselCardPair> items =
            snapshot.data!.map((a) {
              String formattedAmount = formatAmount(a.total.abs(), exact: true);
              String? prefix = a.total.isNegative ? '-' : '';

              return CarouselCardPair(
                a,
                a.account.name,
                '$prefix\$$formattedAmount',
                isNegative: a.total.isNegative,
              );
            }).toList();

        return Card(
          margin: const EdgeInsets.all(4),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              children: [
                CarouselSlider(
                  carouselController: _carouselController,
                  options: CarouselOptions(
                    initialPage: index,
                    viewportFraction: 1,
                    aspectRatio: 2,
                    onPageChanged: (i, reason) => setState(() => index = i),
                  ),
                  items: items.map((e) => _getCardStack(e)).toList(),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedSmoothIndicator(
                      activeIndex: index,
                      count: items.length,
                      onDotClicked:
                          (i) => setState(() {
                            index = i;
                            _carouselController.animateToPage(
                              i,
                              curve: Curves.decelerate,
                            );
                          }),
                      effect: ExpandingDotsEffect(
                        dotHeight: 8,
                        dotWidth: 8,
                        dotColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer.withAlpha(68),
                        activeDotColor:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
