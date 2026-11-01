# Guia de arquitetura e desenvolvimento de CleanerXcode

## Escopo e fontes de verdade

CleanerXcode é um app macOS de barra de menus da categoria de ferramentas para
desenvolvedores. Ele libera espaço apagando arquivos temporários do Xcode e dos
simuladores.

As fontes deste checkout são, nesta ordem:

- AGENTS.md: regras de engenharia, coordenação e validação (link simbólico
  para `.ai/shared/AGENTS.md`, submódulo `didisouzacosta/AI`).
- PROJECT_BRIEF.md: produto, fluxos, estados e pendências.
- README.md: requisitos públicos e comandos.
- Código e configuração existentes: comportamento efetivamente conectado.

Não trate um tipo, string, pacote ou serviço sem callsite de produção como uma
feature disponível. Não faça migrações de
nomes, pastas ou arquitetura sem escopo explícito.

## Baseline efetiva

- Plataforma e versão mínima: macOS 26.0 no projeto e nos dois targets
  (`MACOSX_DEPLOYMENT_TARGET = 26.0`, card C03). O app ainda roda como agente
  (`LSUIElement = YES`); essa chave só sai no C20, junto com a nova `Window`.
  Hardened Runtime ligado e sem App Sandbox.
- Projeto/workspace: `CleanerXcode.xcodeproj`, com pastas sincronizadas
  (`PBXFileSystemSynchronizedRootGroup`). `Info.plist`, `Config.xcconfig`,
  `Secrets.example.xcconfig` e `Secrets.xcconfig` ficam fora da membership do
  target, para nunca irem para o bundle.
- Configuração e segredos (card C06):
  - `Config.xcconfig` define `VERSION_FILE_URL`, `HIMETRICA_API_KEY =` e
    `SENTRY_DSN =`, vazios por padrão, e termina com
    `#include? "Secrets.xcconfig"`;
  - `Secrets.xcconfig` é ignorado pelo git e preenchido a partir do
    `Secrets.example.xcconfig` versionado. Em xcconfig, `//` é comentário, então
    URLs usam `https:/$()/…`;
  - o `Info.plist` repassa as três chaves, e o `AppConfiguration` trata valor
    vazio ou não expandido (`$(…)`) como "não configurado". Um `SENTRY_DSN`
    sem esquema `http(s)` ou sem host (por exemplo `https:`, quando o `//`
    vira comentário) também conta como não configurado (C08);
  - sem o `Secrets.xcconfig`, o app compila com analytics e erros desligados;
  - a chave do Himetrica e o DSN do Sentry acabam dentro do binário, porque
    são identificadores públicos de cliente. O objetivo é só tirá-los do
    repositório.
- Schemes ou targets:
  - targets `CleanerXcode` (app, bundle `com.didisouzacosta.CleanerXcode`
    desde o C33; até a 0.7: `didisouzacosta.CleanerXcode`) e
    `CleanerXcodeTests` (bundle de testes, `didisouzacosta.CleanerXcodeTests`);
  - assinatura (C33): o target do app usa `CODE_SIGN_IDENTITY[sdk=macosx*] =
    "-"` (ad hoc) em Debug e Release, para compilar sem certificado. A
    notarização rejeita ad hoc: antes de distribuir, o C26 troca a Release
    para Developer ID. Em Debug o cdhash muda a cada build, e o macOS pode
    pedir de novo a aprovação do item de login;
  - scheme `CleanerXcode`, com o test plan `CleanerXcode.xctestplan`
    (paralelizável);
  - o scheme é compartilhado em
    `CleanerXcode.xcodeproj/xcshareddata/xcschemes/CleanerXcode.xcscheme`
    e usa o test plan como plano padrão (D12, card C02). `xcshareddata/` saiu
    do `.gitignore`.
- Linguagem e versão (card C03): nos dois targets,
  - `SWIFT_VERSION = 6.0` (language mode 6, toolchain Swift 6.4.2);
  - `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`;
  - `SWIFT_APPROACHABLE_CONCURRENCY = YES`;
  - `SWIFT_STRICT_CONCURRENCY = complete`;
  - `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`.

  Os pacotes SPM compilam no próprio language mode. Toolchain local
  verificado: Xcode 27.2 (27B52).
- Versão publicada: `MARKETING_VERSION = 0.7.0` e
  `CURRENT_PROJECT_VERSION = 114`, iguais a `resources/version.json` e
  `RELEASE_NOTES.md`.
- Dependências permitidas (SPM, já aprovadas e conectadas):
  - o `firebase-ios-sdk` e todas as dependências transitivas do Google saíram
    no card C05;
  - `himetrica-swift` com versão exata 1.0.0 (revisão `b62348e`, sem
    dependências), aprovado pelo dono no C07. O SDK não instala handlers de
    crash e, no macOS, não registra observers de ciclo de vida;
  - `sentry-cocoa` com versão exata 9.32.0 (revisão `4e1e4ba`), produto
    `Sentry`, aprovado no plano (F33). É um XCFramework estático: o código
    entra no binário do app, e o Xcode embute em `Contents/Frameworks` um
    `Sentry.framework` de 64 KB, sem símbolos, só para levar o
    `PrivacyInfo.xcprivacy` (C08);
  - `swift-timeout` e `LaunchAtLogin` foram removidos no C24 (D4): o timeout
    de processo é do `ProcessRunner` e o "abrir no login" usa
    `SMAppService.mainApp`.
  - Nenhuma dependência nova sem aprovação explícita.
