# claude-status-line

Statusline para [Claude Code](https://claude.com/claude-code) no Windows (pwsh).

Mostra na barra de status, sempre visível:

```
pangare (main*+2)  Opus 4.7 (1M context)  $0.42  1h23m  85.2k/1000k [#.........] 8.5%
```

- **Diretório atual** (dimmed)
- **Branch git** + `*` dirty, `+N` ahead, `-N` behind
- **Modelo** em uso
- **Custo da sessão** em USD (estimado a partir dos tokens × tabela de preços flat)
- **Duração da sessão**
- **Tokens consumidos** / limite do modelo + barra visual + %
  - ciano <20% · amarelo 20-30% · laranja 30-40% · vermelho 40-60% · roxo ≥60%

## Pré-requisitos

- **PowerShell 7+** (`pwsh`) — instala via [aka.ms/powershell](https://aka.ms/powershell) ou `winget install Microsoft.PowerShell`
- Claude Code já instalado

## Instalação (one-liner)

```powershell
irm https://raw.githubusercontent.com/marcosbrigante/claude-status-line/main/install.ps1 | iex
```

O instalador:
1. Baixa `statusline.ps1` pra `~/.claude/statusline.ps1`
2. Adiciona a chave `statusLine` no seu `~/.claude/settings.json` (preserva o resto da config)

Depois disso, **reinicia o Claude Code** (sai e entra de novo) pra ativar.

## Desinstalar

Apaga a chave `statusLine` do `~/.claude/settings.json` e (opcional) o arquivo `~/.claude/statusline.ps1`.

## Customizar

Edite `~/.claude/statusline.ps1` direto. As faixas de cor, formato e o que mostrar tão tudo no fim do arquivo. Pra puxar a versão nova depois, roda o `irm | iex` de novo (sobrescreve o script, preserva o settings.json).

## Como funciona

Claude Code chama o comando do `statusLine` em cada atualização de prompt e passa um JSON pelo stdin com `transcript_path`, `model`, `cwd`. O script lê o transcript (JSONL) pra computar tokens/custo/duração e roda `git status` pra branch info. Custo zero — só CPU local, sem chamada de API.

## Tabela de preços usada

Por milhão de tokens (USD aprox):

| Modelo | Input | Output | Cache read | Cache write |
|--------|-------|--------|------------|-------------|
| Opus   | 15    | 75     | 1.5        | 18.75       |
| Sonnet | 3     | 15     | 0.3        | 3.75        |
| Haiku  | 0.8   | 4      | 0.08       | 1.0         |

Flat rate — não considera tier de 1M context (ligeiramente subestima). Pra contas precisas, use `/cost` no Claude Code.
