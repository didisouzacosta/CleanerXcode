# Skills compartilhadas de desenvolvimento Apple

Esta pasta centraliza cópias versionáveis das skills usadas pelo fluxo de
desenvolvimento iOS e macOS. As cópias foram importadas das fontes instaladas
no ambiente Codex para que os projetos consumidores tenham os arquivos
completos localmente.

Skills atualmente copiadas:

- swiftui-expert-skill
- swift-concurrency
- swiftui-patterns
- swiftui-ui-patterns
- swiftui-liquid-glass
- swiftui-view-refactor
- ios-debugger-agent

Em cada projeto consumidor, `.agents/skills` recebe cópias regulares destas
skills durante o `ai-bootstrap`. O manifesto `.ai/managed-files.sha256`
protege essas cópias durante o `ai-update`; skills extras do consumidor não
são alteradas.
