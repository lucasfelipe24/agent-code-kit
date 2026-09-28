<p align="center">
  <img src="assets/logo.png" alt="Logo do Agent Code Kit" width="160">
</p>

<h1 align="center">Bem-vindo ao Agent Code Kit 👋</h1>

<p align="center">
  <a href="https://www.npmjs.com/package/@lucasfelipe23/agent-code-kit">
    <img alt="versão no npm" src="https://img.shields.io/npm/v/@lucasfelipe23/agent-code-kit.svg">
  </a>
  <a href="https://www.npmjs.com/package/@lucasfelipe23/agent-code-kit">
    <img alt="downloads no npm" src="https://img.shields.io/npm/dm/@lucasfelipe23/agent-code-kit.svg?color=blue">
  </a>
  <a href="#pré-requisitos">
    <img alt="versão do node" src="https://img.shields.io/node/v/@lucasfelipe23/agent-code-kit.svg">
  </a>
  <a href="https://github.com/lucasfelipe24/agent-code-kit/actions/workflows/validate.yml">
    <img alt="CI" src="https://github.com/lucasfelipe24/agent-code-kit/actions/workflows/validate.yml/badge.svg">
  </a>
  <a href="https://github.com/lucasfelipe24/agent-code-kit/graphs/commit-activity">
    <img alt="Mantido" src="https://img.shields.io/badge/Maintained%3F-yes-green.svg">
  </a>
  <a href="LICENSE">
    <img alt="Licença: MIT" src="https://img.shields.io/github/license/lucasfelipe24/agent-code-kit">
  </a>
  <a href="README.md">
    <img alt="Read in English" src="https://img.shields.io/badge/lang-en-blue">
  </a>
</p>

> **Guardrails para o Claude Code.** Ele planeja antes de codar, fica dentro do escopo que você aprovou e não consegue dar uma tarefa como concluída enquanto uma verificação estiver falhando.

<p align="center">
  <a href="#-demo">Demo</a> ·
  <a href="#-início-rápido">Início rápido</a> ·
  <a href="#-como-funciona">Como funciona</a> ·
  <a href="#-skills-e-agentes">Skills</a> ·
  <a href="#-configuração">Configuração</a> ·
  <a href="#-perguntas-frequentes">Perguntas frequentes</a>
</p>

```bash
npx @lucasfelipe23/agent-code-kit init
```

## ✨ Demo

Peça "Adicione uma busca na página de usuários" sem o kit e você recebe três pacotes novos, um módulo de usuários refatorado que você não pediu e um build quebrado que ninguém verificou.

Com o kit:

```text
Você:   Adicione uma busca na página de usuários

Claude: Li o CODEBASE_MAP.md — a página é app/(dashboard)/users/page.tsx e os
        dados vêm de src/services/user.service.ts. Isso mexe em 3 arquivos,
        então aqui está o plano:

        1. Tratar um parâmetro de busca em users/page.tsx
        2. Adicionar searchUsers() em user.service.ts
        3. Adicionar um componente de campo de busca (arquivo novo)

        Posso seguir?

Você:   Sim

Claude: [implementa e depois roda]
        tsc --noEmit ✓   eslint ✓   npm test ✓   abri a página, a busca funciona ✓
        Pronto — todas as verificações passaram.
```

## 🤔 Por quê

O Claude Code é capaz, mas afobado. Por conta própria, ele vai:

- começar a editar antes de entender o seu código
- "melhorar" arquivos em que você nunca pediu para mexer
- adicionar uma dependência ou mudar o seu schema sem perguntar
- dizer "pronto" sem rodar uma única verificação
- repetir o erro que você corrigiu ontem

Um prompt dizendo "não faça isso" ajuda — até o modelo ignorá-lo. O Agent Code Kit entrega as regras **e** o mecanismo que as faz valer.

## 🚀 Início rápido

### Pré-requisitos

