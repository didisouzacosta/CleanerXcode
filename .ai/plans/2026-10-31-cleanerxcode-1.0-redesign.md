# CleanerXcode 1.0 — Plano de redesign nativo (nível 2)

Plano do Manager, revisado pelo agente principal em 2026-10-31. Pendente da aprovação do dono (card D00).

PLAN_STATUS: READY

Papel: Manager (planejamento, nível 2), somente leitura. Nenhum arquivo foi editado e nada foi criado no Figma ou no Trello. Data da análise: 2026-10-31. Branch `v1.0.0`, commit `f11d52c`.

O plano é executável tomando como premissas as recomendações da seção "Perguntas bloqueadoras/decisões do dono". Nenhuma delas impede começar pela fase de layout (card C01). As decisões D1 a D14 ficam num card próprio no Trello para o dono confirmar antes da fase de implementação.

---

## Perguntas bloqueadoras/decisões do dono (com recomendação; não bloqueiam)

| ID | Decisão | Recomendação (premissa do plano) |
|---|---|---|
| D1 | Canal de distribuição | **Fora da Mac App Store**, com Developer ID, Hardened Runtime, notarização e DMG, sem App Sandbox. Justificativa na seção 4 |
| D2 | Deployment target | **macOS 26.0** nos dois targets e no projeto. Liquid Glass nativo, sem caminho de fallback |
| D3 | Modelo de cena | **Uma `Window` principal** com ícone no Dock, cena `Settings` e `MenuBarExtra` **opcional**, ligado por padrão para preservar o hábito de quem atualiza |
| D4 | Dependências que podem sair além do Firebase | Remover **swift-timeout** (deixa de ser necessário sem o `Shell`) e o **fork do LaunchAtLogin** por SSH, que passa a ser `SMAppService.mainApp`, API do sistema |
| D5 | Padrões das categorias | Itens seguros novos ligados. Itens de atenção e perigosos desligados. **Archives passa a vir desligado para quem nunca mexeu na opção**, e a escolha salva de quem já mexeu é preservada. Os demais itens legados mantêm o padrão antigo |
| D6 | Destino dos itens perigosos (Archives, dados do usuário do Xcode) | **Mover para a Lixeira** (`trashItem`), com aviso de que o espaço só é liberado depois de esvaziar a Lixeira. Os demais itens são removidos de forma definitiva |
| D7 | Idade mínima na pasta temporária | **3 dias** por padrão, com opções de 1, 3, 7 e 14 em Ajustes |
| D8 | Desligar o analytics | Opção em Ajustes, "Enviar estatísticas anônimas de uso", **ligada por padrão**, com o README atualizado |
| D9 | Envio de dSYMs ao Sentry | O dono instala o **sentry-cli** localmente (Homebrew) e o roda manualmente no checklist de release. Ele não entra como dependência do app nem como fase de build. Depende do aceite da ferramenta |
| D10 | Forma de integrar o Himetrica | **SDK oficial `himetrica-swift`, versão exata 1.0.0**, sem dependências transitivas. A alternativa de um cliente HTTP próprio é inviável: a Server API exige chave secreta, e o endpoint de cliente não é documentado |
| D11 | Instalar runtimes | Prioridade P3, fora do marco 1.0 |
| D12 | Compartilhar o scheme para CI | Tirar `xcshareddata/` do `.gitignore` e versionar o scheme e o test plan. Opcional, mas recomendado |
| D13 | Versão de entrega | 1.0.0, build 115 |
| D14 | Provisioning Profiles | Sub-opção separada dentro de "Dados do usuário do Xcode", marcada como perigosa e sempre desmarcada por padrão |

---

## 1. Inventário de funcionalidades

Escala de risco usada abaixo:
- **seguro**: o conteúdo é regenerado sozinho e o único custo é tempo.
- **atenção**: custo relevante, como novo download, primeiro debug lento ou dados do simulador perdidos.
- **perigoso**: perda de dados do usuário, de dados não regeneráveis ou de dados difíceis de recuperar.

### 1.1 Funcionalidades atuais mantidas (reescritas de forma nativa)

| ID | Funcionalidade | Risco do alvo | Observação |
|---|---|---|---|
| F1 | Medir o espaço por categoria e o total liberável | — | `FileManager` e `URLResourceValues` substituem `du` |
| F2 | Botão "Limpar <tamanho>" em destaque com o total das categorias selecionadas | — | `.buttonStyle(.glassProminent)` |
| F3 | Selecionar categorias com o tamanho ao lado e persistir a escolha | — | Migra as chaves existentes do `UserDefaults` |
| F4 | DerivedData (`~/Library/Developer/Xcode/DerivedData/*`) | seguro (atenção com o Xcode aberto) | Remove o conteúdo e mantém a pasta |
| F5 | Archives (`~/Library/Developer/Xcode/Archives/*`) | **perigoso** | Contém os dSYMs usados na simbolicação e no reenvio à loja. Vai para a Lixeira e pede confirmação |
| F6 | Caches do Xcode e de gerenciadores: `~/Library/Caches/com.apple.dt.Xcode`, `~/Library/Caches/com.apple.dt.xcodebuild`, `~/Library/Caches/org.carthage.CarthageKit`, `~/Library/Caches/CocoaPods` | seguro | Remover a pasta do CocoaPods substitui `pod cache clean --all` |
| F7 | Device Support (`~/Library/Developer/Xcode/{iOS,watchOS,tvOS,visionOS,macOS} DeviceSupport`) | atenção | É copiado de novo ao conectar o aparelho, e o primeiro debug fica lento |
| F8 | Apagar o conteúdo de todos os simuladores | atenção | Antes era `rm -rf ~/Library/Developer/CoreSimulator`. Agora é `simctl shutdown all` seguido de `simctl erase all` |
| F9 | Remover simuladores indisponíveis (`simctl delete unavailable`) | seguro | Agora entra no relatório |
| F10 | Redefinir as preferências do Xcode | **perigoso** | `UserDefaults.standard.removePersistentDomain(forName: "com.apple.dt.Xcode")`. Fica bloqueado com o Xcode aberto. Perde o local customizado do DerivedData, comportamentos e estado de janelas |
| F11 | Espaço liberável na barra de menus | — | Passa a ser um `MenuBarExtra` opcional |
| F12 | Abrir no login | — | Passa a usar `SMAppService.mainApp` |
| F13 | Verificar atualização (`version.json`) e mostrar o botão Atualizar | — | Corrige a comparação de versões |
| F14 | Links sociais, dedicatória e doação | — | Vão para a aba Sobre em Ajustes e para o rodapé |
| F15 | Analytics de produto | — | **Migra para o Himetrica**, desligado em DEBUG |
| F16 | Localização en (fonte) e pt-BR | — | `Localizable.xcstrings` |
| F17 | Sair (Cmd+Q) | — | Menu padrão do app e item no `MenuBarExtra` |

### 1.2 Funcionalidades novas

| ID | Funcionalidade | Risco | Padrão |
|---|---|---|---|
| F18 | Pasta temporária: `$TMPDIR` (`/var/folders/<x>/<y>/T/`), `/private/tmp` e `/private/var/tmp`, só com itens do usuário que passaram da idade mínima | atenção | desligado |
| F19 | Temporários órfãos de simuladores (`/private/var/tmp/com.apple.CoreSimulator.SimDevice.<UDID>` sem simulador correspondente em nenhum device set). Nesta máquina: 80 pastas para 14 simuladores, dentro de 1,6 GB em `/private/var/tmp` | seguro | ligado |
| F20 | Listar simuladores com nome, tipo, runtime, estado, tamanho (`dataPathSize` + `logPathSize`), último uso e disponibilidade, marcando duplicados | — | — |
| F21 | Apagar simuladores selecionados ou duplicados (`simctl shutdown` e depois `simctl delete <udid…>`) | atenção | ação por item |
| F22 | Listar runtimes (tamanho, último uso, `deletable`) e apagar com `simctl runtime delete <id>` | **perigoso** (novo download de vários GB, e os simuladores dependentes são removidos) | ação por item |
| F23 | Device sets auxiliares: `~/Library/Developer/XCTestDevices`, `~/Library/Developer/Xcode/UserData/Previews`, `~/Library/Developer/Xcode/UserData/IB Support` e `~/Library/Developer/XCPGDevices` (`simctl --set <path> shutdown all` e `delete all`) | seguro | ligado |
| F24 | Caches e logs do CoreSimulator: `~/Library/Developer/CoreSimulator/Caches/*` (exceto `Personalization`), `~/Library/Developer/CoreSimulator/Temp/*` e `~/Library/Logs/CoreSimulator/*` | seguro (reinicia o serviço) | ligado |
| F25 | Cache do SwiftPM (`~/Library/Caches/org.swift.swiftpm`, 3,5 GB nesta máquina) | atenção (os pacotes são baixados de novo e builds offline falham) | desligado |
| F26 | Products do Xcode (`~/Library/Developer/Xcode/Products/*`) | atenção | desligado |
| F27 | Dados do usuário do Xcode (`~/Library/Developer/Xcode/UserData/*`, exceto Previews e IB Support, que estão em F23): temas, atalhos (`KeyBindings`), snippets, breakpoints, `Capabilities`, `XcodeCloud` e `IDEEditorInteractivityHistory`. A sub-opção F27b cobre `UserData/Provisioning Profiles` e o caminho legado `~/Library/MobileDevice/Provisioning Profiles` | **perigoso** | desligado (Lixeira) |
| F28 | Relatório da limpeza por item (removido, pulado, falhou), estado de falha parcial e "Tentar de novo" só para os itens que falharam | — | — |
| F29 | Cancelar a limpeza em andamento, com granularidade por item | — | — |
| F30 | Confirmação antes de executar itens perigosos e de atenção, nomeando cada item e o efeito | — | — |
| F31 | Detectar Xcode e Simulator abertos e avisar. Encerra o Simulator com consentimento | — | — |
| F32 | Encerrar simuladores e reiniciar o CoreSimulatorService sem reiniciar o Mac | — | — |
| F33 | Relatório de crashes e erros com **Sentry** | — | ligado em Debug e Release, em ambientes separados |
| F34 | Janela de Ajustes: abrir no login, barra de menus, idade mínima da pasta temporária, opt-out do analytics, Sobre | — | — |
| F35 | (P3, opcional) Instalar runtime com `xcodebuild -downloadPlatform` | — | — |

### 1.3 Funcionalidades removidas

| ID | O que sai | Substituto |
|---|---|---|
| FR1 | Scripts bash (`Shell`, `Command`, `CommandExecutor`, `Scripts/*.sh`) | Serviços nativos, e `Process` direto em `/usr/bin/xcrun` só para o `simctl` |
| FR2 | Recálculo com `du` a cada ~6 s (`Timer`) | Medição sob demanda: ao abrir ou ativar a janela, após a limpeza e no botão Atualizar |
| FR3 | Firebase Core, Analytics e Crashlytics, com todas as dependências transitivas: GoogleAppMeasurement, GoogleUtilities, GoogleDataTransport, nanopb, Promises, abseil-cpp-binary, grpc-binary, leveldb, gtm-session-fetcher, app-check, interop-ios-for-google-sdks, google-ads-on-device-conversion-ios-sdk e swift-protobuf | Himetrica (F15) e Sentry (F33) |
| FR4 | Telas Cleaner e Preferences com navegação lateral (`Route`, `MainView`) | Janela única e cena `Settings` |
| FR5 | App só de barra de menus (`LSUIElement = YES`) | App de janela com barra de menus opcional |
| FR6 | `MIXPANEL_TOKEN` (em `Config.xcconfig` e `Info.plist`) e `Bundle.mixpanelToken` | Nada. O dono deve revogar o token no Mixpanel, porque ele continua no histórico do git |
| FR7 | `pod cache clean --all` | Remoção nativa de `~/Library/Caches/CocoaPods` |
| FR8 | `rm -rf ~/Library/Developer/CoreSimulator` | F8, F21, F23 e F24 |
| FR9 | Dependências swift-timeout e LaunchAtLogin | Depende de D4 |
| FR10 | `import Charts` e `import TipKit` sem uso, `ExpandableButton`, `HighlightButton`, `CustomCircularProgressViewStyle`, `ScrollContentHeightModifier`, `StoragedValue` genérico e `String: Error` (`@retroactive`) | Componentes do sistema com estilos glass e erros tipados |

### 1.4 Fora do escopo, por segurança

- `/Library/Developer/CoreSimulator/*` (Images, Volumes, Cryptex, Caches/dyld): pertence a root e a disk images montadas. Só a via `simctl runtime delete` mexe nisso.
- `/System/Library/AssetsV2/...`: protegido pelo SIP.
- `/var/folders/.../C` (cache do sistema por usuário) e `/var/folders/.../0`.
- `~/Library/org.swift.swiftpm` e `~/.swiftpm`: configuração do usuário, como mirrors, registries e fingerprints.
- O que ainda precisa de investigação de leitura no card C10 antes de virar categoria: `~/Library/Developer/CoreDevice` (637 MB, DeviceFS de aparelhos físicos), `~/Library/Developer/Xcode/CodingAssistant` (pode conter histórico do usuário), `~/Library/Developer/DVTDownloads` e o cache de documentação do Xcode 27.
- Keychain e contas do Xcode.

---

## 2. Requisitos, fluxos, estados e restrições

### 2.1 Requisitos funcionais

- **R1 (F1)**: medir de forma nativa o tamanho alocado de cada categoria, sem bash e com cancelamento. Repetir a medição ao abrir ou ativar a janela (com debounce de 2 s e cache de 60 s), depois de cada limpeza e no botão Atualizar. Sem polling periódico.
- **R2 (F2)**: o total liberável é a soma das categorias selecionadas que já foram medidas, e aparece em destaque no topo e no botão "Limpar <tamanho>". Se nada estiver selecionado, ou o total for 0, o botão fica desabilitado e mostra "Nada a limpar". O total é sempre rotulado como "estimado", porque clones APFS e hard links podem gerar diferença.
- **R3 (F3)**: a seleção persiste por categoria. Na migração v1→v2, os valores salvos nas chaves legadas são preservados (seção 9).
- **R4 (F4–F10, F18, F19, F23–F27)**: há um catálogo declarativo de categorias com ID estável, raízes, exclusões, método (remover o conteúdo, Lixeira, comando `simctl`, reset de domínio), risco e padrão. O catálogo fica numa tabela única e testável (seção 5.4).
- **R5 (F30, F31)**:
  - antes de executar, se o plano tiver itens perigosos ou de atenção, abre uma confirmação que lista cada um com o efeito e o destino (Lixeira ou definitivo);
  - com o Xcode aberto, F10 e F27 ficam bloqueados ("Feche o Xcode") e F4 mostra um aviso;
  - com o Simulator aberto ou simuladores ligados, F8, F21, F22, F23 e F24 avisam que eles serão encerrados.
- **R6 (F28)**: a limpeza registra o resultado de cada item. O estado final é sucesso só se nenhum item falhou, falha parcial se alguns falharam e falha se todos falharam. Item inexistente conta como "pulado", não como falha. É proibido mostrar sucesso quando algo falhou.
- **R7 (F29)**: o cancelamento acontece entre itens, sobre os filhos diretos de cada raiz. O resultado final é "cancelado", com o que já foi liberado. Um processo `simctl` em andamento recebe `terminate()`.
- **R8 (F9, F20, F21)**: a seção Simuladores lista os simuladores do set padrão a partir de `simctl list --json devices`. O tamanho vem de `dataPathSize + logPathSize`, ou da enumeração da pasta do simulador quando esses campos faltam. Duplicados são grupos com o mesmo `deviceTypeIdentifier` e o mesmo runtime; o mais recente por `lastUsedAt` é sugerido para ficar. A ação "Remover duplicados (n)" seleciona os outros e nunca apaga sozinha. Apagar significa desligar os simuladores ligados e depois rodar `simctl delete`.
- **R9 (F22)**: a lista de runtimes vem de `simctl runtime list --json` e mostra versão, build, `sizeBytes`, `lastUsedAt`, `deletable` e quantos simuladores dependem de cada runtime. Apagar exige uma confirmação de perigo informando que os simuladores dependentes serão removidos e que o runtime terá de ser baixado de novo, e roda `simctl runtime delete <identifier>`. Runtimes com `deletable == false` aparecem desabilitados.
- **R10 (F32)**: nenhuma operação apaga arquivos em `/Library/Developer/CoreSimulator`. Antes de qualquer operação com simuladores, o app roda `simctl shutdown all` (em cada set afetado) e encerra o Simulator.app com `NSRunningApplication.terminate()`. Se a operação incluiu remoção direta de arquivos dentro de `~/Library/Developer/CoreSimulator` (F24), o app reinicia o CoreSimulatorService; o launchd o relança na próxima chamada. Critério: depois de qualquer limpeza, `simctl list` e o boot de um simulador funcionam sem reiniciar o Mac.
- **R11 (F18)**: a pasta temporária tem salvaguardas:
  - só itens cujo dono é o usuário atual (`getuid()`);
  - idade mínima calculada pela modificação mais recente, recursiva para pastas, com `contentModificationDateKey`;
  - itens que não são arquivo, pasta ou link simbólico (sockets, FIFOs) são pulados;
  - uma lista de exclusões não é apagada (`com.apple.launchd.*`, `.X11-unix`, `powerlog`, `*.sock`, os próprios arquivos do app e os itens de F19, que são tratados em F19);
  - `EBUSY`, `EPERM` e `EACCES` fazem o item ser pulado como "em uso ou sem permissão", sem virar falha da categoria;
  - aviso fixo na linha: "Feche apps de IA e terminais antes. Itens com menos de N dias são preservados."
- **R12**: quando `/usr/bin/xcrun` ou `simctl` não existirem (Xcode ausente ou `xcode-select` apontando para as Command Line Tools), a seção Simuladores e as categorias F8, F9 e F23 ficam no estado "Ferramentas do Xcode indisponíveis", com orientação. As demais categorias continuam funcionando.
- **R13**: o app não pede permissão preventivamente e nunca usa `NSOpenPanel`. Se a operação devolver `EPERM` por TCC, ela termina em "Permissão negada", com um botão para "Ajustes do Sistema > Privacidade e Segurança > Acesso Total ao Disco" (`x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`) e "Tentar de novo".
- **R14 (F11, F34)**: janela única com Liquid Glass, cena `Settings` e `MenuBarExtra(isInserted:)` opcional. Com a barra de menus ligada, fechar a janela não encerra o app; com ela desligada, fechar a última janela encerra.
- **R15 (F12)**: abrir no login usa `SMAppService.mainApp` (`register()`, `unregister()`, `status`). A preferência legada `launch-at-login` só é usada uma vez na migração.
- **R16 (F13)**: a verificação de atualização compara versões semânticas por componente numérico, de modo que `0.10.0` é maior que `0.9.0`. Erros de rede são silenciosos para o usuário e registrados como breadcrumb.
- **R17 (F14)**: a aba Sobre em Ajustes reúne versão, atualização, links sociais, dedicatória e doação. O rodapé da janela mostra versão e "Atualizar" quando houver versão nova.
- **R18 (F16)**: todas as strings novas existem em en e pt-BR. Ícones têm rótulo de acessibilidade, a linha de cada categoria tem `accessibilityValue` com tamanho e estado, e o layout funciona com texto grande e com "Reduzir transparência".
- **R19**: Swift language mode 6 no toolchain Swift 6.4.2, isolamento padrão `MainActor`, Approachable Concurrency, deployment target macOS 26.0 e zero avisos.
- **R20 (FR3)**: remover o Firebase por completo (pacotes, produtos, `GoogleService-Info*.plist`, `AppDelegate`, `.gitignore`, README, Release Notes) sem sobrar nenhuma entrada do Google no `Package.resolved`.
- **R21 (F15)**: analytics com Himetrica atrás do protocolo `Analytics`, com implementação nula em testes, previews e DEBUG. Eventos com nomes estáveis, sem dados pessoais nem caminhos, e opt-out em Ajustes.
- **R22 (F33)**: Sentry atrás do protocolo `ErrorReporting`, com implementação nula em testes e previews. Liga em DEBUG e Release com `environment` separado e `release` contendo versão e build. Usa `sendDefaultPii = false` e sanitização em `beforeSend`, e os erros da limpeza viram eventos agregados.
- **R23**: a chave do Himetrica e o DSN do Sentry ficam fora do repositório, em `Secrets.xcconfig` não versionado, com um exemplo versionado. O `MIXPANEL_TOKEN` é removido.
- **R24 (FR1, FR9, FR10)**: remover o `Shell`, os scripts e o código morto, e as dependências da D4.
- **R25**: distribuição por Developer ID, notarização, stapling e DMG, com envio de dSYMs ao Sentry (D9).
- **R26 (F35, P3)**: instalar runtime com `xcodebuild -downloadPlatform <plataforma>`.
- **R27**: testes e previews nunca apagam dados reais, nunca rodam `simctl` contra o sistema e nunca inicializam o Himetrica ou o Sentry reais. O app hospedeiro dos testes (`TEST_HOST`) detecta que está em teste e monta tudo com implementações nulas, sem medir nada.

### 2.2 Requisitos não funcionais

- **N1**: nenhum I/O de disco ou de processo roda no main actor. A interface continua responsiva medindo 30 GB de DerivedData; o tempo é registrado como evidência, não prometido.
- **N2, segurança de caminho**: todo caminho a remover passa pela `SafePathPolicy`:
  - o caminho é padronizado;
  - precisa ser descendente estrito de uma raiz do catálogo;
  - nunca é a própria raiz, nem `~`, `/` ou `~/Library`;
  - links simbólicos não são seguidos (remove-se o link, não o alvo);
  - não pode estar em volumes montados (`volumeIsRootFileSystemKey` e comparação do `volumeIdentifierKey` com o da raiz).
- **N3, privacidade**: nenhum payload de analytics ou de erro leva caminho completo, nome de arquivo, nome de simulador, UDID, usuário ou e-mail.
- **N4**: Light, Dark, "Reduzir transparência", "Aumentar contraste" e VoiceOver.
- **N5**: `scripts/lint-swift.sh` sem violações e estilo do `SWIFT_REFERENCE` (MARKs, espaçamento, um modificador por linha).
- **N6**: nenhuma dependência nova além de `himetrica-swift` e `sentry-cocoa`, ambas com versão exata.
- **N7**: binário assinado e notarizado, com Hardened Runtime e sem entitlements de sandbox.

### 2.3 Fluxos

1. **Abrir o app**: a janela aparece e todas as linhas ficam em "Medindo…". Os tamanhos chegam em paralelo, o total vai somando, e o botão é habilitado quando há total maior que zero.
2. **Limpar**: tocar em "Limpar 38,4 GB" monta um plano.
   - Se o plano tiver itens perigosos ou de atenção, ou se houver Xcode ou Simulator abertos, abre a confirmação, que pode ser cancelada ou confirmada.
   - Durante a limpeza aparecem a barra de progresso, o item atual e o botão Cancelar.
   - O resultado é o relatório: sucesso, falha parcial com a lista e "Tentar de novo", ou cancelado.
   - Depois disso o app mede tudo de novo.
3. **Simuladores**: expandir a seção carrega a lista. É possível selecionar linhas ou "Remover duplicados", confirmar, encerrar os simuladores, apagar, recarregar e mostrar o resultado.
4. **Runtimes**: apagar uma linha abre a confirmação de perigo; depois roda `simctl runtime delete`, a lista é recarregada e os simuladores dependentes somem.
5. **Ajustes** (Cmd+, ou o botão da toolbar): abas Geral e Sobre.
6. **Barra de menus**: o painel mostra o total, "Limpar <tamanho>", "Abrir CleanerXcode" e "Sair". Se o plano tiver um item perigoso, o botão do painel abre a janela principal já na confirmação.
7. **Atualização**: com versão nova, o rodapé e a aba Sobre mostram "Atualizar", que abre a URL do DMG.

### 2.4 Estados (contrato da tela)

**Janela principal (`CleanerPhase`):**
- `measuring(first:)`: linhas com placeholder e total "Medindo…";
- `ready`: total maior que zero e botão ativo;
- `nothingSelected`: nada selecionado;
- `nothingToClean`: tudo medido e total 0;
- `confirming(plan)`;
- `cleaning(progress)`, com item atual, n de m, bytes liberados e Cancelar;
- `cancelling`;
- `finished(report)`, com variantes sucesso, falha parcial, falha e cancelado;
- `permissionDenied(report)`.

**Por linha de categoria:**
- `measuring`, `measured(bytes)`, `empty` (0 B ou pasta ausente), `unavailable(reason)` (ferramentas ausentes, Xcode aberto) e `failed(kind)`.

**Seção Simuladores:**
- `loading`, `loaded`, `empty`, `toolsUnavailable`, `failed` e `deleting(udids)`.

**Avisos fixos:**
- Xcode aberto, Simulator aberto e itens que vão para a Lixeira.

### 2.5 Restrições

- O dono não seleciona pastas, nunca.
- Nada de bash: `Process` só para `/usr/bin/xcrun` (simctl e, no P3, xcodebuild), com argumentos em array e sem shell.
- Preservar as alterações locais em `project.pbxproj`: `DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE = Automatic`, a exceção de membership de `Config.xcconfig`, `LastUpgradeCheck = 2720`, `DEAD_CODE_STRIPPING` e `STRING_CATALOG_GENERATE_SYMBOLS`.
- Preservar os arquivos da camada de IA.
- Testes de UI e XCUIAutomation são proibidos.

---

## 3. Escopo, não escopo e premissas

**Escopo:**
- F1 a F34, FR1 a FR10, R1 a R25 e R27;
- o layout no Figma;
- o board no Trello;
- a documentação: README, RELEASE_NOTES, `version.json`, `.ai/PROJECT_BRIEF.md` e `.ai/PROJECT_GUIDE.md`.

**Não escopo:**
- edição Mac App Store (a alternativa híbrida fica documentada na seção 4);
- Sparkle ou qualquer atualizador automático;
- Atalhos e App Intents;
- limpeza de caches de ferramentas de IA fora da pasta temporária;
- F35 no marco 1.0;
- `/Library/Developer/CoreSimulator` por arquivo;
- CI hospedado; o projeto só fica pronto para CI.

**Premissas:**
- D1 a D14 conforme as recomendações.
- A chave do Himetrica e o DSN do Sentry reais serão fornecidos pelo dono. Até lá, o envio live fica pendente.
- O Xcode 27.2 continua sendo o toolchain.

---

## 4. Decisão de distribuição: Developer ID e notarização, fora da Mac App Store

**Decisão:** distribuir **fora da loja**, com Developer ID, Hardened Runtime, notarização com `notarytool`, staple e DMG, **sem App Sandbox**. A regra do dono se aplica: a única via compatível com a loja exige que o usuário escolha pastas.

