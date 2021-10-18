import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:nekoton_flutter/nekoton_flutter.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Plugin example app'),
          ),
          body: Center(
            child: RaisedButton(
              child: const Text('PRESS ME'),
              onPressed: () async {
                final instance = await Nekoton.getInstance();

                final wallet = await instance.subscriptionsController.subscribeToGenericContract(
                  origin: "origin",
                  address: "0:f35f602c47bf42c3e292262023aa7e71a53e604fdf6bf42be4bf6dd9ab8e04c3",
                );

                wallet.onTransactionsFoundStream.listen((event) {
                  if (event.lastOrNull?.prevTransactionId != null) {
                    wallet.preloadTransactions(event.lastOrNull!.prevTransactionId!);
                  }
                });
              },
            ),
          ),
        ),
      );
}
