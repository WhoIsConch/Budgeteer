import 'package:budget/appui/components/status.dart';
import 'package:budget/appui/goals/view_goal.dart';
import 'package:budget/appui/transactions/manage_transfer.dart';
import 'package:budget/appui/transactions/view_transaction.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:budget/models/enums.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/services/providers/transaction_provider.dart';
import 'package:budget/utils/ui.dart';
import 'package:budget/utils/validators.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget/appui/transactions/manage_transaction.dart';

class TransactionsList extends StatefulWidget {
  const TransactionsList({
    super.key,
    this.objects,
    this.filters,
    this.sort,
    this.showActionButton = false,
    this.showBackground = true,
  });

  final bool showActionButton;
  final bool showBackground;
  final List<Filter>? filters;
  final List<Transaction>? objects;
  final Sort? sort;

  @override
  State<TransactionsList> createState() => _TransactionsListState();
}

class _TransactionsListState extends State<TransactionsList> {
  List<Transaction> selectedObjects = [];
  late final DeletionManager deletionManager;

  List<Transaction>? _lastSuccessfulData;

  // Just in case I need this in the future
  Widget get bottomLoader => const Center(
    child: Padding(
      padding: EdgeInsets.all(8.0),
      child: LinearProgressIndicator(),
    ),
  );

  bool isSelected(Transaction object) =>
      selectedObjects.where((e) => e.id == object.id).isNotEmpty;

  // TODO: Find a way to make this more performant. The keying can be slow if
  // there are too many objects in the list.
  Widget _getListview(List<Transaction> objects) {
    final List<Transaction> heldTransactions = [];

    return AnimatedSwitcher(
      duration: Duration(milliseconds: 150),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: ListView.separated(
        // Use a key that ensures the AnimatedSwitcher only animates when the
        // objects actually change. If the objects list is the same, the switcher
        // shouldn't animate
        key: ValueKey(objects.map((o) => o.id).join(',')),
        separatorBuilder: (context, index) {
          // Don't render a separator for transactions that aren't going to
          // show up in the list
          if (heldTransactions.contains(objects[index])) {
            return SizedBox.shrink();
          }

          return SizedBox(height: 8.0);
        },
        itemCount: objects.length,

        itemBuilder: (context, index) {
          final object = objects[index];

          if (object.transferWith != null) {
            final transfer = heldTransactions.singleWhereOrNull(
              (element) => element.transferWith == object.id,
            );

            if (transfer == null) {
              heldTransactions.add(object);
              return SizedBox.shrink();
            }

            return TransferTile(transferFrom: object, transferTo: transfer);
          }

          return Card(
            margin: EdgeInsets.zero,
            child: TransactionTile(
              transaction: object,
              onMultiselect: (value) => _onMultiselect(value, object),
              showCheckbox: selectedObjects.isNotEmpty,
              isSelected: isSelected(object),
            ),
          );
        },
      ),
    );
  }

  Widget getList() {
    // Return a stack with a listview in it so we can put that floating
    // action button at the bottom right
    List<Widget> stackChildren;

    if (widget.objects == null) {
      // TODO: Not sure if Streams are lazy by default, but if they aren't
      // or this setup isn't, we should make it lazy.
      stackChildren = [
        StreamBuilder<List<Transaction>>(
          // key: ValueKey(
          //     'tx_stream_${widget.filters.hashCode}_${widget.sort.hashCode}'),
          initialData: const [],
          stream: _getStream(),
          builder: (context, snapshot) {
            List<Transaction>? objectsToDisplay;
            bool showLoadingIndicator = false;

            if (snapshot.hasError) {
              return const Center(
                child: Text('Something went wrong. Please try again'),
              );
            }

            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                if (_lastSuccessfulData != null) {
                  objectsToDisplay = _lastSuccessfulData;
                  showLoadingIndicator = true;
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
                break;
              case ConnectionState.active:
              case ConnectionState.done:
                _lastSuccessfulData = snapshot.data ?? [];
                objectsToDisplay = _lastSuccessfulData;

                showLoadingIndicator = false;
                break;
            }

            final currentList = objectsToDisplay ?? [];

            Widget listContent;
            if (currentList.isEmpty && !showLoadingIndicator) {
              listContent = ErrorInset.noTransactions;
            } else {
              listContent = _getListview(currentList);
            }

            return listContent;
          },
        ),
      ];
    } else {
      if (widget.objects!.isEmpty) {
        stackChildren = [ErrorInset.noTransactions];
      } else {
        stackChildren = [_getListview(widget.objects!)];
      }
    }

    FloatingActionButton? actionButton;

    if (selectedObjects.isNotEmpty) {
      actionButton = FloatingActionButton(
        heroTag: 'list_fab',
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        onPressed: _onDelete,
        child: const Icon(size: 28, Icons.delete),
      );
    } else if (widget.showActionButton) {
      actionButton = FloatingActionButton(
        heroTag: 'list_fab',
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        onPressed: _onCreate,
        child: const Icon(size: 28, Icons.add),
      );
    } else {
      actionButton = null;
    }

    if (actionButton != null) {
      stackChildren.add(
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Align(alignment: Alignment.bottomRight, child: actionButton),
        ),
      );
    }

