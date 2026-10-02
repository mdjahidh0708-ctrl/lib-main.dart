import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.init();
  runApp(const DainikAyBayApp());
}


Future<String> exportTransactionsCsv() async {
  final rows = await DB.instance.exportAll();
  final data = <List<dynamic>>[
    ['ID', 'শিরোনাম', 'ক্যাটাগরি', 'পরিমাণ', 'ধরন', 'ওয়ালেট', 'তারিখ'],
    ...rows.map((r) => [
      r['id'],
      r['title'],
      r['category'],
      r['amount'],
      r['is_income'] == 1 ? 'আয়' : 'ব্যয়',
      r['wallet'],
      r['date'],
    ]),
  ];
  final csvText = const ListToCsvConverter().convert(data);
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/dainik_ay_bay_export_${DateTime.now().millisecondsSinceEpoch}.csv';
  await File(path).writeAsString(csvText, encoding: utf8);
  return path;
}

class TransactionItem {
  final int? id;
  final String title;
  final String category;
  final double amount;
  final bool isIncome;
  final String wallet;
  final String date;

  TransactionItem({
    this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    required this.wallet,
    required this.date,
  });
}

class DainikAyBayApp extends StatelessWidget {
  const DainikAyBayApp({super.key});

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final rows = await AppDatabase.instance.all();
    if (!mounted) return;
    setState(() {
      transactions = rows.map((m) => TransactionItem(
        id: m['id'] as int,
        title: m['title'] as String,
        category: m['category'] as String,
        amount: (m['amount'] as num).toDouble(),
        isIncome: (m['is_income'] as int) == 1,
        wallet: m['wallet'] as String,
        date: m['date'] as String,
      )).toList();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'দৈনিক আয় ব্যয়',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans',
        colorSchemeSeed: Colors.teal,
        scaffoldBackgroundColor: const Color(0xfff6f8fa),
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
  int tab = 0;

  double income = 40000;
  double expense = 14500;

  List<TransactionItem> transactions = [];
  bool loading = true;

  double get balance => income - expense;

  void addTransaction(bool isIncome) async {
    final result = await showModalBottomSheet<TransactionItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddTransactionSheet(isIncome: isIncome),
    );

    if (result != null) {
      await AppDatabase.instance.insert({
        'title': result.title,
        'category': result.category,
        'amount': result.amount,
        'is_income': result.isIncome ? 1 : 0,
        'wallet': result.wallet,
        'date': result.date,
      });
      await _loadTransactions();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final rows = await AppDatabase.instance.all();
    if (!mounted) return;
    setState(() {
      transactions = rows.map((m) => TransactionItem(
        id: m['id'] as int,
        title: m['title'] as String,
        category: m['category'] as String,
        amount: (m['amount'] as num).toDouble(),
        isIncome: (m['is_income'] as int) == 1,
        wallet: m['wallet'] as String,
        date: m['date'] as String,
      )).toList();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _home(),
      _transactions(),
      _reports(),
      _budget(),
      _settings(),
    ];

    return Scaffold(
      body: SafeArea(child: loading ? const Center(child: CircularProgressIndicator()) : pages[tab]),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _quickAdd(),
              icon: const Icon(Icons.add),
              label: const Text('নতুন হিসাব'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'হোম'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'লেনদেন'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'রিপোর্ট'),
          NavigationDestination(icon: Icon(Icons.track_changes_outlined), selectedIcon: Icon(Icons.track_changes), label: 'বাজেট'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'সেটিংস'),
        ],
      ),
    );
  }

  Future<void> deleteTransaction(TransactionItem t) async {
    if (t.id == null) return;
    await AppDatabase.instance.delete(t.id!);
    await _loadTransactions();
  }

  void _quickAdd() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('আপনি কী যোগ করবেন?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.add_circle_outline)),
                title: const Text('আয় যোগ করুন'),
                onTap: () { Navigator.pop(context); addTransaction(true); },
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.remove_circle_outline)),
                title: const Text('ব্যয় যোগ করুন'),
                onTap: () { Navigator.pop(context); addTransaction(false); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _home() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: const Text('দৈনিক আয় ব্যয়', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _balanceCard(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _summaryCard('মোট আয়', income, Icons.arrow_downward, Colors.green)),
                    const SizedBox(width: 12),
                    Expanded(child: _summaryCard('মোট ব্যয়', expense, Icons.arrow_upward, Colors.red)),
                  ],
                ),
                const SizedBox(height: 22),
                _sectionTitle('সাম্প্রতিক লেনদেন', 'সব দেখুন', () => setState(() => tab = 1)),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _transactionTile(transactions[i]),
            childCount: transactions.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }

  Widget _balanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xff00695c), Color(0xff00897b)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('বর্তমান ব্যালেন্স', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text('৳ ${balance.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          const Text('অক্টোবর ২০২৬', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, double value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 4),
          Text('৳ ${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String title, String action, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }

  Widget _transactionTile(TransactionItem t) {
    return ListTile(
      leading: CircleAvatar(
        child: Icon(t.isIncome ? Icons.arrow_downward : Icons.arrow_upward),
      ),
      title: Text(t.title),
      subtitle: Text('${t.category} • ${t.wallet} • ${t.date}'),
      trailing: Text(
        '${t.isIncome ? '+' : '-'}৳${t.amount.toStringAsFixed(0)}',
        style: TextStyle(fontWeight: FontWeight.bold, color: t.isIncome ? Colors.green : Colors.red),
      ),
    );
  }

  Widget _transactions() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('সব লেনদেন')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'মাস', label: Text('এই মাস')),
                ButtonSegment(value: 'সপ্তাহ', label: Text('৭ দিন')),
                ButtonSegment(value: 'সব', label: Text('সব')),
              ],
              selected: const {'মাস'},
              onSelectionChanged: (_) {},
            ),
          ),
          ...transactions.map(_transactionTile),
        ],
      ),
    );
  }

  Widget _reports() {
    final categories = {'খাবার': 35, 'যাতায়াত': 20, 'বিল': 15, 'শপিং': 12, 'অন্যান্য': 18};
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('রিপোর্ট')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('এই মাস', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _reportNumber('মোট আয়', income, Colors.green),
          _reportNumber('মোট ব্যয়', expense, Colors.red),
          _reportNumber('অবশিষ্ট', balance, Colors.teal),
          const SizedBox(height: 22),
          const Text('খরচের ক্যাটাগরি', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...categories.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              Expanded(child: Text(e.key)),
              SizedBox(width: 140, child: LinearProgressIndicator(value: e.value / 100, minHeight: 9)),
              const SizedBox(width: 10),
              Text('${e.value}%'),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _reportNumber(String label, double value, Color color) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text('৳ ${value.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
      ),
    );
  }

  Widget _budget() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('বাজেট')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('মাসিক বাজেট', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('৳ 30,000', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: expense / 30000),
                const SizedBox(height: 8),
                Text('ব্যবহৃত ৳ ${expense.toStringAsFixed(0)} • অবশিষ্ট ৳ ${(30000 - expense).toStringAsFixed(0)}'),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          _budgetRow('🍚 খাবার', 6500, 8000),
          _budgetRow('🚌 যাতায়াত', 2000, 3000),
          _budgetRow('🎬 বিনোদন', 1000, 2000),
        ],
      ),
    );
  }

  Widget _budgetRow(String name, double used, double limit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('৳${used.toStringAsFixed(0)} / ৳${limit.toStringAsFixed(0)}'),
          ]),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: used / limit),
        ]),
      ),
    );
  }


  Future<void> _backup() async {
    try {
      final rows = await AppDatabase.instance.exportAll();
      final payload = jsonEncode({
        'app': 'দৈনিক আয় ব্যয়',
        'version': 1,
        'created_at': DateTime.now().toIso8601String(),
        'transactions': rows,
      });
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/dainik_ay_bay_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(payload);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Backup সম্পন্ন'),
          content: Text('ফাইলটি তৈরি হয়েছে:
${file.path}'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('ঠিক আছে'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup ব্যর্থ: $e')));
    }
  }

  Future<void> _restore() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      );
      if (result == null || result.files.single.path == null) return;
      final content = await File(result.files.single.path!).readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! Map || decoded['transactions'] is! List) {
        throw const FormatException('সঠিক backup ফাইল নয়');
      }
      final rows = <Map<String, Object?>>[];
      for (final item in decoded['transactions']) {
        if (item is! Map) continue;
        rows.add({
          'title': item['title']?.toString() ?? 'অন্যান্য',
          'category': item['category']?.toString() ?? 'অন্যান্য',
          'amount': (item['amount'] as num).toDouble(),
          'is_income': (item['is_income'] as num).toInt(),
          'wallet': item['wallet']?.toString() ?? 'Cash',
          'date': item['date']?.toString() ?? '',
        });
      }
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Restore করবেন?'),
          content: Text('${rows.length}টি লেনদেন পাওয়া গেছে। বর্তমান local data replace হবে।'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
          ],
        ),
      );
      if (ok != true) return;
      await AppDatabase.instance.replaceAll(rows);
      await _loadTransactions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${rows.length}টি লেনদেন Restore হয়েছে')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore ব্যর্থ: $e')));
    }
  }

  Widget _settings() => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: const Text('সেটিংস')),
    body: ListView(children: [
      const ListTile(leading: Icon(Icons.account_balance_wallet_outlined), title: Text('ওয়ালেট ম্যানেজমেন্ট')),
      const ListTile(leading: Icon(Icons.category_outlined), title: Text('ক্যাটাগরি ম্যানেজমেন্ট')),
      const ListTile(leading: Icon(Icons.notifications_outlined), title: Text('রিমাইন্ডার')),
      const ListTile(leading: Icon(Icons.lock_outline), title: Text('PIN / Fingerprint Lock')),
      ListTile(
        leading: const Icon(Icons.backup_outlined),
        title: const Text('Backup'),
        subtitle: const Text('সব হিসাব JSON ফাইলে সংরক্ষণ'),
        onTap: _backup,
      ),
      ListTile(
        leading: const Icon(Icons.restore_outlined),
        title: const Text('Restore'),
        subtitle: const Text('Backup ফাইল থেকে হিসাব ফিরিয়ে আনুন'),
        onTap: _restore,
      ),
      const ListTile(
        leading: Icon(Icons.cloud_outlined),
        title: Text('Cloud Backup'),
        subtitle: Text('পরবর্তী সংস্করণে'),
      ),
      const ListTile(
        leading: Icon(Icons.file_download_outlined),
        title: Text('PDF / CSV Export'),
      ),
      const ListTile(
        leading: Icon(Icons.language),
        title: Text('ভাষা: বাংলা'),
      ),
    ]),
  );

}

