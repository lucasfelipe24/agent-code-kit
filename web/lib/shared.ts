export const appName = 'agent-code-kit';
export const docsRoute = '/docs';
export const docsContentRoute = '/llms.mdx/docs';

// GitHub Pages serves the site under /<repo>. Next's <Link> applies basePath on
// its own; anything fetched by URL (search index, page markdown) needs withBase().
export const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? '/agent-code-kit';

export function withBase(path: string): string {
  return `${basePath}${path}`;
}

// Markdown served as text (llms.txt, page .md) has no <Link> to add basePath,
// so prefix root-relative inline link targets: `](/en/…` → `](/<repo>/en/…`.
// Code fences and inline code are left as written; `](//host` and targets that
// already carry the base path are skipped, so applying it twice is harmless.
const rootLink = new RegExp(`\\]\\(/(?!/|${basePath.slice(1)}/)`, 'g');

export function withBaseLinks(markdown: string): string {
  let fence = false;
  return markdown
    .split('\n')
    .map((line) => {
      if (/^\s*(```|~~~)/.test(line)) fence = !fence;
      if (fence || !line.includes('](/')) return line;
      return line
        .split(/(`[^`]*`)/)
        .map((part, i) => (i % 2 ? part : part.replace(rootLink, `](${basePath}/`)))
        .join('');
    })
    .join('\n');
}

export const gitConfig = {
  user: 'lucasfelipe24',
  repo: 'agent-code-kit',
  branch: 'main',
};

export const repoUrl = `https://github.com/${gitConfig.user}/${gitConfig.repo}`;
export const npxCommand = 'npx @lucasfelipe23/agent-code-kit init';
export const curlCommand = `curl -fsSL https://raw.githubusercontent.com/${gitConfig.user}/${gitConfig.repo}/main/install.sh | bash`;

export function getPageMarkdownUrl(page: { slugs: string[]; locale?: string }) {
  const segments = [...page.slugs, 'content.md'];
  const locale = page.locale ? `/${page.locale}` : '';

  return { segments, url: withBase(`${locale}${docsContentRoute}/${segments.join('/')}`) };
}
