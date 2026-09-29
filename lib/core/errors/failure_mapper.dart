import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_failure.dart';

bool isNetworkError(Object error) {
  if (error is NetworkFailure) return true;
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('Network is unreachable') ||
      text.contains('ClientException') ||
      text.contains('AuthRetryableFetchException');
}

AppFailure mapFailure(Object error) {
  if (error is AppFailure) return error;
  if (isNetworkError(error)) {
    return const NetworkFailure(
      'The workspace could not be reached. Your draft stays on this device.',
    );
  }
  if (error is AuthException) {
    return AuthFailure(_authMessage(error.message));
  }
  if (error is PostgrestException) {
    return _fromToken('${error.message} ${error.code ?? ''}');
  }
  if (error is FunctionException) {
    return _fromToken('${error.details ?? ''} ${error.reasonPhrase ?? ''}');
  }
  final mapped = _fromToken(error.toString());
  if (mapped is! UnexpectedFailure) return mapped;
  return const UnexpectedFailure(
    'Something went wrong. Try again, or check the audit log if the action may have saved.',
  );
}

AppFailure _fromToken(String text) {
  const messages = <String, AppFailure>{
    'not_authenticated': AuthFailure('Sign in again to continue.'),
    'invalid_name': ValidationFailure('Enter a name between 2 and 80 characters.'),
    'invalid_slug': ValidationFailure(
      'Use 3 to 40 lowercase letters, numbers, or hyphens.',
    ),
    'slug_taken': ValidationFailure('That organization address is already in use.'),
    'permission_denied': PermissionFailure('You do not have permission to do that.'),
    'invalid_email': ValidationFailure('Enter a valid email address.'),
    'invalid_token': ValidationFailure('That invite code is not valid.'),
    'invalid_role': ValidationFailure('Choose a valid role.'),
    'invalid_timezone': ValidationFailure('Choose a valid venue timezone.'),
    'invalid_currency': ValidationFailure('Use a three-letter currency code.'),
    'invite_not_found': ValidationFailure('That invite was not found.'),
    'invite_closed': ValidationFailure('That invite is no longer open.'),
    'invite_already_accepted': ValidationFailure('That invite was already accepted.'),
    'invite_expired': ValidationFailure('That invite has expired.'),
    'invite_email_mismatch': PermissionFailure(
      'Sign in with the email address the invite was sent to.',
    ),
    'already_member': ValidationFailure('You already belong to this organization.'),
    'join_already_pending': ValidationFailure(
      'You already have a pending request for this venue.',
    ),
    'invalid_service_style': ValidationFailure('Choose a service style.'),
    'invalid_message': ValidationFailure('Keep the note under 500 characters.'),
    'join_not_found': ValidationFailure('That join request was not found.'),
    'venue_not_found': ValidationFailure('No venue uses that code.'),
    'cannot_assign_role': PermissionFailure(
      'You cannot assign a role above your own.',
    ),
    'role_requires_venue': ValidationFailure('Choose a venue for this role.'),
    'last_owner': ValidationFailure(
      'The organization must keep at least one owner.',
    ),
    'invalid_decision': ValidationFailure('Choose approve or decline.'),
    'invalid_room_code': ValidationFailure('Use a room code such as CELLAR-A.'),
    'invalid_unit_code': ValidationFailure('Use a rack code such as RACK-01.'),
    'code_taken': ValidationFailure('That code is already used in this venue.'),
    'template_not_found': ValidationFailure('Choose a rack template.'),
    'room_not_found': ValidationFailure('Choose a cellar room.'),
    'invalid_quantity': ValidationFailure('Enter a whole number of bottles.'),
    'invalid_cost': ValidationFailure('Enter a unit cost such as 24.0000.'),
    'invalid_wine_type': ValidationFailure('Choose a supported wine type.'),
    'invalid_sku': ValidationFailure('SKU must be letters, numbers, or hyphens.'),
    'invalid_vintage': ValidationFailure('Vintage must be a year or NV.'),
    'invalid_bottle_size': ValidationFailure('Bottle size must be millilitres.'),
    'invalid_import': ValidationFailure('The import was not a list of wines.'),
    'vendor_not_found': ValidationFailure('Choose a vendor.'),
    'vendor_exists': ValidationFailure('That vendor already exists.'),
    'item_not_found': ValidationFailure('That wine was not found.'),
    'slot_not_found': ValidationFailure('Choose a mapped slot.'),
    'insufficient_quantity': ValidationFailure('Staging does not have that many bottles.'),
    'slot_over_capacity': ValidationFailure('That slot cannot hold that many bottles.'),
    'invalid_count_kind': ValidationFailure('Choose a count type.'),
    'invalid_count_mode': ValidationFailure('Choose blind or expected.'),
    'session_not_found': ValidationFailure('That count session was not found.'),
    'session_not_open': ValidationFailure('This count is no longer open for entries.'),
    'session_not_submitted': ValidationFailure('Submit the count before review.'),
    'count_conflict': ValidationFailure('Resolve the conflicting counts before approval.'),
    'count_needs_lot': ValidationFailure(
      'A found bottle has no lot. Receive it before approving that line.',
    ),
    'adjustment_would_go_negative': ValidationFailure(
      'That adjustment would take a balance below zero.',
    ),
    'invalid_destination': ValidationFailure('Choose a bar, event hold, or member locker.'),
    'holder_required': ValidationFailure('Name the member who holds this locker.'),
    'invalid_tier': ValidationFailure('Choose a member tier.'),
    'invalid_release_date': ValidationFailure('Enter the release date as YYYY-MM-DD.'),
    'campaign_not_found': ValidationFailure('That release was not found.'),
    'campaign_not_draft': ValidationFailure('Lines can only be added before the release is reserved.'),
    'campaign_not_reserved': ValidationFailure('Reserve the release before pickup.'),
    'member_not_found': ValidationFailure('Choose a club member.'),
    'allocation_not_found': ValidationFailure('That allocation line was not found.'),
    'insufficient_reserved': ValidationFailure('Pickup cannot exceed the bottles still reserved.'),
    'invalid_list_kind': ValidationFailure('Choose a list type.'),
    'invalid_threshold': ValidationFailure('Threshold must be zero or more bottles.'),
    'invalid_pour': ValidationFailure('Enter a pour size in millilitres.'),
    'list_not_found': ValidationFailure('That wine list was not found.'),
    'list_item_exists': ValidationFailure('That wine is already on the list.'),
    'bottle_not_open': ValidationFailure('That bottle is not open.'),
    'insufficient_pour': ValidationFailure('That pour is larger than the open bottle.'),
    'guest_not_found': ValidationFailure('Choose a guest.'),
    'reservation_not_found': ValidationFailure('That reservation was not found.'),
    'reservation_not_booked': ValidationFailure('Only a booked reservation can be seated.'),
    'reservation_not_seated': ValidationFailure('That party is not seated.'),
    'table_not_found': ValidationFailure('Choose a table.'),
    'table_unavailable': ValidationFailure('That table is not open.'),
    'table_occupied': ValidationFailure('That table already has a seated party.'),
    'party_exceeds_capacity': ValidationFailure('The party is larger than the table.'),
    'invalid_party': ValidationFailure('Party size must be between 1 and 20.'),
    'invalid_shift': ValidationFailure('Shift end must be after the start.'),
    'already_clocked_in': ValidationFailure('You are already clocked in.'),
    'not_clocked_in': ValidationFailure('You are not clocked in.'),
    'checklist_not_found': ValidationFailure('That checklist item was not found.'),
    'checklist_already_done': ValidationFailure('That item is already complete.'),
    'document_not_found': ValidationFailure('That document was not found.'),
    'already_acknowledged': ValidationFailure('You already acknowledged that document.'),
    'event_not_found': ValidationFailure('That event was not found.'),
    'event_closed': ValidationFailure('This event is already closed.'),
    'channel_not_found': ValidationFailure('That channel was not found.'),
    'invalid_provider': ValidationFailure('Choose a supported POS.'),
    'handshake_required': ValidationFailure('The POS did not accept those credentials. Nothing was marked connected.'),
    'push_failed': ValidationFailure('The POS did not accept the 86 update.'),
    'invalid_plan': ValidationFailure('Choose trial, active, or expired.'),
    'plan_required': PermissionFailure('Reports need an active or trial plan.'),
    'self_approval_denied': PermissionFailure('Someone else must approve a count you started or entered.'),
    'lot_required': ValidationFailure('This slot has more than one lot. Count each lot separately.'),
    'lot_item_mismatch': ValidationFailure('That lot is a different wine than the SKU.'),
    'pull_unsupported': ValidationFailure('Sales pull is available for Square. Other POS systems push checks in.'),
    'pull_failed': ValidationFailure('The sales pull failed. Nothing new was marked complete.'),
    'location_mapping_required': ValidationFailure('Choose the Square location for this venue before pulling sales.'),
    'pos_stock_shortage': ValidationFailure('A mapped sale exceeds available house stock. Correct the stock, then pull again.'),
    'connection_save_failed': ValidationFailure('The POS credentials could not be saved. The connection was not changed.'),
    'invalid_location': ValidationFailure('Choose a Square location.'),
    'invalid_item_map': ValidationFailure('Enter a Square item ID and an existing local wine SKU.'),
    'item_already_applied': ValidationFailure('This Square item already depleted stock. Its mapping cannot be changed.'),
    'count_needs_recount': ValidationFailure('This count mixed lots. Start a new count and enter each lot.'),
    'count_out_of_scope': ValidationFailure('That slot is outside this count.'),
  };
  for (final entry in messages.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  return const UnexpectedFailure(
    'The request was rejected. Check the details and try again.',
  );
}

String _authMessage(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('invalid login') || lower.contains('invalid credentials')) {
    return 'Email or password is incorrect.';
  }
  if (lower.contains('already registered') || lower.contains('already been registered')) {
    return 'An account with that email already exists. Sign in instead.';
  }
  if (lower.contains('password')) {
    return 'Password does not meet the account rules.';
  }
  if (lower.contains('email')) {
    return 'Check the email address and try again.';
  }
  return 'Sign-in could not be completed.';
}
