import 'package:auto_size_text/auto_size_text.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

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
