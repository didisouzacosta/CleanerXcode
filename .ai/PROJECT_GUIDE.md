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
feature disponível. Exemplos atuais: `import Charts` e `import TipKit`. Não faça migrações de
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
  - targets `CleanerXcode` (app, bundle `didisouzacosta.CleanerXcode`) e
    `CleanerXcodeTests` (bundle de testes);
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
  - `swift-timeout` (up to next major, a partir de 0.2.1; resolvido em 0.4.1):
    `withThrowingTimeout` em `Shell`;
  - `LaunchAtLogin` (fork `git@github.com:didisouzacosta/LaunchAtLogin-Modern.git`,
    branch `main`), que exige acesso SSH ao GitHub. O produto aparece duas
    vezes nas referências do target.
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
  - Nível 2 para qualquer mudança em `Resources/Scripts/*.sh`,
    `Shell`, `CommandExecutor` ou no fluxo `CleanerStore.clear()`. Esse código
    apaga dados do usuário de forma irreversível e envolve processos, timeout
    e cancelamento.
  - Nível 2 para a migração para Swift 6, mudanças em chaves de
    `Preferences`/`StoragedValue` (perda de preferências salvas), analytics,
    verificação de atualização e assinatura ou distribuição.

## Arquitetura

O app é pequeno, com uma única cena `MenuBarExtra`. O estado vive em stores
`@Observable` compostos na raiz e distribuídos por `.environment`. Não há
ViewModels por tela.

- Layout (card C04): código em `CleanerXcode/Sources/{App,Core,Features}`,
  recursos em `CleanerXcode/Resources` e testes em `Tests/`, na raiz do repo,
  como root group sincronizado do target `CleanerXcodeTests`.
- Entrada e composição (`Sources/App`):
  - o `init()` de `CleanerXcodeApp.swift` chama `AppEnvironment.current()`
    e `AppContainer.makeServices(environment:configuration:)`, que é uma
    função pura;
  - em teste (`XCTestConfigurationFilePath` ou `XCTestBundlePath`) ou em
    preview (`XCODE_RUNNING_FOR_PREVIEWS=1`) o container entrega
    `InertCommandExecutor`, que não roda scripts, `NullAnalytics`,
    `NullErrorReporter` e
    `UserDefaults(suiteName: "didisouzacosta.CleanerXcode.test-host")`;
  - fora de teste entrega `Shell` e `Preferences(.standard)`. O analytics é
    `HimetricaAnalytics` só em Release e com `HIMETRICA_API_KEY` configurada,
    senão `NullAnalytics`. A fábrica (`makeHimetrica`) é injetável para os
    testes nunca configurarem o SDK real;
  - o reporter de erros é `SentryErrorReporter` em Debug e em Release
    (environments `debug` e `production`) sempre que houver `SENTRY_DSN`,
    senão `NullErrorReporter`. O container chama `start()` uma vez; a fábrica
    (`makeErrorReporter`) é injetável e os testes nunca iniciam o SDK real.
    O release é `bundleID@versão+build` e o `dist` é o build;
  - o `HimetricaAnalytics` checa a preferência `send-anonymous-analytics`
    (padrão ligado) a cada evento e só chama `Himetrica.configure` no
    primeiro evento permitido. Ele nunca usa `identify`, `trackScreen` nem os
    modificadores de view do SDK;
  - no `onAppear` do rótulo, `LaunchAtLogin` e `checkUpdates()` são pulados no
    host de testes;
  - `Route` e `MainView` também ficam em `Sources/App`.
- Domínio: `Sources/Core/Models` (`UsedSpace`, `Version`) e
  `Sources/Core/Contracts` (`ApplicationInfo`, com implementação padrão que
  baixa e decodifica o `version.json`). `Bundle` conforma a `ApplicationInfo`.
- Features (`Sources/Features`):
  - `Cleaner/`: `CleanerView` (com o `CleanerButton` privado), `CleanerStore`
    e `Components/` (`ExpandableButton`, `HighlightButton`,
    `ScrollContentHeightModifier`, `CustomCircularProgressViewStyle`);
  - `Settings/`: `PreferencesView`;
  - `Update/`: `UpdateStore`.
