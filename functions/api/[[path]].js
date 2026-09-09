// Cloudflare Pages Function: proxies the external structural-biology APIs that
// vercel.json handled with rewrites. Pages Functions run before static assets,
// so this intercepts /api/* before the SPA fallback in _redirects can swallow it.
//
// Mirrors the dev-server proxies in vite.config.ts and the rewrites in
// vercel.json: the /api/<prefix> segment is stripped and the rest is forwarded.

const PROXY_TARGETS = {
  uniprot: "https://rest.uniprot.org",
  "rcsb-search": "https://search.rcsb.org",
  "rcsb-files": "https://files.rcsb.org",
  alphafold: "https://alphafold.ebi.ac.uk",
};

export async function onRequest({ request, params }) {
  const segments = Array.isArray(params.path)
    ? params.path
    : [params.path].filter(Boolean);
  const [prefix, ...rest] = segments;
  const base = PROXY_TARGETS[prefix];

  // Routes served by the Express server (/api/ai, /api/phaeleon,
  // /api/workflow) have no equivalent on a static deploy. Answer with JSON so
  // callers fail cleanly instead of parsing the SPA's HTML.
  if (!base) {
    return Response.json(
      {
        error: "not_implemented",
        message: `/api/${segments.join("/")} is not available on this static deployment.`,
      },
      { status: 501 },
    );
  }

  const incoming = new URL(request.url);
  const target = `${base}/${rest.join("/")}${incoming.search}`;

  const headers = new Headers(request.headers);
  headers.delete("host");
  headers.delete("cookie");

  const upstream = await fetch(target, {
    method: request.method,
    headers,
    body:
      request.method === "GET" || request.method === "HEAD"
        ? undefined
        : request.body,
    redirect: "follow",
  });

  // Strip hop-by-hop encoding headers; the body is re-streamed by the runtime.
  const responseHeaders = new Headers(upstream.headers);
  responseHeaders.delete("content-encoding");
  responseHeaders.delete("content-length");

  return new Response(upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers: responseHeaders,
  });
}
