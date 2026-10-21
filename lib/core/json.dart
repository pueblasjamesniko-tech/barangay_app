/// ASP.NET can send keys as "fullName" (typed models) or "FullName" (Dapper rows).
/// We lowercase every key once, so the models below only deal with lowercase keys.
dynamic norm(dynamic v) {
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries) e.key.toString().toLowerCase(): norm(e.value),
    };
  }
  if (v is List) return v.map(norm).toList();
  return v;
}

int asInt(dynamic v, [int d = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? d;
}

int? asIntN(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

String asStr(dynamic v, [String d = '']) => v == null ? d : v.toString();

String? asStrN(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

bool asBool(dynamic v) => v == true || v == 1 || '$v'.toLowerCase() == 'true';

DateTime asDate(dynamic v) => DateTime.tryParse(asStr(v)) ?? DateTime.now();

List<String> asStrList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];
