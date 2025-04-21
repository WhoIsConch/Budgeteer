import 'package:powersync/powersync.dart';

const powersyncAppSchema = Schema([
  Table('transactions', [
    Column.text('user_id'),
    Column.text('title'),
    Column.text('notes'),
    Column.real('amount'),
    Column.text('date'),
    Column.integer('type'),
    Column.text('category_id'),
    Column.integer('is_deleted'),
  ]),
  Table('categories', [
    Column.text('user_id'),
    Column.text('name'),
    Column.real('balance'),
    Column.integer('reset_increment'),
    Column.integer('allow_negatives'),
    Column.integer('color'),
    Column.integer('is_deleted'),
  ])
]);
