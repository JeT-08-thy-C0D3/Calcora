import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CalcoraApp());
}

class CalcoraApp extends StatefulWidget {
  const CalcoraApp({super.key});

  @override
  State<CalcoraApp> createState() => _CalcoraAppState();
}

class _CalcoraAppState extends State<CalcoraApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6750A4);
    return MaterialApp(
      title: 'Calcora',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF15121D),
      ),
      home: CalculatorPage(
        isDarkMode: _themeMode == ThemeMode.dark,
        onThemeToggle: () => setState(() {
          _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        }),
      ),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({
    required this.isDarkMode,
    required this.onThemeToggle,
    super.key,
  });

  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  static const _historyKey = 'calcora_history';
  String _expression = '';
  String _result = '0';
  bool _scientificMode = true;
  bool _isDegrees = true;
  bool _justCalculated = false;
  double _memory = 0;
  List<Calculation> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_historyKey);
    if (encoded == null) return;
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      if (mounted) {
        setState(() {
          _history = decoded
              .map((entry) => Calculation.fromJson(entry as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {
      // A malformed older value should not stop the calculator from opening.
    }
  }

  Future<void> _saveHistory() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _historyKey,
      jsonEncode(_history.map((entry) => entry.toJson()).toList()),
    );
  }

  void _press(String value) {
    setState(() {
      switch (value) {
        case 'C':
          _expression = '';
          _result = '0';
          _justCalculated = false;
          break;
        case '\u232B':
          if (_expression.isNotEmpty) {
            _expression = _expression.substring(0, _expression.length - 1);
          }
          break;
        case '=':
          _calculate();
          break;
        case 'MC':
          _memory = 0;
          break;
        case 'MR':
          if (_result == 'Error') _result = '0';
          _expression += _format(_memory);
          break;
        case 'ANS':
          if (_result != 'Error') {
            if (_justCalculated) {
              _expression = '';
              _justCalculated = false;
            }
            _expression += _result;
          }
          break;
        case 'M+':
          _updateMemory(add: true);
          break;
        case 'M\u2212':
          _updateMemory(add: false);
          break;
        default:
          if (_result == 'Error') _result = '0';
          if (_justCalculated) {
            if (const {'+', '\u2212', '\u00D7', '\u00F7', '%', '^'}.contains(value)) {
              _expression = _result;
            } else {
              _expression = '';
            }
            _justCalculated = false;
          }
          _expression += value;
      }
    });
  }

  void _calculate() {
    if (_expression.trim().isEmpty) return;
    try {
      final value = ExpressionParser(_expression, useDegrees: _isDegrees).parse();
      if (!value.isFinite) throw const FormatException();
      final formatted = _format(value);
      _result = formatted;
      _justCalculated = true;
      _history = [
        Calculation(expression: _expression, result: formatted, createdAt: DateTime.now()),
        ..._history,
      ];
      if (_history.length > 50) _history.removeRange(50, _history.length);
      _saveHistory();
    } on FormatException {
      _result = 'Error';
      _justCalculated = false;
    }
  }

  void _updateMemory({required bool add}) {
    try {
      final value = _expression.isNotEmpty
          ? ExpressionParser(_expression, useDegrees: _isDegrees).parse()
          : double.parse(_result);
      if (!value.isFinite) throw const FormatException();
      _memory = add ? _memory + value : _memory - value;
    } on FormatException {
      _result = 'Error';
    }
  }

  String _format(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsPrecision(10).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryPage(
          history: _history,
          onSelect: (calculation) {
            Navigator.of(context).pop();
            setState(() {
              _expression = calculation.expression;
              _result = calculation.result;
              _justCalculated = true;
            });
          },
          onClear: () {
            setState(_history.clear);
            _saveHistory();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keys = _scientificMode ? _scientificKeys : _basicKeys;
    final columns = _scientificMode ? 5 : 4;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.calculate_rounded, color: Color(0xFFD0BCFF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Calcora',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: widget.isDarkMode ? 'Use light theme' : 'Use dark theme',
                    onPressed: widget.onThemeToggle,
                    icon: Icon(
                      widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Calculation history',
                    onPressed: _openHistory,
                    icon: const Icon(Icons.history_rounded),
                  ),
                  Tooltip(
                    message: _scientificMode ? 'Scientific mode' : 'Basic mode',
                    child: Switch(
                      value: _scientificMode,
                      onChanged: (value) => setState(() => _scientificMode = value),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _press('ANS'),
                      child: const Text('ANS'),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _isDegrees = !_isDegrees),
                      icon: const Icon(Icons.straighten_rounded, size: 17),
                      label: Text(_isDegrees ? 'DEG' : 'RAD'),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  reverse: true,
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    _expression.isEmpty ? ' ' : _expression,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, .16),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _result,
                    key: ValueKey(_result),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final rows = (keys.length / columns).ceil();
                    final keyWidth =
                        (constraints.maxWidth - (columns - 1) * 10) / columns;
                    final keyHeight =
                        (constraints.maxHeight - (rows - 1) * 10) / rows;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: GridView.count(
                        key: ValueKey(_scientificMode),
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: columns,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: keyWidth / keyHeight,
                        children: [
                          for (final key in keys)
                            CalculatorKey(
                              label: key,
                              onTap: () => _press(key),
                              isAction: const {
                                'C',
                                '\u232B',
                                '=',
                                'MC',
                                'MR',
                                'M+',
                                'M\u2212',
                              }.contains(key),
                              isOperator: const {
                                '\u00F7',
                                '\u00D7',
                                '\u2212',
                                '+',
                                '%',
                                '^',
                              }.contains(key),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _basicKeys = [
  'MC', 'MR', 'M+', 'M\u2212',
  'C', '\u232B', '%', '\u00F7',
  '7', '8', '9', '\u00D7',
  '4', '5', '6', '\u2212',
  '1', '2', '3', '+',
  '00', '0', '.', '=',
];

const _scientificKeys = [
  'MC', 'MR', 'M+', 'M\u2212', 'C',
  'sin(', 'cos(', 'tan(', 'ln(', 'log(',
  '\u221A(', '(', ')', '\u03C0', 'e',
  '\u232B', '%', '\u00F7', '\u00D7', '\u2212',
  '7', '8', '9', '+', '^',
  '4', '5', '6', '^', '=',
  '1', '2', '3', '0', '.',
];

class CalculatorKey extends StatefulWidget {
  const CalculatorKey({
    required this.label,
    required this.onTap,
    required this.isAction,
    required this.isOperator,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool isAction;
  final bool isOperator;

  @override
  State<CalculatorKey> createState() => _CalculatorKeyState();
}

class _CalculatorKeyState extends State<CalculatorKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = widget.label == '='
        ? scheme.primary
        : widget.isAction
            ? scheme.secondaryContainer
            : widget.isOperator
                ? scheme.tertiaryContainer
                : scheme.surfaceContainerHighest;
    final foreground = widget.label == '='
        ? scheme.onPrimary
        : widget.isAction || widget.isOperator
            ? scheme.onSecondaryContainer
            : scheme.onSurface;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? .94 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: foreground,
                fontSize: widget.label.length > 3 ? 15 : 21,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    required this.history,
    required this.onClear,
    required this.onSelect,
    super.key,
  });

  final List<Calculation> history;
  final VoidCallback onClear;
  final ValueChanged<Calculation> onSelect;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _pageSize = 10;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final pageCount = math.max(1, (widget.history.length / _pageSize).ceil());
    if (_page >= pageCount) _page = pageCount - 1;
    final start = _page * _pageSize;
    final items = widget.history.skip(start).take(_pageSize).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (widget.history.isNotEmpty)
            TextButton(
              onPressed: () {
                widget.onClear();
                setState(() => _page = 0);
              },
              child: const Text('Clear'),
            ),
        ],
      ),
      body: widget.history.isEmpty
          ? const Center(child: Text('Your calculations will appear here.'))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return Card(
                        child: ListTile(
                          onTap: () => widget.onSelect(item),
                          title: Text(item.expression),
                          subtitle: Text(item.createdAtLabel),
                          trailing: Text(
                            '= ${item.result}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _page == 0
                              ? null
                              : () => setState(() => _page--),
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Previous'),
                        ),
                        Expanded(
                          child: Text(
                            'Page ${_page + 1} of $pageCount \u2022 ${widget.history.length} saved',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _page >= pageCount - 1
                              ? null
                              : () => setState(() => _page++),
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('Next'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class Calculation {
  const Calculation({
    required this.expression,
    required this.result,
    required this.createdAt,
  });

  final String expression;
  final String result;
  final DateTime createdAt;

  String get createdAtLabel =>
      '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} '
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'expression': expression,
        'result': result,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Calculation.fromJson(Map<String, dynamic> json) => Calculation(
        expression: json['expression'] as String,
        result: json['result'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class ExpressionParser {
  ExpressionParser(String expression, {this.useDegrees = true})
      : _input = expression
            .replaceAll('\u00D7', '*')
            .replaceAll('\u00F7', '/')
            .replaceAll('\u2212', '-')
            .replaceAll('\u221A', 'sqrt')
            .replaceAll('\u03C0', 'pi')
            .replaceAll(RegExp(r'\s+'), '');

  final String _input;
  final bool useDegrees;
  int _index = 0;

  double parse() {
    final result = _expression();
    if (_index != _input.length) {
      throw const FormatException();
    }
    return result;
  }

  double _expression() {
    var value = _term();
    while (true) {
      if (_consume('+')) {
        value += _term();
      } else if (_consume('-')) {
        value -= _term();
      } else {
        return value;
      }
    }
  }

  double _term() {
    var value = _power();
    while (true) {
      if (_consume('*')) {
        value *= _power();
      } else if (_consume('/')) {
        final divisor = _power();
        if (divisor == 0) {
          throw const FormatException();
        }
        value /= divisor;
      } else if (_consume('%')) {
        final divisor = _power();
        if (divisor == 0) {
          throw const FormatException();
        }
        value %= divisor;
      } else {
        return value;
      }
    }
  }

  double _power() {
    var value = _unary();
    if (_consume('^')) {
      value = math.pow(value, _power()).toDouble();
    }
    return value;
  }

  double _unary() {
    if (_consume('+')) {
      return _unary();
    }
    if (_consume('-')) {
      return -_unary();
    }
    return _primary();
  }

  double _primary() {
    if (_consume('(')) {
      final value = _expression();
      if (!_consume(')')) {
        throw const FormatException();
      }
      return value;
    }
    if (_isLetter) {
      final name = _readName();
      if (name == 'pi') {
        return math.pi;
      }
      if (name == 'e') {
        return math.e;
      }
      if (!_consume('(')) {
        throw const FormatException();
      }
      final value = _expression();
      if (!_consume(')')) {
        throw const FormatException();
      }
      return switch (name) {
        'sin' => math.sin(_angle(value)),
        'cos' => math.cos(_angle(value)),
        'tan' => math.tan(_angle(value)),
        'sqrt' when value >= 0 => math.sqrt(value),
        'ln' when value > 0 => math.log(value),
        'log' when value > 0 => math.log(value) / math.ln10,
        _ => throw const FormatException(),
      };
    }
    return _number();
  }

  double _number() {
    final start = _index;
    var hasDecimal = false;
    while (_index < _input.length) {
      final char = _input[_index];
      if (_isDigit(char)) {
        _index++;
      } else if (char == '.' && !hasDecimal) {
        hasDecimal = true;
        _index++;
      } else {
        break;
      }
    }
    if (start == _index || _input.substring(start, _index) == '.') {
      throw const FormatException();
    }
    return double.parse(_input.substring(start, _index));
  }

  bool _consume(String value) {
    if (_input.startsWith(value, _index)) {
      _index += value.length;
      return true;
    }
    return false;
  }

  bool get _isLetter =>
      _index < _input.length && RegExp(r'[a-z]').hasMatch(_input[_index]);

  String _readName() {
    final start = _index;
    while (_isLetter) {
      _index++;
    }
    return _input.substring(start, _index);
  }

  bool _isDigit(String value) => RegExp(r'[0-9]').hasMatch(value);

  double _angle(double value) => useDegrees ? value * math.pi / 180 : value;
}
