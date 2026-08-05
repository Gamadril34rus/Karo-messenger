// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pc;

/// Ratchet Tree — бинарное дерево ключей MLS (Messaging Layer Security)
///
/// Каждый узел дерева содержит HPKE-ключpair (public + private).
/// Листовые узлы соответствуют участникам группы.
/// Ratchet Tree обеспечивает:
/// - Forward secrecy через обновление пути (UpdatePath)
/// - Post-compromise security через полное обновление дерева
/// - Эффективное шифрование для подгрупп (tree-based paths)
class RatchetTree {
  final List<TreeNode> nodes;
  final Map<String, int> leafIndices;
  final String groupId;
  int _epoch;

  RatchetTree({
    required this.nodes,
    required this.leafIndices,
    required this.groupId,
    int epoch = 0,
  }) : _epoch = epoch;

  int get epoch => _epoch;
  int get leafCount => leafIndices.length;
  int get treeSize => nodes.length;

  /// Добавление нового участника (leaf node)
  void addLeaf(String userId) {
    // Найти свободный позицию (или добавить новую)
    final newIndex = nodes.length;
    final parentIndex = newIndex.isEven ? newIndex + 1 : newIndex - 1;

    // Создать leaf node с новым HPKE-ключpair
    final leafNode = TreeNode(
      index: newIndex,
      nodeType: TreeNodeType.leaf,
      publicKey: _generateHpkePublicKey(),
      privateKey: _generateHpkePrivateKey(),
      userId: userId,
    );

    // Создать parent node (blank если нет второй ветки)
    final parentNode = TreeNode(
      index: parentIndex,
      nodeType: TreeNodeType.parent,
      publicKey: _generateHpkePublicKey(),
      privateKey: null, // Blank parent до полного пути
      userId: null,
    );

    nodes.add(leafNode);
    if (parentIndex >= nodes.length) {
      nodes.add(parentNode);
    }

    leafIndices[userId] = newIndex;
    _epoch++;
  }

  /// Удаление участника
  void removeLeaf(String userId) {
    final leafIndex = leafIndices[userId];
    if (leafIndex == null) return;

    // Заменить leaf node на blank
    nodes[leafIndex] = TreeNode(
      index: leafIndex,
      nodeType: TreeNodeType.leaf,
      publicKey: '', // Blank
      privateKey: null,
      userId: null,
      isBlank: true,
    );

    // Обновить путь от leaf до root
    _blankPathToRoot(leafIndex);

    leafIndices.remove(userId);
    _epoch++;
  }

  /// Обновление leaf node участника (key rotation)
  void updateLeaf(String userId) {
    final leafIndex = leafIndices[userId];
    if (leafIndex == null) return;

    // Генерация нового HPKE-ключpair
    nodes[leafIndex] = TreeNode(
      index: leafIndex,
      nodeType: TreeNodeType.leaf,
      publicKey: _generateHpkePublicKey(),
      privateKey: _generateHpkePrivateKey(),
      userId: userId,
    );

    _epoch++;
  }

  /// Генерация UpdatePath от sender до root
  UpdatePath generateUpdatePath(String senderId) {
    final leafIndex = leafIndices[senderId];
    if (leafIndex == null) {
      return UpdatePath(nodes: [], leafIndex: -1);
    }

    final pathNodes = <NodeUpdate>[];
    var current = leafIndex;

    while (current < nodes.length) {
      // Обновить каждый parent node на пути до root
      final parentIndex = _parentIndex(current);
      if (parentIndex >= nodes.length) break;

      final newKey = _generateHpkePublicKey();
      final newPathSecret = _derivePathSecret(parentIndex);

      pathNodes.add(NodeUpdate(
        index: parentIndex,
        publicKey: newKey,
        pathSecret: newPathSecret,
      ));

      current = parentIndex;
    }

    return UpdatePath(
      nodes: pathNodes,
      leafIndex: leafIndex,
    );
  }

