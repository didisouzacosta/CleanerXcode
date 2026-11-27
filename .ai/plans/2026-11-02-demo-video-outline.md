# Vídeo de demonstração — esboço do roteiro

Rascunho de 2026-11-02, a pedido do dono. É só a estrutura: textos, telas e tempos
vão mudar, porque o dono ainda vai ajustar detalhes das telas. Não produzir o
vídeo antes de o dono aprovar o roteiro final. O vídeo vai no espaço reservado no
topo do README.

## Objetivo e formato

- **Objetivo:** mostrar o que o app faz, a simplicidade e as vantagens, e deixar
  claro que:
  - ele é gratuito e open source;
  - 100% das doações vão para caridade.
- **Público:** desenvolvedores Apple que usam Xcode.
- **Duração alvo:** 60 a 90 s. Sem cortes longos; uma ideia por cena.
- **Tom:** direto e leve, com animações sutis como as do app.
- **Imagem:** telas reais do app em pt-BR ou en (a decidir), janela 920×620,
  claro e escuro.
- **Áudio:** narração ou só texto na tela com trilha (a decidir). Legendas sempre.
- **Ferramentas:** storyboard no Figma (MCP do Figma), a partir dos frames da
  página 08. A ferramenta de montagem e renderização fica no card do Trello.

## Cenas

| # | Tempo | O que aparece | Texto na tela ou narração (rascunho) | Mensagem |
|---|---|---|---|---|
| 1 | 0–5 s | Ícone do app, fundo neutro | "Seu Mac está cheio por causa do Xcode?" | Gancho |
| 2 | 5–12 s | Gráfico de disco do macOS com Developer ocupando dezenas de GB | "DerivedData, caches, simuladores e runtimes se acumulam sem você ver." | O problema |
| 3 | 12–22 s | Visão geral: total liberável e legenda por seção | "O CleanerXcode mostra quanto espaço você recupera antes de limpar." | Ver primeiro |
| 4 | 22–34 s | Uma seção com os itens, tamanhos e o selo de risco; a confirmação de um item perigoso | "Cada item diz o risco. Os perigosos começam desligados, pedem confirmação e vão para a Lixeira." | Segurança |
| 5 | 34–44 s | Limpar: progresso, Cancelar visível, relatório com "Tentar de novo" | "Um clique para limpar. Dá para cancelar a qualquer momento, e o relatório mostra o que aconteceu." | Simplicidade e controle |
| 6 | 44–56 s | Simuladores e runtimes: "Selecionar duplicados", remover; folha "Baixar runtimes" e a fila | "Remova simuladores duplicados e runtimes antigos, ou baixe os que faltam para o seu Xcode." | Gerência completa |
| 7 | 56–63 s | Barra de menus com o espaço liberável; Ajustes | "Fica na barra de menus, sempre à mão." | Conveniência |
| 8 | 63–69 s | Ajustes › Privacidade | "Sem login e sem dados pessoais. As estatísticas anônimas podem ser desligadas." | Privacidade |
| 9 | 69–78 s | Página do repositório no GitHub, licença MIT, um pull request | "Gratuito e open source. O código está no GitHub, aberto a pull requests e melhorias." | Open source |
| 10 | 78–85 s | Aba Sobre, "Apoiar o projeto" | "As doações são opcionais, e 100% vai para caridade: abrigos e hospitais." | Propósito |
| 11 | 85–90 s | Ícone, botão de download e o endereço do GitHub | "Baixe grátis. github.com/didisouzacosta/CleanerXcode" | Chamada final |

## Pontos a confirmar com o dono

- **Idioma:** idioma do vídeo e das legendas (en, pt-BR ou as duas versões).
- **Narração:** narração ou só texto na tela.
- **Trilha sonora.**
- **Cena 6:** usar o progresso com tempo estimado do C34 se ele estiver pronto até lá.
- **Cena 9:** a frase sobre o que é fechado. Só as chaves de métricas (Himetrica)
  e de relatório de erros (Sentry) ficam fora do repositório. Um build sem elas
  funciona e não envia nada. Entra no vídeo ou fica só no README?
- **Dados das telas:** usar fixtures de preview, sem caminhos, nomes ou UDIDs reais
  da máquina do dono.
