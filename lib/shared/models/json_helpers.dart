/// Tolerant JSON number decoding for the LeadX API payloads.
///
/// Laravel model casts (`decimal:2` on money columns, `integer`, …)
/// serialize as JSON **strings** ("100.00") in the API resources, while
/// controller-computed aggregates arrive as JSON numbers. Decoding with a
/// bare `json['field'] as num?` throws a `TypeError` on the string form,
/// which — because screens only catch [dynamic] `ApiException`s — leaves
/// the UI frozen on its loading state. These helpers accept either shape.
library;

/// A nullable `num` that accepts a JSON number **or** a numeric string.
num? numFromJson(dynamic value) {
  if (value is num) return value;
  if (value is String && value.trim().isNotEmpty) {
    return num.tryParse(value.trim());
  }
  return null;
}

/// A nullable `double` field (money, totals, prices).
double? doubleFromJson(dynamic value) => numFromJson(value)?.toDouble();

/// A nullable `int` field (ids, counts, page numbers).
int? intFromJson(dynamic value) => numFromJson(value)?.toInt();
