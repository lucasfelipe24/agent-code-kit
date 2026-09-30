import type { Locale } from './i18n';
import type { TranscriptLine } from '@/components/landing/session-transcript';
import type { LoopStep } from '@/components/landing/loop-diagram';

export type Counts = {
  skills: number;
  moduleSkills: number;
  hooks: number;
  agents: number;
  templates: number;
};

type LandingCopy = {
  title: string;
  lead: string;
  readDocs: string;
  copy: { copy: string; copied: string; failed: string };
  transcriptLabel: string;
  speakers: Record<TranscriptLine['kind'], string>;
  transcript: TranscriptLine[];
  loopHeading: string;
  loopLead: string;
  loop: LoopStep[];
  loopReturn: string;
  enforcedBy: { rule: string; hook: string };
  counts: (c: Counts) => string;
  skillsHeading: string;
  skillsLead: string;
  skillsEmpty: string;
  allSkills: string;
  templatesHeading: string;
  templatesLead: string;
  installHeading: string;
  installLead: string;
  installNpx: string;
  installCurl: string;
  footer: string;
};

// The first two lines protect-changes.sh really prints (see
// .claude/hooks/protect-changes.sh → block_change). Keep them in step. They
// stay English on every locale, marked lang="en".
const blocked: TranscriptLine[] = [
  { kind: 'block', lang: 'en', text: 'BLOCKED by protect-changes.sh: npm install fuse.js' },
  {
    kind: 'block',
    lang: 'en',
    text: 'Reason: new dependency — adding a package requires explicit approval (CLAUDE.md → Protected Changes)',
  },
];