**Fundamentos (consultados em 2026-10-31):**

1. Um app sandboxed só acessa o próprio container, locais da allowlist e itens escolhidos pelo usuário. Os caminhos `~/Library/Developer/*`, `~/Library/Caches/*` de outros apps, `/private/tmp` e `/private/var/tmp` exigem um destes dois caminhos:
   - um `NSOpenPanel` com security-scoped bookmarks, que viola a regra do dono;
   - os entitlements `com.apple.security.temporary-exception.files.home-relative-path.read-write` e `...absolute-path.read-write`. A referência de entitlements da Apple exige justificar cada exceção no App Store Connect e não garante aceite. Um engenheiro de DTS da Apple escreveu que o App Review "takes a very dim view" dessas exceções, e outras respostas no fórum indicam que elas não deveriam mais ser necessárias na loja.
2. O `simctl` e o CoreSimulatorService não funcionam a partir do sandbox. Um processo filho herda o sandbox do app e não alcança `~/Library/Developer`. O DTS diz que rodar comandos de shell "won't be possible in a Mac App Store app". Remover runtimes mexe em disk images do sistema (`/System/Library/AssetsV2`, montadas por cryptexd), algo fora do alcance de qualquer sandbox.
3. O Acesso Total ao Disco não resolve: é um privilégio de MAC/TCC separado do App Sandbox, e um app sandboxed com esse acesso continua limitado ao próprio sandbox estático ou dinâmico (resposta de DTS no thread 807142; post "On File System Permissions").
4. As App Review Guidelines, em 2.4.5(vii), exigem atualização só pela loja, o que derruba o `version.json` próprio. Em 2.4.5(viii), vedam "optionally installed technologies", e a dependência de Xcode e simctl abre esse risco.

**Segurança fora da loja:**
- Hardened Runtime sem exceções (nada de `disable-library-validation` ou `allow-jit`), assinatura Developer ID, notarização e staple no app e no DMG;
- entitlements vazios (sem sandbox);
- `Process` só com executável absoluto `/usr/bin/xcrun`, sem shell e com argumentos em array. Opcional: `Process.launchRequirementData` (macOS 14.4+) para exigir que o binário seja assinado pela Apple;
- `SafePathPolicy` (N2), Lixeira para itens perigosos e confirmações.

**Alternativa híbrida (não é o padrão):** uma edição "Lite" para a loja, sandboxed, com um único `NSOpenPanel` de `~/Library/Developer` (bookmark security-scoped), cobrindo só DerivedData, Archives, Device Support e Products. Ficariam de fora simuladores, runtimes, pasta temporária, caches em `~/Library/Caches` e preferências do Xcode, e o `version.json` próprio também sairia. Ela viola a regra do dono ("não selecionar pasta") e por isso não é recomendada.

**Atenção:** a alteração local já desfez a assinatura manual `Developer ID Application` em `pbxproj`, que agora é Automatic. A assinatura Developer ID passa a ser feita no export (`method = developer-id` em `ExportOptions.plist`, card C26), sem reverter o diff local.

---

## 5. Arquitetura proposta

### 5.1 Build settings

Aplicar nos targets `CleanerXcode` e `CleanerXcodeTests` (os valores batem com os templates do Xcode 27.2 encontrados em `Xcode.app/.../Templates/Project Templates/Base/App Base.xctemplate`):
- `SWIFT_VERSION = 6.0`. "Swift 6.4" é a versão do compilador (swiftlang-6.4.2); o language mode é 6, e esse é o valor válido;
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (SE-0466);
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` (inclui SE-0461 `nonisolated(nonsending)` e a inferência de conformances isoladas);
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`;
- `SWIFT_STRICT_CONCURRENCY = complete`, explícito por clareza;
- `MACOSX_DEPLOYMENT_TARGET = 26.0` no projeto e nos dois targets, corrigindo a divergência atual de 15.0 e 15.2;
- remover `INFOPLIST_KEY_LSUIElement` (**adiado para o C20** na execução do C03, em 2026-10-31: sem a nova `Window`, o app ficaria com ícone no Dock e sem janela entre os cards);
- `DEVELOPMENT_ASSET_PATHS = "CleanerXcode/Resources/Preview Content"`;
- `ENABLE_USER_SCRIPT_SANDBOXING` continua `YES`, já que o upload de dSYM é manual (D9).

**Impacto nas dependências:**
- `sentry-cocoa` 9.32.0 usa tools 6.0 e language mode v5 no próprio pacote, com XCFrameworks binários;
- `himetrica-swift` 1.0.0 usa tools 5.9 e não tem dependências;
- os dois compilam no próprio modo de linguagem, e os tipos não-Sendable deles são tratados nos adaptadores, nunca vazando para o domínio.

### 5.2 Estrutura de pastas (folders sincronizados)

O `scripts/lint-swift.sh` só coleta `Sources/` e `Tests/` na raiz ou em `<pasta-de-topo>/Sources|Tests`. Hoje ele não encontra nenhum código, o que é mais um motivo para reorganizar.

```
CleanerXcode/                      (root group sincronizado do target app)
├── Config.xcconfig                (versionado; inclui `#include? "Secrets.xcconfig"`)
├── Secrets.example.xcconfig       (versionado; placeholders)
├── Secrets.xcconfig               (NÃO versionado; .gitignore)
├── Info.plist, CleanerXcode.entitlements
├── Resources/  Assets.xcassets, Localizable.xcstrings, Preview Content/
└── Sources/
    ├── App/        CleanerXcodeApp.swift, AppDelegate.swift, AppContainer.swift,
    │               AppEnvironment.swift (isRunningTests, buildConfiguration), AppConfiguration.swift
    ├── Core/
    │   ├── Cleanup/      CleanupCategory.swift, CleanupCategoryID.swift, CleanupCatalog.swift,
    │   │                 CleanupTarget.swift, RiskLevel.swift, RemovalMode.swift, CleanupPlan.swift,
    │   │                 CleanupProgress.swift, CleanupReport.swift, CleanupItemResult.swift,
    │   │                 CleanupError.swift, SafePathPolicy.swift, CleanupLocations.swift
    │   ├── FileSystem/   DiskUsageScanning.swift, FileSystemSizeScanner.swift,
    │   │                 FileRemoving.swift, FileSystemRemover.swift, TemporaryItemsPolicy.swift,
    │   │                 OrphanSimulatorTempFinder.swift
    │   ├── Process/      ProcessRunning.swift, ProcessRunner.swift, ProcessRequest.swift, ProcessOutput.swift
    │   ├── Simulators/   SimulatorManaging.swift, SimctlSimulatorService.swift, SimulatorDevice.swift,
    │   │                 SimulatorRuntime.swift, DeviceSet.swift, DuplicateSimulatorDetector.swift,
    │   │                 SimctlJSON.swift (DTOs), CoreSimulatorServiceRestarter.swift
    │   ├── Xcode/        XcodePreferencesResetting.swift, RunningApplicationsProviding.swift
    │   ├── Cleanup/Executor/ CleanupExecuting.swift, CleanupExecutor.swift
    │   ├── Persistence/  PreferencesStoring.swift, UserDefaultsPreferencesStore.swift, PreferencesMigrator.swift
    │   ├── Platform/     LoginItemManaging.swift (SMAppService), SystemSettingsOpener.swift
    │   ├── Network/      VersionChecking.swift, RemoteVersionChecker.swift, SemanticVersion.swift
    │   └── Integrations/ Analytics.swift, AnalyticsEvent.swift, NullAnalytics.swift, HimetricaAnalytics.swift,
    │                     ErrorReporting.swift, ReportableFailure.swift, NullErrorReporter.swift,
    │                     SentryErrorReporter.swift, SentryEventSanitizer.swift, ErrorReportingConfiguration.swift
    └── Features/
        ├── Cleaner/      CleanerView.swift, CleanerViewModel.swift, CleanerPhase.swift, CategoryRowState.swift,
        │                 Components/ (HeroTotalView, CleanButtonBar, CategorySectionView, CategoryRowView,
        │                 RiskBadgeView, CleanupReportView, DangerConfirmationView, PermissionCalloutView)
        ├── Simulators/   SimulatorsSectionView.swift, SimulatorsViewModel.swift, SimulatorRowState.swift,
        │                 Components/ (SimulatorRowView, RuntimeRowView, DuplicateBadgeView)
        ├── Settings/     SettingsView.swift, SettingsViewModel.swift, Components/(GeneralTab, AboutTab)
        ├── MenuBar/      MenuBarContentView.swift, MenuBarLabelView.swift
        └── Update/       UpdateViewModel.swift (ex-UpdateStore)
Tests/                             (raiz do repo; root group sincronizado do target de testes, ex-CleanerXcodeTests/)
├── Core/ (Cleanup, FileSystem, Process, Simulators, Persistence, Network, Integrations)
├── Features/ (Cleaner, Simulators, Settings, Update)
└── Support/ (Fakes/, Fixtures/simctl-devices.json, simctl-runtimes.json, TemporaryDirectoryFixture.swift)
```

Exceções declaradas ao `SWIFT_REFERENCE`, a registrar no `PROJECT_GUIDE`:
- os arquivos de configuração (`*.xcconfig`, `Info.plist` e entitlements) ficam na raiz de `CleanerXcode/`, porque o `baseConfigurationReferenceRelativePath = Config.xcconfig` está ancorado no root group;
- `Tests/` fica na raiz do repo para o gate de lint encontrá-lo. O `pbxproj` precisa atualizar o path do root group sincronizado do target de testes.

### 5.3 MVVM, composição e isolamento

**Composição:**
- O `AppContainer` (MainActor) cria as implementações concretas a partir de `AppEnvironment` e `AppConfiguration`.
- Se `AppEnvironment.isRunningTests` for verdadeiro, ele usa `NullAnalytics`, `NullErrorReporter` e serviços inertes, e não dispara medições. A detecção usa as variáveis de ambiente `XCTestConfigurationFilePath` ou `XCTestBundlePath`.
- A decisão fica numa função pura testável, `AppContainer.makeServices(environment:configuration:)`.

**ViewModels (`@Observable`, MainActor pelo isolamento padrão):**
- `CleanerViewModel`: fases, seleção, tamanhos, plano, relatório e intenções `refresh()`, `toggle(_:)`, `requestClean()`, `confirm()`, `cancel()`, `retryFailed()`, `dismissReport()`;
- `SimulatorsViewModel`: `load()`, `select(_:)`, `selectDuplicates()`, `deleteSelected()`, `deleteRuntime(_:)`;
- `SettingsViewModel`;
- `UpdateViewModel`.

As Views não importam Sentry, Himetrica nem `ServiceManagement`.

**Tipos de domínio:** declarados `nonisolated struct … : Sendable, Hashable/Codable`. Com `MainActor` como padrão, o `nonisolated` explícito evita que as conformances fiquem isoladas no main actor.

**Serviços de I/O:** `nonisolated struct … : Sendable` com métodos `@concurrent func … async throws`. Assim o trabalho sai do main actor mesmo com SE-0461, e cada chamada cria o próprio `FileManager()`.

**Paralelismo da medição:** `withThrowingTaskGroup` dentro do ViewModel (MainActor), em que cada filho chama `scanner.allocatedSize(of:)` (`@concurrent`). Os resultados são aplicados no main actor à medida que chegam, e a task da medição anterior é cancelada antes de uma nova.

**Execução da limpeza:**
- `CleanupExecutor.execute(_ plan:) -> AsyncThrowingStream<CleanupEvent, Error>` roda de forma sequencial por categoria e por filho direto, com `try Task.checkCancellation()` entre itens. O `continuation.onTermination` cancela a task produtora.
- O ViewModel consome o stream num `Task` guardado (`cleanupTask`), e `cancel()` cancela esse task.
- Não usar `[weak self]` dentro de grupos (corrige o aviso atual `#ImplicitStrongCapture`).
- Usar `Task.sleep` só no caso estritamente visual de manter o relatório na tela, sem dependência em testes. O relatório fica até o usuário dispensá-lo, sem os timers de 0,5, 1 e 2 s do código atual.

**ProcessRunner:**
- `Process` é `Sendable` no SDK macOS 27.2 (`NSTask` com `NS_SWIFT_SENDABLE`, verificado em `NSTask.h`).
- O executável é `/usr/bin/xcrun`, e `stdout` e `stderr` usam pipes separados.
- A leitura é concorrente com `async let`, a partir de `fileHandleForReading.bytes`, para não travar com buffer cheio. O problema de `waitUntilExit` está relatado no fórum, thread 815676.
- O término usa `terminationHandler` ligado a `withCheckedContinuation`.
- O cancelamento usa `withTaskCancellationHandler { … } onCancel: { process.terminate() }`.
- O timeout usa uma corrida em `withThrowingTaskGroup` com `Task.sleep(for:)`. Os padrões são 60 s para list e delete, 30 min para `runtime delete` e 10 min para `erase all`.
- Exit code diferente de zero vira `CleanupError.commandFailed(exitCode:, summary:)`, com o stderr truncado e sanitizado.
- `Task.detached`, locks, `@unchecked Sendable` e `nonisolated(unsafe)` são proibidos.

**Adaptadores de terceiros:**
- `HimetricaAnalytics`: o SDK é `@MainActor` e o protocolo `Analytics` é MainActor (padrão), então a chamada é direta.
- `SentryErrorReporter`: `beforeSend` recebe uma referência a uma função `nonisolated static func sanitize(_:) -> Event?` em `SentryEventSanitizer`, não uma closure literal formada em contexto MainActor. Isso evita a asserção de isolamento em runtime quando o Sentry chama a closure fora do main thread.

### 5.4 Protocolos e contratos

- `DiskUsageScanning`: `func allocatedSize(of target: CleanupTarget) async throws -> Int64`.
  - Usa `FileManager.enumerator(at:includingPropertiesForKeys:[.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isDirectoryKey, .isSymbolicLinkKey, .fileResourceTypeKey], options:[], errorHandler:)`.
  - Não segue links; erro de leitura num subitem conta como 0 e é registrado.
  - Faz `checkCancellation` a cada 500 itens.
- `FileRemoving`:
  - `func removeContents(of root: URL, policy: SafePathPolicy, mode: RemovalMode, filter: (URL) -> Bool) -> AsyncThrowingStream<CleanupItemResult, Error>`;
  - `func remove(_ url: URL, mode: RemovalMode) async throws`;
  - `RemovalMode` tem os casos `.delete` (`removeItem`) e `.trash` (`trashItem(at:resultingItemURL:)`).
- `ProcessRunning`: `func run(_ request: ProcessRequest) async throws -> ProcessOutput`.
- `SimulatorManaging`:
  - `listDevices(in: DeviceSet) async throws -> [SimulatorDevice]` e `listRuntimes() async throws -> [SimulatorRuntime]`;
  - `shutdownAll(in:)`, `delete(_ udids: [String], in:)`, `deleteUnavailable()`, `eraseAll()`, `deleteAllDevices(in:)` e `deleteRuntime(identifier:)`;
  - `restartService()`, que encontra o PID de `com.apple.CoreSimulator.CoreSimulatorService` com `libproc` (`proc_listallpids` e `proc_name`) e envia `kill(pid, SIGTERM)`. O launchd relança o serviço sob demanda. Isso foi verificado no `launchctl print gui/<uid>`, onde o serviço é um endpoint XPC on-demand. Precisa de validação empírica (C27).
- `TemporaryItemsPolicy` (struct pura): `func shouldRemove(_ item: TemporaryItem, now: Date) -> TemporaryDecision`, que devolve `.remove` ou `.skip(reason)`.
- `RunningApplicationsProviding`: `isXcodeRunning`, `isSimulatorRunning` e `terminateSimulator() async -> Bool`, com `NSRunningApplication` e os bundle IDs `com.apple.dt.Xcode` e `com.apple.iphonesimulator`.
- `XcodePreferencesResetting`: `func reset() throws`.
- `LoginItemManaging`: `var isEnabled: Bool { get }` e `func setEnabled(_:) throws`, sobre `SMAppService.mainApp`.
- `PreferencesStoring`: `isSelected(_ id:) -> Bool?`, `setSelected(_:_:)`, `bool(for key:) -> Bool?`, `set(_:for:)` e `schemaVersion`. O `PreferencesMigrator` é puro.
- `VersionChecking`: `func latestVersion() async throws -> RemoteVersion`. `SemanticVersion: Comparable`.
- `Analytics` (mantido): `func log(_ event: AnalyticsEvent)`, com as implementações `HimetricaAnalytics` e `NullAnalytics`.
- `ErrorReporting`: `func start()`, `func capture(_ failure: ReportableFailure)` e `func breadcrumb(_ stage: ReportingStage)`, com as implementações `SentryErrorReporter` e `NullErrorReporter`.

**Modelo de erro por item:** `CleanupError: Error, Sendable, Equatable` com os casos:
- `.permissionDenied` (`EACCES`, `EPERM`, `CocoaError.fileWriteNoPermission` e `.fileReadNoPermission`);
- `.inUse` (`EBUSY`);
- `.notFound`, que é tratado como "pulado";
- `.toolUnavailable` (xcrun ou simctl ausentes);
- `.commandFailed(exitCode:Int32, summary:String)`;
- `.timedOut`;
- `.cancelled`;
- `.blockedByRunningApp(AppKind)`;
- `.unsafePath`, que é bug e é sempre reportado;
- `.unknown(domain:String, code:Int)`.

`CleanupItemResult` guarda `categoryID`, `displayPath` (com `~`, só para a interface), `bytes` e `outcome` (`.removed`, `.trashed`, `.skipped(SkipReason)` ou `.failed(CleanupError)`). `CleanupReport` guarda `results`, `freedBytes`, `trashedBytes` e `outcome` (`.success`, `.partialFailure`, `.failure` ou `.cancelled`). A lógica de agregação é pura e testada.

### 5.5 Catálogo (fonte única de verdade, `CleanupCatalog`)

| ID (chave de preferência) | Raízes / operação | Método | Risco | Padrão |
|---|---|---|---|---|
| `remove-derived-data` | `~/Library/Developer/Xcode/DerivedData` (filhos) | delete | seguro (aviso com Xcode aberto) | ligado |
| `remove-caches` | Caches do Xcode, xcodebuild, Carthage, CocoaPods | delete | seguro | ligado |
| `remove-archives` | `~/Library/Developer/Xcode/Archives` (filhos) | trash | perigoso | desligado (salvo é preservado) |
| `clear-device-support` | `*DeviceSupport` (5 plataformas) | delete | atenção | desligado |
| `clear-simulator-data` | `simctl shutdown all` e depois `simctl erase all` | simctl | atenção | desligado |
| `remove-old-simulators` | `simctl delete unavailable` | simctl | seguro | desligado (legado) |
| `reset-xcode-preferences` | domínio `com.apple.dt.Xcode` | reset | perigoso (bloqueado com Xcode aberto) | desligado |
| `clear-auxiliary-device-sets` | XCTestDevices, UserData/Previews, UserData/IB Support, XCPGDevices | `simctl --set` e depois delete das sobras | seguro | ligado |
| `clear-simulator-caches` | CoreSimulator/Caches (exceto Personalization), CoreSimulator/Temp, Logs/CoreSimulator | delete e reinício do serviço | seguro | ligado |
| `clear-orphan-simulator-temp` | `/private/var/tmp/com.apple.CoreSimulator.SimDevice.<UDID>` órfãos | delete | seguro | ligado |
| `clear-temporary-files` | `$TMPDIR`, `/private/tmp` e `/private/var/tmp` com a `TemporaryItemsPolicy` | delete | atenção | desligado |
| `remove-swiftpm-cache` | `~/Library/Caches/org.swift.swiftpm` | delete | atenção | desligado |
| `remove-xcode-products` | `~/Library/Developer/Xcode/Products` (filhos) | delete | atenção | desligado |
| `remove-xcode-user-data` | `UserData/*` exceto Previews, IB Support e Provisioning Profiles | trash | perigoso (bloqueado com Xcode aberto) | desligado |
| `remove-provisioning-profiles` | `UserData/Provisioning Profiles` e `~/Library/MobileDevice/Provisioning Profiles` | trash | perigoso | desligado |

Todas as raízes são montadas a partir de `CleanupLocations`, que é injetável (home, temp e var/tmp), para os testes apontarem para uma pasta temporária criada pelo próprio teste.

### 5.6 Destino de `Shell` e dos scripts

`Shell.swift`, `CommandExecutor.swift`, `Command.swift`, `Scripts/*.sh`, os scripts de teste `.sh`, `ShellTests`, `CommandExecutorTests`, `CommandTests`, `CommandExecutorStub`, `StoragedValue`, `Preference+Extension`, `String+ErrorExtension` e `Route` são **apagados** no card C24, depois que os substitutos estiverem testados. As dependências swift-timeout e LaunchAtLogin saem junto (D4).

### 5.7 Observabilidade

**Himetrica (F15/R21):**
- SPM `https://github.com/himetrica/himetrica-swift`, regra **exactVersion 1.0.0** (tag `1.0.0`, commit `b62348e`, `Package.swift` sem dependências).
- Configuração em `HimetricaAnalytics.start(apiKey:)`:
  ```
  HimetricaConfig(apiKey: …, autoTrackScreenViews: false, respectAdTracking: false, enableLogging: false)
  ```
- Só inicializa se: build não for DEBUG, não estiver em teste, a chave não estiver vazia e o opt-out estiver ligado. Se o opt-out for desligado em runtime, o adaptador para de enviar (guarda interna), porque o SDK não tem método de desligar.
- Nunca chamar `identify`, `trackScreen` nem os modificadores de view do SDK.
- `Himetrica.shared` dá `fatalError` sem configuração, por isso o adaptador só existe se a configuração tiver ocorrido. Caso contrário, o container usa `NullAnalytics`.
- Limitações registradas: o SDK está em beta, envia `platform = "ios"` fixo no macOS, tamanho de tela 0 e modelo "Mac".

**Eventos (nomes estáveis, só `[a-z0-9_]`, propriedades enumeradas):**

| Evento | Propriedades |
|---|---|
| `cleaner` | `categories` (IDs de categoria separados por vírgula; mantém a semântica do evento antigo), `result` (`success`, `partial_failure` ou `cancelled`), `freed_bucket` (`<1GB`, `1-10GB`, `10-50GB` ou `>50GB`) |
| `cleaner_partial_failure` | `failed_categories`, `error_kinds` (`permission`, `in_use`, `tool_unavailable`, `timeout`, `command_failed` ou `other`) |
| `simulator_deleted` | `count`, `reason` (`duplicate` ou `manual`) |
| `simulator_unavailable_deleted` | `count` |
| `runtime_deleted` | `count` |
| `social` | `platform` |
| `donate` | sem propriedades |
| `update_opened` | sem propriedades |

Nenhum caminho, nome de simulador, UDID nem tamanho exato entra nos eventos.

**Sentry (F33/R22):**
- SPM `https://github.com/getsentry/sentry-cocoa`, **exactVersion 9.32.0**, produto **`Sentry`** (XCFramework estático, sem problema de library validation no Hardened Runtime; mínimo macOS 12).
- `SentryErrorReporter.start()` roda na composição (`AppContainer`, a partir do `init` do App, no main thread), com:
  - `dsn`;
  - `environment`: `debug` em Debug e `production` em Release, derivado de `#if DEBUG`;
  - `releaseName = "didisouzacosta.CleanerXcode@<CFBundleShortVersionString>+<CFBundleVersion>"`;
  - `dist = build`;
  - `sendDefaultPii = false`;
  - `sampleRate` e `tracesSampleRate` vindos de `ErrorReportingConfiguration` (padrão: debug 1.0/0.0, production 1.0/0.0, sem performance);
  - `enableUncaughtNSExceptionReporting = true` (exigência para macOS na doc);
  - `debug = false`;
  - `beforeSend = SentryEventSanitizer.sanitize`;
  - `beforeBreadcrumb = SentryEventSanitizer.sanitizeBreadcrumb`.
- O sanitizador troca `/Users/<nome>` e `/private/var/folders/...` por `~` ou `<tmp>`, remove nomes de arquivo fora de uma allowlist de frames, limpa `user` e `serverName` e trunca mensagens.
- Fica ligado em DEBUG, como o dono pediu, mas **nunca** em testes ou previews.
- Os erros da limpeza viram **um evento agregado** `cleanup_partial_failure` de nível warning, com tags de categoria e de tipo de erro e contagens, sem paths.
- Erros inesperados (decodificação do JSON do simctl, `unsafePath`) entram como `capture(error:)` sanitizado.
- Ações do dono no painel do Sentry: ligar Data Scrubbing e "Prevent Storing of IP Addresses".

**Segredos (R23):**
- `Config.xcconfig` (versionado) recebe `#include? "Secrets.xcconfig"` e perde o `MIXPANEL_TOKEN`.
- `Secrets.example.xcconfig` (versionado) define `HIMETRICA_API_KEY =` e `SENTRY_DSN =`.
- `.gitignore` recebe `CleanerXcode/Secrets.xcconfig`. A entrada `GoogleService-info.plist` sai.
- `Info.plist` troca `MIXPANEL_TOKEN` por `HIMETRICA_API_KEY = $(HIMETRICA_API_KEY)` e `SENTRY_DSN = $(SENTRY_DSN)`.
- Cuidado com o DSN no xcconfig: `//` inicia comentário, então ele deve ser escrito com o truque já usado em `VERSION_FILE_URL` (`https:/$()/…`). O `Secrets.example` documenta isso.
- A chave do Himetrica e o DSN acabam dentro do binário; isso é público por natureza (são identificadores de cliente). O objetivo é tirá-los do repositório.

---

## 6. Fase de layout no Figma (card C01)

**Ferramenta e ordem:** invocar a skill `figma:figma-create-new-file` antes de `create_new_file`, depois `create_session` com a chave do arquivo e um resumo da tarefa, depois `figma:figma-use` (obrigatória antes de cada `use_figma`) e `figma:figma-generate-design`. Rodar `search_design_system` e `get_libraries` para tentar reaproveitar o kit oficial "macOS 26" da Apple, se estiver disponível na conta. Se não estiver, criar primitivos locais.

**Arquivo:** "CleanerXcode — Redesign 1.0 (Liquid Glass)", projeto novo. O idioma principal dos frames é pt-BR, e um frame em en serve para conferir truncamento.