- Infraestrutura (`Sources/Core`):
  - `Process/`: o protocolo `CommandExecutor`, a implementação `Shell`, o
    `InertCommandExecutor` e o catálogo `Command`. Os scripts `.sh` ficam em
    `Resources/Scripts`;
  - `Integrations/`: `Analytics`, `AnalyticsEvent` (eventos estáveis:
    `cleaner`, `cleaner_partial_failure`, `simulator_deleted`,
    `simulator_unavailable_deleted`, `runtime_deleted`, `social`, `donate` e
    `update_opened`, sem caminhos nem tamanhos exatos), `HimetricaAnalytics`,
    `NullAnalytics` e `AnalyticsTracker`, o adaptador `@Observable` que as
    Views recebem por `.environment`. Também `ErrorReporting` (com
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
  - remoção (C12): `FileRemoving` e `FileSystemRemover` removem os filhos
    diretos da raiz um a um, com `@concurrent` e `onResult` por item. A
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
    `commandFailed`, com o stderr sanitizado e cortado em 500 caracteres. O
    `Shell` antigo continua até o C24;
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
  - `Persistence/`: `Preferences` e `StoragedValue`;
  - `Helpers/`: `Constants` (URLs via `staticURL(_:)`, que falha alto se o
    literal for inválido), `StateValue` e as extensões. `String` conforma a
    `Error`/`LocalizedError` por `@retroactive`, e os erros são lançados como
    strings.
- Testes (`Tests/`): espelham `App/`, `Core/` e `Features/`. `Support/` traz
  os stubs, os scripts de teste (`Support/Scripts`), o `UserDefaults.test`, o
  `Bundle.test`, o helper `waitUntil` e o `TemporaryDirectoryFixture`, que
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
  - `CleanerStore`: `usedSpace` (`StateValue<UsedSpace>`), `status`,
    `steps` e os comandos ativos, derivados de `Preferences`;
  - `UpdateStore`: `hasUpdate` (`StateValue<Bool>`) e `version`;
  - `Preferences`: um `StoragedValue<Bool>` por opção;
  - `Route`: `path`;
  - estado local de View: `isFirstOpen` no rótulo da barra e
    `contentHeight` nas preferências.
- Isolamento de atores e tarefas:
  - com `MainActor` como isolamento padrão, stores, `Shell` e o protocolo
    `CommandExecutor` são isolados no main actor;
  - `clear()` roda os comandos em sequência numa `Task` no main actor e checa
    o cancelamento entre os comandos. Depois espera 1 s antes do sucesso e
    2 s antes de voltar a `idle`. A pausa de "0,5 s" por passo nunca existiu,
    porque `Double.second` trunca para 0; os timers somem no C19;
  - `Shell.run` fica no main actor, mas o `Process`, o `readToEnd` e o
    `waitUntilExit` rodam em `@concurrent nonisolated static func execute`,
    fora dele. Isso é necessário porque a `withThrowingTimeout` é
    `nonisolated(nonsending)` e herda o isolamento de quem chama;
  - o callback do `Timer`, agendado no `RunLoop.main`, usa
    `MainActor.assumeIsolated`;
  - o helper de teste `waitUntil` é `async` (com `Task.sleep`) para não
    bloquear o main actor.
  - Avalie tudo isso com a skill `swift-concurrency` antes de mexer.
- Cancelamento e invalidação de resultados obsoletos:
  - `clear()` e `calculateFreeUpSpace()` cancelam a `Task` anterior antes de
    criar outra;
  - `stopTimer()` cancela o cálculo e invalida o `Timer`;
  - `Shell.cancel()` cancela só a última `task`, e o `Process` filho não
    recebe `terminate()` nem no cancelamento nem no timeout.
- Limites de memória e trabalho pendente: cada script tem timeout padrão de
  10 s. O cálculo é reagendado ~6 s depois de cada execução, o que mantém um
  `du -sk` periódico em `~/Library`. A saída do processo é lida inteira com
  `readToEnd()`.
- Permissões, rede, arquivos e outros efeitos:
  - os scripts apagam com `rm -rf`, `xcrun simctl delete unavailable`,
    `defaults delete com.apple.dt.Xcode` e `pod cache clean --all`, sem
    confirmação; por isso o app não usa sandbox;
  - a rede se limita a `URLSession.shared` para o `version.json` e, em Release
    com chave e com a preferência "Enviar estatísticas de uso" ligada (opt-out,
    padrão ligado), aos eventos do Himetrica;
  - o Himetrica 1.0.0 grava `hm_visitor_id` (UUID aleatório) em
    `UserDefaults.standard` e envia `visitorId`, `sessionId`, um User-Agent
    com as versões do app e do macOS e, como toda requisição, o IP. Isso é
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
    contagens. O `CleanerStore` deixa os breadcrumbs `cleanup_started` e
    `cleanup_finished`. Opções: `sendDefaultPii = false`,
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
  - `LaunchAtLogin` registra o item de login.

## Regras de implementação

- Injete serviços e protocolos nas fronteiras de comportamento
  (`CommandExecutor`, `Analytics`, `ApplicationInfo`, `UserDefaults` em
  `Preferences`).
- Use dublês nos testes e nas previews (`CommandExecutorStub`,
  `AnalyticsStub`, `UserDefaults.test`). Nunca execute os scripts reais de
  limpeza em testes ou previews.
- Preserve cancelamento, isolamento e tratamento de erros.
- Todo script novo em `CleanerXcode/Resources/Scripts/` precisa de:
  - um `Command` estático e a entrada em `Command.commands`;
  - uma preferência com chave igual ao nome do script e um padrão seguro
    (desligado para operações amplas ou irreversíveis);
  - o tamanho em `calculate-free-up-space.sh`, `UsedSpace` e
    `CleanerStore.size(of:)`, quando aplicável;
  - o toggle em `PreferencesView` e testes.
- Não renomeie scripts nem chaves de preferência sem plano de migração, porque
  a chave em `UserDefaults` é o nome do script.
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
  - as Views atuais não têm `#Preview`;
  - os estados relevantes do `CleanerButton` são `idle` com e sem espaço,
    `isCleaning`, `isCompleted` e `error`;
  - as previews precisam de um `CommandExecutor` falso que nunca rode
    `Shell`, de `Preferences` com `UserDefaults` isolado e de um `Analytics`
    nulo;
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
    passaram, sem avisos. No C14: 217 execuções passaram, sem avisos;
  - teste focado: acrescente `-only-testing:CleanerXcodeTests/<Suite>` ao
    mesmo comando;
  - avisos do compilador: nenhum desde o C03. Avisos novos no código
    alterado são defeitos;
  - alguns testes usam `Task.sleep`/`waitUntil` com tempo real; a referência
    pede espera explícita.
- Testes de integração: `ShellTests` roda scripts de teste reais por
  `/bin/bash`. Nenhum teste executa os scripts de limpeza, e não deve
  executar.
- Build: `xcodebuild build -project CleanerXcode.xcodeproj -scheme CleanerXcode -destination 'platform=macOS'`.
  A resolução de pacotes precisa de acesso SSH ao GitHub por causa do
  `LaunchAtLogin`.
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
