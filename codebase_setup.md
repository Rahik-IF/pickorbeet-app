# Flutter + Django Codebase Setup Guide

This document describes how the PickOrbeet Flutter app is structured and how it talks to the Django REST API in `pickorbeet-backend`. Follow it so new features match the existing client pattern and the real server contract.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Client Architecture (Flutter)](#client-architecture-flutter)
3. [Server Architecture (Django)](#server-architecture-django)
4. [API Contract](#api-contract)
5. [Authentication Flow](#authentication-flow)
6. [Customer Endpoints](#customer-endpoints)
7. [Adding New Features](#adding-new-features)
8. [Best Practices](#best-practices)
9. [Dependencies & Setup](#dependencies--setup)

---

## Project Overview

```
pickorbeet/
├── pickorbeet-app/        # Flutter shop (this guide)
├── pickorbeet-backend/    # Django 5 + Django REST Framework
└── pickorbeet-frontend/   # Next.js shop (same API)
```

- **App**: Flutter, **MVVM**, **Riverpod** for state, **fpdart** `Either` for API results.
- **API**: Django REST Framework, **PostgreSQL**, **SimpleJWT**. Base path is `/api/v1/`.
- **Shop scope**: the mobile app uses public and customer endpoints. Staff, POS, inventory, and reports live in the admin panel and are not part of this app.
- **Money**: Bangladeshi Taka (BDT). Amounts are decimal strings such as `"1290.00"`.
- **IDs**: UUID strings. Product and category routes that take a slug use the slug, not the id.

Local API base:

| Device | Base URL |
|--------|----------|
| iOS simulator, desktop | `http://127.0.0.1:8000/api/v1` |
| Android emulator | `http://10.0.2.2:8000/api/v1` |
| Physical device | `http://<lan-ip>:8000/api/v1` |

Media files are served from the server origin, not under `/api/v1`. A relative image such as `/media/products/a.jpg` becomes `http://127.0.0.1:8000/media/products/a.jpg`.

Interactive docs: `http://127.0.0.1:8000/api/docs/` (Swagger) and `http://127.0.0.1:8000/api/redoc/`.

---

## Client Architecture (Flutter)

### MVVM Pattern Overview

| Layer | Responsibility |
|-------|----------------|
| **Model** | JSON shapes returned by the API |
| **View** | Pages and widgets |
| **ViewModel** | Screen state, calls repositories, writes global notifiers |
| **Repository** | HTTP calls and local token storage |

Views never call `http` directly. ViewModels never parse raw JSON. Repositories return `Either<AppFailure, T>`.

### File Structure

```
pickorbeet-app/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── constants/
│   │   │   └── server_constant.dart
│   │   ├── failure/
│   │   │   └── failure.dart
│   │   ├── models/
│   │   │   ├── user_model.dart
│   │   │   ├── address_model.dart
│   │   │   └── paginated.dart
│   │   ├── network/
│   │   │   ├── api_client.dart          # base URL, JSON, Bearer, cookie jar
│   │   │   └── api_exception.dart
│   │   ├── providers/
│   │   │   └── current_user_notifier.dart
│   │   ├── theme/
│   │   │   ├── app_pallete.dart
│   │   │   └── theme.dart
│   │   ├── widgets/
│   │   │   ├── custom_field.dart
│   │   │   └── loader.dart
│   │   └── utils.dart
│   └── features/
│       ├── auth/
│       ├── home/                        # GET /products/homepage/
│       ├── catalog/                     # categories, search, product detail
│       ├── cart/
│       ├── checkout/                    # checkout, coupons, delivery
│       ├── orders/                      # my orders + public tracking
│       ├── payments/                    # SSLCommerz gateway URL
│       └── store/                       # public settings + contact form
├── assets/
└── pubspec.yaml
```

Each feature uses the same folders:

```
feature_name/
├── models/
├── repositories/
│   ├── feature_remote_repository.dart
│   └── feature_local_repository.dart    # only when something is stored on device
├── view/
│   ├── pages/
│   └── widgets/
└── viewmodel/
```

### Core Pieces

**Server URL.** Android emulators cannot reach `127.0.0.1` on the host.

```dart
import 'dart:io';

class ServerConstant {
  static String get origin =>
      Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';

  static String get apiBase => '$origin/api/v1';

  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$origin$path';
  }
}
```

**Failures.** Map Django error bodies into one message. DRF uses several shapes: `{"detail": "..."}`, `{"error": "..."}`, and field maps such as `{"email": ["..."], "password": ["Passwords don't match."]}`.

```dart
class AppFailure {
  final String message;
  const AppFailure([this.message = 'Sorry, an unexpected error occurred!']);

  @override
  String toString() => message;
}
```

**Signed-in user.** Keep the profile alive for the whole session. Tokens live in the local auth repository, not on the user model, because login, Google sign-in, and email verification all return `access` and `refresh` separately from `user`.

```dart
@Riverpod(keepAlive: true)
class CurrentUserNotifier extends _$CurrentUserNotifier {
  @override
  UserModel? build() => null;

  void setUser(UserModel user) => state = user;
  void clear() => state = null;
}
```

**HTTP client.** Every path includes the trailing slash Django expects. Send `Authorization: Bearer <access>`. Persist the `sessionid` cookie: guest carts are stored against the Django session, not a header.

```dart
class ApiClient {
  ApiClient(this._tokenStore, this._cookies);

  final AuthLocalRepository _tokenStore;
  final CookieJar _cookies;

  Future<http.Response> get(String path, {Map<String, String>? query}) {
    return _send('GET', path, query: query);
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) {
    return _send('POST', path, body: body);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${ServerConstant.apiBase}$path').replace(
      queryParameters: query,
    );
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final access = _tokenStore.getAccessToken();
    if (access != null) headers['Authorization'] = 'Bearer $access';

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    request.headers.addAll(await _cookieHeader(uri));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    await _storeCookies(uri, response);
    if (response.statusCode == 401 && access != null) {
      return _refreshAndRetry(request);
    }
    return response;
  }
}
```

On `401`, call `POST /auth/token/refresh/` with `{ "refresh": "<refresh>" }`. The server rotates refresh tokens (`ROTATE_REFRESH_TOKENS` and `BLACKLIST_AFTER_ROTATION` are on), so save both the new `access` and the new `refresh`. If refresh fails, clear tokens and the current user.

**Pagination.** List endpoints use page-number pagination, 20 items per page.

```json
{
  "count": 42,
  "next": "http://127.0.0.1:8000/api/v1/products/?page=2",
  "previous": null,
  "results": []
}
```

`GET /products/?ids=` is the exception: it returns a bare list so a wishlist can load a specific set. `GET /products/homepage/`, `GET /products/banners/`, and `GET /products/by-category/` are also unpaginated.

---

### Repository Pattern

Remote repositories decode the status code, then return `Left` or `Right`.

```dart
@riverpod
AuthRemoteRepository authRemoteRepository(AuthRemoteRepositoryRef ref) {
  return AuthRemoteRepository(ref.watch(apiClientProvider));
}

class AuthRemoteRepository {
  AuthRemoteRepository(this._api);
  final ApiClient _api;

  Future<Either<AppFailure, AuthSession>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _api.post('/auth/login/', body: {
        'email': email,
        'password': password,
      });
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        return Left(AppFailure(readError(body)));
      }
      return Right(AuthSession.fromMap(body));
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }
}
```

`AuthSession` holds `access`, `refresh`, and `UserModel`. Registration does **not** return tokens. It returns `201` with `requires_verification: true`. Tokens arrive only after `POST /auth/verify-email/`.

Local storage keeps the two tokens:

```dart
class AuthLocalRepository {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  void saveSession(String access, String refresh) { /* SharedPreferences */ }
  String? getAccessToken() { /* ... */ }
  String? getRefreshToken() { /* ... */ }
  void clear() { /* remove both keys */ }
}
```

### ViewModel Pattern

```dart
@riverpod
class AuthViewModel extends _$AuthViewModel {
  @override
  AsyncValue<UserModel>? build() => null;

  Future<void> loginUser({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    final res = await ref.read(authRemoteRepositoryProvider).login(
          email: email,
          password: password,
        );
    switch (res) {
      case Left(value: final failure):
        state = AsyncValue.error(failure.message, StackTrace.current);
      case Right(value: final session):
        ref.read(authLocalRepositoryProvider).saveSession(
              session.access,
              session.refresh,
            );
        ref.read(currentUserNotifierProvider.notifier).setUser(session.user);
        state = AsyncValue.data(session.user);
    }
  }
}
```

Pages are `ConsumerWidget` or `ConsumerStatefulWidget`. Watch `isLoading` to show `Loader`. Use `ref.listen` for navigation and snackbars. Dispose `TextEditingController`s.

### Models

Match serializer field names. Parse money with `Decimal` or keep it as `String` until display. Parse UUID fields as `String`. Use `copyWith`, `fromMap` / `toMap`, and value equality.

```dart
class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String role; // customer | seller | accountant | super_admin
  final String fullName;
  final bool isVerified;

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      email: map['email'] as String,
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      phone: map['phone'] as String?,
      role: map['role'] as String? ?? 'customer',
      fullName: map['full_name'] as String? ??
          '${map['first_name'] ?? ''} ${map['last_name'] ?? ''}'.trim(),
      isVerified: map['is_verified'] as bool? ?? false,
    );
  }
}
```

Login's nested `user` omits `phone` and `is_verified`. Profile (`GET /auth/profile/`) includes them, plus `address`, `city`, `postal_code`, `order_count`, and `total_spent`. After login, call the profile endpoint if the screen needs those fields.

---

## Server Architecture (Django)

The app does not import Django code. This section is the contract behind the endpoints above.

```
pickorbeet-backend/
├── manage.py
├── core/
│   ├── settings.py          # JWT, pagination, CORS, SSLCommerz, delivery defaults
│   └── urls.py              # /api/v1/<app>/
├── apps/
│   ├── accounts/            # User, Address, OTP, password reset
│   ├── products/            # catalog, homepage, store settings, contact
│   ├── orders/              # cart, checkout, coupons, delivery options
│   ├── payments/            # SSLCommerz
│   └── reports/             # staff only
├── media/                   # uploaded images
└── docs/
```

| App | Models the shop cares about |
|-----|-----------------------------|
| `accounts` | `User` (email login, roles), `Address` |
| `products` | `Category`, `SubCategory`, `Product`, `ProductImage`, `ProductVariant`, `HomepageBanner`, `HomepageSection`, `StoreSettings`, `ContactMessage` |
| `orders` | `Cart`, `CartItem`, `Order`, `OrderItem`, `OrderStatusHistory`, `Coupon`, `DeliveryOption` |
| `payments` | `Payment` (SSLCommerz session) |

`User.role` is `customer`, `seller`, `accountant`, or `super_admin`. The shop registers customers. Staff roles are created in the admin panel.

Default permissions are `IsAuthenticatedOrReadOnly`, with JWT first and session auth second. Public catalog reads do not need a token. Cart and checkout are `AllowAny` and use the session cookie for guests. Profile, addresses, and `my-orders` require a Bearer token.

Access tokens last 1 day. Refresh tokens last 7 days and rotate on every refresh. The header type is `Bearer`.

Timezone is `Asia/Dhaka`. Checkout sets the delivery charge from the shipping address: **৳60** when `shipping_city` is Dhaka, Mirpur, Uttara, Gulshan, Banani, Dhanmondi, or Mohammadpur, or when `shipping_district` is Dhaka; otherwise **৳120**. Those amounts are `DELIVERY_CHARGE_INSIDE_DHAKA` and `DELIVERY_CHARGE_OUTSIDE_DHAKA` in `core/settings.py`. The cart payload exposes the same two numbers. `GET /orders/delivery-options/` lists admin-defined options, but checkout does not read a selected option. `delivery_option` and `payment_method` sent on the checkout body are ignored.

---

## API Contract

- Prefix every path with `/api/v1` and end it with `/`.
- `Content-Type` and `Accept` are `application/json`.
- Authenticated calls send `Authorization: Bearer <access>`.
- Guest cart, coupon apply, and guest checkout send and store the `sessionid` cookie. Log in before checkout if the order should appear under `my-orders`.
- Success codes: `200` for reads and most writes, `201` for register, checkout, and contact, `204` is not used by the customer endpoints.
- Validation errors are `400` with a field map. Missing auth is `401` with `{"detail": "..."}`. Missing objects are `404` with `{"error": "..."}` or `{"detail": "Not found."}`.

Product images on list and detail payloads are **relative** (`/media/...`). Cart and order item images are **absolute** when the request has a host. Always run paths through `ServerConstant.mediaUrl`.

---

## Authentication Flow

```
Register ──► email OTP ──► verify-email ──► store access + refresh
Login ─────────────────────────────────────► store access + refresh
Google credential ─────────────────────────► store access + refresh
401 on a call ──► POST /auth/token/refresh/ ──► retry once
Logout ──► POST /auth/logout/ { refresh } ──► delete both tokens
```

### Register

`POST /auth/register/`

```json
{
  "email": "customer@example.com",
  "phone": "01700000000",
  "first_name": "Ayesha",
  "last_name": "Rahman",
  "password": "a-strong-password",
  "password_confirm": "a-strong-password"
}
```

`201` body:

```json
{
  "message": "Registration successful. Please check your email for verification code.",
  "user": { "id": "<uuid>", "email": "...", "first_name": "...", "last_name": "..." },
  "requires_verification": true
}
```

Passwords must match and pass Django's validators (length, common passwords, numeric-only, similarity to the email or name). `phone` is optional.

### Verify email

`POST /auth/verify-email/` with `{ "email", "otp_code" }`. The code is 6 digits and expires in 10 minutes. Five failed attempts invalidate it. Success returns `access`, `refresh`, and `user` (including `is_verified: true`). Store the session the same way as login.

`POST /auth/resend-verification/` with `{ "email" }` always returns a generic message.

### Login

`POST /auth/login/` with `{ "email", "password" }`.

```json
{
  "access": "<jwt>",
  "refresh": "<jwt>",
  "user": {
    "id": "<uuid>",
    "email": "customer@example.com",
    "first_name": "Ayesha",
    "last_name": "Rahman",
    "role": "customer",
    "full_name": "Ayesha Rahman"
  }
}
```

The access token also carries `email`, `role`, and `full_name` claims. Do not decode the token for profile data; use `/auth/profile/`.

### Google

`POST /auth/google/` with `{ "credential": "<Google ID token>" }`. The token must be issued for the same `GOOGLE_CLIENT_ID` the server expects. New users are created as verified customers. The response matches verify-email: `access`, `refresh`, and `user`.

### Session maintenance

| Action | Method and path | Body | Auth |
|--------|-----------------|------|------|
| Refresh | `POST /auth/token/refresh/` | `{ "refresh" }` | No |
| Logout | `POST /auth/logout/` | `{ "refresh" }` | Bearer |
| Profile | `GET` or `PATCH /auth/profile/` | profile fields on PATCH | Bearer |
| Change password | `POST /auth/change-password/` | `old_password`, `new_password`, `new_password_confirm` | Bearer |
| Forgot password | `POST /auth/forgot-password/` | `{ "email" }` | No |
| Reset password | `POST /auth/reset-password/` | `token`, `new_password`, `new_password_confirm` | No |

Forgot-password always returns the same message, whether or not the email exists. The reset link is emailed by the server and points at the website (`FRONTEND_URL/reset-password?token=...`). The app can still submit the token if it receives it.

### Addresses

All require a Bearer token. The server sets `user` and computes `is_inside_dhaka` from `city` and `district` (Dhaka and the listed area names).

| Action | Path |
|--------|------|
| List / create | `GET`, `POST /auth/addresses/` |
| Read / update / delete | `GET`, `PATCH`, `DELETE /auth/addresses/<uuid>/` |

Create body: `address_type` (`shipping` or `billing`), `full_name`, `phone`, `address_line1`, `address_line2`, `city`, `district`, `postal_code`, `country` (default `Bangladesh`), `is_default`.

---

## Customer Endpoints

Paths below are relative to `/api/v1`.

### Catalog

| Action | Path | Notes |
|--------|------|--------|
| Categories | `GET /products/categories/` | Paginated. Full category objects, including `subcategories` and `product_count` |
| Category | `GET /products/categories/<slug>/` | Same shape as one list item |
| Subcategories | `GET /products/categories/<category_slug>/subcategories/` | |
| Products | `GET /products/` | Active products only |
| Product | `GET /products/<slug>/` | Images, variants, descriptions |
| Featured | `GET /products/featured/` | Up to 12 featured products |
| Homepage | `GET /products/homepage/` | `{ "sections": [...] }` |
| Banners | `GET /products/banners/?placement=hero` | `hero` or `promo`. Not paginated |
| By category | `GET /products/by-category/` | First 6 categories, 4 products each |

`GET /products/` query parameters:

| Param | Example | Behavior |
|-------|---------|----------|
| `search` | `hijab` | Matches name, description, SKU |
| `ordering` | `price` or `-created_at` | Also `name` |
| `page` | `2` | Page size 20 |
| `category` | `<uuid>,<uuid>` | Category ids |
| `category_slug` | `borkha` | |
| `subcategory` | `<uuid>` | |
| `subcategory_slug` | `party-wear` | |
| `size` | `M,L` | `XS` `S` `M` `L` `XL` `XXL` `XXXL` `FREE` |
| `color` | `black` | Exact filter |
| `min_price`, `max_price` | `500`, `3000` | |
| `is_featured` | `true` | |
| `on_sale` | `true` | `compare_price` greater than `price` |
| `ids` | `<uuid>,<uuid>` | Unpaginated, max 50 ids |

List product fields: `id`, `name`, `slug`, `sku`, `barcode`, `category`, `category_name`, `subcategory`, `subcategory_name`, `short_description`, `price`, `compare_price`, `primary_image`, `discount_percentage`, `stock_quantity`, `is_low_stock`, `is_out_of_stock`, `is_featured`, `variants`.

Detail adds `description`, `barcode_image`, `size`, `color`, `material`, `images`, and full `category` / `subcategory` objects. `cost_price` is never returned on public serializers.

A variant includes `id`, `sku`, `size`, `color`, `price`, `stock_quantity`, `is_active`, and `effective_price` (`price` when set, otherwise the product price). Send `variant_id` when adding a variant to the cart.

Homepage sections use `type`: `hero`, `categories`, `benefits`, `products`, `promos`. Every section has `key`, `title`, `subtitle`, `view_all_label`, and `view_all_url`. Product sections add `products` in the list shape. Hero and promo sections add `banners` (`image`, `title`, `subtitle`, `button_label`, `link`, `placement`). Benefit sections add `items` (`id`, `title`, `description`, `icon` — `shield`, `truck`, `card`, or `returns`). A `categories` section has no nested categories; load those from `GET /products/categories/`.

### Cart

Guest carts require the cookie jar. Authenticated carts are looked up by the JWT user. Responses return the whole cart.

| Action | Path | Body |
|--------|------|------|
| Get | `GET /orders/cart/` | |
| Add | `POST /orders/cart/add/` | `{ "product_id", "variant_id"?, "quantity" }` |
| Update quantity | `PATCH /orders/cart/item/<item_uuid>/` | `{ "quantity" }` minimum 1 |
| Remove item | `DELETE /orders/cart/item/<item_uuid>/` | |
| Clear | `DELETE /orders/cart/clear/` | `{ "message": "Cart cleared" }` |

Cart body: `id`, `items`, `total_items`, `subtotal`, `delivery_charge_inside_dhaka`, `delivery_charge_outside_dhaka`.

Each item: `id`, `product`, `variant`, `product_name`, `product_image`, `quantity`, `unit_price`, `total_price`, `size`, `color`.

Add fails with `400` `{"error": "Insufficient stock"}` and `404` when the product or variant does not exist. Adding the same product and variant increments quantity.

### Checkout, coupons, delivery

| Action | Path | Auth |
|--------|------|------|
| Delivery options | `GET /orders/delivery-options/` | Public list: `id`, `name`, `charge`, `display_order`. Display only; checkout does not apply the selected row |
| Validate coupon | `POST /orders/coupons/validate/` | `{ "code", "subtotal"? }` |
| Apply to cart | `POST /orders/coupons/apply/` | `{ "code" }` uses the current cart subtotal |
| Checkout | `POST /orders/checkout/` | Guest or Bearer. Needs a non-empty cart. Charge comes from the shipping address |

Validate and apply return `valid`, `coupon`, and `discount_amount`. Invalid codes are `400` with `valid: false` and `error`.

Checkout body (guest email, phone, and name are optional when a Bearer token is sent):

```json
{
  "guest_email": "guest@example.com",
  "guest_phone": "01700000000",
  "guest_name": "Guest",
  "shipping_name": "Ayesha Rahman",
  "shipping_phone": "01700000000",
  "shipping_address_line1": "House 12, Road 5",
  "shipping_address_line2": "",
  "shipping_city": "Dhaka",
  "shipping_district": "Dhaka",
  "shipping_postal_code": "1212",
  "use_different_billing": false,
  "coupon_code": "WELCOME10",
  "notes": ""
}
```

`201` returns `{ "message", "order" }`. The order includes `order_number` (`ORD-YYYYMMDD-XXXXXX`), `tracking_number`, `order_status: "pending"`, `payment_status: "pending"`, `subtotal`, `delivery_charge`, `discount`, `total`, `items`, and `status_history`. Use the returned `delivery_charge` and `total`. A charge preview built from `delivery-options` can disagree with the saved order. The cart is emptied. Stock is reduced later, when staff confirm the order, not at checkout.

Cash on delivery is “do not call the payment endpoint.” The order stays `payment_status: "pending"` until staff mark it paid. Card and mobile banking call `POST /payments/initiate/` with the new order id.

`order_status` values: `pending`, `confirmed`, `processing`, `shipped`, `out_for_delivery`, `delivered`, `cancelled`, `refunded`.

`payment_status` values: `pending`, `paid`, `failed`, `refunded`.

`order_type` for the app is `online`.

### Orders

| Action | Path | Auth |
|--------|------|------|
| My orders | `GET /orders/my-orders/` | Bearer. Paginated list |
| Order detail | `GET /orders/my-orders/<uuid>/` | Bearer. Only that user's orders |
| Track | `POST /orders/track/` | Public |

Track body needs `order_number` or `tracking_number`. Optional `phone` must match `shipping_phone` or `guest_phone`. The response includes status timestamps and `status_history`, not the full address.

### Payments

`POST /payments/initiate/` with `{ "order_id": "<order uuid>" }` is public.

Success:

```json
{
  "payment_url": "https://sandbox.sslcommerz.com/...",
  "session_key": "...",
  "transaction_id": "TXN-..."
}
```

Open `payment_url` in an in-app web view. SSLCommerz redirects to the website success, fail, and cancel URLs. The app should watch those navigations, close the web view, and reload the order. Do not mark an order paid on the client. The server updates `payment_status` from the gateway callback.

Already-paid orders and a missing gateway configuration return `400` or `500` with `error`.

### Store and contact

`GET /products/settings/public/` returns `logo`, `popular_searches` (comma-separated string), `contact_address`, `contact_phone_1`, `contact_phone_2`, `contact_email_1`, `contact_email_2`, `business_hours`, and `map_embed_url`.

`POST /products/contact/` with `name`, `email`, `phone`, `subject`, `message` returns `201` and `{ "message" }`.

---

## Adding New Features

1. Confirm the endpoint in `pickorbeet-backend/apps/<app>/urls.py` and the serializer fields. Prefer the customer routes listed above. Routes under `admin/`, plus everything in `reports/`, require a staff role and belong to the admin panel.
2. Add a model whose `fromMap` uses the serializer's JSON keys, including nested objects.
3. Add a remote repository method that calls `ApiClient` and returns `Either<AppFailure, T>`.
4. Add a Riverpod view model. Put shared session data in `core/providers`, not in the feature.
5. Add pages that watch the view model and listen for `AsyncValue` success and error.
6. If the endpoint needs a signed-in user, send the Bearer token and handle `401` through the shared refresh path.
7. If the endpoint is a cart or checkout call, send it through the cookie-aware client.

A new catalog filter is a query parameter on the existing product repository, not a new endpoint. A new screen that only rearranges homepage sections should read `GET /products/homepage/` instead of hard-coding section order.

---

## Best Practices

- Keep one `ApiClient`. Do not build `http.Client` calls inside widgets.
- Treat every list response as paginated unless this guide says otherwise. Request the next page from `next`, or pass `page`.
- Keep decimal money as strings in models. Format with a `৳` prefix in the widget.
- Resolve every image with `ServerConstant.mediaUrl` so relative and absolute URLs both work.
- Send UUIDs as strings. Never trim the hyphens.
- Preserve trailing slashes. Django redirects a missing slash, and that redirect can drop a POST body.
- After register, route to OTP entry. Do not write tokens until verify-email, login, or Google returns them.
- Save the rotated refresh token. Reusing an old refresh token fails once rotation and blacklisting are on.
- Clear the cart notifier when checkout returns `201`, and clear the user notifier on logout.
- Surface `error`, `detail`, and the first field error. A password mismatch arrives as `{"password": ["Passwords don't match."]}`.
- Do not send `cost_price`, staff ids, or report requests from the shop app.
- Guest checkout is supported. Orders created without a Bearer token will not show up in `my-orders`.

---

## Dependencies & Setup

### Backend

From `pickorbeet-backend`:

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python manage.py migrate
python manage.py runserver 8000
```

Create the PostgreSQL database `pickorbeet_db` first. Auth, catalog, and guest cart work without Google or SSLCommerz keys. Google sign-in needs `GOOGLE_CLIENT_ID`. Card payment needs `SSLCOMMERZ_STORE_ID`, `SSLCOMMERZ_STORE_PASSWORD`, and `SSLCOMMERZ_SANDBOX=True` for the sandbox.

### Flutter

```yaml
dependencies:
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  fpdart: ^1.1.0
  http: ^1.2.2
  shared_preferences: ^2.3.2

dev_dependencies:
  build_runner: ^2.4.13
  riverpod_generator: ^2.6.2
```

Generate providers after changing an annotated file:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Run the API before the app. Point `ServerConstant` at `10.0.2.2` on Android and at the machine's LAN address on a physical device. Confirm a public call first:

```bash
curl -s http://127.0.0.1:8000/api/v1/products/homepage/
```
