# CleanerXcode — Brief do produto

## Identidade do produto

- Nome: CleanerXcode (publicado como BETA no README).
- Plataforma: macOS 15.0+, app de barra de menus (`MenuBarExtra` com estilo
  `.window`, `LSUIElement = YES`, sem ícone no Dock), categoria
  `public.app-category.developer-tools`.
- Problema que resolve: o Xcode acumula Derived Data, Archives, caches, Device
  Support e dados de simuladores que ocupam muito espaço em disco.
- Público principal: desenvolvedores Apple que usam Xcode no Mac.
- Proposta de valor: liberar espaço com um clique a partir da barra de menus,
  mostrando antes quanto espaço pode ser recuperado. Gratuito, open source (MIT)
  e sem login ou coleta de dados pessoais.

## Experiência principal

Regras de experiência do dono (2026-10-31), válidas para a versão 1.0:

- A janela principal abre com tamanho comum (920×620, mínimo 760×520), é
  redimensionável e o macOS lembra o tamanho e a posição; a navegação usa
  barra lateral nativa (Visão geral, as quatro seções e Simuladores e
  runtimes); o conteúdo do detalhe rola e a barra de ação, com o total e a
  ação principal, fica sempre visível (C32, Figma página 08).
- O conteúdo rola por baixo da toolbar e da barra de ação, sem corte seco, e
  toda rolagem usa o efeito de borda suave (blur) no topo e na base (pedido do
  dono no C32).
- Toda mudança na tela tem uma animação sutil: nada aparece, some ou muda de
  forma brusca (seções, avisos, cartões, textos, números e botões). Com
  Reduzir movimento, nada desliza nem muda de escala: as mudanças acontecem de
  uma vez.

### Fluxos

- Fluxo de entrada: o app abre como agente na barra de menus (opcionalmente
  no login, via `LaunchAtLogin`). Ao aparecer o rótulo da barra, aplica a
  preferência de abrir no login e consulta se há versão nova. O
  `CleanerStore` calcula o espaço ocupado assim que é criado.
- Fluxo principal (tela Cleaner): o usuário abre o popover, vê o botão
  "Clear <tamanho>" com o total liberável das opções ativas e toca nele. Os
  comandos ativos rodam em paralelo; o botão mostra o progresso circular,
  depois "🎉 Success, all clear!" por cerca de 2 s e volta ao estado inicial.
- Fluxos alternativos:
  - Preferências (ícone de engrenagem, desabilitado durante a limpeza):
    liga/desliga cada opção de limpeza com o tamanho atual ao lado, exibir o
    espaço liberável na barra de menus, abrir no login, dedicatória e doação.
  - Atualização: se o `version.json` remoto tiver versão maior que a
    instalada, aparece o botão "Update", que abre o link do DMG.
  - Links sociais (GitHub, X, LinkedIn) e doação (Stripe) abrem no navegador.
  - Sair (`Quit`) encerra o app.

### Estados

- Rótulo da barra de menus (quando "Display Free Up Space In Menu Bar" está
  ligado): "Cleaning" durante a limpeza; "Calculating" apenas no primeiro
  cálculo com total zero; depois o tamanho liberável formatado.
- `CleanerStore.Status`: `idle` (botão azul, "Clear" ou "Clear <tamanho>"),
  `isCleaning` (verde, progresso `steps/commands`, sem toque), `isCompleted`
  (verde, sucesso, sem toque) e `error` (vermelho, "Try again").
- Carregamento: `usedSpace` (`StateValue<UsedSpace>`) fica em `isLoading`
  durante o cálculo; o resultado é recalculado após cada comando concluído, ao
  fim da limpeza e a cada ~6 s por um `Timer` reprogramado após cada cálculo.
- Vazio: sem opções ativas ou com diretórios ausentes, o total é zero e o botão
  mostra só "Clear".
