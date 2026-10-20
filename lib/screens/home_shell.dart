import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/app_database.dart';

const _neon = Color(0xFF00F0A0);
const _muted = Color(0xFF8AA39B);

/// غلاف التنقل الرئيسي؛ كل تبويب مسؤول عن مهمة واحدة.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    SalePage(),
    ProductsPage(),
    AccountsPage(),
    ReportsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'كاشير المحل الذكي',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 3),
            Text(
              'قراءة باركود • حساب مكسب • دخل وخارج',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 16),
            child: Icon(Icons.point_of_sale_rounded, color: _neon, size: 30),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        backgroundColor: const Color(0xFF071310),
        indicatorColor: _neon,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'البيع',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'المخزون',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'الحسابات',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'التقارير',
          ),
        ],
      ),
    );
  }
}

class SalePage extends StatefulWidget {
  const SalePage({super.key});
  @override
  State<SalePage> createState() => _SalePageState();
}

class _SalePageState extends State<SalePage> {
  final _barcode = TextEditingController();
  final Map<String, int> _cart = {};
  bool _scanning = false;
  String _message = 'امسح باركود المنتج أو اكتبه يدويًا';

  Future<void> _addBarcode(String code) async {
    final product = await AppDatabase.instance.productByBarcode(code.trim());
    if (!mounted) return;
    if (product == null) {
      setState(() => _message = 'المنتج مش متسجل. افتح المخزون وسجّله الأول.');
      return;
    }
    final stock = product['quantity']! as int;
    final count = (_cart[code] ?? 0) + 1;
    if (stock < count) {
      setState(() => _message = 'الكمية المطلوبة أكبر من المخزون المتاح.');
      return;
    }
    setState(() {
      _cart[code] = count;
      _barcode.clear();
      _message = 'تمت إضافة ${product['name']} للفاتورة';
    });
  }

