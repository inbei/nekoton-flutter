import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:ffi/ffi.dart';
import 'package:rxdart/rxdart.dart';
import 'package:synchronized/synchronized.dart';

import '../../bindings.dart';
import '../../crypto/models/signed_message.dart';
import '../../ffi_utils.dart';
import '../../models/pointed.dart';
import '../../transport/transport.dart';
import '../contract_subscription/contract_subscription.dart';
import '../models/contract_state.dart';
import '../models/on_message_expired_payload.dart';
import '../models/on_message_sent_payload.dart';
import '../models/on_state_changed_payload.dart';
import '../models/on_transactions_found_payload.dart';
import '../models/pending_transaction.dart';
import '../models/polling_method.dart';
import '../models/transaction.dart';
import '../models/transaction_id.dart';
import 'models/transaction_execution_options.dart';

class GenericContract extends ContractSubscription implements Pointed {
  final _lock = Lock();
  Pointer<Void>? _ptr;
  final _onMessageSentPort = ReceivePort();
  final _onMessageExpiredPort = ReceivePort();
  final _onStateChangedPort = ReceivePort();
  final _onTransactionsFoundPort = ReceivePort();
  final _pendingTransactionsSubject = BehaviorSubject<List<PendingTransaction>>.seeded([]);
  late final Stream<OnMessageSentPayload> onMessageSentStream;
  late final Stream<OnMessageExpiredPayload> onMessageExpiredStream;
  late final Stream<OnStateChangedPayload> onStateChangedStream;
  late final Stream<OnTransactionsFoundPayload> onTransactionsFoundStream;
  late final Stream<List<PendingTransaction>> pendingTransactionsStream;
  @override
  late final Transport transport;
  final _addressMemo = AsyncMemoizer<String>();

  GenericContract._();

  static Future<GenericContract> subscribe({
    required Transport transport,
    required String address,
  }) async {
    final instance = GenericContract._();
    await instance._initialize(
      transport: transport,
      address: address,
    );
    return instance;
  }

  @override
  Future<String> get address => _addressMemo.runOnce(() async {
        final ptr = await clonePtr();

        final result = await executeAsync(
          (port) => NekotonFlutter.bindings.nt_generic_contract_address(
            port,
            ptr,
          ),
        );

        final address = cStringToDart(result);

        return address;
      });

  Future<ContractState> get contractState async {
    final ptr = await clonePtr();

    final result = await executeAsync(
      (port) => NekotonFlutter.bindings.nt_generic_contract_contract_state(
        port,
        ptr,
      ),
    );

    final string = cStringToDart(result);
    final json = jsonDecode(string) as Map<String, dynamic>;
    final contractState = ContractState.fromJson(json);

    return contractState;
  }

  Future<List<PendingTransaction>> get pendingTransactions async {
    final ptr = await clonePtr();

    final result = await executeAsync(
      (port) => NekotonFlutter.bindings.nt_generic_contract_pending_transactions(
        port,
        ptr,
      ),
    );

    final string = cStringToDart(result);
    final json = jsonDecode(string) as List<dynamic>;
    final list = json.cast<Map<String, dynamic>>();
    final pendingTransactions = list.map((e) => PendingTransaction.fromJson(e)).toList();

    return pendingTransactions;
  }

  @override
  Future<PollingMethod> get pollingMethod async {
    final ptr = await clonePtr();

    final result = await executeAsync(
      (port) => NekotonFlutter.bindings.nt_generic_contract_polling_method(
        port,
        ptr,
      ),
    );

    final string = cStringToDart(result);
    final json = jsonDecode(string) as String;
    final pollingMethod = pollingMethodFromEnumString(json);

    return pollingMethod;
  }

  Future<String> estimateFees(SignedMessage signedMessage) async {
    final ptr = await clonePtr();
    final signedMessageStr = jsonEncode(signedMessage);

    final result = await executeAsync(
      (port) => NekotonFlutter.bindings.nt_generic_contract_estimate_fees(
        port,
        ptr,
        signedMessageStr.toNativeUtf8().cast<Char>(),
      ),
    );

    final fees = cStringToDart(result);

    return fees;
  }

  Future<PendingTransaction> send(SignedMessage signedMessage) async {
    final ptr = await clonePtr();
    final signedMessageStr = jsonEncode(signedMessage);

    await prepareReliablePolling();

    final result = await executeAsync(
      (port) => NekotonFlutter.bindings.nt_generic_contract_send(
        port,
        ptr,
        signedMessageStr.toNativeUtf8().cast<Char>(),
      ),
    );

    skipRefreshTimer();

    final string = cStringToDart(result);
    final json = jsonDecode(string) as Map<String, dynamic>;
    final pendingTransaction = PendingTransaction.fromJson(json);

    _pendingTransactionsSubject.add(await pendingTransactions);

    return pendingTransaction;
  }

