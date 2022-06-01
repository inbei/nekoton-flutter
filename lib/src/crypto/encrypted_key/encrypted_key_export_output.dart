import 'package:freezed_annotation/freezed_annotation.dart';

import '../mnemonic/models/mnemonic_type.dart';
import '../models/export_key_output.dart';

part 'encrypted_key_export_output.freezed.dart';
part 'encrypted_key_export_output.g.dart';

@freezed
class EncryptedKeyExportOutput with _$EncryptedKeyExportOutput implements ExportKeyOutput {
  @JsonSerializable(
    fieldRename: FieldRename.snake,
    explicitToJson: true,
  )
  const factory EncryptedKeyExportOutput({
    required String phrase,
    required MnemonicType mnemonicType,
  }) = _EncryptedKeyExportOutput;

  factory EncryptedKeyExportOutput.fromJson(Map<String, dynamic> json) => _$EncryptedKeyExportOutputFromJson(json);
}