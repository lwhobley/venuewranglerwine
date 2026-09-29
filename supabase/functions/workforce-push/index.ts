import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type ServiceAccount = { project_id: string; client_email: string; private_key: string };
type OutboxItem = {
  id: string; tokens: string[];
  notification: { title: string; shift_id: string | null };
};
const encode = (value: Uint8Array) => btoa(String.fromCharCode(...value))
  .replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
async function accessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const encoder = new TextEncoder();
  const header = encode(encoder.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = encode(encoder.encode(JSON.stringify({
    iss: account.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
  })));
  const pem = account.private_key.replace(/-----[^-]+-----|\s/g, '');
  const key = await crypto.subtle.importKey('pkcs8',
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const unsigned = `${header}.${claims}`;
  const signature = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoder.encode(unsigned)));
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${unsigned}.${encode(signature)}` }),
  });
  if (!response.ok) throw new Error('fcm_auth_failed');
  const data = await response.json();
  if (typeof data.access_token !== 'string') throw new Error('fcm_auth_failed');
  return data.access_token;
}

Deno.serve(async (request) => {
  const secret = Deno.env.get('WORKFORCE_PUSH_JOB_SECRET');
  if (request.method !== 'POST') return Response.json({ error: 'method_not_allowed' }, { status: 405 });
  // This endpoint is invoked by the scheduled worker, never by employee clients.
  const supplied = request.headers.get('Authorization') ?? '';
  if (!secret || supplied !== `Bearer ${secret}`) return Response.json({ error: 'unauthorized' }, { status: 401 });
  const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
  const { data: pending, error } = await client.rpc('workforce_outbox_claim');
  if (error) return Response.json({ error: 'outbox_claim_failed' }, { status: 503 });
  const items = pending as OutboxItem[];
  let account: ServiceAccount | undefined;
  let token: string | undefined;
  try {
    if (raw) {
      account = JSON.parse(raw);
      if (account?.project_id !== 'venuewranglerwine') throw new Error('fcm_project_mismatch');
      token = await accessToken(account);
    }
  } catch {
    for (const item of items) await client.rpc('workforce_outbox_complete', { p_id: item.id, p_status: 'failed', p_error: 'fcm_auth_failed' });
    return Response.json({ error: 'fcm_auth_failed' }, { status: 503 });
  }
  let sent = 0;
  for (const item of items) {
    if (!account || !token) {
      await client.rpc('workforce_outbox_complete', { p_id: item.id, p_status: 'unconfigured', p_error: 'fcm_credentials_missing' });
      continue;
    }
    let successful = 0;
    let failed = false;
    for (const device of item.tokens) {
      try {
        const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
          method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: {
            token: device, notification: { title: 'Venue Wrangler schedule update', body: 'Open your schedule to review.' },
            data: { notification_id: item.id, ...(item.notification.shift_id ? { shift_id: item.notification.shift_id } : {}) },
            android: { priority: 'high', notification: { channel_id: 'workforce', tag: item.id } },
            apns: { headers: { 'apns-collapse-id': item.id }, payload: { aps: { sound: 'default' } } },
          } }),
        });
        if (response.ok) successful++;
        else {
          const detail = await response.json();
          const unregistered = detail?.error?.details?.some((x: { errorCode?: string }) => x.errorCode === 'UNREGISTERED');
          if (unregistered) await client.from('push_devices').update({ enabled: false }).eq('token', device);
          else failed = true;
        }
      } catch { failed = true; }
    }
    // No registered device is not evidence of delivery.
    const state = successful > 0 && !failed ? 'sent' : failed ? 'failed' : 'unconfigured';
    await client.rpc('workforce_outbox_complete', { p_id: item.id, p_status: state, p_error: state === 'sent' ? null : 'no_confirmed_delivery' });
    if (state === 'sent') sent++;
  }
  return Response.json({ processed: items.length, sent });
});
