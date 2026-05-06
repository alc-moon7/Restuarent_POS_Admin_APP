import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/menu_image_view.dart';
import '../../core/widgets/menu_item_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/menu_item.dart';
import '../../services/menu_image_service.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final categories = ['All', ...app.categories];
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = 'All';
    }

    final query = _searchController.text.trim().toLowerCase();
    final items = app.menuItems
        .where((item) {
          final matchesCategory =
              _selectedCategory == 'All' || item.category == _selectedCategory;
          final matchesQuery =
              query.isEmpty ||
              item.name.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query) ||
              item.category.toLowerCase().contains(query);
          return matchesCategory && matchesQuery;
        })
        .toList(growable: false);

    final stats = _MenuStats.from(app.menuItems);

    return AppScaffold(
      title: 'Menu Management',
      subtitle: 'Create, edit, and control availability across the cloud menu.',
      actions: [
        PrimaryButton(
          label: 'Add Item',
          icon: Icons.add,
          onPressed: () => _openMenuForm(context),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsStrip(
            stats: stats,
            currency: NumberFormat.compactCurrency(symbol: r'$'),
          ),
          SizedBox(height: 14),
          _MenuToolbar(
            searchController: _searchController,
            onSearchChanged: (_) => setState(() {}),
          ),
          SizedBox(height: 12),
          if (app.menuItems.isNotEmpty)
            _CategoryStrip(
              categories: categories,
              selectedCategory: _selectedCategory,
              countOf: (cat) => cat == 'All'
                  ? app.menuItems.length
                  : app.menuItems.where((i) => i.category == cat).length,
              onSelected: (value) => setState(() => _selectedCategory = value),
            ),
          SizedBox(height: 14),
          if (app.menuItems.isEmpty)
            EmptyState(
              title: 'No menu items yet',
              message:
                  'Add your first item and it will sync to the cloud menu API.',
              icon: Icons.restaurant_menu,
              action: PrimaryButton(
                label: 'Add Menu Item',
                icon: Icons.add,
                onPressed: () => _openMenuForm(context),
              ),
            )
          else if (items.isEmpty)
            EmptyState(
              title: 'No items found',
              message: 'Try another search term or category filter.',
              icon: Icons.search_off,
            )
          else
            _MenuGrid(
              items: items,
              onEdit: (item) => _openMenuForm(context, item: item),
              onDelete: (item) => _confirmDelete(context, item),
              onAvailabilityChanged: (item, value) async {
                await app.toggleMenuAvailability(item.id, value);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openMenuForm(BuildContext context, {MenuItem? item}) async {
    final app = AppScope.of(context);
    final result = await showModalBottomSheet<_MenuFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _MenuItemForm(initialItem: item),
    );
    if (result == null) return;
    await app.saveMenuItem(
      id: item?.id,
      name: result.name,
      description: result.description,
      category: result.category,
      price: result.price,
      imageUrl: result.imageUrl,
      isAvailable: result.isAvailable,
      preparationTimeMinutes: result.preparationTimeMinutes,
      tags: result.tags,
      createdAt: item?.createdAt,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(item == null ? 'Menu item added' : 'Menu item updated'),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, MenuItem item) async {
    final app = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete menu item?'),
        content: Text(
          '${item.name} will be removed from the admin app and future API responses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await app.deleteMenuItem(item.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Menu item deleted')));
  }
}

class _MenuToolbar extends StatelessWidget {
  const _MenuToolbar({required this.searchController, required this.onSearchChanged});

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search by item, description, or category',
          ),
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats, required this.currency});

  final _MenuStats stats;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final values = [
      _StatValue(
        label: 'Items',
        value: stats.total.toString(),
        icon: Icons.restaurant_menu_rounded,
        color: PosColors.primary,
      ),
      _StatValue(
        label: 'Available',
        value: stats.available.toString(),
        icon: Icons.check_circle_outline,
        color: PosColors.success,
      ),
      _StatValue(
        label: 'Categories',
        value: stats.categories.toString(),
        icon: Icons.category_outlined,
        color: PosColors.info,
      ),
      _StatValue(
        label: 'Avg Price',
        value: stats.averagePrice == 0
            ? '-'
            : currency.format(stats.averagePrice),
        icon: Icons.payments_outlined,
        color: PosColors.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: columns == 1 ? 3.6 : 2.65,
          children: values
              .map((value) => _MenuStatTile(value: value))
              .toList(growable: false),
        );
      },
    );
  }
}

