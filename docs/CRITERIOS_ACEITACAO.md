# GameLab Minigolfe — critérios de aceitação

**Versão:** 0.3 · 14/10/2026  
**Fase:** 4 — protótipo construído  
**Fonte normativa:** GDD v0.4 e conversão 3D deste pacote, com os esclarecimentos da revisão do GDD v0.1.  
**Situação:** validação parcial em engine/Linux; aceite no iPhone e avaliação humana pendentes. Veja [VALIDACAO.md](VALIDACAO_3D.md).

Este documento preserva os identificadores AC-01 a AC-22 do GDD e acrescenta AC-23 a AC-30. Define casos, dados e evidências para o futuro projeto Godot 4/GDScript. O projeto e a suíte executável existem, com resultados registrados no relatório. A validação no iPhone permanece pendente. As verificações matemáticas feitas na revisão não aprovam nenhum critério de jogabilidade.

## 1. Onde verificar

| Método | Uso | Limite da evidência |
| --- | --- | --- |
| **E — engine/headless** | Executar regras isoladas e integrações do futuro projeto na versão Godot fixada: entrada normalizada, física, sessão, temporizadores e leitura/gravação em diretório de teste | Um teste fora da engine pode ajudar a preparar os casos, mas não prova colisões, ordem de eventos nem comportamento do runtime Godot |
| **D — computador, manual** | Jogar com mouse; observar telas, gestos, feedback, proporções distintas, perda de foco, confirmação de abandono e reabertura do aplicativo | Não comprova toque, suspensão, desempenho, área segura ou persistência no iPhone |
| **I — iPhone real** | Jogar a versão privada no aparelho; verificar toque, dedos adicionais, emulação de entrada, interrupção do aplicativo, recortes, área segura, desempenho e persistência local | Registrar o aparelho, iOS, versão/build e forma de execução; aprovação vale para o ambiente efetivamente testado |

A engine está fixada em Godot 4.6.3. Executar a suíte com `sh scripts/dev.sh test` e o teste de renderização com `sh scripts/dev.sh capture` em um display gráfico. O projeto deverá oferecer casos reproduzíveis e pontos controlados para preparar estados e provocar falhas, sem colocar essas opções na interface do jogador.

Na construção, são obrigatórios os casos de regra e integração pertinentes em E e o fluxo jogável em D. Na avaliação, registrar cada critério e resolver falhas impeditivas. A aceitação para iPhone exige I para controles, área segura, interrupções, desempenho e persistência; uma exportação bem-sucedida não substitui essa execução. Som, música e polimento artístico são opcionais para a primeira avaliação.

## 2. Matriz de critérios

E, D e I indicam métodos planejados, não execuções concluídas. As variantes detalhadas nas seções seguintes fazem parte dos respectivos critérios.

