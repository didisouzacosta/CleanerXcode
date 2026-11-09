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
  barra lateral nativa (Visão geral, as quatro seções, Simuladores e
  runtimes e, desde o C40, a seção Ajustes com Geral e Sobre); o conteúdo do
  detalhe rola e a barra de ação, com o total e a ação principal, fica sempre
  visível nas páginas de limpeza (C32, Figma página 08). Na Visão geral,
  "Simuladores e runtimes" ocupa a linha inteira e as quatro seções ficam em
  1, 2 ou 4 colunas iguais, nunca 3 (C40). O fundo do conteúdo é `#F7F7F9`
  no claro (C40).
- O conteúdo rola por baixo da toolbar e da barra de ação, sem corte seco, e
  toda rolagem usa o efeito de borda suave (blur) no topo e na base (pedido do
  dono no C32). A exceção é o topo da coluna de detalhe da janela principal, sob
  o título e o subtítulo da toolbar: enquanto há conteúdo por baixo, ele usa o
  efeito de borda rígido (`.hard`), para o conteúdo não aparecer através do
  título (pedido do dono em 2026-11-03). Em repouso volta ao suave, sem faixa
  nem linha. A base, sob a barra de ação, continua sempre suave.
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
    Na 1.0, desde o C40, os Ajustes são páginas da barra lateral (Ajustes ›
    Geral e Sobre, ⌘7 e ⌘8), abertas também por "Ajustes…" (⌘,) e pela
    engrenagem do painel da barra de menus; não há janela de Ajustes nem
    engrenagem na toolbar.
  - Atualização: se o `version.json` remoto tiver versão maior que a
    instalada, aparece o botão "Update", que abre o link do DMG. Na 1.0,
    desde o C40, é um botão redondo com seta ao lado de "Versão x (y)", no
    rodapé da barra lateral e no Sobre.
  - Links sociais (GitHub, X, LinkedIn) e doação (Stripe) abrem no navegador.
  - Sugestão de doação (1.0, C31): a cada 5 limpezas bem-sucedidas (5ª, 10ª…),
    contadas entre aberturas, o sucesso troca "OK" por "Apoiar o projeto"
    (rosa, com coração) e "Fechar" em texto, e o detalhe passa a "Gostou?
    Qualquer valor ajuda — 100% vai para abrigos e hospitais". "Apoiar o
    projeto" abre a folha "Apoie o CleanerXcode" e o resultado volta ao
    sucesso comum com OK; só "Doar qualquer valor" na folha abre o Stripe e
    registra `donate`; "Agora não" e Esc só fecham. O painel da barra de menus
    mostra a mesma sugestão e "Apoiar" abre a janela principal com a folha.
    Falha parcial, falha, cancelamento e permissão negada não contam nem
    sugerem. O rodapé da barra lateral e o Sobre continuam abrindo o Stripe
    direto.
  - Sair (`Quit`) encerra o app.

### Estados

- Rótulo da barra de menus (quando "Display Free Up Space In Menu Bar" está
  ligado): "Cleaning" durante a limpeza; "Calculating" apenas no primeiro
  cálculo com total zero; depois o tamanho liberável formatado. Na 1.0, desde
  o C40, a medição em segundo plano mantém o último tamanho até chegar o novo,
  e o tamanho acompanha as pastas em tempo real (C40 · tempo real): só a
  linha da categoria que mudou é medida de novo, sem voltar a "Calculating".
- `CleanerStore.Status`: `idle` (botão azul, "Clear" ou "Clear <tamanho>"),
  `isCleaning` (verde, progresso `steps/commands`, sem toque), `isCompleted`
  (verde, sucesso, sem toque) e `error` (vermelho, "Try again").
