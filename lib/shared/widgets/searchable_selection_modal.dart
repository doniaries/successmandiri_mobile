import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SearchableSelectionModal extends StatefulWidget {
  final String title;
  final List<dynamic> items;
  final int? selectedId;
  final String labelKey;
  final String? subLabelKey;
  final String? hint;
  final Widget? addNewScreen;
  final String? addNewLabel;

  const SearchableSelectionModal({
    super.key,
    required this.title,
    required this.items,
    this.selectedId,
    required this.labelKey,
    this.subLabelKey,
    this.hint,
    this.addNewScreen,
    this.addNewLabel,
  });

  static Future<int?> show({
    required BuildContext context,
    required String title,
    required List<dynamic> items,
    int? selectedId,
    required String labelKey,
    String? subLabelKey,
    String? hint,
    Widget? addNewScreen,
    String? addNewLabel,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchableSelectionModal(
        title: title,
        items: items,
        selectedId: selectedId,
        labelKey: labelKey,
        subLabelKey: subLabelKey,
        hint: hint,
        addNewScreen: addNewScreen,
        addNewLabel: addNewLabel,
      ),
    );
  }

  @override
  State<SearchableSelectionModal> createState() => _SearchableSelectionModalState();
}

class _SearchableSelectionModalState extends State<SearchableSelectionModal> {
  late List<dynamic> _filteredItems;
  final TextEditingController _searchController = TextEditingController();
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = widget.items.where((item) {
        final label = item[widget.labelKey]?.toString().toLowerCase() ?? '';
        return label.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF01579B),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: widget.hint ?? 'Cari...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF01579B)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // List
              Expanded(
                child: _filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'Data tidak ditemukan',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            if (widget.addNewScreen != null) ...[
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF01579B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  elevation: 2,
                                ),
                                icon: const Icon(Icons.add_rounded, size: 20),
                                label: Text(
                                  widget.addNewLabel ?? 'TAMBAH BARU',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () async {
                                  FocusScope.of(context).unfocus();
                                  final navigator = Navigator.of(context);
                                  final newRecord = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => widget.addNewScreen!),
                                  );
                                  if (newRecord != null) {
                                    int? newId;
                                    if (newRecord is Map) {
                                      newId = newRecord['id'] as int?;
                                    } else {
                                      try {
                                        newId = (newRecord as dynamic).id as int?;
                                      } catch (_) {}
                                    }
                                    if (newId != null) {
                                      navigator.pop(newId);
                                    }
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final id = item['id'] as int;
                          final label = item[widget.labelKey]?.toString() ?? '';
                          final isSelected = id == widget.selectedId;
                          
                          double? subLabelValue;
                          if (widget.subLabelKey != null) {
                            subLabelValue = double.tryParse(item[widget.subLabelKey]?.toString() ?? '0');
                          }

                          return ListTile(
                            onTap: () => Navigator.pop(context, id),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            title: Text(
                              label.toUpperCase(),
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? const Color(0xFF01579B) : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: subLabelValue != null && subLabelValue > 0
                                ? Text(
                                    'Hutang: ${currencyFormat.format(subLabelValue)}',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF01579B))
                                : null,
                            selected: isSelected,
                            selectedTileColor: const Color(0xFFE3F2FD).withValues(alpha: 0.5),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