- Requisitos de hardware: Mac com macOS 26+. Para comportamento real, Xcode
  instalado com dados em `~/Library/Developer`. `xcrun simctl` e `pod` são
  opcionais.

## Coordenação dos subagentes

Use os níveis de execução e os papéis definidos e detalhados no `AGENTS.md`,
executados por subagentes que o agente principal cria com a ferramenta em uso:

- Nível 0 (direto): o agente principal executa sem subagentes.
- Nível 1 (padrão): subagente no papel Developer com plano curto → revisão por
  subagente no papel Manager, somente leitura.
- Nível 2 (completo): Manager planeja → Developer implementa e valida →
  Manager revisa.

Correções voltam ao Developer e passam por re-revisão até não restarem
apontamentos `BLOCKING`. A base não fixa agentes, nomes nem modelos; registre
aqui somente preferências ou exceções do projeto.

- Nível mínimo por área ou tipo de tarefa (decorre dos gatilhos de
  concorrência, segurança e integração do `AGENTS.md`):
  - Nível 2 para qualquer mudança em `Core/Cleanup`, `Core/FileSystem`,
    `Core/Process`, `Core/Simulators` ou no `CleanupExecutor`. Esse código
    apaga dados do usuário de forma irreversível e envolve processos, timeout
    e cancelamento.
  - Nível 2 para mudanças em chaves de preferências (`PreferencesStoring`,
    `PreferencesMigrator`: perda de preferências salvas), analytics,
    verificação de atualização e assinatura ou distribuição.

## Arquitetura

Desde o C20 o app tem uma janela única (`Window`), a cena `Settings` e o
`MenuBarExtra(isInserted:)` opcional. O estado vive em ViewModels
`@Observable` (`CleanerViewModel`, `SimulatorsViewModel`, `SettingsViewModel`
e `UpdateViewModel`), montados pelo `AppContainer` e passados explicitamente
às Views. Os detalhes de cada card estão nos adendos do plano.

- Janela (C32, Figma página 08): a cena `Window` usa o id `WindowID.main`
  (`"cleaner"`), abre com `defaultSize` 920×620, aceita no mínimo 760×520
  (`windowResizability(.contentMinSize)`) e o macOS lembra o frame; não há
  ajuste de altura ao conteúdo (`WindowHeightFitter` saiu). A raiz
  `CleanerWindowView` é um `NavigationSplitView`: a barra lateral nativa
  (`CleanerSidebarView`, `List(selection:)` com `.listStyle(.sidebar)`, rodapé
  `SidebarFooterView` em `.safeAreaBar`, com `.scrollEdgeEffectStyle(.soft,
  for: .all)`) e o detalhe (`CleanerDetailView`), um `ScrollView` com a
  página do destino, `.scrollEdgeEffectStyle(.soft, for: .all)` e a
  `ActionBarView` em `.safeAreaBar(edge: .bottom)`. A seleção é o enum puro
  `SidebarDestination`, guardado por janela em `@SceneStorage`; ⌘1–⌘6 vêm de
  `CleanerCommands` (`@FocusedBinding`) e ⌃⌘S de `SidebarCommands`. A sheet de
  confirmação da limpeza fica na raiz. Os textos e as regras ficam em tipos
  puros testados: `ActionBarContent` (adaptador sobre `HeroContent`),
  `SpaceBreakdown`, `CleanerNotice`, `OverviewPresentation`, `SectionSummary`
  e `SimulatorPresentation`.

- Layout (card C04): código em `CleanerXcode/Sources/{App,Core,Features}`,
  recursos em `CleanerXcode/Resources` e testes em `Tests/`, na raiz do repo,
  como root group sincronizado do target `CleanerXcodeTests`.
