import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:qalam/Pages/homepage_posts.dart';
import 'package:qalam/Pages/my_profile.dart';
import 'package:qalam/styles.dart';
import 'package:qalam/user_data.dart';

class Home extends StatefulWidget {
  final AuthService authService;
  Home({super.key, required this.authService});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentIndex = 0;
  final _pageController = PageController();
  var initConnectivityState;

  final List<Widget> _children = [
    const ViewPosts(),
    const Placeholder(),
    const Placeholder(),
    const MyProfile(),
  ];

  @override
  void initState() {
    super.initState();
    getInitConnectivity();
  }

  Future<void> getInitConnectivity() async {
    initConnectivityState = await Connectivity().checkConnectivity();
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

  @override
  Widget build(BuildContext context) {
    var user = Provider.of<User>(context);
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
          title: coloredLogo,
          actions: [
            IconButton(
              onPressed: () async {},
              icon: Icon(Icons.person_pin_rounded),
            ),
            IconButton(
              onPressed: () {
                showModalBottomSheet(
                    context: context,
                    builder: (context) => const Placeholder());
              },
              icon: const Icon(Icons.search),
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
