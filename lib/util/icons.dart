import 'package:flutter/widgets.dart';

/// Kategori ikonları veritabanında [IconData.codePoint] olarak saklanır ve
/// çalışma zamanında yeniden kurulur. Bu yüzden release derlemede
/// `--no-tree-shake-icons` ŞART (yoksa ikonlar boş görünür).
IconData iconFromCodePoint(int codePoint) =>
    // ignore: non_const_argument_for_const_parameter
    IconData(codePoint, fontFamily: 'MaterialIcons');
