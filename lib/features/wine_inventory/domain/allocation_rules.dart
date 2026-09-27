int projectedShortage({
  required int required,
  required int reserved,
  required int houseAvailable,
  required int priorUnreservedNeed,
  required bool draft,
}) {
  if (!draft) {
    return (required - reserved).clamp(0, required);
  }
  final stillNeeded = required - reserved;
  final remaining = (houseAvailable - priorUnreservedNeed).clamp(0, houseAvailable);
  return (stillNeeded - remaining).clamp(0, stillNeeded);
}

bool canPickup({
  required int reserved,
  required int fulfilled,
  required int quantity,
}) {
  return quantity > 0 && quantity <= reserved - fulfilled;
}

int houseLeftAfterReserve({required int house, required int reserved}) {
  return (house - reserved).clamp(0, house);
}
