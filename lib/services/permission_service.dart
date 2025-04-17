import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Request SMS permission
  Future<bool> requestSmsPermission() async {
    var status = await Permission.sms.status;

    // If permission already granted
    if (status.isGranted) {
      return true;
    }

    // Request permission
    status = await Permission.sms.request();
    return status.isGranted;
  }
}