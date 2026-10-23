import 'package:pickorbeet/core/models/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_user_notifier.g.dart';

/// The signed-in customer's profile for the whole session. Tokens live in `AuthLocalRepository`.
@Riverpod(keepAlive: true)
class CurrentUserNotifier extends _$CurrentUserNotifier {
  @override
  UserModel? build() => null;

  void setUser(UserModel user) => state = user.mergeMissing(state);

  void clear() => state = null;
}
