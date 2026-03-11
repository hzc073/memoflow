import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/location/location_adapter_utils.dart';
import 'package:memos_flutter_app/data/models/location_settings.dart';

void main() {
  group('formatLocationPrecisionSummary', () {
    test('formats city precision with province and city', () {
      final value = formatLocationPrecisionSummary(
        precision: LocationPrecision.city,
        province: '浙江省',
        city: '温州市',
        district: '瓯海区',
        street: '黄屿大道',
      );

      expect(value, '浙江省•温州市');
    });

    test('formats district precision with city and district', () {
      final value = formatLocationPrecisionSummary(
        precision: LocationPrecision.district,
        province: '浙江省',
        city: '温州市',
        district: '瓯海区',
        street: '黄屿大道',
      );

      expect(value, '温州市•瓯海区');
    });

    test('deduplicates municipality names', () {
      final value = formatLocationPrecisionSummary(
        precision: LocationPrecision.city,
        province: '北京市',
        city: '北京市',
        district: '朝阳区',
        street: '建国路',
      );

      expect(value, '北京市');
    });
  });
}
