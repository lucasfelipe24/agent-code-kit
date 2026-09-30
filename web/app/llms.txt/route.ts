import { withBaseLinks } from '@/lib/shared';
import { docsLlms } from '@/lib/source';

export const revalidate = false;

// index() lists page links itself (not through renderPage), so prefix them here.
export async function GET() {
  return new Response(withBaseLinks(await docsLlms.index()));
}