- [Claude Code](https://code.claude.com/docs)
- Node.js 18 ou mais recente
- bash — macOS, Linux ou WSL no Windows

### Instalação

Rode na raiz do seu projeto:

```bash
npx @lucasfelipe23/agent-code-kit init
```

O instalador detecta a sua stack e escolhe um [template](#templates-de-stack) correspondente.

<details>
<summary>Prefere não usar Node.js? Instale com curl</summary>

O instalador roda direto do GitHub (ele precisa de git e bash):

```bash
curl -fsSL https://raw.githubusercontent.com/lucasfelipe24/agent-code-kit/main/install.sh | bash
```

Passe as mesmas opções depois de `bash -s --`, por exemplo `| bash -s -- --profile strict`, ou `--version v1.22.3` para uma versão específica.

</details>

### Uso

1. **Descreva o seu projeto** no `CODEBASE_MAP.md`: o que ele faz, onde ficam as coisas, como rodá-lo. O Claude o lê no início de toda sessão, então quanto melhor ele estiver, melhor o Claude trabalha. `./scripts/validate.sh` lista os placeholders que você ainda não preencheu.

2. **Verifique a instalação:**

   ```bash
   npx @lucasfelipe23/agent-code-kit doctor
   ```

   O doctor confere os arquivos e as configurações e depois roda um autoteste dos hooks num projeto descartável.

3. **Abra o Claude Code** normalmente. Não há comando novo para aprender — as regras e os hooks já estão ativos.

## 🧩 Como funciona

O kit adiciona quatro camadas ao seu projeto:

| Camada | O que é | O que faz |
|---|---|---|
| **Regras** | `CLAUDE.md` | Um fluxo fixo — planejar, confirmar, implementar, verificar — que o Claude segue em toda sessão |
| **Guardrails** | 28 hooks que o Claude Code executa a cada ação | Bloqueiam o que as regras proíbem: editar segredos, dar push na `main`, encerrar com uma verificação falhando |
| **Skills e agentes** | 37 skills e 6 subagentes | Auditorias, debugging, revisões e releases — executados quando você pede |
| **Memória** | `tasks/` | O plano, as decisões, as lições e os handoffs que passam de uma sessão para a outra |

Regras são conselhos. Hooks são imposição: rodam fora do modelo, em toda ação correspondente, quer ele se lembre da regra ou não.

## 📏 As regras

O `CLAUDE.md` dá ao Claude um fluxo de trabalho para seguir em toda sessão:

| Regra | O que o Claude faz |
|---|---|
| **Planejar primeiro** | Para mudanças em 3+ arquivos, escreve um plano em `tasks/todo.md` e espera o seu sinal verde |
| **Disciplina de escopo** | Mexe só no que a tarefa precisa; registra qualquer outra coisa que notar em "Not Now" |
| **Mudanças protegidas** | Para antes de novas dependências e de mudanças em schema, API, autenticação ou build; apresenta opções e registra a sua escolha como uma decisão |
| **Verificação** | Roda typecheck, lint, testes e um smoke test, nessa ordem, antes de dar uma tarefa como concluída |
| **Lições** | Quando você o corrige, escreve uma lição em `tasks/lessons/` e revisa as regras principais no início de cada sessão |
| **Contexto em camadas** | Carrega o mapa do projeto em toda sessão, o plano e o handoff só ao retomar um trabalho, e as lições e decisões só quando são relevantes |

Coloque as suas próprias regras no `CLAUDE.project.md` — elas têm prioridade sobre as do kit.

## 🚧 Guardrails

Hooks são scripts shell que o Claude Code executa em pontos fixos: antes de uma chamada de ferramenta, depois de uma edição, quando o Claude tenta encerrar. Um hook bloqueante interrompe a ação e diz ao Claude por quê.

| Hook | O que ele bloqueia |
|---|---|
| `protect-files` | Edições em arquivos `.env`, credenciais, chaves privadas e lock files |
| `protect-changes` | Edições em manifestos de dependências, migrations, código de autenticação e workflows de CI até você aprovar a mudança |
| `branch-protect` | Pushes para `main`/`master` e force pushes |
| `block-dangerous-commands` | `rm -rf /`, `git reset --hard`, `DROP TABLE` e similares |
| `conventional-commit` | Mensagens de commit fora do padrão [Conventional Commits](https://www.conventionalcommits.org/) |
| `quality-gate` + `stop-gate` | Encerrar enquanto o typecheck, o lint ou a checagem de sintaxe de um arquivo editado estiver falhando |
| `mcp-gate` | Chamadas a servidores MCP que não estão na sua allowlist (desligado até você criar `.claude/mcp-allowlist.txt`) |

O perfil padrão liga 23 dos 28 hooks. Os que não aparecem acima observam em vez de bloquear: alertam sobre segredos e Unicode invisível nas edições, detectam loops de edição e saídas de ferramenta grandes demais, reinjetam o seu plano depois de uma compactação de contexto e mantêm um log da sessão para o `/scorecard`. Depois da instalação, `agent_docs/hooks.md` descreve cada hook e como escrever os seus.

Os hooks são testados — veja [Rodar os testes](#-rodar-os-testes).

## 🧰 Skills e agentes

Skills são comandos que você roda no Claude Code com `/nome`. Algumas boas para começar:

| Skill | O que faz |
|---|---|
| `/capabilities` | Mostra tudo o que o kit disponibiliza neste projeto |
| `/debug` | Encontra a causa raiz antes de mexer no código e depois adiciona um teste de regressão |
| `/review-pipeline` | Roda várias auditorias sobre o seu diff em paralelo e junta os achados num único relatório |
| `/ship` | Testes, changelog, commits limpos e um pull request |
| `/office-hours` | Esclarece o que construir e por quê, antes de qualquer código |

<details>
<summary>Todas as 37 skills</summary>

**Planejar**

| Skill | O que faz |
|---|---|
| `/office-hours` | Esclarece o que construir e por quê, antes de qualquer código |
| `/shape-spec` | Cria uma pasta de spec para uma feature que se estende por várias sessões |
| `/interface-design` | Faz subagentes em paralelo desenharem interfaces concorrentes e depois as compara |
| `/feature-cycle` | Roda spec → plano → build → verificação → revisão → ship de ponta a ponta, parando em qualquer gate que falhar |

**Construir e depurar**

| Skill | O que faz |
|---|---|
| `/debug` | Encontra a causa raiz antes de mexer no código e depois adiciona um teste de regressão |
| `/ui-component-builder` | Constrói um componente de UI com acessibilidade, estados de carregamento/vazio/erro e layout responsivo |
| `/refactoring-guide` | Planeja uma refatoração passo a passo, com o risco de cada passo |
| `/web-read` | Transforma uma página web em markdown limpo, usando menos tokens que um fetch bruto |

**Revisar e auditar**

| Skill | O que faz |
|---|---|
| `/review-pipeline` | Roda várias auditorias sobre o seu diff em paralelo e junta os achados num único relatório |
| `/code-quality-audit` | Code smells, tratamento de erros e manutenibilidade |
| `/architecture-review` | Fronteiras entre módulos, dependências e SOLID |
| `/deepening-review` | Encontra módulos rasos, que só repassam chamadas, e trabalha no que você escolher |
| `/performance-audit` | Gargalos de inicialização, renderização, memória e I/O |
| `/testing-audit` | Cobertura, qualidade e testes instáveis (flaky) |
| `/dead-code-audit` | Funções, imports e arquivos sem uso |
| `/dependency-audit` | Vulnerabilidades, versões desatualizadas, licenças e excesso de dependências |
| `/accessibility-audit` | Conformidade com a WCAG 2.1 AA |
| `/design-review` | Consistência visual e comportamento responsivo de uma UI já construída |
| `/documentation-audit` | Qualidade de comentários, documentação de API e README |
| `/doc-gardening` | Documentação que ficou defasada em relação ao código |
| `/mcp-audit` | Os seus servidores MCP comparados com a allowlist, com os riscos de cada um |
| `/quality-audit` | O seu código comparado com o seu `golden-principles.yaml` |
| `/project-health-report` | Um retrato do projeto inteiro cobrindo tudo o que está acima |

**Entregar**

| Skill | O que faz |
|---|---|
| `/ship` | Testes, changelog, commits limpos e um pull request |
| `/verification-status` | Quais verificações rodaram na tarefa atual, mais as manuais que ainda faltam |

**Memória e relatórios**

| Skill | O que faz |
|---|---|
| `/note` | Salva um achado ou uma decisão para que sobreviva a uma compactação de contexto |
| `/lesson-refresh` | Revisa `tasks/lessons/`: manter, atualizar, promover ou arquivar cada lição |
| `/lesson-resurface` | Encontra lições arquivadas relacionadas à tarefa atual |
| `/pulse` | O que foi entregue, o que quebrou e o que se aprendeu num período |
| `/retro` | Uma retrospectiva semanal |
| `/scorecard` | Números da sessão: taxa de aprovação nos gates, bloqueios disparados, orçamento de saída |

**Configuração do projeto**

| Skill | O que faz |
|---|---|
| `/constitution` | Escreve o `golden-principles.yaml` do seu projeto |
| `/harness-init` | Cria uma estrutura `docs/` (arquitetura, planos, quality score) |
| `/references-sync` | Traz a documentação das bibliotecas para `docs/references/`, para o Claude ler localmente |
| `/skill-generator` | Gera skills sob medida para a sua stack |
| `/skill-extractor` | Transforma algo aprendido numa sessão em uma skill reutilizável |

</details>

Liste-as pelo terminal com `npx @lucasfelipe23/agent-code-kit skills`. O módulo opcional de wiki adiciona `/wiki-ingest`, `/wiki-lint` e `/wiki-briefing`.

**Subagentes** para os quais o Claude pode delegar trabalho:

| Agente | O que faz |
|---|---|
| `code-reviewer` | Revisa corretude, manutenibilidade e performance |
| `security-reviewer` | Procura vulnerabilidades |
| `qa-reviewer` | Confere uma tarefa contra os seus critérios de conclusão, com evidências |
| `planner` | Transforma uma tarefa num plano de implementação |
| `devils-advocate` | Tenta quebrar uma mudança: suposições ocultas, entradas que a fazem falhar |
| `dead-code-remover` | Remove código que ele verificou estar sem uso |

## 📦 O que é instalado

Tudo vai para o diretório do seu projeto, onde você pode ler e editar. Nada é instalado globalmente.

| Caminho | O que é | Em upgrades |
|---|---|---|
| `CLAUDE.md` | As regras do fluxo de trabalho | Atualizado, a menos que você o tenha editado |
| `CLAUDE.project.md` | As regras próprias do seu projeto | Nunca alterado |
| `CODEBASE_MAP.md` | O mapa do seu projeto — preencha-o | Nunca alterado |
| `agent_docs/` | Guias que o Claude lê quando são relevantes: fluxo de trabalho, debugging, testes, hooks | Atualizado, exceto `agent_docs/project/` (seu) |
| `.claude/hooks/` | Os 28 scripts de hook | Atualizado, exceto `.claude/hooks/project/` (seu) |
| `.claude/skills/`, `.claude/agents/` | Skills e subagentes | Atualizado |
| `.claude/settings.json` | Quais hooks rodam e as listas de permissão e bloqueio de comandos | Nunca alterado |
| `tasks/` | Plano, decisões, lições e handoffs — o Claude escreve aqui enquanto trabalha | Nunca alterado |
| `scripts/` | `doctor.sh`, `statusline.sh`, `convert.sh` e outros utilitários | Atualizado |
| `.kit-manifest`, `.kit-baseline` | O que o kit instalou, para que upgrades e a desinstalação mexam só nos arquivos dele | Reescrito |

Se o seu projeto já tem um `CLAUDE.md` ou `CODEBASE_MAP.md`, o instalador mantém os seus e pergunta antes de continuar.

## 🔧 Configuração

### Perfis

```bash
npx @lucasfelipe23/agent-code-kit init --profile strict
```

| Perfil | O que você recebe |
|---|---|
| `standard` (padrão) | Regras, docs, skills, agentes e 23 hooks |
| `minimal` | Só os hooks — sem `CLAUDE.md` nem docs |
| `strict` | O `standard`, mais os 5 hooks opcionais (auto-lint, auto-format, skill-compliance, skill-extract-reminder, notify-waiting); edições em configs de build também exigem aprovação |

### Templates de stack

Cada template adiciona regras específicas da stack ao `CLAUDE.md` e um `CODEBASE_MAP.md` pré-preenchido. O instalador escolhe um a partir dos arquivos do seu projeto (`next.config.*`, `go.mod`, `Cargo.toml`, `*.sln`/`*.csproj`, `manage.py`, `requirements.txt`, `package.json`); para escolher você mesmo, use `--template <nome>`.

| Template | Stack | Adiciona regras para |
|---|---|---|
| `nextjs` | Next.js 16, App Router, Prisma, Tailwind | Server vs. client components, verificação do build |
| `node-api` | Express, TypeScript, Knex.js | Arquitetura em camadas, design de API |
| `python-fastapi` | FastAPI, SQLAlchemy 2.0, Pydantic v2 | Padrões async, injeção de dependência, Alembic |
| `django` | Django (+ DRF) | Fat models, disciplina com migrations, queries N+1 |
| `go` | Go modules | Wrapping de erros, propagação de context, testes com `-race` |
| `rust` | Cargo | `Result`/`?` em vez de `unwrap`, clippy `-D warnings`, controle de `unsafe` |
| `dotnet` | C#, ASP.NET Core, EF Core | Nullable references, `CancellationToken`, migrations do EF |

### Módulos opcionais

| Flag | Adiciona |
|---|---|
| `--wiki` | Uma wiki de conhecimento que o Claude constrói a partir das fontes que você adiciona, com `/wiki-ingest`, `/wiki-lint` e `/wiki-briefing` |
| `--html` | Convenções para escrever specs, planos e relatórios como páginas HTML em vez de markdown |
| `--gitignore` | Adiciona os arquivos do kit ao `.gitignore`, para manter o kit local em vez de commitá-lo |

<details>
<summary>Diga às verificações como rodar</summary>

Por padrão, o quality gate detecta os seus comandos de typecheck e lint. Para defini-los você mesmo, copie `.claude/commands.json.example` para `.claude/commands.json`:

```json
{
  "typecheck": "pnpm -w typecheck",
  "lint": "pnpm -w lint",
  "test": "pnpm -w test",
  "build": "pnpm -w build"
}
```

`typecheck` e `lint` rodam depois de cada edição, então mantenha-os rápidos. `test` e `build` rodam só no `/ship` e nas revisões.

</details>

<details>
<summary>Ligar ou desligar um hook</summary>

Os hooks ficam listados em `.claude/settings.json`: remova uma entrada para desligar aquele hook. `agent_docs/hooks.md` mostra como adicionar os opcionais. O mesmo arquivo guarda as listas de permissão e bloqueio de comandos — test runners e linters são permitidos; `curl`, `wget`, ler `.env` e `npm publish` são bloqueados.

</details>

<details>
<summary>Status line</summary>

`scripts/statusline.sh` mostra o modelo, a branch, o uso de contexto e o custo da sessão na parte de baixo do Claude Code. Adicione-o ao `.claude/settings.json` ([documentação da status line](https://code.claude.com/docs/en/statusline)):

```json
{
  "statusLine": {
    "type": "command",
    "command": "./scripts/statusline.sh"
  }
}
```

```text
Opus | feat/search | ███████░░░ 78% | $1.24
```

</details>

## 🔄 Upgrade

```bash
npx @lucasfelipe23/agent-code-kit@latest init --upgrade
```

- Os arquivos do kit que você não editou são atualizados.
- Os arquivos do kit que você editou são mantidos. Se o kit também os mudou, a versão dele é salva ao lado da sua como `<arquivo>.kit-new` para você fazer o merge.
- Os seus arquivos — `CODEBASE_MAP.md`, `CLAUDE.project.md`, `tasks/`, `.claude/settings.json` e as pastas `project/` — nunca são alterados.

Adicione `--diff` para pré-visualizar um upgrade: ele roda numa cópia descartável e informa o que mudaria, sem escrever no seu projeto. Para instalar uma versão específica, coloque-a no nome do pacote: `npx @lucasfelipe23/agent-code-kit@1.22.2 init`.

## 🧹 Desinstalação

```bash
npx @lucasfelipe23/agent-code-kit uninstall --dry-run   # lista o que seria removido e o que seria mantido
npx @lucasfelipe23/agent-code-kit uninstall             # remove, depois que você confirmar
```

Só os arquivos do kit são removidos. Os arquivos que você adicionou em pastas compartilhadas como `scripts/` ou `.claude/skills/` ficam, assim como o `CODEBASE_MAP.md` depois que você o preenche. `tasks/` e o seu overlay (`CLAUDE.project.md` e as pastas `project/`) são removidos por padrão — o desinstalador avisa quando `tasks/` contém trabalho seu —, então mantenha-os com `--keep-tasks` e `--keep-project`.

Instalou com curl? `curl -fsSL https://raw.githubusercontent.com/lucasfelipe24/agent-code-kit/main/uninstall.sh | bash -s -- --dry-run` funciona do mesmo jeito, só que não consegue comparar os arquivos com as cópias do próprio kit, então sempre mantém o `CODEBASE_MAP.md`.

## 🔌 Outras ferramentas de IA

As regras vão para outras ferramentas; os hooks não, porque dependem do sistema de hooks do Claude Code.

| Comando | Escreve |
|---|---|
| `npx @lucasfelipe23/agent-code-kit convert cursor` | `.cursor/rules/` |
| `npx @lucasfelipe23/agent-code-kit convert windsurf` | `.windsurf/rules/` |
| `npx @lucasfelipe23/agent-code-kit convert aider` | `CONVENTIONS.md` e `.aider.conf.yml` |
| `npx @lucasfelipe23/agent-code-kit convert agents-md` | [`AGENTS.md`](https://agents.md/), lido pelo Codex, Copilot, Jules e outros |
| `npx @lucasfelipe23/agent-code-kit convert skills` | As skills em `.agents/skills/`, lidas pelo Codex, Zed e Amp |
| `npx @lucasfelipe23/agent-code-kit convert codex` | `AGENTS.md` mais as skills em `.agents/skills/` |
| `npx @lucasfelipe23/agent-code-kit convert all` | Todos os anteriores |

Já tem regras para outra ferramenta? `convert import` as reúne em `tasks/imported-rules.md` para você revisar e mover para o `CLAUDE.project.md`.

## 🤖 Auto mode e /loop

O auto mode do Claude Code aprova ações rotineiras sem perguntar. É o kit que torna isso seguro: os hooks bloqueantes e a lista de bloqueio dele rodam antes do classificador do auto mode, e o classificador só pode adicionar restrições, nunca removê-las. O mesmo vale para execuções autônomas do `/loop`. Depois da instalação, veja `agent_docs/auto-mode.md`.

## ❓ Perguntas frequentes

<details>
<summary><b>Ele vai sobrescrever o meu <code>CLAUDE.md</code>?</b></summary>

Não. Se você já tem um, o instalador o mantém e pergunta antes de continuar. Para adotar as regras do kit depois, mova as suas para o `CLAUDE.project.md`, apague o `CLAUDE.md` e rode `npx @lucasfelipe23/agent-code-kit init --upgrade`.

</details>

<details>
<summary><b>Ele envia o meu código para algum lugar?</b></summary>

Não. Os hooks e scripts do kit rodam localmente e não enviam dados para lugar nenhum. A única chamada de rede que fazem é uma notificação push opcional quando o Claude está esperando por você (ntfy ou Pushover), desligada a menos que você a configure.

</details>

<details>
<summary><b>Uma verificação está falhando por um motivo que não tem a ver com a minha tarefa. O Claude travou?</b></summary>

Defina `SKIP_QUALITY_GATE=1` para deixá-lo encerrar. Use isso para infraestrutura quebrada, não para pular uma falha real.

</details>

<details>
<summary><b>Devo commitar os arquivos do kit?</b></summary>

Commitá-los dá ao time inteiro as mesmas regras, hooks e memória. Para manter o kit só para você, instale com `--gitignore`.

</details>

<details>
<summary><b>Funciona no Windows?</b></summary>

Pelo WSL. O instalador e os hooks são scripts bash.

</details>

## 🧪 Rodar os testes

Os hooks são testados. O repositório do kit roda um harness de regressão com 136 cenários — cada comportamento de bloqueio, mais testes de bugs já corrigidos — a cada mudança. A partir de um clone do repositório:

```bash
npm test        # cenários de hooks do KitBench, depois os testes de instalação/desinstalação e da CLI
npm run check   # checagens de manifesto, scaffold, strict settings, AGENTS.md e skills
```

```text
KitBench
  s01-protect-files-blocks-env              PASS
  s31-branch-protect-blocks-push-u-main     PASS
  s52-quality-gate-fix-unblocks-stop        PASS
  ...
  136/136 PASS  0 FAIL
```

## 👤 Autor

**Lucas Felipe**

- GitHub: [@lucasfelipe24](https://github.com/lucasfelipe24)

## 🤝 Contribuições

O Agent Code Kit é um projeto solo: é construído e mantido por uma pessoa só, então não aceita issues nem pull requests de fora. Achou um problema de segurança? Reporte em privado pelo [relato de vulnerabilidades do GitHub](https://github.com/lucasfelipe24/agent-code-kit/security/advisories/new).

## Mostre o seu apoio

Dê uma ⭐️ se este projeto te ajudou!

## 📝 Licença

Copyright © 2026 [Lucas Felipe](https://github.com/lucasfelipe24).<br />
Este projeto usa a licença [MIT](LICENSE).
