import 'package:flutter/material.dart';
import 'package:upi_expense_tracker/services/merchant_store.dart';
import 'package:upi_expense_tracker/utils/category_utils.dart';

class MerchantManagerScreen extends StatefulWidget {
  final List<String> knownMerchants;
  const MerchantManagerScreen({Key? key, required this.knownMerchants}) : super(key: key);

  @override
  State<MerchantManagerScreen> createState() => _MerchantManagerScreenState();
}

class _MerchantManagerScreenState extends State<MerchantManagerScreen> {
  final TextEditingController _merchantController = TextEditingController();
  SpendCategory _selectedCategory = SpendCategory.food;
  String _searchQuery = '';
  bool _formExpanded = true;
  SpendCategory? _filterCategory; // null = All

  @override
  void initState() {
    super.initState();
    // No listeners needed; autocomplete options derive from knownMerchants
  }

  @override
  void dispose() {
    _merchantController.dispose();
    super.dispose();
  }

  // No _updateFilteredMerchants needed; options filter directly

  // Reusable form widget used in page and dialog
  Widget _buildFormFields(ColorScheme scheme, {bool closeOnSubmit = false}) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
          'Merchant Name',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) {
              return const Iterable<String>.empty();
            }
            return widget.knownMerchants
                .where((m) => m.toLowerCase().contains(query))
                .toSet()
                .take(10);
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final opt = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(opt, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => onSelected(opt),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          onSelected: (String selection) {
            _merchantController.text = selection;
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            _merchantController.value = controller.value;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                hintText: 'Search existing or add new merchant',
                prefixIcon: Icon(Icons.storefront, color: scheme.primary, size: 18),
                                  border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.primary, width: 2),
                                  ),
                                  filled: true,
                fillColor: scheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
                              Text(
                                'Category',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
        const SizedBox(height: 6),
                              DropdownButtonFormField<SpendCategory>(
                                value: _selectedCategory,
          isExpanded: true,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.primary, width: 2),
                                  ),
                                  filled: true,
            fillColor: scheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                onChanged: (v) => setState(() => _selectedCategory = v ?? _selectedCategory),
                                items: SpendCategory.values.map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: getCategoryColor(c).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(getCategoryIcon(c), color: getCategoryColor(c), size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                                        child: Text(
                                          getCategoryName(c),
                                          overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                )).toList(),
          menuMaxHeight: 280,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
                          onPressed: () {
                            final name = _merchantController.text.trim();
                            if (name.isEmpty) return;
              final store = MerchantStore.instance;
                            store.upsertMapping(name, _selectedCategory);
              setState(() {});
                            _merchantController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                  content: Row(children: [Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text('Added $name to ${getCategoryName(_selectedCategory)}'))]),
                  backgroundColor: Colors.green[600],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
              if (closeOnSubmit) Navigator.pop(context);
            },
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Add Merchant', style: TextStyle(fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
                          ),
                        ),
                      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = MerchantStore.instance;
    final entries = store.mappings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        title: const Text('Manage Merchants'),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return MediaQuery.removeViewInsets(
                removeBottom: true,
                context: context,
                child: AlertDialog(
                  title: const Text('Add Merchant'),
                  content: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _buildFormFields(scheme, closeOnSubmit: true),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                _CategoryFilterButton(
                  label: 'All',
                  isSelected: _filterCategory == null,
                  color: scheme.primary,
                  icon: Icons.all_inclusive,
                  onTap: () => setState(() => _filterCategory = null),
                ),
                ...SpendCategory.values.map((c) => _CategoryFilterButton(
                  label: getCategoryName(c),
                  isSelected: _filterCategory == c,
                  color: getCategoryColor(c),
                  icon: getCategoryIcon(c),
                  onTap: () => setState(() => _filterCategory = c),
                )),
              ],
            ),

            const SizedBox(height: 12),

            // Scrollable area only for cards (1 per row)
            Expanded(
              child: entries.isEmpty
                  ? Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store_mall_directory_outlined, size: 48, color: scheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text('No merchants added yet', style: TextStyle(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final list = _filterCategory == null
                            ? entries
                            : entries.where((e) => e.value == _filterCategory).toList();
                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final e = list[index];
                            return _MerchantCard(entry: e);
                          },
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

class _MerchantCard extends StatelessWidget {
  final MapEntry<String, SpendCategory> entry;
  const _MerchantCard({Key? key, required this.entry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            scheme.surface,
            getCategoryColor(entry.value).withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: getCategoryColor(entry.value).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(getCategoryIcon(entry.value), color: getCategoryColor(entry.value), size: 18),
        ),
        title: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(getCategoryName(entry.value), style: TextStyle(color: getCategoryColor(entry.value), fontSize: 11)),
        trailing: _DeleteButton(merchantKey: entry.key),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final String merchantKey;
  const _DeleteButton({Key? key, required this.merchantKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: scheme.error.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.delete_outline, color: scheme.error, size: 18),
      ),
      onPressed: () {
        final store = MerchantStore.instance;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Merchant'),
            content: Text('Remove "$merchantKey" from your merchants?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                        onPressed: () {
                  store.removeMapping(merchantKey);
                  Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                      content: Row(children: [Icon(Icons.delete_forever, color: Colors.white), const SizedBox(width: 8), Text('Removed $merchantKey')]),
                              backgroundColor: scheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          );
                        },
                style: ElevatedButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                child: const Text('Delete'),
                      ),
            ],
                    ),
                  );
                },
    );
  }
}

class _CategoryFilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryFilterButton({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.icon,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? color : scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
