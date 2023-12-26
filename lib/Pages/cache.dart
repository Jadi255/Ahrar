import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'cache.g.dart';

@HiveType(typeId: 0)
class Message {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String to;
  @HiveField(2)
  final String from;
  @HiveField(3)
  final String text;
  @HiveField(4)
  final DateTime created;
  @HiveField(5)
  final DateTime updated;

  Message(this.id, this.to, this.from, this.text, this.created, this.updated);
}

class CacheManager {
  Future<void> cacheMessage(Message message) async {
    final box = await Hive.openBox<Message>('messages');
    await box.put(message.id, message);
  }

  Future<List<Message>> getMessages() async {
    final box = await Hive.openBox<Message>('messages');
    return box.values.toList();
  }

  Future<void> clearMessages() async {
    final box = await Hive.openBox<Message>('messages');
    await box.clear();
  }
}