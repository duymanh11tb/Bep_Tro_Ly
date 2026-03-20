import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/fridge_service.dart';
import '../models/fridge_model.dart';

class FridgeSelector extends StatefulWidget {
  final int? selectedFridgeId;
  final Function(FridgeModel) onSelected;
  final bool isCompact;

  const FridgeSelector({
    super.key,
    this.selectedFridgeId,
    required this.onSelected,
    this.isCompact = false,
  });

  @override
  State<FridgeSelector> createState() => _FridgeSelectorState();
}

class _FridgeSelectorState extends State<FridgeSelector> {
  List<FridgeModel> _fridges = [];
  bool _isLoading = true;
  int? _currentId;

  @override
  void initState() {
    super.initState();
    _currentId = widget.selectedFridgeId;
    _loadFridges();
  }

  Future<void> _loadFridges() async {
    final fridges = await FridgeService().getFridges();
    if (!mounted) return;

    setState(() {
      _fridges = fridges;
      _isLoading = false;
      
      if (_currentId == null && fridges.isNotEmpty) {
        // Fallback to active fridge if not provided
        _setInitialActive();
      }
    });
  }

  Future<void> _setInitialActive() async {
    final activeId = await FridgeService.getActiveFridgeId();
    if (!mounted) return;
    if (activeId != null) {
      setState(() {
        _currentId = activeId;
        final fridge = _fridges.firstWhere((f) => f.fridgeId == activeId, 
            orElse: () => _fridges.first);
        widget.onSelected(fridge);
      });
    } else if (_fridges.isNotEmpty) {
      setState(() {
        _currentId = _fridges.first.fridgeId;
        widget.onSelected(_fridges.first);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_fridges.isEmpty) {
      return const Text('Chưa có tủ lạnh nào', style: TextStyle(color: Colors.red));
    }

    if (widget.isCompact) {
      final selected = _fridges.firstWhere(
        (f) => f.fridgeId == _currentId,
        orElse: () => _fridges.first,
      );

      return InkWell(
        onTap: _showPicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.kitchen, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                selected.name,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: AppColors.primary),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn tủ lạnh',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _currentId,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
              items: _fridges.map((f) => DropdownMenuItem(
                value: f.fridgeId,
                child: Text(f.name),
              )).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _currentId = val);
                  final fridge = _fridges.firstWhere((f) => f.fridgeId == val);
                  widget.onSelected(fridge);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chọn tủ lạnh đích',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ..._fridges.map((f) => ListTile(
                  leading: Icon(
                    Icons.kitchen, 
                    color: f.fridgeId == _currentId ? AppColors.primary : Colors.grey
                  ),
                  title: Text(
                    f.name,
                    style: TextStyle(
                      fontWeight: f.fridgeId == _currentId ? FontWeight.bold : FontWeight.normal,
                      color: f.fridgeId == _currentId ? AppColors.primary : Colors.black,
                    ),
                  ),
                  trailing: f.fridgeId == _currentId 
                      ? const Icon(Icons.check, color: AppColors.primary) 
                      : null,
                  onTap: () {
                    setState(() => _currentId = f.fridgeId);
                    widget.onSelected(f);
                    Navigator.pop(context);
                  },
                )),
              ],
            ),
          ),
        );
      },
    );
  }
}
