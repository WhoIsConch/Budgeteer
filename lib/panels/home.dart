import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountsCarousel(items: [
          CarouselCardPair(context, "Total Balance", "\$4,312.83"),
          CarouselCardPair(context, "Checking", "\$4,182.33"),
          CarouselCardPair(context, "Cash", "\$130.50"),
        ]),
      ],
    );
  }
}

class CarouselCardPair {
  final String title;
  final String content;
  final BuildContext context;

  const CarouselCardPair(this.context, this.title, this.content);

  Widget get stack => Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(title,
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(content,
                style: Theme.of(context).textTheme.displayLarge!.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer)),
          ),
        ],
      );
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

  @override
  Widget build(BuildContext context) {
    return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
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
                      (e) => e.stack,
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
