import 'dart:io';

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
  return File(path).existsSync();
}

ImageProvider imageProviderFromPath(String path) {
  if (isRemoteImagePath(path)) return NetworkImage(path);
  if (isAssetImagePath(path)) return AssetImage(path);
  return FileImage(File(path));
}

Widget buildImageFromPath(
  String path, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
}) {
  if (isRemoteImagePath(path)) {
    return Image.network(
      path,
      width: width,
      height: height,
      fit: fit,
    );
  }

  if (isAssetImagePath(path)) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
    );
  }

  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
  );
}