| ID | Verificação | Resultado esperado | Método | Aceite completo |
| --- | --- | --- | --- | --- |
| AC-01 | Iniciar uma sessão pelo menu | Abrir mapa 01, com contador e total em zero | E, D, I | Parcial — ver relatório |
| AC-02 | Preparar e variar uma mira | Bola parada; seta, barra e percentual respondem ao arraste | E, D, I | Parcial — ver relatório |
| AC-03 | Soltar na zona neutra | Nenhum movimento e nenhuma tacada contada | E, D, I | Parcial — ver relatório |
| AC-04 | Soltar um arraste válido | Um único lançamento e exatamente uma tacada | E, D, I | Parcial — ver relatório |
| AC-05 | Arrastar além do máximo | Potência limitada a 100% | E, D, I | Parcial — ver relatório |
| AC-06 | Tocar durante movimento ou adicionar outro dedo | Não aplicar impulso extra nem transferir o controle | E, D, I | Parcial — ver relatório |
| AC-07 | Comparar 25%, 50% e 75% em campo livre, a partir da mesma posição | Velocidades iniciais e distâncias de parada crescentes | E, D | Parcial — ver relatório |
| AC-08 | Lançar contra uma parede, inclusive na potência máxima | Rebater sem atravessar a parede | E, D, I | Parcial — ver relatório |
| AC-09 | Esperar a bola parar | Liberar a mira sem velocidade residual | E, D, I | Parcial — ver relatório |
| AC-10 | Passar pelo alvo acima da velocidade de captura | Não concluir o buraco naquele instante | E, D, I | Parcial — ver relatório |
| AC-11 | Entrar no alvo em velocidade válida | Capturar, contar o resultado uma vez e bloquear novas tacadas | E, D, I | Parcial — ver relatório |
| AC-12 | Cair na água do percurso 03 | Retornar à posição anterior, com velocidade zero e sem tacada adicional | E, D, I | Parcial — ver relatório |
| AC-13 | Concluir os mapas 01, 02 e 03 | Avançar na ordem e abrir o resultado somente após o terceiro | E, D, I | Parcial — ver relatório |
| AC-14 | Registrar resultados 3, 4 e 5 em um teste de pontuação | Mostrar total 12 | E, D | Parcial — ver relatório |
| AC-15 | Repetir uma sessão ou abandoná-la | Zerar a sessão seguinte e preservar o melhor total já salvo | E, D, I | Parcial — ver relatório |
| AC-16 | Concluir com total melhor, igual e pior | Atualizar somente o melhor resultado; distinguir melhor alcançado em memória de recorde com gravação confirmada | E, D, I | Parcial — ver relatório |
| AC-17 | Fechar e reabrir após salvar | Restaurar o melhor total no ambiente efetivamente testado | E, D, I | Parcial — ver relatório |
| AC-18 | Ler dados ausentes, inválidos ou de versão desconhecida | Permitir jogar sem travar; preservar formato desconhecido | E, D, I | Parcial — ver relatório |
| AC-19 | Perder foco durante mira e movimento | Nenhuma soltura atrasada gera tacada; sessão suspende e retoma corretamente | E, D, I | Parcial — ver relatório |
| AC-20 | Usar proporções de tela distintas | Bola e controles visíveis, campo inteiro na visão geral e toque alinhado à bola | D, I | Parcial — ver relatório |
| AC-21 | Confirmar e cancelar retorno ao menu | Cancelar conserva a sessão; confirmar a encerra | E, D, I | Parcial — ver relatório |
| AC-22 | Abrir e jogar sem conexão | Menu, três mapas, resultado e recorde local disponíveis | D, I | Parcial — ver relatório |
| AC-23 | Observar pontuação em cada captura e no feedback, com resultados 3, 4 e 5 | Totais 3, 7 e 12, sem contagem duplicada, inclusive na captura do terceiro buraco | E, D, I | Parcial — ver relatório |
| AC-24 | Forçar falha de abertura, escrita e substituição na gravação | Preservar arquivo anterior, manter resultado e melhor alcançado em memória, indicar recorde não salvo e permitir tentativa em conclusão posterior | E, D, I | Parcial — ver relatório |
| AC-25 | Sobrepor pausas de aplicativo e modal, incluindo captura e reposicionamento | Congelar física e todos os temporizadores da sessão; retomar uma única vez apenas quando todas as causas forem removidas | E, D, I | Parcial — ver relatório |
| AC-26 | Exercitar fronteiras de arraste e captura | Zona neutra inclusiva em 12; saturação em 180; captura inclusiva em distância 22 e velocidade 150; direção preservada e magnitude limitada | E, D | Parcial — ver relatório |
| AC-27 | Disputar entrada entre campo e interface e reproduzir toque com mouse emulado | Interface tem prioridade em um novo gesto; arraste ativo não aciona botões ao cruzá-los; menu segue a disponibilidade por estado; não há tacada duplicada | E, D, I | Parcial — ver relatório |
| AC-28 | Validar números JSON e fazer ida e volta do registro | Aceitar `null` ou número matematicamente integral de pelo menos 3; rejeitar booleanos, frações e valores menores; preservar versão desconhecida | E, D, I | Parcial — ver relatório |
| AC-29 | Colidir obliquamente e em cantos na velocidade máxima | Não atravessar barreiras; conservar componente tangencial e aplicar restituição 0,78 apenas à normal de cada impacto | E, D, I | Parcial — ver relatório |
| AC-30 | Escapar dos limites e retornar com posição anterior inválida | Recuperar na posição inicial válida, zerar velocidade e mira, sem tacada ou penalidade adicional | E, D | Parcial — ver relatório |
| AC-31 | Cenário, esfera e colisões 3D | Corpos e pisos nativos, parede na velocidade máxima sem atravessamento | E, D, I | Parcial — ver relatório |
| AC-32 | Controle projetado pela câmera em diferentes alturas | Mouse/toque iniciam mira e reproduzem direção e potência sem deslocar a bola | E, D, I | Parcial — ver relatório |
| AC-33 | Gravidade, aterrissagem e repouso apoiado | Esfera cai até piso real; ápice não libera nova tacada | E, D, I | Parcial — ver relatório |
| AC-34 | Subida para o terraço do mapa 02 | Ganhar altura e repousar no nível de 0,60 m | E, D, I | Parcial — ver relatório |
| AC-35 | Salto automático sobre o vão | Rampa conserva movimento vertical; cruzar água no ar e aterrissar | E, D, I | Parcial — ver relatório |
| AC-36 | Queda na água e retorno em altura | Retornar à pose segura sem tacada adicional, incluindo borda elevada | E, D, I | Parcial — ver relatório |
| AC-37 | Apoio sobre obstáculos e pausa aérea | Pousar no topo sem travar; mirar mantendo altura; pausa congela corpo e velocidade | E, D, I | Parcial — ver relatório |
| AC-38 | Câmera próxima durante mira, movimento e pausa | Seguir a bola; congelar lente e pose durante mira/pausa; conservar direção e força no mesmo pixel | E, D, I | Parcial — ver relatório |
| AC-39 | Alternar visão durante um gesto e soltar dedos antigos | Cancelar sem tacada; nenhuma soltura antiga troca novamente a visão ou lança; nova mira funciona em ambas as projeções | E, D, I | Parcial — ver relatório |
| AC-40 | Sons, pausa e silenciamento | Uma indicação sonora por evento; parar vozes na pausa/mute; reativar sem reproduzir eventos antigos | E, D, I | Parcial — ver relatório |

