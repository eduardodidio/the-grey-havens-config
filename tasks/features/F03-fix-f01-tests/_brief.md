# F03 — Fix pre-existing F01 test failures (echo-driver drift + codex event mapper)

**Tipo:** Bug remediation + test↔implementation reconciliation.
**Modo:** PLAN_ONLY (Architect só planeja; Waves executam depois).
**Origem:** Follow-up TL-03 da revisão F02. Estas falhas são PRÉ-EXISTENTES
(vieram do F01), apenas reveladas pelo novo `tests/run.sh` (F02-T01). Não são
regressões do F02.

## Estado atual (grounded)

`bash tests/run.sh` → **12 passed, 2 failed**. As 9 suítes F02 passam; falham
apenas 2 arquivos pré-F02.

### Falha 1 — `tests/F01-spawn-dispatch.sh` (5 asserts)

**Categoria A — drift de schema do echo-driver:**
- O teste espera `"type":"echo"` (linha 72) e `"task_id":"task"` (linha 73).
- O `drivers/echo-driver.sh` (canônico, shipped) emite:
  `{"type":"system","subtype":"echo-driver","role":...,"feature":...,
  "task":"task","model":...,"fallback":...,"effort":...}`.
- Ou seja, `type` é `system` + `subtype:echo-driver` (não `echo`) e o campo é
  `task` (não `task_id`).
- **Decisão de design (CONFIRMADA pelo Architect):** o driver é a fonte
  canônica do contrato (`drivers/DRIVER_CONTRACT.md`) e as suítes de simulação
  F02 (`F02-sim-dispatch.sh`, `F02-sim-parallel.sh`) já foram escritas contra
  ESSE shape. A correção **alinha o teste F01 ao driver**, NÃO muda o driver
  (mudar o driver quebraria as suítes F02 e o DRIVER_CONTRACT).

**Categoria B — propagação de exit code:**
- Asserts (linhas 158–160): com exit do driver = 1, o teste espera spawn-agent
  sair 1 e meta `status:"failed"`/`exit_code:1`; observado: exit 0,
  `completed`.
- **Root-cause (CONFIRMADO pelo Architect):** o teste exporta
  `DIDIO_ECHO_EXIT_CODE=1` (linha 149), mas o driver lê `ECHO_DRIVER_EXIT`
  (`drivers/echo-driver.sh:15`; `DRIVER_CONTRACT.md:33`). **Mismatch de nome de
  variável** → o driver sempre sai 0. A propagação de produção em
  `bin/didio-spawn-agent.sh` (linhas 152–193: `EXIT_CODE=$?` →
  `FINAL_STATUS=failed` → `exit $EXIT_CODE`) está CORRETA. **Não é bug de
  produção — é defeito só do teste.** A Wave 0 deve provar isso por inspeção +
  execução antes de qualquer mudança.

### Falha 2 — `bin/test_didio_events.py` (1 de 13)

- `test_codex_event_with_no_analogue_degrades_to_raw` (linhas 88–93): espera que
  um item Codex sem análogo Claude (`reasoning`) apareça no output com
  `kind=="raw"` e `category=="reasoning"`.
- **Root-cause (CONFIRMADO pelo Architect):** `bin/didio-events-lib.py:101`
  inclui `"reasoning"` em `_CODEX_TOOL_ITEM_TYPES` → o item vira `kind="tool"`,
  não `raw`. Isso CONTRADIZ o próprio docstring do módulo (linhas 24–26 e
  88–89), que cita `reasoning` como o exemplo canônico de degradação para raw.
  **O bug está no mapper.** Correção: remover `"reasoning"` de
  `_CODEX_TOOL_ITEM_TYPES` para o item cair no fallback (`item.completed` →
  `kind="raw", category=item_type`). `count_tool_errors` não conta `reasoning`
  (linha 233), então os outros 12 testes permanecem verdes.

## Diretrizes para o plano

- **Audit + fix** com critérios de aceitação verificáveis.
- **Meta final:** `bash tests/run.sh` → **14 passed, 0 failed**.
- **Não quebrar** as 9 suítes F02 nem o DRIVER_CONTRACT (a direção é alinhar
  testes/mapper ao contrato canônico; o exit-code é defeito só de teste).
- **Single-writer por Wave** e paralelismo onde possível. As frentes de fix
  tocam arquivos distintos (`tests/F01-spawn-dispatch.sh` vs
  `bin/didio-events-lib.py`) → paralelas numa única Wave após o Wave 0 de
  root-cause.
- Sem novas dependências. Respeitar guardrails do CLAUDE.md.
- Atualizar diagramas (`docs/diagrams/F03-*.mmd`) e nota no README; ADR para a
  decisão de contrato (testes alinham ao driver canônico; exit-code é test-only).

## Decisão arquitetural a registrar (ADR 0005)

O contrato do driver (`drivers/DRIVER_CONTRACT.md`) e o echo-driver shipped são
a **fonte canônica** do schema de eventos e do nome de variável de exit
(`ECHO_DRIVER_EXIT`). Testes que divergem do contrato são corrigidos para
seguir o contrato — não o contrário. Exceção examinada e descartada: o
exit-code NÃO é bug de produção (propagação verificada correta).
