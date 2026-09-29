import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { squareSales, squareSearchBody } from './square.ts';

const known = new Set([
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
]);

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  const raw = await req.text();
  const body = JSON.parse(raw);
  const action = String(body.action ?? '');
  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  if (action === 'webhook') {
    return ingestWebhook(admin, body, raw, req);
  }

  const user = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } },
  );
  const { data: authData } = await user.auth.getUser();
  if (!authData.user) return json({ error: 'not_authenticated' }, 401);

  if (action === 'connect') return connect(admin, user, body);
  if (action === 'ingest') return ingest(admin, user, body);
  if (action === 'locations') return squareLocations(admin, user, body);
  if (action === 'push86') return push86(admin, user, body);
  return json({ error: 'invalid_provider' }, 400);
});

async function connect(admin: SupabaseClient<any>, user: SupabaseClient<any>, body: Record<string, unknown>) {
  const organizationId = String(body.organizationId ?? '');
  const providerKey = String(body.providerKey ?? '');
  if (!known.has(providerKey)) return json({ error: 'invalid_provider' }, 400);
  const { error: permissionError } = await user.rpc('assert_integration_manage', {
    p_organization_id: organizationId,
  });
  if (permissionError) return json({ error: 'permission_denied' }, 403);

  const secret = {
    access_token: str(body.accessToken),
    client_id: str(body.clientId),
    client_secret: str(body.clientSecret),
    merchant_id: str(body.merchantId),
    shop_domain: str(body.shopDomain),
    restaurant_guid: str(body.restaurantGuid),
    webhook_url: str(body.webhookUrl),
    webhook_secret: str(body.webhookSecret),
    sandbox: body.sandbox === true,
  };
  const handshake = await handshakeCall(providerKey, secret);
  if (!handshake.ok) return json({ error: 'handshake_required', detail: handshake.detail }, 400);

  const { data: connectionId, error: ensureError } = await user.rpc('ensure_integration', {
    p_organization_id: organizationId,
    p_provider_key: providerKey,
  });
  if (ensureError || !connectionId) return json({ error: 'permission_denied' }, 403);
  const { error: activationError } = await admin.rpc('activate_pos_integration', {
    p_connection_id: connectionId,
    p_secret: secret,
  });
  if (activationError) return json({ error: 'connection_save_failed' }, 502);
  return json({ status: 'connected' }, 200);
}

async function squareLocations(
  admin: SupabaseClient<any>,
  user: SupabaseClient<any>,
  body: Record<string, unknown>,
) {
  const connectionId = String(body.connectionId ?? '');
  const { error: permissionError } = await user.rpc('assert_pos_actor', {
    p_connection_id: connectionId,
    p_venue_id: null,
  });
  if (permissionError) return json({ error: 'permission_denied' }, 403);
  const loaded = await loadSecret(admin, connectionId);
  if (!loaded || loaded.providerKey !== 'square') return json({ error: 'pull_unsupported' }, 400);
  try {
    return json({ locations: await fetchSquareLocations(loaded.secret) }, 200);
  } catch (_error) {
    return json({ error: 'pull_failed' }, 502);
  }
}

async function ingest(
  admin: SupabaseClient<any>,
  user: SupabaseClient<any>,
  body: Record<string, unknown>,
) {
  const connectionId = String(body.connectionId ?? '');
  const venueId = String(body.venueId ?? '');
  const { error: permissionError } = await user.rpc('assert_pos_actor', {
    p_connection_id: connectionId,
    p_venue_id: venueId,
  });
  if (permissionError) return json({ error: 'permission_denied' }, 403);
  const loaded = await loadSecret(admin, connectionId);
  if (!loaded) return json({ error: 'handshake_required' }, 400);
  if (loaded.providerKey !== 'square') return json({ error: 'pull_unsupported' }, 400);
  const { data: venueMap, error: mapError } = await admin
    .from('integration_venue_maps')
    .select('external_location_id')
    .eq('connection_id', connectionId)
    .eq('venue_id', venueId)
    .maybeSingle();
  if (mapError) return json({ error: 'pull_failed' }, 502);
  if (!venueMap) return json({ error: 'location_mapping_required' }, 400);
  try {
    const sales = await pullSquare(loaded.secret, venueMap.external_location_id);
    const result = await applyChecks(admin, connectionId, venueId, sales.map((sale) => ({
      externalId: sale.externalId,
      occurredAt: sale.occurredAt,
      lines: sale.lines,
    })));
    await admin.from('integration_sync_runs').insert({
      connection_id: connectionId,
      organization_id: loaded.organizationId,
      direction: 'ingest',
      status: 'ok',
      detail: `applied:${result.applied},unmapped:${result.unmapped}`,
    });
    return json(result, 200);
  } catch (error) {
    const code = error instanceof Error && error.message === 'pos_stock_shortage'
      ? 'pos_stock_shortage' : 'pull_failed';
    await admin.from('integration_sync_runs').insert({
      connection_id: connectionId,
      organization_id: loaded.organizationId,
      direction: 'ingest',
      status: 'failed',
      detail: code,
    });
    return json({ error: code }, code === 'pos_stock_shortage' ? 409 : 502);
  }
}

