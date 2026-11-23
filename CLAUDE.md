# Diretrizes do Projeto (Addon WoW)

- Responda sempre em Português do Brasil.
- Alvo: WoW Forever (conteúdo WotLK sobre o motor moderno, `## Interface: 16001`). Use as APIs desse cliente (`C_*`, valores secretos em combate); diferenças com a API antiga ficam em `Compat.lua`.
- Estrutura, sincronização com o jogo e regras de código: ver `AGENTS.md`.

## Regras Estritas de Economia de Tokens
- **Respostas curtas:** Vá direto ao ponto. Não escreva introduções longas, resumos óbvios ou explicações linha a linha de código trivial.
- **Leitura cirúrgica:** Nunca varra o projeto inteiro sem necessidade. Consulte primeiro o arquivo `.toc` para localizar os módulos e leia apenas os arquivos diretamente envolvidos na tarefa.
- **Addons de inspiração:** Nunca leia pastas de referência (`Referencias/`, `References/`, `Inspiracoes/`) ou `Libs/` por conta própria, a menos que o usuário mencione explicitamente o caminho com `@`.
- **Edições pontuais:** Ao alterar arquivos `.lua` ou `.xml`, modifique apenas o trecho necessário em vez de reescrever o arquivo inteiro.
- **Sem excesso de verificação:** Não execute múltiplos comandos ou leituras redundantes após aplicar uma edição simples.