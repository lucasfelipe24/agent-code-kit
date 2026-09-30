import { createMDX } from 'fumadocs-mdx/next';

const withMDX = createMDX();

// GitHub Pages serves the repo's site under /agent-code-kit. Keep in step with
// lib/shared.ts, which reads the same variable for URLs fetched at runtime.
const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? '/agent-code-kit';

/** @type {import('next').NextConfig} */
const config = {
  output: 'export',
  basePath,
  env: { NEXT_PUBLIC_BASE_PATH: basePath },
  trailingSlash: true,
  images: { unoptimized: true },
  reactStrictMode: true,
};

export default withMDX(config);
