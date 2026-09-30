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
  <a href="https://lucasfelipe24.github.io/agent-code-kit/pt-BR/">
    <img alt="Documentação" src="https://img.shields.io/badge/docs-site-blue">
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
  <a href="#-fluxos-de-trabalho">Fluxos de trabalho</a> ·
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

| | Um `CLAUDE.md` escrito à mão | Com o kit |
|---|---|---|
| **Regras** | O que você lembrou de escrever | Um fluxo testado: planejar, confirmar, implementar, verificar |
| **Quando o Claude esquece uma regra** | Nada acontece | Um hook bloqueia a ação e diz ao Claude por quê |
| **"Pronto"** | Quando o Claude disser | Bloqueado enquanto o typecheck ou o lint de algum arquivo editado estiver falhando |
| **Dependências, schema, autenticação** | Fica a critério do modelo | Para até você aprovar; a sua escolha é registrada como uma decisão |
| **As suas correções** | Somem quando a sessão termina | Viram lições; as mais importantes são carregadas em toda sessão |
| **Depois de uma compactação ou numa sessão nova** | O Claude começa do zero | O plano ativo, as lições principais e as suas notas voltam sozinhos |
| **Revisões, auditorias, releases** | Um prompt novo a cada vez | 37 skills e 6 subagentes, cada um com um processo fixo |

**Vale a pena se você** usa o Claude Code num código de verdade — novo ou que você mantém há anos — e responde pelo que ele entrega; quer as mesmas regras para todo o time, versionadas junto com o código; ou deixa o Claude rodar sozinho por mais tempo (auto mode, `/loop`) e precisa de limites que ele não consegue contornar na conversa.

**Provavelmente não compensa se** você só usa o Claude Code para scripts avulsos, ou está no Windows sem WSL.

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

