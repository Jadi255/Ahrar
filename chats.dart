import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_bubbles/bubbles/bubble_special_one.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qalam/Pages/cache.dart';
import 'package:qalam/Pages/fetchers.dart';
import 'package:qalam/Pages/profile_settings.dart';
import 'package:qalam/Pages/writers.dart';
import 'package:qalam/styles.dart';
import 'package:qalam/user_data.dart';

class AllConversations extends StatefulWidget {
  const AllConversations({super.key});

  @override
  State<AllConversations> createState() => _AllConversationsState();
}

class _AllConversationsState extends State<AllConversations>
    with AutomaticKeepAliveClientMixin {
  List<Widget> convos = [];
  List<String> conversations = [];
  bool isLoading = false;
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'لا تزال خاصية المحادثات في المرحلة التجريبية، نعتذر لوجود بعض المشاكل'),
    ));
    fetchMessages();
    realtime();
  }

  void realtime() async {
    if (!kIsWeb) {
      convos.clear();
      final user = Provider.of<User>(context, listen: false);
      user.pb.collection('messages').subscribe('*', (e) async {
        isLoading = true;
        await fetchMessages();
      });
    } else if (kIsWeb) {
      Timer.periodic(Duration(seconds: 15), (timer) async {
        try {
          final cacheManager = CacheManager();
          final messages = await cacheManager.getMessages();
          List ids = [];
          for (var message in messages) {
            ids.add(message.id);
          }
          final user = Provider.of<User>(context, listen: false);

          var newest = await user.pb
              .collection('messages')
              .getList(page: 1, perPage: 1, sort: '-created');
          var response = newest.items[0];
          var id = response.toJson()['id'];
          if (!ids.contains(id)) {
            isLoading = true;
            await fetchMessages();
          }
        } catch (e) {
          print(e);
        }
      });
    }
  }

  String formatDate(DateTime date) {
    date = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final aDate = DateTime(date.year, date.month, date.day);
    var hour = date.hour;
    var minutes = date.minute;
    if (aDate == today) {
      return '${hour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    } else {
      return '${aDate.day}/${aDate.month}\n${hour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    }
  }

  Future fetchMessages() async {
    conversations.clear();
    setState(() {
      isLoading = true;
    });

    final user = Provider.of<User>(context, listen: false);
    final fetcher = Fetcher(pb: user.pb);
    var messages = await fetcher.fetchMessages(user.id);
    final cacheManager = CacheManager();
    if (messages.length == 0) {
      convos = [];
      setState(() {});
    }

    for (int i = 0; i < messages.length; i++) {
      var item = messages[i].toJson();
      final message = Message(
        item['id'],
        item['to'],
        item['from'],
        item['text'],
        DateTime.parse(item['created']),
        DateTime.parse(item['updated']),
      );
      await cacheManager.cacheMessage(message);

      if (item['from'] != user.id) {
        conversations.add(item['from']);
      } else if (item['to'] != user.id) {
        conversations.add(item['to']);
      }
    }
    convos.clear();
    conversations = conversations.toSet().toList();
    for (var conversation in conversations) {
      String? lastText;
      var msgTime;
      var setLatest = messages.reversed.toList();
      for (var item in setLatest) {
        var message = item.toJson();
        if (message['from'] == conversation || message['to'] == conversation) {
          lastText = message['text'];
          msgTime = formatDate(DateTime.parse(message['created']));
        }
      }
      var request = await fetcher.getUser(conversation);
      var chatPartner = request.toJson();
      final avatarUrl =
          user.pb.getFileUrl(request, chatPartner['avatar']).toString();
      convos.add(
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        ConversationView(
                      id: chatPartner['id'],
                      name: chatPartner['full_name'],
                      avatar: avatarUrl,
                    ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      var begin = Offset(1.0, 0.0);
                      var end = Offset.zero;
                      var curve = Curves.ease;

                      var tween = Tween(begin: begin, end: end)
                          .chain(CurveTween(curve: curve));

                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                  ),
                );
              },
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: Colors.grey.shade100,
                foregroundImage: CachedNetworkImageProvider(avatarUrl),
                backgroundImage: Image.asset('assets/placeholder.jpg').image,
              ),
              title: Text(chatPartner['full_name'],
                  style: defaultText, textScaler: TextScaler.linear(0.90)),
              //subtitle: Text(lastText!, textScaler: TextScaler.linear(0.80)),
              trailing: Text(
                msgTime,
                textAlign: TextAlign.center,
                textScaler: TextScaler.linear(0.75),
              ),
            ),
          ),
        ),
      );
    }
    isLoading = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = Provider.of<User>(context, listen: false);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        child: Icon(Icons.message_rounded),
        onPressed: () {
          showModalBottomSheet(
              enableDrag: false,
              context: context,
              builder: (context) {
                return Scaffold(
                    appBar: AppBar(
                      automaticallyImplyLeading: true,
                    ),
                    body: MyFriends(
                      user: user,
                      chatMode: true,
                    ));
              });
        },
      ),
      body: SingleChildScrollView(
          child: pagePadding(
        Column(
          children: [
            Visibility(
              visible: isLoading,
              child: Center(child: shimmer),
            ),
            Visibility(
              visible: !isLoading,
              child: Column(
                children: convos,
              ),
            ),
          ],
        ),
      )),
    );
  }
}

