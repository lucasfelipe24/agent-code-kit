import { IBM_Plex_Mono, IBM_Plex_Sans, IBM_Plex_Sans_Condensed } from 'next/font/google';
import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { Provider } from '@/components/provider';
import { i18n, isLocale } from '@/lib/i18n';
import { withBase } from '@/lib/shared';
import '../global.css';

const sans = IBM_Plex_Sans({
  subsets: ['latin'],
  weight: ['400', '500', '600'],
  variable: '--font-plex-sans',
});

const condensed = IBM_Plex_Sans_Condensed({
  subsets: ['latin'],
  weight: ['600'],
  variable: '--font-plex-condensed',
});

const mono = IBM_Plex_Mono({
  subsets: ['latin'],
  weight: ['400', '500'],
  variable: '--font-plex-mono',
});

export const metadata: Metadata = {
  title: {
    template: '%s | agent-code-kit',
    default: 'agent-code-kit',
  },
  icons: { icon: withBase('/mark.png') },
};

export function generateStaticParams() {
  return i18n.languages.map((lang) => ({ lang }));
}

export default async function Layout({ children, params }: LayoutProps<'/[lang]'>) {
  const { lang } = await params;
  if (!isLocale(lang)) notFound();

  return (
    <html
      lang={lang}
      className={`${sans.variable} ${condensed.variable} ${mono.variable}`}
      suppressHydrationWarning
    >
      <body className="flex flex-col min-h-screen">
        <Provider lang={lang}>{children}</Provider>
      </body>
    </html>
  );
}