- Carregamento: `usedSpace` (`StateValue<UsedSpace>`) fica em `isLoading`
  durante o cálculo; o resultado é recalculado após cada comando concluído, ao
  fim da limpeza e a cada ~6 s por um `Timer` reprogramado após cada cálculo.
  Na 1.0 não há esse timer: a janela mede ao abrir e ao ser ativada e, desde o
  C40, o app mede em segundo plano para o ícone da barra de menus (ver Limites
  conhecidos).
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
  - Baixar runtimes (C30), na página "Simuladores e runtimes": um cartão
    abaixo da lista de runtimes (ou do cartão de status no estado vazio) abre,
    por "Escolher…", a folha "Baixar runtimes" com iOS, watchOS, tvOS e
    visionOS, cada uma com os runtimes já instalados, e nada selecionado. O
    primário "Baixar N runtimes" baixa as escolhidas uma de cada vez, na ordem
    fixa, por `xcrun xcodebuild -downloadPlatform <plataforma>`, sem shell,
    para a versão do Xcode selecionado. O cartão mostra o item atual com a
    posição ("2 de 3"), o que terminou e o que está na fila, e "Cancelar".
    Desde o C34, quando a saída do `xcodebuild` mostra o progresso, o título
    traz a porcentagem do item atual ("Baixando o runtime do iOS… 42%"), uma
    barra determinada fica entre o título e a legenda, e a legenda começa com
    o tempo estimado ("Cerca de 12 min restantes", calculado pelos bytes e
    mostrado só depois de 10 s); depois de 100% vem "Instalando o runtime do
    iOS…", e enquanto a lista é atualizada depois do último item,
    "Atualizando a lista de runtimes…". Sem linha reconhecida, o progresso
    fica indeterminado, como no C30. Cada runtime instalado aparece na lista
    na hora, sem esperar o fim da fila; no fim, tudo instalado, falha (o motivo de cada plataforma e "Tentar de
    novo", que refaz só as falhas) ou cancelado ("Escolher…" de novo). Uma
    falha não para a fila, salvo sem as ferramentas do Xcode. Nada começa
    durante uma limpeza ou exclusão; "Remover" dos runtimes fica bloqueado
    enquanto baixa; o download continua ao sair da página, é cancelado ao sair
    do app e tem prazo de 6 h por item. Sem evento de analytics novo.
  - Versões anteriores de runtime (C35): cada plataforma da folha "Baixar
    runtimes" ganha, à direita, um seletor de versão. A primeira opção é
    sempre a versão do Xcode selecionado ("27.2 (Xcode) · 8,32 GB", o
    download do C30, sem `-buildVersion`); depois vêm as versões finais do
    catálogo público da Apple estritamente menores que o SDK daquela
    plataforma, da mais nova à mais antiga, com o tamanho, sem as já
    instaladas e nunca uma mais nova que o Xcode. Escolher uma versão marca a
    plataforma; desmarcar mantém a versão escolhida; uma versão por
    plataforma em cada fila. A fila passa `-buildVersion <versão>` por
    plataforma ao `xcodebuild`, e o cartão nomeia a versão ("Baixando o
    runtime do iOS 26.5… 42%", "iOS 26.5 instalado", "Na fila: iOS 26.5,
    watchOS"); "Tentar de novo" repete as mesmas versões. A folha abre na
    hora e carrega as versões enquanto está aberta ("Carregando versões
    anteriores…"); fechar a folha cancela a leitura. O catálogo
    (`index2.dvtdownloadableindex` em `devimages-cdn.apple.com`) é lido só ao
    abrir a folha e com o cache vencido (o intervalo do catálogo, limitado a
    1 h…7 d; hoje 24 h); sem rede, um cache de até 30 dias serve. Sem rede e
    sem cache, catálogo ilegível ou sem a versão do SDK, a folha mostra só a
    versão do Xcode, com a nota "As versões anteriores não estão disponíveis
    agora…" e "Tentar de novo", e funciona como no C30. Uma versão recusada
    pelo Xcode ("… is not available for download.", em qualquer saída e com
    qualquer código) termina como "Indisponível para o Xcode selecionado",
    sem nada instalado. Com uma versão anterior escolhida, a folha avisa que
    versões anteriores servem para testar em sistemas mais antigos.
- Recursos premium ou condicionais: não há recursos pagos. A doação é opcional,
  por link externo.
- Limites conhecidos:
  - A remoção é definitiva (`rm -rf`), sem Lixeira, confirmação ou desfazer.
  - Remove Old Simulators e Reset Xcode Preferences não entram no total
    liberável estimado.
  - Comandos lentos (Derived Data ou CoreSimulator grandes) podem passar dos
    10 s de timeout.
  - Na 0.x, o cálculo com `du` rodava continuamente a cada ~6 s. Na 1.0,
    desde o C40, o app mede tudo em segundo plano 30 s depois de abrir e a
    cada 30 min, só com o item da barra de menus e o tamanho ligados; uma
    medição recente adia a próxima, a exclusão de simuladores adia 2 min,
    Pouca Energia ou o Mac quente pulam os ticks periódicos e o sleep pausa o
    laço (o wake recomeça com 2 min). Desde o C40 · tempo real, com as
    mesmas condições, o FSEvents observa as pastas medidas: cada categoria
    medida em disco (as 11 observadas, todas as categorias medidas em disco,
    selecionadas ou não) é medida de novo cerca de 5 s depois que a mudança
    para, no máximo 1×/min por categoria em atividade contínua, sem custo sem
    mudanças; nada roda durante limpeza ou exclusão de simuladores, em Pouca
    Energia, com o Mac quente ou em repouso. Os temporários, as pastas órfãs
    do `/private/var/tmp`, os simuladores antigos e o reset das preferências
    só mudam no cálculo completo (janela, painel ou laço de 30 min).
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
  `launch-at-login`. Na 1.0, `successful-cleanup-count` (C31, `Int`) conta as
  limpezas bem-sucedidas para a sugestão de doação; ausente, ilegível ou
  negativo vale 0, e a chave não entra na migração de domínio.
- Sincronização ou serviços externos:
  - GitHub raw (`VERSION_FILE_URL` em `Config.xcconfig` → `Info.plist`) para
    a versão e o DMG;
  - catálogo público de runtimes da Apple (C35): um GET sem autenticação nem
    cookies a `https://devimages-cdn.apple.com/downloads/xcode/simulators/index2.dvtdownloadableindex`,
    em sessão `ephemeral`, só ao abrir "Baixar runtimes" e no máximo uma vez
    por intervalo do catálogo (24 h hoje); o filtrado fica em
    `~/Library/Caches/<bundle id>/simulator-runtime-catalog.json`
    (`formatVersion` 1, revalidado na leitura). Nada do usuário é enviado; a
    Apple vê o IP e o User-Agent padrão da `URLSession`;
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
  componentes. Não precisa ser idêntica pixel a pixel. Os critérios foram
  revistos pelo dono em 2026-11-02:
  - Igualdade geral do componente ou da tela, com o texto incluído: acima de 95%.
  - Layout: acima de 98%, medido com as áreas de texto mascaradas. Inclui
    espaçamentos, posições, tamanhos, cores, formas, ícones e componentes.
  - Texto: tem tolerância. Fonte, tamanho, renderização e quebra de linha podem
    diferir do Figma, mas o texto precisa estar legível e dizer o mesmo
    conteúdo do frame.

  Abaixo de qualquer um dos dois limites, a tela volta para correção e a tarefa
  não é concluída. O relatório da tarefa registra os frames comparados, as duas
  medidas de cada um, as diferenças restantes com a justificativa de cada uma e
  as imagens enviadas ao dono.

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
  - download real de runtime (C30, AC28-live): concluir e aparecer na lista,
    uma fila de 2, Cancelar no meio encerrar o `xcodebuild`, sair do app no meio, e os casos sem
    Xcode, sem rede e com a licença não aceita. Fica com o dono, junto do C27;
  - versões anteriores reais (C35, AC22-live, equivale ao AC36): em
    2026-11-09 o dono baixou de verdade uma versão anterior, e funcionou. Falta
    confirmar a folha sem rede e uma versão recusada terminando como
    "Indisponível para o Xcode selecionado";
  - progresso real do download (C34, AC-live): a porcentagem e o tempo
    estimado aparecem num download real sem `-exportPath`, "Instalando…"
    aparece depois de 100% e o Cancelar encerra o `xcodebuild`; conferir
    também se o tempo estimado some com a rede parada (a estimativa só é
    recalculada quando chega uma linha nova). O formato da
    saída só foi visto numa amostra curta com `-exportPath`; as linhas de fim
    ("Done downloading", "Beginning asset import", "Done importing") vêm das
    strings do binário. Fica com o dono, junto do AC28-live;
  - medição em segundo plano (C40, AC20-live): impacto de energia aceitável
    ao longo de cerca de 1 h com a janela fechada, sem prender o
    `CoreSimulatorService` por causa dos ticks (o `simctl list` roda a cada
    medição). Fica com o dono;
  - medição em tempo real (C40 · tempo real, AC20-live): o rótulo reage a um
    build real com a janela fechada (~5 s depois do fim, ou a cada ~60 s num
    build longo), CPU perto de zero sem mudanças e energia aceitável ao longo
    de cerca de 1 h com build e simulador rodando (a pasta Devices é medida a
    cada minuto enquanto o simulador escreve). Fica com o agente principal e
    o dono; testes não comprovam isso;
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
| Download de runtimes (C30) | `Sources/Core/Simulators/{RuntimeDownloading,XcodebuildRuntimeDownloader,RuntimePlatform,RuntimeBuildVersion}.swift`, `Sources/Core/Process/XcrunFailure.swift`, `Sources/Features/Simulators/{RuntimeDownloadState,RuntimeDownloadRun,RuntimeDownloadOutcome,RuntimeDownloadChoice,RuntimeDownloadSheetContent,RuntimeDownloadPresentation,RuntimeDownloadCardView,RuntimeDownloadSheet}.swift` |
| Progresso do download de runtimes (C34) | `Sources/Core/Process/{ProcessRunning,ProcessRunner,OutputLineSplitter}.swift`, `Sources/Core/Simulators/{RuntimeDownloadEvent,RuntimeDownloadOutputParser,XcodebuildRuntimeDownloader}.swift`, `Sources/Features/Simulators/{RuntimeDownloadProgress,RuntimeDownloadProgressTracker,RuntimeDownloadRateEstimator,RuntimeDownloadRemaining,RuntimeDownloadPresentation,RuntimeDownloadCardView}.swift` e o `SimulatorsViewModel` |
| Versões anteriores de runtime (C35) | `Sources/Core/Simulators/{RuntimeCatalog,RuntimeCatalogEntry,RuntimeCatalogError,RuntimeCatalogDTO,RuntimeCatalogParser,RuntimeCatalogFetching,RuntimeCatalogCache,LossyElement,SimulatorSDKReading,RuntimeVersionsSnapshot,RuntimeVersionProviding,XcodebuildRuntimeDownloader}.swift`, `Sources/Features/Simulators/{RuntimeVersionOption,RuntimeVersionOptions,RuntimeVersionsModel,RuntimeDownloadChoice,RuntimeDownloadRun,RuntimeDownloadPresentation,RuntimeDownloadSheetContent,RuntimeDownloadSheet,RuntimeDownloadPlatformRow,PreviewRuntimeVersionSource}.swift`, `Sources/App/AppContainer.swift` |
| Janela de tamanho comum com barra lateral (C32) | `Sources/App/{CleanerXcodeApp,WindowID}.swift`, `Sources/Features/Cleaner/Window/{CleanerWindowView,CleanerSidebarView,SidebarFooterView,CleanerDetailView,ActionBarView,OverviewView,OverviewSummaryCard,SpaceBreakdownBar,SectionCardView,CategoryPageView,SectionHeaderView,GlassSurface,CleanerCommands}.swift`, `Sources/Features/Cleaner/Presentation/{SidebarDestination,ActionBarContent,SpaceBreakdown,CleanerNotice,OverviewPresentation}.swift`, `Sources/Features/Simulators/SimulatorsPageView.swift` |
| Ajustes, barra de menus e Sobre (C22) | `Sources/Features/Settings/*.swift`, `Sources/App/CleanerXcodeApp.swift` (`AppDelegate`) |
| Layout do C40: grade, Ajustes na barra lateral, versão e medição em segundo plano | `Sources/Features/Cleaner/Window/{SectionGridLayout,CleanerPageView,CleanerToolbar,CleanerCommands,SidebarFooterView}.swift`, `Sources/Features/Settings/{GeneralSettingsView,AboutSettingsView,SettingsSectionView,SettingsRowView}.swift`, `Sources/Features/Update/VersionUpdateRow.swift`, `Sources/App/AppRouter.swift`, `Sources/Features/Cleaner/{BackgroundMeasurementPolicy,BackgroundMeasurementScheduler,BackgroundMeasuring}.swift`, `Sources/Core/Platform/PowerConditions.swift` |
| Medição em tempo real (C40 · tempo real) | `Sources/Core/FileSystem/{FileSystemChange,FileSystemChangeWatching,FSEventsChangeWatcher}.swift`, `Sources/Features/Cleaner/{LiveMeasurementPolicy,PendingCategoryChanges,WatchedCategoryRoots,LiveMeasuring,LiveMeasurementScheduler}.swift`, `CleanerViewModel.measureCategories(_:)` |
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
- Decisão do C30: o dono pediu a instalação de runtimes no 1.0, o que supera
  a D11 ("fora do marco 1.0"), e depois escolheu "Só plataformas": as 4
  plataformas numa folha, em fila, sem versões antigas, sem tamanhos, sem
  seletor de versão e sem evento de analytics (ver o adendo do C30 no plano
  1.0). **Substituída em parte pelo C35:** "sem versões antigas, sem
  tamanhos, sem seletor de versão" deixou de valer; a fila, a ordem fixa e a
  ausência de analytics continuam.
- Decisão do C35 (2026-11-09): o dono pediu baixar runtimes de versões
  anteriores sem `.dmg`. Origem só o catálogo público da Apple, com fallback
  "só a versão do Xcode"; sem entrada manual, sem `-architectureVariant`, sem
  betas nem RCs, sem `diskImage`/`package`; já instaladas ficam fora do menu;
  nota de privacidade em `docs/PRIVACY.md` (ver o adendo do C35 no plano
  1.0). Limite conhecido (P2): o filtro (cryptex por mobile asset, com
  `architectures` contendo a arquitetura do Mac e sem `hostRequirements`) é
  uma heurística sobre um formato não documentado, observada em 2026-11-09
  (o `xcodebuild` do Xcode 27.2 recusou 17.5/18.x e baixou 26.x/27.x); uma
  recusa futura aparece como "Indisponível para o Xcode selecionado".
- Decisão do C34: o dono pediu o progresso e o tempo estimado do download
  de runtime. A saída do `xcodebuild -downloadPlatform` não é documentada:
  o formato fica fixado por uma amostra real nos testes, e uma saída
  diferente volta ao progresso indeterminado do C30 (ver o adendo do C34 no
  plano 1.0).
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
