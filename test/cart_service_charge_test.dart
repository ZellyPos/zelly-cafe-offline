import 'package:flutter_test/flutter_test.dart';
import 'package:tezzro/models/product.dart';
import 'package:tezzro/providers/cart_provider.dart';

void main() {
  group('CartProvider No Service Charge Logic', () {
    late CartProvider cartProvider;

    setUp(() {
      cartProvider = CartProvider();
    });

    test(
      'totalForServiceCharge should exclude products with noServiceCharge=true',
      () {
        final productWithService = Product(
          id: 1,
          name: 'Choy',
          price: 10000,
          category: 'Ichimliklar',
          noServiceCharge: false,
        );

        final productWithoutService = Product(
          id: 2,
          name: 'Non',
          price: 5000,
          category: 'Yeguliklar',
          noServiceCharge: true,
        );

        cartProvider.addItem(productWithService);
        cartProvider.addItem(
          productWithoutService,
          null,
          null,
          2,
        ); // 2 * 5000 = 10000

        expect(cartProvider.totalAmount, 20000);
        expect(cartProvider.totalForServiceCharge, 10000);
      },
    );

    // Note: To test calculateWaiterServiceFee, we would need to mock the Waiter
    // but the model and provider might depend on context or DB.
    // This simple test validates the core logic introduced.
  });
}
