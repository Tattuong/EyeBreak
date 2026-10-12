import 'package:flutter_test/flutter_test.dart';
import 'package:shiftlens/core/constants/iap_constants.dart';
import 'package:shiftlens/core/services/iap_config_service.dart';
import 'package:shiftlens/models/shop_item.dart';

void main() {
  test('ShiftLens IAP ids and R252 endpoint', () {
    expect(IapConstants.productPrefix, 'sl');
    expect(IapConstants.remoteConfigUrl, 'https://api2.blwsmartware.net/R252.json');
    expect(IapConstants.coinPackIds.first, 'sl_pack_1');
    expect(IapConstants.coinPackIds.last, 'sl_pack_10');
    expect(IapConstants.coinPackIds, hasLength(10));
    expect(IapConstants.removeAdsProductId, 'sl_remove_ads');
    expect(IapConstants.proProductId, 'sl_pro');
    expect(IapConstants.allProductIds, containsAll([...IapConstants.coinPackIds, 'sl_remove_ads', 'sl_pro']));
    expect(IapConstants.coinsForProduct('sl_pack_5'), 500);
    expect(IapConstants.freeArchiveLimit, 8);
    expect(IapConstants.proArchiveLimit, 99);
  });

  test('disable=1 hides billing only', () {
    final off = IapRemoteConfig.fromJson({'disable': 1, 'name': 'ShiftLens'});
    expect(off.billingDisabled, isTrue);
    final on = IapRemoteConfig.fromJson({'disable': 0, 'name': 'ShiftLens', 'code': 'FULL_IAP'});
    expect(on.billingDisabled, isFalse);
    expect(on.name, 'ShiftLens');
  });

  test('shop catalog extras can be applied and reverted', () {
    expect(ShopCatalog.items.where((e) => e.id.startsWith('theme_')), isNotEmpty);
    expect(ShopCatalog.find(ShopCatalog.featPro), isNotNull);
    expect(ShopCatalog.find('remove_ads'), isNotNull);
    expect(ShopCatalog.find(ShopCatalog.featHint), isNotNull);
    expect(ShopCatalog.find(ShopCatalog.featSound), isNotNull);
    expect(ShopCatalog.isDefaultId(ShopCatalog.defaultThemeId), isTrue);
  });
}
