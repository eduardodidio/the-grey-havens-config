# F03 — Fix pre-existing F01 test failures

**Status:** planned

## Feature goal

Reconciliar dois arquivos de teste pré-existentes (herdados do F01) com o
contrato canônico do driver e com o próprio docstring do normalizer de eventos,
levando `bash tests/run.sh` de **12 passed / 2 failed** para **14 passed / 0
failed** — sem quebrar nenhuma das 9 suítes F02 nem o `DRIVER_CONTRACT.md`. A
direção foi confirmada na fase de root-cause: o driver e o contrato são a fonte
canônica; os testes/mapper é que estavam fora de sincronia. Nenhuma mudança de
produção é necessária para a propagação de exit code (verificada correta).

## Architecture impact

- **Testes (test layer):** `tests/F01-spawn-dispatch.sh` — asserts de schema e
  nome de variável de exit alinhados ao echo-driver canônico.
- **Normalização de eventos (bin layer):** `bin/didio-events-lib.py` — o item
  Codex `reasoning` passa a degradar para `kind="raw"` conforme o contrato
  documentado; `bin/test_didio_events.py` permanece como está (já expressa o
  comportamento correto).
- **Produção (bin/spawn + drivers):** **nenhuma mudança** — a propagação de
  exit em `bin/didio-spawn-agent.sh` e o `drivers/echo-driver.sh` já estão
  corretos e canônicos.
- **Docs:** ADR 0005 (decisão de contrato), diagramas F03, nota no README.

## Wave manifest

- **Wave 0**: F03-T01        (root-cause audit + confirmação da direção — read-only)
- **Wave 1**: F03-T02, F03-T03        (fixes em arquivos distintos, paralelos)
- **Wave 2**: F03-T04        (diagramas + ADR + nota no README)

## Global acceptance criteria

1. `bash tests/run.sh` → **14 passed, 0 failed**.
2. As 9 suítes F02 (incl. `F02-sim-dispatch.sh`, `F02-sim-parallel.sh`,
   `F02-shellcheck.sh`) continuam passando.
3. `drivers/echo-driver.sh` e `drivers/DRIVER_CONTRACT.md` permanecem
   inalterados (o contrato é a fonte canônica).
4. `bin/didio-spawn-agent.sh` permanece inalterado (propagação de exit já
   correta; root-cause documentado em F03-T01).
5. O fix do mapper (`bin/didio-events-lib.py`) mantém os outros 12 testes de
   `bin/test_didio_events.py` verdes.
6. `bash tests/F02-shellcheck.sh` continua limpo (sem novos avisos).
7. ADR 0005 registra a decisão de contrato; diagramas F03 e nota no README
   entregues conforme os gates do projeto.

## Diagrams to create

- `docs/diagrams/F03-architecture.mmd` — fluxo dos dois fixes: teste → driver
  canônico (schema/exit var) e item Codex → mapper → raw. **Owner: F03-T04.**
- `docs/diagrams/F03-journey.mmd` — jornada do mantenedor: `tests/run.sh`
  falhando → audit (Wave 0) → fixes (Wave 1) → verde (Wave 2). **Owner: F03-T04.**

## Root-cause summary (confirmado pelo Architect, a re-verificar em F03-T01)

| Falha | Arquivo | Causa raiz | Direção do fix |
|-------|---------|-----------|----------------|
| 1A schema | `tests/F01-spawn-dispatch.sh:72-73` | teste espera `"type":"echo"`/`"task_id"`; driver emite `"subtype":"echo-driver"`/`"task"` | alinhar teste ao driver |
| 1B exit-code | `tests/F01-spawn-dispatch.sh:149` | teste usa `DIDIO_ECHO_EXIT_CODE`; driver lê `ECHO_DRIVER_EXIT` | alinhar teste ao contrato; produção OK |
| 2 mapper | `bin/didio-events-lib.py:101` | `"reasoning"` listado como tool; docstring diz que deve virar raw | remover `reasoning` de `_CODEX_TOOL_ITEM_TYPES` |
