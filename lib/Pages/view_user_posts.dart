import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qalam/styles.dart';
import 'renderers.dart';
import '../user_data.dart';

class ViewUserPosts extends StatefulWidget {
  final User user;

  const ViewUserPosts({super.key, required this.user});

  @override
  State<ViewUserPosts> createState() => _ViewUserPostsState();
}

class _ViewUserPostsState extends State<ViewUserPosts> {
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
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
      Renderer renderer = Provider.of<Renderer>(context, listen: false);
      renderer.renderPosts(
          context, widget.user, _currentPage, 5, 'myPosts', 'id', false);
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
