bool listItemAvailable({
  required bool published,
  required bool manual86,
  required int houseBottles,
  required int threshold,
  required int openRemainingMl,
  required int? pourMl,
}) {
  if (!published || manual86) return false;
  if (houseBottles >= threshold) return true;
  if (pourMl != null && pourMl > 0 && openRemainingMl >= pourMl) return true;
  return false;
}

String? unavailableReason({
  required bool published,
  required bool manual86,
  required int houseBottles,
  required int threshold,
  required int openRemainingMl,
  required int? pourMl,
}) {
  if (listItemAvailable(
    published: published,
    manual86: manual86,
    houseBottles: houseBottles,
    threshold: threshold,
    openRemainingMl: openRemainingMl,
    pourMl: pourMl,
  )) {
    return null;
  }
  if (!published) return 'unpublished';
  if (manual86) return 'manual_86';
  return 'below_threshold';
}

int? remainingAfterPour({required int remainingMl, required int pourMl}) {
  if (pourMl <= 0 || pourMl > remainingMl) return null;
  return remainingMl - pourMl;
}
