
final RegExp idRegex = new RegExp(r'[_a-zA-Z0-9]');

String commas(int n) {
  String str = '${n}';
  int len = str.length;
  // if (len > 6) {
  //   int pos1 = len - 6;
  //   int pos2 = len - 3;
  //   return '${str.substring(0, pos1)},${str.substring(pos1, pos2)},${str.substring(pos2)}';
  // } else
  if (len > 3) {
    int pos = len - 3;
    return '${str.substring(0, pos)},${str.substring(pos)}';
  } else {
    return str;
  }
}

String pluralize(String word, int count) {
  if (count == 1) return word;
  if (word.endsWith('s')) return '${word}es';
  return '${word}s';
}

/// Diff the two strings and return the list of edits to convert [a] to [b].
List<Edit> simpleDiff(String a, String b) {
  if (a.isEmpty && b.isNotEmpty) return [new Edit(0, 0, b)];
  if (a.isNotEmpty && b.isEmpty) return [new Edit(0, a.length, b)];
  if (a == b) return [new Edit(0, 0, '')];

  // Look for a single deletion, addition, or replacement edit that will convert
  // [a] to [b]. Else do a wholesale replacement.

  int startA = 0;
  int startB = 0;

  int endA = a.length;
  int endB = b.length;

  while (startA < endA && startB < endB && a[startA] == b[startB]) {
    startA++;
    startB++;
  }

  while (endA > startA && endB > startB && a[endA - 1] == b[endB - 1]) {
    endA--;
    endB--;
  }

  return [
    new Edit(startA, endA - startA, b.substring(startB, endB))
  ];
}

/// Ensure the first letter is lower-case.
String toStartingLowerCase(String str) {
  if (str == null) return null;
  if (str.isEmpty) return str;
  return str.substring(0, 1).toLowerCase() + str.substring(1);
}

String toTitleCase(String str) {
  if (str == null) return null;
  if (str.isEmpty) return str;
  return str.substring(0, 1).toUpperCase() + str.substring(1);
}

class Edit {
  final int offset;
  final int length;
  final String replacement;

  Edit(this.offset, this.length, this.replacement);

  bool operator==(obj) {
    if (obj is! Edit) return false;
    Edit other = obj;
    return offset == other.offset && length == other.length &&
        replacement == other.replacement;
  }

  int get hashCode => offset ^ length ^ replacement.hashCode;

  String toString() => "[Edit ${offset}:${length}:'${replacement}']";
}
