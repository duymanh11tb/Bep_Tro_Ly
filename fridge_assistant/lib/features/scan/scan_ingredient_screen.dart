import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/fridge_selector.dart';
import '../dashboard/dashboard_screen.dart';
import '../../services/barcode_lookup_service.dart';
import '../../services/pantry_service.dart';
import '../../services/fridge_service.dart';

class ScanIngredientScreen extends StatefulWidget {
  const ScanIngredientScreen({super.key});

  @override
  State<ScanIngredientScreen> createState() => _ScanIngredientScreenState();
}

class _ScanIngredientScreenState extends State<ScanIngredientScreen> {
  bool _flashOn = false;
  CameraController? _cameraController;
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isInitializingCamera = true;
  bool _isCapturing = false;
  bool _isScanningText = false;
  final List<XFile> _capturedImages = [];
  int? _selectedFridgeId;
  FridgeModel? _selectedFridge;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _barcodeScanner.close();
    _textRecognizer.close();
    super.dispose();
  }

  Future<bool> _handleAddItem({
    required String nameVi,
    double quantity = 1,
    String unit = 'cái',
    DateTime? expiryDate,
    String? notes,
  }) async {
    if (_selectedFridge?.status == 'paused') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tủ lạnh "${_selectedFridge?.name}" đang tạm ngưng. Không thể thêm nguyên liệu.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    return await PantryService.addItem(
      nameVi: nameVi,
      quantity: quantity,
      unit: unit,
      expiryDate: expiryDate,
      notes: notes,
      fridgeId: _selectedFridgeId,
    );
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _isInitializingCamera = false);
        return;
      }

      await _startCamera(_currentCameraIndex);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isInitializingCamera = false);
    }
  }

  Future<void> _startCamera(int index) async {
    final oldController = _cameraController;
    final newController = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await oldController?.dispose();
    _cameraController = newController;

    try {
      await newController.initialize();
      await newController.setFlashMode(
        _flashOn ? FlashMode.torch : FlashMode.off,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializingCamera = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isInitializingCamera = false);
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    try {
      final nextState = !_flashOn;
      await controller.setFlashMode(
        nextState ? FlashMode.torch : FlashMode.off,
      );
      if (!mounted) {
        return;
      }
      setState(() => _flashOn = nextState);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thiết bị không hỗ trợ đèn flash.')),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (!mounted) return;
      setState(() {
        _capturedImages.insert(0, pickedFile);
      });
      await _scanCapturedImage(pickedFile);
    }
  }

  Future<void> _captureImage() async {
    final controller = _cameraController;
    if (_isCapturing ||
        _isScanningText ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final image = await controller.takePicture();
      if (!mounted) {
        return;
      }
      setState(() {
        _capturedImages.insert(0, image);
      });
      await _scanCapturedImage(image);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chụp ảnh thất bại, vui lòng thử lại.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _scanCapturedImage(XFile image) async {
    if (_isScanningText) {
      return;
    }

    setState(() => _isScanningText = true);
    try {
      final inputImage = InputImage.fromFilePath(image.path);

      // Ưu tiên barcode trước để xử lý nhanh sản phẩm đóng gói.
      final barcodes = await _barcodeScanner.processImage(inputImage);
      final barcodeIngredients = _extractIngredientsFromBarcodes(barcodes);

      if (!mounted) {
        return;
      }

      if (barcodeIngredients.isNotEmpty) {
        await _showDetectedIngredientsSheet(barcodeIngredients);
        return;
      }

      final firstBarcodeValue = _pickFirstBarcodeValue(barcodes);
      if (firstBarcodeValue != null && mounted) {
        final suggestedName = await BarcodeLookupService.lookupProductName(
          firstBarcodeValue,
        );
        if (suggestedName != null && suggestedName.trim().isNotEmpty) {
          await _saveBarcodeProductDirectly(
            barcodeValue: firstBarcodeValue,
            productName: suggestedName,
          );
          return;
        }
        await _showBarcodeDetectedDialog(
          firstBarcodeValue,
          suggestedName: suggestedName,
        );
        return;
      }

      final result = await _textRecognizer.processImage(inputImage);
      final candidates = _extractIngredientCandidates(result.text);

      if (!mounted) {
        return;
      }

      if (candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không nhận diện được nguyên liệu rõ ràng từ ảnh.'),
          ),
        );
        return;
      }

      await _showDetectedIngredientsSheet(candidates);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quét chữ thất bại, vui lòng thử lại.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isScanningText = false);
      }
    }
  }

  List<String> _extractIngredientsFromBarcodes(List<Barcode> barcodes) {
    final results = <String>[];
    final seen = <String>{};

    for (final barcode in barcodes) {
      final value = (barcode.displayValue ?? barcode.rawValue ?? '').trim();
      if (value.isEmpty) {
        continue;
      }

      final candidates = _extractIngredientCandidates(
        value.replaceAll('|', '\n'),
      );
      for (final item in candidates) {
        final key = _normalize(item);
        if (key.isNotEmpty && seen.add(key)) {
          results.add(item);
        }
      }
    }

    return results;
  }

  String? _pickFirstBarcodeValue(List<Barcode> barcodes) {
    for (final barcode in barcodes) {
      final value = (barcode.displayValue ?? barcode.rawValue ?? '').trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Future<void> _showBarcodeDetectedDialog(
    String barcodeValue, {
    String? suggestedName,
  }) async {
    final defaultName = suggestedName?.trim().isNotEmpty == true
        ? suggestedName!.trim()
        : 'Sản phẩm mã $barcodeValue';
    final controller = TextEditingController(text: defaultName);

    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Đã nhận diện mã vạch'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                barcodeValue,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (suggestedName != null && suggestedName.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Gợi ý: $suggestedName',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Tên sản phẩm',
                  hintText: 'Nhập tên để lưu vào tủ lạnh',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Bỏ qua'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Lưu vào tủ lạnh'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    final productName = value?.trim() ?? '';
    if (productName.isEmpty || !mounted) {
      return;
    }

    final expiryDate = _suggestExpiryDateForName(productName);
    final ok = await _handleAddItem(
      nameVi: productName,
      quantity: 1,
      unit: 'cái',
      expiryDate: expiryDate,
      notes: 'Thêm từ mã vạch: $barcodeValue',
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Đã thêm "$productName" vào tủ lạnh.'
              : 'Lưu sản phẩm từ mã vạch thất bại.',
        ),
      ),
    );
  }

  Future<void> _saveBarcodeProductDirectly({
    required String barcodeValue,
    required String productName,
  }) async {
    final expiryDate = _suggestExpiryDateForName(productName);
    final ok = await _handleAddItem(
      nameVi: productName,
      quantity: 1,
      unit: 'cái',
      expiryDate: expiryDate,
      notes: 'Thêm tự động từ mã vạch: $barcodeValue',
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Đã tự thêm "$productName" vào tủ lạnh.'
              : 'Tự lưu sản phẩm từ mã vạch thất bại.',
        ),
      ),
    );
  }

  List<String> _extractIngredientCandidates(String rawText) {
    final knownIngredients = {
      'thit',
      'ga',
      'bo',
      'heo',
      'ca',
      'tom',
      'muc',
      'trung',
      'sua',
      'pho mai',
      'dua leo',
      'ca chua',
      'hanh',
      'hanh tay',
      'toi',
      'gung',
      'ot',
      'ot chuong',
      'rau',
      'rau muong',
      'rau cai',
      'bong cai',
      'ca rot',
      'khoai tay',
      'khoai lang',
      'bi do',
      'bi xanh',
      'nam',
      'tao',
      'chuoi',
      'cam',
      'chanh',
      'dua hau',
      'nho',
      'gao',
      'bun',
      'mi',
      'mi tom',
      'nuoc mam',
      'nuoc tuong',
      'dau an',
      'duong',
      'muoi',
      'tieu',
      'bot ngot',
    };

    final blacklist = {
      'tong',
      'thanh tien',
      'giam gia',
      'ma gd',
      'hoa don',
      'stt',
      'cashier',
      'thank you',
      'phone',
      'vat',
      'ngan hang',
      'so luong',
      'don gia',
      'tong cong',
    };

    final results = <String>[];
    final seen = <String>{};
    final lines = rawText.split(RegExp(r'\r?\n'));

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final normalized = _normalize(line);
      if (normalized.length < 2 || normalized.length > 32) {
        continue;
      }
      if (blacklist.any((word) => normalized.contains(word))) {
        continue;
      }
      if (RegExp(r'^\d+[\d\s.,/:-]*$').hasMatch(normalized)) {
        continue;
      }

      final maybeParts = line.split(RegExp(r'[,;|]'));
      for (final partRaw in maybeParts) {
        final part = partRaw.trim();
        final partNorm = _normalize(part);
        if (partNorm.isEmpty || partNorm.length > 24) {
          continue;
        }
        if (blacklist.any((word) => partNorm.contains(word))) {
          continue;
        }

        final looksLikeIngredient =
            knownIngredients.any((k) => partNorm.contains(k)) ||
            RegExp(r'^[a-zA-ZA-Z\s]{2,24}$').hasMatch(partNorm);

        if (!looksLikeIngredient) {
          continue;
        }

        if (seen.add(partNorm)) {
          results.add(_toDisplayName(part));
        }
      }
    }

    return results.take(12).toList();
  }

  String _normalize(String value) {
    var s = value.toLowerCase();
    const map = {
      'à': 'a',
      'á': 'a',
      'ả': 'a',
      'ã': 'a',
      'ạ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'ặ': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ậ': 'a',
      'è': 'e',
      'é': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ẹ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ệ': 'e',
      'ì': 'i',
      'í': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ị': 'i',
      'ò': 'o',
      'ó': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ọ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ộ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ợ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ụ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ự': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'ỵ': 'y',
      'đ': 'd',
    };
    map.forEach((k, v) {
      s = s.replaceAll(k, v);
    });

    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  String _toDisplayName(String raw) {
    final clean = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) {
      return clean;
    }
    return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
  }

  Future<void> _showDetectedIngredientsSheet(List<String> items) async {
    final selected = <String>{...items};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nguyên liệu nhận diện được',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chọn món bạn muốn thêm vào tủ lạnh',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 280,
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isChecked = selected.contains(item);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item),
                            value: isChecked,
                            activeColor: AppColors.primary,
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  selected.add(item);
                                } else {
                                  selected.remove(item);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: selected.isEmpty
                            ? null
                            : () async {
                                Navigator.of(context).pop();
                                await _addDetectedItemsToPantry(
                                  selected.toList(),
                                );
                              },
                        child: Text(
                          'Thêm vào tủ lạnh (${selected.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addDetectedItemsToPantry(List<String> items) async {
    var successCount = 0;
    for (final item in items) {
      final expiryDate = _suggestExpiryDateForName(item);
      final ok = await _handleAddItem(
        nameVi: item,
        quantity: 1,
        unit: 'cái',
        expiryDate: expiryDate,
        notes: 'Thêm từ quét camera',
      );
      if (ok) {
        successCount++;
      }
    }

    if (!mounted) {
      return;
    }

    if (successCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thêm được nguyên liệu nào.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã thêm $successCount nguyên liệu vào tủ lạnh.')),
    );
  }

  Future<void> _showManualInputDialog() async {
    final controller = TextEditingController();

    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nhập nguyên liệu'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Ví dụ: Cà chua'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    final ingredientName = value?.trim() ?? '';
    if (ingredientName.isEmpty) {
      return;
    }

    final expiryDate = _suggestExpiryDateForName(ingredientName);
    final ok = await _handleAddItem(
      nameVi: ingredientName,
      quantity: 1,
      unit: 'cái',
      expiryDate: expiryDate,
      notes: 'Thêm thủ công từ màn quét',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Đã thêm "$ingredientName" vào tủ lạnh.'
              : 'Thêm nguyên liệu thất bại, vui lòng thử lại.',
        ),
      ),
    );
  }

  DateTime _suggestExpiryDateForName(String ingredientName) {
    final n = _normalize(ingredientName);
    final now = DateTime.now();

    if (n.contains('sua') || n.contains('yaourt') || n.contains('kem')) {
      return now.add(const Duration(days: 10));
    }

    if (n.contains('thit') || n.contains('bo') || n.contains('heo')) {
      return now.add(const Duration(days: 3));
    }

    if (n.contains('ga') ||
        n.contains('ca') ||
        n.contains('tom') ||
        n.contains('muc')) {
      return now.add(const Duration(days: 2));
    }

    if (n.contains('rau') ||
        n.contains('hanh') ||
        n.contains('toi') ||
        n.contains('ca chua') ||
        n.contains('dua')) {
      return now.add(const Duration(days: 5));
    }

    if (n.contains('tao') ||
        n.contains('chuoi') ||
        n.contains('cam') ||
        n.contains('chanh') ||
        n.contains('nho')) {
      return now.add(const Duration(days: 7));
    }

    if (n.contains('gao') ||
        n.contains('mi') ||
        n.contains('nuoc mam') ||
        n.contains('nuoc tuong') ||
        n.contains('duong') ||
        n.contains('muoi')) {
      return now.add(const Duration(days: 180));
    }

    return now.add(const Duration(days: 14));
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isInitializingCamera) {
      return;
    }

    final nextIndex = (_currentCameraIndex + 1) % _cameras.length;
    if (!mounted) {
      return;
    }
    setState(() {
      _isInitializingCamera = true;
      _flashOn = false;
      _currentCameraIndex = nextIndex;
    });
    await _startCamera(nextIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Quét nguyên liệu',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.help_outline_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ──── Chọn tủ lạnh ────
                  FridgeSelector(
                    selectedFridgeId: _selectedFridgeId,
                    isCompact: true,
                    onSelected: (fridge) {
                      setState(() {
                        _selectedFridgeId = fridge.fridgeId;
                        _selectedFridge = fridge;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildCameraPreview(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.keyboard,
                          label: 'Nhập thủ công',
                          onTap: _showManualInputDialog,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionTile(
                          icon: _flashOn
                              ? Icons.flash_on_rounded
                              : Icons.flashlight_off_rounded,
                          label: 'Đèn Flash',
                          onTap: _toggleFlash,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'ẢNH ĐÃ CHỤP (${_capturedImages.length})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Xem tất cả',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _capturedImages.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == _capturedImages.length) {
                          return _buildAddThumb();
                        }
                        return _buildShotThumb(_capturedImages[index]);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomControlBar(),
          _buildAppBottomNav(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraController;
    return Container(
      height: 360,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: _isInitializingCamera
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E86A)),
                  )
                : (controller == null || !controller.value.isInitialized)
                ? const Center(
                    child: Text(
                      'Không mở được camera',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : CameraPreview(controller),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
          ),
          if (_isScanningText)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.45),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF00E86A)),
                      SizedBox(height: 10),
                      Text(
                        'Đang nhận diện nguyên liệu...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Center(
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00FF7A), width: 3),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Căn chỉnh mã vạch hoặc hóa đơn vào khung',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF7A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 58),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7EE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShotThumb(XFile image) {
    return Container(
      width: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        image: DecorationImage(
          image: FileImage(File(image.path)),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildAddThumb() {
    return GestureDetector(
      onTap: _captureImage,
      child: Container(
        width: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
        ),
        child: const Icon(
          Icons.add_a_photo_outlined,
          color: AppColors.textHint,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildBottomControlBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildRoundButton(
            Icons.photo_library_outlined,
            onTap: _pickImageFromGallery,
          ),
          GestureDetector(
            onTap: _captureImage,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(color: const Color(0xFFE5E7EB), width: 4),
                color: const Color(0xFF00E86A),
              ),
              child: _isCapturing
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Icon(Icons.camera_alt_rounded, size: 36),
            ),
          ),
          _buildRoundButton(Icons.autorenew_rounded, onTap: _switchCamera),
        ],
      ),
    );
  }

  Widget _buildRoundButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Color(0xFFEFF1F4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildAppBottomNav() {
    return BottomNavBar(
      currentIndex: 0,
      onTap: (index) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(initialTabIndex: index),
          ),
          (route) => false,
        );
      },
    );
  }
}
