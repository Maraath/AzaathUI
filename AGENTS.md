# Regras do Projeto — AzaathUI (ProjectAzaath)

## Estrutura do Projeto

- `AzaathUI/` — o addon. `Compat.lua` e `Core.lua` primeiro (namespace, módulos, API compatível), depois `Modules/` (um módulo por arquivo ou pasta) e `Data/` (dados gerados, não editar à mão). A ordem de carga é a do `AzaathUI.toc`.
  - `Modules/Sheet/` — ficha do personagem (tecla C): `Core.lua` (utilitários e dados), um arquivo por aba e `Window.lua` (janela, abas, eventos; carrega por último). Símbolos comuns em `Azaath.SheetUI`.
  - `Modules/Talents/` — Crisol de talentos: `Core`, `Tree` (leitura das árvores), `Visuals`, `Crucible`, `Panel`, `Page`. Símbolos comuns em `Azaath.TalentsUI`. O bloco entre `@@CURVAS DOS CANTOS@@` em `Visuals.lua` é gerado por `tools/talents-concept/gen-sounds.js`.
  - Nesses dois módulos, cada arquivo importa o que usa no topo (`local X = U.X`); estado que muda (janela atual, aba, seleção) fica direto em `U.campo`, nunca copiado para um `local`.
  - `Modules/Config/` — painel `/azaath`: `Locale.lua` (textos ptBR/enUS por chave; idioma em `AzaathUIDB.config.lang`), `Options.lua` (aplicação ao vivo, migração e o esquema das abas), `Widgets.lua` (estilo e controles), `Window.lua` (janela, navegação, busca). `Modules/Config.lua` ficou só com o Modo de Edição. Opção nova = linha em `Options.lua` + chave com rótulo e descrição nos dois idiomas.
  - `Modules/OlhoAzaath/` — Olho de Azaath (brilho no objeto interativo mirado + ícones de coleta no minimapa). Namespace `Azaath.OlhoNS`, dados em `AzaathUIDB.olho` (o `Core.lua` migra a chave antiga `lueur`), comando `/olho`, idiomas só `enUS` e `ptBR`, texturas em `Media/OlhoAzaath`.
  - `Modules/Nav/` — código de terceiros embutido (Polestar Nav, com `CREDITS.md`/`LICENSE.txt`). Mexer só no necessário.
- `AzaathUI_Nav_EK/`, `AzaathUI_Nav_Kalimdor/` — dados de caminho por continente (addons separados, habilitados por personagem).
- `tools/` — nada daqui vai para o jogo:
  - `Sync-Jogo.ps1` — espelha os três addons na pasta do jogo e confere por hash.
  - `Atualizar-Azaath.bat` (+ `Agendar-Atualizacao-Azaath.ps1`, tarefa diária às 04:00) — regenera os dados e sincroniza.
  - `map-extract/` — extrator de dados do cliente e dos bancos de missões. `questdb.js` gera `Data/Quests/QuestDB.lua` a partir do **ForeverLoremaster** (escolha do usuário em 2026-11-20).
  - `media/` — geradores procedurais de texturas (`generate-*.js`).
  - `*-concept/` — cada pasta recorta da arte de conceito (`concept.png`) as texturas/dados de uma tela; `grimoire-concept/png.js` é biblioteca compartilhada. `preview/` e `insp/` são saídas descartáveis.

## Regras de Código

1. **Limite de 200 locais por função** (o arquivo inteiro conta como uma função). Arquivos grandes agrupam constantes em tabelas e cada aba/parte grande vai para o próprio arquivo. Antes de acrescentar `local` no topo de um arquivo grande, confira a contagem.
2. **Sem globais**: tudo fica no namespace `Azaath` (`local _, Azaath = ...`). Exceções conhecidas: SavedVariables, `SLASH_*`/`BINDING_*` e `Polestar_*` (biblioteca Nav).
3. **Arquivo `.lua` novo ou `.toc` alterado** exige reiniciar o cliente; editar um `.lua` existente basta `/reload`.

## Sincronização Obrigatória com a Pasta do Jogo (WoW AddOns)