- Entrada e composição (`Sources/App`):
  - o `init()` de `CleanerXcodeApp.swift` chama `AppEnvironment.current()`
    e `AppContainer.makeServices(environment:configuration:)`, que é uma
    função pura;
  - em teste (`XCTestConfigurationFilePath` ou `XCTestBundlePath`) ou em
    preview (`XCODE_RUNNING_FOR_PREVIEWS=1`) o container entrega
    `NullAnalytics`, `NullErrorReporter`,
    `UserDefaults(suiteName: "didisouzacosta.CleanerXcode.test-host")` e
    serviços inertes (sem disco, `simctl`, login item nem rede);
  - fora de teste entrega `UserDefaults.standard`. O analytics é
    `HimetricaAnalytics` só em Release e com `HIMETRICA_API_KEY` configurada,
    senão `NullAnalytics`. A fábrica (`makeHimetrica`) é injetável para os
    testes nunca configurarem o SDK real;
  - o reporter de erros é `SentryErrorReporter` em Debug e em Release
    (environments `debug` e `production`) sempre que houver `SENTRY_DSN`,
    senão `NullErrorReporter`. O container chama `start()` uma vez; a fábrica
    (`makeErrorReporter`) é injetável e os testes nunca iniciam o SDK real.
    O release é `bundleID@versão+build` e o `dist` é o build;
  - fora de teste e de preview, o `makeCleanerViewModel` roda primeiro o
    `PreferencesDomainMigrator` (C33), que copia do domínio do id antigo as
    chaves de `AppContainer.legacyDomainKeys`, e depois o
    `PreferencesMigrator`. Tudo acontece antes de qualquer ViewModel, dos
    Ajustes, do analytics ou do `AppDelegate` lerem o domínio. Não roda se o
    app for compilado com o id antigo. O leitor do domínio antigo é injetável
    (`legacyPreferences`); os testes passam `{ nil }` ou um domínio de teste;
  - o `HimetricaAnalytics` checa a preferência `send-anonymous-analytics`
    (padrão ligado) a cada evento e só chama `Himetrica.configure` no
    primeiro evento permitido. Ele nunca usa `identify`, `trackScreen` nem os
    modificadores de view do SDK;
  - o `AppDelegate` aplica a regra de fechar a última janela.
- Domínio: `Sources/Core/Models/Version.swift` (o `version.json`) e
  `Sources/Core/Update` (`SemanticVersion`, `VersionChecking`).
- Features (`Sources/Features`):
  - `Cleaner/`: `CleanerViewModel`, `Presentation/` e `Window/` (a janela);
  - `Simulators/`: a página "Simuladores e runtimes" (`SimulatorsPageView`);
  - `Settings/`: Ajustes, painel e rótulo da barra de menus;
  - `Update/`: `UpdateViewModel`.
