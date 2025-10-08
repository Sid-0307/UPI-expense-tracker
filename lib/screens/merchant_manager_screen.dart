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
  final TextEditingController _searchController = TextEditingController();
  SpendCategory _selectedCategory = SpendCategory.food;
  String _searchQuery = '';
  SpendCategory? _filterCategory; // null = All

  @override
  void initState() {
    super.initState();
    _initializeStore();
  }

  Future<void> _initializeStore() async {
    await MerchantStore.instance.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Reusable form widget used in dialog
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
            onPressed: () async {
                            final name = _merchantController.text.trim();
                            if (name.isEmpty) return;
              final store = MerchantStore.instance;
              await store.upsertMapping(name, _selectedCategory);
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

  // Show edit dialog for a specific merchant
  void _showEditDialog(String merchantName, SpendCategory currentCategory) {
    SpendCategory editCategory = currentCategory;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Merchant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Merchant: $merchantName',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Text('Category', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setDialogState) => DropdownButtonFormField<SpendCategory>(
                value: editCategory,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (v) => setDialogState(() => editCategory = v ?? editCategory),
                items: SpendCategory.values.map((c) => DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      Icon(getCategoryIcon(c), color: getCategoryColor(c), size: 16),
                      const SizedBox(width: 8),
                      Text(getCategoryName(c)),
                    ],
                  ),
                )).toList(),
                          ),
                        ),
                      ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await MerchantStore.instance.upsertMapping(merchantName, editCategory);
              setState(() {}); // Refresh main screen
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.white),
                      const SizedBox(width: 8),
                      Text('Updated $merchantName'),
                    ],
                  ),
                  backgroundColor: Colors.blue[600],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // Handle merchant deletion with immediate UI update
  Future<void> _deleteMerchant(String merchantKey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Merchant'),
        content: Text('Remove "$merchantKey" from your merchants?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await MerchantStore.instance.removeMapping(merchantKey);
      setState(() {}); // Immediately update UI

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.delete_forever, color: Colors.white),
                const SizedBox(width: 8),
                Text('Removed $merchantKey'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  // Helper method to build category filter chips
  Widget _buildCategoryFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Merchant',
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
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search merchants...',
                prefixIcon: Icon(Icons.search, color: scheme.primary, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: scheme.onSurfaceVariant, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
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
            ),

            const SizedBox(height: 12),

            // Horizontal scrolling category filters
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: SizedBox(
                height: 40,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // All Categories button
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildCategoryFilterChip(
                          label: 'All',
                          icon: Icons.all_inclusive,
                          isSelected: _filterCategory == null,
                          color: scheme.primary,
                          onTap: () => setState(() => _filterCategory = null),
                        ),
                      ),
                      // Individual category buttons
                      ...SpendCategory.values.map((category) {
                        final categoryColor = category == SpendCategory.others
                            ? getCategoryColor(category, colorScheme: scheme)
                            : getCategoryColor(category);

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildCategoryFilterChip(
                            label: getCategoryName(category),
                            icon: getCategoryIcon(category),
                            isSelected: _filterCategory == category,
                            color: categoryColor,
                            onTap: () => setState(() => _filterCategory = category),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Results count
            Builder(
              builder: (context) {
                final filteredEntries = entries.where((e) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      e.key.toLowerCase().contains(_searchQuery);
                  final matchesCategory = _filterCategory == null ||
                      e.value == _filterCategory;
                  return matchesSearch && matchesCategory;
                }).toList();

                return Text(
                  '${filteredEntries.length} merchant${filteredEntries.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),

            const SizedBox(height: 8),

            // Merchant list
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
                    Icon(Icons.store_mall_directory_outlined,
                        size: 48, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text('No merchants added yet',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              )
                  : Builder(
                builder: (context) {
                  final filteredList = entries.where((e) {
                    final matchesSearch = _searchQuery.isEmpty ||
                        e.key.toLowerCase().contains(_searchQuery);
                    final matchesCategory = _filterCategory == null ||
                        e.value == _filterCategory;
                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (filteredList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 48, color: scheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text('No merchants found',
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = filteredList[index];
                      return _MerchantCard(
                        entry: entry,
                        onEdit: () => _showEditDialog(entry.key, entry.value),
                        onDelete: () => _deleteMerchant(entry.key),
                      );
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MerchantCard({
    Key? key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: getCategoryColor(entry.value).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(getCategoryIcon(entry.value),
              color: getCategoryColor(entry.value), size: 16),
        ),
        title: Text(entry.key,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(getCategoryName(entry.value),
            style: TextStyle(color: getCategoryColor(entry.value), fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.edit, color: scheme.primary, size: 16),
              ),
              onPressed: onEdit,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.delete_outline, color: scheme.error, size: 16),
              ),
              onPressed: onDelete,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}