Todos os comandos da CLI estão em [Guias e comandos](#guias-e-comandos).

## 🧩 Como funciona

O kit adiciona quatro camadas ao seu projeto: **regras** (`CLAUDE.md`), **guardrails** (hooks que o Claude Code executa a cada ação), **skills e agentes**, e **memória** (`tasks/`). As [Funcionalidades](#-funcionalidades) listam tudo o que há em cada uma.

Regras são conselhos. Hooks são imposição: rodam fora do modelo, em toda ação correspondente, quer ele se lembre da regra ou não.

## 🎁 Funcionalidades

Tudo o que o kit adiciona, e para que serve cada parte:

| Funcionalidade | O que você recebe | Por que ajuda |
|---|---|---|
| [**Regras de trabalho**](#-as-regras) | `CLAUDE.md`: planejar primeiro, disciplina de escopo, mudanças protegidas, verificação, lições | O Claude trabalha do mesmo jeito em toda sessão, em qualquer máquina |
| [**Guardrails**](#-guardrails) | 28 hooks — 23 ligados por padrão, 5 opcionais | As regras valem mesmo quando o modelo as esquece |
| [**Automação da sessão**](#-uma-sessão-com-o-kit) | Contexto devolvido a cada início e depois de cada compactação; um handoff salvo no fim | Nada de reexplicar a tarefa depois de um `/clear` ou de uma compactação |
| [**Fluxos de trabalho**](#-fluxos-de-trabalho) | Skills que se encadeiam da ideia até o pull request | Um caminho conhecido para features, bugs, revisões e releases |
| [**Skills**](#-skills-e-agentes) | 37 comandos para planejamento, debugging, auditorias, revisões, releases e relatórios | Um processo repetível em vez de um prompt improvisado |
| [**Subagentes**](#-skills-e-agentes) | 6 especialistas: revisão de código, segurança, QA, planejamento, revisão adversarial, código morto | Uma segunda opinião com um escopo estreito e contexto próprio |
| [**Memória do projeto**](#arquivos-que-o-kit-escreve-enquanto-você-trabalha) | `tasks/`: plano, decisões, lições, handoffs, specs, revisões, relatórios | Decisões e correções sobrevivem à sessão e ficam no git junto com o código |
| [**Guias**](#guias-e-comandos) | 12 guias em `agent_docs/`, lidos só quando a tarefa precisa | Orientação aprofundada sem pagar por ela em todo prompt |
| [**Templates de stack**](#templates-de-stack) | 7 stacks, detectadas na instalação | Regras da stack e um mapa do projeto pré-preenchido desde o primeiro dia |
| [**Módulos opcionais**](#módulos-opcionais) | Wiki de conhecimento, artefatos HTML, instalação só local | Adicione só o que usar |
| [**Outras ferramentas de IA**](#-outras-ferramentas-de-ia) | Exportação para Cursor, Windsurf, Aider, Codex e `AGENTS.md` | Um conjunto de regras para todas as suas ferramentas |
| [**Upgrades seguros**](#-upgrade) | Um registro de instalação por arquivo, prévias, cópias `.kit-new` e backups | O upgrade só atualiza arquivos do kit intactos; a desinstalação só remove o que o kit escreveu |
| [**Testado**](#-rodar-os-testes) | Uma suíte de regressão rodada em Linux e macOS | Cada guardrail é verificado a cada mudança no kit |

## 📏 As regras

O `CLAUDE.md` dá ao Claude um fluxo de trabalho para seguir em toda sessão:

| Regra | O que o Claude faz |
|---|---|
| **Planejar primeiro** | Para mudanças em 3+ arquivos, reformula o seu pedido como uma meta verificável ("corrija o bug" → "escreva um teste que reproduza o bug e faça-o passar"), escreve um plano em `tasks/todo.md` e espera o seu sinal verde |
| **Disciplina de escopo** | Mexe só no que a tarefa precisa, segue o estilo dos arquivos que edita e registra qualquer outra coisa que notar em "Not Now" |
| **Mudanças protegidas** | Para antes de novas dependências e de mudanças em schema, API, autenticação ou build; apresenta opções e registra a sua escolha como uma decisão |
| **Verificação** | Roda typecheck, lint, testes e um smoke test, nessa ordem, antes de dar uma tarefa como concluída — e, quando processa um lote, informa quantos itens falharam ou foram pulados |
| **Lições** | Quando você o corrige, escreve uma lição em `tasks/lessons/` e revisa as regras principais no início de cada sessão |
| **Contexto em camadas** | Carrega o mapa do projeto em toda sessão, o plano e o handoff só ao retomar um trabalho, e as lições e decisões só quando são relevantes |
| **Depois de uma compactação** | Relê o plano, os arquivos que estava editando e as suas notas antes de escrever mais uma linha |
| **Modelo por fase** | Planeja e depura com o modelo mais capaz, implementa com um mais rápido |
| **Modelo vs. código** | Deixa o trabalho determinístico — parsing, retries, conversões de formato, consultas — para o código, não para o modelo |

Coloque as suas próprias regras no `CLAUDE.project.md` — elas têm prioridade sobre as do kit.

## 🚧 Guardrails

Hooks são scripts shell que o Claude Code executa em pontos fixos: antes de uma chamada de ferramenta, depois de uma edição, quando o Claude tenta encerrar. Um hook bloqueante interrompe a ação e diz ao Claude por quê.

### Todos os hooks

**Bloquear** — interrompem a ação e dizem ao Claude por quê

| Hook | Roda | O que faz |
|---|---|---|
| `protect-files` | Antes de edições e de `git add` | Bloqueia a edição de arquivos `.env`, credenciais, chaves privadas e lock files, e a adição de qualquer um deles ao stage, exceto lock files |
| `protect-changes` | Antes de edições e de comandos no shell | Bloqueia manifestos de dependências, migrations, código de autenticação, workflows de CI e instalação de dependências até você aprovar |
| `branch-protect` | Antes de comandos no shell | Bloqueia pushes para `main`/`master` e force pushes |
| `block-dangerous-commands` | Antes de comandos no shell | Bloqueia `rm -rf /`, `git reset --hard`, `DROP TABLE` e similares |
| `conventional-commit` | Antes de comandos no shell | Bloqueia mensagens de commit fora do padrão [Conventional Commits](https://www.conventionalcommits.org/) |
| `mcp-gate` | Antes de chamadas a ferramentas MCP | Bloqueia servidores MCP que não estão em `.claude/mcp-allowlist.txt` (desligado até você criá-lo) |
| `stop-gate` | Quando o Claude tenta encerrar | Bloqueia enquanto a verificação de um arquivo editado estiver falhando, tiver estourado o tempo ou for mais antiga que o arquivo |
| `loop-detect` | Depois de edições | Alerta quando o mesmo arquivo aparece 4 vezes entre as últimas 10 edições, e bloqueia na 6ª |

O perfil padrão liga 23 dos 28 hooks. Os demais verificam, dão contexto ou mantêm registros em vez de bloquear, ou são opcionais:

<details>
<summary>Os hooks que verificam, dão contexto, observam ou são opcionais</summary>

**Verificar** — rodam depois de cada edição e informam o resultado

| Hook | Roda | O que faz |
|---|---|---|
| `quality-gate` | Depois de edições | Roda o typecheck, o lint ou a checagem de sintaxe do arquivo e registra o resultado para o `stop-gate` |
| `secret-scan` | Depois de edições | Alerta sobre segredos gravados num arquivo: API keys, tokens, chaves privadas, senhas |
| `unicode-scan` | Depois de edições | Alerta sobre Unicode invisível que pode esconder código |

**Contexto** — dão ao Claude a informação certa na hora certa

| Hook | Roda | O que faz |
|---|---|---|
| `session-start` | No início da sessão e depois de uma compactação | Aponta para o mapa do projeto, as lições principais, a tarefa ativa e a branch; depois de uma compactação, também o contrato da tarefa e o journal do `/note` |
| `prompt-router` | A cada prompt | Adiciona um lembrete das regras quando você menciona autenticação, cobrança, migrations, deploys ou dependências |
| `glob-guidance` | Antes de edições | A primeira edição num arquivo de teste ou de migration traz as orientações para esse tipo de arquivo |
| `bash-budget`, `read-budget` | Depois de comandos no shell e de leituras de arquivo | Alertam uma vez quando a saída da sessão passa de um orçamento de tokens |
| `journal-fold` | No fim da sessão | Salva o journal do `/note` e o handoff entre subagentes em `tasks/handoff-<sessão>.md` |

**Observar** — registram o que aconteceu, para o `/scorecard`

| Hook | Roda | O que faz |
|---|---|---|
| `session-end` | No fim da sessão | Grava uma linha de scorecard em `.hook-state/session-audit.log` |
| `subagent-pre`, `subagent-post` | Em volta de cada subagente | Registram qual agente rodou e por quanto tempo |
| `tool-failure-observe` | Depois de uma chamada de ferramenta que falhou | Conta as falhas por ferramenta |
| `stop-failure-observe` | Quando um turno termina num erro da API | Registra rate limits e erros de servidor |
| `task-complete-notify` | Quando o Claude termina | Envia uma notificação no desktop (macOS, Linux) |

**Opcionais** — ligados no perfil strict, ou adicione você mesmo

| Hook | Roda | O que faz |
|---|---|---|
| `auto-format` | Depois de edições | Roda o seu formatador |
| `auto-lint` | Depois de edições | Roda o seu linter |
| `skill-compliance` | Depois de edições | Lembra o Claude de conferir os checklists das skills ativas |
| `skill-extract-reminder` | A cada prompt | Lembra o Claude de transformar algo novo que aprendeu numa skill |
| `notify-waiting` | Quando o Claude está esperando por você | Envia uma notificação push (ntfy ou Pushover) |

</details>

Depois da instalação, `agent_docs/hooks.md` descreve cada hook e como escrever os seus.

Os hooks são testados — veja [Rodar os testes](#-rodar-os-testes).

## 🔁 Uma sessão com o kit

O que roda, e quando, sem você digitar nenhum comando:

| Quando | O que acontece |
|---|---|
| **A sessão começa** | O Claude recebe ponteiros para o mapa do projeto, as lições principais, a tarefa ativa em `tasks/todo.md` e a branch atual |
| **Você envia um prompt** | Se você mencionar autenticação, cobrança, migration, deploy ou uma dependência nova, o Claude recebe um lembrete curto das regras que se aplicam |
| **Antes de uma edição** | Segredos, lock files e mudanças protegidas não aprovadas são bloqueados; a primeira edição num arquivo de teste ou de migration traz as orientações para esse tipo de arquivo |
| **Antes de um comando no shell** | Pushes para a `main`, comandos destrutivos, instalação de dependências e mensagens de commit são verificados |
| **Depois de uma edição** | O typecheck ou o lint do arquivo roda e o resultado é registrado; a edição passa por uma varredura de segredos e Unicode invisível; um arquivo editado 4 vezes nas últimas 10 edições gera um alerta de loop, e a 6ª edição é bloqueada |
| **O Claude tenta encerrar** | Bloqueado enquanto a verificação de algum arquivo editado estiver falhando, tiver estourado o tempo ou for mais antiga que o arquivo |
| **O contexto é compactado** | A tarefa ativa, as lições principais, o contrato da tarefa (se houver) e as suas entradas do `/note` voltam ao contexto |
| **A sessão termina** | Uma linha de scorecard é gravada para o `/scorecard`, e os achados e decisões do seu `/note` são salvos em `tasks/handoff-<sessão>.md` para a próxima sessão |

## 🧭 Fluxos de trabalho

As skills foram feitas para se encadear. Alguns caminhos comuns:

### Construir uma feature

1. `/office-hours` — defina o que construir e por quê, enquanto a ideia ainda está vaga.
2. `/shape-spec` — crie uma pasta de spec, quando o trabalho for durar várias sessões.
3. Peça a mudança. O Claude a reformula como uma meta verificável, escreve o plano em `tasks/todo.md` e espera o seu sinal verde.
4. O Claude implementa; cada edição é verificada na hora.
5. `/review-pipeline` — auditorias em paralelo sobre o diff, antes do merge.
6. `/ship` — testes, changelog, commits limpos e o pull request.

O `/feature-cycle` roda os passos 2 a 6 de uma vez e para no primeiro gate que falhar.

### Corrigir um bug

O `/debug` reproduz o bug e reúne evidências até encontrar a causa raiz, corrige, e depois adiciona um teste de regressão que falha sem a correção.

### Revisar uma mudança

O `/review-pipeline` roda várias auditorias sobre o diff em paralelo e junta os achados num relatório só. Quando quiser alguém tentando quebrar a mudança, peça o agente `devils-advocate`.

### Trabalhar em várias sessões

O plano em `tasks/todo.md` e as decisões em `tasks/decisions.md` sobrevivem a qualquer sessão. O `/note` guarda um achado ou uma decisão no meio da sessão: ele sobrevive a uma compactação e é salvo num handoff quando a sessão termina, para a próxima continuar de onde você parou.

### Adotar num projeto existente

1. Rode o `init`. O seu `CLAUDE.md`, o seu `.claude/settings.json` e os seus hooks, agentes e scripts ficam como estão, e o instalador lista o que deixou intacto.
2. Manteve o seu `settings.json`? Registre nele os hooks do kit — o `doctor` falha até você fazer isso.
3. Manteve o seu `CLAUDE.md`? Mova as suas regras para o `CLAUDE.project.md` para ativar as do kit (veja as [Perguntas frequentes](#-perguntas-frequentes)).
4. Preencha o `CODEBASE_MAP.md`. O `/constitution` consegue inferir os seus princípios de código a partir do código existente e gravá-los em `golden-principles.yaml`, e o `/quality-audit` depois verifica o código contra eles.

### Acompanhar o trabalho

| Quando | Skill | O que ela responde |
|---|---|---|
| Toda semana | `/pulse` | O que foi entregue, quebrou e foi aprendido, salvo em `tasks/pulses/` como uma linha do tempo |
| Toda semana | `/retro` | Como o trabalho andou: sessões, volume, pontos quentes, o que mudar |
| A qualquer hora | `/scorecard` | Números da sessão: taxa de aprovação nos gates, bloqueios disparados, orçamento de saída |
| A cada poucas semanas | `/lesson-refresh` | Quais lições manter, afinar, promover ou arquivar |

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
| `/accessibility-audit` | Conformidade com a WCAG 2.2 AA |
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

### Como um projeto fica organizado

```text
seu-projeto/
├── CLAUDE.md            # as regras de trabalho (do kit)
├── CLAUDE.project.md    # as suas regras; têm prioridade sobre as do kit
├── CODEBASE_MAP.md      # o mapa do seu projeto, lido em toda sessão
├── agent_docs/          # guias que o Claude lê quando precisa; project/ é seu
├── .claude/
│   ├── settings.json    # quais hooks rodam; listas de comandos permitidos e negados
│   ├── hooks/           # os 28 hooks; project/ é seu
│   ├── skills/          # as 37 skills
│   ├── agents/          # os 6 subagentes
│   └── extensions/      # skills de outros autores
├── scripts/             # doctor, validate, statusline, convert e outros utilitários
├── tasks/               # plano, decisões, lições, handoffs, specs, relatórios
└── .hook-state/         # o estado de trabalho dos hooks (ignorado pelo git)
```

### Arquivos que o kit escreve enquanto você trabalha

| Arquivo | Escrito por | Para que serve |
|---|---|---|
| `tasks/todo.md` | O Claude, quando planeja | O plano oficial: a tarefa atual, os passos e o "Not Now" para tudo que está fora do escopo |
| `tasks/decisions.md` | O Claude, depois que você aprova uma mudança protegida | Decisões de arquitetura (ADRs), com as opções que você considerou |
| `tasks/lessons/` | O Claude, depois que você o corrige | Uma lição por arquivo; o `_index.md` guarda as regras principais carregadas em toda sessão, e o `/lesson-refresh` move as desatualizadas para `_archive/` |
| `tasks/handoff-<sessão>.md` | O `journal-fold`, no fim da sessão | De onde a próxima sessão continua |
| `tasks/specs/<data>-<nome>/` | `/shape-spec` | Spec, decisões e referências de uma feature que dura várias sessões |
| `tasks/*_CONTRACT.md` | Você ou o Claude | Os critérios de conclusão de uma tarefa, verificados pelo `qa-reviewer` |
| `tasks/reviews/` | `/review-pipeline` | O relatório de revisão consolidado, quando você escolhe salvá-lo |
| `tasks/pulses/`, `tasks/retros/` | `/pulse`, `/retro` | Relatórios periódicos que formam uma linha do tempo (o `/retro` pergunta antes de criar a pasta dele) |
| `.claude/golden-principles.yaml` | `/constitution` | Os seus princípios de código, que o `/quality-audit` verifica |
| `docs/` | `/harness-init`, `/quality-audit`, `/references-sync` | Docs de arquitetura, o quality score e cópias locais da documentação das bibliotecas |
| `.hook-state/` | Os hooks | Estado da sessão: resultados dos gates, o registro de verificações, o log da sessão, o journal do `/note`, orçamentos |
| `<arquivo>.kit-new`, `.kit-backup/` | `--upgrade`, `uninstall` | A versão mais nova do kit para um arquivo que você editou; cópias salvas antes de uma substituição ou remoção |

### Guias e comandos

<details>
<summary>Os 12 guias em <code>agent_docs/</code></summary>

| Guia | Cobre |
|---|---|
| `workflow.md` | Ciclo de vida da tarefa, reformulação como meta, o template de plano, estratégia de sessão, higiene de contexto |
| `debugging.md` | O protocolo de debugging: evidência antes da correção |
| `testing.md` | O que e como testar |
| `conventions.md` | Convenções de código e como seguir o estilo existente |
| `hooks.md` | Cada hook, os perfis e como escrever os seus |
| `skills.md` | Como usar as skills e estendê-las |
| `subagents.md` | Quando e como passar trabalho para um subagente |
| `worktrees.md` | Como isolar agentes paralelos que editam arquivos |
| `auto-mode.md` | Como rodar sem supervisão com segurança, e quando parar e perguntar |
| `contracts.md` | Critérios de conclusão de uma tarefa |
| `prompting.md` | Prompting e consciência de vieses |
| `architecture-language.md` | O vocabulário por trás do `/deepening-review` e do `/interface-design` |

</details>

Todo comando roda como `npx @lucasfelipe23/agent-code-kit <comando>`:

| Comando | O que faz |
|---|---|
| `init` | Instala o kit; `--upgrade`, `--diff`, `--profile`, `--template`, `--wiki`, `--html` e `--gitignore` mudam como |
| `doctor` | Confere os arquivos, as configurações e o registro dos hooks, e depois faz um autoteste dos hooks |
| `skills` | Lista as skills pelo terminal |
| `convert <ferramenta>` | Exporta as regras para outra ferramenta de IA |
| `generate agents-md` | Escreve um `AGENTS.md` portável |
| `uninstall` | Remove o que o kit instalou, depois da sua confirmação |

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
- Um arquivo seu em um caminho que o kit também usa (o seu `scripts/validate.sh`, o seu `.claude/agents/code-reviewer.md`) fica como está quando o registro da instalação está marcado como completo, o que toda primeira instalação e todo `--upgrade` fazem. O resumo lista esses arquivos como "yours". Apague o seu e rode de novo para receber a versão do kit. Uma instalação anterior ao registro substitui esse arquivo e guarda a cópia anterior em `.kit-backup/`.
- Os seus arquivos — `CODEBASE_MAP.md`, `CLAUDE.project.md`, `tasks/`, `.claude/settings.json` e as pastas `project/` — nunca são alterados.

Adicione `--diff` para pré-visualizar um upgrade: ele roda numa cópia descartável e informa o que mudaria, sem escrever no seu projeto. Para instalar uma versão específica, coloque-a no nome do pacote: `npx @lucasfelipe23/agent-code-kit@1.22.2 init`.

## 🧹 Desinstalação

```bash
npx @lucasfelipe23/agent-code-kit uninstall --dry-run   # lista o que seria removido e o que seria mantido
npx @lucasfelipe23/agent-code-kit uninstall             # remove, depois que você confirmar
```

Só são removidos os arquivos que o registro da instalação (`.kit-baseline`) lista e que você não editou desde então. Um arquivo do kit que você alterou fica, listado como mantido, e o mesmo vale para um arquivo que o registro não lista, mesmo que o `.kit-manifest` o cite. Os arquivos que você adicionou em pastas compartilhadas como `scripts/` ou `.claude/skills/` ficam, assim como o `CODEBASE_MAP.md` depois que você o preenche. Dentro de `tasks/`, só saem os arquivos do scaffold que você não tocou; o que você editou ou adicionou fica, e a pasta também (um `tasks/` com código seu está seguro). O seu overlay (`CLAUDE.project.md` e as pastas `project/`) só sai enquanto ainda for o modelo intocado do kit; o que você escreveu ali fica (`--keep-project` continua aceito e não faz nada). Os módulos wiki e artifacts funcionam igual: saem os arquivos semente intocados, e ficam as suas páginas, fontes e artefatos. `--keep-tasks` mantém o `tasks/` inteiro.

Instalou com curl? `curl -fsSL https://raw.githubusercontent.com/lucasfelipe24/agent-code-kit/main/uninstall.sh | bash -s -- --dry-run` funciona do mesmo jeito, só que não consegue comparar os arquivos com as cópias do próprio kit, então sempre mantém o `CODEBASE_MAP.md` e todos os arquivos de `tasks/`.

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

Os hooks são testados. O repositório do kit roda um harness de regressão com 158 cenários — cada comportamento de bloqueio, mais testes de bugs já corrigidos — a cada mudança. A partir de um clone do repositório:

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
  158/158 PASS  0 FAIL
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
