/**
 * Bases for the four public data APIs the client reads from.
 *
 * Dev (vite proxy) and Vercel (vercel.json rewrites) expose them under
 * same-origin `/api/*` paths. GitHub Pages has no rewrite layer, so that build
 * sets VITE_DIRECT_UPSTREAM=1 and the browser calls each origin directly.
 * All four upstreams answer with `Access-Control-Allow-Origin: *`.
 */
const DIRECT = import.meta.env.VITE_DIRECT_UPSTREAM === "1";

export const UNIPROT_BASE = DIRECT ? "https://rest.uniprot.org" : "/api/uniprot";
export const RCSB_SEARCH_BASE = DIRECT ? "https://search.rcsb.org" : "/api/rcsb-search";
export const RCSB_FILES_BASE = DIRECT ? "https://files.rcsb.org" : "/api/rcsb-files";
export const ALPHAFOLD_BASE = DIRECT ? "https://alphafold.ebi.ac.uk" : "/api/alphafold";
