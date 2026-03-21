import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BarcodeLookupService {
  static Future<String?> lookupProductName(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) {
      return null;
    }

    final url = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$code.json?fields=product_name_vi,product_name,brands',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) {
        return null;
      }

      final product = data['product'];
      if (product is! Map<String, dynamic>) {
        return null;
      }

      final productNameVi = (product['product_name_vi'] ?? '')
          .toString()
          .trim();
      final productName = (product['product_name'] ?? '').toString().trim();
      final brands = (product['brands'] ?? '').toString().trim();

      if (productNameVi.isNotEmpty) {
        return productNameVi;
      }

      if (productName.isNotEmpty && brands.isNotEmpty) {
        return '$productName - $brands';
      }

      if (productName.isNotEmpty) {
        return productName;
      }

      return null;
    } catch (e) {
      debugPrint('BarcodeLookupService.lookupProductName error: $e');
      return null;
    }
  }
}
