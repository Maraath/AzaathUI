# AzaathUI

**[PT-BR]** | **[EN-US abaixo / below]**

---

## 🇧🇷 Português

### Transforme o WoW Forever num RPG de ação

O **AzaathUI** troca a interface inteira do jogo por uma experiência de **RPG de ação moderno**, inspirada em títulos como New World e Black Desert. A arte é toda desenhada para o addon. O HUD fica no centro da tela, as placas de nome são vivas e as janelas parecem artefatos do próprio mundo.

Feito especialmente para o **WoW Forever** (conteúdo WotLK sobre o motor moderno).

### ✨ Destaques

**HUD de combate**
- Bússola no topo da tela, no lugar do minimapa tradicional
- Vida, recurso, XP e barras de ação centralizados, com tudo à vista sem desviar o olhar da luta
- Várias skins: **Azaath**, **Black Desert (Zerker)**, **Modern** e **Classic**, cada uma com sua disposição das barras
- Conjuração em espiral e auras integradas ao HUD

**Placas de nome dos inimigos**
- Barras redesenhadas sobre a cabeça dos inimigos
- Marcadores de alvo, mouse e **objetivo de missão**
- Molduras especiais para **raros** e **elites**
- **Facho de saque** sobre os corpos que ainda têm loot

**Combate**
- Texto de dano flutuante estilizado (`/damage`)
- Câmera de ação com FreeLook

**Mapa-múndi próprio**
- Moldura "Expedição" desenhada à mão, com pedra, runas e estandartes
- Missões, **portas de masmorra** e faixa de nível das zonas
- **Rare Scanner**: localiza e avisa sobre monstros raros (`/azrare`)
- **Caminho mágico** que guia até o objetivo (rotas nos módulos `AzaathUI_Nav_EK` e `AzaathUI_Nav_Kalimdor`)

**Ficha de personagem (tecla C)**
- Card de atributos, **Crisol de talentos** com as 3 árvores juntas, reputação e perícias
- **Santuário** com catálogo de masmorras, chefes e drops
- **Grimório** em forma de livro, com som de virar a folha

**Mochila e itens**
- Mochila com skin própria e **trava de itens**
- Painel Equipado com astrolábio animado
- **Card de item** no lugar da tooltip, com preço de leilão (`/leilao`)
- Diário de saques (`/saques`)

**Ofícios**
- **Mesa do Artesão**: profissões com cartas, altar e mochila

**Olho de Azaath**
- Central do addon: menu radial, painel **Loremaster** com guias de missão (`/lore`) e assistente de configuração em 6 etapas (`/olho`)

### 📦 Instalação

1. Instale pelo app do CurseForge **ou** extraia o zip na pasta `Interface\AddOns` do seu cliente WoW Forever.
2. São 3 pastas:
   - `AzaathUI`: o addon principal (obrigatório)
   - `AzaathUI_Nav_EK` e `AzaathUI_Nav_Kalimdor`: rotas do caminho mágico (opcionais)
3. Entre no jogo. O assistente de configuração abre na primeira vez. Depois, use `/azaath` ou `/olho`.

> As configurações são salvas **por personagem**.

### ⌨️ Comandos

| Comando | Função |
|---|---|
| `/azaath` | Comandos gerais do addon |
| `/olho` | Abre o Olho de Azaath (menu e configuração) |
| `/lore` | Painel Loremaster (guias de missão) |
| `/azrare` | Rare Scanner |
| `/damage` | Opções do dano flutuante |
| `/leilao` | Preços de leilão |
| `/saques` | Diário de saques |

### ⚠️ Observações

- Versão **beta**: bugs podem acontecer. Relate na aba *Issues* do GitHub.
- Feito para o **WoW Forever**. Não funciona em outros clientes.
- Por regras do próprio jogo, a posição do jogador e do grupo **não aparece dentro de masmorras**.

### 🙏 Créditos

