import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum VietnamRegion { north, central, south }

class RegionalProfile {
  final VietnamRegion region;
  final bool isAutoDetected;
  final String? detectedLocation;

  const RegionalProfile({
    required this.region,
    required this.isAutoDetected,
    this.detectedLocation,
  });

  String get regionLabel {
    switch (region) {
      case VietnamRegion.north:
        return 'Miền Bắc';
      case VietnamRegion.central:
        return 'Miền Trung';
      case VietnamRegion.south:
        return 'Miền Nam';
    }
  }

  String get cuisinePreference {
    switch (region) {
      case VietnamRegion.north:
        return 'Ẩm thực miền Bắc Việt Nam';
      case VietnamRegion.central:
        return 'Ẩm thực miền Trung Việt Nam';
      case VietnamRegion.south:
        return 'Ẩm thực miền Nam Việt Nam';
    }
  }

  String get seasoningPreference {
    switch (region) {
      case VietnamRegion.north:
        return 'Nêm vị thanh, vừa phải; ưu tiên độ cân bằng, không quá ngọt.';
      case VietnamRegion.central:
        return 'Nêm đậm đà hơn, có thể cay và mặn hơn một chút tùy món.';
      case VietnamRegion.south:
        return 'Nêm hài hòa thiên ngọt nhẹ, vị tròn, thơm và dễ ăn.';
    }
  }

  String get cacheKey => region == VietnamRegion.north
      ? 'north'
      : region == VietnamRegion.central
      ? 'central'
      : 'south';
}

class RegionPreferenceService {
  static const String _manualRegionKey = 'regional_manual_region_v1';
  static const String _autoRegionKey = 'regional_auto_region_v1';
  static const String _autoDetectedLocationKey =
      'regional_auto_detected_location_v1';
  static const String _autoUpdatedAtMsKey = 'regional_auto_updated_at_ms_v1';

  static const Duration _autoDetectTtl = Duration(days: 7);