O jogo lê uma **cópia** do addon em `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`, não a pasta do projeto. Ao terminar qualquer mudança em `AzaathUI`, `AzaathUI_Nav_EK` ou `AzaathUI_Nav_Kalimdor`, rode:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\Sync-Jogo.ps1
```

Ele espelha as pastas (inclusive apagando no jogo o que saiu do projeto) e confere o conteúdo por hash. Não copie arquivos avulsos à mão: foi assim que a cópia do jogo ficou divergente até 2026-11-20.

## Escopo das Skins (`modern`, `azaath` e `bdo`)

1. **Skins Ativas**: **New Modern** (`modern`), **Azaath (arte de conceito)** (`azaath`) e **Black Desert** (`bdo`). As skins `classic` e `azaath_crystal` foram removidas e não devem ser reintroduzidas (o `Core.lua` converte as escolhas antigas para `modern`).
2. **Apenas Barra de Tarefas e Frame do Personagem**: As skins aplicam-se **exclusivamente** à barra de tarefas (barras de ação / action bars) e ao frame do personagem (barra de vida, recurso e XP).
3. **Demais Áreas da Interface Inalteradas**: Todas as outras áreas da interface (minimapa, micro menu, ficha de personagem, placas de nome, alvo, grupo, inventário, rastreador de quests, bússola, chat, etc.) devem permanecer **iguais às já estabelecidas**, independentemente da skin selecionada. Não crie variações por skin fora da barra de tarefas e do frame do personagem (vida/recurso/XP).
4. **Buffs e Debuffs na Skin Azaath**: Na skin `azaath`, os buffs e debuffs do jogador devem **sempre** acompanhar a barra de vida / HUD Azaath por padrão, tanto em **posição** (presos à âncora da HUD) quanto em **dimensionamento** (acompanhando a escala da HUD Azaath). Na skin `modern`, manter o comportamento já estabelecido (edição livre de posição e tamanho).
5. **Visual da mochila é escolha à parte**: `inventory.style` (`classic` ou `azaath`, Modules/InventorySkin.lua) não segue a skin global; é uma opção própria do inventário pedida pelo usuário (2026-11-23).

## Mapa-Múndi Próprio do Azaath (sem OpenMap)

O mapa antigo, portado do **OpenMap**, foi removido em 2026-11-17 (a cópia de segurança foi descartada em 2026-11-20). O mapa do `AzaathUI` está sendo criado **do zero** e **não deve depender nem copiar código ou dados de addons de terceiros** (OpenMap, Leatrix Maps etc.).

1. **Dados em tempo real vêm do jogo**: hierarquia de mapas, arte, áreas exploradas, posição, nomes e demais informações devem usar as funções do próprio cliente (`C_Map`, `C_MapExplorationInfo`, `C_TaxiMap` etc.), para que o mapa acompanhe os patches automaticamente.
2. **O que o jogo não informa ao addon** (quadros do minimapa, partes das zonas inexploradas, posição dos nomes de sub-região) é gerado pelo nosso extrator em `D:\ProjectAzaath\tools\map-extract\`, que lê os arquivos de dados do cliente instalado. Edite o extrator e gere de novo; não edite os arquivos gerados à mão. Após um patch do jogo, rode o extrator outra vez.
3. **Ervas e minérios**: podem integrar com o GatherLite quando ele estiver instalado, mas o mapa deve funcionar sem ele (coletor próprio).
   **Exceção autorizada pelo usuário (2026-11-17)**: as áreas dos objetivos de missão usam dados e código do Polestar — `Data/Map/QuestAreas.lua` (gerado por `tools/map-extract/questareas.js` a partir do `Polestar_QuestDB`, origem pfQuest/MIT, aviso em `Data/Map/QuestAreas-NOTICE.txt`) e `Modules/MapRegions.lua` (cópia do `Nav/Regions.lua` do Polestar, GPL-3.0, com crédito). Não remover essa atribuição.
   **Exceção autorizada pelo usuário (2026-11-18)**: o nível mínimo de profissão das missões (coluna `skill` de `Data/Quests/QuestDB.lua`, formato `SkillLine:nível`) vem do QuestieDB (`github.com/Questie/QuestieDB`, `data/Classic/classicQuestDB.lua`, GPL-3.0), lido por `tools/map-extract/questie-skills.js` a partir da cópia em `tools/map-extract/thirdparty/questiedb/` (não vai para o addon; nenhum addon precisa estar instalado). Crédito em `Data/Quests/QuestDB-NOTICE.txt`; não remover.
4. Mantenha a sincronização obrigatória com a pasta ativa do jogo.
