import { source } from '@/lib/source';
import { DocsLayout } from 'fumadocs-ui/layouts/docs';
import { baseOptions } from '@/lib/layout.shared';

export default async function Layout({ children, params }: LayoutProps<'/[lang]/docs'>) {
  const { lang } = await params;

  return (
    // The nav's "Docs" link would repeat the sidebar's root here: drop it.
    <DocsLayout tree={source.getPageTree(lang)} {...baseOptions(lang)} links={[]}>
      {children}
    </DocsLayout>
  );
}