class ConversationView extends StatefulWidget {
  final name;
  final id;
  final avatar;
  const ConversationView({super.key, required this.name, this.id, this.avatar});

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  TextEditingController controller = TextEditingController();
  List<String> messages = [];
  List<Widget> bubbles = [];
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadMessagesFromCache().then((_) {
      // Wait for the UI to be rendered then scroll to the bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    });
    realTime();
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void realTime() async {
    final user = Provider.of<User>(context, listen: false);
    if (!kIsWeb) {
      user.pb.collection('messages').subscribe(
        '*',
        (e) async {
          var action = e.action;
          if (action == 'create') {
            var record = e.record;
            var message = record!.toJson();
            if (message['from'] == user.id) {
              return;
            }
            var bubble;
            var msgTime = DateTime.parse(message['created']);
            var local = msgTime.toLocal();
            var time =
                '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
            bubble = Column(
              children: [
                BubbleSpecialOne(
                  text: message['text'],
                  isSender: false,
                  tail: false,
                  color: Colors.white,
                  textStyle: TextStyle(color: blackColor, fontSize: 14),
                ),
                BubbleSpecialOne(
                  text: time,
                  isSender: false,
                  tail: false,
                  color: Colors.transparent,
                  textStyle:
                      TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
              ],
            );

            bubbles.add(bubble);
            setState(() {});
            final cacheMessage = Message(
              message['id'],
              message['to'],
              message['from'],
              message['text'],
              DateTime.parse(message['created']),
              DateTime.parse(message['updated']),
            );
            await CacheManager().cacheMessage(cacheMessage);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          });
          setState(() {});
        },
      );
    } else if (kIsWeb) {
      final fetcher = Fetcher(pb: user.pb);
      Timer.periodic(Duration(seconds: 15), (timer) async {
        try {
          final newMessages = await fetcher.fetchMessages(user.id);
          for (var item in newMessages) {
            var message = item.toJson();
            if (!messages.contains(message['id'])) {
              messages.add(message['id']);
              bool isSender = (message['from'] == user.id);
              var bubble;
              var msgTime = DateTime.parse(message['created']);
              var local = msgTime.toLocal();
              var time =
                  '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
              if (!isSender) {
                bubble = Column(
                  children: [
                    BubbleSpecialOne(
                      text: message['text'],
                      isSender: false,
                      tail: false,
                      color: Colors.white,
                      textStyle: TextStyle(color: blackColor, fontSize: 14),
                    ),
                    BubbleSpecialOne(
                      text: time,
                      isSender: false,
                      tail: false,
                      color: Colors.transparent,
                      textStyle:
                          TextStyle(color: Colors.grey.shade500, fontSize: 10),
                    ),
                  ],
                );
              }
              bubbles.add(bubble);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollController
                    .jumpTo(_scrollController.position.maxScrollExtent);
              });
              setState(() {});
              final cacheMessage = Message(
                message['id'],
                message['to'],
                message['from'],
                message['text'],
                DateTime.parse(message['created']),
                DateTime.parse(message['updated']),
              );
              await CacheManager().cacheMessage(cacheMessage);
            }
          }
        } catch (e) {
          print(e);
        }
      });
    }
  }

  String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final aDate = DateTime(date.year, date.month, date.day);