- Infraestrutura (`Sources/Core`):
  - `Process/`: `ProcessRequest`, `ProcessRunner` e afins (sem shell; não há
    scripts `.sh` desde o C24);
  - `Integrations/`: `Analytics`, `AnalyticsEvent` (eventos estáveis:
    `cleaner`, `cleaner_partial_failure`, `simulator_deleted`,
    `simulator_unavailable_deleted`, `runtime_deleted`, `social`, `donate` e
    `update_opened`, sem caminhos nem tamanhos exatos), `HimetricaAnalytics`,
    `NullAnalytics`, chamados só pelos ViewModels. Também `ErrorReporting` (com
    `ReportableFailure` e `ReportingStage`), `NullErrorReporter`,
    `SentryErrorReporter`, `ErrorReportingConfiguration` e
    `SentryEventSanitizer`. Só esses dois últimos arquivos do Sentry importam
    o SDK; as Views não importam Sentry nem Himetrica;
  - `Cleanup/` (C09, ainda não conectado à interface): o domínio da limpeza
    nativa. `CleanupCategoryID` (as chaves de preferência como rawValue, com
    as sete legadas preservadas), `RiskLevel`, `RemovalMode`,
    `CleanupOperation`, `CleanupTarget`, `CleanupCategory`, `CleanupCatalog`
    (tabela 5.5 do plano, 15 categorias montadas a partir de
    `CleanupLocations`), `SafePathPolicy` (com `PathInspecting` e
    `FileSystemPathInspector`), `CleanupError` (só valores enumerados, sem
    caminho), `CleanupItemResult` e `CleanupReport` (agregação pura: sucesso,
    falha parcial, falha ou cancelado). Os tipos são
    `nonisolated struct/enum … : Sendable`;
  - regras da `SafePathPolicy`:
    - `validateRoot`: a raiz precisa ser do catálogo; não pode ser symlink;
      resolvida, fica dentro de `~/Library` ou de uma pasta temporária e não
      contém `/`, `~` nem `~/Library`. Se falhar, o resultado é
      `.unsupportedRoot` e o alvo é pulado, por exemplo DerivedData
      apontando para um disco externo;
    - `validate`: o item é descendente estrito, sem `.`/`..`, fora de
      `excludedNames` e de raízes aninhadas, sem pasta symlinkada saindo da
      raiz, existente (senão `.notFound`) e no volume da raiz. O volume é
      comparado por `volumeURLKey`, equivalente ao `volumeIdentifierKey`
      citado na N2 do plano;
    - `.unsafePath` é sempre bug e é reportado;
  - `CleanupItemResult` normaliza `.failed(.notFound)` e
    `.failed(.unsupportedRoot)` em `.skipped`, então inexistência nunca vira
    falha (R6). `PathInspecting.existence(of:)` distingue presente, ausente
    (`ENOENT`/`ENOTDIR`) e ilegível, e um item ilegível lança o erro real.
    Um symlink entre a base permitida e a raiz torna a raiz
    `.unsupportedRoot`;
  - `CategorySize` e `CategorySizeMeasurer` (C11): medem as categorias em
    paralelo com um grupo de tarefas e entregam cada resultado no ator de
    quem chama, só se a medição não foi cancelada. Categorias sem alvo não
    geram resultado. As categorias temporárias não podem passar pelo medidor
    bruto; a medição delas vem do C15;
  - `FileSystem/` (C11): `DiskUsageScanning` e `FileSystemSizeScanner`
    (`@concurrent`, sem `du`, sem seguir links, `FileManager` próprio por
    chamada, cancelamento a cada 500 itens). Raiz inexistente ou symlink
    mede 0; raiz ilegível lança `CleanupError`; subitem ilegível conta 0 e
    só a contagem é registrada;
  - pasta temporária (C15): `TemporaryItemsPolicy` (pura: exclusões, dono,
    tipo e idade mínima de 3 dias por padrão; `softened` torna EBUSY e
    permissão "pulado"), `TemporaryItemInspector` (modificação mais
    recente, recursiva; leitura parcial ou cancelada conta como recente;
    pastas com socket, FIFO ou dispositivo dentro são preservadas fora do
    F19), `OrphanSimulatorTempFinder` (UDIDs de `DeviceSet.all(in:)`: set
    padrão + sets auxiliares existentes) e
    `TemporaryFilters`. A medição dessas categorias passa por
    `FilteredContentsMeasurer` via
    `CategorySizeMeasurer.measure(_:filters:...)`, e o `ItemSizeReader`
    mede um item (pasta, link ou arquivo) para o remover e a medição;
  - remoção (C12): `FileRemoving` e `FileSystemRemover` removem os filhos
    diretos da raiz um a um, com `onResult` por item no ator de quem chama
    e o trabalho de disco em helpers `@concurrent`. A
    `SafePathPolicy` é injetada no init e consultada antes de cada remoção.
    `FileOperating` (`FileManagerOperations`: `removeItem` e `trashItem`)
    isola as operações destrutivas, e os testes usam o
    `FileOperationsSpy`, que nunca toca a Lixeira real. O cancelamento
    acontece entre itens, e o resultado de cada item removido sempre chega;
  - `Process/` (C13): `ProcessRequest` (`.xcrun(_:timeout:)` com os prazos
    de 60 s, 600 s e 1.800 s), `ProcessOutput`, `ProcessRunning` e
    `ProcessRunner` (`@concurrent`, sem shell, stdout e stderr lidos em
    paralelo por `readabilityHandler`, porque `FileHandle.bytes` bloqueia o
    pool cooperativo). Prazo e cancelamento terminam o processo com
    `SIGTERM` e esperam só ele sair. Exit diferente de zero vira
    `commandFailed`, com o stderr sanitizado e cortado em 500 caracteres;
  - `Simulators/` (C14): `DeviceSet`, `SimulatorDevice`, `SimulatorRuntime`,
    `SimctlJSON` (DTOs tolerantes a campos ausentes), `SimulatorManaging` e
    `SimctlSimulatorService` (listar, desligar, apagar simuladores
    desligando um a um os ligados antes, `delete unavailable`, `erase all`,
    `delete all` por set, `runtime delete`; o exit 72 e os erros
    `xcrun: error:` viram `.toolUnavailable`),
    `DuplicateSimulatorDetector` (mesmo tipo e runtime, mantém o mais
    recente) e `CoreSimulatorServiceRestarter` (libproc + `SIGTERM`). Os
    testes usam `ProcessRunnerSpy` e `ServiceRestarterSpy` e nunca rodam o
    `simctl` nem sinalizam o serviço real;
  - `Xcode/` (C16): `UserDefaultsPreferencesResetter` (reset do domínio
    `com.apple.dt.Xcode` por `removePersistentDomain`; testes usam domínios
    próprios) e `WorkspaceRunningApplications` (Xcode e Simulator por
    bundle ID; `terminateSimulator()` nunca fecha o Xcode). As restrições do
    R5 ficam em `Cleanup/CleanupRestrictions`, derivadas das flags
    `isBlockedWhileXcodeRuns`, `warnsWhileXcodeRuns` e `shutsDownSimulators`
    do catálogo;
  - `Cleanup/Executor/` (C17): `CleanupPlan`, `CleanupEvent` e
    `CleanupExecutor` (main actor; `execute(_:onEvent:) async ->
    CleanupReport`; ordem fixa: fechar o Simulator e `shutdown all`,
    passos `simctl`, remoções e reset, reinício do CoreSimulatorService só
    depois de remoção direta no F24; cancelamento devolve relatório
    `cancelled` com o que já foi liberado);
  - `Features/Cleaner/` (C19): `CleanerPhase`, `CleanupProgress`,
    `CategoryRowState` (com o planejamento puro das linhas),
    `SimulatorSnapshot`/`SimulatorSnapshotReader`, `CleanerViewModel`
    (`@Observable`; mede sob demanda com debounce de 2 s e cache de 60 s
    na ativação, nunca durante a limpeza; confirma planos de atenção ou
    perigo e os que fechariam simuladores ou têm o Xcode aberto;
    reconfere Xcode e Simulator; relatório até
    dispensar; `retryFailed()` só nas categorias que falharam) e
    `CleanupOutcomeReporter` (analytics e um único erro agregado; a tag
    `failed_categories` vai para `extra` do Sentry). A janela do C20 o usa;
  - `Persistence/`: desde o C18, `PreferencesStoring`,
    `UserDefaultsPreferencesStore` (formato legado `Data` com JSON de
    `Bool`) e `PreferencesMigrator` (v1→v2, uma vez; valores salvos
    preservados; `launch-at-login` entregue ao `SMAppService` uma vez) e,
    desde o C33, `PreferencesDomainMigrator`: cópia crua, uma vez (marcador
    `legacy-domain-migration-version`), sem sobrescrever e sem copiar o schema,
    do domínio `didisouzacosta.CleanerXcode`, lido com
    `persistentDomain(forName:)`. O domínio antigo nunca é gravado nem apagado.
    Vindo da 0.7 (schema < 2), `launch-at-login` é copiado e, se ausente, vira
    `true`; vindo de uma build 1.0 de desenvolvimento, não é copiado;
  - `Platform/` (C18): `MainAppLoginItem` (`SMAppService.mainApp` via
    `AppServiceControlling`; testes com serviço falso);
  - `Helpers/`: `Constants` (URLs via `staticURL(_:)`, que falha alto se o
    literal for inválido) e `Bundle+Extension` (`version` e `build`).
