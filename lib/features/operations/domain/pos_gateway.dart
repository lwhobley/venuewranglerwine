import 'dart:convert';

import 'package:crypto/crypto.dart';

const posProviders = <String>[
  'toast',
  'square',
  'clover',
  'shopify',
  'lightspeed',
  'spoton',
  'touchbistro',
  'revel',
  'heartland',
  'aloha',
  'generic',
];

const pullPosProviders = <String>['toast', 'square', 'clover', 'shopify'];
const salesPullProviders = <String>['square'];

class PosSaleLine {
  const PosSaleLine({required this.sku, required this.name, required this.quantity});

  final String sku;
  final String name;
  final String quantity;
}

class PosSale {
  const PosSale({
    required this.externalId,
    required this.occurredAt,
    required this.lines,
  });

  final String externalId;
  final String occurredAt;
  final List<PosSaleLine> lines;

  String idempotencyKey(String connectionId) => '$connectionId:$externalId';
}

class EightySixPush {
  const EightySixPush({required this.sku, required this.externalSku, required this.available});

  final String sku;
  final String externalSku;
  final bool available;

  Map<String, Object?> toJson() => {
    'event': available ? 'wine.available' : 'wine.86',
    'sku': sku,
    'externalSku': externalSku,
    'available': available,
  };
}

class HandshakeRequest {
  const HandshakeRequest({required this.method, required this.url, required this.headers, this.body});

  final String method;
  final String url;
  final Map<String, String> headers;
  final Map<String, Object?>? body;
}

int posBottlesToDeplete({
  required bool itemFound,
  required String quantity,
  required bool alreadyApplied,
}) {
  if (alreadyApplied || !itemFound) return 0;
  final value = num.tryParse(quantity);
  if (value == null || value <= 0 || value != value.roundToDouble()) return 0;
  return value.toInt();
}

String posWebhookSignature(String secret, String rawBody) {
  return Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(rawBody)).toString();
}

bool connectionAllowed({required int statusCode, required bool bodyOk}) {
  return statusCode >= 200 && statusCode < 300 && bodyOk;
}

HandshakeRequest? handshakeFor({
  required String providerKey,
  required String accessToken,
  String? merchantId,
  String? shopDomain,
  String? webhookUrl,
  bool sandbox = false,
}) {
  switch (providerKey) {
    case 'toast':
      return HandshakeRequest(
        method: 'POST',
        url: sandbox
            ? 'https://ws-sandbox-api.eng.toasttab.com/authentication/v1/authentication/login'
            : 'https://ws-api.toasttab.com/authentication/v1/authentication/login',
        headers: const {'content-type': 'application/json'},
        body: {
          'clientId': merchantId,
          'clientSecret': accessToken,
          'userAccessType': 'TOAST_MACHINE_CLIENT',
        },
      );
    case 'square':
      return HandshakeRequest(
        method: 'GET',
        url: sandbox
            ? 'https://connect.squareupsandbox.com/v2/locations'
            : 'https://connect.squareup.com/v2/locations',
        headers: {'authorization': 'Bearer $accessToken', 'content-type': 'application/json'},
      );
    case 'clover':
      if (merchantId == null || merchantId.isEmpty) return null;
      final host = sandbox ? 'https://apisandbox.dev.clover.com' : 'https://api.clover.com';
      return HandshakeRequest(
        method: 'GET',
        url: '$host/v3/merchants/$merchantId',
        headers: {'authorization': 'Bearer $accessToken'},
      );
    case 'shopify':
      if (shopDomain == null || shopDomain.isEmpty) return null;
      return HandshakeRequest(
        method: 'GET',
        url: 'https://$shopDomain/admin/api/2025-01/shop.json',
        headers: {'x-shopify-access-token': accessToken},
      );
    default:
      if (!posProviders.contains(providerKey) || webhookUrl == null || webhookUrl.isEmpty) {
        return null;
      }
      return HandshakeRequest(
        method: 'POST',
        url: webhookUrl,
        headers: {'content-type': 'application/json'},
        body: const {'event': 'handshake'},
      );
  }
}

List<PosSale> normalizeSales(String providerKey, Map<String, dynamic> payload) {
  switch (providerKey) {
    case 'square':
      final orders = payload['orders'] as List? ?? const [];
      return [
        for (final order in orders)
          PosSale(
            externalId: (order as Map)['id'].toString(),
            occurredAt: order['created_at']?.toString() ?? '',
            lines: [
              for (final line in (order['line_items'] as List? ?? const []))
                PosSaleLine(
                  sku: ((line as Map)['catalog_object_id'] ?? line['uid'] ?? '').toString(),
                  name: line['name']?.toString() ?? '',
                  quantity: line['quantity']?.toString() ?? '1',
                ),
            ],
          ),
      ];
    case 'generic':
    case 'lightspeed':
    case 'spoton':
    case 'touchbistro':
    case 'revel':
    case 'heartland':
    case 'aloha':
      final checks = payload['checks'] as List? ?? const [];
      return [
        for (final check in checks)
          PosSale(
            externalId: (check as Map)['externalId'].toString(),
            occurredAt: check['occurredAt']?.toString() ?? '',
            lines: [
              for (final line in (check['lines'] as List? ?? const []))
                PosSaleLine(
                  sku: (line as Map)['sku'].toString(),
                  name: line['name']?.toString() ?? '',
                  quantity: line['quantity'].toString(),
                ),
            ],
          ),
      ];
    default:
      return const [];
  }
}