**Páginas:**
1. **00 Capa e decisões**: objetivo, D1–D14 e a legenda de risco (seguro em verde ou secundário, atenção em laranja, perigoso em vermelho).
2. **01 Foundations**:
   - variáveis com modos Light e Dark (cores semânticas: label, secondaryLabel, separator, accent, riskSafe, riskAttention, riskDanger, success, failure);
   - tipografia SF Pro (largeTitle para o total, headline, body, caption);
   - espaçamento 4/8/12/16/24;
   - raios de canto;
   - ícones SF Symbols de cada categoria: `hammer`, `archivebox`, `externaldrive`, `iphone`, `ipad.and.iphone`, `trash`, `clock.arrow.circlepath`, `shippingbox`, `person.crop.square`, `gearshape`, `doc.badge.gearshape`.
3. **02 Components** (variantes como component sets):
   - `CleanButton`, estilo glassProminent: idle-com-total, desabilitado, hover, pressed;
   - `GlassButton`: Cancelar, Atualizar, Tentar de novo;
   - `ToolbarGroup`: atualizar e ajustes, ícones com rótulo de acessibilidade, sem misturar texto e ícone;
   - `HeroTotal`: medindo, valor, zero;
   - `CategoryRow`: medindo, medido, vazio, selecionado, desmarcado, indisponível, bloqueado-Xcode-aberto, falhou, com `RiskBadge` atenção ou perigoso e botão de info com popover;
   - `SectionHeader`;
   - `SimulatorRow`: desligado, ligado, duplicado, indisponível, apagando, selecionado;
   - `RuntimeRow`: normal, em uso, não deletável, apagando;
   - `ProgressPanel`: item atual, n/m, bytes;
   - `ReportBanner`: sucesso, falha parcial com lista expansível, cancelado, permissão negada;
   - `DangerConfirmation` (sheet): lista de itens, destino Lixeira ou definitivo, botão destrutivo;
   - `RunningAppWarning`;
   - `ToolsUnavailableCallout`;
   - `MenuBarPanel`.
4. **03 Janela principal**, 560×720 padrão e 480×560 mínimo, **cada estado em Light e Dark**:
   - medindo (primeira vez); pronto; nada selecionado; nada a limpar;
   - Simuladores expandido com duplicados; runtimes;
   - confirmação de perigo; limpando; cancelando; cancelado;
   - sucesso; falha parcial; permissão negada;
   - Xcode aberto; Simulator aberto; ferramentas do Xcode indisponíveis;
   - um frame com "Reduzir transparência" e outro com texto grande.
   - Composição: toolbar unificada em glass (título, botão atualizar, `SettingsLink`) → hero (total grande + subtítulo "de 81,2 GB encontrados" + `CleanButton` + Cancelar quando aplicável, agrupados num `GlassEffectContainer`) → lista agrupada **sem glass no conteúdo** (seções Xcode, Simuladores, Temporários, Dados do usuário e reset, com o perigo no fim) → seção Simuladores e Runtimes recolhível → rodapé com versão e Atualizar.
5. **04 Ajustes**:
   - aba Geral: abrir no login, mostrar na barra de menus, mostrar o tamanho na barra, idade mínima da pasta temporária, enviar estatísticas anônimas;
   - aba Sobre: versão, atualização, links sociais, dedicatória, doação;
   - Light e Dark.
6. **05 Barra de menus**: rótulo com ícone e tamanho, e o painel em Light e Dark.
7. **06 Fluxos**: protótipo ligando pronto → confirmação → limpando → sucesso ou falha parcial, e simuladores → confirmar → apagando → lista atualizada.
8. **07 Handoff**: tabela de componente para API SwiftUI:
   - `.buttonStyle(.glassProminent)` e `.glass`;
   - `GlassEffectContainer`;
   - `.glassEffect(.regular.interactive(), in:)` só no hero;
   - `ToolbarSpacer`;
   - `List` e `Form(.grouped)`;
   - `.confirmationDialog` ou `.sheet(item:)`;
   - `MenuBarExtra(isInserted:)`;
   - `Settings` com `TabView`.

**O dono aprova antes de implementar (gate do C01):**
- hierarquia do total e do botão;
- agrupamento e ordem das categorias e a forma de mostrar o risco;
- seção de simuladores e duplicados;
- texto e conteúdo da confirmação de perigo e do aviso da Lixeira;
- conteúdo de Ajustes;
- presença e padrão da barra de menus;
- Light e Dark;
- textos pt-BR das ações destrutivas.

O link do arquivo e a data da aprovação ficam registrados no card.

---

## 7. Board no Trello

**Nome:** "CleanerXcode 1.0 — Redesign nativo".

**Listas (posições 1–6):** Decisões do dono · Backlog · Ready · Em andamento · Revisão · Concluído.

**Labels:**
- prioridade: P0 Crítico (red), P1 Alto (orange), P2 Médio (yellow), P3 Baixo (green);
- área: Design (purple), Swift 6/Build (blue), Core/Disco (sky), Simuladores (lime), Temp (pink), UI (black), Observabilidade (red_dark), Distribuição (blue_dark), Docs (green_dark), Testes/Validação (orange_dark).

**Posições iniciais:** o card D00 vai para "Decisões do dono", o C01 para "Ready" e os demais para "Backlog", com `pos` sequencial na ordem abaixo.

**D00. Decisões do dono D1–D14** (P0, área Docs)
- Descrição: a tabela de decisões com as recomendações.
- Checklist: um item por decisão (D1 … D14).
- Aceite: cada decisão marcada como confirmada ou alterada. As alterações voltam ao Manager para ajustar o plano.

**C01. Criar layout no Figma** (P0, área Design)
- Depende de: nenhum card (pode começar enquanto o D00 corre).
- Descrição: a seção 6 inteira.
- Checklist: criar o arquivo; Foundations com Light e Dark; componentes; os 18 estados da janela em Light e Dark; Ajustes; barra de menus; fluxos; handoff; revisão de acessibilidade (contraste, Reduzir transparência); aprovação do dono.
- Aceite: AC30; link e data da aprovação no card.

**C02. Preparar a baseline de engenharia** (P0, área Swift 6/Build)
- Depende de: C01 aprovado e D00.
- Checklist:
  - registrar o estado inicial (`git status` e diff do pbxproj preservados);
  - compartilhar o scheme e o test plan (D12);
  - confirmar a suíte atual (35 testes) e a falha atual do lint ("No Swift sources");
  - documentar os comandos.
- Aceite: suíte verde registrada e alterações locais intactas.

**C03. Migrar para Swift 6 (language mode 6) e macOS 26** (P0, área Swift 6/Build)
- Depende de: C02.
- Checklist: os build settings da 5.1 nos dois targets; corrigir os avisos atuais (`CleanerStore.swift:89`, `@Entry` de classe em `Preferences.swift:93` e `Route.swift:34`) ou removê-los; build e testes.
- Aceite: AC19.

**C04. Reestruturar pastas e criar o AppContainer** (P0, áreas Swift 6/Build e UI)
- Depende de: C03.
- Checklist:
  - `CleanerXcode/Sources/{App,Core,Features}`, `CleanerXcode/Resources`, `Tests/` na raiz;
  - atualizar o root group sincronizado dos testes e `DEVELOPMENT_ASSET_PATHS`;
  - criar `AppEnvironment` (`isRunningTests`), `AppConfiguration` e `AppContainer.makeServices`;
  - garantir que o lint encontre os arquivos.
- Aceite: AC27 (parte de composição) e AC31.

**C05. Remover o Firebase** (P0, área Observabilidade)
- Depende de: C03.
- Checklist:
  - remover a referência ao pacote `firebase-ios-sdk` e os produtos FirebaseCore, FirebaseAnalytics e FirebaseCrashlytics do target;
  - `Package.resolved` sem nenhuma identidade Google ou transitiva (abseil, app-check, google-ads-on-device-conversion, googleappmeasurement, googledatatransport, googleutilities, grpc, gtm-session-fetcher, interop, leveldb, nanopb, promises, swift-protobuf);
  - apagar `GoogleService-Info-Example.plist` e qualquer `GoogleService-Info.plist` local, sem versionar;
  - remover `import Firebase` e o `FirebaseApp.configure()` do `AppDelegate`;
  - apagar `GoogleAnalytics.swift` e deixar `NullAnalytics` provisório;
  - `.gitignore`;
  - README (dependências, "Coding Standards", menções a Google Analytics);
  - entrada no RELEASE_NOTES.
- Aceite: AC20.

**C06. Segredos fora do repositório e remoção do MIXPANEL_TOKEN** (P0, área Observabilidade)
- Depende de: C03.
- Checklist:
  - `#include? "Secrets.xcconfig"`;
  - `Secrets.example.xcconfig`;
  - `.gitignore`;
  - chaves no `Info.plist`;
  - `AppConfiguration` lendo as chaves, com string vazia virando "não configurado";
  - remover `MIXPANEL_TOKEN` (xcconfig, Info.plist e `Bundle.mixpanelToken`);
  - lembrete ao dono para revogar o token no Mixpanel;
  - build sem `Secrets.xcconfig` continua passando.
- Aceite: AC23.

**C07. Integrar o Himetrica** (P1, área Observabilidade)
- Depende de: C05, C06 e C04.
- Checklist:
  - SPM `himetrica-swift` com versão exata 1.0.0, produto `Himetrica`;
  - `HimetricaAnalytics: Analytics` (adaptador) e `NullAnalytics`;
  - `AnalyticsEvent` com os eventos da 5.7;
  - mapeamento de propriedades;
  - guardas: DEBUG, teste, chave vazia, opt-out;
  - testes do mapeamento de eventos e da escolha da implementação;
  - README (privacidade).
- Aceite: AC21 e AC21b. O AC21-live fica pendente da chave real.

**C08. Integrar o Sentry** (P1, área Observabilidade)
- Depende de: C05, C06 e C04.
- Checklist:
  - SPM `sentry-cocoa` com versão exata 9.32.0, produto `Sentry`;
  - protocolo `ErrorReporting`, `NullErrorReporter`, `SentryErrorReporter` e `ErrorReportingConfiguration` (dsn, environment, releaseName, dist, sampleRate e tracesSampleRate por ambiente);
  - `environment` `debug` ou `production` derivado da configuração de build;
  - release `bundleID@versão+build`;
  - `sendDefaultPii = false`, `enableUncaughtNSExceptionReporting = true`;
  - `SentryEventSanitizer` nonisolated e puro, para eventos e breadcrumbs;
  - evento agregado `cleanup_partial_failure`;
  - nunca iniciar em testes ou previews (via `AppEnvironment`);
  - instruções de dSYM no checklist de release (D9);
  - README (privacidade e dependências).
- Aceite: AC22, AC22b e AC22c. O AC22-live fica pendente do DSN.

**C09. Domínio de limpeza e catálogo (TDD)** (P0, área Core/Disco)
- Depende de: C04.
- Checklist: `CleanupCategoryID` (chaves legadas como rawValue), `RiskLevel`, `RemovalMode`, `CleanupTarget`, `CleanupCatalog` (tabela 5.5), `CleanupLocations` injetável, `SafePathPolicy`, `CleanupError`, `CleanupItemResult`, `CleanupReport` e a agregação.
- Aceite: AC4 e AC29.

**C10. Investigar alvos adicionais (somente leitura)** (P2, área Core/Disco)
- Depende de: C09.
- Checklist: confirmar caminho, conteúdo e risco de `~/Library/Developer/CoreDevice`, `Xcode/CodingAssistant`, `DVTDownloads` e o cache de documentação do Xcode 27; propor a entrada no catálogo ou a exclusão justificada.
- Aceite: relatório anexado ao card. Nenhuma categoria nova entra sem aprovação do dono.

**C11. Medição nativa de tamanho** (P0, área Core/Disco)
- Depende de: C09.
- Checklist: `FileSystemSizeScanner` (`@concurrent`, sem seguir links, cancelável), medição paralela por categoria, testes com árvores criadas pelo teste (incluindo link para fora e cancelamento).
- Aceite: AC1.

**C12. Remoção nativa com erro por item** (P0, área Core/Disco)
- Depende de: C09.
- Checklist:
  - `FileSystemRemover` (delete ou trash), apagando os filhos da raiz um a um;
  - mapeamento de erros POSIX e Cocoa;
  - `SafePathPolicy` obrigatória;
  - testes de permissão negada (pasta 0500 criada pelo teste), inexistente, link e cancelamento.
- Aceite: AC6, AC7 e AC29.

**C13. ProcessRunner sem bash** (P0, área Core/Disco)
- Depende de: C04.
- Checklist: `ProcessRunner` (`/usr/bin/xcrun`, pipes separados lidos em paralelo, timeout, `terminate` no cancelamento, exit code e stderr); testes com `/bin/echo`, `/bin/sleep` e `/usr/bin/false` (binários do sistema, inofensivos); opcional: `launchRequirementData`.
- Aceite: AC24b.

**C14. Serviço de simuladores e runtimes** (P0, área Simuladores)
- Depende de: C13 e C09.
- Checklist:
  - DTOs de `simctl list --json devices` (`dataPathSize`, `logPathSize`, `lastUsedAt`, `isAvailable`, `state`, `deviceTypeIdentifier`) e de `simctl runtime list --json` (`identifier`, `runtimeIdentifier`, `sizeBytes`, `lastUsedAt`, `deletable`, `state`, `kind`);
  - fixtures sanitizados;
  - `DuplicateSimulatorDetector`;
  - comandos `shutdown`, `delete`, `erase all`, `delete unavailable`, `--set` e `runtime delete`;
  - `restartService()` com libproc;
  - estado `toolUnavailable`;
  - testes com um `ProcessRunning` falso que valida os argumentos exatos.
- Aceite: AC8, AC9, AC10 e AC12.

**C15. Pasta temporária e temporários órfãos de simuladores** (P1, área Temp)
- Depende de: C12 e C14.
- Checklist: `TemporaryItemsPolicy` (dono, idade, tipo, exclusões, os próprios arquivos do app) com testes de tabela de verdade; `OrphanSimulatorTempFinder` (UDIDs de todos os sets); categorias `clear-temporary-files` e `clear-orphan-simulator-temp`.
- Aceite: AC11 e AC11b.

**C16. Reset do Xcode e dados do usuário** (P1, área Core/Disco)
- Depende de: C12.
- Checklist: `XcodePreferencesResetting` com `removePersistentDomain` (testado com um domínio de teste próprio); `RunningApplicationsProviding`; bloqueio com Xcode aberto; UserData e Provisioning Profiles para a Lixeira.
- Aceite: AC5.

**C17. Executor de limpeza e reinício sem reboot** (P0, áreas Core/Disco e Simuladores)
- Depende de: C11, C12, C14, C15 e C16.
- Checklist:
  - `CleanupExecutor` com stream de eventos;
  - ordem fixa: encerrar o Simulator, `simctl shutdown all` nos sets afetados, operações `simctl`, remoções de arquivo, reinício do serviço se houve remoção direta no CoreSimulator;
  - progresso, cancelamento, relatório;
  - testes com fakes validando a ordem e a ausência de reinício quando não há remoção direta.
- Aceite: AC6, AC7 e AC10.

**C18. Migração de preferências e abrir no login** (P0, área Core/Disco)
- Depende de: C09.
- Checklist: `UserDefaultsPreferencesStore` compatível com o JSON `Data` legado; `PreferencesMigrator` v1→v2 (seção 9); `LoginItemManaging` com `SMAppService`; testes com `UserDefaults(suiteName:)` semeado com os valores legados.
- Aceite: AC3 e AC15.

**C19. ViewModel da limpeza** (P0, área UI)
- Depende de: C17 e C18.
- Checklist: `CleanerViewModel` com todas as fases da 2.4, total, seleção, plano e confirmação, avisos de app aberto, retry só dos itens que falharam, analytics e errorReporter via protocolos; testes de cada transição, incluindo cancelamento e falha parcial.
- Aceite: AC2, AC5, AC6 e AC7.

**C20. Janela única com Liquid Glass** (P0, área UI)
- Depende de: C19 e C01.
- Checklist:
  - remover `INFOPLIST_KEY_LSUIElement` do target do app (adiado do C03);
  - cena `Window("CleanerXcode", id: "main")` com `defaultSize` e `windowResizability`;
  - verificar se a janela aparece no lançamento. Se não aparecer, trocar para `WindowGroup(id:)` em instância única e registrar a troca;
  - toolbar em glass;
  - hero com `GlassEffectContainer`;
  - lista sem glass no conteúdo;
  - sheets de confirmação, relatório e estados;
  - `#Preview` de cada estado com ViewModels de preview;
  - acessibilidade.
- Aceite: AC14, AC18 e AC30b.

**C21. Seção Simuladores e Runtimes** (P0, áreas UI e Simuladores)
- Depende de: C14 e C20.
- Checklist: `SimulatorsViewModel`; lista com seleção, duplicados e "Remover duplicados"; runtimes com confirmação de perigo; estados `toolsUnavailable`, vazio, falha e apagando; previews; testes do ViewModel.
- Aceite: AC8 e AC9.

**C22. Ajustes, barra de menus e Sobre** (P1, área UI)
- Depende de: C18 e C20.
- Checklist:
  - `Settings` com as abas Geral e Sobre e `SettingsLink`;
  - `MenuBarExtra(isInserted:)` com rótulo de tamanho;
  - comportamento ao fechar a última janela;
  - abrir no login;
  - opt-out do analytics;
  - idade mínima da pasta temporária;
  - social, dedicatória e doação, com eventos `social` e `donate`;
  - previews.
- Aceite: AC14, AC15 e AC17.

**C23. Atualização com comparação semântica** (P1, área Core/Disco)
- Depende de: C04.
- Checklist: `SemanticVersion` e testes (0.10.0 > 0.9.0, 1.0.0 > 0.7.0 com builds); `RemoteVersionChecker` com `URLSession` e timeout; `UpdateViewModel`; evento `update_opened`.
- Aceite: AC16.

**C24. Remover o Shell, os scripts e o código morto** (P1, área Core/Disco)
- Depende de: C17 e C20 a C23.
- Checklist: apagar os itens da 5.6; remover swift-timeout e LaunchAtLogin (D4) do pbxproj e do `Package.resolved`; remover os imports Charts e TipKit; `grep` sem referências a `/bin/bash` nem a `.sh`.
- Aceite: AC24.

**C25. Localização, acessibilidade e previews finais** (P1, área UI)
- Depende de: C20 a C22.
- Checklist: todas as strings em en e pt-BR no `xcstrings`; VoiceOver; Dynamic Type; Reduzir transparência; contraste.
- Aceite: AC18.

**C26. Distribuição Developer ID e dSYMs** (P1, área Distribuição)
- Depende de: C24, C07 e C08.
- Checklist:
  - `ExportOptions.plist` (`method developer-id`, `signingStyle automatic`, team MM4N959BB5);
  - `xcodebuild archive` e `-exportArchive`;
  - `xcrun notarytool submit --keychain-profile <perfil> --wait`;
  - `xcrun stapler staple` no app e no DMG (`hdiutil create`);
  - `spctl -a -vvv`, `codesign --verify --deep --strict`;
  - entitlements vazios conferidos;
  - envio de dSYMs com `sentry-cli debug-files upload --org --project <dSYMs>` (D9);
  - documentar em `RELEASE.md` ou na seção Entrega do `PROJECT_GUIDE`.
- Aceite: AC25.

**C27. Validação manual real (com autorização explícita do dono)** (P0, área Testes/Validação)
- Depende de: C26 ou uma build Release local.
- Checklist:
  - na máquina do dono, medir antes e depois cada categoria segura;
  - apagar um simulador duplicado e um runtime não usado;
  - rodar `xcrun simctl list` e bootar um simulador pelo Xcode **sem reiniciar o Mac**;
  - pasta temporária com idade mínima;
  - falha parcial provocada (pasta sem permissão criada para o teste);
  - cancelamento no meio;
  - abrir no login com o app em /Applications;
  - registrar tudo com evidência.
- Aceite: AC10-live, AC6-live e AC15-live.

**C28. Validação live de analytics e crash** (P1, áreas Observabilidade e Testes/Validação)
- Depende de: C07, C08 e as chaves reais.
- Checklist:
  - build Release com a chave real: evento `cleaner` visível no Himetrica (dashboard ou MCP Himetrica `get_events`/`get_realtime`, só leitura);
  - build Debug: erro de teste chegando ao Sentry no environment `debug`;
  - build Release sem debugger: crash de teste no environment `production` com release e build corretos e simbolicado;
  - conferir que nenhum payload contém path ou usuário.
- Aceite: AC21-live e AC22-live.

**C29. Documentação** (P1, área Docs)
- Depende de: C26.
- Checklist:
  - README: requisitos macOS 26+, recursos, privacidade (analytics anônimo via Himetrica com opt-out, crashes via Sentry sem PII, nenhum dado pessoal), dependências (Himetrica, Sentry), remoção do Google Analytics, instruções de `Secrets.xcconfig`;
  - RELEASE_NOTES v1.0.0 build 115;
  - `resources/version.json`;
  - `MARKETING_VERSION` e `CURRENT_PROJECT_VERSION` juntos;
  - `.ai/PROJECT_BRIEF.md` e `.ai/PROJECT_GUIDE.md` (baseline, arquitetura, exceções, comandos).
- Aceite: AC26.

**C30. (Opcional) Instalar runtime** (P3, área Simuladores)
- Depende de: C21.
- Checklist: `xcodebuild -downloadPlatform iOS [-buildVersion]` pelo `ProcessRunner`, com progresso indeterminado, cancelamento e timeout longo; estado na seção Runtimes.
- Aceite: AC28.

---

## 8. Sequência de implementação, TDD e validação

**Marcos:**
- **M0 (Design)**: D00 e C01. **Gate**: Figma aprovado.
- **M1 (Fundação)**: C02 → C03 → C04 → C05 → C06 → C07 e C08 em paralelo.
- **M2 (Core nativo)**: C09 → C11, C12 e C13 em paralelo → C14 → C15 e C16 → C17 → C18, com C10 em paralelo.
- **M3 (UI)**: C19 → C20 → C21 e C22 → C23 → C25.
- **M4 (Limpeza e release)**: C24 → C26 → C27 e C28 → C29. C30 depois do 1.0.

**TDD por fase (Swift Testing apenas, sem `sleep` arbitrário, espera explícita por stream ou fake):**
- **M1**: testes de `AppContainer.makeServices` (em teste ou DEBUG, a escolha certa de cada implementação), de `AppConfiguration` (string vazia vira não configurado), de mapeamento de `AnalyticsEvent` e do `SentryEventSanitizer` (paths `/Users/x/...` viram `~/...`, `/private/var/folders/...` vira `<tmp>`, usuário removido, breadcrumbs limpos).
- **M2**:
  - testes de `SafePathPolicy` (raiz, ancestral, link, `..`, volume diferente) e da agregação do relatório;
  - scanner e remover sobre árvores numa pasta temporária criada pelo teste (`TemporaryDirectoryFixture` em `FileManager.temporaryDirectory/<UUID>`, removida no fim);
  - `ProcessRunner` com binários inofensivos;
  - `SimctlSimulatorService` com um `ProcessRunning` falso e fixtures JSON;
  - tabela de verdade da `TemporaryItemsPolicy`;
  - migração com `UserDefaults(suiteName: UUID)`;
  - ordem do executor com fakes.
  - **Nenhum teste toca em `~/Library`, `/private/tmp` ou `simctl` reais.**
- **M3**: testes dos ViewModels para cada transição de estado, com fakes determinísticos e um relógio injetável para a idade mínima. Previews para cada estado (determinísticos, sem `Bundle.main` para versão).
- **M4**: testes de `SemanticVersion`, e um `grep` dos artefatos removidos.

**Comandos de validação:**
- Focado, durante o desenvolvimento:
  ```sh
  xcodebuild test -project CleanerXcode.xcodeproj -scheme CleanerXcode -destination 'platform=macOS' -derivedDataPath "$TMPDIR/cleanerxcode-<card>-dd" CODE_SIGNING_ALLOWED=NO -only-testing:CleanerXcodeTests/<Suite>
  ```
- Suíte completa: o mesmo comando sem `-only-testing`.
- Build Release:
  ```sh
  xcodebuild build -project CleanerXcode.xcodeproj -scheme CleanerXcode -configuration Release -destination 'platform=macOS' -derivedDataPath "$TMPDIR/cleanerxcode-<card>-dd" CODE_SIGNING_ALLOWED=NO
  ```
  Zero avisos novos.
- Lint: `scripts/lint-swift.sh --fix` e depois `scripts/lint-swift.sh`.
- Pacotes: `xcodebuild -resolvePackageDependencies -project CleanerXcode.xcodeproj` e depois conferir o `Package.resolved`. O resultado esperado é só `himetrica-swift` e `sentry-cocoa`, mais `swift-timeout` e `launchatlogin-modern` até o C24 se a D4 for aceita.
- Sem Firebase: `grep -riE "firebase|google" CleanerXcode Tests CleanerXcode.xcodeproj` vazio, e `nm -gU <app>/Contents/MacOS/CleanerXcode | grep -i FIR` vazio.
- No fim de cada execução, remover o DerivedData temporário da tarefa, preservando o DerivedData compartilhado (regra do AGENTS.md).

---

## 9. Riscos, regressões, segurança, concorrência e migração

**Operações destrutivas:**
- Mitigações gerais: `SafePathPolicy`, catálogo fechado, remoção do conteúdo mantendo as raízes, Lixeira para itens perigosos, confirmação, bloqueio com o Xcode aberto, nada em `/Library/Developer/CoreSimulator` e nenhum teste com dados reais.
- O Developer **não** deve rodar limpeza real na máquina de desenvolvimento. O C27 exige autorização explícita do dono.

**Pasta temporária:**
- Risco: apagar arquivos em uso por agentes de IA, terminais, `cc-socks` ou `claude-501`.
- Mitigações: idade mínima, filtro de dono, sockets pulados, exclusões, categoria desligada por padrão e aviso. Em `/private/var/tmp` há sockets `com.apple.launchd.*` (verificado), que entram na lista de exclusões.

**Simuladores:**
- `simctl runtime delete` pode pedir privilégio ou demorar. Validar no C27 e tratar o timeout longo.
- A semântica de `clear-simulator-data` muda de apagar tudo para `erase all`: os simuladores continuam existindo. Isso vai para as Release Notes.
- O reinício do serviço por SIGTERM é empírico. Fallback: avisar "feche o Xcode e o Simulator e tente de novo" e nunca sugerir reboot como passo normal.

