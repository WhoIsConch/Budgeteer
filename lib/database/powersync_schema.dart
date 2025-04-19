import 'package:powersync/powersync.dart';

const powersyncAppSchema = Schema([
  Table('transactions', [
    Column.text('user_id'),
    Column.text('title'),
    Column.text('notes'),
    Column.text('amount'),
    Column.text('date'),
    Column.integer('type'),
    Column.integer('category_id')
  ]),
  Table('categories', [
    Column.text('user_id'),
    Column.text('name'),
    Column.text('balance'),
    Column.integer('reset_increment'),
    Column.integer('allow_negatives'),
    Column.integer('color')
  ])
]);
