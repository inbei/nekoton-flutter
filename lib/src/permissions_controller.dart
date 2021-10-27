import 'dart:async';

import 'approval_controller.dart';
import 'models/nekoton_exception.dart';
import 'preferences.dart';
import 'provider/models/permission.dart';
import 'provider/models/permissions.dart';
import 'provider/models/permissions_changed_event.dart';
import 'provider/provider_events.dart';

class PermissionsController {
  static PermissionsController? _instance;
  final _approvalController = ApprovalController.instance();
  late final Preferences _preferences;

  PermissionsController._();

  static Future<PermissionsController> getInstance() async {
    if (_instance == null) {
      final instance = PermissionsController._();
      await instance._initialize();
      _instance = instance;
    }

    return _instance!;
  }

  Future<Permissions> requestPermissions({
    required String origin,
    required List<Permission> permissions,
  }) async {
    late Permissions requested;

    try {
      requested = await checkPermissions(
        origin: origin,
        requiredPermissions: permissions,
      );
    } catch (_) {
      requested = await _approvalController.requestApprovalForPermissions(
        origin: origin,
        permissions: permissions,
      );

      await _preferences.setPermissions(
        origin: origin,
        permissions: requested,
      );
    }

    permissionsChangedSubject.add(PermissionsChangedEvent(permissions: requested));

    return requested;
  }

  Future<void> removeOrigin(String origin) async {
    await _preferences.deletePermissions(origin);

    permissionsChangedSubject.add(const PermissionsChangedEvent(permissions: Permissions()));
  }

  Future<void> deletePermissionsForAccount(String address) async {
    await _preferences.deletePermissionsForAccount(address);
  }

  Permissions getPermissions(String origin) => _preferences.getPermissions(origin);

  Future<Permissions> checkPermissions({
    required String origin,
    required List<Permission> requiredPermissions,
  }) async {
    final permissions = getPermissions(origin);

    for (final requiredPermission in requiredPermissions) {
      switch (requiredPermission) {
        case Permission.tonClient:
          if (permissions.tonClient == null || permissions.tonClient == false) {
            throw PermissionsNotGrantedException();
          }
          break;
        case Permission.accountInteraction:
          if (permissions.accountInteraction == null) {
            throw PermissionsNotGrantedException();
          }
          break;
      }
    }

    return permissions;
  }

  Future<void> _initialize() async {
    _preferences = await Preferences.getInstance();
  }
}