async function push86(
  admin: SupabaseClient<any>,
  user: SupabaseClient<any>,
  body: Record<string, unknown>,
) {
  const connectionId = String(body.connectionId ?? '');
  const { error: permissionError } = await user.rpc('assert_pos_actor', {
    p_connection_id: connectionId,
    p_venue_id: null,
  });
  if (permissionError) return json({ error: 'permission_denied' }, 403);
  const loaded = await loadSecret(admin, connectionId);
  if (!loaded) return json({ error: 'handshake_required' }, 400);
  const payload = {
    event: body.available === true ? 'wine.available' : 'wine.86',
    sku: str(body.sku),
    externalSku: str(body.externalSku),
    available: body.available === true,
  };
  const sent = await pushAvailability(loaded.providerKey, loaded.secret, payload);
  await admin.from('integration_sync_runs').insert({
    connection_id: connectionId,
    organization_id: loaded.organizationId,
    direction: 'push',
    status: sent.ok ? 'ok' : 'failed',
    detail: sent.ok ? 'pushed' : 'push_failed',
  });
  return json({ status: sent.ok ? 'pushed' : 'push_failed' }, sent.ok ? 200 : 502);
}

async function ingestWebhook(
  admin: SupabaseClient<any>,
  body: Record<string, unknown>,
  raw: string,
  req: Request,
) {
  const connectionId = String(body.connectionId ?? '');
  const venueId = String(body.venueId ?? '');
  const loaded = await loadSecret(admin, connectionId);
  if (!loaded?.secret.webhook_secret) return json({ error: 'handshake_required' }, 401);
  const given = req.headers.get('x-vw-signature') ?? '';
  const expected = await sign(loaded.secret.webhook_secret, raw);
  if (!safeEqual(given, expected)) return json({ error: 'permission_denied' }, 401);
  try {
    return json(await applyChecks(admin, connectionId, venueId, body.checks), 200);
  } catch (error) {
    const code = error instanceof Error && error.message === 'pos_stock_shortage'
      ? 'pos_stock_shortage' : 'pull_failed';
    return json({ error: code }, code === 'pos_stock_shortage' ? 409 : 502);
  }
}

async function applyChecks(
  admin: SupabaseClient<any>,
  connectionId: string,
  venueId: string,
  checks: unknown,
) {
  let applied = 0;
  let unmapped = 0;
  for (const check of (checks as Record<string, unknown>[]) ?? []) {
    const { data, error } = await admin.rpc('apply_pos_check', {
      p_connection_id: connectionId,
      p_venue_id: venueId,
      p_external_id: String(check.externalId ?? ''),
      p_occurred_at: String(check.occurredAt ?? new Date().toISOString()),
      p_lines: check.lines ?? [],
    });
    if (error) throw new Error(error.message.includes('pos_stock_shortage')
      ? 'pos_stock_shortage' : 'pull_failed');
    if (data?.applied) applied += 1;
    unmapped += Number(data?.unmapped ?? 0);
  }
  return { applied, unmapped };
}

