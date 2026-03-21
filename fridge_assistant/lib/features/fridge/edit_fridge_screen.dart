import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/fridge_service.dart';
import '../../models/fridge_model.dart';

class EditFridgeScreen extends StatefulWidget {
  final FridgeModel fridge;
  const EditFridgeScreen({super.key, required this.fridge});

  @override
  State<EditFridgeScreen> createState() => _EditFridgeScreenState();
}

class _EditFridgeScreenState extends State<EditFridgeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  bool _isPaused = false;
  final FridgeService _fridgeService = FridgeService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.fridge.name);
    _locationController = TextEditingController(text: widget.fridge.location);
    _isPaused = widget.fridge.status == 'paused';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final result = await _fridgeService.updateFridge(
        widget.fridge.fridgeId,
        _nameController.text,
        _locationController.text,
        status: _isPaused ? 'paused' : 'active',
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Đã cập nhật thành công')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'])),
          );
        }
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa tủ lạnh này không? Mọi dữ liệu liên quan sẽ bị mất.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final result = await _fridgeService.deleteFridge(widget.fridge.fridgeId);

      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Đã xóa tủ lạnh thành công')),
          );
          // If the deleted fridge was active, clear it
          final activeId = await FridgeService.getActiveFridgeId();
          if (activeId == widget.fridge.fridgeId) {
             // We don't have a clearActive method yet, but we can set it to a non-existent ID or handle in UI
          }
          Navigator.pop(context, 'deleted');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'])),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chỉnh sửa tủ lạnh',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _isLoading ? null : _handleDelete,
          ),
        ],
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(
                label: 'Tên tủ lạnh',
                controller: _nameController,
                validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập tên tủ' : null,
              ),
              const SizedBox(height: 24),
              _buildTextField(
                label: 'Mô tả/ Vị trí',
                controller: _locationController,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Tạm ngưng hoạt động',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: const Text('Khi tạm ngưng, tủ lạnh sẽ không thể thêm/sửa sản phẩm'),
                  value: _isPaused,
                  activeColor: Colors.red,
                  onChanged: (bool value) {
                    setState(() => _isPaused = value);
                  },
                ),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Lưu thay đổi',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}