class _MenuStatTile extends StatelessWidget {
  const _MenuStatTile({required this.value});

  final _StatValue value;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: PosGradients.cardTint(value.color),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: value.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(PosRadii.md),
                    border: Border.all(
                      color: value.color.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(value.icon, color: value.color, size: 19),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 2),
                      Text(
                        value.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: PosColors.muted,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selectedCategory,
    required this.countOf,
    required this.onSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final int Function(String category) countOf;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == selectedCategory;
          return ChoiceChip(
            selected: selected,
            label: Text('$category (${countOf(category)})'),
            onSelected: (_) => onSelected(category),
            avatar: selected
                ? Icon(Icons.check_rounded, size: 16, color: PosColors.primary)
                : null,
          );
        },
      ),
    );
  }
}

class _StatValue {
  _StatValue({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MenuStats {
  _MenuStats({
    required this.total,
    required this.available,
    required this.categories,
    required this.averagePrice,
  });

  final int total;
  final int available;
  final int categories;
  final double averagePrice;

  static _MenuStats from(List<MenuItem> items) {
    final total = items.length;
    final available = items.where((item) => item.isAvailable).length;
    final categories = items.map((item) => item.category).toSet().length;
    final averagePrice = total == 0
        ? 0.0
        : items.fold<double>(0, (sum, item) => sum + item.price) / total;
    return _MenuStats(
      total: total,
      available: available,
      categories: categories,
      averagePrice: averagePrice,
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({
    required this.items,
    required this.onEdit,
    required this.onDelete,
    required this.onAvailabilityChanged,
  });

  final List<MenuItem> items;
  final ValueChanged<MenuItem> onEdit;
  final ValueChanged<MenuItem> onDelete;
  final void Function(MenuItem item, bool value) onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1150
            ? 3
            : constraints.maxWidth >= 720
            ? 2
            : 1;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: columns == 1
                ? 0.72
                : columns == 2
                ? 0.76
                : 0.8,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return MenuItemCard(
              item: item,
              onEdit: () => onEdit(item),
              onDelete: () => onDelete(item),
              onAvailabilityChanged: (value) =>
                  onAvailabilityChanged(item, value),
            );
          },
        );
      },
    );
  }
}

class _MenuItemForm extends StatefulWidget {
  const _MenuItemForm({this.initialItem});

  final MenuItem? initialItem;

  @override
  State<_MenuItemForm> createState() => _MenuItemFormState();
}