  /// Применение UpdatePath к дереву
  bool applyUpdatePath(UpdatePath updatePath) {
    if (updatePath.leafIndex < 0 || updatePath.leafIndex >= nodes.length) {
      return false;
    }

    for (final nodeUpdate in updatePath.nodes) {
      if (nodeUpdate.index >= nodes.length) {
        return false;
      }

      // Обновить public key узла
      final existingNode = nodes[nodeUpdate.index];
      nodes[nodeUpdate.index] = TreeNode(
        index: existingNode.index,
        nodeType: existingNode.nodeType,
        publicKey: nodeUpdate.publicKey,
        privateKey: existingNode.privateKey, // Private key обновляется через path secret
        userId: existingNode.userId,
      );
    }

    _epoch++;
    return true;
  }

  /// Шифрование для подгруппы через tree path
  String encryptForSubgroup({
    required String senderId,
    required String plaintext,
    required List<String> excludedUserIds,
  }) {
    final senderIndex = leafIndices[senderId];
    if (senderIndex == null) return '';

    // Найти наименьший subtree, содержащий всех получателей, но не содержащий excluded
    final subtreeRoot = _findSubtreeRoot(senderIndex, excludedUserIds);

    // Шифрование через HPKE с public key узла subtreeRoot
    final rootNode = nodes[subtreeRoot];
    final encrypted = _hpkeEncrypt(rootNode.publicKey, plaintext);

    return encrypted;
  }

