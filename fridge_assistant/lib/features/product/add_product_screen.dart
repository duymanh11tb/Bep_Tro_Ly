import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/pantry_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _searchController = TextEditingController();

  String _selectedUnit = 'Gam';
  DateTime? _purchaseDate;
  DateTime? _expiryDate;
  bool _isLoading = false;

  final List<String> _units = [
    'Gam',
    'Kg',
    'Lít',
    'Ml',
    'Cái',
    'Quả',
    'Bó',
    'Hộp',
    'Gói',
    'Chai',
    'Lon',
    'Bịch',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isPurchase}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isPurchase ? now : now.add(const Duration(days: 7)),
      firstDate: isPurchase ? DateTime(2020) : now,
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isPurchase) {
          _purchaseDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên nguyên liệu'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await PantryService.addItem(
        nameVi: name,
        quantity: double.tryParse(_quantityController.text) ?? 1,
        unit: _selectedUnit.toLowerCase(),
        expiryDate: _expiryDate,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Đã thêm "$name" vào tủ lạnh!'),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lỗi thêm sản phẩm. Vui lòng thử lại.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thêm Nguyên Liệu',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: Text(
              'Lưu',
              style: TextStyle(
                color: _isLoading ? AppColors.textHint : AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ──── Search Bar ────
                    _buildSearchBar(),
                    const SizedBox(height: 16),

                    // ──── Camera Button ────
                    _buildCameraButton(),
                    const SizedBox(height: 24),

                    // ──── Divider "HOẶC NHẬP THỦ CÔNG" ────
                    _buildDividerWithText('HOẶC NHẬP THỦ CÔNG'),
                    const SizedBox(height: 24),

                    // ──── Tên Nguyên Liệu ────
                    _buildLabel('Tên Nguyên Liệu'),
                    const SizedBox(height: 8),
                    _buildNameField(),
                    const SizedBox(height: 20),

                    // ──── Số Lượng + Đơn Vị ────
                    Row(
                      children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Số Lượng'),
                            const SizedBox(height: 8),
                            _buildQuantityField(),
                          ],
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Đơn Vị'),
                            const SizedBox(height: 8),
                            _buildUnitDropdown(),
                          ],
                        )),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ──── Ngày Mua ────
                    _buildLabel('Ngày Mua'),
                    const SizedBox(height: 8),
                    _buildDateField(
                      date: _purchaseDate,
                      placeholder: 'dd/mm/yyyy',
                      onTap: () => _pickDate(isPurchase: true),
                    ),
                    const SizedBox(height: 20),

                    // ──── Hạn Sử Dụng ────
                    _buildLabel('Hạn Sử Dụng'),
                    const SizedBox(height: 8),
                    _buildDateField(
                      date: _expiryDate,
                      placeholder: 'dd/mm/yyyy',
                      onTap: () => _pickDate(isPurchase: false),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ──── Bottom Submit Button ────
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // WIDGET BUILDERS
  // ──────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm hoặc quét mã vạch',
          hintStyle: const TextStyle(
            color: AppColors.textHint,
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.textHint, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCameraButton() {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tính năng chụp ảnh đang phát triển'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text(
              'Chụp ảnh nguyên liệu',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDividerWithText(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.divider, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.divider, thickness: 1)),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: 'Vd: Thịt bò, Cà chua',
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildQuantityField() {
    return TextField(
      controller: _quantityController,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.left,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildUnitDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedUnit,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: _units.map((unit) => DropdownMenuItem(
            value: unit,
            child: Text(unit),
          )).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedUnit = value);
          },
        ),
      ),
    );
  }

  Widget _buildDateField({
    required DateTime? date,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date != null ? _formatDate(date) : placeholder,
                style: TextStyle(
                  color: date != null ? AppColors.textPrimary : AppColors.textHint,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today_outlined,
              color: date != null ? AppColors.primary : AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Thêm vào Tủ Lạnh',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