    return Stack(children: stackChildren);
  }

  void _onDelete() {
    final deletionManager = DeletionManager(context);

    deletionManager.stageObjectsForDeletion<Transaction>(
      selectedObjects.map((t) => t.id).toList(),
    );

    setState(() {
      selectedObjects.clear();
    });
  }

  void _onCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageTransactionPage()),
    );
  }

  void _onMultiselect(bool? value, Transaction object) => setState(() {
    if (value != null && value) {
      selectedObjects.add(object);
    } else {
      selectedObjects.removeWhere((o) => object.id == o.id);
    }
  });

  Stream<List<Transaction>> _getStream() {
    final db = context.read<AppDatabase>();

    final Stream<List<Transaction>> sourceStream = db.transactionDao
        .watchTransactionsPage(filters: widget.filters, sort: widget.sort);

    return sourceStream;
  }

  @override
  void initState() {
    super.initState();

    deletionManager = DeletionManager(context);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showBackground) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(padding: const EdgeInsets.all(8.0), child: getList()),
      );
    } else {
      return getList();
    }
  }
}

class GoalTile extends StatelessWidget {
  final GoalWithAmount goalPair;
  final void Function(bool? isSelected)? onMultiselect;
  final bool isSelected;
  final bool showCheckbox;

  const GoalTile({
    super.key,
    required this.goalPair,
    this.onMultiselect,
    this.isSelected = false,
    this.showCheckbox = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final percentage = goalPair.calculatePercentage();
    final isFinished = percentage >= 1 || goalPair.goal.isArchived;

    final containerColor =
        isFinished
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.secondaryContainer;

    final onColor =
        isFinished
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSecondaryContainer;

    // Decide whether to show the checkmark with the leading progress indicator
    final progressIndicator = CircularProgressIndicator(
      value: goalPair.calculatePercentage(),
      backgroundColor: theme.colorScheme.onSecondaryContainer.withAlpha(68),
      strokeCap: StrokeCap.round,
    );

    Widget leadingWidget;

    if (isFinished) {
      leadingWidget = Stack(
        alignment: Alignment.center,
        children: [
          progressIndicator,
          Icon(Icons.check, color: theme.colorScheme.primary),
        ],
      );
    } else {
      leadingWidget = progressIndicator;
    }

    return ListTile(
      title: Text(goalPair.goal.name),
      leading: leadingWidget,
      subtitle: Text(
        '\$${formatAmount(goalPair.netAmount)}/\$${formatAmount(goalPair.goal.cost)}',
      ),
      tileColor: containerColor,
      textColor: onColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GoalViewer(initialGoalPair: goalPair),
            ),
          ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final void Function(bool? isSelected)? onMultiselect;
  final bool isSelected;
  final bool showCheckbox;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onMultiselect,
    this.isSelected = false,
    this.showCheckbox = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget leadingWidget;

    // Use an alternate color scheme if the transaction is either in the
    // future or archived to tell the user that the transaction is
    // ephemeral
    final isInFuture = transaction.date.isAfter(DateTime.now());
    final isAlternateColorScheme = transaction.isArchived || isInFuture;

    final containerColor =
        isAlternateColorScheme
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.secondaryContainer;

    final onColor =
        isAlternateColorScheme
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSecondaryContainer;

    if (showCheckbox) {
      leadingWidget = SizedBox(
        height: 48,
        width: 48,
        child: Checkbox(
          value: isSelected,
          onChanged: (value) => onMultiselect!(value),
        ),
      );
    } else {
      leadingWidget = IconButton(
        icon:
            (transaction.type == TransactionType.expense)
                ? Icon(Icons.remove_circle, color: onColor)
                : Icon(Icons.add_circle, color: onColor),
        onPressed: onMultiselect != null ? () => onMultiselect!(true) : null,
      );
    }

    String subtitle = transaction.formatDate();

    if (isInFuture) {
      subtitle += ' (Future)';
    }

    if (transaction.isArchived) {
      subtitle += ' (Archived)';
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
      horizontalTitleGap: 4,
      leading: AnimatedSwitcher(
        duration: const Duration(milliseconds: 125),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: leadingWidget,
      ),
      title: Text(
        // Formats as "$500.00: Title of the Budget"
        "${"\$${formatAmount(transaction.amount, truncateIfWhole: false)}"}: \"${transaction.title}\"",
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle),
      onTap: () async {
        var hydratedTransaction = await context
            .read<AppDatabase>()
            .transactionDao
            .hydrateTransaction(transaction);

        if (!context.mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    ViewTransaction(transactionData: hydratedTransaction),
          ),
        );
      },
      onLongPress: () => showOptionsDialog(context, transaction),
      trailing: IconButton(
        icon: Icon(Icons.more_vert, color: onColor),
        onPressed: () => showOptionsDialog(context, transaction),
      ),
      tileColor: containerColor,
      textColor: onColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    );
  }
}

class TransferTile extends StatelessWidget {
  final Transaction transferFrom;
  final Transaction transferTo;

  const TransferTile({
    super.key,
    required this.transferFrom,
    required this.transferTo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
        horizontalTitleGap: 4,
        leading: SizedBox(
          height: 48.0,
          width: 48.0,
          child: Icon(Icons.compare_arrows, size: 36),
        ),
        title: Text(
          'Transfer of \$${formatAmount(transferFrom.amount, exact: true)}: ${transferFrom.title}',
        ),
        subtitle: Text(transferFrom.formatDate()),
        onTap:
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (_) => ManageTransferPage(
                      initialTransfer: (transferFrom, transferTo),
                    ),
              ),
            ),
        onLongPress:
            () => showTransferOptions(context, (transferFrom, transferTo)),
      ),
    );
  }
}
