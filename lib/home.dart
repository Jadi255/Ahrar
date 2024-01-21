import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qalam/Pages/cache.dart';
import 'package:qalam/Pages/chats.dart';
import 'package:qalam/Pages/fetchers.dart';
import 'package:qalam/Pages/homepage_posts.dart';
import 'package:qalam/Pages/my_profile.dart';
import 'package:qalam/Pages/notifications.dart';
import 'package:qalam/Pages/search.dart';
import 'package:qalam/Pages/topics.dart';
import 'package:qalam/styles.dart';
import 'package:qalam/user_data.dart';
import 'package:side_navigation/side_navigation.dart';
import 'package:url_launcher/url_launcher.dart';

int buildNo = 24010021;

class Home extends StatefulWidget {
  final AuthService authService;
  const Home({super.key, required this.authService});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    const breakpoint = 640.0; // You can adjust this value
    // Get the current screen width
    double screenWidth = MediaQuery.of(context).size.width;
    print(screenWidth);

    // Determine if we are on a mobile device or tablet/desktop based on the breakpoint
    bool isMobile = screenWidth <= breakpoint;

    return isMobile
        ? MobileView(
            authService: widget.authService,
          )
        : DesktopView();
  }
}

class MobileView extends StatefulWidget {
  final AuthService authService;

  const MobileView({super.key, required this.authService});

  @override
  State<MobileView> createState() => _MobileViewState();
}

class _MobileViewState extends State<MobileView>
    with AutomaticKeepAliveClientMixin {
  int _currentIndex = 0;
  final _pageController = PageController();
  var initConnectivityState;
  bool get wantKeepAlive => true;

  final List<Widget> _children = [
    const ViewPosts(),
    const AllConversations(desktop: false),
    const Topics(),
    MyProfile(
      isLeading: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await getAlerts();
      if (kIsWeb) {
        final user = Provider.of<User>(context, listen: false);
        if (user.fullName == "") {
          context.go('/');
        }
      } else {
        await checkUpdates();
      }
    });
    getInitConnectivity();
    messagesSubscriber();
    getMessages();
  }

  Future getAlerts() async {
    final user = Provider.of<User>(context, listen: false);
    var fetcher = Fetcher(pb: user.pb);
    var request = await fetcher.getAlerts(user.id);
    for (var i = 0; i < request.length; i++) {
      var alert = await request[i]!.toJson();
      String id = alert['id'];
      String alertText = alert['alert'];
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.black,
                  iconColor: Colors.black,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        alert['title'],
                        textScaler: TextScaler.linear(0.75),
                      ),
                    ],
                  ),
                  content: Padding(
                    padding: EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [Text(alertText)],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () {
                          user.pb
                              .collection('alerts')
                              .update(id, body: {"seen": true});
                          Navigator.of(context).pop();
                        },
                        child: Text('تم'),
                        style: TextButtonStyle)
                  ]),
            );
          });
    }
  }

  void getMessages() async {
    if (!mounted) return;

    CacheManager().clearMessages();
    final user = Provider.of<User>(context, listen: false);
    final fetcher = Fetcher(pb: user.pb);
    final messages = await fetcher.fetchMessages(user.id);
    final cacheManager = CacheManager();
    if (messages.length == 0) {
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
    }
  }

  void showBuildVer() {
    showDialog(
        barrierDismissible: true,
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.black,
            iconColor: Colors.black,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'معلومات الإصدار',
                  textScaler: TextScaler.linear(0.75),
                ),
              ],
            ),
            content: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                  textDirection: TextDirection.rtl,
                  'إصدار رقم $buildNo\n\nتصميم جهاد ناصرالدين (C) ${DateTime.now().year}'),
            ),
          );
        });
  }

  void messagesSubscriber() async {
    final user = Provider.of<User>(context, listen: false);
    if (!kIsWeb) {
      await user.pb.collection('notifications').subscribe(
        '*',
        (e) async {
          getMessages();
        },
      );
    } else if (kIsWeb) {
      Timer.periodic(
        Duration(seconds: 30),
        (timer) async {
          try {
            getMessages();
          } catch (e) {
            print(e);
          }
        },
      );
    }
  }

  Future<void> getInitConnectivity() async {
    initConnectivityState = await Connectivity().checkConnectivity();
  }

  void authRefresh() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.authRefresh();
  }

  Stream<ConnectivityResult> connectivityStream() async* {
    final Connectivity connectivity = Connectivity();
    await for (ConnectivityResult result
        in connectivity.onConnectivityChanged) {
      if (result != initConnectivityState) {
        initConnectivityState = result;
        yield result;
      }
    }
  }

  void onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future checkUpdates() async {
    final user = Provider.of<User>(context, listen: false);
    var request = await user.pb
        .collection('version_control')
        .getFullList(filter: 'latest = true');

    if (request.isNotEmpty) {
      var response = request[0].toJson();
      if (response['build'] <= buildNo) {
        return;
      }
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            return AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.black,
                iconColor: Colors.black,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'يوجد تحديث جديد',
                      style: defaultText,
                      textScaler: TextScaler.linear(0.75),
                    ),
                  ],
                ),
                content: Padding(
                  padding: EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Text(
                          'تم إطلاق نسخة محدثة من تطبيق قلم. هل ترغب بتحمليها الآن؟',
                          textDirection: TextDirection.rtl,
                        )
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('لا'),
                      style: TextButtonStyle),
                  TextButton(
                      onPressed: () async {
                        await launchUrl(Uri.parse(response['repo']));
                      },
                      child: Text('نعم'),
                      style: TextButtonStyle),
                ]);
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var user = Provider.of<User>(context);
    authRefresh();
    connectivityStream().listen((event) {
      if (event == ConnectivityResult.none) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.wifi_off,
                  color: Colors.white,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text('أنت غير متصل بالإنترنت'),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.wifi,
                  color: Colors.white,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text('عاد الإتصال'),
                ),
              ],
            ),
          ),
        );
      }
    });

    user.realTime();
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: GestureDetector(
            onTap: () {
              showBuildVer();
            },
            child: coloredLogo,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: CircleAvatar(
                  backgroundColor: Colors.grey.shade100,
                  foregroundImage: user.avatar,
                  backgroundImage: Image.asset('assets/placeholder.jpg').image,
                  radius: 15),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        SearchMenu(),
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
              icon: const Icon(Icons.search),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 5.0),
              child: NotificationBell(desktop: false),
            ),
          ],
        ),
        body: PageView(
          controller: _pageController,
          children: _children,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          onTap: onTabTapped,
          currentIndex: _currentIndex,
          selectedItemColor: greenColor,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "الرئيسية",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message_rounded),
              label: "محادثات",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tag),
              label: "مواضيع",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: "صفحتي",
            )
          ],
        ),
      ),
    );
  }
}

