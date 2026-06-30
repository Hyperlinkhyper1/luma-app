import 'package:flutter/material.dart';

/// A category to seed on first launch.
class SeedCategory {
  const SeedCategory(this.name, this.colorValue, this.iconCodepoint);
  final String name;
  final int colorValue;
  final int iconCodepoint;
}

/// A merchant to seed, linked to a category by name.
class SeedMerchant {
  const SeedMerchant(this.name, this.categoryName);
  final String name;
  final String categoryName;
}

// Category names are referenced by merchants, so keep them stable.
const _groceries = 'Groceries';
const _eatingOut = 'Eating out';
const _clothing = 'Clothing';
const _transport = 'Transport';
const _subscriptions = 'Subscriptions';
const _housing = 'Housing';
const _utilities = 'Utilities';
const _health = 'Health & care';
const _entertainment = 'Entertainment';
const _shopping = 'Shopping';
const _other = 'Other';

final List<SeedCategory> seedCategories = [
  SeedCategory(_groceries, Colors.green.toARGB32(), Icons.shopping_cart_rounded.codePoint),
  SeedCategory(_eatingOut, Colors.orange.toARGB32(), Icons.restaurant_rounded.codePoint),
  SeedCategory(_clothing, Colors.pink.toARGB32(), Icons.checkroom_rounded.codePoint),
  SeedCategory(_transport, Colors.blue.toARGB32(), Icons.directions_car_rounded.codePoint),
  SeedCategory(_subscriptions, Colors.indigo.toARGB32(), Icons.subscriptions_rounded.codePoint),
  SeedCategory(_housing, Colors.teal.toARGB32(), Icons.home_rounded.codePoint),
  SeedCategory(_utilities, Colors.amber.toARGB32(), Icons.bolt_rounded.codePoint),
  SeedCategory(_health, Colors.red.toARGB32(), Icons.favorite_rounded.codePoint),
  SeedCategory(_entertainment, Colors.deepPurple.toARGB32(), Icons.sports_esports_rounded.codePoint),
  SeedCategory(_shopping, Colors.cyan.toARGB32(), Icons.shopping_bag_rounded.codePoint),
  SeedCategory(_other, Colors.blueGrey.toARGB32(), Icons.category_rounded.codePoint),
];

final List<SeedMerchant> seedMerchants = [
  // Groceries
  const SeedMerchant('Albert Heijn', _groceries),
  const SeedMerchant('Jumbo', _groceries),
  const SeedMerchant('Lidl', _groceries),
  const SeedMerchant('Aldi', _groceries),
  const SeedMerchant('PLUS', _groceries),
  const SeedMerchant('Picnic', _groceries),
  const SeedMerchant('Dirk', _groceries),
  // Eating out
  const SeedMerchant("McDonald's", _eatingOut),
  const SeedMerchant("Domino's", _eatingOut),
  const SeedMerchant('Starbucks', _eatingOut),
  const SeedMerchant('Thuisbezorgd', _eatingOut),
  const SeedMerchant('Uber Eats', _eatingOut),
  const SeedMerchant('KFC', _eatingOut),
  // Clothing
  const SeedMerchant('H&M', _clothing),
  const SeedMerchant('Zara', _clothing),
  const SeedMerchant('Nike', _clothing),
  const SeedMerchant('Zalando', _clothing),
  const SeedMerchant('Primark', _clothing),
  const SeedMerchant('Uniqlo', _clothing),
  // Transport
  const SeedMerchant('Shell', _transport),
  const SeedMerchant('BP', _transport),
  const SeedMerchant('NS', _transport),
  const SeedMerchant('OV-chipkaart', _transport),
  const SeedMerchant('Uber', _transport),
  const SeedMerchant('Shell Recharge', _transport),
  // Subscriptions
  const SeedMerchant('Spotify', _subscriptions),
  const SeedMerchant('Netflix', _subscriptions),
  const SeedMerchant('Disney+', _subscriptions),
  const SeedMerchant('YouTube Premium', _subscriptions),
  const SeedMerchant('iCloud', _subscriptions),
  const SeedMerchant('HBO Max', _subscriptions),
  // Utilities
  const SeedMerchant('Vodafone', _utilities),
  const SeedMerchant('KPN', _utilities),
  const SeedMerchant('Odido', _utilities),
  const SeedMerchant('Eneco', _utilities),
  const SeedMerchant('Vattenfall', _utilities),
  // Health & care
  const SeedMerchant('Etos', _health),
  const SeedMerchant('Kruidvat', _health),
  const SeedMerchant('Apotheek', _health),
  // Entertainment
  const SeedMerchant('Steam', _entertainment),
  const SeedMerchant('PlayStation Store', _entertainment),
  const SeedMerchant('Pathé', _entertainment),
  // Shopping / general
  const SeedMerchant('bol.com', _shopping),
  const SeedMerchant('Coolblue', _shopping),
  const SeedMerchant('Amazon', _shopping),
  const SeedMerchant('Action', _shopping),
  const SeedMerchant('MediaMarkt', _shopping),
  const SeedMerchant('IKEA', _shopping),
  const SeedMerchant('Apple', _shopping),
];
