import 'package:flutter_test/flutter_test.dart';
import 'package:pickorbeet/core/models/user_model.dart';
import 'package:pickorbeet/features/account/profile_draft.dart';

void main() {
  test('names, phone, and photo size', () {
    expect(ProfileDraft.nameError('  ', 'first name'), 'Enter your first name.');
    expect(ProfileDraft.nameError('Rahik', 'first name'), isNull);
    expect(ProfileDraft.phoneError(''), isNull);
    expect(ProfileDraft.phoneError('+880 1712-345678'), isNull);
    expect(ProfileDraft.phoneError('021234567'), isNotNull);
    expect(ProfileDraft.photoError(0), isNotNull);
    expect(ProfileDraft.photoError(ProfileDraft.maxPhotoBytes), isNull);
    expect(ProfileDraft.photoError(ProfileDraft.maxPhotoBytes + 1), 'Profile photos must be 2 MB or smaller.');
    expect(ProfileDraft.filenameFor('photo.JPEG'), 'avatar.jpg');
    expect(ProfileDraft.filenameFor('photo.png'), 'avatar.png');
    expect(ProfileDraft.filenameFor('photo.gif'), 'avatar.jpg');
    expect(ProfileDraft.filenameFor('../secret.png'), 'avatar.png');
  });

  test('login keeps the saved photo and a profile response can clear it', () {
    final saved = UserModel.fromMap({
      'id': '1',
      'email': 'nehal@example.com',
      'first_name': 'Rahik',
      'last_name': 'Forman',
      'phone': '01712345678',
      'address': 'Road 1',
      'city': 'Dhaka',
      'postal_code': '1207',
      'avatar': 'https://cdn.example/a.jpg',
    });
    final login = UserModel.fromMap({
      'id': '1',
      'email': 'nehal@example.com',
      'first_name': 'Rahik',
      'last_name': 'Forman',
      'role': 'customer',
      'full_name': 'Rahik Forman',
    });

    final merged = login.mergeMissing(saved);
    expect(merged.avatar, 'https://cdn.example/a.jpg');
    expect(merged.phone, '01712345678');
    expect(merged.address, 'Road 1');
    expect(merged.fromProfile, isFalse);

    final cleared = UserModel.fromMap({
      'id': '1',
      'email': 'nehal@example.com',
      'first_name': 'Rahik',
      'last_name': 'Forman',
      'phone': '',
      'address': '',
      'city': 'Dhaka',
      'postal_code': '1207',
      'avatar': null,
    });
    final next = cleared.mergeMissing(merged);
    expect(next.fromProfile, isTrue);
    expect(next.avatar, isNull);
    expect(next.phone, isNull);
    expect(next.city, 'Dhaka');
  });
}