## 3. Preparação dos cenários

Manter cada caso isolado e restaurar sua preparação antes da próxima execução. Os futuros testes de persistência usam diretório temporário próprio, nunca o arquivo real do jogador. Injeções de estado e falha são recursos de teste, sem alterar as regras do jogo.

| Preparação | Dados necessários | Observação |
| --- | --- | --- |
| Campo livre | Posição inicial fixa, sem alvo ou obstáculos no trajeto; arrastes 54, 96 e 138 | Validar velocidades iniciais 250, 500 e 750; as distâncias contínuas 62,50, 250 e 562,50 são referências, não exigência de igualdade exata no modelo discreto |
| Limites de entrada | Vetores horizontais, verticais e diagonais; comprimentos ao redor de 12 e 180; toque perto do limite de início 72 | Medir em coordenadas lógicas; não usar pixels de tela como distância física |
| Alvo controlado | Centro do alvo conhecido; distância e velocidade preparadas antes do passo de decisão | Permite distinguir captura de frenagem aplicada no mesmo passo |
| Captura e pontuação | Percurso atual com 3, 4 ou 5 tacadas; lista anterior conhecida; eventos de captura repetidos | Registrar contador, lista, total, quantidade de avanços e valor próprio do feedback |
| Colisões | Parede vertical e horizontal, incidência oblíqua, canto e obstáculos dos mapas reais; velocidade até 1.000 | Registrar velocidade antes e depois de cada impacto e a normal usada |
| Retorno | Posição anterior válida; área fora de jogo; fuga da região válida; posição anterior inválida | Guardar quantidade de tacadas antes da recuperação e posição final |
| Pausas | Relógio controlável de sessão e causas independentes de aplicativo/modal | Registrar movimento, tempo de repouso, tempo de captura e tempo de retorno antes, durante e após suspensão |
| Persistência | Arquivo ausente; registros conhecidos, corrompidos e de versão desconhecida; recorde anterior 12; tentativa com melhor 9 | Guardar cópia/identidade dos bytes anteriores e contar tentativas de abertura, escrita e substituição |
| Telas e aparelhos | Proporções distintas e iPhone com recorte e área inferior reservada | Registrar área segura, transformação entre tela/campo e os pontos de toque utilizados |

