import type { ReactNode } from 'react';

// Root layout for `/` only: a static export has no middleware, so this page
// picks the locale in the browser. The site itself lives under app/[lang]/.
export default function RedirectLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