Dados de missões, NPCs e masmorras adaptados de **AzerothCore** (GPL-2.0+), **pfQuest** (MIT), **Dungeon Master**, **Polestar**, **OneForAll** e **TryhardRoutes**. Código e arte próprios sob **GPL-3.0**.

Código-fonte: https://github.com/Maraath/AzaathUI

---

## 🇺🇸 English

### Turn WoW Forever into an action RPG

**AzaathUI** replaces the entire game interface with a **modern action-RPG experience**, inspired by titles like New World and Black Desert. All the art is drawn for the addon. The HUD sits at the center of the screen, the nameplates come alive, and the windows look like artifacts from the world itself.

Built specifically for **WoW Forever** (WotLK content on the modern engine).

### ✨ Highlights

**Combat HUD**
- Top-of-screen compass instead of the traditional minimap
- Centered health, resource, XP and action bars, so you see everything without looking away from the fight
- Multiple skins: **Azaath**, **Black Desert (Zerker)**, **Modern** and **Classic**, each with its own bar layout
- Spiral cast bar and auras built into the HUD

**Enemy nameplates**
- Redesigned bars above enemies' heads
- Target, mouseover and **quest objective** markers
- Special frames for **rares** and **elites**
- **Loot beam** above corpses that still have loot

**Combat**
- Stylized floating combat text (`/damage`)
- Action camera with FreeLook

**Custom world map**
- Hand-drawn "Expedition" frame with stone, runes and banners
- Quests, **dungeon entrances** and zone level ranges
- **Rare Scanner**: finds rare monsters and alerts you (`/azrare`)
- **Magic path** that guides you to your objective (routes in the `AzaathUI_Nav_EK` and `AzaathUI_Nav_Kalimdor` modules)

**Character sheet (C key)**
- Attribute card, **Talent Crucible** with all 3 trees together, reputation and skills
- **Sanctuary** with a catalog of dungeons, bosses and drops
- Book-style **Grimoire**, with a page-turn sound

**Bags and items**
- Custom bag skin with **item lock**
- Equipped panel with an animated astrolabe
- **Item card** in place of the tooltip, with auction prices (`/leilao`)
- Loot journal (`/saques`)

**Professions**
- **Artisan's Table**: professions with cards, an altar and a bag

**Eye of Azaath**
- The addon's hub: radial menu, **Loremaster** panel with quest guides (`/lore`) and a 6-step setup wizard (`/olho`)

### 📦 Installation

1. Install through the CurseForge app **or** extract the zip into your WoW Forever `Interface\AddOns` folder.
2. It contains 3 folders:
   - `AzaathUI`: the main addon (required)
   - `AzaathUI_Nav_EK` and `AzaathUI_Nav_Kalimdor`: magic path routes (optional)
3. Log in. The setup wizard opens the first time. After that, use `/azaath` or `/olho`.

> Settings are saved **per character**.

### ⌨️ Commands

| Command | Function |
|---|---|
| `/azaath` | General addon commands |
| `/olho` | Opens the Eye of Azaath (menu and settings) |
| `/lore` | Loremaster panel (quest guides) |
| `/azrare` | Rare Scanner |
| `/damage` | Floating combat text options |
| `/leilao` | Auction prices |
| `/saques` | Loot journal |

### ⚠️ Notes

- **Beta** release: bugs may happen. Please report them in the GitHub *Issues* tab.
- Built for **WoW Forever**. It does not work on other clients.
- Due to the game's own rules, player and party positions **are not shown inside dungeons**.
- The in-game interface is currently in **Brazilian Portuguese**.

### 🙏 Credits

Quest, NPC and dungeon data adapted from **AzerothCore** (GPL-2.0+), **pfQuest** (MIT), **Dungeon Master**, **Polestar**, **OneForAll** and **TryhardRoutes**. Original code and art under **GPL-3.0**.

Source code: https://github.com/Maraath/AzaathUI
