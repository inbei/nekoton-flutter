import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:tuple/tuple.dart';

import '../../bindings.dart';
import '../../ffi_utils.dart';
import '../../transport/transport.dart';
import 'models/root_token_contract_details.dart';
import 'models/token_wallet_details.dart';

Future<Tuple2<TokenWalletDetails, RootTokenContractDetails>> getTokenWalletDetails({
  required Transport transport,
  required String tokenWallet,
}) async {
  final ptr = await transport.clonePtr();
  final transportType = transport.connectionData.type;

  final result = await executeAsync(
    (port) => bindings().get_token_wallet_details(
      port,
      ptr,
      transportType.index,
      tokenWallet.toNativeUtf8().cast<Int8>(),
    ),
  );

  final string = cStringToDart(result);
  final jsonList = jsonDecode(string) as List<Map<String, dynamic>>;
  final tokenWalletDetails = TokenWalletDetails.fromJson(jsonList.first);
  final rootContractDetails = RootTokenContractDetails.fromJson(jsonList.last);

  return Tuple2(tokenWalletDetails, rootContractDetails);
}