class _MenuItemFormState extends State<_MenuItemForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  late final TextEditingController _imageController;
  late final TextEditingController _prepController;
  final MenuImageService _imageService = MenuImageService();
  late bool _isAvailable;
  late Set<String> _tags;
  bool _imageBusy = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _categoryController = TextEditingController(text: item?.category ?? '');
    _priceController = TextEditingController(
      text: item == null ? '' : item.price.toStringAsFixed(2),
    );
    _imageController = TextEditingController(text: item?.imageUrl ?? '');
    _prepController = TextEditingController(
      text: item?.preparationTimeMinutes?.toString() ?? '',
    );
    _isAvailable = item?.isAvailable ?? true;
    _tags = {...?item?.tags};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    _prepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.initialItem == null
                            ? 'Add Menu Item'
                            : 'Edit Menu Item',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: 'Item name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Item name is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: 'Description'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Description is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final category = TextFormField(
                      controller: _categoryController,
                      decoration: InputDecoration(labelText: 'Category'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Category is required';
                        }
                        return null;
                      },
                    );
                    final price = TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(labelText: 'Price'),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        final price = double.tryParse(value ?? '');
                        if (price == null || price <= 0) {
                          return 'Enter a valid price';
                        }
                        return null;
                      },
                    );
                    if (compact) {
                      return Column(
                        children: [category, SizedBox(height: 10), price],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: category),
                        SizedBox(width: 12),
                        Expanded(child: price),
                      ],
                    );
                  },
                ),
                SizedBox(height: 10),
                _ImagePickerField(
                  controller: _imageController,
                  busy: _imageBusy,
                  onPick: _pickImage,
                  onClear: () {
                    _imageController.clear();
                    setState(() {});
                  },
                  onChanged: (_) => setState(() {}),
                ),
                if (_imageController.text.trim().isNotEmpty) ...[
                  SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1.8,
                      child: MenuImageView(
                        imageUrl: _imageController.text.trim(),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 10),
                TextFormField(
                  controller: _prepController,
                  decoration: InputDecoration(
                    labelText: 'Preparation time',
                    hintText: 'Minutes, optional',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                SizedBox(height: 10),
                SwitchListTile.adaptive(
                  value: _isAvailable,
                  onChanged: (value) => setState(() => _isAvailable = value),
                  contentPadding: EdgeInsets.zero,
                  title: Text('Available for ordering'),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: Text('Veg'),
                      selected: _tags.contains('veg'),
                      onSelected: (selected) => _toggleTag('veg', selected),
                    ),
                    FilterChip(
                      label: Text('Spicy'),
                      selected: _tags.contains('spicy'),
                      onSelected: (selected) => _toggleTag('spicy', selected),
                    ),
                    FilterChip(
                      label: Text('Popular'),
                      selected: _tags.contains('popular'),
                      onSelected: (selected) => _toggleTag('popular', selected),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: Icon(Icons.save_outlined),
                    label: Text(
                      widget.initialItem == null ? 'Create Item' : 'Save Item',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleTag(String tag, bool selected) {
    setState(() {
      if (selected) {
        _tags.add(tag);
      } else {
        _tags.remove(tag);
      }
    });
  }

  Future<void> _pickImage() async {
    final app = AppScope.of(context);
    setState(() => _imageBusy = true);
    try {
      final dataUrl = await _imageService.pickMenuImageDataUrl();
      if (dataUrl == null) return;
      var imageUrl = dataUrl;
      var uploadWarning = false;
      try {
        imageUrl = await app.uploadMenuImageDataUrl(dataUrl);
      } catch (_) {
        uploadWarning = true;
      }
      _imageController.text = imageUrl;
      if (mounted) setState(() {});
      if (!mounted) return;
      final uploaded = !imageUrl.startsWith('data:image/');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uploadWarning
                ? 'Image kept locally. Cloud upload will need internet.'
                : uploaded
                ? 'Image uploaded to cloud'
                : 'Image saved locally. It will sync when cloud is ready.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _imageBusy = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _MenuFormResult(
        name: _nameController.text,
        description: _descriptionController.text,
        category: _categoryController.text,
        price: double.parse(_priceController.text),
        imageUrl: _imageController.text,
        isAvailable: _isAvailable,
        preparationTimeMinutes: int.tryParse(_prepController.text),
        tags: _tags.toList(growable: false)..sort(),
      ),
    );
  }
}

class _ImagePickerField extends StatelessWidget {
  const _ImagePickerField({
    required this.controller,
    required this.busy,
    required this.onPick,
    required this.onClear,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: 'Image URL or gallery image',
            hintText: 'Optional',
            prefixIcon: Icon(Icons.image_outlined),
          ),
          minLines: 1,
          maxLines: 2,
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : onPick,
              icon: busy
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.photo_library_outlined),
              label: Text('Choose from gallery'),
            ),
            OutlinedButton.icon(
              onPressed: controller.text.trim().isEmpty ? null : onClear,
              icon: Icon(Icons.clear),
              label: Text('Clear image'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MenuFormResult {
  _MenuFormResult({
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.isAvailable,
    required this.tags,
    this.imageUrl,
    this.preparationTimeMinutes,
  });

  final String name;
  final String description;
  final String category;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final int? preparationTimeMinutes;
  final List<String> tags;
}
