class SignedDocument {
  final String id;

  final String title;
  final String ownerName;
  final String moxId;

  final String createdAt;

  final String documentHash;
  final String digitalSignature;
  final String publicKey;

  final String originalFileName;

  SignedDocument({
    required this.id,
    required this.title,
    required this.ownerName,
    required this.moxId,
    required this.createdAt,
    required this.documentHash,
    required this.digitalSignature,
    required this.publicKey,
    required this.originalFileName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'ownerName': ownerName,
      'moxId': moxId,
      'createdAt': createdAt,
      'documentHash': documentHash,
      'digitalSignature': digitalSignature,
      'publicKey': publicKey,
      'originalFileName': originalFileName,
    };
  }

  factory SignedDocument.fromJson(Map<String, dynamic> json) {
    return SignedDocument(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      moxId: json['moxId']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      documentHash: json['documentHash']?.toString() ?? '',
      digitalSignature: json['digitalSignature']?.toString() ?? '',
      publicKey: json['publicKey']?.toString() ?? '',
      originalFileName: json['originalFileName']?.toString() ?? '',
    );
  }
}
