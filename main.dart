import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MilkCalculatorApp());
}

class MilkCalculatorApp extends StatelessWidget {
  const MilkCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Milk Calculator',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tabIndex,
          children: const [
            AddEntryScreen(),
            PriceScreen(),
            ReportScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.attach_money), label: 'Price'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Report'),
        ],
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
      ),
    );
  }
}

class MilkStore with ChangeNotifier {
  static const _priceKey = 'pricePerLiter';
  static const _entriesKey = 'entriesJson'; // Map<String(date), double(liters)>

  double _pricePerLiter = 0.0;
  Map<String, double> _entries = {}; // ISO date -> liters (sum for that day)

  double get pricePerLiter => _pricePerLiter;
  Map<String, double> get entries => _entries;

  MilkStore._();

  static final MilkStore instance = MilkStore._();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _pricePerLiter = prefs.getDouble(_priceKey) ?? 0.0;
    final raw = prefs.getString(_entriesKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _entries = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }
    notifyListeners();
  }

  Future<void> setPrice(double price) async {
    _pricePerLiter = price;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_priceKey, _pricePerLiter);
    notifyListeners();
  }

  Future<void> addLiters(DateTime date, double liters) async {
    final key = _isoDate(date);
    _entries[key] = (_entries[key] ?? 0) + liters;
    await _saveEntries();
    notifyListeners();
  }

  Future<void> setLitersForDate(DateTime date, double liters) async {
    final key = _isoDate(date);
    if (liters <= 0) {
      _entries.remove(key);
    } else {
      _entries[key] = liters;
    }
    await _saveEntries();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _entries.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_entriesKey);
    notifyListeners();
  }

  double litersForDate(DateTime date) {
    return _entries[_isoDate(date)] ?? 0.0;
  }

  double totalLitersForMonth(DateTime month) {
    final y = month.year;
    final m = month.month;
    double sum = 0.0;
    _entries.forEach((k, v) {
      final dt = DateTime.parse(k);
      if (dt.year == y && dt.month == m) sum += v;
    });
    return sum;
  }

  Map<DateTime, double> dailyBreakdownForMonth(DateTime month) {
    final y = month.year;
    final m = month.month;
    final map = <DateTime, double>{};
    _entries.forEach((k, v) {
      final dt = DateTime.parse(k);
      if (dt.year == y && dt.month == m) {
        map[dt] = v;
      }
    });
    final sortedKeys = map.keys.toList()..sort();
    return {for (final k in sortedKeys) k: map[k]!};
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_entries.map((k, v) => MapEntry(k, v)));
    await prefs.setString(_entriesKey, raw);
  }

  static String _isoDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}

class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key});

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final store = MilkStore.instance;
  DateTime _selectedDate = DateTime.now();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    store.load().then((_) {
      setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() => setState(() {});

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(today.year - 3),
      lastDate: DateTime(today.year + 3),
      initialDate: _selectedDate,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final litersToday = store.litersForDate(_selectedDate);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Date: ${MilkStore._isoDate(_selectedDate)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month),
                label: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Add quantity', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton(
                onPressed: () => store.addLiters(_selectedDate, 1.0),
                child: const Text('1 L'),
              ),
              ElevatedButton(
                onPressed: () => store.addLiters(_selectedDate, 0.5),
                child: const Text('½ L'),
              ),
              ElevatedButton(
                onPressed: () => store.addLiters(_selectedDate, 0.25),
                child: const Text('¼ L'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total for this day:', style: Theme.of(context).textTheme.titleMedium),
              Text('${litersToday.toStringAsFixed(2)} L', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: litersToday > 0
                    ? () async {
                        await store.setLitersForDate(_selectedDate, 0);
                      }
                    : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear this day'),
              ),
            ],
          ),
          const Divider(height: 32),
          const Text('Tip: set your price per liter in the Price tab.'),
        ],
      ),
    );
  }
}

class PriceScreen extends StatefulWidget {
  const PriceScreen({super.key});

  @override
  State<PriceScreen> createState() => _PriceScreenState();
}

class _PriceScreenState extends State<PriceScreen> {
  final store = MilkStore.instance;
  final controller = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    store.load().then((_) {
      controller.text = store.pricePerLiter == 0 ? '' : store.pricePerLiter.toString();
      setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    controller.dispose();
    super.dispose();
  }

  void _onStore() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Price per liter', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g., 54.5',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final value = double.tryParse(controller.text.replaceAll(',', ''));
              if (value == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid number')),
                );
                return;
              }
              await store.setPrice(value);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved')),
              );
            },
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
          const SizedBox(height: 24),
          Text('Current price: ₹${store.pricePerLiter.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final store = MilkStore.instance;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    store.load().then((_) {
      setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() => setState(() {});

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 3),
      initialDate: _month,
      helpText: 'Pick any date in the month',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final liters = store.totalLitersForMonth(_month);
    final cost = liters * store.pricePerLiter;
    final breakdown = store.dailyBreakdownForMonth(_month);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Month: ${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickMonth,
                icon: const Icon(Icons.calendar_today),
                label: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total liters'),
                      Text(liters.toStringAsFixed(2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Price per liter'),
                      Text('₹${store.pricePerLiter.toStringAsFixed(2)}'),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total cost', style: Theme.of(context).textTheme.titleLarge),
                      Text('₹${cost.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Daily breakdown', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: breakdown.isEmpty
                ? const Center(child: Text('No entries for this month'))
                : ListView(
                    children: breakdown.entries.map((e) {
                      return ListTile(
                        title: Text(MilkStore._isoDate(e.key)),
                        trailing: Text('${e.value.toStringAsFixed(2)} L'),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
