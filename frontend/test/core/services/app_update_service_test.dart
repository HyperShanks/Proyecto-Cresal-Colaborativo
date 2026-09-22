import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/app_update_service.dart';

void main() {
  group('AppUpdateService and UpdateInfo Unit Tests', () {
    test('UpdateInfo.fromJson parsea correctamente versión mayor y disponible', () {
      final json = {
        'update_available': true,
        'latest_version': '1.0.1',
        'release_name': 'Versión 1.0.1 - Estabilidad',
        'release_notes': 'Corrección de bugs y mejoras en carrito.',
        'download_url': '/api/v1/updates/download/android',
        'asset_name': 'cresal-app.apk',
        'asset_size': 45123456,
      };

      final info = UpdateInfo.fromJson(json, '1.0.0');

      expect(info.updateAvailable, isTrue);
      expect(info.latestVersion, '1.0.1');
      expect(info.currentVersion, '1.0.0');
      expect(info.releaseName, 'Versión 1.0.1 - Estabilidad');
      expect(info.releaseNotes, contains('mejoras en carrito'));
      expect(info.downloadUrl, '/api/v1/updates/download/android');
      expect(info.assetName, 'cresal-app.apk');
      expect(info.assetSize, 45123456);
    });

    test('UpdateInfo.fromJson maneja payload sin actualización', () {
      final json = {
        'update_available': false,
        'latest_version': '1.0.0',
        'release_name': '1.0.0',
        'release_notes': '',
        'download_url': null,
      };

      final info = UpdateInfo.fromJson(json, '1.0.0');

      expect(info.updateAvailable, isFalse);
      expect(info.latestVersion, '1.0.0');
      expect(info.downloadUrl, isNull);
    });

    test('AppUpdateService singleton instancia única', () {
      final s1 = AppUpdateService();
      final s2 = AppUpdateService();
      expect(identical(s1, s2), isTrue);
    });
  });
}
