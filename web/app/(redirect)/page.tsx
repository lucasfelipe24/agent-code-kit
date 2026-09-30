import type { Metadata } from 'next';
import { withBase } from '@/lib/shared';

const english = withBase('/en/');
const portuguese = withBase('/pt-BR/');

// Runs before paint: Portuguese browsers go to /pt-BR/, everyone else to /en/.
const pickLocale = `location.replace(/^pt\\b/i.test(navigator.language) ? ${JSON.stringify(portuguese)} : ${JSON.stringify(english)});`;

export const metadata: Metadata = { title: 'agent-code-kit' };

export default function RootRedirect() {
  return (
    <>
      <meta httpEquiv="refresh" content={`0; url=${english}`} />
      <script dangerouslySetInnerHTML={{ __html: pickLocale }} />
      <main>
        <ul>
          <li>
            <a href={english}>English</a>
          </li>
          <li>
            <a href={portuguese} lang="pt-BR" hrefLang="pt-BR">
              Português
            </a>
          </li>
        </ul>
      </main>
    </>
  );
}
