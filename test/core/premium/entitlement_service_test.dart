import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/premium/entitlement_service.dart';
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class MockInAppPurchase extends Mock implements InAppPurchase {}

void main() {
  late AppDatabase db;
  late EntitlementService service;
  // ignore: unused_local_variable
  late MockInAppPurchase mockIap;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    mockIap = MockInAppPurchase();
    service = EntitlementService(db, iap: mockIap);
  });

  tearDown(() async {
    await db.close();
  });

  group('EntitlementService', () {
    test('initial state is not premium', () async {
      final state = await service.getCachedEntitlement();
      expect(state.isPremium, isFalse);
    });

    test('updateEntitlement persists state', () async {
      final now = DateTime.now();
      final state = EntitlementState(
        isPremium: true,
        source: 'lifetime_purchase',
        lastVerifiedAt: now,
      );

      await service.updateEntitlement(state);
      final cached = await service.getCachedEntitlement();

      expect(cached.isPremium, isTrue);
      expect(cached.source, 'lifetime_purchase');
      expect(cached.lastVerifiedAt.millisecondsSinceEpoch ~/ 1000, 
             now.millisecondsSinceEpoch ~/ 1000);
    });

    test('onPurchaseCompleted updates to premium', () async {
      final details = PurchaseDetails(
        purchaseID: '123',
        productID: EntitlementService.lifetimeProductId,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: '',
        ),
        transactionDate: '',
        status: PurchaseStatus.purchased,
      );

      await service.onPurchaseCompleted(details);
      final state = await service.getCachedEntitlement();

      expect(state.isPremium, isTrue);
      expect(state.source, 'lifetime_purchase');
    });
  });
}
