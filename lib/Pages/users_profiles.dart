import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qalam/Pages/chats.dart';
import 'package:qalam/Pages/fetchers.dart';
import 'package:qalam/Pages/renderers.dart';
import 'package:qalam/styles.dart';
import 'package:qalam/user_data.dart';

class UserProfile extends StatefulWidget {
  final id;
  final fullName;
  final avatar;
  const UserProfile(
      {super.key, required this.id, required this.fullName, this.avatar});

  @override
  State<UserProfile> createState() => UserProfileState();
}

class UserProfileState extends State<UserProfile> {
  var id;
  var fullName;
  var avatar;
  bool isVerified = false;
  @override
  void initState() {
    super.initState();
    id = widget.id;
    fullName = widget.fullName;
    avatar = widget.avatar;
  }

  Future getUser() async {
    final provider = Provider.of<User>(context, listen: false);
    final _fetcher = Fetcher(pb: provider.pb);
    var record = await _fetcher.getUser(id);
    var user = record.toJson();
    final avatarUrl = _fetcher.pb.getFileUrl(record, user['avatar']).toString();
    var isFriend = user['friends'].contains(provider.id);
    if (user['is_verified']) {
      isVerified = true;
    }

    final widget = pagePadding(
      Column(
        children: [
          themedCard(
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  GestureDetector(
                    child: circularImage(CachedNetworkImageProvider(avatarUrl)),
                    onTap: () {
                      showImage(context, CachedNetworkImageProvider(avatarUrl));
                    },
                  ),
                  if (isVerified)
                    IconButton(
                      icon: Icon(Icons.check_circle_rounded),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم التحقق من هوية هذا الحساب'),
                          ),
                        );
                      },
                      color: greenColor,
                    ),
                  ListTile(
                    title: Text(
                      user['full_name'],
                      textScaler: TextScaler.linear(1.15),
                      style: defaultText,
                      textAlign: TextAlign.center,
                    ),
                    subtitle: Text(
                      user['about'],
                      textScaler: TextScaler.linear(0.85),
                      style: defaultText,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isFriend)
            Card(
              color: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0.5,
              child: ListTile(
                trailing: const Icon(Icons.person_add),
                title: Text('إضافة صديق', style: defaultText),
                onTap: () async {
                  Fetcher fetcher = Fetcher(pb: provider.pb);
                  var request =
                      await fetcher.sendRequest(user['id'], provider.id);
                  if (request) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم إرسال طلب صداقة'),
                      ),
                    );
                  }
                  if (!request) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'لقد قمت بإرسال طلب صداقة مسبقاً وبانتظار قبوله'),
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          if (isFriend)
            Card(
              color: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0.5,
              child: ListTile(
                trailing: const Icon(Icons.person_remove),
                title: Text('إزالة صديق', style: defaultText),
                onTap: () async {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          actionsAlignment: MainAxisAlignment.spaceBetween,
                          backgroundColor: Colors.white,
                          surfaceTintColor: Colors.white,
                          content: Text('هل أنت متأكد؟',
                              style: defaultText, textAlign: TextAlign.center),
                          actions: [
                            IconButton(
                              onPressed: () async {
                                final fetcher = Fetcher(pb: provider.pb);
                                await fetcher.removeFriend(
                                    user['id'], provider.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('تم إزالة الصديق'),
                                  ),
                                );
                                Navigator.of(context).pop();
                              },
                              icon: Icon(Icons.check, color: greenColor),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              icon: Icon(Icons.close, color: redColor),
                            )
                          ],
                        );
                      });
                },
              ),
            ),
          Card(
            color: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0.5,
            child: ListTile(
              trailing: const Icon(Icons.message_rounded),
              title: Text('محادثة', style: defaultText),
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        ConversationView(
                      name: user['full_name'],
                      id: user['id'],
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
            ),
          ),
          Divider(),
          Card(
            color: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0.5,
            child: ListTile(
              trailing: const Icon(Icons.text_snippet_rounded),
              title: Text('عرض المنشورات', style: defaultText),
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        ChangeNotifierProvider(
                      create: (context) =>
                          Renderer(fetcher: Fetcher(pb: user.pb), pb: user.pb),
                      child: ChangeNotifierProvider(
                          create: (context) => Renderer(
                              fetcher: Fetcher(pb: provider.pb),
                              pb: provider.pb),
                          child: UserPosts(id: id)),
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
            ),
          ),
          //TODO HERE
        ],
      ),
    );

    return widget;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        child: FutureBuilder(
          future: getUser(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                children: [
                  Center(child: shimmer),
                ],
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error,
                      color: Colors.black,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Text(
                        'نعتذر، حدث خطأ ما\nالرجاء المحاولة في وقت لاحق',
                        style: defaultText,
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              );
            }
            if (snapshot.hasData) {
              var data = snapshot.data;
              return data!;
            } else {
              return shimmer;
            }
          },
        ),
      ),
    );
  }
}

class UserPosts extends StatefulWidget {
  final id;
  const UserPosts({super.key, required this.id});

  @override
  State<UserPosts> createState() => _UserPostsState();
}

class _UserPostsState extends State<UserPosts> {
  late Renderer _renderer;
  ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  List<Widget> _allPosts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        loadPosts();
      }
    });

    loadPosts();
  }

  void addPosts(List<Widget> newPosts) {
    setState(() {
      _allPosts.clear();
      _allPosts.addAll(newPosts);
      _isLoading = false;
    });
  }

  void loadPosts() {
    final user = Provider.of<User>(context, listen: false);
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
      Renderer renderer = Provider.of<Renderer>(context, listen: false);
      renderer.renderPosts(
          context, user, _currentPage, 7, 'profilePosts', widget.id, false);
      _currentPage++;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshPosts() async {
    _currentPage = 1;
    loadPosts();
    _allPosts.clear();
  }

  @override
  Widget build(BuildContext context) {
    Renderer renderer = Provider.of<Renderer>(context);
    renderer.postsStream.listen((newPosts) {
      addPosts(newPosts);
    });
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
      ),
      body: RefreshIndicator(
        color: greenColor,
        onRefresh: _refreshPosts,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return StreamBuilder<List<Widget>>(
              stream: renderer.postsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: shimmer);
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  return SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    controller: _scrollController,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_allPosts.isEmpty && !_isLoading)
                            Center(
                                child: Text('لا يوجد منشورات',
                                    style: defaultText)),
                          Column(
                            children: _allPosts,
                          ),
                          if (_isLoading) Center(child: shimmer)
                        ],
                      ),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}