Para comparação de ponto flutuante e discretização, declarar no caso uma tolerância compatível com o passo físico, as unidades lógicas e a versão da engine. Não ampliar uma tolerância para esconder cruzamento de parede, tacada extra ou decisão de fronteira incorreta. Registrar os parâmetros efetivamente usados; mudanças de calibração exigem atualizar a expectativa e repetir os casos afetados.

## 4. Entrada, movimento e fronteiras

### AC-02 a AC-06, AC-09, AC-26 e AC-27

- Testar toque inicial dentro, exatamente no raio 72 e fora dele. Testar botão da interface sobre uma região elegível da bola: um novo gesto no botão aciona a interface, sem iniciar mira.
- Testar arrastes de comprimento 0, imediatamente abaixo de 12, exatamente 12 e imediatamente acima. Os três primeiros cancelam sem tacada; somente o último pode lançar. Não normalizar um vetor nulo para criar uma direção arbitrária.
- Testar imediatamente abaixo de 180, exatamente 180 e acima, incluindo vetores diagonais e muito longos. A potência é limitada a `[0, 1]`, a velocidade inicial não excede 1.000 e a direção continua oposta ao arraste, sem distorção por limitar componentes separadamente.
- Usar arrastes 54, 96 e 138 para conferir potência 25%, 50% e 75%. Conferir seta, barra, percentual e bola imóvel durante a mira. Zona neutra não apresenta seta de lançamento.
- Repetir toque e soltura válidos e contar os lançamentos. O gesto produz uma única tacada. Dedos extras, solturas sem gesto ativo e toque durante movimento não produzem impulso.
- Testar uma sequência de toque com a emulação de mouse habilitada na configuração efetivamente usada. O par de eventos referente ao mesmo gesto não inicia duas miras nem registra duas tacadas. Também testar mouse físico separado.
- Durante um arraste ativo, atravessar e soltar sobre um botão: o gesto continua pertencendo à mira e não abre o menu. Uma ação nova e separada de menu é aceita em `Bola pronta`, `Mirando` e `Em movimento`; abrir a confirmação cancela a mira ativa sem tacada.
- Em `Reposicionar` e `Buraco concluído`, o acesso ao menu da partida fica indisponível. Em menu, resultado e confirmação não há entrada física para a bola. O cancelamento de uma mira não transforma sua soltura posterior em gesto novo.
- Para repouso, testar velocidade abaixo de 12 unidades/s durante menos e durante pelo menos 0,12 s de tempo ativo. Velocidade que deixa de satisfazer o limiar reinicia a confirmação; a mira só é liberada ao concluir o repouso, com velocidade exatamente zerada.

Para AC-10, AC-11 e AC-26, cobrir separadamente distância 22 e velocidade 150, cada uma imediatamente abaixo, exatamente no limite e imediatamente acima. Usar velocidade 149, 150 e 151 com distância válida e distância 21, 22 e 23 com velocidade válida. Valores exatamente 22 e 150 permitem captura; valores acima de qualquer limite não permitem. Validar ainda o caso em que captura e confirmação de repouso seriam elegíveis no mesmo passo: capturar antes de liberar outra mira. O alvo não adiciona uma parede circular.

### AC-07, AC-08 e AC-29

Comparar movimentos a partir da mesma posição e direção. A desaceleração de 500 unidades/s² reduz o módulo, respeita o tempo do passo e não inverte o movimento ao chegar a zero. As distâncias de parada para 25%, 50% e 75% devem crescer nessa ordem. Registrar distância e tempo no projeto, sem tratar o cálculo contínuo como medição de jogo.

Em um impacto isolado, decompor a velocidade de entrada em normal e tangente à superfície. A saída esperada é a tangente preservada mais a normal invertida e multiplicada por 0,78. Se houver frenagem no mesmo passo, medir o instante do impacto ou explicitar a ordem para separar a frenagem da restituição; reduzir todo o vetor por 0,78 não satisfaz o critério.