    if (aDate == today) {
      return 'اليوم';
    } else if (aDate == yesterday) {
      return 'أمس';
    } else {
      return '${aDate.day}/${aDate.month}/${aDate.year}';
    }
  }

  Future<void> loadMessagesFromCache() async {
    final cacheManager = CacheManager();
    List cachedMessages = await cacheManager.getMessages();
    DateTime? lastDate;
    cachedMessages.sort((a, b) => a.created.compareTo(b.created));

    for (var message in cachedMessages) {
      messages.add(message.id);
      if (lastDate == null || !isSameDay(lastDate, message.created)) {
        if (message.from == widget.id || message.to == widget.id) {
          lastDate = message.created;
          final dateChip = Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: Center(
              child: Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text(
                    formatDate(lastDate!),
                  ),
                ),
                color: Color.fromARGB(255, 205, 229, 230),
                surfaceTintColor: Color.fromARGB(255, 205, 229, 230),
              ),
            ),
          );
          bubbles.add(dateChip);
        }
      }

      final user = Provider.of<User>(context, listen: false);
      bool isSender = (message.from == user.id);
      var bubble;
      var local = message.created.toLocal();
      var time =
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      if (isSender) {
        if (message.to == widget.id) {
          bubble = Column(
            children: [
              BubbleSpecialOne(
                text: message.text,
                isSender: true,
                tail: false,
                color: greenColor,
                textStyle: TextStyle(color: Colors.white, fontSize: 14),
              ),
              BubbleSpecialOne(
                text: time,
                isSender: true,
                tail: false,
                color: Colors.transparent,
                textStyle: TextStyle(color: Colors.grey.shade500, fontSize: 10),
              ),
            ],
          );
          bubbles.add(bubble);
        }
      } else {
        if (message.from == widget.id) {
          bubble = Column(
            children: [
              BubbleSpecialOne(
                text: message.text,
                isSender: false,
                tail: false,
                color: Colors.white,
                textStyle: TextStyle(color: blackColor, fontSize: 14),
              ),
              BubbleSpecialOne(
                text: time,
                isSender: false,
                tail: false,
                color: Colors.transparent,
                textStyle: TextStyle(color: Colors.grey.shade500, fontSize: 10),
              ),
            ],
          );
          bubbles.add(bubble);
        }
      }
    }

    setState(() {});
  }

  void sendMessage() async {
    if (controller.text == "") {
      return;
    }
    var messageText = controller.text;
    var date = DateTime.now();
    var local = date.toLocal();
    var time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    CacheManager cacheManager = CacheManager();
    var text = controller.text;
    var bubble = Column(
      children: [
        BubbleSpecialOne(
          text: text,
          isSender: true,
          tail: false,
          color: greenColor,
          textStyle: TextStyle(color: Colors.white, fontSize: 14),
        ),
        BubbleSpecialOne(
          text: time,
          isSender: true,
          tail: false,
          color: Colors.transparent,
          textStyle: TextStyle(color: Colors.grey.shade500, fontSize: 10),
        ),
      ],
    );
    bubbles.add(bubble);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });

    setState(() {
      controller.text = '';
    });

    final user = Provider.of<User>(context, listen: false);
    final writer = Writer(pb: user.pb);

    try {
      final request = await writer.sendMessage(messageText, user.id, widget.id);
      final message = Message(
        request['id'],
        request['to'],
        request['from'],
        request['text'],
        DateTime.parse(request['created']),
        DateTime.parse(request['updated']),
      );
      await cacheManager.cacheMessage(message);

      await writer.messageNotifier(request['to'], request['from']);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ ما. الرجاء المحاولة في وقت لاحق')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          centerTitle: true,
          title: Padding(
            padding: const EdgeInsets.all(10.0),
            child: ListTile(
              title: Text(widget.name, style: defaultText),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: Colors.grey.shade100,
                foregroundImage: CachedNetworkImageProvider(widget.avatar),
                backgroundImage: Image.asset('assets/placeholder.jpg').image,
              ),
            ),
          )),
      bottomSheet: SafeArea(
        bottom: true,
        child: Container(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    maxLines: null,
                    controller: controller,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelStyle: TextStyle(
                        color: Colors.black, // Set your desired color
                      ),
                      contentPadding: EdgeInsets.all(20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    sendMessage();
                  },
                  icon: Icon(Icons.send),
                )
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 100),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15.0),
            child: Column(
              children: bubbles,
            ),
          ),
        ),
      ),
    );
  }
}
