import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qalam/styles.dart';
import 'fetchers.dart';
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
      _renderer.renderPosts(context, widget.user, _currentPage, 7, 'myPosts');
      _currentPage++;
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
      ),
      body: StreamBuilder<List<Widget>>(
        stream: _renderer.postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: shimmer);
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            return SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_allPosts.isEmpty)
                    Center(child: Text('لا يوجد منشورات', style: defaultText)),
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
    );
  }
}