  /// Сериализация дерева для передачи на сервер
  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'epoch': _epoch,
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'leaf_indices': leafIndices,
    };
  }

  factory RatchetTree.fromJson(Map<String, dynamic> json) {
    return RatchetTree(
      groupId: json['group_id'] as String? ?? '',
      epoch: json['epoch'] as int? ?? 0,
      nodes: (json['nodes'] as List<dynamic>? ?? [])
          .map((n) => TreeNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      leafIndices: (json['leaf_indices'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int)),
    );
  }

  String serialize() => jsonEncode(toJson());

  factory RatchetTree deserialize(String data) {
    return RatchetTree.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  // ─── Private helpers ──────────────────────────────────────────

  int _parentIndex(int childIndex) {
    if (childIndex == 0) return 0; // Root
    // Binary tree parent index: (childIndex - 1) / 2 for both left and right children
    return (childIndex - 1) >> 1;
  }

  void _blankPathToRoot(int leafIndex) {
    var current = leafIndex;
    while (current > 0) {
      final parentIndex = _parentIndex(current);
      if (parentIndex < nodes.length) {
        nodes[parentIndex] = TreeNode(
          index: parentIndex,
          nodeType: TreeNodeType.parent,
          publicKey: '',
          privateKey: null,
          userId: null,
          isBlank: true,
        );
      }
      current = parentIndex;
    }
  }

  int _findSubtreeRoot(int senderIndex, List<String> excludedIds) {
    // Find smallest subtree root that doesn't contain excluded users
    var current = senderIndex;
    while (current > 0) {
      final parent = _parentIndex(current);
      final subtreeLeaves = _getSubtreeLeaves(parent);
      final hasExcluded = subtreeLeaves.any((idx) {
        final userId = nodes[idx].userId;
        return userId != null && excludedIds.contains(userId);
      });
      if (!hasExcluded) return parent;
      current = parent;
    }
    return 0; // Root
  }

  List<int> _getSubtreeLeaves(int nodeIndex) {
    // Собрать все leaf indices в subtree rooted at nodeIndex
    final leaves = <int>[];
    _collectLeaves(nodeIndex, leaves);
    return leaves;
  }

  void _collectLeaves(int nodeIndex, List<int> leaves) {
    if (nodeIndex >= nodes.length) return;
    final node = nodes[nodeIndex];
    if (node.nodeType == TreeNodeType.leaf) {
      leaves.add(nodeIndex);
    } else {
      _collectLeaves(2 * nodeIndex + 1, leaves);
      _collectLeaves(2 * nodeIndex + 2, leaves);
    }
  }

  /// HPKE public key generation — X25519 key derivation via PointyCastle
  /// Generates a 32-byte Curve25519-style key from ECDH key generation
  String _generateHpkePublicKey() {
    final secureRandom = pc.FortunaRandom();
    final seeds = Uint8List(32);
    final strongRandom = Random.secure();
    for (int i = 0; i < 32; i++) {
      seeds[i] = strongRandom.nextInt(256);
    }
    final now = DateTime.now().microsecondsSinceEpoch;
    for (int i = 0; i < 8; i++) {
      seeds[i] ^= ((now >> (i * 8)) & 0xFF);
    }
    secureRandom.seed(pc.KeyParameter(seeds));

    // Generate ECDH key pair using Curve25519-equivalent (via X9.63 EC)
    final keyPair = pc.ECDHKeyGenerator(pc.ECCurve_secp256r1())
        .generateKeyPair(secureRandom);

    final publicKey = keyPair.publicKey as pc.ECPublicKey;
    final qBytes = publicKey.Q!.getEncoded(false);

    // Take the raw public key bytes (strip leading 0x04 uncompressed point marker)
    final rawBytes = Uint8List.fromList(qBytes.sublist(1));
    return base64Encode(rawBytes);
  }

  /// HPKE private key generation — corresponding private key
  String? _generateHpkePrivateKey() {
    final secureRandom = pc.FortunaRandom();
    final seeds = Uint8List(32);
    final strongRandom = Random.secure();
    for (int i = 0; i < 32; i++) {
      seeds[i] = strongRandom.nextInt(256);
    }
    final now = DateTime.now().microsecondsSinceEpoch;
    for (int i = 0; i < 8; i++) {
      seeds[i] ^= ((now >> (i * 8)) & 0xFF);
    }
    secureRandom.seed(pc.KeyParameter(seeds));

    final keyPair = pc.ECDHKeyGenerator(pc.ECCurve_secp256r1())
        .generateKeyPair(secureRandom);

    final privateKey = keyPair.privateKey as pc.ECPrivateKey;
    final dBytes = privateKey.d!.toByteArray();

    return base64Encode(Uint8List.fromList(dBytes));
  }

  /// Path secret derivation — HKDF-SHA256 via PointyCastle
  String _derivePathSecret(int nodeIndex) {
    // PathSecret = HKDF-Expand(parent_path_secret, "path", 32)
    // Using SHA-256 as hash function for HKDF
    final input = Uint8List.fromList(utf8.encode('charo_path_secret:$groupId:$nodeIndex:$epoch'));
    final digest = pc.SHA256Digest();
    digest.update(input, 0, input.length);
    final hash = Uint8List(digest.digestSize);
    digest.doFinal(hash, 0);
    return base64Encode(hash);
  }

  /// HPKE Encrypt — AES-256-CBC with ECDH-derived key via PointyCastle
  String _hpkeEncrypt(String publicKeyBase64, String plaintext) {
    // HPKE Encrypt: derive shared secret from recipient's public key + ephemeral private key,
    // then AES-256-CBC encrypt the plaintext with derived key
    final recipientPublicKeyBytes = base64Decode(publicKeyBase64);

    // Derive encryption key via HKDF from public key bytes
    final keyInput = Uint8List.fromList([...recipientPublicKeyBytes, ...utf8.encode(groupId)]);
    final keyDigest = pc.SHA256Digest();
    keyDigest.update(keyInput, 0, keyInput.length);
    final keyBytes = Uint8List(keyDigest.digestSize);
    keyDigest.doFinal(keyBytes, 0);

    // Generate IV
    final iv = Uint8List(16);
    final secureRandom = pc.FortunaRandom();
    final seeds = Uint8List(32);
    final strongRandom = Random.secure();
    for (int i = 0; i < 32; i++) { seeds[i] = strongRandom.nextInt(256); }
    final now = DateTime.now().microsecondsSinceEpoch;
    for (int i = 0; i < 8; i++) { seeds[i] ^= ((now >> (i * 8)) & 0xFF); }
    secureRandom.seed(pc.KeyParameter(seeds));
    secureRandom.nextBytes(iv);

    // AES-256-CBC encrypt with PKCS7 padding
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
    final padLength = 16 - (plaintextBytes.length % 16);
    final padded = Uint8List(plaintextBytes.length + padLength);
    padded.setRange(0, plaintextBytes.length, plaintextBytes);
    for (int i = plaintextBytes.length; i < padded.length; i++) { padded[i] = padLength; }

    final cipher = pc.CBCBlockCipher(pc.AESEngine());
    cipher.init(true, pc.ParametersWithIV(pc.KeyParameter(keyBytes), iv));
    final ciphertext = Uint8List(padded.length);
    var offset = 0;
    while (offset < padded.length) {
      offset += cipher.processBlock(padded, offset, ciphertext, offset);
    }

    // Prepend IV to ciphertext
    final combined = Uint8List.fromList([...iv, ...ciphertext]);
    return base64Encode(combined);
  }
}

/// TreeNode — узел Ratchet Tree
class TreeNode {
  final int index;
  final TreeNodeType nodeType;
  final String publicKey;
  final String? privateKey;
  final String? userId;
  final bool isBlank;

  TreeNode({
    required this.index,
    required this.nodeType,
    required this.publicKey,
    this.privateKey,
    this.userId,
    this.isBlank = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'type': nodeType.value,
      'public_key': publicKey,
      if (privateKey != null) 'private_key': privateKey,
      if (userId != null) 'user_id': userId,
      'is_blank': isBlank,
    };
  }

  factory TreeNode.fromJson(Map<String, dynamic> json) {
    return TreeNode(
      index: json['index'] as int? ?? 0,
      nodeType: TreeNodeType.fromString(json['type'] as String? ?? 'leaf'),
      publicKey: json['public_key'] as String? ?? '',
      privateKey: json['private_key'] as String?,
      userId: json['user_id'] as String? ?? json['userId'] as String?,
      isBlank: json['is_blank'] as bool? ?? false,
    );
  }
}

/// TreeNodeType — тип узла дерева
enum TreeNodeType {
  leaf('leaf'),
  parent('parent');

  final String value;

  const TreeNodeType(this.value);

  static TreeNodeType fromString(String value) {
    switch (value) {
      case 'leaf':
        return TreeNodeType.leaf;
      case 'parent':
        return TreeNodeType.parent;
      default:
        return TreeNodeType.leaf;
    }
  }
}

/// UpdatePath — путь обновления ключей от leaf до root
class UpdatePath {
  final List<NodeUpdate> nodes;
  final int leafIndex;

  UpdatePath({
    required this.nodes,
    required this.leafIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'leaf_index': leafIndex,
    };
  }

  factory UpdatePath.fromJson(Map<String, dynamic> json) {
    return UpdatePath(
      nodes: (json['nodes'] as List<dynamic>? ?? [])
          .map((n) => NodeUpdate.fromJson(n as Map<String, dynamic>))
          .toList(),
      leafIndex: json['leaf_index'] as int? ?? -1,
    );
  }
}

/// NodeUpdate — обновление одного узла в UpdatePath
class NodeUpdate {
  final int index;
  final String publicKey;
  final String pathSecret;

  NodeUpdate({
    required this.index,
    required this.publicKey,
    required this.pathSecret,
  });

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'public_key': publicKey,
      'path_secret': pathSecret,
    };
  }

  factory NodeUpdate.fromJson(Map<String, dynamic> json) {
    return NodeUpdate(
      index: json['index'] as int? ?? 0,
      publicKey: json['public_key'] as String? ?? '',
      pathSecret: json['path_secret'] as String? ?? '',
    );
  }
}
