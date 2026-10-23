import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pickorbeet/core/motion/branch_container.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/app_shell.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/widgets/placeholder_page.dart';
import 'package:pickorbeet/features/account/view/pages/account_page.dart';
import 'package:pickorbeet/features/account/view/pages/addresses_page.dart';
import 'package:pickorbeet/features/account/view/pages/order_detail_page.dart';
import 'package:pickorbeet/features/account/view/pages/orders_page.dart';
import 'package:pickorbeet/features/account/view/pages/settings_page.dart';
import 'package:pickorbeet/features/account/view/pages/track_order_page.dart';
import 'package:pickorbeet/features/auth/view/pages/forgot_password_page.dart';
import 'package:pickorbeet/features/auth/view/pages/login_page.dart';
import 'package:pickorbeet/features/auth/view/pages/register_page.dart';
import 'package:pickorbeet/features/auth/view/pages/reset_password_page.dart';
import 'package:pickorbeet/features/auth/view/pages/verify_email_page.dart';
import 'package:pickorbeet/features/cart/view/pages/cart_page.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/view/pages/categories_page.dart';
import 'package:pickorbeet/features/catalog/view/pages/product_detail_page.dart';
import 'package:pickorbeet/features/catalog/view/pages/product_list_page.dart';
import 'package:pickorbeet/features/checkout/checkout_args.dart';
import 'package:pickorbeet/features/checkout/view/checkout_page.dart';
import 'package:pickorbeet/features/home/view/pages/home_page.dart';
import 'package:pickorbeet/features/notifications/view/notifications_page.dart';
import 'package:pickorbeet/features/vouchers/view/vouchers_page.dart';
import 'package:pickorbeet/features/wishlist/view/pages/wishlist_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // Re-runs redirects when the customer signs in or out, or the session expires.
  final sessionChanges = ValueNotifier<int>(0);
  ref.listen(sessionNotifierProvider, (_, _) => sessionChanges.value++);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.home,
    refreshListenable: sessionChanges,
    redirect: (context, state) {
      final signedIn =
          ref.read(sessionNotifierProvider) == SessionStatus.signedIn;
      final location = state.matchedLocation;
      if (!signedIn && Routes.isProtected(location)) {
        return Routes.loginFrom(state.uri.toString());
      }
      if (signedIn && Routes.isAuthScreen(location)) {
        final from = state.uri.queryParameters['from'];
        return from != null && from.startsWith('/') ? from : Routes.account;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Routes.home),
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(shell: shell),
        navigatorContainerBuilder: (context, shell, children) =>
            AnimatedBranchContainer(
              currentIndex: shell.currentIndex,
              children: children,
            ),
        branches: [
          _tab(Routes.home, (_) => const HomePage()),
          _tab(Routes.categories, (_) => const CategoriesPage()),
          _tab(Routes.wishlist, (_) => const WishlistPage()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.account,
                builder: (_, _) => const AccountPage(),
                routes: [
                  GoRoute(
                    path: 'vouchers',
                    builder: (_, _) => const VouchersPage(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (_, _) => const SettingsPage(),
                  ),
                ],
              ),
            ],
          ),
          _tab(Routes.cart, (_) => const CartPage()),
        ],
      ),
      // Everything below opens over the tabs, without the bottom bar.
      GoRoute(
        path: Routes.search,
        builder: (_, _) => const PlaceholderPage('Search'),
      ),
      GoRoute(
        path: Routes.products,
        builder: (_, state) => _productList(state),
      ),
      GoRoute(
        path: Routes.category(':slug'),
        builder: (_, state) => ProductListPage(
          title: state.pathParameters['slug'],
          query: ProductQuery(categorySlug: state.pathParameters['slug']),
        ),
      ),
      GoRoute(
        path: Routes.product(':slug'),
        builder: (_, state) => ProductDetailPage(
          slug: state.pathParameters['slug']!,
          heroTag: _heroTag(state.extra),
        ),
      ),
      GoRoute(
        path: Routes.checkout,
        builder: (_, state) => CheckoutPage(
          args: CheckoutArgs.fromUri(state.uri, extra: state.extra),
        ),
      ),
      GoRoute(
        path: Routes.payment(':orderId'),
        builder: (_, _) => const PlaceholderPage('Payment'),
      ),
      GoRoute(
        path: Routes.orderSuccess(':orderId'),
        builder: (_, _) => const PlaceholderPage('Order placed'),
      ),
      GoRoute(
        path: Routes.orders,
        builder: (_, state) =>
            OrdersPage(initialStatus: state.uri.queryParameters['status']),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                OrderDetailPage(orderId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'details',
                builder: (_, state) =>
                    OrderDetailPage(orderId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.trackOrder,
        builder: (_, state) => TrackOrderPage(
          initialQuery:
              state.uri.queryParameters['order'] ??
              state.uri.queryParameters['tracking'] ??
              '',
          orderId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, state) =>
            LoginPage(from: state.uri.queryParameters['from']),
      ),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (_, state) =>
            VerifyEmailPage(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, state) =>
            ResetPasswordPage(token: state.uri.queryParameters['token'] ?? ''),
      ),
      GoRoute(
        path: Routes.profile,
        builder: (_, _) => const PlaceholderPage('Profile'),
      ),
      GoRoute(
        path: Routes.addresses,
        builder: (_, _) => const AddressesPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, _) => const AddressesPage(startCreating: true),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                AddressesPage(editId: state.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: Routes.changePassword,
        builder: (_, _) => const PlaceholderPage('Change password'),
      ),
      GoRoute(
        path: Routes.privacy,
        builder: (_, _) => const PlaceholderPage('Privacy'),
      ),
      GoRoute(
        path: Routes.help,
        builder: (_, _) => const PlaceholderPage('Help'),
      ),
      GoRoute(path: '/settings', redirect: (_, _) => Routes.settings),
      GoRoute(
        path: Routes.notifications,
        builder: (_, _) => const NotificationsPage(),
      ),
      GoRoute(
        path: Routes.paymentMethods,
        builder: (_, _) => const PlaceholderPage('Payment methods'),
      ),
      GoRoute(
        path: Routes.membership,
        builder: (_, _) => const PlaceholderPage('Membership'),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    sessionChanges.dispose();
  });
  return router;
}

StatefulShellBranch _tab(
  String path,
  Widget Function(GoRouterState state) page,
) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => page(state))],
);

String? _heroTag(Object? extra) => extra is String ? extra : null;

ProductListPage _productList(GoRouterState state) {
  final params = state.uri.queryParameters;
  return ProductListPage(
    title: params['title'],
    query: ProductQuery(
      categorySlug: params['category'],
      subcategorySlug: params['subcategory'],
      search: params['q'],
      ordering: params['ordering'],
      featured: params['featured'] == 'true',
      onSale: params['sale'] == 'true',
    ),
  );
}
