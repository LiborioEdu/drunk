# 🔒 Especificação de Segurança, Segredos e Governança de `.gitignore` (DRUNK // 10K)

> **Documento:** `GITIGNORE_AND_SECURITY_SPECS.md`  
> **Escopo:** Política obrigatória de controle de versão, prevenção de vazamento de credenciais, artefatos de build e dados locais no repositório `front`.  
> **Arquivo Regido:** [`.gitignore`](file:///home/eduardo/dev/drunk/front/.gitignore)

---

## 1. Objetivo

Garantir que **nenhuma chave de API, credencial de agente/MCP, banco de dados local de execução, ambiente virtual ou artefato efêmero de compilação** seja acidentalmente rastreado ou enviado (`git commit` / `git push`) para repositórios remotos.

---

## 2. Auditoria do Workspace Atual (Itens Detectados e Bloqueados)

Durante a inspeção do diretório `/home/eduardo/dev/drunk/front`, foram identificados os seguintes arquivos/pastas sensíveis ou locais que **não estavam cobertos** pelo `.gitignore` padrão do Flutter e agora estão **estritamente bloqueados**:

| Item Detectado no Workspace | Categoria de Risco | Regra Adicionada no `.gitignore` | Motivo |
| :--- | :--- | :--- | :--- |
| `.agents/mcp_config.json` | **Crítico (Vazamento de Chave de API)** | `.agents/`, `mcp_config.json`, `*mcp_config*.json` | Contém o header `X-Goog-Api-Key` do servidor MCP do Google Stitch em texto puro. |
| `drunk.db` | **Alto (Dados Locais / SQLite)** | `*.db`, `*.sqlite*`, `*.db-wal`, `*.db-shm`, `drunk.db` | Banco de dados SQLite local de testes/corridas; contém estado local da máquina do desenvolvedor e binário mutável. |
| `.venv/` | **Médio (Poluição de Repositório)** | `.venv/`, `venv/`, `__pycache__/`, `*.py[cod]` | Ambiente virtual Python 3.12 local com centenas de binários e bibliotecas instaladas. |
| `dart_defines.json` / `.env` | **Crítico (Chaves de Mapa / Ambiente)** | `.env*`, `dart_defines*.json`, `secrets*.json` | Caso o desenvolvedor utilize `--dart-define-from-file` ou `.env` (ex: `CARTO_API_KEY`), o arquivo jamais será commitado. |
| `.vscode/` / `.idea/` / `*.iml` | **Baixo (Configuração Pessoal de IDE)** | `.vscode/`, `.idea/`, `*.iml` | Caminhos locais do SDK (`Dart_SDK.xml`, `local.properties`) que quebram o build na máquina de outros devs. |

---

## 3. Matriz de Classificação: O Que NUNCA Commitar vs. O Que DEVE Ser Commitado

### 3.1. Proibido no Controle de Versão (Sempre no `.gitignore`)

1. **Segredos, Tokens e Configurações de Agentes IA (`SecOps`)**
   - Qualquer arquivo `.env`, `.env.local`, `.env.development`, `.env.production`.
   - Arquivos de definição de variáveis do Flutter: `dart_defines.json`, `env.json`, `secrets.json`.
   - Pastas de configuração de assistentes e MCPs: `.agents/`, `.claude/`, `.cursor/`, `.gemini/`, `.windsurf/`, `mcp_config.json`.
   - Certificados e chaves de assinatura mobile: `*.keystore`, `*.jks`, `key.properties`, `*.p12`, `*.mobileprovision`, `google-services.json`, `GoogleService-Info.plist`.

2. **Bancos de Dados Locais e Estado de Runtime**
   - Arquivos SQLite (`*.db`, `*.sqlite`, `*.sqlite3`, `*.db-journal`, `*.db-wal`, `*.db-shm`).
   - Caixas locais do Hive/SharedPreferences exportadas (`*.hive`, `*.Boxes`).

3. **Ambientes Virtuais e Dependências Externas**
   - Ambientes Python (`.venv/`, `venv/`, `env/`, `__pycache__/`).
   - Cache do Dart/Flutter (`.dart_tool/`, `.pub-cache/`, `.flutter-plugins-dependencies`, `.fvm/`).
   - Dependências Node/Web (`node_modules/`, `.firebase/`, `.vercel/`).

4. **Artefatos de Compilação e Cobertura de Testes**
   - Diretórios `/build/`, `/coverage/`, `lcov.info`.
   - Símbolos de ofuscação (`app.*.symbols`, `app.*.map.json`).
   - Pastas efêmeras geradas pelo Flutter nas plataformas (`**/Flutter/ephemeral/`, `**/flutter/ephemeral/`, `/android/.gradle/`, `/ios/Pods/`).

### 3.2. Obrigatório no Controle de Versão (Rastreado pelo Git)

1. **Catálogo Seed Oficial de Bares da Cidade (`assets/data/city_bars_seed.json`)**
   - Protegido explicitamente no `.gitignore` com a regra `!assets/data/*.json` para garantir que a lista oficial de bares de Teresina seja versionada junto com o código.
2. **Lockfile de Dependências do Aplicativo (`pubspec.lock`)**
   - Como o projeto é um **aplicativo final** (e não um pacote publicado no `pub.dev`), o `pubspec.lock` deve ser mantido no Git para garantir builds 100% reprodutíveis entre todos os desenvolvedores e CI/CD.
3. **Templates de Exemplo sem Segredos Reais**
   - Arquivos `.env.example`, `.env.sample` e `.env.template` são permitidos (`!.env.example`) apenas com placeholders vazios.
4. **Documentação de Arquitetura e Design (`docs/`)**
   - `docs/SPECS.md`, `docs/IMPLEMENTATION_PLAN.md`, `docs/DESIGN.md`, `docs/GITIGNORE_AND_SECURITY_SPECS.md` e protótipos visuais em `docs/stitch/`.

---

## 4. Padrão de Injeção Segura de Variáveis no Flutter

Sempre que uma chave opcional for necessária no futuro (ex.: `CARTO_API_KEY` ou URL de backend), o projeto segue a regra:

1. **No código Dart**: leitura exclusivamente via `String.fromEnvironment('NOME_DA_CHAVE')` (como implementado em [`DrunkMapTileLayer`](file:///home/eduardo/dev/drunk/front/lib/core/widgets/drunk_map_tiles.dart)).
2. **Em desenvolvimento local**: passagem via CLI (`--dart-define=NOME_DA_CHAVE=valor`) ou arquivo `dart_defines.json` (já ignorado no [`.gitignore`](file:///home/eduardo/dev/drunk/front/.gitignore)).
3. **Proibição de Hardcoding**: nenhuma chave privada pode ser escrita em arquivos `.dart`, `.yaml`, `.html` ou `.json` versionados.

---

## 5. Checklist Antes de Qualquer `git commit`

Antes de realizar um commit, execute:

```bash
# 1. Verifica quais arquivos seriam incluídos no commit
git status

# 2. Garante que arquivos sensíveis estão sendo ignorados corretamente
git check-ignore -v .agents/mcp_config.json drunk.db .venv
```

Caso algum arquivo sensível já tenha sido adicionado ao índice do Git no passado, remova-o do rastreamento sem apagá-lo do disco:

```bash
git rm -r --cached .agents/ drunk.db .venv/
```