**Causa do "precisa reiniciar":**
- **(a)** O script atual roda `rm -rf ~/Library/Developer/CoreSimulator` com o CoreSimulatorService ativo. Esse serviço é por usuário e de longa duração, e mantém o device set e handles em memória. O Xcode e o `simctl` passam a ver um estado inconsistente até o serviço ser reiniciado, e o reboot faz isso.
- **(b)** Os runtimes são disk images Cryptex montadas pelo sistema. Nesta máquina, os `mountPath` são `/Library/Developer/CoreSimulator/Volumes/iOS_24B114` e `/private/var/run/com.apple.security.cryptexd/mnt/...`, com origem em `/System/Library/AssetsV2` (SIP). Apagar arquivos em `/Library/Developer/CoreSimulator/{Images,Volumes,Cryptex}` deixa montagens órfãs.
- **Correção:** usar a API (`simctl delete`, `erase`, `runtime delete`, que segundo o help do Xcode 27.2 "shuts down booted simulators and unmounts the disk first"), encerrar antes e reiniciar o serviço só depois de remoção direta.

**Concorrência e cancelamento:**
- I/O fica fora do main actor (`@concurrent`), e as tasks são guardadas e canceladas antes de uma nova medição ou limpeza.
- O processo filho recebe `terminate` no cancelamento e no timeout, corrigindo a pendência atual.
- Sem `Task.detached` nem `@unchecked`.
- As closures do Sentry são `nonisolated` para evitar as asserções de isolamento do Swift 6.
- O Himetrica é `@MainActor` e só é chamado a partir dos ViewModels.

**Dependências:**
- O SDK do Himetrica está em beta (`platform` "ios" fixo, sem lifecycle no AppKit): fica isolado num adaptador e pode ser trocado sem afetar o domínio.
- O Sentry baixa XCFrameworks binários com checksum fixo no manifesto (supply chain coberta pela versão exata).
- **Perda do histórico de analytics** do Firebase. Os nomes dos eventos foram mantidos para comparação conceitual.

**Validação live pendente:** envio de eventos ao Himetrica e de crashes ou erros ao Sentry até haver chave e DSN reais (C28). Não se pode alegar envio antes disso.

**Assinatura:** o diff local trocou para Automatic. A notarização depende do export Developer ID (C26). Não reverter o diff.

**Regressões de comportamento a comunicar nas Release Notes:**
- deixa de ser um app só de barra de menus;
- Archives vem desligado para quem nunca mexeu;
- Archives e dados do usuário vão para a Lixeira;
- "Dados de simulador" passa a apagar o conteúdo sem remover os simuladores;
- o mínimo passa a ser macOS 26.

**Migração do `UserDefaults` (`PreferencesMigrator`, v1→v2, idempotente, com `preferences-schema-version = 2`):**
- As chaves legadas dos scripts (`remove-archives`, `remove-caches`, `remove-derived-data`, `clear-device-support`, `clear-simulator-data`, `remove-old-simulators`, `reset-xcode-preferences`) continuam iguais e com a mesma codificação (`Data` com JSON de `Bool`). Valor salvo é preservado; chave ausente recebe o novo padrão (D5).
- `display-free-up-space-in-menu-bar` passa a ser lida como "mostrar o tamanho na barra". A chave nova `show-menu-bar-extra` vem ligada por padrão.
- `launch-at-login`: se for `true` e `SMAppService.mainApp.status` for `.notRegistered`, chama `register()` uma vez. Daí em diante, a fonte de verdade é o `SMAppService`. O LaunchAtLogin-Modern já usa `SMAppService`, então quem tinha a opção ligada continua registrado.
- Valor corrompido volta ao padrão sem crash, e o evento é registrado no Sentry como breadcrumb sem a chave.
- Testes cobrem todos os casos com uma suite isolada.

---

## 10. Critérios de aceite

| AC | Requisito | Resultado esperado | Validação |
|---|---|---|---|
| AC1 | R1 | A medição de cada categoria bate com a soma de `totalFileAllocatedSize` da árvore do teste, não segue links, cancela em menos de 1 lote e roda fora do main actor | `FileSystemSizeScannerTests` |
| AC2 | R2 | O total é a soma das categorias selecionadas; o botão fica desabilitado com zero ou sem seleção; o rótulo é "Limpar <ByteCountFormatter>" | `CleanerViewModelTests` e preview |
| AC3 | R3 | Os valores legados são preservados e os padrões novos valem só para chave ausente; a migração é idempotente | `PreferencesMigratorTests` |
| AC4 | R4 | Cada categoria tem raízes, método, risco e padrão conforme a tabela 5.5; não há raiz fora de home, temp ou var/tmp | `CleanupCatalogTests` |
| AC5 | R5 | Plano com perigo ou atenção exige confirmação; com o Xcode aberto, prefs e UserData ficam bloqueados e DerivedData mostra aviso | `CleanerViewModelTests` com `RunningApplicationsProviding` falso |
| AC6 | R6 | Com um item falhando, o estado final é falha parcial com a lista; inexistente conta como pulado; nunca há sucesso com falha | `CleanupExecutorTests` e `CleanerViewModelTests`; AC6-live no C27 |
| AC7 | R7 | Cancelar entre itens produz relatório "cancelado" com os bytes já liberados; o processo falso recebe terminate | `CleanupExecutorTests` e `ProcessRunnerTests` |
| AC8 | R8 | O parse dos fixtures dá o tamanho de `dataPathSize + logPathSize`; os duplicados são agrupados e o mais recente é sugerido; apagar emite `shutdown` e depois `delete` com os UDIDs exatos | `SimctlSimulatorServiceTests`, `DuplicateSimulatorDetectorTests` e `SimulatorsViewModelTests` |
| AC9 | R9 | A lista de runtimes tem tamanho e `deletable`; apagar exige confirmação e emite `runtime delete <identifier>` | Testes do serviço e do ViewModel |
| AC10 | R10 | O executor nunca gera caminho em `/Library/Developer/CoreSimulator`; encerra antes; reinicia o serviço só depois de remoção direta | `CleanupExecutorTests`; AC10-live: boot de simulador sem reboot (C27) |
| AC11 | R11 | A política pula itens de outro dono, recentes, sockets e excluídos, e remove os elegíveis | `TemporaryItemsPolicyTests` |
| AC11b | R11 (F19) | Só são órfãos os UDIDs ausentes de todos os sets | `OrphanSimulatorTempFinderTests` |
| AC12 | R12 | Sem xcrun ou simctl, a seção fica indisponível e as outras categorias funcionam | Testes do serviço e do ViewModel |
| AC13 | R13 | `EPERM` leva ao estado de permissão negada com ação para os Ajustes; não há `NSOpenPanel` no código | Testes do ViewModel e `grep NSOpenPanel` vazio |
| AC14 | R14 | Janela única aparece no lançamento; `MenuBarExtra` alterna; fechar a última janela segue a regra | Build e execução local (sem XCUI), evidência em captura e preview |
| AC15 | R15 | `SMAppService` liga e desliga; a migração registra uma vez | `LoginItemTests` com fake; AC15-live em /Applications (C27) |
| AC16 | R16 | Comparação semântica correta (0.10.0 > 0.9.0) | `SemanticVersionTests` |
| AC17 | R17 | A aba Sobre tem social, dedicatória e doação, e emite os eventos `social` e `donate` | Testes do `SettingsViewModel` |
| AC18 | R18 | Todas as strings existem em en e pt-BR; ícones têm rótulos; previews com texto grande e Reduzir transparência | Verificação do `xcstrings` e previews |
| AC19 | R19 | `SWIFT_VERSION 6.0`, MainActor por padrão, approachable, macOS 26; build sem avisos | `xcodebuild build` e conferência do pbxproj |
| AC20 | R20 | Nenhuma referência a Firebase ou Google no código, no pbxproj, no `Package.resolved`, no binário e no README | `grep` e `nm` |
| AC21 | R21 | Os eventos têm nomes e propriedades estáveis, sem paths, nomes ou UDIDs; Null em DEBUG, teste ou chave vazia | `AnalyticsEventTests` e `AppContainerTests` |
| AC21b | R21 | O opt-out impede o envio | Teste do adaptador com espião |
| AC21-live | R21 | O evento aparece no projeto Himetrica | C28 (pendente da chave) |
| AC22 | R22 | O Sentry inicia em Debug (environment `debug`) e em Release (`production`), com release `bundleID@versão+build` | `ErrorReportingConfigurationTests` |
| AC22b | R22 | O sanitizador remove paths do usuário, temp e usuário de eventos e breadcrumbs; a falha parcial gera um único evento agregado | `SentryEventSanitizerTests` e teste do ViewModel com espião |
| AC22c | R22, R27 | Em testes e previews, o Sentry nunca é inicializado (Null) | `AppContainerTests` |
| AC22-live | R22 | Crash ou erro de teste chega ao environment certo, simbolicado | C28 (pendente do DSN) |
| AC23 | R23 | O repo não contém a chave nem o DSN; existe exemplo versionado; o build passa sem `Secrets.xcconfig`; `MIXPANEL_TOKEN` não existe | `git grep` e build |
| AC24 | R24 | Não sobra nenhum `.sh`, `/bin/bash`, `Shell` ou `CommandExecutor`; deps D4 removidas | `grep` e `Package.resolved` |
| AC24b | R24, R10 | O `ProcessRunner` aplica timeout e terminate, separa o stderr e não trava com saída grande | `ProcessRunnerTests` |
| AC25 | R25 | App e DMG assinados com Developer ID, notarizados e com staple; dSYMs enviados | `spctl`, `codesign`, `notarytool log` e painel do Sentry |
| AC26 | Docs | README, RELEASE_NOTES, `version.json`, versão e build, BRIEF e GUIDE atualizados | Revisão do diff |
| AC27 | R27 | Em teste, o app hospedeiro não mede, não chama `simctl` e não inicia SDKs | `AppContainerTests` |
| AC28 | R26 (P3) | Download de runtime com progresso e cancelamento | Teste do serviço com fake |
| AC29 | N2 | A `SafePathPolicy` rejeita raiz, ancestral, link para fora e outro volume | `SafePathPolicyTests` |
| AC30 | Layout | Arquivo Figma com todos os frames da seção 6 em Light e Dark, aprovado pelo dono | Link e data no card C01 |
| AC30b | Layout | A implementação corresponde ao Figma aprovado (hierarquia, estados, glass só na camada de controles) | Revisão do Manager com capturas locais |
| AC31 | N5 | `scripts/lint-swift.sh` encontra `CleanerXcode/Sources` e `Tests` e passa sem violações | Execução do script |

---

## 11. SKILLS_STATUS

```text
SKILLS_STATUS:
- APPLIED: .agents/skills/swift-concurrency/SKILL.md — obrigatória no planejamento; settings reais lidos no pbxproj (SWIFT_VERSION 5.0, sem strict/default isolation) e defaults do Xcode 27.2 nos templates; desenho de @concurrent, Task entry isolation, TaskGroup, cancelamento, Process Sendable, closures nonisolated para Sentry — referências: SKILL.md (Fast Path, Task entry isolation, Swift 6 migration loop)
- APPLIED: .agents/skills/swiftui-expert-skill/SKILL.md — @Observable em ViewModels MainActor, @State privado, modifiers em vez de troca de raiz, .task/cancelamento, Liquid Glass só por pedido explícito do dono (atendido), APIs modernas, previews por estado
- APPLIED: .agents/skills/swiftui-ui-patterns/SKILL.md — composição da tela única, estados de async explícitos, sheets por item, injeção explícita por inicializador/ambiente, previews com fakes
- APPLIED: .agents/skills/swiftui-patterns/SKILL.md — escolha de cena (Window principal + Settings + MenuBarExtra opcional), activation policy regular e documentada, Settings como cena própria, toolbar com ações e atalhos; refs: references/windowing.md, references/menu-bar-extra.md, references/settings.md
- APPLIED: .agents/skills/swiftui-liquid-glass/SKILL.md — glass só na camada de controles (toolbar, hero, botões .glass/.glassProminent), GlassEffectContainer para agrupar, interactive só em interativos; ref: references/liquid-glass.md; conferido com "Adopting Liquid Glass" (Apple)
- APPLIED: .agents/skills/swiftui-view-refactor/SKILL.md — redesign substitui CleanerView/PreferencesView/MainView: subviews dedicadas por seção, ações fora do body, raiz estável, ViewModel não opcional criado no init
- SKIPPED: .agents/skills/ios-debugger-agent/SKILL.md — app macOS nativo validado em platform=macOS; não há iOS Simulator como destino do app (o simctl aparece só como ferramenta gerenciada pelo produto, nunca para depurar o app)
- CONFLICTS: swiftui-view-refactor ("MV por padrão") × SWIFT_REFERENCE (MVVM obrigatório) — adotado MVVM (CleanerViewModel, SimulatorsViewModel, SettingsViewModel, UpdateViewModel), conforme a precedência do projeto — validação: revisão do Manager
- CONFLICTS: swiftui-liquid-glass/expert ("#available + fallback") × deployment target macOS 26 (D2) — sem fallback, porque toda a base suportada tem a API — validação: build com MACOSX_DEPLOYMENT_TARGET=26.0
- CONFLICTS: swiftui-patterns ("WindowGroup(id:) para a janela de lançamento em apps com MenuBarExtra") × decisão de janela única singleton — adotada Window(id:) com a verificação obrigatória de apresentação no lançamento e fallback documentado para WindowGroup(id:) — validação: AC14
- CONFLICTS: SWIFT_REFERENCE (Resources/ só conteúdo, Tests/ espelhado) × pbxproj e gate de lint — xcconfig, Info.plist e entitlements ficam na raiz de CleanerXcode/; Tests/ na raiz do repo — exceção a registrar no PROJECT_GUIDE — validação: AC31
```

---

## 12. Fontes consultadas

