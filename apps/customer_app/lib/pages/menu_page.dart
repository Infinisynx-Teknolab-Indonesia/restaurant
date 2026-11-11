import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

import '../cart.dart';
import 'checkout_page.dart';
import 'home_shell.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});
  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List<MenuCategory>? _cats;
  String? _error;
  int _sel = 0; // 0 = semua
  String _kind = ''; // '' | food | drink
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
    menuTick.addListener(_load);
  }

  @override
  void dispose() {
    menuTick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await api.menu();
      if (mounted) setState(() { _cats = c; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final cart = context.watch<Cart>();
    final user = s.user!;
    final cats = _cats ?? [];
    final kindCats = cats.where((c) => _kind.isEmpty || c.kind == _kind).toList();
    final all = kindCats.expand((c) => c.items).toList();
    final rec = all.where((i) => i.isRecommended).toList();
    final shown = all.where((i) =>
        (_sel == 0 || i.categoryId == _sel) && (_q.isEmpty || i.name.toLowerCase().contains(_q.toLowerCase()))).toList();
    final hour = DateTime.now().hour;
    final greet = hour < 11 ? 'Selamat pagi' : hour < 15 ? 'Selamat siang' : hour < 18 ? 'Selamat sore' : 'Selamat malam';
    final cols = (MediaQuery.sizeOf(context).width / 200).floor().clamp(2, 6);

    return Scaffold(
      body: PullRefresh(
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: GradientHeader(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 14, 20, 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${tr(greet)},', style: TextStyle(color: Colors.white.withValues(alpha: .8))),
                      Text(user.name, style: serifStyle(size: 26, color: Colors.white)),
                    ]),
                  ),
                  InkWell(
                    onTap: () => HomeShell.goTab(context, 3),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(99)),
                      child: Row(children: [
                        const Icon(Icons.stars_rounded, size: 18, color: Color(0xFFFCD34D)),
                        const SizedBox(width: 6),
                        AnimatedNumber(value: user.points, format: (v) => '${angka(v)} poin', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ]),
                if (s.info != null) ...[
                  const SizedBox(height: 6),
                  Text(tr('${s.info!.name} · Buka ${s.info!.openHours}'), style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 12.5)),
                ],
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: tr('Cari roti, kue, kopi...'),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ]),
            ),
          ),
          if (_error != null && _cats == null)
            SliverFillRemaining(child: ErrorView(message: _error!, onRetry: _load))
          else if (_cats == null)
            const SliverFillRemaining(child: LoadingView())
          else ...[
            if (rec.isNotEmpty && _q.isEmpty && _sel == 0) ...[
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SectionTitle('Rekomendasi', icon: Icons.local_fire_department_rounded))),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 214,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: rec.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => SizedBox(width: 168, child: _ItemCard(item: rec[i], qty: cart.qtyOf(rec[i].id), cats: cats)),
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SizedBox(
                height: 58,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _kindChip('', 'Semua', Icons.apps_rounded),
                    _kindChip('food', 'Makanan', Icons.restaurant_rounded),
                    _kindChip('drink', 'Minuman', Icons.local_cafe_rounded),
                    Container(width: 1, height: 26, margin: const EdgeInsets.fromLTRB(4, 4, 10, 4), color: context.borderColor),
                    for (final c in kindCats) _catChip(c.id, c.name, categoryIcon(c.icon)),
                  ],
                ),
              ),
            ),
            if (shown.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: EmptyView(icon: Icons.search_off_rounded, text: tr('Menu tidak ditemukan')))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .78),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _ItemCard(item: shown[i], qty: cart.qtyOf(shown[i].id), cats: cats),
                    childCount: shown.length,
                  ),
                ),
              ),
          ],
        ]),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: cart.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutPage())),
                  child: Row(children: [
                    PopIn(key: ValueKey(cart.count), duration: const Duration(milliseconds: 600), child: Badge(label: Text('${cart.count}'), child: const Icon(Icons.shopping_bag_rounded))),
                    const SizedBox(width: 14),
                    Expanded(child: Text(tr('Lihat Keranjang'), style: TextStyle(fontSize: 16))),
                    Text(rupiah(cart.subtotal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
    );
  }

  Widget _kindChip(String kind, String name, IconData icon) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          avatar: Icon(icon, size: 18),
          label: Text(name),
          selected: _kind == kind && _sel == 0,
          showCheckmark: false,
          onSelected: (_) => setState(() {
            _kind = kind;
            _sel = 0;
          }),
        ),
      );

  Widget _catChip(int id, String name, IconData icon) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: Icon(icon, size: 18),
          label: Text(name),
          selected: _sel == id,
          showCheckmark: false,
          onSelected: (_) => setState(() => _sel = id),
        ),
      );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.qty, required this.cats});
  final MenuItem item;
  final int qty;
  final List<MenuCategory> cats;

  @override
  Widget build(BuildContext context) {
    final icon = categoryIcon(cats.firstWhere((c) => c.id == item.categoryId, orElse: () => cats.first).icon);
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => showItemSheet(context, item, icon),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            MenuImage(url: item.imageUrl, icon: icon, radius: 0),
            if (qty > 0)
              Positioned(
                top: 8, right: 8,
                child: CircleAvatar(radius: 13, backgroundColor: context.cs.primary,
                    child: Text('$qty', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(child: Text(rupiah(item.price), style: TextStyle(color: context.cs.primary, fontWeight: FontWeight.w800))),
              InkWell(
                onTap: () {
                  context.read<Cart>().add(item);
                  showSnack(context, '${item.name} ditambahkan');
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: context.cs.primary, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

Future<void> showItemSheet(BuildContext context, MenuItem item, IconData icon) {
  final cart = context.read<Cart>();
  int qty = cart.qtyOf(item.id) > 0 ? cart.qtyOf(item.id) : 1;
  final notes = TextEditingController(text: cart.lines.where((l) => l.item.id == item.id).map((l) => l.notes).firstOrNull ?? '');
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MenuImage(url: item.imageUrl, icon: icon, height: 190, radius: 16),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Text(item.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            Text(rupiah(item.price), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.cs.primary)),
          ]),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.description, style: TextStyle(color: c.muted)),
          ],
          const SizedBox(height: 16),
          TextField(controller: notes, decoration: deco(c, 'Catatan (opsional)', icon: Icons.edit_note_rounded, hint: 'Contoh: tidak pedas, dipanaskan')),
          const SizedBox(height: 18),
          Row(children: [
            QtyStepper(qty: qty, min: 1, onChanged: (v) => setSt(() => qty = v)),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    if (cart.qtyOf(item.id) > 0) {
                      cart.setQty(item.id, qty);
                      cart.setNotes(item.id, notes.text.trim());
                    } else {
                      cart.add(item, qty: qty, notes: notes.text.trim());
                    }
                    Navigator.pop(c);
                  },
                  child: Text(tr('Tambah · ${rupiah(item.price * qty)}')),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}
