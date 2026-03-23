import 'package:flutter/material.dart';
import '../../models/ingredient.dart';
import '../../services/ingredient_service.dart';
import '../../core/theme/app_colors.dart';

class AddEditIngredientScreen extends StatefulWidget {
  final Ingredient? ingredient;
  
  const AddEditIngredientScreen({super.key, this.ingredient});
  
  @override
  State<AddEditIngredientScreen> createState() => _AddEditIngredientScreenState();
}

class _AddEditIngredientScreenState extends State<AddEditIngredientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  DateTime? _expiryDate;
  
  final IngredientService _service = IngredientService();
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.ingredient != null) {
      _nameController.text = widget.ingredient!.name;
      _quantityController.text = widget.ingredient!.quantity.toString();
      _unitController.text = widget.ingredient!.unit;
      _expiryDate = widget.ingredient!.expiryDate;
    } else {
      _unitController.text = 'kg';
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }
  
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final ingredient = Ingredient(
        id: widget.ingredient?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        quantity: double.parse(_quantityController.text),
        unit: _unitController.text,
        expiryDate: _expiryDate,
        createdAt: widget.ingredient?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      if (widget.ingredient == null) {
        await _service.addIngredient(ingredient);
      } else {
        await _service.updateIngredient(ingredient);
      }
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ingredient == null ? 'Thêm nguyên liệu' : 'Sửa nguyên liệu'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên nguyên liệu',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.food_bank),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập tên nguyên liệu';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Số lượng',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập số lượng';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Số lượng không hợp lệ';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Đơn vị',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập đơn vị';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(_expiryDate == null
                  ? 'Chọn ngày hết hạn'
                  : 'HSD: ${_formatDate(_expiryDate!)}'),
              subtitle: const Text('Để trống nếu không có hạn sử dụng'),
              onTap: () => _selectDate(context),
              tileColor: Colors.grey[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(widget.ingredient == null ? 'THÊM' : 'CẬP NHẬT'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() => _expiryDate = date);
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
