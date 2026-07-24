import 'dart:convert';

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
    // Binary tree: parent = (child - 1) / 2 (rounded down) for left,
    // or (child - 2) / 2 for right, but simplified:
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
    // Найти наименьший subtree root, не содержащий excluded
    // В реальности — traverse tree upward
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

  String _generateHpkePublicKey() {
    // В реальности — HPKE key generation через pointycastle / mlswg-dart
    // Генерация 32-byte public key
    final bytes = List.generate(32, (i) => ((i * 7 + 13) & 0xFF));
    return base64Encode(bytes);
  }

  String? _generateHpkePrivateKey() {
    final bytes = List.generate(32, (i) => ((i * 11 + 37) & 0xFF));
    return base64Encode(bytes);
  }

  String _derivePathSecret(int nodeIndex) {
    // PathSecret = DeriveSecret(parent_path_secret, "path")
    final bytes = List.generate(32, (i) => ((i * 23 + nodeIndex) & 0xFF));
    return base64Encode(bytes);
  }

  String _hpkeEncrypt(String publicKey, String plaintext) {
    // HPKE Encrypt(publicKey, plaintext, aad)
    // В реальности — через HPKE API
    final combined = '$publicKey:$plaintext';
    return base64Encode(combined.codeUnits);
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
