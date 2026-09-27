import '../../finance/data/database.dart';
import '../../finance/finance_repository.dart';
import '../../finance/logic/holding_value.dart';
import '../../finance/logic/insights.dart';
import '../../finance/stock_service.dart';
import 'providers/ai_client.dart';

/// Finance actions shared by every assistant provider.
class FinanceAiTools {
  FinanceAiTools(
    this.repository, {
    this.fetchHistory = StockService.fetchHistory,
  });

  final FinanceRepository repository;
  final Future<List<PricePoint>> Function(String, ChartRange) fetchHistory;

  static const names = {
    'add_finance_transaction',
    'list_finance_options',
    'list_finance_transactions',
    'get_finance_summary',
    'list_finance_holdings',
    'get_market_trend',
  };

  static const schemas = <AiToolDefinition>[
    AiToolDefinition(
      name: 'add_finance_transaction',
      description:
          'Record one expense or income in the Finance ledger in EUR. Ask for the exact amount, type and calendar date if unclear. Use list_finance_transactions to check for duplicates before retrying a possibly completed write. Category and merchant must match existing Finance names exactly; ask the user when uncertain.',
      parameters: {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['expense', 'income'],
          },
          'amount_eur': {
            'type': 'number',
            'description': 'Positive amount in euros, e.g. 12.50.',
          },
          'date': {
            'type': 'string',
            'description': 'Exact local calendar date, YYYY-MM-DD.',
          },
          'note': {'type': 'string'},
          'category': {
            'type': 'string',
            'description': 'Existing Finance category name, for expenses.',
          },
          'merchant': {
            'type': 'string',
            'description': 'Existing Finance merchant name, for expenses.',
          },
          'pot': {
            'type': 'string',
            'description':
                'Existing Finance pot name to receive income or pay an expense from.',
          },
        },
        'required': ['kind', 'amount_eur', 'date'],
      },
    ),
    AiToolDefinition(
      name: 'list_finance_options',
      description:
          'List existing Finance categories, merchants and pots before assigning them to a transaction. Use the returned names exactly.',
      parameters: {'type': 'object', 'properties': {}, 'required': []},
    ),
    AiToolDefinition(
      name: 'list_finance_transactions',
      description:
          'Read recent Finance ledger entries, including ids, dates, categories and merchants. Use to answer spending questions or check for a duplicate before adding.',
      parameters: {
        'type': 'object',
        'properties': {
          'limit': {'type': 'integer', 'description': '1 to 50, default 20.'},
        },
        'required': [],
      },
    ),
    AiToolDefinition(
      name: 'get_finance_summary',
      description:
          'Summarize a Finance calendar month: income, spending, net, previous month comparison, and spending by category. All amounts are EUR cents.',
      parameters: {
        'type': 'object',
        'properties': {
          'month': {
            'type': 'string',
            'description': 'YYYY-MM; defaults to current local month.',
          },
        },
        'required': [],
      },
    ),
    AiToolDefinition(
      name: 'list_finance_holdings',
      description:
          'Read tracked Finance stock holdings and their cached prices. Quotes may be stale; distinguish cost basis from a live market quote. Values are in the stated quote currency.',
      parameters: {'type': 'object', 'properties': {}, 'required': []},
    ),
    AiToolDefinition(
      name: 'get_market_trend',
      description:
          'Read the market price trend for one explicit stock ticker from the Finance chart source. Ask for the ticker if the company or exchange is ambiguous. Returns observed price points and change, not a forecast or recommendation. The quote currency may be unavailable from this endpoint.',
      parameters: {
        'type': 'object',
        'properties': {
          'ticker': {
            'type': 'string',
            'description': 'Exact exchange ticker, e.g. AAPL or ASML.AS.',
          },
          'range': {
            'type': 'string',
            'enum': ['1D', '1W', '1M', '6M', '1Y'],
          },
        },
        'required': ['ticker'],
      },
    ),
  ];

  Future<Map<String, dynamic>> execute(
    String name,
    Map<String, dynamic> input,
  ) async {
    try {
      switch (name) {
        case 'add_finance_transaction':
          return await _addTransaction(input);
        case 'list_finance_options':
          return await _options();
        case 'list_finance_transactions':
          return await _listTransactions(input);
        case 'get_finance_summary':
          return await _summary(input);
        case 'list_finance_holdings':
          return await _holdings();
        case 'get_market_trend':
          return await _marketTrend(input);
        default:
          return {'status': 'error', 'message': 'Unknown finance tool.'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _addTransaction(
    Map<String, dynamic> input,
  ) async {
    final kind = switch (input['kind']) {
      'expense' => TxnKind.expense,
      'income' => TxnKind.income,
      _ => null,
    };
    final amount = input['amount_eur'];
    final date = _date(input['date']);
    if (kind == null ||
        amount is! num ||
        !amount.isFinite ||
        amount <= 0 ||
        amount > 1000000000 ||
        date == null) {
      return _needsInfo(
        'Ask for expense or income, a positive EUR amount, and an exact date (YYYY-MM-DD).',
      );
    }
    final cents = (amount * 100).round();
    if (cents <= 0) return _needsInfo('Ask for an amount of at least €0.01.');
    final note = (input['note'] as String?)?.trim();
    final categoryName = (input['category'] as String?)?.trim();
    final merchantName = (input['merchant'] as String?)?.trim();
    final potName = (input['pot'] as String?)?.trim();
    if (kind == TxnKind.income &&
        ((categoryName?.isNotEmpty ?? false) ||
            (merchantName?.isNotEmpty ?? false))) {
      return _needsInfo(
        'Finance categories and merchants are only used for expenses. Clarify the entry type.',
      );
    }
    int? categoryId;
    int? merchantId;
    int? potId;
    if (categoryName != null && categoryName.isNotEmpty) {
      final categories = await repository.allCategories();
      final matches = categories
          .where((c) => c.name.toLowerCase() == categoryName.toLowerCase())
          .toList();
      if (matches.length != 1) {
        return _needsInfo(
          'Category not found uniquely. Ask the user to choose an existing category: ${categories.map((c) => c.name).join(', ')}.',
        );
      }
      categoryId = matches.single.id;
    }
    if (merchantName != null && merchantName.isNotEmpty) {
      final merchants = await repository.allMerchants();
      final matches = merchants
          .where((m) => m.name.toLowerCase() == merchantName.toLowerCase())
          .toList();
      if (matches.length != 1) {
        return _needsInfo(
          'Merchant not found uniquely. Ask the user to choose an existing merchant: ${merchants.map((m) => m.name).join(', ')}.',
        );
      }
      merchantId = matches.single.id;
      categoryId ??= matches.single.defaultCategoryId;
    }
    if (potName != null && potName.isNotEmpty) {
      final pots = await repository.allPots();
      final matches = pots
          .where((p) => p.name.toLowerCase() == potName.toLowerCase())
          .toList();
      if (matches.length != 1) {
        return _needsInfo(
          'Pot not found uniquely. Ask the user to choose an existing pot: ${pots.map((p) => p.name).join(', ')}.',
        );
      }
      potId = matches.single.id;
    }
    final id = await repository.addTransaction(
      kind: kind,
      amountCents: cents,
      date: date,
      note: note?.isEmpty ?? true ? null : note,
      categoryId: categoryId,
      merchantId: merchantId,
      potId: potId,
    );
    return {
      'status': 'created',
      'transaction_id': id,
      'kind': kind.name,
      'amount_cents': cents,
      'currency': 'EUR',
      'date': _isoDate(date),
      'category': categoryName,
      'merchant': merchantName,
      'pot': potName,
    };
  }

  Future<Map<String, dynamic>> _options() async {
    final categories = await repository.allCategories();
    final merchants = await repository.allMerchants();
    final pots = await repository.allPots();
    return {
      'status': 'ok',
      'categories': [
        for (final c in categories) {'id': c.id, 'name': c.name},
      ],
      'merchants': [
        for (final m in merchants)
          {
            'id': m.id,
            'name': m.name,
            'default_category_id': m.defaultCategoryId,
          },
      ],
      'pots': [
        for (final p in pots) {'id': p.id, 'name': p.name},
      ],
    };
  }

  Future<Map<String, dynamic>> _listTransactions(
    Map<String, dynamic> input,
  ) async {
    final limit = ((input['limit'] as num?)?.toInt() ?? 20).clamp(1, 50);
    final txns = await repository.watchTransactions(limit: limit).first;
    final categories = {
      for (final c in await repository.allCategories()) c.id: c.name,
    };
    final merchants = {
      for (final m in await repository.allMerchants()) m.id: m.name,
    };
    return {
      'status': 'ok',
      'currency': 'EUR',
      'transactions': [
        for (final t in txns)
          {
            'id': t.id,
            'kind': t.kind.name,
            'amount_cents': t.amountCents,
            'date': _isoDate(t.date),
            'note': t.note,
            'category': categories[t.categoryId],
            'merchant': merchants[t.merchantId],
            'pot_id': t.potId,
          },
      ],
    };
  }

  Future<Map<String, dynamic>> _summary(Map<String, dynamic> input) async {
    final rawMonth = input['month'];
    final month = rawMonth == null
        ? DateTime(DateTime.now().year, DateTime.now().month)
        : _month(rawMonth);
    if (month == null) {
      return _needsInfo('Ask for an exact month in YYYY-MM format.');
    }
    final txns = await repository.watchTransactions().first;
    final categories = {
      for (final c in await repository.allCategories()) c.id: c.name,
    };
    final merchants = {
      for (final m in await repository.allMerchants()) m.id: m.name,
    };
    final report = PeriodReport.build(
      period: ReportPeriod(ReportSpan.month, month),
      txns: txns,
      merchantNames: merchants,
    );
    final ranked = report.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {
      'status': 'ok',
      'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
      'currency': 'EUR',
      'income_cents': report.incomeCents,
      'expense_cents': report.expenseCents,
      'net_cents': report.netCents,
      'previous_expense_cents': report.previousExpenseCents,
      'by_category': [
        for (final e in ranked)
          {
            'category': categories[e.key] ?? 'Uncategorized',
            'amount_cents': e.value,
          },
      ],
      'top_merchants': [
        for (final m in report.topMerchants)
          {'name': m.name, 'amount_cents': m.cents, 'count': m.count},
      ],
    };
  }

  Future<Map<String, dynamic>> _holdings() async {
    final holdings = await repository.watchHoldings().first;
    return {
      'status': 'ok',
      'holdings': [
        for (final h in holdings)
          {
            'ticker': h.ticker,
            'name': h.name,
            'shares': h.shares,
            'average_cost_cents': h.avgCostCents,
            'last_price_cents': h.lastPriceCents,
            'last_price_at': h.lastPriceAt?.toIso8601String(),
            'currency': h.currency ?? 'EUR',
            'value_eur_cents': h.missingFxRate ? null : h.valueEurCents,
            'missing_fx_rate': h.missingFxRate,
          },
      ],
    };
  }

  Future<Map<String, dynamic>> _marketTrend(Map<String, dynamic> input) async {
    final ticker = (input['ticker'] as String?)?.trim().toUpperCase() ?? '';
    if (!RegExp(r'^[A-Z0-9^.=\-]{1,20}$').hasMatch(ticker)) {
      return _needsInfo(
        'Ask for one exact stock ticker, including its exchange suffix where needed.',
      );
    }
    final range = ChartRange.values
        .where((r) => r.label == (input['range'] ?? '1M'))
        .firstOrNull;
    if (range == null) {
      return _needsInfo('Choose a range: 1D, 1W, 1M, 6M or 1Y.');
    }
    final points = await fetchHistory(ticker, range);
    if (points.isEmpty) {
      return {
        'status': 'unavailable',
        'message': 'No market history is available for $ticker.',
        'ticker': ticker,
      };
    }
    final first = points.first.priceCents;
    final last = points.last.priceCents;
    final step = (points.length / 24).ceil().clamp(1, points.length);
    final sampled = <PricePoint>[
      for (var i = 0; i < points.length; i += step) points[i],
    ];
    if (sampled.last != points.last) sampled.add(points.last);
    return {
      'status': 'ok',
      'ticker': ticker,
      'range': range.label,
      'source': 'Yahoo Finance chart',
      'currency': 'unknown',
      'first_price_cents': first,
      'last_price_cents': last,
      'change_cents': last - first,
      'change_percent': first == 0 ? null : (last - first) * 100 / first,
      'first_at': points.first.time.toIso8601String(),
      'last_at': points.last.time.toIso8601String(),
      'points': [
        for (final p in sampled)
          {'time': p.time.toIso8601String(), 'price_cents': p.priceCents},
      ],
    };
  }

  static DateTime? _date(Object? raw) {
    if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return null;
    }
    final year = int.parse(raw.substring(0, 4));
    final month = int.parse(raw.substring(5, 7));
    final day = int.parse(raw.substring(8, 10));
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static DateTime? _month(Object? raw) {
    if (raw is! String || !RegExp(r'^\d{4}-\d{2}$').hasMatch(raw)) return null;
    final year = int.parse(raw.substring(0, 4));
    final month = int.parse(raw.substring(5, 7));
    return month >= 1 && month <= 12 ? DateTime(year, month) : null;
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _needsInfo(String message) => {
    'status': 'needs_info',
    'message': message,
  };
}
