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
  Icon filterIcon = Icon(Icons.filter_alt);

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
          ),
          body: TabBarView(
            children: [
              PublicPosts(user: user),
              Center(
                child: Text('Friends'),
              )
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
  late Renderer _renderer;
  ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  List<Widget> _allPosts = [];
  bool _isLoading = false;
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _renderer =
        Renderer(fetcher: Fetcher(pb: widget.user.pb), pb: widget.user.pb);
    _renderer.postsStream.listen((newPosts) {
      addPosts(newPosts);
    });

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
      _allPosts.addAll(newPosts);
      _isLoading = false;
    });
  }

  void loadPosts() {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
      _renderer.renderPosts(context, widget.user, _currentPage, 7, 'publicAll');
      _currentPage++;
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
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
    super.build(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        focusColor: Colors.grey.shade500,
        hoverColor: Colors.black,
        onPressed: () {},
        child: SvgPicture.asset('assets/quill.svg', color: Colors.white),
      ),
      body: RefreshIndicator(
        color: greenColor,
        onRefresh: _refreshPosts,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return StreamBuilder<List<Widget>>(
              stream: _renderer.postsStream,
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
