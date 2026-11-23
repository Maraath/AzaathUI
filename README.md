# AzaathUI

Interface completa de RPG de ação para **WoW Forever** (conteúdo WotLK sobre o motor moderno, `## Interface: 16001`): bússola superior, quadros de unidade, barras de ação centralizadas, mapa-múndi próprio, ficha de personagem, mochila, Olho de Azaath e mais.

## Instalação

Copie as três pastas para `World of Warcraft\_classic_\Interface\AddOns\` (ou a pasta AddOns do seu cliente Forever):

- `AzaathUI` (addon principal)
- `AzaathUI_Nav_EK` e `AzaathUI_Nav_Kalimdor` (dados de rota do caminho mágico, opcionais)

## Estrutura

- `AzaathUI/`: código Lua, mídia e dados do addon
- `AzaathUI_Nav_*`: dados de navegação por continente
- `tools/`: geradores de texturas (`gen.js`), extratores de dados e scripts de empacotamento/sincronização

## Créditos e licenças de terceiros

Partes dos dados vêm destes projetos:

- [AzerothCore](https://www.azerothcore.org/): GPL-2.0-or-later
- [pfQuest](https://github.com/shagu/pfQuest): MIT
- Dungeon Master: GPL
- Polestar, OneForAll, TryhardRoutes: dados de referência

O código e a arte próprios deste repositório são distribuídos sob a **GNU GPL v3.0**, que você encontra em [LICENSE](LICENSE).

World of Warcraft e Blizzard Entertainment são marcas registradas da Blizzard Entertainment, Inc. Este projeto não é afiliado à Blizzard.