  Future<void> _openScanner() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) _showMessage('لازم تسمح بالكاميرا علشان نقرأ الباركود.');
      return;
    }
    setState(() => _scanning = true);
  }

  Future<void> _finishSale() async {
    if (_cart.isEmpty) {
      _showMessage('ضيف منتج واحد على الأقل.');
      return;
    }
    try {
      final items = _cart.entries
          .map((e) => <String, Object?>{'barcode': e.key, 'quantity': e.value})
          .toList();
      final products = await AppDatabase.instance.products();
      double total = 0;
      for (final item in items) {
        final p = products.firstWhere((x) => x['barcode'] == item['barcode']);
        total +=
            (p['sell_price']! as num).toDouble() * (item['quantity']! as int);
      }
      await AppDatabase.instance.completeSale(items: items, paid: total);
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _message = 'اتحفظت الفاتورة بنجاح.';
      });
    } catch (error) {
      _showMessage('ماقدرناش نحفظ الفاتورة: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _barcode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _neon,
                  foregroundColor: const Color(0xFF002116),
                  padding: const EdgeInsets.symmetric(vertical: 23),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _openScanner,
                icon: const Icon(Icons.photo_camera_outlined, size: 28),
                label: const Text(
                  'افتح الكاميرا',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              Text(_message, style: const TextStyle(color: _muted)),
              if (_scanning) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    height: 300,
                    child: MobileScanner(
                      onDetect: (capture) {
                        final codes = capture.barcodes;
                        final code = codes.isEmpty
                            ? null
                            : codes.first.rawValue;
                        if (code != null && code.isNotEmpty) {
                          setState(() => _scanning = false);
                          _addBarcode(code);
                        }
                      },
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _scanning = false),
                  child: const Text('إغلاق الكاميرا'),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _barcode,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        hintText: 'اكتب الباركود يدويًا',
                      ),
                      onSubmitted: _addBarcode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _addBarcode(_barcode.text),
                    child: const Text('إضافة'),
                  ),
                ],
              ),
            ],
          ),
        ),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سلة البيع • ${_cart.length} صنف',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (_cart.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.qr_code_scanner, size: 52, color: _muted),
                        SizedBox(height: 8),
                        Text(
                          'السلة فاضية',
                          style: TextStyle(color: _muted, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._cart.entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key),
                    subtitle: Text('الكمية: ${entry.value}'),
                    trailing: IconButton(
                      onPressed: () => setState(() {
                        if (entry.value <= 1) {
                          _cart.remove(entry.key);
                        } else {
                          _cart[entry.key] = entry.value - 1;
                        }
                      }),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: _finishSale,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('حفظ البيع وخصم المخزون'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _search = TextEditingController();
  final _barcode = TextEditingController();
  final _name = TextEditingController();
  final _buy = TextEditingController();
  final _sell = TextEditingController();
  final _qty = TextEditingController();
  List<Map<String, Object?>> _items = [];

  Future<void> _refresh() async {
    final data = await AppDatabase.instance.products(
      search: _search.text.trim(),
    );
    if (mounted) setState(() => _items = data);
  }

  Future<void> _save() async {
    final buy = double.tryParse(_buy.text);
    final sell = double.tryParse(_sell.text);
    final qty = int.tryParse(_qty.text);
    if (_barcode.text.trim().isEmpty ||
        _name.text.trim().isEmpty ||
        buy == null ||
        sell == null ||
        qty == null ||
        buy < 0 ||
        sell < 0 ||
        qty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('راجع بيانات المنتج والأسعار والكمية.')),
      );
      return;
    }
    await AppDatabase.instance.saveProduct(
      barcode: _barcode.text.trim(),
      name: _name.text.trim(),
      buyPrice: buy,
      sellPrice: sell,
      quantity: qty,
    );
    _barcode.clear();
    _name.clear();
    _buy.clear();
    _sell.clear();
    _qty.clear();
    await _refresh();
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    _barcode.dispose();
    _name.dispose();
    _buy.dispose();
    _sell.dispose();
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'إضافة منتج للمخزون',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _barcode,
              decoration: const InputDecoration(labelText: 'الباركود'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم المنتج'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سعر الشراء'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _sell,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سعر البيع'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الكمية'),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _save, child: const Text('حفظ المنتج')),
          ],
        ),
      ),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'المنتجات المسجلة',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'بحث بالاسم أو الباركود',
              ),
              onChanged: (_) => _refresh(),
            ),
            const SizedBox(height: 8),
            ..._items.map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${p['name']}'),
                subtitle: Text(
                  'باركود: ${p['barcode']} • شراء: ${p['buy_price']} • بيع: ${p['sell_price']}',
                ),
                trailing: Text(
                  '${p['quantity']}',
                  style: TextStyle(
                    color: (p['quantity']! as int) <= 5 ? Colors.orange : _neon,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});
  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _type = 'مصروف تشغيلي';
  List<Map<String, Object?>> _movements = [];

  Future<void> _refresh() async {
    final rows = await AppDatabase.instance.todayMovements();
    if (mounted) setState(() => _movements = rows);
  }

  Future<void> _add() async {
    final amount = double.tryParse(_amount.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اكتب مبلغ أكبر من صفر.')));
      return;
    }
    await AppDatabase.instance.addCashMovement(
      type: _type,
      amount: amount,
      note: _note.text.trim(),
    );
    _amount.clear();
    _note.clear();
    await _refresh();
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تسجيل مبلغ خارج',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              items: const [
                DropdownMenuItem(
                  value: 'مصروف تشغيلي',
                  child: Text('مصروف تشغيلي'),
                ),
                DropdownMenuItem(
                  value: 'شراء بضاعة',
                  child: Text('شراء بضاعة'),
                ),
                DropdownMenuItem(value: 'سحب شخصي', child: Text('سحب شخصي')),
                DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'مصروف تشغيلي'),
              decoration: const InputDecoration(labelText: 'نوع الحركة'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ بالجنيه'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'التفاصيل'),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _add, child: const Text('تسجيل الحركة')),
          ],
        ),
      ),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'حركات اليوم',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            ..._movements.map(
              (m) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${m['type']}'),
                subtitle: Text('${m['note'] ?? ''}'),
                trailing: Text('${m['amount']} ج.م'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    future: AppDatabase.instance.todaySales(),
    builder: (context, snapshot) {
      final sales = snapshot.data ?? const <Map<String, Object?>>[];
      double sum(String key) => sales.fold<double>(
        0,
        (total, row) => total + ((row[key] as num?)?.toDouble() ?? 0),
      );
      return ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملخص اليوم',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                _Metric(label: 'عدد الفواتير', value: '${sales.length}'),
                _Metric(
                  label: 'إجمالي المبيعات',
                  value: '${sum('total').toStringAsFixed(2)} ج.م',
                ),
                _Metric(
                  label: 'تكلفة البضاعة',
                  value: '${sum('cost').toStringAsFixed(2)} ج.م',
                ),
                _Metric(
                  label: 'مجمل الربح',
                  value: '${sum('profit').toStringAsFixed(2)} ج.م',
                ),
              ],
            ),
          ),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'آخر الفواتير',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                ...sales.map(
                  (s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('فاتورة #${s['id']}'),
                    subtitle: Text('${s['created_at']}'),
                    trailing: Text('${s['total']} ج.م'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: _muted)),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _neon,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
      ],
    ),
  );
}
