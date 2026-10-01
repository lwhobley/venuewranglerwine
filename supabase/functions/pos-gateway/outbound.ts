// Outbound URL policy for user-supplied hosts. Literal-host checks only: it does not
// resolve DNS, so it blocks obvious internal targets rather than rebinding attacks.
const blockedSuffixes = ['.local', '.internal', '.localhost', '.lan', '.home.arpa'];

function privateIpv4(host: string) {
  const parts = host.split('.').map(Number);
  if (parts.length !== 4 || parts.some((n) => !Number.isInteger(n) || n < 0 || n > 255)) return false;
  const [a, b] = parts;
  return a === 0 || a === 10 || a === 127 || (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127);
}

export function isSafeOutboundHost(host: string) {
  const name = host.toLowerCase().replace(/\.$/, '');
  if (!name || name === 'localhost') return false;
  if (name.startsWith('[') || name.includes(':')) return false; // IPv6 literals
  if (/^[0-9.]+$/.test(name)) return !privateIpv4(name) && name.split('.').length === 4;
  if (!name.includes('.')) return false;
  return !blockedSuffixes.some((suffix) => name.endsWith(suffix));
}

export function safeOutboundUrl(value: string | null | undefined): URL | null {
  if (!value) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:' || url.username || url.password) return null;
    return isSafeOutboundHost(url.hostname) ? url : null;
  } catch (_error) {
    return null;
  }
}

export function isShopifyDomain(value: string | null | undefined) {
  return !!value && /^[a-z0-9][a-z0-9-]*\.myshopify\.com$/i.test(value);
}