- Falha:
  - falha no cálculo vira `UsedSpace()` zerado, sem mensagem;
  - falha em um comando é guardada no passo, mas o status ainda vai para
    `isCompleted`: o caso `error` existe e nunca é atribuído, então a
    falha não aparece na interface;
  - falha ao buscar a versão vai para `hasUpdate.error` e o botão "Update"
    não aparece.
- Permissão e indisponibilidade: o app não pede permissões. Ele roda sem App
  Sandbox (entitlements vazios) e com Hardened Runtime, para poder apagar
  pastas em `~/Library`. `xcrun simctl` e `pod` dependem do ambiente do
  usuário.
- Interrupção e recuperação: cada comando tem timeout de 10 s
  (`withThrowingTimeout`). Uma nova limpeza cancela a `Task` anterior. Cancelar
  ou estourar o timeout não encerra o `Process` já iniciado.

## Recursos e limites

- Recursos disponíveis (com callsite em produção):
  - Remove Archives (`~/Library/Developer/Xcode/Archives`), padrão ligado.
  - Remove Caches (`~/Library/Caches/com.apple.dt.Xcode`,
    `~/Library/Caches/org.carthage.CarthageKit` e `pod cache clean --all` se o
    CocoaPods existir), padrão ligado.
  - Remove Derived Data (`~/Library/Developer/Xcode/DerivedData/`), padrão
    ligado.
  - Clear Device Support (iOS, watchOS e tvOS DeviceSupport), padrão desligado.
  - Clear Simulator Data (`~/Library/Developer/CoreSimulator` inteiro),
    padrão desligado.
  - Remove Old Simulators (`xcrun simctl delete unavailable`), padrão
    desligado.
  - Reset Xcode Preferences (`defaults delete com.apple.dt.Xcode`), padrão
    desligado.
  - Cálculo do espaço por categoria (`calculate-free-up-space.sh`, `du -sk`,
    em KB).
  - Exibir o espaço liberável na barra de menus (padrão ligado) e abrir no
    login (padrão ligado).
  - Verificar atualização por `resources/version.json` no GitHub.
  - Analytics de produto pelo Himetrica (C07), só em Release com chave e com
    a preferência "Enviar estatísticas de uso" ligada (padrão). Os eventos
    estáveis estão no PROJECT_GUIDE; nenhum leva caminhos, nomes, UDIDs ou
    tamanhos exatos. O toggle da preferência entra na tela de Ajustes (C22).
  - Relatório de crashes e erros pelo Sentry (C08), em Debug e Release com
    `SENTRY_DSN`, em environments separados. Uma limpeza com falha gera um
    único evento agregado; caminhos do usuário viram `~`, caminhos
    temporários são removidos e sessões não são rastreadas.
  - Localização: inglês (fonte) e pt-BR em `Localizable.xcstrings`.
- Recursos premium ou condicionais: não há recursos pagos. A doação é opcional,
  por link externo.
- Limites conhecidos:
  - A remoção é definitiva (`rm -rf`), sem Lixeira, confirmação ou desfazer.
  - Remove Old Simulators e Reset Xcode Preferences não entram no total
    liberável estimado.
  - Comandos lentos (Derived Data ou CoreSimulator grandes) podem passar dos
    10 s de timeout.
  - O cálculo com `du` roda continuamente a cada ~6 s enquanto o app está
    aberto.
  - A comparação de versões junta os componentes (`0.10.0` → `0100`), o que
    pode falhar com componentes de dois dígitos.
