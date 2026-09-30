import { llms, loader } from 'fumadocs-core/source';
import { defineDocs } from 'fumadocs-mdx/macro';
import { metaSchema, pageSchema } from 'fumadocs-core/source/schema';
import { docsRoute, withBase, withBaseLinks } from './shared';
import { i18n } from './i18n';

const docs = defineDocs({
  dir: 'content/docs',
  docs: {
    // `source`: repo path of the file a generated page was built from (optional string).
    schema: pageSchema.extend({ source: pageSchema.shape.description }),
    postprocess: {
      includeProcessedMarkdown: true,
    },
  },
  meta: {
    schema: metaSchema,
  },
});

// See https://fumadocs.dev/docs/headless/source-api for more info
export const source = loader({
  baseUrl: docsRoute,
  source: docs.toFumadocsSource(),
  i18n,
  plugins: [],
});

export const docsLlms = llms(source, {
  renderPage: async (page) =>
    withBaseLinks(`# ${page.data.title} (${withBase(page.url)})

${await page.data.getText('processed')}`),
});
