import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:qalam/Pages/fetchers.dart';
import 'package:qalam/Pages/renderers.dart';
import 'package:qalam/styles.dart';
import 'package:qalam/user_data.dart';

class ViewPosts extends StatefulWidget {
  const ViewPosts({super.key});

  @override
  State<ViewPosts> createState() => _ViewPostsState();
}

class _ViewPostsState extends State<ViewPosts> {
  bool bannerState = false;

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User>(context);
    return DefaultTabController(
      initialIndex: 0,
      length: 2,
      child: Scaffold(
          appBar: AppBar(
              primary: false,
              automaticallyImplyLeading: false,
              title: TabBar(
                dividerHeight: 0,
                dividerColor: Colors.white,
                overlayColor: MaterialStatePropertyAll(Colors.white),
                labelColor: greenColor,
                indicatorColor: Colors.white,
                unselectedLabelColor: blackColor,
                tabs: const <Widget>[
                  Tab(icon: Icon(Icons.public)),
                  Tab(icon: Icon(Icons.people)),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.filter_alt),
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            ChangeNotifierProvider(
                          create: (context) => Renderer(
                              fetcher: Fetcher(pb: user.pb), pb: user.pb),
                          child: FilterPosts(user: user),
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
              ]),
          body: TabBarView(
            children: [
              ChangeNotifierProvider(
                create: (context) =>
                    Renderer(fetcher: Fetcher(pb: user.pb), pb: user.pb),
                child: PublicPosts(user: user),
              ),
              ChangeNotifierProvider(
                create: (context) =>
                    Renderer(fetcher: Fetcher(pb: user.pb), pb: user.pb),
                child: FriendsPosts(user: user),
              ),
            ],
          )),
    );
  }
}

class PublicPosts extends StatefulWidget {
  final User user;
  const PublicPosts({super.key, required this.user});

  @override
  State<PublicPosts> createState() => _PublicPostsState();
}

class _PublicPostsState extends State<PublicPosts>
    with AutomaticKeepAliveClientMixin {
  ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  List<Widget> _allPosts = [];
  bool _isLoading = false;
  bool refresh = false;
  bool get wantKeepAlive => true;

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

  Future loadPosts() async {
    Renderer renderer = Provider.of<Renderer>(context, listen: false);
    renderer.renderPosts(
        context, widget.user, _currentPage, 7, 'publicAll', 'id', refresh);
    if (refresh) {
      refresh = false;
    }
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
      _currentPage++;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshPosts() async {
    _allPosts.clear();
    _currentPage = 1;
    refresh = true;
    await loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Renderer renderer = Provider.of<Renderer>(context);
    renderer.postsStream.listen((newPosts) {
      addPosts(newPosts);
    });
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: "PublicPosts",
        backgroundColor: Colors.black,
        focusColor: Colors.grey.shade500,
        hoverColor: Colors.black,
        onPressed: () {
          showBottomSheet(
              context: context,
              builder: (context) {
                return CreatePost();
              });
        },
        child: SvgPicture.asset('assets/quill.svg', color: Colors.white),
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

class FriendsPosts extends StatefulWidget {
  final User user;

  const FriendsPosts({super.key, required this.user});

  @override
  State<FriendsPosts> createState() => _FriendsPostsState();
}

class _FriendsPostsState extends State<FriendsPosts>
    with AutomaticKeepAliveClientMixin {
  ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  List<Widget> _allPosts = [];
  bool _isLoading = false;
  bool refresh = false;
  bool get wantKeepAlive => true;

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

  Future loadPosts() async {
    Renderer renderer = Provider.of<Renderer>(context, listen: false);
    renderer.renderPosts(
        context, widget.user, _currentPage, 7, 'friends', 'id', refresh);
    if (refresh) {
      refresh = false;
    }
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
      _currentPage++;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshPosts() async {
    _allPosts.clear();
    _currentPage = 1;
    refresh = true;
    await loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Renderer renderer = Provider.of<Renderer>(context);
    renderer.postsStream.listen((newPosts) {
      addPosts(newPosts);
    });
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: "FriendPosts",
        backgroundColor: Colors.black,
        focusColor: Colors.grey.shade500,
        hoverColor: Colors.black,
        onPressed: () {
          showBottomSheet(
              context: context,
              builder: (context) {
                return CreatePost();
              });
        },
        child: SvgPicture.asset('assets/quill.svg', color: Colors.white),
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

class FilterPosts extends StatefulWidget {
  final User user;

  const FilterPosts({super.key, required this.user});

  @override
  State<FilterPosts> createState() => _FilterPostsState();
}

class _FilterPostsState extends State<FilterPosts> {
  ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  List<Widget> _allPosts = [];
  bool _isLoading = false;
  bool refresh = false;
  String? timeRange = 'all';
  bool isVisible = false;

  @override
  void initState() {
    super.initState();
    _allPosts = [];
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        loadPosts();
      }
    });
  }

  void addPosts(List<Widget> newPosts) {
    setState(() {
      _allPosts.clear();
      _allPosts.addAll(newPosts);
      _isLoading = false;
    });
  }

  Future loadPosts() async {
    Renderer renderer = Provider.of<Renderer>(context, listen: false);
    renderer.renderPosts(
        context, widget.user, _currentPage, 7, 'filter', timeRange, refresh);
    if (refresh) {
      refresh = false;
    }
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
      _currentPage++;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshPosts() async {
    _allPosts.clear();
    _currentPage = 1;
    refresh = true;
    await loadPosts();
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
        title: Text(
          'المنشورات الأعلى تصنيفاً',
          textDirection: TextDirection.rtl,
          style: defaultText,
          textScaler: TextScaler.linear(0.75),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            controller: _scrollController,
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 5.0),
                              child: CupertinoSlidingSegmentedControl<String>(
                                children: const {
                                  'today': Text('اليوم'),
                                  'week': Text('هذا الأسبوع'),
                                  'month': Text('هذا الشهر'),
                                  'year': Text('هذا العام'),
                                  'all': Text('كل الأوقات'),
                                },
                                onValueChanged: (String? value) {
                                  setState(() {
                                    timeRange = value!;
                                  });
                                },
                                groupValue:
                                    timeRange, // Your time range variable
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: FilledButton(
                            style: FilledButtonStyle,
                            onPressed: () async {
                              setState(() {
                                isVisible = true;
                              });
                              _allPosts.clear();
                              await loadPosts();
                            },
                            child: const Text('متابعة')),
                      ),
                    ],
                  ),
                ),
                Visibility(
                  visible: isVisible,
                  child: StreamBuilder<List<Widget>>(
                    stream: renderer.postsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: shimmer);
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else {
                        return ConstrainedBox(
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
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