- Testes (`Tests/`): espelham `App/`, `Core/` e `Features/`. `Support/` traz
  os stubs e spies, os fixtures do `simctl`, o `UserDefaults.test`, o
  `TestPreferencesDomain` e o `TemporaryDirectoryFixture`, que
  cria uma pasta exclusiva do teste e a apaga no `deinit` (testes de disco
  nunca tocam dados reais).

Exceções declaradas ao `SWIFT_REFERENCE.md` (card C04):

- `Config.xcconfig`, `Info.plist` e `CleanerXcode.entitlements` ficam na raiz de
  `CleanerXcode/`, porque o `baseConfigurationReferenceRelativePath` e as
  exceções de membership estão ancorados no root group;
- `Tests/` fica na raiz do repo, e não dentro de `CleanerXcode/`, para o gate
  de lint encontrá-lo.

Divergências conhecidas em relação a `.ai/SWIFT_REFERENCE.md`, mantidas até
haver escopo explícito para migrar:

- stores compartilhados no lugar de MVVM por tela;
- nenhum `#Preview`;
- `CleanerButton` e `CleanerStep` declarados junto de outros tipos.

Código novo segue a referência dentro dessas fronteiras, sem reorganizar o
existente por conta própria.

## Estado, concorrência e efeitos

- Fonte de verdade de cada estado:
  - `CleanerViewModel`: fase da janela (`CleanerPhase`), linhas por categoria,
    seleção (persistida no `PreferencesStoring`), restrições de apps abertos e
    o relatório da última limpeza;
  - `SimulatorsViewModel`: fase das listas, simuladores, runtimes, seleção e a
    confirmação pendente; `loadOnActivation()` lista só na primeira ativação
    da janela (a partir de `idle`), e `loadIfNeeded()`, ao abrir a página
    "Simuladores e runtimes", lista de novo depois de lista vazia, falha ou
    ferramentas ausentes. Reativar a janela nunca roda o `simctl` de novo;
  - `SettingsViewModel`: os switches dos Ajustes (store) e o status do login
    item (`SMAppService`);
  - `UpdateViewModel`: a atualização disponível;
  - estado local de View: a página da barra lateral (`@SceneStorage`
    `sidebar-destination`) e "Detalhes" do relatório. Não há seções
    recolhidas desde o C32; as chaves antigas `section-collapsed-*` e
    `simulators-list-expanded` ficam órfãs, sem migração.
- Isolamento de atores e tarefas:
  - com `MainActor` como isolamento padrão, os ViewModels são isolados no main
    actor; o I/O de disco e de processo roda em serviços `@concurrent`
    (`FileSystemSizeScanner`, `FileSystemRemover`, `ProcessRunner`);
  - o `CleanupExecutor` orquestra no main actor e entrega os resultados no ator
    de quem chama;
  - avalie tudo isso com a skill `swift-concurrency` antes de mexer.
- Cancelamento e invalidação de resultados obsoletos:
  - medições têm geração: uma medição nova cancela a anterior e só a mais nova
    muda o estado; nada é medido durante confirmação ou limpeza;
  - a limpeza é cancelada entre itens e sempre devolve relatório;
  - o processo filho recebe `SIGTERM` no cancelamento e no timeout;
  - as listagens da seção de simuladores têm geração, e uma exclusão invalida
    as anteriores.
- Limites de trabalho: sem polling. A janela mede ao abrir e ao ser ativada,
  com debounce de 2 s e cache de 60 s; o `simctl` tem timeouts de 60, 600 e
  1.800 s conforme a operação.