  Future<Transaction> executeTransactionLocally({
    required SignedMessage signedMessage,
    required TransactionExecutionOptions options,
  }) async {
    final ptr = await clonePtr();
    final signedMessageStr = jsonEncode(signedMessage);
    final optionsStr = jsonEncode(options);

    final result = await executeAsync(
      (port) => NekotonFlutter.bindings.nt_generic_contract_execute_transaction_locally(
        port,
        ptr,
        signedMessageStr.toNativeUtf8().cast<Char>(),
        optionsStr.toNativeUtf8().cast<Char>(),
      ),
    );

    final string = cStringToDart(result);
    final json = jsonDecode(string) as Map<String, dynamic>;
    final transaction = Transaction.fromJson(json);

    return transaction;
  }

  @override
  Future<void> refresh() async {
    final ptr = await clonePtr();

    await executeAsync(
      (port) => NekotonFlutter.bindings.nt_generic_contract_refresh(
        port,
        ptr,
      ),
    );

    _pendingTransactionsSubject.add(await pendingTransactions);
  }

  Future<void> preloadTransactions(TransactionId from) async {
    final ptr = await clonePtr();
    final fromStr = jsonEncode(from);

    await executeAsync(
      (port) => NekotonFlutter.bindings.nt_generic_contract_preload_transactions(
        port,
        ptr,
        fromStr.toNativeUtf8().cast<Char>(),
      ),
    );
  }

  @override
  Future<void> handleBlock(String block) async {
    final ptr = await clonePtr();

    await executeAsync(
      (port) => NekotonFlutter.bindings.nt_generic_contract_handle_block(
        port,
        ptr,
        block.toNativeUtf8().cast<Char>(),
      ),
    );

    _pendingTransactionsSubject.add(await pendingTransactions);
  }

  @override
  Future<Pointer<Void>> clonePtr() => _lock.synchronized(() {
        if (_ptr == null) throw Exception('Generic contract use after free');

        final ptr = NekotonFlutter.bindings.nt_generic_contract_clone_ptr(
          _ptr!,
        );

        return ptr;
      });

  @override
  Future<void> freePtr() => _lock.synchronized(() async {
        if (_ptr == null) return;

        _onMessageSentPort.close();
        _onMessageExpiredPort.close();
        _onStateChangedPort.close();
        _onTransactionsFoundPort.close();

        await pausePolling();

        NekotonFlutter.bindings.nt_generic_contract_free_ptr(
          _ptr!,
        );

        _ptr = null;
      });

  Future<void> _initialize({
    required Transport transport,
    required String address,
  }) =>
      _lock.synchronized(() async {
        this.transport = transport;

        onMessageSentStream = _onMessageSentPort.cast<String>().map((e) {
          final json = jsonDecode(e) as Map<String, dynamic>;
          final payload = OnMessageSentPayload.fromJson(json);
          return payload;
        }).asBroadcastStream();

        onMessageExpiredStream = _onMessageExpiredPort.cast<String>().map((e) {
          final json = jsonDecode(e) as Map<String, dynamic>;
          final payload = OnMessageExpiredPayload.fromJson(json);
          return payload;
        }).asBroadcastStream();

        onStateChangedStream = _onStateChangedPort.cast<String>().map((e) {
          final json = jsonDecode(e) as Map<String, dynamic>;
          final payload = OnStateChangedPayload.fromJson(json);
          return payload;
        }).asBroadcastStream();

        onTransactionsFoundStream = _onTransactionsFoundPort.cast<String>().map((e) {
          final json = jsonDecode(e) as Map<String, dynamic>;
          final payload = OnTransactionsFoundPayload.fromJson(json);
          return payload;
        }).asBroadcastStream();

        pendingTransactionsStream = _pendingTransactionsSubject;

        final transportPtr = await transport.clonePtr();
        final transportType = transport.connectionData.type;

        final result = await executeAsync(
          (port) => NekotonFlutter.bindings.nt_generic_contract_subscribe(
            port,
            _onMessageSentPort.sendPort.nativePort,
            _onMessageExpiredPort.sendPort.nativePort,
            _onStateChangedPort.sendPort.nativePort,
            _onTransactionsFoundPort.sendPort.nativePort,
            transportPtr,
            transportType.index,
            address.toNativeUtf8().cast<Char>(),
          ),
        );

        _ptr = Pointer.fromAddress(result).cast<Void>();

        await startPolling();
      });
}
