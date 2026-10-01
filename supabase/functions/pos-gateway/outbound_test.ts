import { isShopifyDomain, safeOutboundUrl } from './outbound.ts';

const assert = (condition: boolean, message: string) => {
  if (!condition) throw new Error(message);
};

Deno.test('accepts public https hosts', () => {
  assert(safeOutboundUrl('https://hooks.example.com/pos') !== null, 'public host');
});

Deno.test('rejects internal and unsafe targets', () => {
  for (const url of [
    'http://example.com', 'https://localhost/x', 'https://127.0.0.1/', 'https://10.0.0.5/',
    'https://169.254.169.254/latest/meta-data', 'https://192.168.1.1/', 'https://172.16.0.1/',
    'https://[::1]/', 'https://db.internal/', 'https://intranet/', 'https://user:pw@example.com/',
    'not a url', '',
  ]) assert(safeOutboundUrl(url) === null, `should block ${url}`);
});

Deno.test('shopify domain allow-list', () => {
  assert(isShopifyDomain('wine-shop.myshopify.com'), 'valid');
  assert(!isShopifyDomain('evil.com/x.myshopify.com'), 'path trick');
  assert(!isShopifyDomain('myshopify.com.evil.com'), 'suffix trick');
});
