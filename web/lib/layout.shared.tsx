import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import { uiTranslations } from 'fumadocs-ui/i18n';
import { i18n } from './i18n';
import { appName, repoUrl, withBase } from './shared';

export const translations = i18n
  .translations()
  .extend(uiTranslations())
  .add({
    en: {
      displayName: 'English',
    },
    'pt-BR': {
      displayName: 'Português (Brasil)',
      'Back to Home(404 not found page)': 'Voltar ao início',
      'Choose a language(language switcher)': 'Escolha um idioma',
      'Choose a language(language switcher)(aria-label)': 'Escolha um idioma',
      'Close Banner(banner)(aria-label)': 'Fechar aviso',
      'Close Search(search dialog)(aria-label)': 'Fechar busca',
      'Close Sidebar(aria-label)': 'Fechar barra lateral',
      'Close Sidebar(sidebar)(aria-label)': 'Fechar barra lateral',
      'Collapse Sidebar(sidebar)(aria-label)': 'Recolher barra lateral',
      'Copied Anchor Link(heading anchor)(aria-label)': 'Link da seção copiado',
      'Copied Link(accordion)(aria-label)': 'Link copiado',
      'Copied Markdown(page actions)': 'Markdown copiado',
      'Copied Text(code block)(aria-label)': 'Texto copiado',
      'Copy Anchor Link(heading anchor)(aria-label)': 'Copiar link da seção',
      'Copy Link(accordion)(aria-label)': 'Copiar link',
      'Copy Markdown(page actions)': 'Copiar Markdown',
      'Copy Text(code block)(aria-label)': 'Copiar texto',
      'Dark(theme switcher)(aria-label)': 'Escuro',
      'Default(type table)': 'Padrão',
      'Edit on GitHub(edit page)': 'Editar no GitHub',
      'Hide Sidebar(sidebar)': 'Ocultar barra lateral',
      'Last updated on(page footer)': 'Atualizado em',
      'Layout Tab(layout tab trigger)': 'Aba de layout',
      'Light(theme switcher)(aria-label)': 'Claro',
      'Next Page(pagination)': 'Próxima',
      'No Headings(table of contents)': 'Sem seções',
      'No results found(search dialog)': 'Nenhum resultado',
      'On this page(table of contents)': 'Nesta página',
      'Open Search(search trigger)(aria-label)': 'Abrir busca',
      'Open Sidebar(aria-label)': 'Abrir barra lateral',
      'Open Sidebar(sidebar)(aria-label)': 'Abrir barra lateral',
      'Open in ChatGPT(page actions)': 'Abrir no ChatGPT',
      'Open in Claude(page actions)': 'Abrir no Claude',
      'Open in Cursor(page actions)': 'Abrir no Cursor',
      'Open in GitHub(page actions)': 'Abrir no GitHub',
      'Open in Scira AI(page actions)': 'Abrir no Scira AI',
      'Open(page actions)': 'Abrir',
      'Page Not Found(404 not found page)': 'Página não encontrada',
      'Parameters(type table)': 'Parâmetros',
      'Previous Page(pagination)': 'Anterior',
      'Prop(type table)': 'Prop',
      'Read {url}, I want to ask questions about it.(page actions)':
        'Leia {url}, quero fazer perguntas sobre ela.',
      'Returns(type table)': 'Retorno',
      'Search(search dialog)': 'Buscar',
      'Search(search trigger)': 'Buscar',
      'Show Sidebar(sidebar)': 'Mostrar barra lateral',
      'System(theme switcher)(aria-label)': 'Sistema',
      'Table of Contents(inline table of contents)': 'Sumário',
      'The page you are looking for might have been removed, had its name changed, or is temporarily unavailable.(404 not found page)':
        'A página que você procura pode ter sido removida, renomeada ou está temporariamente indisponível.',
      'Toggle Menu(home layout header)(aria-label)': 'Abrir menu',
      'Toggle Theme(theme switcher)(aria-label)': 'Alternar tema',
      'Type(type table)': 'Tipo',
      'View as Markdown(page actions)': 'Ver como Markdown',
    },
  });

const docsLabel: Record<string, string> = { en: 'Docs', 'pt-BR': 'Documentação' };

export function baseOptions(locale: string): BaseLayoutProps {
  return {
    i18n: true,
    nav: {
      title: (
        <span className="flex items-center gap-2 font-semibold">
          {/* eslint-disable-next-line @next/next/no-img-element -- static export, no image optimizer */}
          <img src={withBase('/mark.png')} alt="" width={24} height={24} />
          {appName}
        </span>
      ),
      url: `/${locale}`,
    },
    links: [{ text: docsLabel[locale] ?? docsLabel.en, url: `/${locale}/docs`, active: 'nested-url' }],
    githubUrl: repoUrl,
  };
}
