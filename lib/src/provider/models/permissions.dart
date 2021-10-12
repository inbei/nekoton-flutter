import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import 'account_interaction.dart';

part 'permissions.freezed.dart';
part 'permissions.g.dart';

@freezed
@HiveType(typeId: 223)
class Permissions with _$Permissions {
  @JsonSerializable(explicitToJson: true)
  const factory Permissions({
    @HiveField(0) @JsonKey(includeIfNull: false) bool? tonClient,
    @HiveField(1) @JsonKey(includeIfNull: false) AccountInteraction? accountInteraction,
  }) = _Permissions;

  factory Permissions.fromJson(Map<String, dynamic> json) => _$PermissionsFromJson(json);
}
