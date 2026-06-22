import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool isRemoteImagePath(String path) {
  final uri = Uri.tryParse(path);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

bool isAssetImagePath(String path) {
  return path.startsWith('assets/');
}

bool hasDisplayableImagePath(String? path) {
  if (path == null || path.trim().isEmpty) return false;
  if (isRemoteImagePath(path) || isAssetImagePath(path)) return true;
  if (kIsWeb) return false;
  return File(path).existsSync();
}

ImageProvider imageProviderFromPath(String path) {
  if (isRemoteImagePath(path)) return NetworkImage(path);
  if (isAssetImagePath(path)) return AssetImage(path);
  if (kIsWeb) return const AssetImage('assets/images/app/logoAppDnd.png');
  return FileImage(File(path));
}

Widget buildImageFromPath(
  String path, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
  FilterQuality filterQuality = FilterQuality.high,
}) {
  if (isRemoteImagePath(path)) {
    return Image.network(
      path,
      width: width,
      height: height,
      fit: fit,
      filterQuality: filterQuality,
    );
  }

  if (isAssetImagePath(path)) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      filterQuality: filterQuality,
    );
  }

  if (kIsWeb) {
    return SizedBox(width: width, height: height);
  }

  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    filterQuality: filterQuality,
  );
}
