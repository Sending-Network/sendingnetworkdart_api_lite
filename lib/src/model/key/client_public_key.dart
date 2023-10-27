class ClientPublicKey {
  String? publicKey;
  String? keyType;

  ClientPublicKey({this.publicKey, this.keyType});

  ClientPublicKey.fromJson(Map<String, Object?> json)
      : publicKey = json['publicKey'] as String?,
        keyType = json['keyType'] as String?;

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    if (keyType != null) data['keyType'] = keyType;
    if (publicKey != null) data['publicKey'] = publicKey;
    return data;
  }
}