async function handshakeCall(provider: string, secret: Secret) {
  if (provider === 'toast') {
    const host = secret.sandbox
      ? 'https://ws-sandbox-api.eng.toasttab.com'
      : 'https://ws-api.toasttab.com';
    const response = await fetch(`${host}/authentication/v1/authentication/login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        clientId: secret.client_id,
        clientSecret: secret.client_secret,
        userAccessType: 'TOAST_MACHINE_CLIENT',
      }),
    });
    const payload = await response.json().catch(() => ({}));
    return { ok: response.ok && payload.status === 'SUCCESS', detail: response.status };
  }
  if (provider === 'square') {
    const host = secret.sandbox ? 'https://connect.squareupsandbox.com' : 'https://connect.squareup.com';
    const response = await fetch(`${host}/v2/locations`, {
      headers: { authorization: `Bearer ${secret.access_token}` },
    });
    return { ok: response.ok, detail: response.status };
  }
  if (provider === 'clover') {
    const host = secret.sandbox ? 'https://apisandbox.dev.clover.com' : 'https://api.clover.com';
    const response = await fetch(`${host}/v3/merchants/${secret.merchant_id}`, {
      headers: { authorization: `Bearer ${secret.access_token}` },
    });
    return { ok: response.ok, detail: response.status };
  }
  if (provider === 'shopify') {
    const response = await fetch(`https://${secret.shop_domain}/admin/api/2025-01/shop.json`, {
      headers: { 'x-shopify-access-token': secret.access_token ?? '' },
    });
    return { ok: response.ok, detail: response.status };
  }
  if (!secret.webhook_url || !secret.webhook_secret) return { ok: false, detail: 0 };
  const raw = JSON.stringify({ event: 'handshake' });
  const response = await fetch(secret.webhook_url, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-vw-signature': await sign(secret.webhook_secret, raw),
    },
    body: raw,
  });
  return { ok: response.ok, detail: response.status };
}

async function fetchSquareLocations(secret: Secret) {
  const host = secret.sandbox ? 'https://connect.squareupsandbox.com' : 'https://connect.squareup.com';
  const headers = { authorization: `Bearer ${secret.access_token}`, 'content-type': 'application/json' };
  const locations = await fetch(`${host}/v2/locations`, { headers });
  if (!locations.ok) throw new Error('pull_failed');
  const locationPayload = await locations.json();
  return ((locationPayload.locations ?? []) as Record<string, unknown>[])
    .map((row) => ({ id: String(row.id), name: String(row.name ?? row.id) }));
}

async function pullSquare(secret: Secret, locationId: string) {
  const host = secret.sandbox ? 'https://connect.squareupsandbox.com' : 'https://connect.squareup.com';
  const headers = { authorization: `Bearer ${secret.access_token}`, 'content-type': 'application/json' };
  const sales = [];
  let cursor: string | undefined;
  for (let page = 0; page < 20; page++) {
    const response = await fetch(`${host}/v2/orders/search`, {
      method: 'POST',
      headers,
      body: JSON.stringify(squareSearchBody(locationId, cursor)),
    });
    if (!response.ok) throw new Error('pull_failed');
    const payload = await response.json();
    sales.push(...squareSales(payload, locationId));
    cursor = payload.cursor ? String(payload.cursor) : undefined;
    if (!cursor) return sales;
  }
  throw new Error('pull_failed');
}

async function pushAvailability(provider: string, secret: Secret, payload: Record<string, unknown>) {
  if (!secret.webhook_url) return { ok: false };
  const raw = JSON.stringify(payload);
  const headers: Record<string, string> = { 'content-type': 'application/json' };
  if (secret.webhook_secret) headers['x-vw-signature'] = await sign(secret.webhook_secret, raw);
  const response = await fetch(secret.webhook_url, { method: 'POST', headers, body: raw });
  return { ok: response.ok };
}

async function sign(secret: string, raw: string) {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(raw));
  return [...new Uint8Array(mac)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

function safeEqual(given: string, expected: string) {
  if (given.length !== expected.length) return false;
  let mismatch = 0;
  for (let i = 0; i < given.length; i++) mismatch |= given.charCodeAt(i) ^ expected.charCodeAt(i);
  return mismatch === 0;
}

async function loadSecret(admin: SupabaseClient<any>, connectionId: string) {
  const { data: connection } = await admin
    .from('integration_connections')
    .select('id, organization_id, provider_key, status')
    .eq('id', connectionId)
    .single();
  if (!connection || connection.status !== 'connected') return null;
  const { data: secret } = await admin
    .from('integration_secrets')
    .select('*')
    .eq('connection_id', connectionId)
    .single();
  if (!secret) return null;
  return {
    organizationId: connection.organization_id as string,
    providerKey: connection.provider_key as string,
    secret: secret as Secret,
  };
}

function str(value: unknown) {
  return value == null ? null : String(value);
}

function json(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

type Secret = {
  access_token: string | null;
  client_id: string | null;
  client_secret: string | null;
  merchant_id: string | null;
  shop_domain: string | null;
  webhook_url: string | null;
  webhook_secret: string | null;
  sandbox: boolean;
};