export const landingCopy: Record<Locale, LandingCopy> = {
  en: {
    title: 'Claude plans, stays in scope, and proves the work before it stops.',
    lead: 'agent-code-kit installs rules, hooks and skills into your project. The rules tell Claude how to work. The hooks stop it when it skips a step.',
    readDocs: 'Read the docs',
    copy: { copy: 'Copy', copied: 'Copied', failed: 'Select the command to copy it' },
    transcriptLabel: 'A Claude Code session with the kit: a hook blocks an unapproved dependency.',
    speakers: { user: 'You:', agent: 'Claude:', tool: 'Claude runs:', block: 'Hook output:' },
    transcript: [
      { kind: 'user', text: 'Add a search feature to the users page' },
      { kind: 'agent', text: 'Read CODEBASE_MAP.md. This touches 3 files, so here is the plan. Proceed?' },
      { kind: 'user', text: 'Yes' },
      { kind: 'tool', text: '$ npm install fuse.js' },
      ...blocked,
      {
        kind: 'agent',
        text: 'A new dependency needs your approval. Two options: fuse.js for fuzzy matching, or a filter on the existing query with no new package. Which one?',
      },
    ],
    loopHeading: 'Every task goes through the same four steps',
    loopLead: 'Rules ask Claude to follow the loop. Hooks enforce the steps that can’t be left to good intentions.',
    loop: [
      {
        title: 'Plan',
        body: 'Restates the task as a goal it can check and writes the plan to tasks/todo.md.',
        enforcedBy: 'rule',
      },
      {
        title: 'Confirm',
        body: 'Waits for your go-ahead. A hook blocks new dependencies, migrations and auth changes until you approve.',
        enforcedBy: 'hook',
      },
      {
        title: 'Implement',
        body: 'Touches only the files the task needs. Each code edit is typechecked or linted as it is made.',
        enforcedBy: 'hook',
      },
      {
        title: 'Verify',
        body: 'Typecheck, lint, tests, smoke test. A hook stops the task from ending while an edited file’s typecheck or lint is failing.',
        enforcedBy: 'hook',
      },
    ],
    loopReturn: 'The next task starts at Plan again.',
    enforcedBy: { rule: 'Asked by a rule', hook: 'Enforced by a hook' },
    counts: (c) =>
      `${c.skills} skills, ${c.hooks} hooks, ${c.agents} agents and ${c.templates} stack templates. All of it is Markdown and shell.`,
    skillsHeading: 'Skills you run with /name',
    skillsLead: 'Grouped by where they fit in the work.',
    skillsEmpty: 'The skill list isn’t available in this build.',
    allSkills: 'All skills',
    templatesHeading: 'Stack templates',
    templatesLead: 'The installer detects your stack and adds its rules to CLAUDE.md, plus a pre-filled CODEBASE_MAP.md.',
    installHeading: 'Install it in your project',
    installLead: 'Run this in your project root. Your own CLAUDE.md, settings, hooks and agents stay as they are.',
    installNpx: 'npx',
    installCurl: 'curl',
    footer: 'MIT licensed.',
  },
  'pt-BR': {
    title: 'O Claude planeja, fica no escopo e comprova o trabalho antes de parar.',
    lead: 'O agent-code-kit instala regras, hooks e skills no seu projeto. As regras dizem ao Claude como trabalhar. Os hooks o interrompem quando ele pula uma etapa.',
    readDocs: 'Ler a documentação',
    copy: { copy: 'Copiar', copied: 'Copiado', failed: 'Selecione o comando para copiar' },
    transcriptLabel: 'Uma sessão do Claude Code com o kit: um hook bloqueia uma dependência não aprovada.',
    speakers: { user: 'Você:', agent: 'Claude:', tool: 'Claude executa:', block: 'Saída do hook:' },
    transcript: [
      { kind: 'user', text: 'Adicione uma busca na página de usuários' },
      { kind: 'agent', text: 'Li o CODEBASE_MAP.md. Isso toca 3 arquivos, então aqui está o plano. Posso seguir?' },
      { kind: 'user', text: 'Sim' },
      { kind: 'tool', text: '$ npm install fuse.js' },
      ...blocked,
      {
        kind: 'agent',
        text: 'Uma dependência nova precisa da sua aprovação. Duas opções: fuse.js para busca aproximada, ou um filtro na consulta que já existe, sem pacote novo. Qual prefere?',
      },
    ],
    loopHeading: 'Toda tarefa passa pelas mesmas quatro etapas',
    loopLead: 'As regras pedem que o Claude siga o ciclo. Os hooks garantem as etapas que não podem depender de boa vontade.',
    loop: [
      {
        title: 'Planejar',
        body: 'Reescreve a tarefa como um objetivo verificável e registra o plano em tasks/todo.md.',
        enforcedBy: 'rule',
      },
      {
        title: 'Confirmar',
        body: 'Espera o seu ok. Um hook bloqueia dependências novas, migrations e mudanças de autenticação até você aprovar.',
        enforcedBy: 'hook',
      },
      {
        title: 'Implementar',
        body: 'Mexe só nos arquivos que a tarefa precisa. Cada edição de código passa por typecheck ou lint na hora.',
        enforcedBy: 'hook',
      },
      {
        title: 'Verificar',
        body: 'Typecheck, lint, testes, smoke test. Um hook impede o fim da tarefa enquanto o typecheck ou o lint de um arquivo editado estiver falhando.',
        enforcedBy: 'hook',
      },
    ],
    loopReturn: 'A próxima tarefa começa de novo em Planejar.',
    enforcedBy: { rule: 'Pedido por uma regra', hook: 'Garantido por um hook' },
    counts: (c) =>
      `${c.skills} skills, ${c.hooks} hooks, ${c.agents} agentes e ${c.templates} templates de stack. Tudo em Markdown e shell.`,
    skillsHeading: 'Skills que você roda com /nome',
    skillsLead: 'Agrupadas pelo momento do trabalho em que entram.',
    skillsEmpty: 'A lista de skills não está disponível nesta versão do site.',
    allSkills: 'Todas as skills',
    templatesHeading: 'Templates de stack',
    templatesLead: 'O instalador detecta a sua stack e adiciona as regras dela ao CLAUDE.md, além de um CODEBASE_MAP.md já preenchido.',
    installHeading: 'Instale no seu projeto',
    installLead: 'Rode na raiz do projeto. O seu CLAUDE.md, suas configurações, hooks e agentes continuam como estão.',
    installNpx: 'npx',
    installCurl: 'curl',
    footer: 'Licença MIT.',
  },
};