class DesktopView extends StatefulWidget {
  const DesktopView({super.key});

  @override
  State<DesktopView> createState() => _DesktopViewState();
}

class _DesktopViewState extends State<DesktopView>
    with AutomaticKeepAliveClientMixin {
  var initConnectivityState;
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await getAlerts();
      if (kIsWeb) {
        final user = Provider.of<User>(context, listen: false);
        if (user.fullName == "") {
          context.go('/');
        }
      }
    });
    getInitConnectivity();
    messagesSubscriber();
    getMessages();
  }

  Future getAlerts() async {
    final user = Provider.of<User>(context, listen: false);
    var fetcher = Fetcher(pb: user.pb);
    var request = await fetcher.getAlerts(user.id);
    for (var i = 0; i < request.length; i++) {
      var alert = await request[i]!.toJson();
      String id = alert['id'];
      String alertText = alert['alert'];
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.black,
                  iconColor: Colors.black,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        alert['title'],
                        textScaler: TextScaler.linear(0.75),
                      ),
                    ],
                  ),
                  content: Padding(
                    padding: EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [Text(alertText)],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () {
                          user.pb
                              .collection('alerts')
                              .update(id, body: {"seen": true});
                          Navigator.of(context).pop();
                        },
                        child: Text('تم'),
                        style: TextButtonStyle)
                  ]),
            );
          });
    }
  }

  void getMessages() async {
    if (!mounted) return;

    CacheManager().clearMessages();
    final user = Provider.of<User>(context, listen: false);
    final fetcher = Fetcher(pb: user.pb);
    final messages = await fetcher.fetchMessages(user.id);
    final cacheManager = CacheManager();
    if (messages.length == 0) {
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
    }
  }

  void showBuildVer() {
    showDialog(
        barrierDismissible: true,
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.black,
            iconColor: Colors.black,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'معلومات الإصدار',
                  textScaler: TextScaler.linear(0.75),
                ),
              ],
            ),
            content: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                  textDirection: TextDirection.rtl,
                  'إصدار رقم $buildNo\n\nتصميم جهاد ناصرالدين (C) ${DateTime.now().year}'),
            ),
          );
        });
  }

  void messagesSubscriber() async {
    final user = Provider.of<User>(context, listen: false);
    if (!kIsWeb) {
      await user.pb.collection('notifications').subscribe(
        '*',
        (e) async {
          getMessages();
        },
      );
    } else if (kIsWeb) {
      Timer.periodic(
        Duration(seconds: 30),
        (timer) async {
          try {
            getMessages();
          } catch (e) {
            print(e);
          }
        },
      );
    }
  }

  Future<void> getInitConnectivity() async {
    initConnectivityState = await Connectivity().checkConnectivity();
  }

  void authRefresh() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.authRefresh();
  }

  Widget childView = ViewPosts();

  Stream<ConnectivityResult> connectivityStream() async* {
    final Connectivity connectivity = Connectivity();
    await for (ConnectivityResult result
        in connectivity.onConnectivityChanged) {
      if (result != initConnectivityState) {
        initConnectivityState = result;
        yield result;
      }
    }
  }

  List<SideNavigationBarItem> SideNavButtons = const [
    SideNavigationBarItem(
      icon: Icons.home,
      label: "الرئيسية",
    ),
    SideNavigationBarItem(
      icon: Icons.search,
      label: "بحث",
    ),
    SideNavigationBarItem(
      icon: Icons.tag,
      label: "مواضيع",
    ),
    SideNavigationBarItem(
      icon: Icons.person,
      label: "صفحتي",
    ),
  ];

  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var user = Provider.of<User>(context);
    authRefresh();
    connectivityStream().listen((event) {
      if (event == ConnectivityResult.none) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.wifi_off,
                  color: Colors.white,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text('أنت غير متصل بالإنترنت'),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.wifi,
                  color: Colors.white,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text('عاد الإتصال'),
                ),
              ],
            ),
          ),
        );
      }
    });

    user.realTime();
    var sidebarLeft = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: GestureDetector(
            onTap: () {
              showImage(context, user.avatar);
            },
            child: CircleAvatar(
              radius: 45,
              backgroundColor: Colors.grey.shade100,
              foregroundImage: user.avatar,
              backgroundImage: Image.asset('assets/placeholder.jpg').image,
            ),
          ),
        ),
        ListTile(
          onTap: () {
            setState(() {
              childView = MyProfile(isLeading: false);
              selectedIndex = 3;
            });
          },
          title: Text(
            style: defaultText,
            user.fullName,
            textAlign: TextAlign.center,
            textScaler: TextScaler.linear(1.25),
          ),
          subtitle: Text(
            style: defaultText,
            user.bio,
            textAlign: TextAlign.center,
          ),
        ),
        Divider(),
        Container(
          height: 500,
          child: SideNavigationBar(
            theme: SideNavigationBarTheme(
              itemTheme: SideNavigationBarItemTheme(
                selectedItemColor: greenColor,
              ),
              togglerTheme: SideNavigationBarTogglerTheme(),
              dividerTheme: SideNavigationBarDividerTheme(
                showHeaderDivider: true,
                showFooterDivider: false,
                showMainDivider: false,
              ),
            ),
            expandable: false,
            initiallyExpanded: true,
            selectedIndex: selectedIndex,
            items: SideNavButtons,
            onTap: (index) {
              setState(() {
                switch (index) {
                  case 0:
                    childView = ViewPosts();
                    break;
                  case 1:
                    childView = SearchMenu();
                  case 2:
                    childView = Topics();
                  case 3:
                    childView = MyProfile(isLeading: false);
                }
                selectedIndex = index;
              });
            },
          ),
        ),
      ],
    );

    var sidebarRight = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: NotificationBell(desktop: true),
        ),
        Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 5),
          child: ExpansionTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('المحادثات', style: defaultText),
              ],
            ),
            children: [
              Container(
                height: MediaQuery.of(context).size.height / 2.5,
                child: AllConversations(desktop: true),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: GestureDetector(
          onTap: () {
            showBuildVer();
          },
          child: coloredLogo,
        ),
      ),
      body: Row(
        children: [
          Flexible(
            flex: 2,
            child: SingleChildScrollView(child: sidebarLeft),
          ),
          Flexible(
            flex: 4,
            child: childView,
          ),
          Flexible(
            flex: 2,
            child: sidebarRight,
          ),
        ],
      ),
    );
  }
}