Lançar contra paredes horizontais e verticais e contra cantos com incidências distintas, inclusive a 1.000 unidades/s. Verificar bola de raio 14 sem atravessar a geometria, sem ganhar velocidade e sem ficar presa em uma sequência infinita de impactos. Em um canto com mais de uma normal, avaliar cada impacto efetivamente resolvido; não exigir que a tangente de uma parede permaneça intacta depois de um segundo impacto com outra parede. Repetir nos obstáculos dos três percursos com o passo físico configurado, inicialmente 60 passos/s.

## 5. Captura, retorno e pontuação

### AC-11 a AC-16 e AC-23

Preparar uma sessão com três resultados sucessivos de 3, 4 e 5. Em cada captura, transferir o contador atual para a lista e zerá-lo na mesma transição, antes de expor o novo estado à interface. O feedback guarda seu próprio número de tacadas do buraco concluído, separado do contador atual.

| Ponto de observação | Resultados concluídos | Contador atual | Feedback do buraco | Total |
| --- | --- | ---: | ---: | ---: |
| Captura do mapa 01 e seus aproximadamente 0,7 s de feedback | `[3]` | 0 | 3 | 3 |
| Abertura do mapa 02 | `[3]` | 0 | Encerrado | 3 |
| Captura do mapa 02 e seu feedback | `[3, 4]` | 0 | 4 | 7 |
| Abertura do mapa 03 | `[3, 4]` | 0 | Encerrado | 7 |
| Captura do mapa 03 e seu feedback | `[3, 4, 5]` | 0 | 5 | 12 |
| Tela de resultado | `[3, 4, 5]` | 0 | Encerrado | 12 |

Observar o primeiro estado pós-captura, passos intermediários de feedback e a transição final, não apenas a tela de resultado. Entregar eventos de captura repetidos e tentativas de nova tacada durante o feedback: não há novo registro, novo impulso, avanço adicional nem total transitório duplicado. Somente a conclusão do terceiro buraco gera o resultado da sessão e avalia a gravação de recorde.

Nova sessão começa no mapa 01 com resultados vazios e contador zero. Abandono descarta os dados da sessão; repetição e abandono preservam o recorde já confirmado em arquivo. Abandono e fechamento não iniciam gravação de recorde ou resultado parcial, mesmo quando existe um melhor alcançado em memória ainda não salvo.

### AC-12 e AC-30

Testar queda da esfera na água do mapa 03, permitindo cruzar o vão no ar e fuga da região válida de cada mapa. A posição de retorno é a guardada imediatamente antes do lançamento; a tacada lançada permanece contada. A recuperação termina com velocidade zero e sem mira ativa, sem acrescentar penalidade.

Repetir com posição anterior fora da região válida, dentro de obstáculo ou da área fora de jogo e com coordenadas não finitas, como `NaN`/infinito, se o runtime permitir preparar esses dados. A recuperação usa a posição inicial válida do mapa. Eventos repetidos durante o retorno não somam tacadas nem iniciam retornos simultâneos. Validar a recuperação da posição antes de permitir uma nova mira.

## 6. Pausa e confirmação de abandono

### AC-19, AC-21 e AC-25

Pausa do aplicativo e pausa da confirmação são causas independentes. A sessão fica suspensa enquanto qualquer causa estiver ativa. Congelar posição/velocidade e todos os relógios da sessão: confirmação de repouso, feedback de captura e temporizador de reposicionamento, além de qualquer outro temporizador de sessão criado na implementação. Tempo de relógio real em segundo plano não consome esses intervalos.

