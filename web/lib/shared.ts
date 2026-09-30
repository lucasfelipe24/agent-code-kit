export const appName = 'agent-code-kit';
export const docsRoute = '/docs';
export const docsContentRoute = '/llms.mdx/docs';

// GitHub Pages serves the site under /<repo>. Next's <Link> applies basePath on
// its own; anything fetched by URL (search index, page markdown) needs withBase().
export const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? '/agent-code-kit';

export function withBase(path: string): string {
  return `${basePath}${path}`;
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
