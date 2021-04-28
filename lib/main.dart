import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: HomePage(),
    );
  }
}

class FileInfo {
  final String assetName;
  final int size;

  const FileInfo({required this.assetName, required this.size});
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var isLoad = false;

  final files = <FileInfo>[];

  final controllers = <String, VideoPlayerController>{};
  VideoPlayerController? currentController;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      final manifestString = await rootBundle.loadString('AssetManifest.json');
      final map = json.decode(manifestString) as Map<String, dynamic>;
      final assets = map.keys.where((e) => e.startsWith('assets')).toList();

      final end = <FileInfo>[];

      for (final asset in assets) {
        final byteData = await rootBundle.load(asset);
        final length = byteData.lengthInBytes;

        if (asset.endsWith('a64.mp4')) {
          end.add(FileInfo(assetName: asset, size: length));
        } else {
          files.add(FileInfo(assetName: asset, size: length));
        }
      }

      files.addAll(end);

      setState(() {
        isLoad = true;
      });
    });
  }

  Future<void> _onPressed(FileInfo e) async {
    if (currentController != null) {
      currentController!.pause();

      final cc = currentController;
      setState(() {
        currentController = null;
      });

      controllers.remove(e.assetName);

      SchedulerBinding.instance?.addPostFrameCallback((timeStamp) {
        cc?.dispose();
      });
    }

    if (!controllers.containsKey(e.assetName)) {
      final controller = VideoPlayerController.asset(e.assetName);

      controller.initialize().then((_) {
        controller.setVolume(1);
        controller.setLooping(true);
        controller.play();
        setState(() {});
      });

      controllers[e.assetName] = controller;
    } else {
      controllers[e.assetName]!.seekTo(Duration.zero);
      controllers[e.assetName]!.play();
    }

    setState(() {
      currentController = controllers[e.assetName];
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (!isLoad) {
      body = Center(child: const CircularProgressIndicator());
    } else {
      body = Stack(
        fit: StackFit.expand,
        children: [
          if (currentController != null && currentController!.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: Container(
                width: currentController!.value.size.width,
                height: currentController!.value.size.height,
                child: VideoPlayer(currentController!),
              ),
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: files.map((e) {
                final fn = e.assetName.split('/').last.split('.').first;
                final l = e.size / 1024 / 1024;
                final name = '$fn ${l.toStringAsFixed(1)}MB';
                return TextButton(onPressed: () => _onPressed(e), child: Text(name));
              }).toList(),
            ),
          ),
        ],
      );
    }
    return Scaffold(extendBody: true, body: body);
  }
}
