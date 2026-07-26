import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MiniAppViewer extends StatefulWidget {
  final String title;

  const MiniAppViewer({super.key, required this.title});

  @override
  State<MiniAppViewer> createState() => _MiniAppViewerState();
}

class _MiniAppViewerState extends State<MiniAppViewer> {
  late final WebViewController controller;
  bool isLoading = true;

  // الرابط الرسمي المعتمد
  final String allowedHost = "ao-almnzoma.blogspot.com";

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // السماح فقط بالنطاق المعتمد
            if (request.url.contains(allowedHost)) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageFinished: (url) => setState(() => isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse("https://$allowedHost"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // خلفية بيضاء نظيفة لمنع أي وميض أحمر
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF28A9CC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF28A9CC)),
            ),
        ],
      ),
    );
  }
}
