import 'package:flutter/material.dart';

class KeepAliveTab extends StatefulWidget {
  final Widget child;

  const KeepAliveTab({Key? key, required this.child}) : super(key: key);

  @override
  _KeepAliveTabState createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<KeepAliveTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}