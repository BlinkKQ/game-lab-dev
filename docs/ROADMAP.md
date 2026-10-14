# Roadmap — GameLab Minigolfe

Fonte de escopo: [GDD v0.2](GDD.md). Detalhes de verificação: [critérios de aceitação](CRITERIOS_ACEITACAO.md). O protótipo e o PCK foram implementados e verificados em Linux; evidências e limitações estão em [VALIDACAO.md](VALIDACAO.md).

## Fases e estado

| Fase | Entrega | Estado atual | Condição de conclusão |
| --- | --- | --- | --- |
| 2 — definição | GDD com regras, mapas e parâmetros | GDD v0.1 recebido e revisado | Escopo suficientemente concreto para preparar a implementação |
| 3 — passagem para desenvolvimento | GDD v0.2, mecânicas, telas, critérios, roadmap e README | Pacote documental preparado | Documentos consistentes, decisões preservadas e testes planejados |
| 4 — construção | Projeto Godot com os três percursos | Protótipo e PCK verificados em Linux | Executável no computador, fluxo principal disponível e verificações básicas concluídas |
| 5 — avaliação | Relatório dos critérios, falhas e ajustes | Relatório técnico Linux disponível; avaliação humana pendente | Evidências por critério e alvo; problemas separados de pendências e testes não executados |
| 6 — teste privado no iPhone | Versão privada testável no aparelho | Pendente | Fluxo principal, toque, área segura, suspensão e salvamento testados no iPhone real |
| Posterior | Android, conteúdo ou novos sistemas | Fora do MVP | Escopo definido a partir da avaliação da primeira versão |

## Ordem de construção da fase 4

1. **Base do projeto.** Fixar a versão do Godot 4, configurar composição 720 × 1280 e física a 60 passos/s, centralizar os parâmetros e criar os três mapas como dados. Documentar comandos efetivamente usados e escolher um caminho de dados local para o recorde.
2. **Controle e bola no mapa 01.** Implementar mouse/toque, exclusividade do gesto, prévia e zona neutra, frenagem, colisão, repouso e captura. Verificar fronteiras, velocidade máxima e prioridades de entrada antes de expandir a sessão.
3. **Sessão completa.** Integrar os mapas 02 e 03, retorno sem penalidade adicional, posição de recuperação, registro único de resultados e avanço após feedback. Validar os totais durante a captura e a ordem dos mapas.
4. **Telas e interrupções.** Implementar menu, confirmação, resultado, escala uniforme, conversão de coordenadas e motivos independentes de pausa. Verificar temporizadores e solturas antigas durante suspensão e retomada.
5. **Persistência.** Validar JSON, separar melhor da execução e recorde salvo, gravar sem perder o arquivo anterior e tratar falhas e formatos desconhecidos. Testar leitura após reabrir e tentativas de gravação após outra sessão completa.
6. **Verificação integrada.** Executar os testes automatizados e os procedimentos manuais aplicáveis ao computador. Registrar resultados e limitações; manter os critérios específicos de iPhone pendentes até o aparelho real.

Essa ordem é uma sequência de implementação, sem estimativa de prazo. Cada etapa incorpora as verificações relacionadas; a última etapa não substitui testes durante a construção.

## Avaliação da fase 5

- Medir conforto do arraste, entendimento da força, previsibilidade de rebotes e legibilidade.
- Confirmar desempenho e evitar atravessamento de paredes, incluindo colisões oblíquas e cantos.
- Revisar os parâmetros após jogar, mantendo valores e expectativas de testes sincronizados.
- No mapa 01, observar a janela de força de uma tacada direta: aproximadamente 84,14% a 88,01% no modelo contínuo, considerando a região de captura. Isso é um ponto de calibração; concluir em mais tacadas continua permitido.
- Registrar o que passou, falhou, foi bloqueado ou não foi executado, com alvo e evidência. Não transformar o cálculo geométrico em evidência de jogabilidade.

## Preparação da fase 6

Definir a forma de teste privado quando houver uma versão executável. Para exportação nativa, preparar macOS/Xcode, templates compatíveis com a versão fixada do Godot e assinatura aplicável. Não solicitar credenciais de distribuição antes de escolher o procedimento necessário.

Testar no aparelho real toque e dedo adicional, recortes e área segura, suspensão do aplicativo, desempenho, modo offline e persistência após reabrir. Testes em Linux, modo headless ou mouse não substituem essas evidências. Manter a distribuição privada; este roadmap não autoriza publicação ou compartilhamento.

## Decisões que permanecem abertas

| Decisão | Quando resolver | Limite |
| --- | --- | --- |
| Engine e arquitetura | Definidos: Godot 4.6.3, Node2D e modelo separado | Atender GDScript, 2D e as regras do GDD |
| Operações de gravação e dados | Definidos: user://record.json e substituição de temporário | Comportamento testado em Linux; verificar no iPhone |
| Calibração física e conforto do gesto | Protótipo jogável | Atualizar a fonte canônica e os testes juntos |
| Nome final, arte e sons | Avaliação/polimento | Recursos próprios ou com permissão; não bloquear o protótipo |
| Procedimento de teste privado no iPhone | Preparação da fase 6 | Sem publicação implícita ou promessa de validação no aparelho |

Não são pré-requisitos do MVP: backend, contas, ranking online, bots, monetização, multiplayer ou Android. Rever o escopo para 3D antes de produzir mapas definitivos somente se movimento em altura passar a ser objetivo principal.