- Recursos planejados, mas ainda não conectados (README, "Areas for
  Improvement"): personalização avançada da remoção, integração com Atalhos do
  macOS e melhor visualização do espaço liberado. Código sem uso:
  `import Charts`/`import TipKit`.

## Dados e persistência

- Modelos: `UsedSpace` (tamanhos em KB por categoria, com `cache`,
  `deviceSupport` e `totalSize` derivados), `Version` (`version`, `build`,
  `downloadURL`), `Command` (script `.sh` no bundle e timeout),
  `StateValue<T>` (valor + `isLoading` + `error`) e `Route.Path`
  (`cleaner`, `preferences`).
- Fonte primária dos dados: o sistema de arquivos do usuário, via scripts
  bash empacotados e executados com `/bin/bash` por `Shell`, e o
  `version.json` remoto.
- Armazenamento local (até a 0.7; na 1.0 o acesso é o `PreferencesStoring` do
  C18): `UserDefaults.standard` via `StoragedValue<T>` (valor em JSON). As chaves das opções são os nomes dos scripts
  (`remove-archives` etc.) mais `display-free-up-space-in-menu-bar` e
  `launch-at-login`.
- Sincronização ou serviços externos:
  - GitHub raw (`VERSION_FILE_URL` em `Config.xcconfig` → `Info.plist`) para
    a versão e o DMG;
  - links externos (GitHub, X, LinkedIn, Stripe).
- Regras de migração e recuperação: até a 0.7 não havia migração versionada;
  a 1.0 traz o `PreferencesMigrator` (C18) e o `PreferencesDomainMigrator`
  (C33, abaixo). Valor ausente
  ou que falha ao decodificar volta ao `defaultValue`. Renomear um script muda
  a chave da preferência e perde a escolha salva do usuário.
- Bundle id (C33): a 1.0 passa de `didisouzacosta.CleanerXcode` (até a 0.7)
  para `com.didisouzacosta.CleanerXcode`, e o domínio do `UserDefaults` começa
  vazio. No primeiro lançamento, antes do `PreferencesMigrator`, o
  `PreferencesDomainMigrator` copia do domínio antigo, uma vez e sem
  sobrescrever o que já existe no novo, as 15 categorias, as duas opções da
  barra de menus, a idade mínima dos temporários, o opt-out de estatísticas e o
  `hm_visitor_id`. O schema, frames de janela e chaves do sistema não vêm. O
  domínio antigo nunca é gravado nem apagado. Vindo da 0.7, "abrir no login"
  ausente vira ligado (era o comportamento efetivo) e o item é registrado de
  novo com o id novo.

## Validação

Evidências separadas por tipo. Validação local não comprova comportamento live.

- Regra obrigatória de conferência visual (pedido do dono em 2026-10-31): toda
  tarefa que cria ou altera uma tela tem uma etapa própria, antes da revisão do
  Manager e do commit, que compara a tela feita com o layout aprovado no Figma
  (arquivo `n2zvygzbWufumwsOYd1PAj`, páginas 03 a 05 e 08; a página 08,
  "Janela · tamanho comum (C32)", substitui a janela em coluna da página 03). A comparação é feita
  estado a estado, com o render da tela ao lado do frame correspondente,
  conferindo estrutura, hierarquia, textos, cores, espaçamentos, formas e
  componentes. Não precisa ser idêntica pixel a pixel, mas a igualdade tem de
  ficar acima de 98%; abaixo disso a tela volta para correção e a tarefa não é
  concluída. O relatório da tarefa registra os frames comparados, as diferenças
  restantes com a justificativa de cada uma e as imagens enviadas ao dono.

- Validações concluídas:
  - Código: leitura do código conectado em 2026-10-31 (branch `v1.0.0`,
    commit `f11d52c`).
  - Testes: a suíte inicial (35 testes, com `Shell` e o código antigo)
    passou em 2026-10-31; a contagem atual de cada card fica no
    [PROJECT_GUIDE](./PROJECT_GUIDE.md#testes-e-validação).
- Validações pendentes:
  - limpeza real em uma máquina com Xcode, conferindo o espaço liberado contra
    o estimado;
  - comportamento com diretórios grandes (timeout de 10 s) e com falhas
    parciais;
  - envio de eventos ao Himetrica e de erros ao Sentry (C28);
  - verificação de atualização contra o `version.json` publicado;
  - abrir no login com a build assinada e notarizada (Developer ID).
- Condições de hardware, conta ou serviço: Mac com macOS 26+ e Xcode
  instalado; chave do Himetrica e DSN do Sentry (fornecidos pelo dono) para
  validar analytics e erros; Developer ID e notarização para distribuir o DMG.

## Mapa de fontes

| Fluxo | Fontes conectadas |
| --- | --- |
| Entrada, composição e barra de menus | `Sources/App/CleanerXcodeApp.swift`, `Sources/App/AppContainer.swift`, `Sources/App/AppEnvironment.swift`, `Sources/App/AppConfiguration.swift` |
| Versão e `version.json` | `Sources/Core/Models/Version.swift`, `Sources/Core/Helpers/Extensions/Bundle+Extension.swift`, `Config.xcconfig`, `resources/version.json` |
| Analytics | `Sources/Core/Integrations/{Analytics,HimetricaAnalytics,NullAnalytics}.swift`, preferência `send-anonymous-analytics` (`SettingsViewModel`) |
| Domínio da limpeza nativa (C09) | `Sources/Core/Cleanup/*.swift` (`CleanupCatalog`, `SafePathPolicy`, `CleanupReport`) |
| Medição de tamanho (C11) | `Sources/Core/FileSystem/{DiskUsageScanning,FileSystemSizeScanner}.swift`, `Sources/Core/Cleanup/{CategorySize,CategorySizeMeasurer}.swift` |
| Remoção nativa (C12) | `Sources/Core/FileSystem/{FileRemoving,FileSystemRemover,FileOperating}.swift`, `Sources/Core/Cleanup/SafePathPolicy.swift` |
| Execução de processos sem shell (C13) | `Sources/Core/Process/{ProcessRequest,ProcessOutput,ProcessRunning,ProcessRunner}.swift` |
| Simuladores e runtimes (C14) | `Sources/Core/Simulators/*.swift` (`SimctlSimulatorService`, `DuplicateSimulatorDetector`, `CoreSimulatorServiceRestarter`) |
| Pasta temporária e órfãos de simuladores (C15) | `Sources/Core/FileSystem/{TemporaryItemsPolicy,TemporaryItemInspector,OrphanSimulatorTempFinder,TemporaryFilters,FilteredContentsMeasurer,ItemSizeReader}.swift` |
| Reset do Xcode e apps abertos (C16) | `Sources/Core/Xcode/{XcodePreferencesResetting,RunningApplicationsProviding}.swift`, `Sources/Core/Cleanup/CleanupRestrictions.swift` |
| Executor da limpeza (C17) | `Sources/Core/Cleanup/Executor/{CleanupPlan,CleanupExecutor}.swift` |
| Migração de preferências e abrir no login (C18) | `Sources/Core/Persistence/{PreferencesStoring,UserDefaultsPreferencesStore,PreferencesMigrator}.swift`, `Sources/Core/Platform/LoginItemManaging.swift` |
| Migração do bundle id antigo (C33) | `Sources/Core/Persistence/PreferencesDomainMigrator.swift`, `Sources/App/AppContainer.swift` (`legacyDomainKeys`) |
| ViewModel da limpeza (C19) | `Sources/Features/Cleaner/{CleanerPhase,CleanupProgress,CategoryRowState,SimulatorSnapshot,CleanerViewModel,CleanupOutcomeReporter}.swift`, `Sources/Core/Cleanup/Executor/CleanupExecuting.swift` |
| Janela única (C20) | `Sources/Features/Cleaner/Window/*.swift`, `Sources/Features/Cleaner/Presentation/*.swift`, `Sources/Core/Cleanup/InertCleanupServices.swift`, `Sources/App/{CleanerXcodeApp,AppContainer}.swift` |
| Simuladores e runtimes (C21) | `Sources/Features/Simulators/*.swift` |
| Janela de tamanho comum com barra lateral (C32) | `Sources/App/{CleanerXcodeApp,WindowID}.swift`, `Sources/Features/Cleaner/Window/{CleanerWindowView,CleanerSidebarView,SidebarFooterView,CleanerDetailView,ActionBarView,OverviewView,OverviewSummaryCard,SpaceBreakdownBar,SectionCardView,CategoryPageView,SectionHeaderView,GlassSurface,CleanerCommands}.swift`, `Sources/Features/Cleaner/Presentation/{SidebarDestination,ActionBarContent,SpaceBreakdown,CleanerNotice,OverviewPresentation}.swift`, `Sources/Features/Simulators/SimulatorsPageView.swift` |
| Ajustes, barra de menus e Sobre (C22) | `Sources/Features/Settings/*.swift`, `Sources/App/CleanerXcodeApp.swift` (`AppDelegate`) |
| Atualização (C23) | `Sources/Core/Update/{SemanticVersion,VersionChecking}.swift`, `Sources/Features/Update/{UpdateViewModel,UpdatePreview}.swift` |
| Erros e crashes | `Sources/Core/Integrations/{ErrorReporting,NullErrorReporter,SentryErrorReporter,ErrorReportingConfiguration,SentryEventSanitizer}.swift` |
| Distribuição | `releases/CleanerXcode.dmg`, `RELEASE_NOTES.md`, `resources/version.json` |

Caminhos relativos a `CleanerXcode/`, exceto `resources/`, `releases/` e
`RELEASE_NOTES.md`, que ficam na raiz. Os testes ficam em `Tests/`.

## Pendências e decisões

- Resolvido no C17/C19: falhas aparecem como falha parcial ou falha, nunca
  como sucesso (`CleanupReport`, `HeroContent`).
- Resolvido no C13: o cancelamento e o timeout encerram o processo filho
  (`ProcessRunner`).
- Resolvido no C06: o `MIXPANEL_TOKEN` saiu do `Config.xcconfig`, do
  `Info.plist` e do código. **Ação do dono:** revogar o token no Mixpanel,
  porque ele continua no histórico do git.
- Resolvido no C03: o projeto usa Swift 6 (language mode 6) e macOS 26 (ver
  [PROJECT_GUIDE](./PROJECT_GUIDE.md#baseline-efetiva)).
- Decisão: distribuição fora da Mac App Store, por DMG no GitHub, sem App
  Sandbox, com Hardened Runtime e checagem própria de versão.
- Decisão: sem SDKs do Google; analytics de produto pelo Himetrica (desligado
  em DEBUG) e erros pelo Sentry (ligado em DEBUG e Release), ambos sem dados
  pessoais. O README declara
  que o app não pede nome, email nem conta e lista o que cada serviço envia.
- Risco: a remoção destrutiva e irreversível (`rm -rf`, `defaults delete`)
  de pastas que podem conter Archives necessários para symbolication ou
  reenvio à loja.
- Resolvido no C24: o fork `LaunchAtLogin` (por SSH) e o `swift-timeout`
  saíram; o "abrir no login" usa `SMAppService`.
- Decisão do C33: manter o bundle id `com.didisouzacosta.CleanerXcode` e
  migrar as preferências do id antigo (ver o adendo do C33 no plano 1.0).
- Pendência (C27 e C29): o `SMAppService` é ligado ao bundle id, e o app novo
  não consegue desregistrar a entrada de login da 0.7. Pode sobrar uma entrada
  "CleanerXcode" a mais em Ajustes do Sistema › Geral › Itens de Início, que o
  usuário remove à mão. Conferir no C27 e avisar nas Release Notes (C29).
- Pendência (C26): Debug e Release usam assinatura ad hoc
  (`CODE_SIGN_IDENTITY[sdk=macosx*] = "-"`). A notarização rejeita ad hoc, então
  antes de distribuir a Release passa a Developer ID.
- Decisão do C33: a pasta continua `resources/` minúsculo, porque a 0.7.0
  publicada consulta `.../main/resources/version.json`; renomear quebraria a
  checagem de atualização dela (o GitHub raw diferencia maiúsculas). O teste
  `theVersionFileURLKeepsTheLowercasePublishedPath` protege o caminho.
- Próximo passo: definir o escopo da v1.0.0 (branch atual `v1.0.0`, versão
  publicada 0.7.0 build 114) e priorizar: migração para Swift 6, erro visível
  na limpeza, encerramento do processo no cancelamento e remoção do token.