**Web (consultadas em 2026-10-31):**
- [App Sandbox Temporary Exception Entitlements](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html) (arquivo da Apple, revisão de 2017-03-27)
- [App Review Guidelines, 2.4.5](https://developer.apple.com/app-store/review/guidelines/)
- [Developer Forums 663311](https://developer.apple.com/forums/thread/663311) (DTS, 2020-10: exceções temporárias e App Review; shell em app da loja)
- [Developer Forums 807142](https://developer.apple.com/forums/thread/807142) (Acesso Total ao Disco não contorna o App Sandbox)
- [Developer Forums 678819](https://developer.apple.com/forums/thread/678819) ("On File System Permissions", revisado em 2026-09-18)
- [Developer Forums 815676](https://developer.apple.com/forums/thread/815676) (`waitUntilExit` que nunca termina)
- [glassEffect(_:in:)](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)) (macOS 26.0+)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Downloading and installing additional Xcode components](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components)
- [Himetrica: iOS & macOS SDK (Beta)](https://www.himetrica.com/docs/swift), [Docs](https://www.himetrica.com/docs) e [Server API](https://www.himetrica.com/docs/server-api) (exige chave secreta `hm_sk_`)
- [himetrica-swift](https://github.com/himetrica/himetrica-swift): `Package.swift` com tools 5.9, sem dependências, tag 1.0.0 em `b62348e` (verificado com `git ls-remote`)
- [Sentry macOS guide](https://docs.sentry.io/platforms/apple/guides/macos/) e [Sentry dSYM upload](https://docs.sentry.io/platforms/apple/guides/macos/dsym/)
- [sentry-cocoa 9.32.0 Package.swift](https://github.com/getsentry/sentry-cocoa): tools 6.0, macOS 12, produto `Sentry` binário. A tag mais recente, 9.32.0, foi verificada com `git ls-remote`

**Referências citadas sem busca nesta sessão (confirmar a URL ao usar):**
- SE-0466 (default actor isolation) e SE-0461 (`nonisolated(nonsending)`), em github.com/swiftlang/swift-evolution. O guia de migração do swift.org devolveu 403.
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [FileManager.trashItem](https://developer.apple.com/documentation/foundation/filemanager/trashitem(at:resultingitemurl:))
- [URLResourceKey.totalFileAllocatedSizeKey](https://developer.apple.com/documentation/foundation/urlresourcekey/totalfileallocatedsizekey)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

**Evidência local (2026-10-31; Xcode 27.2 27B52, SDK macOS 27.2):**
- `xcrun simctl help runtime`: `runtime delete … shuts down and unmounts first`, `--unusable`, `--outdated`, `--notUsedSinceDays`, `--dry-run`.
- `simctl list --json devices`, que inclui `dataPathSize` e `logPathSize`.
- `simctl runtime list --json`, que inclui `sizeBytes`, `deletable`, `mountPath` e paths em AssetsV2.
- `launchctl print gui/<uid>`: CoreSimulatorService é um endpoint on-demand.
- `NSTask.h`: `NS_SWIFT_SENDABLE` e `launchRequirementData` (macOS 14.4).
- Templates do Xcode 27.2: `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY=YES`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY=YES`, `SWIFT_VERSION=6.0`.
- `/private/var/tmp`: 80 pastas `com.apple.CoreSimulator.SimDevice.*` para 14 simuladores, e sockets `com.apple.launchd.*`.
- `$TMPDIR` com cerca de 588 `TemporaryDirectory.*`.
- `~/Library/Caches/org.swift.swiftpm` com 3,5 GB.
- `UserData` contém `Provisioning Profiles` e `KeyBindings`.
- `scripts/lint-swift.sh` só coleta `Sources/` e `Tests/`.
- `TEST_HOST` aponta para o app, ou seja, os testes rodam hospedados no app.

### Critical Files for Implementation
- /Users/adrianosouzacosta/Documents/Projects/CleanerXcode/CleanerXcode.xcodeproj/project.pbxproj
- /Users/adrianosouzacosta/Documents/Projects/CleanerXcode/CleanerXcode/CleanerXcodeApp.swift
- /Users/adrianosouzacosta/Documents/Projects/CleanerXcode/CleanerXcode/Stores/CleanerStore.swift
- /Users/adrianosouzacosta/Documents/Projects/CleanerXcode/CleanerXcode/Utils/Preferences.swift
- /Users/adrianosouzacosta/Documents/Projects/CleanerXcode/CleanerXcode/Config.xcconfig
- /Users/adrianosouzacosta/Documents/Projects/CleanerXcode/scripts/lint-swift.sh
---

## Artefatos de execução (2026-10-31)

- Board no Trello: [CleanerXcode 1.0 — Redesign nativo](https://trello.com/b/C7McqDHT/cleanerxcode-10-redesign-nativo) (D00 + C01–C30, com checklists, critérios de aceite e etiquetas de prioridade).
- Layout no Figma (C01, em revisão): [CleanerXcode — Redesign 1.0 (Liquid Glass)](https://www.figma.com/design/n2zvygzbWufumwsOYd1PAj).
- Ajustes pedidos pelo dono durante o C01, já aplicados no layout:
  - todos os cards do hero com a mesma altura;
  - linhas de categoria com a mesma altura;
  - seções expansíveis e compactáveis, com estado persistido por seção;
  - sem linhas separadoras nas listas e nos painéis da barra de menus;
  - ícone real do app na aba Sobre.

## Adendo do dono (2026-10-31): sugestão de doação a cada N limpezas

- **F36:** a cada N limpezas concluídas com sucesso, o resultado troca o botão
  OK por "Apoiar o projeto", com "Fechar" abaixo e menos destaque. O card de
  doação abaixo do hero fica oculto nesse estado.
- **R28:**
  - contador `successful-cleanup-count` persistido;
  - `DonationPromptPolicy.shouldPrompt(afterSuccessfulCleanups:)` puro, com
    `interval = 3`, confirmado pelo dono em 2026-10-31: aparece na 3ª, na 6ª,
    na 9ª limpeza bem-sucedida, e assim por diante;
  - só em sucesso, nunca em falha parcial, falha, cancelado ou permissão
    negada;
  - "Apoiar o projeto" abre a Sheet de apoio e loga `donate`;
  - "Fechar" dispensa.
- **AC32:** o prompt aparece só na N-ésima limpeza bem-sucedida (testes da
  policy e do ViewModel); o contador persiste; Fechar dispensa; Apoiar abre a
  sheet e loga `donate`; layout conforme o Figma (variante de Hero "Sucesso
  com apoio" e o frame "Janela · Sucesso com sugestão de doação").
- **Card C31** no Trello (P1), depois do C29. O dono pediu para implementar
  somente no fim.

## Adendo da revisão do C07 (2026-10-31)

- **Contrato `result` do evento `cleaner`:** `success`, `partial_failure` e
  `failure` (quando todas as categorias falham). O `cancelled` passa a ser
  emitido quando o cancelamento chegar na interface (C17/C19). O
  `freed_bucket` é estimado antes da limpeza até o C17.
- **Privacidade do Himetrica 1.0.0:** o SDK envia `visitorId` (UUID aleatório
  em `hm_visitor_id`), `sessionId` e um User-Agent com as versões do app e do
  macOS, e o servidor vê o IP. É dado pseudônimo, então a preferência se chama
  "Enviar estatísticas de uso" ("Send usage statistics"), e o texto do
  Figma/C22 segue esse nome.
- **Gate de distribuição:** nenhum Release com `HIMETRICA_API_KEY` sai antes do
  C22 (toggle de opt-out na UI).
- **Risco (seção 9):** a fila offline do SDK
  (`~/Library/Application Support/Himetrica/EventQueue`) não tem namespace por
  bundle. Num app sem sandbox, ela pode ser compartilhada com outro app que use
  o mesmo SDK: eventos de um podem ser reenviados com a chave do outro, e o
  `reset()` apaga a fila de todos. A probabilidade é baixa, porque exige outro
  app com o SDK e eventos offline. Mitigações possíveis: abrir uma issue no
  `himetrica-swift` pedindo namespace por bundle, aceitar o risco, ou
  trocar/forkar o SDK (exige aprovação). **Decisão do dono pendente.**
  Enquanto isso, nunca usar `Himetrica.reset()`.

## Adendo da implementação do C08 (2026-10-31)

- **Contrato:** `ErrorReporting` com `start()`, `capture(_: ReportableFailure)`
  e `breadcrumb(_: ReportingStage)`. O primeiro caso é
  `ReportableFailure.cleanupFailed(failedCategories:errorKinds:totalCategories:)`,
  que vira a mensagem `cleanup_partial_failure` (warning) com as tags
  `result`, `failed_categories` e `error_kinds` e os extras `failed_count` e
  `total_count`. `capture(error:)` para erros inesperados entra junto com os
  cards que os produzem (decodificação do simctl, `unsafePath`).
- **Sessões desligadas:** `enableAutoSessionTracking = false`. As sessões de
  release health levam o installation ID do Sentry (`distinctId`, conferido em
  `SentryHub.m` do 9.32.0) e não passam pelo `beforeSend`. Sem elas não há
  taxa de crash-free sessions no painel.
- **Frames:** o sanitizador troca o home por `~` em `fileName` e `package` em
  vez de usar uma allowlist de nomes de arquivo. Os frames do app só trazem
  caminhos da máquina de build, e os do sistema não trazem `fileName`.
- **Previews:** o `AppEnvironment` passou a detectar
  `XCODE_RUNNING_FOR_PREVIEWS=1`, e o container trata previews como testes
  (serviços inertes, sem Sentry nem Himetrica), cumprindo o AC22c.
- **DSN inválido:** `AppConfiguration` descarta DSN sem esquema `http(s)` ou
  sem host (NIT do C06).
- **Bundle:** o `Sentry` é estático, e o Xcode embute um
  `Sentry.framework` de 64 KB, sem símbolos, só para o `PrivacyInfo.xcprivacy`.
  A assinatura Developer ID do C25 precisa cobri-lo (o Xcode já assina).
- **Revisão do C08:** o sanitizador passou a cobrir `event.context`
  (inclusive o `user info` de NSError/NSException), `mechanism.desc` e
  `mechanism.data`, e remove `context.app.device_app_hash` (identificador
  derivado do MAC de `en0`). A regex do home não diferencia maiúsculas.
- **Pendências registradas:** a tag `failed_categories` pode passar do limite
  de 200 caracteres do Sentry quando o C09/C17 trouxer as 15 categorias; o
  C17 deve levá-la para `extra` ou contexto. Builds Debug usam `dwarf` (sem
  dSYM), então o AC22-live do C28 deve ser validado com uma build Release e o
  upload de dSYMs.

## Adendo da implementação do C09 (2026-10-31)

- **`SafePathPolicy`** recebe `allowedBases` (`~/Library` e as três pastas
  temporárias) e um `CleanupTarget`.
  - `validateRoot` rejeita, com `.unsupportedRoot`, uma raiz que seja
    symlink, que saia da base depois de resolvida ou que contenha `/`, `~` ou
    `~/Library`. O alvo é pulado sem gerar relatório de bug.
  - `validate` rejeita `.`/`..`, `excludedNames` e raízes do catálogo
    aninhadas, e devolve `.notFound` para item inexistente.
  - O volume é comparado por `volumeURLKey` em vez de `volumeIdentifierKey`.
    Uma URL pode ser devolvida pelo `PathInspecting` e comparada com `==`, e o
    efeito é equivalente ao do identificador.
- **Pendências para o C12, da re-revisão do C09:**
  - (R1) decidir se um symlink num ancestral entre a base e a raiz deve tornar
    a raiz `.unsupportedRoot`. Hoje ele é aceito quando a raiz resolvida fica
    dentro da base; por exemplo, `CoreSimulator` apontando para `~/Library`
    faria `CoreSimulator/Caches` cair em `~/Library/Caches`;
  - (R3) `FileSystemPathInspector.exists` deve devolver `false` só para
    `ENOENT`/`ENOTDIR`, deixando falhas de permissão chegarem ao remover, e
    ganhar um teste de link pendente.
- **`CleanupItemResult`** grava `.failed(.notFound)` e
  `.failed(.unsupportedRoot)` como `.skipped`. O `.failed(.cancelled)`
  continua sendo falha quando a limpeza não foi cancelada.
- **`CleanupOperation`**: os `targets` das categorias simctl indicam o que é
  medido. `clear-simulator-data` mede `CoreSimulator/Devices`;
  `remove-old-simulators` e `reset-xcode-preferences` não têm alvo.
- **Lint × revisão:** o `type_contents_order` do projeto exige subtipos antes
  de subscripts, então o `subscript` do `CleanupCatalog` fica depois de
  `Nested Types`.
- **Pendência para o C17:** o aviso de DerivedData com o Xcode aberto (R5) é
  derivado pelo ID da categoria na interface; o catálogo só modela os
  bloqueios.

## Investigação do C10 (2026-10-31, somente leitura)

Nenhuma categoria nova é proposta:
- `~/Library/Developer/CoreDevice/DeviceFS` (724 MB): é um mount `devicefs`
  (fskit, somente leitura) do `CoreDeviceService` que expõe aparelhos
  físicos, não um cache local. Fica excluído; a `SafePathPolicy` também o
  rejeitaria pelo volume.
- `~/Library/Developer/Xcode/CodingAssistant` (4 KB): só `mcp-servers.json`,
  configuração do usuário. Fica excluído.
- `~/Library/Developer/DVTDownloads` (4 KB): `Assets/MetalToolchain` vazio e
  `Personalization`. É insignificante e fica excluído.
- Cache de documentação do Xcode 27: não foi encontrado em
  `~/Library/Developer`, em `~/Library/Caches/com.apple.dt.Xcode` nem em
  Application Support. Sem categoria.
- `~/Library/Developer/Xcode/UntitledProjects` contém projetos do usuário e
  nenhuma raiz do catálogo o alcança. Isso continua obrigatório.

## Adendo da implementação do C11 (2026-10-31)

- **`FileSystemSizeScanner`** (`Core/FileSystem`, conforma `DiskUsageScanning`):
  - `nonisolated struct` com `@concurrent func allocatedSize(of:)`. A
    enumeração síncrona fica numa função estática, e cada chamada cria o
    próprio `FileManager` por uma fábrica injetável, que os testes usam para
    cancelar no meio e observar a thread.
  - A raiz é lida por `attributesOfItem` (lstat). Raiz inexistente mede 0, e
    raiz symlink mede 0, como o `.unsupportedRoot` da `SafePathPolicy`. Raiz
    ilegível lança o `CleanupError` mapeado, por exemplo `.permissionDenied`.
  - Diretórios e links contam 0, e links nunca são seguidos. Os
    `excludedNames` valem só no nível 1. Um subitem ilegível conta 0, e só a
    contagem vai para o `os.Logger`, sem caminho. O protocolo continua
    devolvendo `Int64`, como na seção 5.4.
  - O cancelamento é verificado no início e a cada 500 itens. Não há
    verificação depois do laço, para que o teste do lote seja
    discriminante. Uma medição cancelada no último lote parcial ainda pode
    devolver um valor, e quem chama verifica o cancelamento antes de usar o
    resultado.
- **`CategorySizeMeasurer`** (`Core/Cleanup`) diverge da seção 5.3:
  - o grupo de tarefas sai do ViewModel para um helper reutilizável no Core.
    O `CleanerViewModel` (C19) continua dono do `Task` da medição e cancela a
    anterior antes de começar outra;
  - há um filho por categoria com alvo, e os alvos de cada categoria são
    medidos em sequência. Um alvo que falha fica fora da soma e vai em
    `CategorySize.failure`;
  - `measure` recebe `isolation: isolated (any Actor)? = #isolation`, e o
    corpo do grupo captura o parâmetro, porque pela SE-0420 uma closure só
    herda o isolamento capturando-o. Sem isso, o teste viu os resultados
    fora da main thread;
  - cada resultado só é entregue depois de `Task.checkCancellation()`, então
    uma medição cancelada não entrega nada;
  - categorias sem alvo (`remove-old-simulators` e
    `reset-xcode-preferences`) não geram resultado; o tamanho delas vem do
    `simctl` (C14).
- **Limitações aceitas:**
  - hard links e clones APFS contam por arquivo, como já indica o rótulo
    "estimado" da R2;
  - as cerca de 13 medições simultâneas ocupam threads do pool cooperativo
    com I/O bloqueante. Isso não afeta a interface, porque o main actor não
    usa o pool, e só pode atrasar outras tarefas assíncronas durante a
    medição. Limitar os filhos fica para o C19, se a medição real mostrar
    impacto.
- **Pendência para o C15 e o C19:** as categorias temporárias são medidas
  brutas aqui. `clear-orphan-simulator-temp` (ligada por padrão) e
  `clear-temporary-files` têm `/private/var/tmp` como alvo, então a medição
  bruta contaria a pasta inteira nas duas e inflaria o "Limpar <total>". O
  C15 entrega a medição filtrada pela `TemporaryItemsPolicy` e pelo
  `OrphanSimulatorTempFinder`, e o C19 não pode mandar essas categorias para
  o medidor bruto.

## Adendo da implementação do C12 (2026-10-31)

- **Contrato do `FileRemoving`**, que diverge da seção 5.4:
  `@concurrent func removeContents(of: CleanupTarget, categoryID:, mode:,
  filter: @Sendable (URL) -> Bool, onResult: @Sendable (CleanupItemResult) -> Void)
  async throws`.
  - A `SafePathPolicy` e as `CleanupLocations` (para o `displayPath`) entram
    no init, então quem chama não consegue pular a política.
  - Não há `remove(_:mode:)` avulso, porque nada precisa dele ainda.
  - Filhos em `excludedNames` nem são listados, e os rejeitados pelo
    `filter` são ignorados sem resultado.
- **API estruturada em vez de `AsyncThrowingStream`** (B1 da revisão):
  - com o stream, cancelar quem consumia encerrava o `next()` na hora e
    perdia o resultado de um item já removido;
  - agora o trabalho roda na task de quem chama, fora do ator dele. Cada
    resultado chega antes do próximo `Task.checkCancellation()`, e o
    `CancellationError` sobe para quem chama;
  - o executor (C17) repassa os resultados para o próprio stream de eventos.
- **Fluxo:**
  - `validateRoot` roda uma vez. `.unsafePath` gera uma falha para a raiz, e
    `.unsupportedRoot` gera um pulado.
  - Raiz inexistente não gera resultado. Raiz ilegível gera
    `failed(.permissionDenied)` para a raiz, mostrada sem barra final.
  - Para cada filho: cancelamento, `validate`, tamanho (pasta pelo scanner,
    link 0, arquivo pela própria alocação), nova verificação de cancelamento
    e só então a remoção ou a Lixeira, via `FileOperating`.
  - Uma falha reporta 0 bytes. Uma pasta esvaziada em parte e que falha
    também reporta 0, então o liberado pode ficar subestimado.
- **Lixeira:** os testes usam um espião e nunca tocam a Lixeira real. O
  caminho real do `trashItem` fica para a validação ao vivo do C27.
- **`SafePathPolicy`:**
  - (R1 do C09) um symlink entre a base permitida e a raiz torna a raiz
    `.unsupportedRoot`. A raiz resolvida precisa ser igual à base resolvida
    mais o mesmo sufixo; symlinks acima da base, como `/var`, continuam
    aceitos.
  - (R3 do C09 e B2 da revisão) `PathInspecting.existence(of:)` devolve
    `.present`, `.missing` (só `ENOENT`/`ENOTDIR`) ou `.unreadable(erro)`.
    Um item que não pode ser consultado lança o erro real, como
    `.permissionDenied`, em vez de `.unsafePath`.

## Adendo da implementação do C13 (2026-10-31)

- **`ProcessRunner`** (`Core/Process`, conforma `ProcessRunning`):
  - `nonisolated struct` com `@concurrent func run(_:)`, sem shell e com os
    argumentos em array. `ProcessRequest.xcrun(_:timeout:)` usa
    `/usr/bin/xcrun`, e o init exige um caminho absoluto. Os testes usam
    binários inofensivos do sistema (`echo`, `sleep`, `false` e `/bin/sh`
    só para escrever no stderr).
  - Prazos em `ProcessRequest`: 60 s por padrão, 600 s para `erase all` e
    1.800 s para `runtime delete`.
  - O término vem do `terminationHandler` com
    `withCheckedThrowingContinuation`. O cancelamento usa
    `withTaskCancellationHandler`, com `terminate()` só se o processo estiver
    rodando. O prazo é uma corrida num task group e termina o processo.
  - Exit diferente de zero, ou sinal não pedido, vira
    `CleanupError.commandFailed(exitCode:summary:)`, com o stderr sanitizado
    por `SentryEventSanitizer.sanitize(text:)` e cortado em 500 caracteres.
    Executável ausente vira `.toolUnavailable`.
- **Divergência da seção 5.3:** as saídas são lidas com
  `readabilityHandler` + `AsyncStream`, e não com
  `fileHandleForReading.bytes`. Um experimento com 40 leituras de `sleep 3`
  mostrou que o `bytes` bloqueia uma thread do pool cooperativo por pipe
  até o processo terminar: um `echo` esperou 3 s. Num `runtime delete` de
  até 30 min isso travaria o resto do app. O teste
  `aQuickCommandFinishesWhileManyLongCommandsAreRunning` falha com o `bytes`.
- **Verificações defensivas sem teste determinístico:** a verificação de
  cancelamento logo antes do `run()` e a que vem depois do task group
  cobrem corridas, porque a verificação no início de `run` e o filho do
  prazo já tratam os casos reproduzíveis. O `terminate()` no caminho do
  prazo repete o do `onCancel` disparado por `cancelAll()`.
- **Não feito (opcional do card):** `launchRequirementData` exigindo binário
  da Apple. O caminho é fixo em `/usr/bin` (SIP) e a regra pode ser
  adicionada no C14, se o dono quiser.
- **Limitação:** depois de `terminate()`, o runner espera o processo sair
  (`terminationHandler`). Ele não espera os pipes nem descendentes, porque
  uma leitura cancelada remove o `readabilityHandler` no `onTermination`,
  e não escala para `SIGKILL`. Um processo que ignore `SIGTERM` atrasaria
  o retorno. Foi verificado que o `xcrun` faz `exec` da ferramenta: o PID
  iniciado por `/usr/bin/xcrun sleep 3` passa a ser o próprio
  `/bin/sleep`, sem filhos. O `SIGTERM` chega então ao `simctl`, e o
  `SIGKILL` com período de tolerância fica para o C27, se a validação ao
  vivo mostrar necessidade.

## Adendo da implementação do C14 (2026-10-31)

- **`Core/Simulators`:**
  - **`DeviceSet`:** padrão ou `.custom(URL)`; o `--set <caminho>` vai logo
    depois de `simctl`.
  - **Tipos de domínio:** `SimulatorDevice` (estado `booted`, `shutdown` ou
    outro) e `SimulatorRuntime` (`identifier` para o `runtime delete`,
    `runtimeIdentifier` para relacionar com os simuladores).
  - **`SimctlJSON`:** DTOs com campos opcionais, para que um campo novo ou
    ausente nunca quebre a lista, e datas ISO 8601. Um JSON ilegível vira
    `SimctlSimulatorService.unreadableOutput` (`.unknown(domain: "SimctlJSON",
    code: 1)`), que é inesperado e deve ser reportado.
  - **`SimctlSimulatorService`:**
    - o tamanho é `dataPathSize + logPathSize`. Sem os dois, a pasta do
      simulador (o pai de `dataPath`) é medida pelo scanner;
    - apagar desliga um a um os simuladores ligados, porque
      `simctl shutdown` aceita um só, e depois roda `delete` com todos os
      UDIDs;
    - **diverge da seção 5.4:** `delete(_ udids:in:)` virou
      `delete(_ devices: [SimulatorDevice], in:)`, porque o desligamento é
      feito um a um e só nos ligados. Quem chama (C17 e C21) passa os
      simuladores listados;
    - prazos: 600 s para `erase all` e 1.800 s para `runtime delete`;
    - viram `.toolUnavailable` (R12) o exit 72 do `xcrun` ("unable to find
      utility"), qualquer erro do próprio `xcrun` (prefixo `xcrun: error:`,
      exit 1, como Xcode apagado mas ainda selecionado ou
      `DEVELOPER_DIR` inexistente, verificado com
      `DEVELOPER_DIR=/nonexistent xcrun simctl list`) e o executável ausente;
    - runtimes trazem também `state` e `kind`, para a interface diferenciar
      "Bundled with Xcode" e estados como `Deleting`;
    - na medição de reserva, o cancelamento (`CancellationError` ou
      `.cancelled`) cancela a listagem. Como o scanner pode retornar mesmo
      cancelado, a listagem verifica o cancelamento antes de usar o valor.
  - **`DuplicateSimulatorDetector`** (puro): agrupa por tipo e runtime e
    mantém o `lastUsedAt` mais recente. Nunca usado conta como o mais
    antigo, e o empate cai no UDID. Simuladores sem tipo ou runtime nunca
    são agrupados. Só sugere; a interface seleciona.
  - **`CoreSimulatorServiceRestarter`:** `LibprocProcessListing` encontra o
    serviço pelo último componente do `proc_pidpath`, porque o
    `proc_name` corta nomes longos como o do serviço, e envia `SIGTERM`.
    `ESRCH` e `EPERM` são ignorados (processo já encerrado ou de outro
    usuário).
- **Testes:** um `ProcessRunnerSpy` valida os argumentos exatos e nunca
  roda o `simctl`. A listagem real é testada contra o próprio processo de
  teste, e o `terminate` real contra um `sleep` criado pelo teste.
- **Verificação ao vivo, somente leitura (2026-10-31):** o serviço real
  decodificou 13 simuladores (31,7 GB) e 2 runtimes deste Mac, e achou o
  PID do CoreSimulatorService sem enviar sinal. O reinício real continua
  pendente para o C27.
- **Pendências para o C17:**
  - um set auxiliar inexistente faz o `simctl` responder "Provided set path
    does not exist", então o executor deve pular sets cujas pastas não
    existam;
  - `erase all` exige os simuladores desligados, então rodar `shutdownAll`
    antes. O mesmo vale antes de `delete`: o serviço só desliga os
    marcados como `Booted`, e um estado de transição ou desatualizado
    deixa de importar depois do `shutdownAll` (R10).
- **Pendência para o C17 e o C21:** os métodos `nonisolated async` rodam no
  ator de quem chama, então a decodificação do JSON e a varredura libproc
  do `restartService()` rodariam no main actor se um ViewModel os chamasse
  direto. O I/O de processo e de disco já é `@concurrent`; marcar o serviço
  como `@concurrent` só se a medição mostrar custo.
- **Pendência para o C21 e o C24:** sem nenhuma ferramenta de
  desenvolvedor instalada, o shim `/usr/bin/xcrun` pode abrir o pedido do
  sistema para instalar as Command Line Tools. Verificar ao vivo e decidir
  se o app consulta antes `xcode-select -p`.

## Adendo da implementação do C15 (2026-10-31)

- **Diverge da seção 5.4:** em vez de `shouldRemove(_:now:)` há
  `decision(for:now:)`, `simulatorTempDecision(for:now:)` e o estático
  `softened(_:)`, e o init exige o `appBundleIdentifier` para a exclusão
  dos arquivos do próprio app.
- **`TemporaryItemsPolicy`** (pura, `Core/FileSystem`):
  - padrão de 3 dias (D7); o init recebe os dias que vierem dos Ajustes
    (C22) e o `getuid()`;
  - `decision(for:now:)` (`clear-temporary-files`): as exclusões vêm
    primeiro (`com.apple.launchd.*`, `.X11-unix`, `powerlog`, `*.sock`,
    nomes que começam com o bundle ID do app e as pastas
    `com.apple.CoreSimulator.SimDevice.*`, que ficam para o F19). Depois o
    dono, o tipo (sockets, FIFOs e dispositivos são pulados) e a idade;
  - `simulatorTempDecision(for:now:)` (`clear-orphan-simulator-temp`):
    verifica só o dono, o tipo e a idade;
  - `softened(_:)`: `failed(.inUse)` vira `skipped(.inUse)` e
    `failed(.permissionDenied)` vira `skipped(.noPermission)`. O executor
    (C17) aplica nas duas categorias temporárias, porque assim `EBUSY`,
    `EPERM` e `EACCES` não viram falha da categoria.
- **`TemporaryItemInspector`:** lê dono, tipo e modificação com lstat.
  - A pasta vale pela modificação mais recente do que tem dentro, de forma
    recursiva e sem seguir links. Uma pasta lida só em parte, ou cuja
    varredura foi cancelada, conta como recente (`distantFuture`), e um
    item ilegível é deixado em paz.
  - **Pastas com socket, FIFO ou dispositivo dentro** (B1 da revisão) são
    preservadas em `clear-temporary-files` (`skip(.unsupportedFileType)`).
    O mtime de um socket não muda com o tráfego, então uma sessão de tmux
    ou de agente de IA com mais de 3 dias pareceria antiga. A regra não
    vale para os órfãos de simulador: as 80 pastas
    `SimDevice.*` desta máquina têm um `syslogsock`, que fica obsoleto
    quando o simulador não existe mais.
  - Uma inspeção rasa (`includingContents: false`) descarta antes da
    varredura recursiva o que as exclusões, o dono, o tipo ou a data da
    própria pasta já rejeitam.
- **`OrphanSimulatorTempFinder`:** compara o UDID sem diferenciar
  maiúsculas e exige um UUID válido depois do prefixo. `knownUDIDs(from:in:)`
  junta os UDIDs de todos os sets e falha se qualquer set falhar, porque
  sem a lista completa nada é órfão.
  - **Salvaguarda além do plano:** os órfãos também passam pela idade e
    pelo dono, para proteger o simulador de um set desconhecido.
  - **"Todos os sets"** (B2 da revisão): `DeviceSet.all(in:)` devolve o set
    padrão mais os sets auxiliares cujas pastas existem: `XCTestDevices`,
    `UserData/Previews/Simulator Devices`,
    `UserData/IB Support/Simulator Devices` e `XCPGDevices`. As pastas que
    não existem ficam de fora porque o `simctl` falha nelas.
- **`TemporaryFilters`:** filtros `@Sendable (URL) -> Bool` para o remover
  (C12) e para a medição, e assim o que aparece como liberável é
  exatamente o que seria removido.
- **Medição filtrada (pendência do C11):**
  - `FilteredContentsMeasurer` mede só os filhos aceitos;
  - `CategorySizeMeasurer.measure(_:filters:...)` usa esse caminho para
    as categorias com filtro;
  - o C19 deve passar os dois filtros temporários. Sem filtro, as
    categorias `removeTemporaryItems` e `removeOrphanSimulatorTemp` não
    geram resultado, em vez de serem medidas de forma bruta.
- **Cancelamento** (B3 da revisão): o remover verifica o cancelamento antes
  de cada chamada do filtro, porque os filtros temporários leem o disco.
  Assim um cancelamento não é engolido enquanto houver itens por filtrar,
  e a varredura do inspector para quando a task é cancelada. Exceção
  aceita: um cancelamento durante o filtro do último item termina o laço
  sem lançar. Nada a mais é removido, e as verificações entre alvos do
  executor (C17) tratam o caso.
- **Pendência para o C27:** um item cujo `fileResourceType` venha nulo
  enquanto a data é lida não é tratado como especial. Não foi possível
  reproduzir em teste; se aparecer ao vivo, tratar como leitura parcial.
- **Pendências para o C17 e o C19:**
  - rodar `OrphanSimulatorTempFinder.knownUDIDs(from:in: DeviceSet.all(in:))`
    antes de medir ou limpar `clear-orphan-simulator-temp` (ligada por
    padrão);
  - se a listagem falhar, por exemplo com `.toolUnavailable` (R12), a
    categoria fica indisponível, sem medição nem limpeza, porque sem a
    lista completa nada é órfão;
  - a medição não aplica a `SafePathPolicy`, então um filho em outro
    volume pode ser contado e depois recusado pelo remover; no pior caso o
    número fica um pouco maior que o liberado.
- **Refatoração:** o cálculo de tamanho por item saiu do
  `FileSystemRemover` para o `ItemSizeReader`, compartilhado com a medição
  filtrada, sem mudança de comportamento (os testes do remover continuam
  passando).
- **Verificação ao vivo, somente leitura (2026-10-31), nada removido:**
  - 5 sets e 13 UDIDs conhecidos;
  - das 80 pastas de simulador em `/private/var/tmp`, 10 são órfãs antigas
    (17,8 MB);
  - em `$TMPDIR` (1.111 itens) e `/private/tmp`, nada passa pela política;
    em `/private/var/tmp`, 7 itens (779 MB);
  - `claude-501` e `cc-socks` nunca são selecionados.
  - Se o C27 mostrar que a política está conservadora demais no
    `$TMPDIR`, revisar sem relaxar as salvaguardas.
- **Pendência para a interface (C20 e C22):** o aviso fixo "Feche apps de
  IA e terminais antes. Itens com menos de N dias são preservados." e a
  escolha de 1, 3, 7 ou 14 dias.

## Adendo da implementação do C16 (2026-10-31)

- **`Core/Xcode`:**
  - `UserDefaultsPreferencesResetter` (`XcodePreferencesResetting`): usa
    `UserDefaults.standard.removePersistentDomain(forName:)`, no lugar de
    `defaults delete`, e lança `.unknown(domain: "XcodePreferences",
    code: 1)` se sobrar valor. Os testes só resetam domínios criados por
    eles e conferem que um domínio vizinho fica intacto; o domínio real
    `com.apple.dt.Xcode` nunca é tocado. A validação ao vivo fica para o C27.
  - `WorkspaceRunningApplications` (`RunningApplicationsProviding`, no
    main actor): detecta o Xcode e o Simulator por bundle ID através de
    `TerminatableApplication`, que o `NSRunningApplication` adota.
    `terminateSimulator()` pede para fechar todos os Simulators ainda
    abertos e consulta `isTerminated` até o prazo (5 s, a cada 100 ms).
    - O resultado de `terminate()` é ignorado, porque ele também é `false`
      para uma instância que acabou de fechar (B2 da revisão). Só o
      `isTerminated` decide, e uma recusa real aparece como prazo vencido.
    - A consulta periódica foi escolhida pela simplicidade em vez da
      notificação `didTerminateApplication`: cada suspensão do main actor
      deixa o run loop atualizar o `isTerminated`.
    - O retorno é `false` se algum não fechou a tempo ou se a espera foi
      cancelada. O Xcode nunca recebe pedido para fechar, e os testes usam
      apps falsos.
- **Catálogo (R4/R5):**
  - **Diverge da seção 5.5:** duas flags declarativas novas em
    `CleanupCategory`. `warnsWhileXcodeRuns` vale só para DerivedData e
    fecha a pendência do C09. `shutsDownSimulators` vale para
    `clear-simulator-data`, `remove-old-simulators`,
    `clear-auxiliary-device-sets` e `clear-simulator-caches`;
  - o R5 lista F8, F21, F22, F23 e F24. O F9 (`delete unavailable`) entrou
    porque o R10 manda desligar os simuladores antes de qualquer operação
    com eles; F21 e F22 ficam na seção Simuladores (C21).
- **`CleanupRestrictions`** (pura): com o Xcode aberto, o reset e o
  UserData ficam bloqueados e o DerivedData mostra aviso. Com simuladores
  ativos (o Simulator.app aberto ou um simulador ligado, calculado pelo
  ViewModel), as categorias com `shutsDownSimulators` avisam que eles
  serão fechados. Uma categoria bloqueada não recebe aviso.
- **UserData e Provisioning Profiles para a Lixeira:** já vinham do
  catálogo (C09, `removeContents(.trash)`) e do remover (C12). O teste de
  tabela do catálogo garante o modo.
- **Testes do reset** (B1 da revisão): os primeiros testes usavam domínios
  com UUID e deixavam um plist vazio de 42 bytes por domínio em
  `~/Library/Preferences` a cada execução, porque o cfprefsd mantém o
  arquivo depois do `removePersistentDomain`.
  - Agora os nomes são fixos e diferentes por teste, e o `defer` remove o
    domínio, sincroniza com `CFPreferencesAppSynchronize` e apaga o plist.
  - O cfprefsd às vezes recria o plist vazio de forma assíncrona depois
    disso (em 1 de 3 execuções seguidas). Nada se acumula: sobram no máximo
    os mesmos 3 arquivos de nome fixo, reaproveitados a cada execução.
  - Os 18 plists que as primeiras execuções desta tarefa deixaram foram
    removidos.
- **Pendência para o C27:** o reset real do Xcode também deixa um
  `com.apple.dt.Xcode.plist` vazio, o que é inofensivo e equivale ao reset.
- **Pendências para o C17 e o C19:**
  - a confirmação de planos com risco de perigo ou atenção (primeira parte
    do AC5) e a exibição das restrições ficam no `CleanerViewModel`;
  - o bloqueio do R5 é um retrato tirado pelo ViewModel. O executor
    confere `isXcodeRunning` de novo logo antes de
    `reset-xcode-preferences` e `remove-xcode-user-data` e falha com
    `.blockedByRunningApp(.xcode)`;
  - `terminateSimulator()` devolve `false` tanto no prazo vencido quanto no
    cancelamento. O executor confere `Task.isCancelled` e reporta
    `.cancelled`, não uma falha ao fechar o Simulator;
  - o executor monta o resetter a partir do `domain` da operação
    `.resetPreferences(domain:)` do catálogo, que fica a única fonte do
    domínio.

## Adendo da implementação do C17 (2026-10-31)

- **`CleanupExecutor`** (`Core/Cleanup/Executor`, no main actor pelo
  isolamento padrão): `execute(_ plan: CleanupPlan, onEvent:) async ->
  CleanupReport`.
  - **Diverge da seção 5.3:** em vez de um
    `AsyncThrowingStream<CleanupEvent, Error>`, a API é estruturada e
    entrega os eventos (`closingSimulators`, `categoryStarted`,
    `itemFinished`, `restartingSimulatorService`) a `onEvent`, no ator de
    quem chama. É a mesma lição do B1 do C12: cancelar quem consome um
    stream perde o resultado em andamento. Aqui o `CleanerViewModel`
    (C19) cancela o próprio `Task`, e o executor devolve um relatório
    `cancelled` com tudo o que já foi liberado (R7/AC7).
  - **Ordem fixa (R10):**
    1. com alguma categoria `shutsDownSimulators`, fecha o Simulator.app e
       roda `simctl shutdown all` no set padrão;
    2. passos `simctl`: `erase all`, `delete unavailable` e, para cada set
       auxiliar existente (`DeviceSet.all(in:)`), `shutdown all` + `delete
       all`, seguidos das sobras nas raízes do catálogo;
    3. remoções de arquivo e reset de preferências, na ordem do catálogo;
    4. reinício do CoreSimulatorService só se uma categoria
       `restartsSimulatorService` (F24) removeu algo.
  - **Simulator e cancelamento:**
    - se o Simulator não fechar, ou o `shutdown all` falhar, só as
      categorias de simulador falham (`.blockedByRunningApp(.simulator)` ou
      o erro), e as outras rodam;
    - um cancelamento durante o fechamento vira relatório `cancelled`,
      nunca falha, e nenhum `shutdown all` roda depois dele.
  - **Pendências anteriores resolvidas:**
    - o executor reconfere `isXcodeRunning` antes de cada categoria
      `isBlockedWhileXcodeRuns` (`.blockedByRunningApp(.xcode)`);
    - monta o resetter a partir do `domain` da operação;
    - roda `knownUDIDs` antes do F19 (com falha na listagem, a categoria
      falha);
    - aplica `TemporaryItemsPolicy.softened` às duas categorias
      temporárias;
    - pula sets auxiliares inexistentes.
  - **Bytes liberados dos passos `simctl`:** diferença do alvo antes e
    depois (`erase all` mede `CoreSimulator/Devices`, os sets medem a
    própria pasta) ou soma dos simuladores indisponíveis listados antes
    (`delete unavailable`). O reset de preferências conta 0.
  - **AC10:** nenhuma raiz sai do catálogo, e um teste com o catálogo
    inteiro confirma que nada aponta para `/Library/Developer/CoreSimulator`.
- **Ajuste no `FileRemoving` (C12):** `onResult` deixou de ser `@Sendable`.
  O laço do remover roda na task e no ator de quem chama, e a listagem e o
  trabalho de cada item rodam em helpers `@concurrent`. Assim o executor
  coleta os resultados sem trava. O `filter` passou a ser `@escaping`.
- **Testes:** fakes com um registro de chamadas compartilhado validam a
  ordem global. A primeira execução dos testes do executor foi contra a
  implementação; o vermelho foi demonstrado com um esqueleto vazio
  (13 falhas) e com 10 mutações, todas pegas.
- **Correções da revisão:**
  - **B1:** depois que um passo `simctl` acontece, o resultado é sempre
    registrado, mesmo se a medição de depois for cancelada. Nesse caso o
    resultado leva 0 bytes, e o total liberado fica subestimado.
  - **B2:** no F23, uma raiz que é ou contém um set cujo `shutdown all` ou
    `delete all` falhou não tem as sobras removidas. Apagar um set vivo
    pelas costas do serviço é a causa (a) do "precisa reiniciar".
  - **B3:** o reinício do CoreSimulatorService também roda depois de um
    cancelamento, se o F24 já removeu algo, e não depende de
    cancelamento.
  - **B4:** um cancelamento engolido no último item da última categoria
    termina o relatório como `cancelled`. Isso fecha a exceção aceita no
    C15.
  - **N1:** o cancelamento durante a listagem dos indisponíveis para o
    passo. Uma falha comum da listagem só zera os bytes.
  - **N3:** uma execução já cancelada nem pede para o Simulator fechar.
  - **N2:** o teste do AC10 confere os caminhos completos entregues ao
    remover e ao `simctl`.
- **Decisões registradas:**
  - (pendência do C14) a decodificação do JSON do `simctl` e a varredura
    libproc do `restartService()` rodam no main actor, porque o executor
    está nele e esses métodos herdam o ator de quem chama. O custo é
    pequeno e fica aceito; marcar `@concurrent` só se a medição mostrar
    impacto;
  - (N7) pela verificação de cancelamento do `ProcessRunner` depois do fim
    do processo (C13), um `erase all` ou `delete all` que termina no exato
    momento do cancelamento aparece como não feito. O liberado pode ficar
    subestimado; validar no C27.
- **Pendência para o C27 (N8):** depois que as sobras do F23 removem o
  `device_set.plist` de `XCTestDevices` e `XCPGDevices`, as pastas
  continuam existindo e o F19 (`knownUDIDs` sobre `DeviceSet.all`) roda
  `simctl --set` nelas. Os dois vêm ligados por padrão. Confirmar ao vivo
  que o `simctl` aceita um set vazio; se não aceitar, o F19 falharia em
  toda limpeza padrão.
- **Pendências para o C19:**
  - a tag `failed_categories` do Sentry (limite de 200 caracteres) vai
    para `extra` quando o ViewModel transformar o relatório em
    `ReportableFailure`;
  - o `freed_bucket` do analytics passa a usar o `freedBytes` real do
    relatório;
  - o evento `cleaner` com `result = cancelled` sai do relatório
    `cancelled`.

## Adendo da implementação do C18 (2026-10-31)

- **`Core/Persistence`:**
  - `PreferencesStoring` distingue chave ausente, valor e valor ilegível
    (`StoredBool`). As extensões `bool(for:)`, `isSelected(_:)` e
    `setSelected(_:_:)` usam os IDs do catálogo, que já são as chaves
    legadas (R3).
  - `UserDefaultsPreferencesStore` lê e grava no formato legado (`Data`
    com JSON de `Bool`), então a 0.7 continua lendo o que a 1.0 grava.
    `preferences-schema-version` é um inteiro simples.
  - `PreferencesMigrator` (v1 → v2, uma vez só):
    - mantém todo valor salvo;
    - chave ausente ou ilegível recebe o padrão do catálogo (D5: Archives
      fica desligado para quem nunca mexeu);
    - `show-menu-bar-extra` vem ligado e
      `display-free-up-space-in-menu-bar` mantém a escolha, agora lida
      como "mostrar o tamanho";
    - `launch-at-login = true` com status `.notRegistered` chama
      `setEnabled(true)` uma vez. Uma falha volta em
      `Outcome.loginItemFailure` sem parar a migração;
    - a chave legada é mantida (B1 da revisão). A versão do esquema já
      garante que ela só é lida uma vez (R15), e voltar para a 0.7 preserva
      a escolha. Apagá-la faria a 0.7 ler "ausente" como `true` e registrar
      o item contra a escolha do usuário. Daí em diante a fonte de verdade
      é o `SMAppService`;
    - um `launch-at-login` ilegível entra na contagem de valores
      corrompidos (B2) e não registra;
    - **decisão:** chave ausente não registra. Quem atualiza já está
      registrado pelo LaunchAtLogin, que usa `SMAppService`, e uma
      instalação nova escolhe em Ajustes;
    - `Outcome.restoredCorruptedValueCount` serve para o breadcrumb sem
      a chave, que quem chama envia (C19/C22).
- **Diverge da seção 5.4 (superfície final):**
  - `PreferencesStoring` tem `schemaVersion` só de leitura,
    `storedValue(for:)`, `set(_:for:)`, `removeValue(for:)` e
    `setSchemaVersion(_:)`. `bool(for:)`, `isSelected(_:)` e
    `setSelected(_:_:)` são extensões;
  - `LoginItemManaging` ganhou `status` (`LoginItemStatus`: `enabled`,
    `notRegistered`, `requiresApproval`, `notFound`), que a migração usa,
    além de `isEnabled` e `setEnabled(_:)`.
- **`Core/Platform/LoginItemManaging`:** `MainAppLoginItem` sobre
  `SMAppService.mainApp` via `AppServiceControlling`, que o
  `SMAppService` adota. Os testes usam um serviço falso e nunca registram
  um item de login real. Os erros chegam como `CleanupError`; como os
  erros do `SMAppService` vêm de domínios próprios, quase sempre viram
  `.unknown(domain:code:)`. Revisar no C20, junto com a orientação para
  `.requiresApproval`.
- `removeValue(for:)` não tem mais uso em produção depois do B1. Fica no
  protocolo para os Ajustes (C20/C22) limparem chaves antigas.
- **Plists de teste:** como no C16, o cfprefsd às vezes recria de forma
  assíncrona um plist vazio depois da limpeza. Pode sobrar no máximo um
  arquivo vazio por suite de nome fixo, agora incluindo as do C18, e nada
  se acumula.
- **SKILLS_STATUS:** swiftui-expert-skill marcada como SKIPPED neste card,
  porque não há código SwiftUI no escopo.
- **Testes:** o migrador usa uma store em memória. Só os testes da
  `UserDefaultsPreferencesStore` e um teste ponta a ponta usam suites
  reais, com nomes fixos por teste e o helper `TestPreferencesDomain`, que
  remove domínio e plist. O vermelho foi demonstrado contra esqueletos, e
  8 mutações foram pegas.
- **Pendências:**
  - C19, C20 e C22: ligar a migração no início do app (antes de ler as
    preferências) e trocar `Preferences`/`StoragedValue` e o pacote
    LaunchAtLogin pelos tipos novos. A remoção do pacote fica no C24 (D4);
  - C27: validar o registro real em `/Applications` (AC15-live).

## Adendo da implementação do C19 (2026-10-31)

- **`Features/Cleaner`:**
  - `CleanerPhase` (fases da 2.4), `CleanupProgress` e `CategoryRowState`
    (`measuring`, `measured`, `empty`, `unavailable(.toolsUnavailable |
    .xcodeIsRunning)` e `failed`).
  - `CleanerViewModel` (`@Observable`, main actor) depende só de
    protocolos: `CleanupExecuting` (que o `CleanupExecutor` adota),
    `SimulatorManaging`, `PreferencesStoring`,
    `RunningApplicationsProviding`, `Analytics` e `ErrorReporting`.
  - `CleanupOutcomeReporter` reúne breadcrumbs, os eventos `cleaner` e
    `cleaner_partial_failure` e o único `ReportableFailure` agregado.
- **Medição (R1):**
  - `refresh()` cancela a medição anterior e usa uma geração, para que uma
    medição velha não sobrescreva o estado;
  - `windowDidActivate()` agrupa rajadas com debounce de 2 s e reaproveita
    uma medição de menos de 60 s;
  - o app mede de novo depois de cada limpeza, e não há polling;
  - antes de medir, lista os simuladores do set padrão (simuladores
    ativos e bytes dos indisponíveis) e os UDIDs de `DeviceSet.all(in:)`.
    Sem as ferramentas, as categorias com
    `CleanupOperation.needsSimulatorTools` (F8, F9, F23 e F19) ficam
    `unavailable(.toolsUnavailable)` e as outras funcionam (R12). Sem a
    lista de UDIDs, o F19 também fica indisponível;
  - as duas categorias temporárias são medidas com os filtros do C15.
- **Total e botão (R2):**
  - `totalBytes` soma as categorias selecionadas e disponíveis já medidas;
  - `canClean` só vale em `.ready`;
  - **diverge do R2:** um reset de preferências selecionado sozinho (0
    bytes) ainda permite limpar, porque ele não libera espaço mas é uma
    ação;
  - o texto "Limpar <tamanho>" e o rótulo "estimado" ficam na view (C20).
- **Confirmação e restrições (R5):**
  - `requestClean()` reconfere o Xcode, e as categorias bloqueadas saem
    do plano e viram indisponíveis;
  - um plano com risco de atenção ou perigo vai para `.confirming(plan)`
    e roda em `confirm()`;
  - `cancel()` na confirmação volta ao estado ocioso;
  - os avisos ficam em `restrictions.warnings`.
- **Execução e relatório (R6/R7):**
  - `cancel()` durante a limpeza vai para `.cancelling` e cancela o
    `Task` da execução, e o executor devolve o relatório `cancelled`
    (C17);
  - o relatório fica em `.finished` até `dismissReport()`, sem timers;
  - uma falha de permissão (sem cancelamento) leva a
    `.permissionDenied(report)` (R13);
  - `retryFailed()` roda só as categorias que falharam, sem nova
    confirmação.
- **Pendências anteriores fechadas:**
  - o `freed_bucket` usa o `freedBytes` real do relatório;
  - o evento `cleaner` sai com `result = cancelled`;
  - a tag `failed_categories` foi para `extras` do `ReportableFailure`
    (o Sentry grava em `setExtra`), por causa do limite de 200 caracteres
    das tags.
- **Correções da revisão:**
  - **B1:** `windowDidActivate()` não faz nada durante uma medição nem com
    a fase em confirmação, limpeza ou cancelamento (a tarefa da ativação
    confere de novo depois do debounce). `run()` cancela a ativação e a
    medição pendentes antes de executar, e a medição pós-limpeza atualiza
    tudo.
  - **B2:** `requestClean()` relê o Simulator.app (e os simuladores
    ligados da última listagem) junto com o Xcode e pede confirmação
    quando alguma categoria do plano tem aviso de app aberto, além de
    atenção ou perigo (F31, fluxo 2.3).
  - **B3:** se o Xcode fechou desde a medição, as categorias que ele
    bloqueava voltam por uma nova medição antes de montar o plano.
  - **B4 (amplia o R12):** sem as ferramentas, as categorias
    `shutsDownSimulators` também ficam indisponíveis, porque o F24 não
    pode rodar sem o `shutdown all` (R10).
  - **B5:** testes novos cobrem a medição substituída (a geração é tirada
    em `refresh()`, antes da nova tarefa, para que a antiga nunca encerre
    o estado da nova; a ordem em que a tarefa antiga retoma não é
    reproduzível em teste, então a garantia vem da construção), a
    re-medição (`measuring(first: false)`), a falha comum da listagem no
    F9, a falha de um set auxiliar só no F19, simulador ligado como ativo
    e o relatório de falha total.
- **Re-revisão:**
  - **B1 residual:** a tarefa da ativação confere de novo, depois do
    debounce, que nenhuma medição começou e que o cache venceu. Assim a
    medição do lançamento não é jogada fora pela ativação simultânea, e
    uma medição que terminou durante a pausa é reaproveitada.
  - **N10:** sem a lista de simuladores (falha comum da listagem ou de um
    set auxiliar), o F19 fica `unavailable(.simulatorListUnavailable)`, e
    não `toolsUnavailable`.
  - **N11:** `refresh()` também não roda com a fase em confirmação,
    limpeza ou cancelamento.
  - **N13 (pendência para o C20):** `isMeasuring` só vira `true` quando a
    tarefa de medição começa a rodar. Uma ativação que acorde exatamente
    nesse intervalo do main actor ainda poderia medir de novo; marcar
    `isMeasuring = true` dentro de `refresh()` fecha a janela.
  - **N12 (aceita):** `retryFailed()` não pede nova confirmação, mesmo que
    surja um aviso de simulador depois da primeira execução, porque tentar
    de novo é uma ação explícita do usuário.
- **NITs aplicadas e registradas:**
  - `trashBoundCategoryIDs` expõe as categorias que vão para a Lixeira,
    para o aviso fixo e a confirmação (N1);
  - o progresso separa bytes liberados e movidos para a Lixeira (N2);
  - o set padrão é listado uma vez, e seus UDIDs são reaproveitados (N3,
    `SimulatorSnapshotReader`);
  - `measurementCount` e `isMeasuring` não são observados (N4);
  - `CategoryRowState` e `CleanupProgress` ganharam arquivos próprios
    (N5);
  - a exceção do reset no R2 precisa do aval do dono, e o C20 decide o
    texto do botão para 0 B (N6);
  - o teste de debounce ainda espera 100 ms reais; trocar por um `Clock`
    injetável fica como melhoria (N7);
  - `retryFailed()` reconfere o Xcode (N8);
  - se o C20 chamar `refresh()`/`windowDidActivate()` a partir de
    `.task`, o cancelamento dela não chega às tarefas internas; avaliar
    `withTaskCancellationHandler` lá (N9).
- **Pendências para o C20:**
  - ligar o ViewModel e a `PreferencesMigrator` no `AppContainer` (antes
    de ler as seleções);
  - trocar o `CleanerStore`/`Preferences` antigos;
  - chamar `windowDidActivate()` na ativação da janela;
  - mostrar os avisos e a ação para os Ajustes no `permissionDenied`.

## Adendo da implementação do C20 (2026-10-31)

- **Cena:** `Window("CleanerXcode", id: "main")`, 560×720 por padrão e
  480×560 no mínimo, `windowResizability(.contentMinSize)` e
  `defaultLaunchBehavior(.presented)`. A janela aparece no lançamento
  (conferido abrindo o build Debug com serviços inertes: uma janela de nível 0
  na tela), então não foi preciso trocar para `WindowGroup`. No test host a
  cena usa `.suppressed`, para os testes não gravarem o frame da janela no
  domínio real do app. `INFOPLIST_KEY_LSUIElement` saiu dos dois configs.
- **Composição:** `AppContainer.makeCleanerViewModel` roda a
  `PreferencesMigrator` antes de o ViewModel ler a seleção e monta scanner,
  `simctl`, remover e executor reais. Test host e previews recebem
  `CleanupLocations.inert` (raízes sob `/var/empty/CleanerXcode-inert`, que
  não existe), `InertDiskUsageScanner`, `InertSimulatorManager`,
  `InertCleanupExecutor` e `InertRunningApplications`, sem migração: nada lê as
  pastas deste Mac, roda `simctl` ou toca no item de login (revisão B1: antes
  as pastas temporárias reais ainda eram lidas pelo medidor filtrado).
- **Interface (Figma, página 03):**
  - toolbar com Atualizar (desabilitado fora de `allowsMeasurement`) e
    `SettingsLink`, desenhados em glass pelo sistema;
  - hero em `glassEffect(.regular)` (fundo sólido com Reduzir transparência),
    ações num `GlassEffectContainer` com `.glassProminent`/`.glass`;
  - lista agrupada sem glass (Xcode, Simuladores, Temporários, Dados do
    usuário e reset), risco crescente dentro de cada seção, seções
    recolhíveis com estado salvo por seção (`@AppStorage`);
  - avisos de Xcode aberto, Simulator aberto, ferramentas indisponíveis,
    permissão negada e itens que vão para a Lixeira;
  - sheet de confirmação com risco e destino (Lixeira, Definitivo,
    Redefinir); fechar a sheet só cancela enquanto ainda é confirmação;
  - relatório no hero, com "Detalhes" mostrando os itens que falharam;
  - rodapé com a versão e "Atualizar para X" quando há versão nova;
  - `#Preview` de cada estado com um ViewModel real e fakes
    (`CleanerWindowPreview`, só em DEBUG; ausente do binário Release).
- **Lógica nova, com TDD:** `CleanerSection.grouping`, `CategoryPresentation`,
  `HeroContent` (ações e números por fase), `CleanupReport.finishedCategoryCount`,
  `foundBytes`, `measuredCategoryCount`, `selectedBytes(of:)`,
  `areSimulatorToolsUnavailable`, `canToggle` (seleção congelada durante
  confirmação e limpeza) e `CleanupRestrictions.isXcodeRunning`/
  `areSimulatorsActive`.
- **N13 aplicada:** `refresh()` marca `isMeasuring` antes de a tarefa começar
  (teste `aRefreshCountsAsMeasuringBeforeItsTaskStarts`).
- **N6 decidida:** um plano sem bytes (só o reset) mostra "Limpar", sem
  tamanho.
- **N9 aceita:** a ativação usa `onChange(of: appearsActive)`, não `.task`;
  uma medição que continua depois de a janela fechar só atualiza o cache.
- **Strings:** 120 chaves novas com pt-BR (29 → 149) no `Localizable.xcstrings`; as três
  frases com contagem usam variação de plural em en e pt-BR. A revisão de
  textos e truncamento fica no C25.
- **Validação:** lint, testes e build Release (números finais na linha do C20
  no `PROJECT_GUIDE`). O dono recusou o acesso de tela, então as capturas
  (AC30b) foram feitas renderizando os `#Preview` fora da tela (harness
  temporário com `NSHostingView.cacheDisplay`, 18 estados em Light, Dark e
  Reduzir transparência, mais as duas sheets) e enviadas ao dono. Glass e
  estilos de botão não aparecem nesse método; o aspecto real fica para o
  C27. As capturas mostraram que o reset exibia "Zero KB"; agora mostra "—".
- **Revisão (Manager):** B1 (locais inertes), B2 (preview de confirmação
  parava em sucesso; preview de "cancelando" adicionado) e B3 (a sheet agora
  mostra o aviso de app aberto em cada item e muda a introdução quando o plano
  só pede confirmação por app aberto). NITs aplicados: N1 (contagem), N3
  (símbolo de sucesso só em sucesso, testado), N7 (nome do teste de migração).
  NITs registrados: N2 (plurais "1 de 1" e textos do Figma, C25), N4 (contar
  as categorias do plano no relatório, C25), N5 (Detalhes no
  `permissionDenied`; as linhas já mostram as falhas), N6 (ordem do TDD do
  `HeroContent`, vermelho mostrado por mutação), N9 (ajustes pequenos de
  SwiftUI).
- **Pendências:**
  - C21: a linha "Gerenciar simuladores" e a ação "Encerrar agora";
  - C22: `MenuBarExtra(isInserted:)`, a regra de fechar a última janela (AC14),
    a nova cena `Settings` (hoje hospeda a `PreferencesView` antiga), o botão
    "Apoiar o projeto" do rodapé e o texto da idade mínima na Pasta temporária;
  - C22/C24: o `MenuBarExtra` antigo (`CleanerStore`, `Preferences`,
    scripts) continua até o C22 e convive com a nova janela; os dois gravam as
    mesmas chaves de seleção sem sincronizar em memória (revisão N8). O C24
    remove `CleanerStore`, `Preferences`, `Shell`, `MainView`, `Route` e o
    pacote LaunchAtLogin;
  - C25: revisão de strings, truncamento em en e VoiceOver real.

## Adendo da implementação do C21 (2026-10-31)

- **`SimulatorsViewModel`:**
  - fases `idle`, `loading`, `loaded`, `empty`, `toolsUnavailable`,
    `failed` e `deleting(ids)`;
  - `load` lista o set padrão e os runtimes juntos;
  - `selectDuplicates` só pré-seleciona os duplicados do
    `DuplicateSimulatorDetector` (o mais recente fica);
  - `requestDeleteSelected` e `requestDeleteRuntime` abrem a confirmação,
    e um runtime com `deletable == false` não pede nada;
  - `confirm` apaga os UDIDs exatos ou o runtime, recarrega as listas (a
    seleção mantém só os que ainda existem) e chama `onDeleted`, que faz a
    janela medir de novo;
  - analytics só em sucesso: `simulator_deleted` com `reason` `duplicate`
    (todos eram sugeridos) ou `manual`, e `runtime_deleted`;
  - uma falha fica em `lastFailure`.
- **Interface:**
  - seção recolhível "Gerenciar simuladores" no fim da lista, recolhida por
    padrão (`@AppStorage`); expandir carrega (fluxo 2.3);
  - simuladores com nome, runtime, estado, último uso, etiqueta de
    duplicado e tamanho, com "Selecionar duplicados (n)" e "Remover n
    simuladores" num `GlassEffectContainer`;
  - runtimes com build, quantos simuladores dependem, último uso, tamanho e
    Remover (desabilitado para os incluídos no Xcode);
  - sheet de perigo para simuladores e para runtime (os dependentes também
    são apagados e o runtime terá de ser baixado de novo);
  - estados de carregando, vazio, ferramentas ausentes e falha;
  - nada aqui apaga enquanto uma limpeza roda, e o hero fica desabilitado
    enquanto simuladores ou um runtime são apagados;
  - o cabeçalho recolhível virou `CollapsibleSectionHeader`, também usado
    pelas seções do C20.
- **Composição:** `AppContainer.makeSimulatorsViewModel`, com
  `SimctlSimulatorService` em produção e `InertSimulatorManager` no test host
  e nas previews.
- **TDD:** vermelho com esqueletos (`SimulatorsViewModelTests`,
  `SimulatorPresentationTests`, `AppContainerTests`), depois verde.
- **Prints:** os estados foram renderizados fora da tela, como no C20, e
  enviados ao dono. Ajustes que saíram deles: "Remover simuladores" sem
  número quando nada está selecionado, "em uso agora" para simulador ligado
  e datas relativas numéricas.
- **Revisão (Manager), correções:**
  - B1: não há prova de que `simctl runtime delete` apague os simuladores do
    runtime (a ajuda só fala em desligar os ligados e desmontar a imagem).
    Agora o ViewModel apaga antes os dependentes pelos UDIDs exatos
    (shutdown e depois delete) e só então o runtime. Se essa etapa falha, o
    runtime fica. Quando outra imagem atende o mesmo `runtimeIdentifier`, os
    simuladores ficam e a confirmação diz só que o runtime terá de ser
    baixado de novo. O spy não apaga mais simuladores no `runtime delete`.
  - B2: a preview "vazio" mostra o estado vazio de verdade; as previews
    abrem a seção expandida (`isInitiallyCollapsed`); há previews das duas
    confirmações e do Dark.
  - B3: "Tentar de novo" nos estados de falha, ferramentas ausentes e vazio;
    expandir recarrega nesses estados; o Atualizar da toolbar recarrega a
    seção já aberta (`reloadIfOpened`). Antes de apagar, a lista é lida de
    novo e o estado atual de cada simulador é usado, então um simulador
    ligado depois do carregamento ainda é desligado antes.
  - B4: testes do estado `deleting` (UDIDs e runtime), das travas durante a
    exclusão e das falhas de cada etapa da exclusão do runtime.
  - B5: "Encerrar agora" no aviso de Simulator aberto
    (`CleanerViewModel.shutDownSimulators`: fecha o Simulator.app, roda
    `shutdown all` e mede de novo; testado).
  - Decisões pendentes do C14:
    - a decodificação do JSON do `simctl` roda no main actor (listas de
      dezenas de itens); sem medição de custo ainda, fica como está e o C27
      confere com Instruments;
    - o aviso de instalar as Command Line Tools que o shim `xcrun` pode
      abrir fica para a validação real do C27.
  - NITs aplicados: N1 (`sheet(item:)`, a sheet não fica vazia ao fechar), N3
    (sem "0 duplicados"), N5 (rótulo de acessibilidade do Remover com o nome
    do runtime).
  - NITs registrados:
    - N2: frases com zero ou um (C25);
    - N4 e N5: tipo do aparelho no VoiceOver, simuladores indisponíveis e
      estados `Deleting`/`Unusable` dos runtimes (C25);
    - N6: preview do aviso "Não foi possível apagar" e texto grande (C25);
    - N7: `unreadableOutput` desta seção não vai para o error reporter (C25).
  - Decisões que se afastam do Figma ou do texto do plano:
    - N8: o `reason` é `duplicate` sempre que todos os selecionados eram
      duplicados sugeridos, mesmo marcados à mão;
    - N9: Simuladores e Runtimes ficam dentro de "Gerenciar simuladores", e o
      runtime incluído no Xcode mostra Remover desabilitado (R9);
    - N9: o rótulo é "Selecionar duplicados (n)", como no Figma, no lugar de
      "Remover duplicados (n)";
    - N9: só os simuladores ligados são desligados (R8), não um `shutdown all`
      antes de toda operação (R10).
  - N10: o `MenuBarExtra` antigo ainda pode limpar enquanto simuladores são
    apagados (sai no C22/C24); no C22, abrir a janela já na confirmação não
    pode empilhar duas sheets.
- **Revisão, 2ª rodada:**
  - B6: uma listagem do Atualizar que termina durante uma exclusão
    sobrescrevia a lista e voltava a fase para `loaded`, reabilitando o hero
    no meio da exclusão. Agora cada listagem tem uma geração, a exclusão
    invalida as anteriores e uma listagem velha é descartada (teste
    `aRefreshThatEndsDuringADeletionIsDiscarded`, vermelho sem a guarda);
  - N11 aplicada: "Encerrar agora" fica desabilitado enquanto simuladores
    são apagados;
  - N12: apagar um runtime também apaga os simuladores dependentes, mas só
    registra `runtime_deleted`, como na tabela de analytics;
  - N13: a contagem "N simuladores dependem" da linha conta todos do
    runtime, enquanto a confirmação usa a regra da imagem gêmea.
- **Validação:** lint sem violações (189 arquivos), 370 execuções de teste
  passando e build Release OK.
- **Pendência:** duas execuções completas do C21 deixaram plists dos domínios
  de teste em `~/Library/Preferences`: a corrida do `cfprefsd` com o
  `TestPreferencesDomain.remove`. Foram removidos; tornar a limpeza confiável
  fica para o C27.

## Adendo da implementação do C22 (2026-10-31)

- **`SettingsViewModel`:**
  - abrir no login via `LoginItemManaging` (o `SMAppService` é a fonte de
    verdade; depois de uma falha mostra o status real e a falha; o
    `requiresApproval` mostra o caminho para Itens de Início, com um botão
    que abre o painel);
  - mostrar na barra de menus (`show-menu-bar-extra`);
  - mostrar o tamanho (`display-free-up-space-in-menu-bar`);
  - idade mínima da pasta temporária (`temporary-minimum-age-days`, inteiro
    no store; só 1, 3, 7 e 14, senão 3);
  - "Enviar estatísticas de uso" (`send-anonymous-analytics`, texto de dado
    pseudônimo, sem `Himetrica.reset()`);
  - eventos `donate` e `social`.
- **`PreferencesStoring`** ganhou `integer(for:)` e `set(_: Int, for:)`.
- **Cena `Settings`** com `TabView` (Geral e Sobre), conforme a página 04
  do Figma. O Sobre tem versão, atualização, apoio, links (GitHub, X,
  LinkedIn) e a dedicatória, com a chave antiga já traduzida.
- **Barra de menus:**
  - `MenuBarExtra(isInserted:)` ligado à preferência; tirar o item da
    barra desliga a preferência;
  - rótulo com o tamanho (`MenuBarPresentation.label`: nada até a primeira
    medição, "Limpando…" durante a limpeza);
  - painel com eyebrow, valor, a ação principal, Ajustes, "Abrir
    CleanerXcode" e Sair;
  - com plano que pede confirmação (`cleanNeedsConfirmation`), o botão vira
    "Revisar e limpar…", abre a janela e chama `requestClean`, então a
    confirmação aparece só na janela e nunca empilha duas sheets.
- **Fechar a última janela:** um `AppDelegate`
  (`applicationShouldTerminateAfterLastWindowClosed`) encerra o app só com
  a barra de menus desligada (`MenuBarPresentation.quitsAfterLastWindowClosed`).
- **Idade mínima:**
  - mudar a idade nos Ajustes chega ao `CleanerViewModel`
    (`setMinimumTemporaryAgeInDays`: troca a política, invalida o cache e
    mede de novo) e aos próximos planos;
  - o app abre com a idade salva;
  - a linha da Pasta temporária mostra o aviso fixo "Feche apps de IA e
    terminais antes · itens com menos de N dias são preservados"
    (pendência do C15).
- **Analytics:** o adaptador do Himetrica lê a chave pelo store a cada
  evento, então o switch vale na hora.
- **Rodapé:** "Apoie o projeto" (abre a página de doação e registra
  `donate`).
- **App:**
  - a cena deixou de usar `CleanerStore`, `Preferences`, `Route`,
    `AnalyticsTracker` e o pacote LaunchAtLogin, que o C24 apaga;
  - `checkUpdates` roda na `.task` da janela, fora de testes e previews.
- **Test host:** o item da barra continua inserido, como antes. Escondê-lo
  gravava `NSStatusItem VisibleCC Item-0 = 0` no domínio real do app, o que
  poderia esconder o item no app de verdade. A chave foi removida e o
  domínio fica vazio depois dos testes.
- **TDD:** vermelho com esqueletos (`SettingsViewModelTests`,
  `MenuBarPresentationTests` e os testes novos do `CleanerViewModel`), depois
  verde.
- **Prints:** Geral, Geral com aprovação pendente, Sobre e o painel (pronto,
  revisar, limpando, falha parcial), renderizados fora da tela e enviados ao
  dono.
- **Revisão (Manager), correções:**
  - B1: o painel recebe `isDeletingSimulators`; Limpar e Tentar de novo
    ficam desabilitados enquanto simuladores ou um runtime são apagados
    (`MenuBarPresentation.isEnabled`, testado; preview "deleting
    simulators").
  - B2: depois de `requestClean`/`retryFailed`, se a fase ficou
    `.confirming` (um app abriu desde a última medição), o painel abre a
    janela (`MenuBarPresentation.needsMainWindow`, testado). Abrir o painel
    chama `windowDidActivate()`, que respeita o debounce e o cache e atualiza
    as restrições (N4).
  - B3: mudar a idade com uma confirmação aberta refaz o plano com a idade
    nova (teste `aNewMinimumAgeChangesThePlanBeingConfirmed`: o executor
    recebe 14 dias).
  - B4: previews do painel (pronto, medindo, revisar na janela, limpando,
    sucesso, falha parcial, permissão negada, simuladores sendo apagados) e
    do rótulo, com fábricas em `MenuBarPanelPreview.swift`; os prints foram
    refeitos a partir delas.
  - B5: o teste do container só confere o tipo (`loginItem is
    InertLoginItem`) e nunca exercita um login item construído pela fábrica.
  - B6: o resultado da migração vai para o Sentry como breadcrumb, sem a
    chave: `preferences_restored` quando valores corrompidos voltam ao padrão
    e `login_item_migration_failed` quando o "abrir no login" legado não pôde
    ser registrado (testado com spy).
  - B7: um register que termina em `requiresApproval` mostra só a
    orientação, sem a falha genérica; com aprovação pendente o switch aparece
    ligado, para poder desligar (N12). Os erros do `SMAppService` continuam
    genéricos ("Erro desconhecido"), por decisão.
  - B8, o que não foi visto rodando (o dono recusou o acesso de tela) e fica
    para o C27, no AC14:
    - o item da barra entrar e sair quando o switch muda;
    - tirar o item com Cmd-arrastar desligar o switch;
    - a regra de fechar a última janela com a barra ligada e desligada.
    No macOS 26 o item da barra pertence ao Control Center, então a lista
    de janelas do processo só mostra a janela principal (conferido num
    lançamento Debug com serviços inertes).
  - NITs aplicados: N1 (comentários), N2 (MARKs e posição da propriedade),
    N3 (texto genérico do painel), N4, N5 (test host com `.constant(true)`),
    N6 (`.cleaning` no teste do rótulo), N7 (rótulo de acessibilidade do
    ícone).
  - NITs registrados:
    - N8: `integer(for:)` aceita NSNumber, e o filtro de opções cobre isso;
    - N9: a fila offline do SDK pode enviar eventos já enfileirados (README,
      C29);
    - N10: preview de "atualização disponível" no C23;
    - N11: o `SettingsLink` do painel pode abrir os Ajustes atrás de outros
      apps (C27).
- **Revisão, 2ª rodada:** aprovada. NITs registrados:
  - R2-N1: a categoria dos breadcrumbs continua "cleanup";
  - R2-N2: desligar com aprovação pendente e falha no `unregister` não
    mostra a falha;
  - R2-N3: o painel não explica por que o botão fica desabilitado durante a
    exclusão de simuladores (C25);
  - R2-N4: os tipos de preview aninhados seguem o padrão do C20.
- **Validação:** lint sem violações (199 arquivos), 389 execuções de teste
  passando e build Release OK. O domínio real do app fica vazio depois dos
  testes. Plists de teste vazaram de novo (pendência do C27) e foram
  removidos.
- **Pendências:**
  - C24: remover os arquivos antigos (`CleanerStore`, `Preferences`,
    `MainView`, `CleanerView`, `PreferencesView`, `Route`,
    `AnalyticsTracker`, `Components`), o `Shell` e o pacote LaunchAtLogin;
  - C25: textos e truncamento;
  - C27:
    - o login item real em /Applications (AC15-live);
    - AC14: o item da barra entrar e sair com o switch;
    - AC14: tirar o item com Cmd-arrastar desligar o switch;
    - AC14: fechar a última janela com a barra ligada (o app continua) e
      desligada (o app encerra);
    - o `SettingsLink` do painel trazer os Ajustes para a frente (N11);
  - C31: a sugestão de doação a cada 3 limpezas.

## Adendo da implementação do C23 (2026-10-31)

- **`SemanticVersion`:**
  - compara por componente numérico; componente ausente conta zero;
  - o build desempata;
  - versão ou build que não sejam números dão `nil`;
  - corrige a conversão antiga, que juntava os dígitos: `1.0.0` e `0.10.0`
    davam 100 (iguais) e `1.0.0` ficava menor que `0.11.0` (110).
- **`RemoteVersionChecker`:** lê o `version.json` (`VERSION_FILE_URL` da
  `AppConfiguration`) com timeout de 10 s e sem cache local. Status fora de
  2xx dá `badResponse`, e sem URL dá `notConfigured`. O
  `InertVersionChecker` atende o test host e as previews.
- **`UpdateViewModel`** (substitui o `UpdateStore` na interface nova):
  - `availableUpdate` só quando o remoto é mais novo (versão e build);
  - qualquer falha fica em silêncio e vira o breadcrumb `update_check_failed`;
  - `logUpdateOpened()` registra `update_opened`;
  - o botão "Atualizar para X" do rodapé e da aba Sobre abre o DMG e
    registra o evento.
- **Composição:** `AppContainer.makeUpdateViewModel`. A versão e o build
  atuais vêm da `AppConfiguration`; a checagem roda na `.task` da janela.
- **Previews:** `UpdatePreview` (com e sem versão nova); preview "About ·
  update available" (o N10 do C22).
- **TDD:** vermelho com esqueletos (`SemanticVersionTests`,
  `RemoteVersionCheckerTests` com um `URLProtocol` stub numa sessão
  efêmera, sem rede; `UpdateViewModelTests`; o teste do container), depois
  verde.
- **Prints:** a aba Sobre e o rodapé com atualização, enviados ao dono.
- **Validação:** lint sem violações (206 arquivos), 405 execuções de teste
  passando e build Release OK. Na primeira rodada vazaram plists de teste
  (pendência do C27), que foram removidos; na última, nenhum. Revisão aprovada
  na 2ª rodada; N10 (manter a atualização já achada depois de um check
  cancelado, sem teste) registrado.
- **Revisão (Manager), correções:**
  - B1: um check cancelado (`CancellationError` ou `URLError(.cancelled)`,
    como ao fechar a janela) não deixa breadcrumb (testado).
  - B2: o `URLProtocol` stub perdeu o `@unchecked Sendable`, que não era
    necessário.
  - NITs aplicados: N1 (exemplo correto da conversão antiga), N2 (o
    container usa o checker remoto no app e o inerte nas previews, testado),
    N3 (só dígitos ASCII, sem sinal; apara quebras de linha), N5 (o stub
    falha em vez de travar até o timeout; uma URL só).
  - NITs registrados:
    - N4: versão remota ilegível fica em silêncio, sem breadcrumb;
    - N6: a política de cache não é testada;
    - N7: o timeout de recurso continua o padrão do `URLSession.shared`;
    - N8: não há preview do rodapé com atualização;
    - N9: a categoria dos breadcrumbs continua "cleanup".
- **Pendência para o C24:** o `UpdateStore`, o `ApplicationInfo` e os
  testes deles só servem à `CleanerView` antiga e saem com ela.

## Adendo da implementação do C24 (2026-10-31)

- **Apagados (seção 5.6):**
  - `Shell`, `CommandExecutor`, `Command`, `InertCommandExecutor` e
    `Resources/Scripts/*.sh`;
  - os scripts de teste (`Tests/Support/Scripts/*.sh`), `ShellTests`,
    `CommandExecutorTests`, `CommandTests` e `CommandExecutorStub`;
  - `StoragedValue`, `Preference+Extension`, `String+ErrorExtension` e
    `Route`;
  - `Components/` (`ExpandableButton`, `HighlightButton`,
    `CustomCircularProgressViewStyle`, `ScrollContentHeightModifier`).
- **Também apagado:** a interface antiga que a janela do C20 substituiu, com
  os testes dela:
  - `MainView`, `CleanerView` (`import Charts`), `CleanerStore`,
    `PreferencesView` (`import TipKit` e `LaunchAtLogin`);
  - `Preferences`, `UpdateStore`, `ApplicationInfo`, `AnalyticsTracker`,
    `StateValue`, `UsedSpace`;
  - `Int+Extension`, `Double+Formatter`, `Data+Decoder`;
  - os helpers de teste `Person` e `TestImprovements`.
- **Mantido do `Bundle+Extension`:** só `version` e `build`. A URL do
  `version.json` vem da `AppConfiguration`.
- **`AppServices`:** perdeu `commandExecutor` e `preferences`; os testes do
  container foram ajustados.
- **Dependências (D4):** `swift-timeout` e `LaunchAtLogin-Modern` saíram do
  pbxproj (41 linhas, só os objetos desses pacotes; as alterações locais
  preservadas continuam intactas) e do `Package.resolved`. A resolução não
  precisa mais de SSH ao GitHub. O Release só embute o `Sentry.framework`.
- **AC24:**
  - `grep` em `CleanerXcode`, `CleanerXcode.xcodeproj` e `Tests` sem
    `/bin/bash`, `.sh`, `Shell`, `CommandExecutor` nem os imports `Timeout`,
    `Charts`, `TipKit` e `LaunchAtLogin`;
  - os nomes `setLaunchAtLogin` e `legacyLaunchAtLoginKey` são do app, não do
    pacote;
  - os testes do `ProcessRunner` ainda rodam `/bin/echo` e `/bin/sh` como
    processos inofensivos de teste; o app só roda `/usr/bin/xcrun`;
  - o bundle Release não tem nenhum `.sh`;
  - os scripts de ferramenta (`scripts/lint-swift.sh` e `.ai/shared/`) não
    são do app e ficam.
- **Docs:** o `PROJECT_GUIDE` foi atualizado nas seções de dependências,
  nível mínimo, arquitetura, estado e concorrência, regras, previews e
  testes; o mapa de código do `PROJECT_BRIEF` perdeu as linhas do código
  antigo. A descrição de produto do brief continua a do 0.7 e é reescrita no
  C29.
- **Validação:** lint sem violações (171 arquivos), 368 execuções de teste
  passando (saíram os 37 testes do código antigo) e build Release OK. O
  domínio real do app fica vazio depois dos testes. Plists de teste vazaram
  (pendência do C27) e foram removidos.
- **Revisão (Manager), correções:**
  - B1: `xcodebuild -resolvePackageDependencies -project CleanerXcode.xcodeproj
    -scheme CleanerXcode` resolveu só Himetrica 1.0.0 (`b62348e`) e Sentry
    9.32.0 (`4e1e4ba`), sem SSH. O Xcode não reescreveu o `Package.resolved`
    (o `originHash` ficou o mesmo) e nenhum outro arquivo mudou.
  - NITs aplicados:
    - N1: o guia não cita mais `Charts`, `TipKit`, `StateValue`, os scripts
      de teste nem o `waitUntil`;
    - N2: o brief marca como resolvidas a falha visível, o encerramento do
      processo e o fork `LaunchAtLogin`;
    - N4: saíram o `Bundle.test`, a cor `greenAction` e os símbolos sociais;
    - N6: o teste virou `whenRunningTestsTheSDKsStayOff`, sem `async throws`;
    - N7: o `Bundle+Extension` importa só `Foundation`.
  - NITs registrados:
    - N3: o README ainda credita LaunchAtLogin e swift-timeout (C29);
    - N5: chaves de texto das Views antigas no `Localizable.xcstrings` (C25).

## Adendo da implementação do C25 (2026-10-31)

- **Strings:**
  - auditoria do `Localizable.xcstrings` contra as chaves que o build extrai
    (`.stringsdata`): 23 chaves das Views antigas removidas (N5 do C24);
  - nenhuma chave faltando, e todas com pt-BR (198 chaves depois da revisão);
  - as frases com contagem têm plural em en e pt-BR;
  - a ação destrutiva usa os textos aprovados ("Limpar", "Apagar", "Apagar
    runtime", destino Lixeira, Definitivo ou Redefinir).
- **VoiceOver:**
  - o símbolo da linha do simulador leva o tipo do aparelho como rótulo só
    quando o nome difere (`SimulatorPresentation.spokenType`, testado), então
    um simulador renomeado continua identificável;
  - simulador sem runtime aparece como "indisponível";
  - runtime em estado diferente de "Ready" (`Deleting`, `Unusable`) mostra o
    estado;
  - o painel explica por que o botão fica desabilitado durante uma exclusão
    ("Aguarde enquanto simuladores ou um runtime são apagados.", R2-N3 do
    C22);
  - a varredura das Views não achou `Image` sem rótulo nem
    `accessibilityHidden` fora de `Label`.
- **Aumentar contraste:** as etiquetas de risco, de duplicado e os avisos
  mantêm o fundo e ganham borda na cor com `colorSchemeContrast ==
  .increased` (`BadgeStyle`). Não há preview de contraste: o ambiente é só
  de leitura.
- **Previews:**
  - previews próprios para as duas sheets de confirmação, os itens que
    falharam, os avisos (inclusive durante a exclusão de simuladores), o
    rodapé (com e sem atualização) e o cabeçalho recolhível;
  - Reduzir transparência, Light e Dark já existiam; as previews de texto
    grande saem idênticas às normais no macOS, e a conferência real fica no
    C27;
  - nenhuma preview usa `Bundle.main` nem serviços reais.
- **Prints:** o painel bloqueado, o aviso, a sheet de runtime, "Não foi
  possível apagar", os estados incomuns de simulador e runtime e a
  comparação de texto grande, enviados ao dono.
- **Validação:** lint sem violações (173 arquivos), 376 execuções de teste
  passando e build Release OK; a auditoria de strings dá 198 chaves, sem
  nenhuma sobrando ou faltando, em Debug e Release. O domínio real fica
  vazio. Plists de teste vazaram (pendência do C27) e foram removidos.
- **Revisão (Manager), correções:**
  - B1: forma `zero` em en e pt-BR para as contagens que chegam a zero
    ("nenhum simulador depende dele", "nenhuma categoria concluída antes de
    cancelar", "nenhuma categoria limpa", "nenhum runtime", "nenhum
    simulador", "nenhum duplicado"). Em português o 0 cairia em "one".
    Testado resolvendo as strings do bundle em pt-BR e en
    (`LocalizedPluralTests`).
  - B2: estados do `simctl` traduzidos (`SimulatorPresentation`:
    `runtimeStateText` para Deleting e Unusable; `deviceStateText` para
    ligado, desligado, indisponível, Booting, Shutting Down e Creating); os
    desconhecidos ficam como vêm. Testado.
  - B3: a escolha do texto do painel foi para
    `MenuBarPresentation.panelDetail` (testado); o bloqueio só aparece quando
    o botão estaria habilitado e cita simuladores ou runtime (N3).
  - B4: as previews da sheet de simuladores usam o
    `SimulatorsConfirmationPreview` com `@State` e conteúdo sempre presente;
    renderizadas. As previews dos avisos ganharam conteúdo sempre presente.
    O preparo das previews de simuladores espera a lista carregar, porque a
    seção também carrega ao expandir.
  - B5: com Aumentar contraste o fundo fica o mesmo e ganha borda na cor
    (`BadgeStyle`/`badgeBackground`, testado), nas etiquetas e nos avisos;
    escurecer o fundo reduzia o contraste do texto.
  - B6: previews novas ("Não foi possível apagar", simulador indisponível e
    runtimes Unusable/Deleting, texto grande da seção). O texto grande foi
    renderizado lado a lado com o padrão e saiu idêntico: o macOS ignora o
    `dynamicTypeSize` nesses estilos. A conferência real de texto grande,
    truncamento em en, VoiceOver real (inclusive o estado marcado ou não das
    caixas) e Aumentar contraste vai para o C27, que já está no checklist.
  - B7: a dedicatória em pt-BR diz "tecnologias Apple" ("Este app simples
    foi feito… Dedico este app ao meu filho…").
  - NITs aplicados:
    - N1: o tipo do aparelho entra no rótulo do símbolo só quando o nome
      difere (`spokenType`), sem dica;
    - N2: as caixas não repetem mais o tamanho no `accessibilityValue`, que
      podia esconder o estado marcado;
    - N4: o `BadgeStyle` ganhou arquivo próprio.
  - NITs registrados:
    - N5: comentários para tradutores nas chaves curtas;
    - N6: a introdução da confirmação diz "itens que exigem atenção" (o
      Figma diz "de atenção e perigosos"), e o subtítulo de Archives não diz
      "à App Store";
    - N7: o botão "Encerrar agora" desabilitado só se vê ao vivo (C27).
  - 2ª rodada: aprovada. Registrados:
    - R2-N2: decisão que se afasta do R18: as caixas não têm mais
      `accessibilityValue` (o tamanho é lido no rótulo, para não esconder o
      estado marcado); confirmar no VoiceOver real do C27;
    - R2-N3: o Remover continua habilitado num runtime que o `simctl` já
      mostra como Deleting (já era assim antes do C25); conferir no C27;
    - R2-N4: o teste de plural não exercita a regra do português que põe o 0
      em "one", porque a forma `zero` vale para o 0 em qualquer idioma;
    - R2-N5: o preparo das previews espera a lista com polling de 20 ms (só
      DEBUG).
- **Fica como está:**
  - o texto da falha parcial não segue o Figma ("em N categorias");
  - o relatório conta as categorias que geraram resultado, não as do plano
    (N4 do C20);
  - "Cancelando…" aparece três vezes no hero (R2-N1 do C22), porque a fase
    não guarda os bytes;
  - "1 de 1 categorias" não tem plural;
  - o `unreadableOutput` da seção de simuladores não vai para o Sentry (N7
    do C21).

## Adendo da implementação do C32 (2026-10-31)

Pedido do dono: a janela aberta parecia uma coluna; ela passa a ter tamanho
comum, inspirada em apps de limpeza de espaço e seguindo a HIG. Design na
página 08 do Figma ("Janela · tamanho comum (C32)").

- **Janela (R29, D1, D2):** `Window` com id novo `WindowID.main` (`"cleaner"`),
  `defaultSize` 920×620, mínimo 760×520 e `windowResizability(.contentMinSize)`.
  O frame de 560 pt salvo na era da coluna (`NSWindow Frame main`) fica órfão e
  não é restaurado. `WindowHeightFitter` e `WindowFitting` saíram, com os testes.
- **Navegação (R30, D3, D4, D5):** `NavigationSplitView` com barra lateral
  nativa; a seleção é `SidebarDestination` em `@SceneStorage`
  (`sidebar-destination`, padrão Visão geral, nunca vazia). ⌘1–⌘6 no menu
  Visualizar (`CleanerCommands`, `@FocusedBinding`), ⌃⌘S por `SidebarCommands`,
  ⌘R no Atualizar. Limpar e Tentar de novo não têm atalho; Esc só cancela uma
  limpeza e Return só fecha o relatório.
- **Barra de ação (R36, R41, D6):** `ActionBarContent` adapta o `HeroContent`
  (que continua a fonte única e serve o painel sem mudança): o principal fica à
  direita, "Ver detalhes" vira "Ocultar detalhes", o medindo inicial mostra
  "Calculando o espaço…" e "—", e a limpeza mostra "Limpando · n de m" com a
  barra fina. Fica em `.safeAreaBar(edge: .bottom)` do detalhe, sem fundo
  próprio: o conteúdo rola por baixo do vidro e o último item sobe acima da
  barra pelo próprio inset.
- **Bordas da rolagem (R42):** `.scrollEdgeEffectStyle(.soft, for: .all)` no
  detalhe da janela, na lista da barra lateral (com o rodapé em `.safeAreaBar`,
  correção B3), no `ScrollView` dos Ajustes › Sobre, no `Form` dos Ajustes
  › Geral e na preview da página de simuladores.
- **Visão geral (R33, R37, D7, D8, D11):** o hero virou o `OverviewSummaryCard`
  (cartão sólido, sem botões), com `HeroContent.indicator` (progresso no
  medindo inicial e na limpeza, `SpaceBreakdown` nos estados parados, nada nos
  relatórios). Os avisos aparecem por página (`CleanerNotice`). Os cartões de
  seção usam `SectionSummary` com estilo `.count` nas fases paradas e `.bytes`
  nas outras; a barra lateral usa `sidebarText`.
- **Simuladores e runtimes (R35, D9):** `SimulatorsPageView` sem seções
  recolhíveis; `SimulatorsViewModel.loadOnActivation()` lista só na primeira
  ativação da janela (fase `idle`), para o cartão e o selo da barra lateral; ao
  abrir a página, `loadIfNeeded()` lista de novo depois de lista vazia, falha ou
  ferramentas ausentes (correção B2 da revisão 1).
  `SimulatorPresentation` ganhou `statusDetail`, `duplicateBadgeCount`,
  `devicesCaption` e `runtimesCaption`; o antigo `sectionSummary` saiu.
- **Removidos:** `CleanerHeroView`, `CategorySectionView`,
  `CollapsibleSectionHeader`, `WindowFooterView`, `SimulatorsSectionView`,
  `WindowHeightFitter` e `WindowFitting`. As chaves `@AppStorage` de seções
  recolhidas ficam órfãs, sem migração.
- **Textos (D12):** "Select at least one category below" virou "Select at
  least one category"; chaves novas com pt-BR; cinco chaves sem uso removidas.
- **Correções da conferência visual (V2, V4):** a barra lateral abria com cerca
  de 144 pt porque o `.toolbar(removing: .sidebarToggle)`, aplicado depois do
  `.navigationSplitViewColumnWidth`, descartava a largura; os dois ficam na
  `List`, com o `toolbar(removing:)` antes, e ela abre com 244 pt. A legenda da
  barra de espaço usa um `FlowLayout` (quebras em `FlowRows`, testado): numa
  linha em 920 pt, em mais linhas no mínimo, sem truncar. Os detalhes de falha
  só fecham quando um relatório sai (`OverviewPresentation.closesFailures`), o
  que deixa as previews começarem com eles abertos. 438 testes únicos (482
  casos executados).
- **Validação:** 438 testes únicos (482 casos executados) passaram, sem avisos;
  lint sem violações; Release sem avisos; auditoria de strings sem chave faltando
  ou sobrando.
- **Conferência visual (AC33l):** feita em janelas reais (20 capturas do harness e
  o app real em Debug, pt-BR, claro e escuro), acima de 98% em todos os frames da
  página 08 do Figma. Achou e corrigiu a barra lateral estreita no primeiro
  lançamento (ordem de `toolbar(removing:)` e `navigationSplitViewColumnWidth`)
  e a legenda truncada no tamanho mínimo (`FlowRows`/`FlowLayout`). As imagens
  foram enviadas ao dono.
- **Ajustes de design declarados no Figma:** onde o macOS desenha componentes
  nativos, o Figma foi alinhado ao sistema: barra lateral de altura total com
  ícones na cor de destaque, título da toolbar no tamanho do sistema, glifos dos
  cartões na cor da seção e o selo nativo como número simples.
- **Divergências mantidas:**
  - o aviso fixo "Alguns itens vão para a Lixeira", exigido pelo plano e ausente
    no Figma (divergência 2 do AC30b, pendente de decisão do dono);
  - os ícones de status em `.fill` colorido, como no painel, contra o contorno
    do Figma (desvio 8, decisão do dono pendente).
- **Armadilha da barra lateral:** em `SidebarRow`, `.badge` e `.tag(destination)`
  têm de ser os últimos modificadores, com o `.tag` por fora. Um `.badge` aplicado
  por fora da linha esconde a tag da `List`, e o item deixa de ser selecionável
  (aconteceu com "Simuladores e runtimes"). Nenhum teste automatizado protege
  essa ordem, porque o teste de UI é proibido.
- **Pendente:** a verificação manual dos atalhos (⌘1–⌘6, ⌃⌘S, ⌘R, Esc, Return)
  e do tamanho mínimo da janela real. A automação foi negada pelo macOS, por
  falta de permissão de Acessibilidade.

## Adendo do C33 (2026-11-01)

Card C33 (AC34). Pedido do dono: "Manter e migrar". O app fica com o bundle id
`com.didisouzacosta.CleanerXcode`, e as preferências vêm do id antigo
`didisouzacosta.CleanerXcode` (até a 0.7). O card também fixa o caminho da
pasta `resources/` (R11).

- **D1. Onde e quando:** `PreferencesDomainMigrator`
  (`Sources/Core/Persistence`) roda dentro de `AppContainer.makeCleanerViewModel`,
  só fora de teste e de preview, logo antes do `PreferencesMigrator`. Nenhum
  ViewModel, nem os Ajustes, o analytics ou o `AppDelegate`, lê o domínio antes.
  Não roda se o app for compilado com o id antigo.
- **D2. Leitura e cópia:** `persistentDomain(forName:)` traz só o que foi salvo no
  domínio antigo, sem as chaves globais ou de argumentos que
  `UserDefaults(suiteName:)` incluiria. A cópia é crua, chave a chave, e preserva
  a codificação. Um valor ilegível volta ao padrão no `PreferencesMigrator`, com o
  breadcrumb `preferences_restored`.
- **D3. O que é copiado** (`AppContainer.legacyDomainKeys`): as 15 categorias,
  `display-free-up-space-in-menu-bar`, `show-menu-bar-extra`,
  `temporary-minimum-age-days`, `send-anonymous-analytics` e `hm_visitor_id`
  (`HimetricaAnalytics.visitorIDKey`, espelho de `StorageManager.Keys.visitorId`
  do SDK 1.0.0).
- **D4. O que fica:** `preferences-schema-version` (diverge do card de propósito:
  o v1→v2 roda de novo sob o id novo, mantém os valores copiados e entrega o item
  de login ao `SMAppService`), frames de janela e de split view, a aba dos Ajustes,
  `NSStatusItem *`, o estado de cena, as chaves órfãs `section-collapsed-*` e
  `simulators-list-expanded`, `hm_session_*`, `hm_original_referrer` e chaves
  `Apple*`/`NS*` ou do Firebase.
- **D5. Uma vez só, sem sobrescrever, sem apagar:** marcador
  `legacy-domain-migration-version = 1` no domínio novo, gravado também quando o
  antigo não existe. Com o marcador, o antigo nem é lido. Uma chave só é copiada
  se o novo não a tem. O antigo nunca é gravado nem apagado, então um downgrade
  para a 0.7 funciona. Limitação: voltar à 0.7 e atualizar de novo não traz o que
  mudou na 0.7 nesse meio-tempo.
- **D6. Item de login:** vindo da 0.7 (schema < 2), `launch-at-login` é copiado
  cru e, se ausente, vira `true` (a 0.7 registrava a cada lançamento). Vindo de
  uma build 1.0 de desenvolvimento (schema ≥ 2), não é copiado. O
  `PreferencesMigrator` registra uma vez com o id novo. A entrada antiga não pode
  ser desregistrada pelo app novo; pode sobrar uma entrada "CleanerXcode" a mais
  em Itens de Início (conferir no C27; Release Notes no C29).
- **D7. Sentry:** o release passa a ser `com.didisouzacosta.CleanerXcode@versão+build`;
  o fallback de `ErrorReportingConfiguration` acompanha. A 0.7 usava Crashlytics,
  então não há continuidade a preservar.
- **D8. Literais:** o subsystem do `Logger` do `FileSystemSizeScanner`, a preview
  da janela e o fallback do Sentry usam o id novo. Fixtures de teste,
  `testHostSuiteName`, `TestPreferencesDomain.prefix` e o bundle do target de
  testes ficam.
- **D9. Pasta temporária:** o `TemporaryItemsPolicy` deixa de proteger itens com
  o prefixo do id antigo. Eles continuam passando pela idade mínima e pelo dono do
  arquivo. Aceito.
- **R11. Pasta `resources/`:** a pasta continua `resources/` minúsculo, porque a
  0.7.0 publicada consulta `.../main/resources/version.json`; renomear quebraria a
  checagem de atualização dela (o GitHub raw diferencia maiúsculas). A
  renomeação para `Resources/` chegou a ser preparada e foi desfeita pelo dono. O
  teste `theVersionFileURLKeepsTheLowercasePublishedPath` lê o `Info.plist`
  compilado e fixa `VERSION_FILE_URL` em `.../main/resources/version.json`.
- **Q1 (máquina do dono):** o domínio novo dele já tem schema 2 e os padrões, e a
  regra de não sobrescrever fica no código. Para trazer as escolhas antigas, o
  dono roda uma vez, com o app fechado, `defaults delete com.didisouzacosta.CleanerXcode`.
  Como o domínio antigo dele está no schema 2, "abrir no login" não é migrado.
- **Q2 (assinatura):** ad hoc (`"-"`) em Debug e Release por enquanto. Antes de
  distribuir, o C26 troca a Release para Developer ID (a notarização rejeita ad
  hoc). Não verificado: ad hoc com Hardened Runtime numa Release distribuída.
- **Validação:** 458 testes únicos (507 casos executados) passaram, sem avisos;
  lint sem violações; Release compila sem avisos, com
  `Identifier=com.didisouzacosta.CleanerXcode` e `Signature=adhoc`. O app não foi
  aberto durante a tarefa, para não migrar os domínios reais do dono.

## Adendo do C30 (2026-11-01)

Card C30 (AC28). Pedido do dono: "Execute a tarefa c30". O pedido explícito supera
a **D11** ("instalar runtimes: P3, fora do marco 1.0"): o C30 entra no branch
`v1.0.0`. Depois de ver a simulação no Figma, o dono escolheu **"Só plataformas"**
(adendo A1 do plano do C30): uma folha "Baixar runtimes" com iOS, watchOS, tvOS e
visionOS, seleção múltipla e download em fila, um de cada vez, sempre na versão do
Xcode selecionado. Sem versões antigas, sem tamanhos, sem catálogo da Apple e sem
rede nova.

- **Comando:** `XcodebuildRuntimeDownloader` (`Sources/Core/Simulators`) roda
  `/usr/bin/xcrun xcodebuild -downloadPlatform <plataforma> [-buildVersion <v>]`
  pelo `ProcessRunning`, sem shell. Pelo `xcrun`, usa o mesmo Xcode do `simctl`, e
  o `SIGTERM` chega ao `xcodebuild` (o `xcrun` faz `exec`, ver o adendo do C13).
  A plataforma é um enum fechado (`RuntimePlatform`, rawValue = argumento) e a
  versão só existe validada (`RuntimeBuildVersion`: de 1 a 3 grupos de dígitos
  ASCII, conferidos byte a byte em UTF-8), então nenhum texto vira outro
  argumento. A interface não passa versão (Q7).
- **Falhas:** `XcrunFailure` (`Sources/Core/Process`) concentra a regra que era do
  `SimctlSimulatorService`: exit 72 ou stderr com `xcrun: error:` →
  `.toolUnavailable`; as demais passam iguais. O `simctl` usa o mesmo helper, sem
  mudança de comportamento.
- **Progresso e prazo:** indeterminado no C30, porque a saída do
  `-downloadPlatform` não é documentada e o `ProcessRunner` só devolvia a saída no
  fim; determinado desde o C34, quando a saída o traz (ver o adendo do C34). Prazo
  de 6 h por item (`ProcessRequest.runtimeDownloadTimeout`, cerca de 8 GB a 3 Mbps).
- **Folha "Baixar runtimes"** (`RuntimeDownloadSheet`, Figma `47:1911`): abre pelo
  "Escolher…" do cartão, num segundo `.sheet(item:)` da página. As 4 plataformas,
  na ordem fixa, com caixa de seleção, símbolo (`iphone`, `applewatch`, `appletv`,
  `visionpro`) e os runtimes instalados de cada uma (`RuntimePlatform.matches`, por
  `platformIdentifier` ou pelo prefixo do identificador; "visionOS 26.0", nunca
  "xrOS 26.0"; mais novos primeiro, sem repetidos) ou "Nenhum runtime instalado".
  Abre sem nada selecionado (Q9), e "Baixar N runtimes" fica desabilitado com 0.
  Return confirma e Esc cancela. Textos e regras em `RuntimeDownloadSheetContent`.
- **Fila** (`RuntimeDownloadRun`, `RuntimeDownloadOutcome`): a ordem é sempre a de
  `RuntimePlatform.allCases`, qualquer que seja a ordem das marcações. Uma falha não
  para os seguintes (Q8), exceto `.toolUnavailable`, que marca o restante como falho
  sem rodar processo. Uma única tarefa, herdando o main actor (grava o estado entre
  os itens; o processo sai do main actor no `ProcessRunner`), guardada para o
  Cancelar: o item atual recebe `SIGTERM`, nenhum outro começa, e o atual e os da
  fila ficam "não baixado". Cada runtime instalado é listado na hora (pedido do
  dono em 2026-11-02), antes de o próximo começar, numa tarefa própria que o
  cancelamento da fila não cancela (uma listagem cancelada viraria
  `.failed(.cancelled)`), e as listagens nunca se sobrepõem. Um Cancelar durante
  essa listagem só encerra a fila quando ela termina (alguns segundos). Na listagem
  depois do último item, o cartão dizia "Baixando…"; desde o C34 diz "Atualizando a
  lista de runtimes…" (N5). Depois da tarefa, a
  lista recarrega só se pode estar defasada (o último item falhou ou foi cancelado).
  Nada é listado durante uma exclusão, que lista no fim (B6). Instalar não faz a
  janela medir de novo: nenhuma categoria da limpeza mede runtimes, e a Visão geral
  e a barra lateral leem a lista do próprio `SimulatorsViewModel`. Remover um
  runtime continua recarregando no fim do `confirm()`.
  "Tentar de novo" refaz só as que falharam, sem abrir a folha, e não roda com a
  folha aberta.
- **Estado:** `SimulatorsViewModel.runtimeDownload` (`RuntimeDownloadState`:
  ocioso, `downloading(run)`, `finished(run)`) e `downloadChoice` (a folha aberta).
  As intenções (`requestRuntimeDownload`, `toggleRuntimePlatform`,
  `cancelRuntimeDownloadChoice`, `confirmRuntimeDownload`,
  `retryFailedRuntimeDownloads`, `cancelRuntimeDownload`,
  `dismissRuntimeDownloadResult`) ficam numa extensão no mesmo arquivo, que acessa
  os membros privados e mantém o corpo do tipo abaixo do limite.
- **Exclusão mútua (R14):** a folha não abre com download, exclusão ou confirmação
  de exclusão aberta; com a folha aberta, nenhuma exclusão é pedida; confirmar a
  folha durante uma exclusão não faz nada. Uma confirmação de remoção de runtime
  ainda aberta quando um download começa (por "Tentar de novo") é descartada pelo
  `confirm()` sem apagar. Durante o download, "Remover" dos
  runtimes fica desabilitado ("Aguarde o download do runtime terminar"); apagar
  simuladores continua permitido. Durante uma limpeza, "Escolher…", "Tentar de
  novo" e o primário da folha ficam desabilitados ("Disponível quando a limpeza
  terminar"); a seleção e os Cancelar, nunca.
- **Cartão** (`RuntimeDownloadCardView` com `RuntimeDownloadPresentation`, textos
  já localizados): ocioso "Baixar runtimes" / "Escolha as plataformas · vários GB
  cada" / "Escolher…"; baixando com a posição "(2 de 3)" e a legenda com o que
  terminou e "Na fila: …"; tudo instalado (verde, sem botão); falha (laranja, "N de
  M runtimes não foram baixados" e os fragmentos por plataforma, "Tentar de novo");
  cancelado (neutro, "Escolher…"). Uma fila de 1 mantém os textos de item único.
  Fica abaixo da lista de runtimes, ou do cartão de status no estado vazio.
- **Sair:** sair da página não cancela (tarefa não estruturada). Sair do app cancela:
  o `CleanerXcodeApp` observa `NSApplication.willTerminateNotification` fora de teste
  e de preview.
- **Composição:** o `AppContainer` entrega `InertRuntimeDownloader` (lança
  `.toolUnavailable`) em teste e em preview, e `XcodebuildRuntimeDownloader` fora
  deles. Nenhum teste roda o `xcodebuild`.
- **Decisões:** Q1 substituída pelo A1 (as 4 plataformas); Q2 sem confirmação além
  da própria folha; Q3 sem item na barra de menus nem nos Comandos; Q4 sem evento de
  analytics (o contrato de eventos e o README não mudam); Q5 a limpeza continua
  permitida durante o download; Q6 prazo de 6 h por item; Q7 sem seletor de versão;
  Q8 a Q11 como no A1.
- **Divergências do plano do C30 e do A1:** os fakes e fixtures das previews ficam
  em arquivos próprios (`PreviewRuntimeDownloader`, `RuntimeDownloadPreviewFixtures`,
  `RuntimeDownloadCardPreview`, `RuntimeDownloadSheetPreview`); os testes do
  ViewModel ficaram em dois arquivos (`SimulatorsViewModelRuntimeDownloadTests`, a
  fila, e `SimulatorsViewModelDownloadSheetTests`, a folha e as guardas) por causa do
  `file_length`; o fragmento de falha "plataforma: motivo" é montado sem chave; a
  guarda de "confirmar a folha durante uma exclusão" não tem teste próprio, porque a
  API não deixa chegar a esse estado (a folha não abre durante uma exclusão e
  nenhuma exclusão começa com a folha aberta). Na revisão, "Tentar de novo" ganhou
  a guarda da folha aberta, mas não a de confirmação aberta: assim a guarda do
  `confirm()` continua alcançável e testada. Na folha, o rótulo de acessibilidade
  de cada caixa é o nome da plataforma e os instalados são a dica, para não
  esconder o estado marcado. Ainda em 2026-11-02, a pedido do dono, as linhas da
  folha ficaram centradas na vertical: a caixa nativa fica com o rótulo oculto numa
  linha centrada, o resto da linha é um botão simples que a marca (oculto ao
  VoiceOver), e os símbolos ficam num quadro fixo de 24×24.
- **Validação:** 520 testes únicos (592 casos executados) passaram, sem avisos;
  lint sem violações; Release compila sem avisos; o catálogo tem 246 chaves, todas
  usadas e traduzidas, com os plurais conferidos por `LocalizedPluralTests`.
  Conferência visual contra o Figma (AC20, regra revista em 2026-11-02): capturas
  da janela real em pt-BR, comparadas sem reamostragem com os nós do Figma. Geral /
  layout com o texto mascarado: parado 98,5 / 99,7; baixando 97,6 / 99,3; fila
  96,9 / 99,3; instalado 98,6 / 99,4; tudo instalado 98,5 / 99,4; falhou 97,7 /
  99,5; falha parcial 97,5 / 99,5; cancelado 98,5 / 99,7; fila durante limpeza
  96,8 / 99,6; escuro 97,2 / 99,4; vazio 98,5 / 99,7; folha 96,9 / 98,7 (por
  região, porque a mensagem quebra em 3 linhas no Figma e 2 no app). A diferença
  restante é a renderização da fonte. Pendente com o
  dono (AC28-live, junto do C27): download real concluído e listado, uma fila de 2 e
  o Cancelar no meio encerrando o `xcodebuild` (`pgrep -fl xcodebuild` vazio), sair
  do app no meio, e os casos sem Xcode, sem rede e com a licença não aceita.

## Adendo do C34 (2026-11-03)

Card C34 (AC35). Pedido do dono em 2026-11-01: "É possível mostrar o progresso do
download do runtime?", "Se possível o tempo estimado de conclusão" e "Card novo e
autorizo um download curto". Nível 2: muda o contrato público do `ProcessRunning`
(`Core/Process`), lê a saída em streaming com cancelamento e prazo, e muda o cartão.
O plano do Manager (2026-11-01) foi escrito antes das correções finais do C30; as
emendas do agente principal prevalecem sobre ele.

- **Amostra real:** `xcrun xcodebuild -downloadPlatform tvOS -exportPath <tmp>`
  (Xcode 27.2), cancelada com `SIGTERM` depois de cerca de 45 s, autorizada pelo
  dono. Tudo sai no stdout; cada redesenho do progresso começa com `\r`, cerca de
  uma vez por segundo, com os números no locale do usuário ("0,7% (27,3 MB of
  3,76 GB)", o "of" em inglês) e espaços que apagam o redesenho anterior. O
  original se perdeu quando o `/private/tmp` foi limpo; a reconstrução em
  `Tests/Support/Fixtures/xcodebuild-download-platform-tvos.txt` (2.049 bytes, 26
  `\r`, 3 `\n`, SHA-256 `288538952271fa1518f38bc2bfe261ae99fa7814b1c70767417d4aa3f6631dc2`)
  guarda os 16 primeiros e os 13 últimos dos 53 trechos, byte a byte, inclusive o
  "Download was cancelled." sem `\n` no fim, que só o `finish()` do
  `OutputLineSplitter` entrega, e deixa de fora os 24 do meio (de 0,2% a 0,7%),
  do mesmo formato. Não tem
  caminho nem usuário, então não precisou de sanitização.
- **Streaming:** `ProcessRunning.run(_:onStandardOutputLine:)` com o mesmo
  contrato do `run(_:)`; o `ProcessRunner` passa o callback ao leitor do stdout,
  que divide os trechos com o `OutputLineSplitter` ("\n", "\r" ou "\r\n", sem
  linhas vazias, a linha cortada guardada entre leituras, UTF-8 com U+FFFD, teto de
  16 KiB). Nenhuma linha chega depois de o método voltar; a linha parcial do fim
  só sai no EOF, nunca depois de cancelamento ou prazo (testado com um
  "partial" pendente no `tail -f`). A implementação padrão do
  protocolo entrega as linhas depois do sucesso, então `ProcessRunnerSpy`,
  `GatedProcessRunner` e `SimctlSimulatorService` não mudaram.
- **Parser e downloader:** `RuntimeDownloadOutputParser` lê cada linha como
  `RuntimeDownloadEvent` (preparando, baixando com fração e bytes, instalando,
  concluído). Aceita vírgula ou ponto decimal, separadores de milhar (inclusive
  espaço, NBSP e NNBSP), kB/MB/GB/TB, "bytes", "Mo"/"Go" e nomes com parênteses;
  100% vira "instalando"; o resto é ignorado. "Done downloading", "Beginning asset
  import" e "Done importing" vêm das strings do binário, não da amostra. O
  `RuntimeDownloading` ganhou o `onProgress`, e uma extensão mantém a chamada sem
  ele; o `XcodebuildRuntimeDownloader` usa o streaming, com os mesmos erros, prazo
  e cancelamento.
- **Tempo estimado:** `RuntimeDownloadRateEstimator` pelos bytes, numa janela de
  120 s entre as mudanças de bytes, suavizado por EWMA (α 0,3). Só aparece com 3
  amostras e 10 s, some depois de 120 s sem mudança e acima de 48 h, e recomeça se
  os bytes voltam ou o total muda. `RuntimeDownloadRemaining` arredonda: "Menos de
  1 min", minutos para cima (no mínimo 2) até 60 e, daí em diante, os 5 minutos
  mais próximos, então o número nunca é "1 min" nem "1 h". O texto usa
  `Duration.UnitsFormatStyle` abreviado; saída real: en "12 min", "60 min",
  "1 hr, 20 min", "2 hr"; pt-BR "12 min", "60 min", "1 h e 20 min", "2 h".
- **ViewModel:** `runtimeDownloadProgress`, separado do `runtimeDownload` para só
  o cartão ser invalidado. Cada item roda num task group do main actor: o filho
  chama o downloader e manda os passos para um `AsyncStream`
  `bufferingNewest(1)`; o corpo passa cada passo ao
  `RuntimeDownloadProgressTracker`, que publica no máximo uma vez por segundo
  (mudança de fase na hora) e nunca o mesmo valor duas vezes. O progresso é limpo
  quando o item termina, antes de a fila gravar o resultado. O relógio (`now`) é
  injetável. A fila do C30 (listagem na hora, `listShieldedFromCancel`, guarda B6,
  `XcrunFailure`) ficou igual: só a chamada ao downloader passou pelo novo
  `download(_:)` por item.
- **Cartão:** com a fração, o título traz a porcentagem arredondada para baixo
  ("Baixando o runtime do iOS… 42%", "… 42% (2 de 3)"), uma barra linear pequena
  fica entre o título e a legenda (rótulo "Progresso do download" e valor com a
  porcentagem e o tempo), e a legenda começa com o tempo ("Cerca de 12 min
  restantes. Mantenha…" ou "Cerca de 12 min restantes · iOS instalado · Na fila:
  visionOS. Mantenha…"). Instalando: "Instalando o runtime do iOS…" com o spinner.
  Preparando ou sem linha reconhecida: exatamente o C30. O `Spacer` virou
  `.frame(maxWidth: .infinity)` com 18 pt à direita, o mesmo espaço de antes até
  os controles. O título usa `.numericText()` e o cartão anima com
  `.subtleAnimation(value: runtimeDownloadProgress)` só na sua subárvore.
- **N5 (emenda do agente principal):** depois do último item, enquanto a lista é
  atualizada, o cartão diz "Atualizando a lista de runtimes…" (spinner, legenda do
  C30, "Cancelar"). Um Cancelar nessa hora continua só encerrando a fila quando a
  listagem termina, com o item instalado.
- **Strings novas (en → pt-BR):** "Downloading the %@ runtime… %@", "… %@ (%lld of
  %lld)", "Installing the %@ runtime…", "… (%lld of %lld)", "Updating the runtimes
  list…", "Less than 1 min left", "About %@ left", "Download progress" e
  "Installing". O catálogo tem 255 chaves, todas traduzidas.
- **Previews:** cartão com 3%, 42% com 12 min, 7% com 1 h e 20 min, instalando,
  fila 2 de 3 com progresso, atualizando a lista (item único e fila) e 42% escuro;
  na página (`SimulatorsSectionPreview`), `.downloadProgress`, `.downloadTimeLeft`,
  `.downloadLongTimeLeft`, `.downloadInstalling` e `.downloadQueueProgress`, que
  passam pelo ViewModel real com o `PreviewRuntimeDownloader.progress` e um
  `PreviewClock` de 10 s por leitura.
- **Divergências do plano:** a fixture não é a original (3.867 bytes, 48 linhas de
  progresso, 50 `\r` e 3 `\n`); como ela, termina sem `\n`. Os testes contam 29
  linhas (28 no `append` e a última no `finish()`), 24 de progresso e 27 passos, e o tempo da fixture no rastreador põe os 24 s dos trechos ausentes
  depois da 12ª linha. O teste do C30 "o fim da fila ainda lista o que terminou"
  virou o do N5. A divisão de linhas decodifica com o decodificador UTF-8 em vez
  de `String(decoding:)`, que o lint (`optional_data_string_conversion`) recusa.
- **Validação:** 575 testes únicos (699 casos executados), sem avisos; lint sem
  violações; Release sem avisos.
- **Conferência visual (AC10):** feita pelo agente principal contra os frames do
  Figma (página 08, y = 4560: `55:2248`, `55:2460`, `55:2672`, `55:2884`,
  `55:3093`, `55:3305`), com capturas da janela real em pt-BR e o mesmo método do
  C30.
  - **Figma alinhado à barra nativa:** os frames desenhavam a barra com 4 pt e um
    trilho mais escuro. A barra passou a 6 pt, com cantos de 3 pt e o trilho claro
    com 10% de opacidade, com 3 pt acima e 2 pt abaixo, para cair no mesmo pixel do
    app. A cor continua ligada a `accent/primary`. O cartão da fila passou de 64
    para 65 pt.
  - **Resultado, geral / layout com o texto mascarado:** 3% 96,7 / 99,4; 42% com
    tempo 96,1 / 98,7; 7% com tempo longo 96,3 / 99,4; instalando 97,7 / 98,4;
    fila 2 de 3 95,1 / 98,5; 42% escuro 95,5 / 98,3.
  - **O que sobra:** a renderização da fonte (o geral da fila é o mais baixo,
    pela legenda em 2 linhas), o traço do ícone um pouco mais fino no app e a cor
    do destaque (`#008DF9` no app, `#009DFF` na exportação do Figma).
  - **Estados do C30 com o código do C34** (B1 da revisão, depois da troca do
    `Spacer`), contra os frames do C30, geral / layout: parado 98,6 / 99,5; vazio
    98,6 / 99,5; baixando 97,8 / 99,4; fila 97,0 / 99,4; instalado 98,6 / 99,4;
    tudo instalado 98,5 / 99,4; falhou 97,8 / 99,6; falha parcial 97,8 / 99,6;
    cancelado 98,5 / 99,5; fila durante limpeza 97,0 / 99,4; escuro 97,4 / 99,3.
    Os números batem com os do C30, então a troca não mudou o layout.
  - **N5 ("Atualizando a lista de runtimes…"):** frames novos no Figma,
    copiados dos frames do C30 com só o texto do cartão trocado: `63:2932`
    (cartão `63:2997`) e `63:3039` (fila, cartão `63:3104`), na página 08, em
    y = 4560. O cartão foi capturado pela preview do cartão, na largura da coluna
    (628 pt), porque a página não tem cenário para esse instante. Item único 97,5
    / 99,4; fila 97,1 / 99,4.
- Pendente com o dono (AC-live, junto do
  AC28-live): num download real sem `-exportPath`, a porcentagem e o tempo
  aparecem, "Instalando…" vem depois de 100% e o Cancelar encerra o `xcodebuild`;
  conferir também se o tempo estimado some com a rede parada (a estimativa só é
  recalculada quando chega uma linha nova do `xcodebuild`).
