import 'package:flutter_test/flutter_test.dart';
import 'package:mwn/models/market.dart';

void main() {
  group('Market.fromJson', () {
    test('parses a full record', () {
      final m = Market.fromJson({
        'id': 1,
        'name': '경산공설시장',
        'location': '경상북도 경산시',
        'latitude': 35.8188,
        'longitude': 128.7345,
        'nx': 92,
        'ny': 90,
        'category': '공설',
        'created_at': '2026-05-30T00:00:00',
        'updated_at': '2026-05-30T00:00:00',
        'is_active': true,
      });

      expect(m.id, 1);
      expect(m.name, '경산공설시장');
      expect(m.latitude, 35.8188);
      expect(m.nx, 92);
      expect(m.ny, 90);
      expect(m.isActive, isTrue);
    });

    test('tolerates missing optional fields', () {
      final m = Market.fromJson({
        'id': 2,
        'name': '자인공설시장',
        'location': '경상북도 경산시 자인면',
        'is_active': false,
      });

      expect(m.latitude, isNull);
      expect(m.longitude, isNull);
      expect(m.nx, isNull);
      expect(m.category, isNull);
      expect(m.isActive, isFalse);
    });
  });

  group('Market coordinate guards', () {
    test('hasCoordinates requires both lat and lng', () {
      Market base({double? lat, double? lng}) => Market(
            id: 1,
            name: 'x',
            location: 'y',
            latitude: lat,
            longitude: lng,
            isActive: true,
          );

      expect(base(lat: 1, lng: 2).hasCoordinates, isTrue);
      expect(base(lat: 1, lng: null).hasCoordinates, isFalse);
      expect(base(lat: null, lng: 2).hasCoordinates, isFalse);
      expect(base().hasCoordinates, isFalse);
    });

    test('hasGridCoordinates requires both nx and ny', () {
      Market base({int? nx, int? ny}) => Market(
            id: 1,
            name: 'x',
            location: 'y',
            nx: nx,
            ny: ny,
            isActive: true,
          );

      expect(base(nx: 92, ny: 90).hasGridCoordinates, isTrue);
      expect(base(nx: 92, ny: null).hasGridCoordinates, isFalse);
      expect(base(nx: null, ny: 90).hasGridCoordinates, isFalse);
      expect(base().hasGridCoordinates, isFalse);
    });
  });

  group('UserMarketInterest.fromJson (watchlist payload)', () {
    test('reads grid coords from the nested market_coordinates object', () {
      // The /api/watchlist payload nests coordinates; this is the shape the
      // map view depends on to know where to draw each marker.
      final interest = UserMarketInterest.fromJson({
        'id': 560,
        'user_id': 7,
        'market_id': 1,
        'market_name': '경산공설시장',
        'market_location': '경상북도 경산시',
        'market_coordinates': {
          'latitude': 35.8188,
          'longitude': 128.7345,
          'nx': 92,
          'ny': 90,
        },
        'created_at': '2026-05-30T00:00:00',
        'is_active': true,
        'notification_enabled': true,
      });

      expect(interest.marketId, 1);
      expect(interest.marketName, '경산공설시장');
      expect(interest.marketCoordinates, isNotNull);
      expect(interest.marketCoordinates!.hasGridCoordinates, isTrue);
      expect(interest.marketCoordinates!.nx, 92);
      expect(interest.marketCoordinates!.ny, 90);
    });

    test('handles a null market_coordinates object', () {
      final interest = UserMarketInterest.fromJson({
        'id': 561,
        'user_id': 7,
        'market_id': 2,
        'market_name': '자인공설시장',
        'market_coordinates': null,
        'is_active': true,
        'notification_enabled': false,
      });

      expect(interest.marketCoordinates, isNull);
      expect(interest.notificationEnabled, isFalse);
    });
  });
}
