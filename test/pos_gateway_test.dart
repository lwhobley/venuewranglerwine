import 'package:flutter_test/flutter_test.dart';
import 'package:venue_wrangler/features/operations/domain/pos_gateway.dart';

void main() {
  test('a connection is refused unless the handshake succeeds', () {
    expect(connectionAllowed(statusCode: 200, bodyOk: true), isTrue);
    expect(connectionAllowed(statusCode: 401, bodyOk: false), isFalse);
    expect(connectionAllowed(statusCode: 200, bodyOk: false), isFalse);
  });

  test('toast and square build documented handshake requests', () {
    final toast = handshakeFor(providerKey: 'toast', accessToken: 'secret', merchantId: 'client');
    expect(toast?.url, contains('/authentication/v1/authentication/login'));
    expect(toast?.body?['userAccessType'], 'TOAST_MACHINE_CLIENT');
    final square = handshakeFor(providerKey: 'square', accessToken: 'token');
    expect(square?.url, 'https://connect.squareup.com/v2/locations');
    expect(square?.headers['authorization'], 'Bearer token');
  });

  test('webhook providers can connect without a private pull API', () {
    final spoton = handshakeFor(
      providerKey: 'spoton',
      accessToken: 'ignored',
      webhookUrl: 'https://pos.example/hooks/vw',
    );
    expect(spoton?.body?['event'], 'handshake');
    expect(handshakeFor(providerKey: 'unknown', accessToken: 'x'), isNull);
  });

  test('the same external check is one idempotency key', () {
    const sale = PosSale(externalId: 'chk-1', occurredAt: '2026-09-27T00:00:00Z', lines: []);
    expect(sale.idempotencyKey('conn'), sale.idempotencyKey('conn'));
    final normalized = normalizeSales('square', {
      'orders': [
        {
          'id': 'ord-1',
          'created_at': '2026-09-27T00:00:00Z',
          'line_items': [
            {'name': 'Les Cotes', 'quantity': '1', 'catalog_object_id': 'CLB-001'},
          ],
        },
      ],
    });
    expect(normalized.single.lines.single.sku, 'CLB-001');
    expect(const EightySixPush(sku: 'CLB-001', externalSku: 'CLB-001', available: false).toJson()['event'], 'wine.86');
  });

  test('only a new mapped whole-bottle sale depletes stock', () {
    expect(posBottlesToDeplete(itemFound: true, quantity: '2', alreadyApplied: false), 2);
    expect(posBottlesToDeplete(itemFound: false, quantity: '2', alreadyApplied: false), 0);
    expect(posBottlesToDeplete(itemFound: true, quantity: '1.5', alreadyApplied: false), 0);
    expect(posBottlesToDeplete(itemFound: true, quantity: '2', alreadyApplied: true), 0);
    expect(salesPullProviders, ['square']);
  });

  test('webhook signatures are hmac sha256 hex of the raw body', () {
    const raw = '{"event":"wine.86"}';
    final signature = posWebhookSignature('secret', raw);
    expect(signature, posWebhookSignature('secret', raw));
    expect(signature, isNot(posWebhookSignature('other', raw)));
    expect(signature.length, 64);
  });
}