- Permissões, rede, arquivos e outros efeitos:
  - a limpeza apaga só o conteúdo das raízes do catálogo fechado
    (`SafePathPolicy`), manda os itens perigosos para a Lixeira, usa `simctl`
    por API e confirma itens de atenção e perigosos; por isso o app não usa
    sandbox;
  - a rede se limita a `URLSession.shared` para o `version.json` e, em Release
    com chave e com a preferência "Enviar estatísticas de uso" ligada (opt-out,
    padrão ligado), aos eventos do Himetrica;
  - o Himetrica 1.0.0 grava `hm_visitor_id` (UUID aleatório) em
    `UserDefaults.standard` (o C33 o copia do domínio do id antigo, com o nome
    espelhado em `HimetricaAnalytics.visitorIDKey`) e envia `visitorId`,
    `sessionId`, um User-Agent com as versões do app e do macOS e, como toda
    requisição, o IP. Isso é
    dado pseudônimo, não anônimo;
  - **limitação do SDK (C07):** a fila offline fica em
    `~/Library/Application Support/Himetrica/EventQueue`, sem namespace por
    bundle. Num app sem sandbox, outro app com o mesmo SDK pode compartilhar
    essa fila, e um evento enfileirado de um app pode ser reenviado com a
    chave do outro. Nunca chame `Himetrica.reset()`, porque ele apaga a fila
    de todos. A mitigação depende do dono (ver plano, seção 9);
  - nenhum Release com `HIMETRICA_API_KEY` é distribuído antes do C22, que traz
    o toggle de opt-out;
  - com `SENTRY_DSN`, o Sentry envia crashes (inclusive `NSException` não
    capturada) e um único evento `cleanup_partial_failure` (warning) por
    limpeza com falha, com tags de resultado, categorias e tipos de erro e
    contagens. O `CleanupOutcomeReporter` deixa os breadcrumbs `cleanup_started`
    e `cleanup_finished`. Opções: `sendDefaultPii = false`,
    `enableAutoSessionTracking = false` (as sessões levam o installation ID
    do Sentry e não passam pelo `beforeSend`), `tracesSampleRate = 0`;
  - o `SentryEventSanitizer` (funções `nonisolated static`, usadas direto em
    `beforeSend` e `beforeBreadcrumb`) remove `user`, `serverName` e
    `context.app.device_app_hash` (SHA1 do MAC de `en0`, do modelo e do bundle
    ID), troca `/Users/<nome>` (sem diferenciar maiúsculas) por `~` e caminhos
    em `/var/folders` por `<tmp>`, e trunca textos em 1024 caracteres. Vale
    para mensagem, exceções (valor, `mechanism.desc` e `mechanism.data`),
    frames, threads, `debugMeta`, `context` (inclusive o `user info` de
    NSError/NSException), tags, extras e breadcrumbs. O `beforeSend` é a única
    barreira: no macOS o SDK não registra outro event processor;
  - ações do dono no painel do Sentry antes do primeiro Release com DSN:
    ligar Data Scrubbing e "Prevent Storing of IP Addresses";
  - `openURL` abre os links externos;
  - o `SMAppService.mainApp` registra o item de login.

## Regras de implementação

- Injete serviços e protocolos nas fronteiras de comportamento
  (`DiskUsageScanning`, `FileRemoving`, `ProcessRunning`, `SimulatorManaging`,
  `CleanupExecuting`, `PreferencesStoring`, `LoginItemManaging`,
  `VersionChecking`, `Analytics`, `ErrorReporting`).
- Use dublês nos testes e nas previews (stubs e spies em `Tests/Support`,
  serviços inertes do `AppContainer`, fakes `*Preview`). Testes e previews
  nunca leem o disco real, rodam `simctl`, tocam no login item, no domínio
  real do Xcode, na Lixeira nem na rede.
- Preserve cancelamento, isolamento e tratamento de erros.
- Toda categoria nova de limpeza entra pelo `CleanupCatalog`, com risco,
  padrão seguro (desligado para operações amplas ou irreversíveis), seção em
  `CleanerSection`, texto em `CategoryPresentation` e testes. Nenhuma
  categoria nova sem aprovação do dono.
- Não renomeie as chaves de preferência sem plano de migração: as categorias
  antigas usam o nome do script como chave em `UserDefaults`.
- Ao mudar a versão, atualize juntos `MARKETING_VERSION`,
  `CURRENT_PROJECT_VERSION`, `resources/version.json` e `RELEASE_NOTES.md`.
- Textos de interface vão para `Localizable.xcstrings` (fonte `en`, com
  tradução `pt-BR`).
- Não adicione dependências sem aprovação explícita.
- Mantenha segredos fora do repositório: chaves só no `Secrets.xcconfig`, que é
  ignorado pelo git, nunca no `Config.xcconfig` nem em código. O
  `MIXPANEL_TOKEN` antigo saiu no C06; o dono precisa revogá-lo no Mixpanel,
  porque ele continua no histórico do git.
- Preserve alterações locais não relacionadas.

## Estilo e formatação Swift

