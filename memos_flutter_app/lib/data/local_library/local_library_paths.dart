import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/debug_ephemeral_storage.dart';

const _managedWorkspacesDirName = 'workspaces';
const _managedWebDavMirrorsDirName = 'webdav_mirrors';
const _managedLibraryDirName = 'library';

class ManagedWorkspacePathProbe {
  const ManagedWorkspacePathProbe({
    required this.workspacePath,
    required this.libraryPath,
    required this.workspaceExists,
    required this.libraryExists,
    required this.hasLibraryContent,
  });

  final String workspacePath;
  final String libraryPath;
  final bool workspaceExists;
  final bool libraryExists;
  final bool hasLibraryContent;

  bool get existsInCurrentContainer => workspaceExists || libraryExists;
}

Future<String> resolveManagedWorkspacePath(
  String workspaceKey, {
  bool create = true,
}) async {
  final root = await _managedWorkspacesRoot(create: create);
  final dir = Directory(
    p.join(root.path, _sanitizeSegment(workspaceKey), _managedLibraryDirName),
  );
  if (create && !await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir.path;
}

Future<ManagedWorkspacePathProbe> probeManagedWorkspacePath(
  String workspaceKey,
) async {
  final root = await _managedWorkspacesRoot(create: false);
  final workspaceDir = Directory(
    p.join(root.path, _sanitizeSegment(workspaceKey)),
  );
  final libraryDir = Directory(
    p.join(workspaceDir.path, _managedLibraryDirName),
  );
  final workspaceExists = await workspaceDir.exists();
  final libraryExists = await libraryDir.exists();
  return ManagedWorkspacePathProbe(
    workspacePath: workspaceDir.path,
    libraryPath: libraryDir.path,
    workspaceExists: workspaceExists,
    libraryExists: libraryExists,
    hasLibraryContent: libraryExists && await _hasAnyEntity(libraryDir),
  );
}

Future<String> resolveManagedWebDavMirrorPath(String accountHash) async {
  final root = await _managedWebDavMirrorsRoot();
  final dir = Directory(p.join(root.path, _sanitizeSegment(accountHash)));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir.path;
}

Future<void> ensureManagedWorkspaceStructure(String workspaceKey) async {
  await resolveManagedWorkspacePath(workspaceKey);
}

Future<Directory> _managedWorkspacesRoot({bool create = true}) async {
  final supportDir = await resolveAppSupportDirectory();
  final root = Directory(p.join(supportDir.path, _managedWorkspacesDirName));
  if (create && !await root.exists()) {
    await root.create(recursive: true);
  }
  return root;
}

Future<Directory> _managedWebDavMirrorsRoot() async {
  final supportDir = await resolveAppSupportDirectory();
  final root = Directory(p.join(supportDir.path, _managedWebDavMirrorsDirName));
  if (!await root.exists()) {
    await root.create(recursive: true);
  }
  return root;
}

String _sanitizeSegment(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'default';
  return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

Future<bool> _hasAnyEntity(Directory dir) async {
  try {
    await for (final _ in dir.list(followLinks: false)) {
      return true;
    }
  } catch (_) {
    return false;
  }
  return false;
}
