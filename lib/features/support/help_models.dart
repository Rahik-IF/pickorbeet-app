import 'package:pickorbeet/core/network/json.dart';

class HelpProfile {
  const HelpProfile({
    required this.name,
    required this.replyLine,
    required this.avatar,
    required this.phone,
    required this.email,
  });

  final String name;
  final String replyLine;
  final String avatar;
  final String phone;
  final String email;

  static const empty = HelpProfile(
    name: 'Nadia Rahman',
    replyLine: 'Usually replies in 2 min',
    avatar: '',
    phone: '',
    email: '',
  );

  factory HelpProfile.fromJson(Json json) => HelpProfile(
    name: json.str('display_name', 'Nadia Rahman'),
    replyLine: json.str('reply_line', 'Usually replies in 2 min'),
    avatar: json.str('avatar'),
    phone: json.str('phone'),
    email: json.str('email'),
  );
}

class HelpOrderCard {
  const HelpOrderCard({
    required this.id,
    required this.orderNumber,
    required this.displayNumber,
    required this.productName,
    required this.productImage,
    required this.status,
    required this.statusLabel,
    required this.expectedDelivery,
  });

  final String id;
  final String orderNumber;
  final String displayNumber;
  final String productName;
  final String productImage;
  final String status;
  final String statusLabel;
  final String expectedDelivery;

  factory HelpOrderCard.fromJson(Json json) => HelpOrderCard(
    id: json.str('id'),
    orderNumber: json.str('order_number'),
    displayNumber: json.str('display_number', json.str('order_number')),
    productName: json.str('product_name'),
    productImage: json.str('product_image'),
    status: json.str('status'),
    statusLabel: json.str('status_label'),
    expectedDelivery: json.str('expected_delivery'),
  );
}

class HelpMessage {
  const HelpMessage({
    required this.id,
    required this.author,
    required this.body,
    required this.topic,
    required this.topicLabel,
    required this.image,
    required this.order,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final String author;
  final String body;
  final String topic;
  final String topicLabel;
  final String image;
  final HelpOrderCard? order;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get fromCustomer => author == 'customer';

  factory HelpMessage.fromJson(Json json) {
    final order = json.obj('order');
    return HelpMessage(
      id: json.str('id'),
      author: json.str('author'),
      body: json.str('body'),
      topic: json.str('topic'),
      topicLabel: json.str('topic_label'),
      image: json.str('image'),
      order: order == null ? null : HelpOrderCard.fromJson(order),
      readAt: json.date('read_at'),
      createdAt: json.date('created_at') ?? DateTime.now(),
    );
  }

  HelpMessage copyWith({DateTime? readAt}) => HelpMessage(
    id: id,
    author: author,
    body: body,
    topic: topic,
    topicLabel: topicLabel,
    image: image,
    order: order,
    readAt: readAt ?? this.readAt,
    createdAt: createdAt,
  );
}

class HelpThread {
  const HelpThread({
    required this.profile,
    required this.messages,
    required this.agentOnline,
  });

  final HelpProfile profile;
  final List<HelpMessage> messages;
  final bool agentOnline;

  factory HelpThread.fromJson(Json json) => HelpThread(
    profile: HelpProfile.fromJson(json.obj('profile') ?? const {}),
    messages: json.listOf('messages', HelpMessage.fromJson),
    agentOnline: json.boolean('agent_online'),
  );
}