| Cenário | Passos | Resultado esperado |
| --- | --- | --- |
| Mira interrompida | Preparar mira, perder foco, emitir soltura atrasada, recuperar foco | Mira cancelada; bola não recebe impulso; contador não muda |
| Movimento interrompido | Lançar, perder foco, aguardar, recuperar foco | Posição, velocidade e progresso do repouso permanecem congelados; retomar o movimento do ponto suspenso |
| Confirmação e foco | Abrir confirmação em movimento, perder foco, recuperar foco, selecionar Continuar | Recuperar foco não fecha a confirmação nem retoma o jogo; Continuar remove a última pausa e retoma uma vez |
| Ordem inversa das causas | Com as duas causas ativas, remover primeiro a causa modal no cenário controlado e depois a do aplicativo | Não retomar enquanto o aplicativo permanece suspenso; retomar uma vez quando a última causa termina |
| Captura interrompida | Suspender durante o feedback do primeiro, segundo e terceiro buraco | Não avançar mapa nem abrir resultado em segundo plano; concluir somente o tempo restante após retomar |
| Retorno interrompido | Suspender durante reposicionamento | Não liberar controle nem consumir o retorno em segundo plano; concluir uma vez após retomar |
| Captura/retorno com causas sobrepostas | Preparar cada estado e aplicar as duas causas pela fixture de pausa | Mesmas garantias de congelamento; nenhuma causa libera a sessão enquanto a outra permanece |
| Eventos repetidos | Repetir notificações de suspensão/retorno e ações já consumidas | Não duplicar resultado, registro de captura, avanço, recuperação ou aplicação de velocidade |
| Abandono | Abrir confirmação em estado permitido e confirmar saída | Descartar a sessão, voltar ao menu, sem resultado parcial nem gravação |

A fixture de pausa permite verificar sobreposição de causas nos estados de captura e retorno, embora o menu da partida esteja indisponível nesses estados. Ela testa o mecanismo interno; não cria um caminho de interface que contrarie AC-27. Os testes manuais percorrem somente ações disponíveis ao jogador.

No computador, testar perda e recuperação de foco. No iPhone real, testar interrupção e suspensão efetiva do aplicativo durante mira, movimento, feedback, retorno e confirmação. Registrar se o sistema encerrou o processo: após encerramento, não exigir restauração da sessão temporária; reabrir inicia sem sessão parcial e preserva apenas dados cuja gravação foi confirmada.

## 7. Persistência e validação do registro

### AC-16 a AC-18, AC-24 e AC-28

Manter duas referências observáveis nos testes: melhor total alcançado durante a execução e último melhor total cuja persistência foi confirmada. Uma falha de gravação não apaga o primeiro nem atualiza o segundo. Menu e resultado indicam claramente o melhor alcançado que não foi salvo e mostram “O recorde não pôde ser salvo.”; não apresentam esse valor como recorde confirmado para a próxima abertura.

Após cada sessão completa, avaliar o melhor alcançado em memória contra o recorde confirmado. Tentar salvar quando esse melhor for menor ou quando não houver recorde confirmado. Assim, uma conclusão posterior pode tentar salvar de novo um melhor anterior, mesmo que o total da nova sessão seja igual ou pior que ele. Empate ou piora em relação ao recorde confirmado não provocam gravação desnecessária. Não tentar salvar ao abandonar, fechar ou pausar.

| Caso de leitura | Expectativa |
| --- | --- |
| Arquivo ausente | Iniciar sem recorde e permitir concluir uma sessão |
| `schema_version: 1`, `best_total: null` | Formato conhecido, sem recorde |
| `best_total: 3`, `3.0` ou outro número matematicamente integral ≥ 3 | Aceitar, independentemente de o parser representar internamente como inteiro ou ponto flutuante |
| Número com escrita exponencial e valor integral ≥ 3 | Aceitar se o parser produzir um número finito e integral |
| `best_total: true` ou `false` | Rejeitar; booleano não é um total numérico |
| `best_total: 3.5`, `2`, `0` ou valor negativo | Rejeitar sem travar |
| String, lista, objeto ou ausência de campo obrigatório | Tratar como dados inválidos, sem travar |
| JSON malformado ou estrutura incompatível | Permitir jogar sem recorde; não confundir leitura inválida com recorde confirmado |
| Versão de formato não reconhecida | Permitir jogar sem recorde; manter os bytes originais e bloquear gravação nesse arquivo por toda a execução |

Validar a ida e volta do formato conhecido: criar registro com `null`, gravar/ler, depois fazer o mesmo com 3 e outro total válido. A validação é numérica, não baseada no nome do tipo retornado pelo parser. Valores não finitos não são aceitos. A leitura, sozinha, não sobrescreve um arquivo inválido ou desconhecido.