  static Future<RegionalProfile> getProfile({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    final manual = prefs.getString(_manualRegionKey);
    final manualRegion = _parseRegion(manual);
    if (manualRegion != null) {
      return RegionalProfile(
        region: manualRegion,
        isAutoDetected: false,
        detectedLocation: prefs.getString(_autoDetectedLocationKey),
      );
    }

    if (!forceRefresh) {
      final cachedAuto = _parseRegion(prefs.getString(_autoRegionKey));
      final updatedAtMs = prefs.getInt(_autoUpdatedAtMsKey);
      if (cachedAuto != null && updatedAtMs != null) {
        final updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
        if (DateTime.now().difference(updatedAt) <= _autoDetectTtl) {
          return RegionalProfile(
            region: cachedAuto,
            isAutoDetected: true,
            detectedLocation: prefs.getString(_autoDetectedLocationKey),
          );
        }
      }
    }

    final detected = await _detectRegionFromIp();
    if (detected != null) {
      await prefs.setString(_autoRegionKey, _regionToCode(detected.region));
      if (detected.detectedLocation != null &&
          detected.detectedLocation!.trim().isNotEmpty) {
        await prefs.setString(
          _autoDetectedLocationKey,
          detected.detectedLocation!,
        );
      }
      await prefs.setInt(
        _autoUpdatedAtMsKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      return RegionalProfile(
        region: detected.region,
        isAutoDetected: true,
        detectedLocation: detected.detectedLocation,
      );
    }

    final fallback = _parseRegion(prefs.getString(_autoRegionKey));
    if (fallback != null) {
      return RegionalProfile(
        region: fallback,
        isAutoDetected: true,
        detectedLocation: prefs.getString(_autoDetectedLocationKey),
      );
    }

    // Fallback an toàn nếu không detect được mạng.
    return const RegionalProfile(
      region: VietnamRegion.south,
      isAutoDetected: true,
      detectedLocation: 'Việt Nam',
    );
  }

  static Future<void> setManualRegion(VietnamRegion region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_manualRegionKey, _regionToCode(region));
  }

  static Future<void> clearManualRegion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_manualRegionKey);
  }

  static VietnamRegion? _parseRegion(String? value) {
    switch (value) {
      case 'north':
        return VietnamRegion.north;
      case 'central':
        return VietnamRegion.central;
      case 'south':
        return VietnamRegion.south;
      default:
        return null;
    }
  }

  static String _regionToCode(VietnamRegion region) {
    switch (region) {
      case VietnamRegion.north:
        return 'north';
      case VietnamRegion.central:
        return 'central';
      case VietnamRegion.south:
        return 'south';
    }
  }

  static Future<RegionalProfile?> _detectRegionFromIp() async {
    try {
      // Avoid third-party geo lookups in web builds because they are commonly
      // blocked by browser policies/network rules in production.
      if (kIsWeb) {
        return null;
      }

      final uri = Uri.parse('https://ipapi.co/json/');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body);
      if (data is! Map<String, dynamic>) return null;

      final country = (data['country_name'] ?? data['country'] ?? '')
          .toString()
          .toLowerCase();
      if (!country.contains('viet') && !country.contains('vn')) {
        return null;
      }

      final cityRaw = (data['city'] ?? '').toString();
      final regionRaw = (data['region'] ?? '').toString();
      final postalRaw = (data['postal'] ?? '').toString();

      final locationText = [
        cityRaw,
        regionRaw,
        postalRaw,
      ].where((e) => e.trim().isNotEmpty).join(', ');

      final mapped = _mapToVietnamRegion(cityRaw, regionRaw);
      return RegionalProfile(
        region: mapped,
        isAutoDetected: true,
        detectedLocation: locationText.isEmpty ? null : locationText,
      );
    } catch (e) {
      debugPrint('RegionPreferenceService._detectRegionFromIp error: $e');
      return null;
    }
  }

  static VietnamRegion _mapToVietnamRegion(String city, String region) {
    final text = _normalize('$city $region');

    const northKeywords = <String>{
      'ha noi',
      'hai phong',
      'quang ninh',
      'bac ninh',
      'bac giang',
      'thai nguyen',
      'lang son',
      'lao cai',
      'yen bai',
      'phu tho',
      'son la',
      'dien bien',
      'hoa binh',
      'tuyen quang',
      'ha giang',
      'vinh phuc',
      'nam dinh',
      'thai binh',
      'ninh binh',
      'ha nam',
      'hung yen',
      'hai duong',
      'cao bang',
      'bac kan',
      'lai chau',
    };

    const centralKeywords = <String>{
      'thua thien hue',
      'hue',
      'da nang',
      'quang nam',
      'quang ngai',
      'binh dinh',
      'phu yen',
      'khanh hoa',
      'ninh thuan',
      'binh thuan',
      'quang tri',
      'quang binh',
      'ha tinh',
      'nghe an',
      'thanh hoa',
      'kon tum',
      'gia lai',
      'dak lak',
      'dak nong',
      'lam dong',
      'buon ma thuot',
      'pleiku',
    };

    const southKeywords = <String>{
      'ho chi minh',
      'tp hcm',
      'sai gon',
      'binh duong',
      'dong nai',
      'ba ria vung tau',
      'tay ninh',
      'long an',
      'tien giang',
      'ben tre',
      'tra vinh',
      'vinh long',
      'dong thap',
      'an giang',
      'kien giang',
      'can tho',
      'hau giang',
      'soc trang',
      'bac lieu',
      'ca mau',
      'binh phuoc',
    };

    if (northKeywords.any(text.contains)) return VietnamRegion.north;
    if (centralKeywords.any(text.contains)) return VietnamRegion.central;
    if (southKeywords.any(text.contains)) return VietnamRegion.south;

    // Mặc định miền Nam nếu chưa map được chính xác.
    return VietnamRegion.south;
  }

  static String _normalize(String input) {
    var text = input.toLowerCase().trim();
    const vietnameseMap = {
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
    };

    vietnameseMap.forEach((key, value) {
      text = text.replaceAll(key, value);
    });

    return text
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
