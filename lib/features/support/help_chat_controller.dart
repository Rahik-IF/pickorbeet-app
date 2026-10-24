import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pickorbeet/core/constants/server_constant.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/features/support/help_models.dart';
import 'package:pickorbeet/features/support/support_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HelpChatState {
  const HelpChatState({
    this.loading = true,
    this.sending = false,
    this.error = '',
    this.profile = HelpProfile.empty,
    this.messages = const [],
    this.agentOnline = false,
    this.agentTyping = false,
  });

  final bool loading;
  final bool sending;
  final String error;
  final HelpProfile profile;
  final List<HelpMessage> messages;
  final bool agentOnline;
  final bool agentTyping;

  HelpChatState copyWith({
    bool? loading,
    bool? sending,
    String? error,
    HelpProfile? profile,
    List<HelpMessage>? messages,
    bool? agentOnline,
    bool? agentTyping,
  }) => HelpChatState(
    loading: loading ?? this.loading,
    sending: sending ?? this.sending,
    error: error ?? this.error,
    profile: profile ?? this.profile,
    messages: messages ?? this.messages,
    agentOnline: agentOnline ?? this.agentOnline,
    agentTyping: agentTyping ?? this.agentTyping,
  );
}

class HelpChatController extends AutoDisposeNotifier<HelpChatState> {
  String _orderNumber = '';
  var _alive = true;
  var _stopped = true;
  var _hasConnected = false;
  var _generation = 0;
  var _attempt = 0;
  var _typingSent = false;
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _retry;
  Timer? _typingClear;

  @override
  HelpChatState build() {
    ref.onDispose(() {
      _alive = false;
      _stop();
    });
    return const HelpChatState();
  }

  Future<void> open(String orderNumber) async {
    _orderNumber = orderNumber;
    _stopped = false;
    state = state.copyWith(loading: true, error: '');
    final result = await ref.read(supportRepositoryProvider).fetchThread();
    if (!_alive) return;
    result.match(
      (failure) =>
          state = state.copyWith(loading: false, error: failure.message),
      (thread) => state = state.copyWith(
        loading: false,
        error: '',
        profile: thread.profile,
        messages: thread.messages,
        agentOnline: thread.agentOnline,
      ),
    );
    if (result.isRight()) await _connect(forceRefresh: false);
  }

  Future<String?> sendText(String body) => _send(body: body);

  Future<String?> sendTopic(String topic) => _send(
    topic: topic,
    orderNumber: topic == 'track_order' ? _orderNumber : '',
  );

  Future<String?> sendPhoto(
    List<int> bytes,
    String filename, {
    String caption = '',
  }) => _send(body: caption, imageBytes: bytes, filename: filename);

  void setTyping(bool active) {
    if (_typingSent == active) return;
    _typingSent = active;
    final socket = _socket;
    if (socket == null) return;
    socket.sink.add(jsonEncode({'type': 'typing', 'active': active}));
  }

  Future<String?> _send({
    String body = '',
    String topic = '',
    String orderNumber = '',
    List<int>? imageBytes,
    String? filename,
  }) async {
    setTyping(false);
    state = state.copyWith(sending: true);
    final result = await ref
        .read(supportRepositoryProvider)
        .send(
          body: body,
          topic: topic,
          orderNumber: orderNumber,
          imageBytes: imageBytes,
          filename: filename,
        );
    if (!_alive) return null;
    return result.match(
      (failure) {
        state = state.copyWith(sending: false);
        return failure.message;
      },
      (message) {
        _upsert(message);
        state = state.copyWith(sending: false);
        return null;
      },
    );
  }

  void _stop() {
    _stopped = true;
    _generation++;
    _retry?.cancel();
    _typingClear?.cancel();
    unawaited(_socketSub?.cancel());
    _socketSub = null;
    unawaited(_socket?.sink.close());
    _socket = null;
  }

  Future<void> _connect({required bool forceRefresh}) async {
    if (_stopped) return;
    final generation = ++_generation;
    _retry?.cancel();
    await _socketSub?.cancel();
    await _socket?.sink.close();
    _socket = null;
    _typingSent = false;
    final token = await ref
        .read(apiClientProvider)
        .ensureAccess(force: forceRefresh);
    if (_stopped || generation != _generation || token == null) return;
    if (_hasConnected) unawaited(_reload());
    _hasConnected = true;
    final channel = WebSocketChannel.connect(_socketUri(token));
    _socket = channel;
    _socketSub = channel.stream.listen(
      (event) {
        _attempt = 0;
        _onSocket(event);
      },
      onError: (_) => _scheduleRetry(generation),
      onDone: () {
        if (_stopped || generation != _generation) return;
        if (channel.closeCode == 4401) {
          unawaited(_connect(forceRefresh: true));
          return;
        }
        _scheduleRetry(generation);
      },
    );
  }

  void _scheduleRetry(int generation) {
    if (_stopped || generation != _generation) return;
    final seconds = (1 << _attempt.clamp(0, 5)).clamp(1, 30);
    _attempt++;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: seconds), () {
      if (!_stopped) unawaited(_connect(forceRefresh: false));
    });
  }

  void _onSocket(dynamic event) {
    if (event is! String) return;
    final decoded = jsonDecode(event);
    if (decoded is! Map) return;
    final json = asJson(decoded);
    switch (json.str('type')) {
      case 'message.created':
        final row = json.obj('message');
        if (row == null) return;
        final message = HelpMessage.fromJson(row);
        _upsert(message);
        if (!message.fromCustomer) {
          unawaited(ref.read(supportRepositoryProvider).markRead());
        }
      case 'message.read':
        _applyRead(json.str('author'), json.date('read_at'));
      case 'presence':
        state = state.copyWith(agentOnline: json.boolean('agent_online'));
      case 'typing':
        if (json.str('author') == 'customer') return;
        _showTyping(json.boolean('active'));
    }
  }

  Future<void> _reload() async {
    final result = await ref.read(supportRepositoryProvider).fetchThread();
    if (!_alive) return;
    result.match(
      (_) {},
      (thread) => state = state.copyWith(
        profile: thread.profile,
        messages: thread.messages,
        agentOnline: thread.agentOnline,
        error: '',
      ),
    );
  }

  void _upsert(HelpMessage message) {
    final next = [...state.messages];
    final index = next.indexWhere((item) => item.id == message.id);
    if (index >= 0) {
      next[index] = message;
    } else {
      next.add(message);
    }
    next.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = state.copyWith(
      messages: next,
      agentTyping: message.fromCustomer ? state.agentTyping : false,
    );
  }

  void _applyRead(String author, DateTime? readAt) {
    if (author.isEmpty || readAt == null) return;
    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          if (message.author == author && message.readAt == null)
            message.copyWith(readAt: readAt)
          else
            message,
      ],
    );
  }

  void _showTyping(bool active) {
    _typingClear?.cancel();
    state = state.copyWith(agentTyping: active);
    if (!active) return;
    _typingClear = Timer(const Duration(seconds: 4), () {
      if (_alive) state = state.copyWith(agentTyping: false);
    });
  }
}

final helpChatProvider =
    NotifierProvider.autoDispose<HelpChatController, HelpChatState>(
      HelpChatController.new,
    );

Uri _socketUri(String token) {
  final origin = ServerConstant.origin;
  final ws = origin.startsWith('https://')
      ? origin.replaceFirst('https://', 'wss://')
      : origin.replaceFirst('http://', 'ws://');
  return Uri.parse(
    '$ws/ws/support/',
  ).replace(queryParameters: {'token': token});
}