Para o formato desconhecido, completar mais de uma sessão, repetir, abandonar e fechar. Nenhuma operação substitui o arquivo nem remove o bloqueio durante essa execução, inclusive depois de uma melhora em memória. Na reabertura, o mesmo arquivo continua reconhecido como versão desconhecida; manutenção/migração ficam fora deste MVP.

Para AC-24, iniciar com arquivo conhecido e recorde confirmado 12, alcançar 9 e executar separadamente as falhas abaixo. Injetar falhas no mecanismo de gravação do projeto, sem depender de permissões ou falhas do aparelho que não possam ser reproduzidas.

| Falha forçada | Verificação |
| --- | --- |
| Abertura do destino temporário para escrita | Arquivo anterior continua legível e com os mesmos bytes; resultado 9 permanece visível |
| Escrita incompleta/erro ao concluir os dados | Dados parciais não substituem o arquivo anterior; erro não confirma persistência |
| Substituição final do arquivo pelo registro concluído | Falha mantém o registro anterior intacto; novo total não aparece como persistido |

Em cada variante, melhor alcançado permanece 9 e recorde confirmado permanece 12. Fechar e reabrir após a falha recupera 12, não 9. Em uma execução que ainda mantém 9 na memória, remover a falha, concluir outra sessão com 10 ou mais e verificar nova tentativa com 9; somente após sucesso o recorde confirmado passa a 9. Fazer também a variante sem arquivo anterior: falha mantém ausência de recorde confirmado e uma conclusão posterior pode tentar novamente.

A gravação normal preserva o registro anterior até a nova gravação estar concluída. Capturar evidência de confirmação da substituição, além de ler o novo registro depois. E valida as falhas por injeção; D e I verificam apresentação e continuidade da sessão com essas falhas quando existir uma versão privada de teste apropriada. A persistência no iPhone deve ser confirmada também sem injeção, com gravação real e reabertura.

## 8. Apresentação, aparelho e uso offline

### AC-20 e AC-22

- Variar proporções de tela no computador e registrar pelo menos uma proporção mais curta e uma mais longa que a referência 720 × 1280. Campo e mapas mantêm escala uniforme e suas coordenadas lógicas.
- No iPhone real, verificar recorte superior, região inferior reservada, textos, botões e o percurso inteiro dentro da área segura. O fundo pode ocupar o restante da tela; elementos essenciais não ficam sob regiões do sistema.
- Testar início de mira e arrastes próximos às bordas e em posições distintas do campo. Conversão entre coordenadas de tela e lógicas mantém toque alinhado à bola e a mesma potência para o mesmo arraste lógico.
- Observar a compreensão de seta, barra, percentual e marcação fora de jogo sem depender só da cor. Os textos de jogo explicam ações; parâmetros e recursos de teste ficam fora da interface normal.
- No aparelho, jogar os três mapas e observar resposta ao toque, movimento e transições; registrar engasgos e condições do teste. Uma aprovação de desempenho requer evidência no aparelho, sem inventar uma meta de FPS que o GDD ainda não definiu.
- Abrir com rede indisponível, concluir os três mapas, retornar ao menu, repetir e reabrir após salvar. Jogabilidade e recorde local não dependem de conexão, contas ou autenticação. Validar instalação/exportação separadamente: indisponibilidade de rede durante o jogo é o que AC-22 exige.

## 9. Registro e conclusão da avaliação

Para cada caso executado, registrar ID e variante, build/commit do projeto, versão Godot, parâmetros físicos, método E/D/I, sistema/aparelho, preparação, passos, resultado esperado, resultado observado e evidência. Logs com contadores e transições ajudam nos casos E; capturas/vídeo ajudam na interface e no aparelho. Evitar incluir dados pessoais nos registros de teste.

Usar estados **Pendente**, **Aprovado**, **Falhou** ou **Bloqueado**, com motivo e próximo passo. Aprovar um critério somente após suas variantes obrigatórias passarem no método exigido; uma parte aprovada em E não autoriza marcar a validação I como concluída. Anexar a evidência ou referenciá-la no relatório da fase 5. Ao corrigir uma falha, repetir o caso e as verificações diretamente afetadas.

O protótipo e suas verificações em engine/Linux estão registrados no relatório. Avaliação humana da jogabilidade e aceite no iPhone permanecem pendentes.