class AddTransactionSheet extends StatefulWidget {
  final bool isIncome;
  const AddTransactionSheet({super.key, required this.isIncome});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final amount = TextEditingController();
  final note = TextEditingController();
  String category = 'খাবার';
  String wallet = 'Cash';

  final expenseCategories = ['খাবার', 'যাতায়াত', 'বাজার', 'বিল', 'শপিং', 'চিকিৎসা', 'শিক্ষা', 'অন্যান্য'];
  final incomeCategories = ['বেতন', 'ব্যবসা', 'ফ্রিল্যান্সিং', 'ভাড়া', 'উপহার', 'অন্যান্য'];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final rows = await AppDatabase.instance.all();
    if (!mounted) return;
    setState(() {
      transactions = rows.map((m) => TransactionItem(
        id: m['id'] as int,
        title: m['title'] as String,
        category: m['category'] as String,
        amount: (m['amount'] as num).toDouble(),
        isIncome: (m['is_income'] as int) == 1,
        wallet: m['wallet'] as String,
        date: m['date'] as String,
      )).toList();
      loading = false;
    });
  }

  String _today() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}-${n.month.toString().padLeft(2, '0')}-${n.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.isIncome ? incomeCategories : expenseCategories;
    if (!cats.contains(category)) category = cats.first;

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isIncome ? 'আয় যোগ করুন' : 'ব্যয় যোগ করুন',
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'পরিমাণ',
                prefixText: '৳ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'ক্যাটাগরি', border: OutlineInputBorder()),
              items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => category = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: wallet,
              decoration: const InputDecoration(labelText: 'ওয়ালেট', border: OutlineInputBorder()),
              items: ['Cash', 'Bank', 'bKash', 'Nagad', 'Rocket']
                  .map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
              onChanged: (v) => setState(() => wallet = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'নোট / বিবরণ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('সংরক্ষণ করুন'),
                onPressed: () {
                  final value = double.tryParse(amount.text.trim());
                  if (value == null || value <= 0) return;
                  Navigator.pop(
                    context,
                    TransactionItem(
                      title: note.text.trim().isEmpty ? category : note.text.trim(),
                      category: category,
                      amount: value,
                      isIncome: widget.isIncome,
                      wallet: wallet,
                      date: _today(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ManageDataPage extends StatefulWidget {
  const ManageDataPage({super.key});
  @override
  State<ManageDataPage> createState() => _ManageDataPageState();
}

class _ManageDataPageState extends State<ManageDataPage> {
  List<Map<String, dynamic>> wallets = [];
  List<Map<String, dynamic>> categories = [];
  bool showIncome = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await DB.instance.getWallets();
    final c = await DB.instance.getCategories();
    if (mounted) setState(() { wallets = w; categories = c; });
  }

  Future<void> _addWallet() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('নতুন ওয়ালেট'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'নাম')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
          ElevatedButton(onPressed: () { if (c.text.trim().isNotEmpty) Navigator.pop(context, true); }, child: const Text('যোগ করুন')),
        ],
      ),
    );
    if (ok == true) {
      try { await DB.instance.addWallet(c.text); await _load(); }
      catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('এই নামে ওয়ালেট আগে থেকেই আছে।'))); }
    }
  }

  Future<void> _addCategory() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(showIncome ? 'নতুন আয়ের ক্যাটাগরি' : 'নতুন ব্যয়ের ক্যাটাগরি'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'নাম')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
          ElevatedButton(onPressed: () { if (c.text.trim().isNotEmpty) Navigator.pop(context, true); }, child: const Text('যোগ করুন')),
        ],
      ),
    );
    if (ok == true) {
      try { await DB.instance.addCategory(c.text, showIncome); await _load(); }
      catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('এই নামে ক্যাটাগরি আগে থেকেই আছে।'))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shownCats = categories.where((c) => c['is_income'] == (showIncome ? 1 : 0)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('ওয়ালেট ও ক্যাটাগরি')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('ওয়ালেট', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(onPressed: _addWallet, icon: const Icon(Icons.add_circle)),
          ]),
          ...wallets.map((w) => ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(w['name']),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
              await DB.instance.deleteWallet(w['id']);
              _load();
            }),
          )),
          const Divider(height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('ক্যাটাগরি', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(onPressed: _addCategory, icon: const Icon(Icons.add_circle)),
          ]),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('ব্যয়')),
              ButtonSegment(value: true, label: Text('আয়')),
            ],
            selected: {showIncome},
            onSelectionChanged: (s) { setState(() => showIncome = s.first); },
          ),
          ...shownCats.map((c) => ListTile(
            leading: const Icon(Icons.label_outline),
            title: Text(c['name']),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
              await DB.instance.deleteCategory(c['id']);
              _load();
            }),
          )),
        ],
      ),
    );
  }
}
