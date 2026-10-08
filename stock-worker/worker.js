// SrTortilla live stock counter - Cloudflare Worker
//
// The store page calls  https://<your-worker>.workers.dev/?ids=18,19,20
// and gets back         { "18": 1, "19": 0, "20": null }
// (a number = copies left, null = Snipcart isn't tracking stock for that product yet).
//
// Settings in Cloudflare (Worker > Settings > Variables and Secrets):
//   SNIPCART_SECRET  (Secret)  your Snipcart *secret* API key - never put it in index.html
//   ALLOWED_ORIGIN   (Text)    https://srtortilla.art

const CACHE_SECONDS = 30;

export default {
  async fetch(request, env, ctx) {
    const origin = env.ALLOWED_ORIGIN || 'https://srtortilla.art';
    const headers = {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': origin,
      'Cache-Control': `public, max-age=${CACHE_SECONDS}`,
    };

    if (request.method === 'OPTIONS') return new Response(null, { headers });
    if (request.method !== 'GET') return new Response('Method not allowed', { status: 405, headers });

    // Only accept short numeric product ids, at most 50 per request
    const url = new URL(request.url);
    const ids = (url.searchParams.get('ids') || '')
      .split(',')
      .filter(id => /^\d{1,6}$/.test(id))
      .slice(0, 50);
    if (ids.length === 0) return new Response('{}', { headers });

    const cache = caches.default;
    const cacheKey = new Request(`${url.origin}/?ids=${ids.join(',')}`);
    const cached = await cache.match(cacheKey);
    if (cached) return cached;

    const auth = 'Basic ' + btoa(env.SNIPCART_SECRET + ':');
    const entries = await Promise.all(ids.map(async id => {
      try {
        const res = await fetch(`https://app.snipcart.com/api/products/${id}`, {
          headers: { Authorization: auth, Accept: 'application/json' },
        });
        if (!res.ok) return [id, null];
        const product = await res.json();
        return [id, typeof product.stock === 'number' ? product.stock : null];
      } catch {
        return [id, null];
      }
    }));

    const response = new Response(JSON.stringify(Object.fromEntries(entries)), { headers });
    ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  },
};
