/// Public Google OAuth client id. The client secret stays on the server.
abstract final class GoogleAuthConfig {
  static const clientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '313521900523-f09l9n8s1uh1qvnnqo3dc3mpm0go2jrr.apps.googleusercontent.com',
  );
}
