import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../../nekoton_flutter.dart';
import '../../bindings.dart';
import '../../ffi_utils.dart';

Future<ExistingWalletInfo> getExistingWalletInfo({
  required Transport transport,
  required String address,
}) async {
  final ptr = await transport.clonePtr();
  final transportType = transport.connectionData.type;

  final result = await executeAsync(
    (port) => bindings().get_existing_wallet_info(
      port,
      ptr,
      transportType.index,
      address.toNativeUtf8().cast<Int8>(),
    ),
  );

  final string = cStringToDart(result);
  final json = jsonDecode(string) as Map<String, dynamic>;
  final existingWalletInfo = ExistingWalletInfo.fromJson(json);

  return existingWalletInfo;
}