- Convenção geral: [Google Swift Style Guide](https://google.github.io/swift/),
  com a exceção declarada de 4 espaços e 120 colunas, aplicada a todo código Swift, incluindo testes.
- Cadeias de modificadores SwiftUI: cada modificador em sua própria linha,
  conforme os exemplos da Apple em
  [Configuring Views](https://developer.apple.com/documentation/swiftui/configuring-views).
- `MARK:` obrigatório e espaçamento entre blocos conforme `SWIFT_REFERENCE.md`.
- Bootstrap/update sincronizam `.swiftlint.yml`, `.swiftformat`, `scripts/lint-swift.sh` e `scripts/fix-swift-spacing.pl` com manifesto e proteção de conflitos.
- Baseline desta base: SwiftLint 0.63.2 e SwiftFormat 0.63.0; confirme a instalação no consumidor e no CI.
- `scripts/lint-swift.sh` é o gate executável local/CI, verifica versões e cobre somente fontes, testes e `Package.swift` nos caminhos do consumidor. Conecte esse comando ao job obrigatório de CI do projeto.
- A base não distribui workflow de CI; chame `scripts/install-swift-tools.sh` e `scripts/lint-swift.sh` no CI do projeto (por exemplo, `ci_scripts/ci_post_clone.sh` no Xcode Cloud).
- Formate desde a criação: `scripts/lint-swift.sh --fix`; rascunhe MARKs ausentes com `scripts/lint-swift.sh --add-marks` e revise os nomes.
- Ferramentas: `scripts/lint-swift.sh` baixa sozinho as versões fixas (com SHA-256 conferido) para o cache por usuário `~/Library/Caches/swift-quality-tools` quando não as encontra no `PATH` ou no Homebrew; `scripts/install-swift-tools.sh` faz o mesmo antecipadamente (CI, Xcode Cloud, trabalho offline).
- Fase de build do Xcode (target sem sandbox de scripts): `scripts/lint-swift.sh --format-only`.
- Estado no projeto:
  - o projeto ainda não tem CI nem fase de build de lint;
  - SwiftLint e SwiftFormat não estão no `PATH` desta máquina (verificado em
    2026-10-31), então o script usa o cache por usuário;
  - no C04 (2026-10-31) todo o código passou pelo `--fix` e pelo gate:
    `Found 0 violations, 0 serious in 53 files`;
  - o `scripts/lint-swift.sh --add-marks` chama `swiftlint` pelo `PATH` e
    falha quando as ferramentas estão só no cache. Para rodar, use
    `PATH="$HOME/Library/Caches/swift-quality-tools/swiftlint-0.63.2:$PATH" scripts/lint-swift.sh --add-marks`.
    É um defeito do script da base compartilhada, a reportar lá.
- Exceções locais justificadas: nenhuma registrada.

## Previews SwiftUI

- Toda `View` criada deve ter `#Preview` para cada estado de apresentação
  suportado, incluindo os estados de carregamento, vazio, erro e sucesso quando
  fizerem parte do contrato da tela.
- Use `@Previewable` em cada propriedade dinâmica local necessária para
  configurar esses estados dentro do corpo de `#Preview`. Esse macro só é
  válido nesse corpo e não substitui a declaração dos previews para cada estado.
- Injete dados e dependências determinísticos; não conecte previews a serviços
  reais, rede, autenticação ou arquivos mutáveis do usuário.
- Convenção confirmada com a documentação da Apple:
  [Previewable](<https://developer.apple.com/documentation/swiftui/previewable()>).
- No CleanerXcode:
  - cada View tem `#Preview` por estado, com fakes em arquivos próprios
    (`CleanerWindowPreview`, `SimulatorsSectionPreview`, `SettingsPreview`,
    `MenuBarPanelPreview`, `UpdatePreview`) e locais inertes;
  - os prints para o dono saem de um harness temporário que renderiza as
    previews fora da tela (`NSHostingView.cacheDisplay`); glass e estilos de
    botão não aparecem nesse método;
  - nunca use `Bundle.main` para buscar versão em preview.

## Testes e validação

Registre comandos e resultados reais. Separe compilação e Simulator de
validação em dispositivo físico e de serviços externos.

- Testes unitários:
  - Swift Testing (`import Testing`) no target `CleanerXcodeTests`, com os
    fontes em `Tests/`. No C04 eram 45 casos: os 35 anteriores mais
    `AppEnvironmentTests`, `AppConfigurationTests` e `AppContainerTests`;
  - comando usado (com DerivedData temporário e sem assinatura):

    ```bash
    xcodebuild test -project CleanerXcode.xcodeproj -scheme CleanerXcode -destination 'platform=macOS' -derivedDataPath <temporário> CODE_SIGNING_ALLOWED=NO
    ```

  - resultado em 2026-10-31, Xcode 27.2: `** TEST SUCCEEDED **`, 35 passaram
    e 0 falharam. `ShellTests/ensureTimeoutError()` leva cerca de 5 s.
    Repetido no C02 com o scheme compartilhado e o test plan: 35 passaram.
    No C04, com build limpo: 45 passaram, sem avisos. No C08: 96 testes
    (101 execuções com os parametrizados) passaram, sem avisos. No C09: 148
    execuções passaram, sem avisos. No C11: 165 execuções passaram, sem
    avisos. No C12: 184 execuções passaram, sem avisos. No C13: 196 execuções
    passaram, sem avisos. No C14: 217 execuções passaram, sem avisos. No C15: 242 execuções
    passaram, sem avisos. No C16: 256 execuções passaram, sem avisos. No C17: 278 execuções
    passaram, sem avisos. No C18: 295 execuções passaram, sem avisos. No C19: 325 execuções
    passaram, sem avisos. No C20: 345 execuções passaram, sem avisos. No C21: 370
    execuções passaram, sem avisos. No C22: 389 execuções passaram, sem avisos. No C23: 405 execuções passaram, sem avisos. No C24: 368 execuções passaram, sem avisos (saíram os testes do código antigo). No C25: 376 execuções passaram, sem avisos. No alinhamento ao Figma (AC30b): 401 execuções passaram, sem avisos. No C32: 432 testes únicos passaram (476 casos executados, porque os testes parametrizados contam cada argumento à parte), sem avisos; saíram os `WindowFittingTests`. Nas correções da conferência visual do C32: 438 testes únicos (482 casos executados), sem avisos. No C33: 458 testes únicos (507 casos executados), sem avisos;
  - teste focado: acrescente `-only-testing:CleanerXcodeTests/<Suite>` ao
    mesmo comando;
  - avisos do compilador: nenhum desde o C03. Avisos novos no código
    alterado são defeitos;
  - o teste de debounce ainda espera tempo real; a referência pede espera
    explícita.
- Testes de integração: o `ProcessRunner` roda processos reais inofensivos
  (`/bin/echo` e afins). Nenhum teste executa limpeza real, e não deve
  executar.
- Build: `xcodebuild build -project CleanerXcode.xcodeproj -scheme CleanerXcode -destination 'platform=macOS'`.
  Desde o C24 a resolução de pacotes não precisa mais de acesso SSH ao GitHub.
- Simulator: não se aplica, porque o app é macOS nativo. A validação local
  roda no próprio Mac (`platform=macOS`). Não use XCUIAutomation nem testes de
  UI.
- Dispositivo físico: o equivalente é rodar a build no Mac e conferir a
  limpeza real. Isso apaga dados do usuário, então só faça em ambiente
  descartável ou com autorização explícita.
- Serviços live: `version.json` no branch `main` do GitHub. O Himetrica está
  integrado desde o C07 e o Sentry desde o C08, mas o envio real de ambos fica
  sem validação até haver a chave e o DSN (C28).
- Lint: `scripts/lint-swift.sh --fix` e depois `scripts/lint-swift.sh`. Desde
  o C04 o gate cobre `CleanerXcode/Sources` e `Tests` e passa com 0
  violações.
- Validações ainda não executadas:
  - build Release assinada (Developer ID) e notarizada;
  - limpeza real e comparação do espaço liberado com o estimado;
  - envio de eventos ao Himetrica e de erros ao Sentry (C28);
  - abrir no login com o app instalado em `/Applications`.

## Entrega

- Checklist de aceitação:
  - testes focados e a suíte completa passando;
  - build macOS sem avisos novos;
  - `scripts/lint-swift.sh --fix` e `scripts/lint-swift.sh` executados nos
    arquivos alterados;
  - strings novas localizadas em `pt-BR`;
  - nenhuma execução dos scripts destrutivos fora de stubs;
  - preferências existentes preservadas.
- Arquivos de documentação a atualizar:
  - `.ai/PROJECT_BRIEF.md` quando mudar fluxo, estado, recurso ou
    pendência;
  - este guia quando mudar baseline, arquitetura ou comandos;
  - `README.md` para requisitos ou recursos públicos;
  - `RELEASE_NOTES.md` e `resources/version.json` em cada release.
- Release com Sentry (D9): depois do archive, o dono envia os dSYMs com o
  `sentry-cli` instalado localmente (Homebrew), fora do build do app:

  ```bash
  sentry-cli debug-files upload --org <org> --project <projeto> <pasta-dos-dSYMs>
  ```
- Artefatos temporários a limpar: DerivedData e `.xcresult` criados em
  caminhos temporários da tarefa, além de logs e capturas próprias. Preserve
  o DerivedData compartilhado e os caches do SwiftPM. `build/` e o DMG em
  `releases/` são entregáveis de release, não temporários.
- Estado de commit esperado: sem commit, salvo pedido explícito. O branch
  atual é `v1.0.0` e o principal é `main`.
- Riscos conhecidos:
  - operações destrutivas e irreversíveis no disco do usuário;
  - falhas silenciosas na limpeza;
  - processo filho não encerrado no cancelamento ou timeout;
  - token versionado;
  - dependência por SSH sem versão fixa;
  - scheme não compartilhado para CI;
  - comparação de versões frágil com componentes de dois dígitos.
