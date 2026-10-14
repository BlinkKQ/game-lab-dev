# GameLab Minigolfe — mecânicas

**Fase:** 4 — protótipo construído.  
**Fonte:** [GDD v0.3](GDD.md) e [conversão 3D](CONVERSAO_3D.md).  
**Situação:** comportamento implementado e verificado em Linux. Veja [VALIDACAO.md](VALIDACAO_3D.md); aceite no iPhone pendente.

O MVP é um minigolfe 3D com câmera inclinada, interface vertical, uma pessoa e três percursos em ordem fixa. A partida e o recorde local funcionam offline. Godot 4.6.3 e GDScript são as tecnologias da implementação. O primeiro alvo é o iPhone, com mouse no computador durante o desenvolvimento. A distribuição permanece privada até autorização explícita para publicar ou compartilhar.

## 1. Sessão e estados

Uma sessão começa com mapa 01, contador atual em zero e lista de resultados vazia. Cada lançamento válido acrescenta uma tacada. Concluir os três buracos gera o resultado; abandonar descarta a sessão sem salvar progresso parcial.

| Estado | Entrada e saída esperadas |
| --- | --- |
| Menu | Jogar cria uma sessão e abre o mapa 01. |
| Bola pronta | Permite iniciar mira ou abrir a confirmação de abandono. |
| Mirando | Ajusta direção e força; soltar lança ou cancela; abrir a confirmação cancela a mira. |
| Em movimento | Atualiza física; bloqueia outra tacada; permite abrir a confirmação de abandono. |
| Reposicionar | Bloqueia tacadas e o botão de menu; após retorno breve, restaura a posição segura e libera a bola. |
| Buraco concluído | Bloqueia tacadas e o botão de menu; mostra feedback por aproximadamente 0,7 s e avança uma única vez. |
| Resultado | Exibe os três resultados; permite repetir ou voltar ao menu. |

Pausa é uma condição separada desses estados. Suspender não deve reiniciar o estado, o percurso ou seus temporizadores. Na transição ao próximo mapa, carregar sua posição inicial e manter o contador atual em zero, pois ele já foi zerado na captura.

## 2. Entrada, direção e potência

1. Aceitar um novo toque somente com a bola pronta e a até **72 unidades lógicas** do centro. Registrar a posição inicial e o identificador do toque.
2. Calcular o arraste entre a posição atual e a posição inicial do toque. O lançamento aponta no sentido contrário ao arraste.
3. Manter a bola parada durante a mira. Exibir seta de direção inicial, barra e percentual de potência.
4. Ao soltar fora da zona neutra, guardar a posição anterior ao lançamento, incrementar o contador uma única vez e aplicar a velocidade inicial.
5. Ao soltar na zona neutra, cancelar sem movimento nem alteração de pontuação.
6. Limpar a interação ao lançar, cancelar ou pausar. Ignorar liberações tardias de uma interação encerrada.

Para um arraste de comprimento `d`:

```text
potencia = limitar((d - 12) / 168, 0, 1)
velocidade_inicial = direcao_contraria_ao_arraste * potencia * 1000
```

| Arraste | Potência | Velocidade inicial |
| --- | ---: | ---: |
| Até 12 unidades | 0% | Sem lançamento |
| 54 unidades | 25% | 250 unidades/s |
| 96 unidades | 50% | 500 unidades/s |
| 138 unidades | 75% | 750 unidades/s |
| 180 unidades ou mais | 100% | 1.000 unidades/s |

Um dedo controla a mira até soltar ou cancelar, mesmo passando por elementos da interface. Esse arraste não aciona o botão de menu. Uma ação independente e deliberada no menu, como `Esc` ou um novo toque diretamente no botão, pode cancelar a mira e abrir a confirmação. Fora dessa ação específica da interface, dedos adicionais não controlam a bola nem transferem a mira. O mouse reproduz pressionar, arrastar e soltar.

Toques fora da região de início, durante movimento ou durante transições não geram tacadas. A nova mira só é liberada após confirmar o repouso; nenhuma velocidade residual deve permanecer.

## 3. Parâmetros e física

As medidas são coordenadas de projeto. Escalar a apresentação não altera a física nem os mapas. Manter estes parâmetros em uma configuração central do futuro projeto.

| Parâmetro | Valor inicial |
| --- | ---: |
| Área lógica de referência | 720 × 1280 |
| Atualização física pretendida | 60 passos/s |
| Raio da bola | 14 unidades |
| Raio para iniciar o toque | 72 unidades |
| Zona neutra de arraste | 12 unidades |
| Arraste máximo útil | 180 unidades |
| Velocidade inicial máxima | 1.000 unidades/s |
| Desaceleração em campo livre | 500 unidades/s² |
| Coeficiente de rebote | 0,78 |
| Limiar de parada | 12 unidades/s |
| Confirmação de parada | 0,12 s |
| Raio de captura do buraco | 22 unidades |
| Velocidade máxima de captura | 150 unidades/s |
| Feedback de conclusão | Aproximadamente 0,7 s |

A bola usa `CharacterBody3D`. Aplicar frenagem horizontal quando apoiada e gravidade real de 9,8 m/s². Rampas projetam o movimento sobre a superfície; ao sair da borda conservar o movimento vertical, permitindo pequenos saltos. No ar, suspender a frenagem do piso. Não há vento. Em colisão com uma parede, refletir a componente normal da velocidade e multiplicá-la por 0,78; preservar a componente tangencial. A desaceleração continua após o impacto. Impedir atravessar paredes, inclusive na potência máxima.

Se a esfera estiver apoiada e sua velocidade horizontal permanecer abaixo de 12 unidades/s durante 0,12 s, zerá-la e liberar a bola. Interromper essa confirmação se a velocidade deixar de satisfazer o limiar. Verificar captura antes de liberar uma nova tacada no mesmo passo.

Capturar somente quando apoiada na altura do buraco, com distância horizontal de até 22 unidades e velocidade horizontal de até 150 unidades/s. O alvo é uma região de captura, sem parede circular adicional. Uma passagem mais rápida não conclui o buraco.

## 4. Captura e pontuação sem duplicação

Manter `resultados`, `tacadas_atuais` e um valor separado `tacadas_capturadas` para o feedback. Durante a sessão:

```text
total = soma(resultados) + tacadas_atuais
```

Ao aceitar uma captura, fazer uma única transição atômica:

1. Marcar o buraco como concluído, bloquear entrada e zerar a velocidade.
2. Copiar `tacadas_atuais` para `tacadas_capturadas` e acrescentá-las a `resultados`.
3. Zerar `tacadas_atuais` na mesma transição, antes de atualizar a interface.
4. Mostrar apenas `tacadas_capturadas` no feedback e iniciar o intervalo de aproximadamente 0,7 s.
5. Após o intervalo, abrir o próximo mapa ou o resultado, uma única vez.

Usar guardas de transição para impedir que callbacks repetidos de colisão, captura ou temporizador registrem o mesmo buraco ou avancem duas vezes. Não somar o valor usado pelo feedback ao total. Exemplo: capturar um buraco com 3 tacadas deixa `resultados = [3]`, `tacadas_atuais = 0` e `total = 3`, inclusive durante o feedback. Uma sessão com resultados 3, 4 e 5 termina com 12.

Mira, cancelamento, toque inválido, pausa e reposicionamento não acrescentam tacadas. Somente sessões com os três buracos concluídos podem atualizar o melhor total.

## 5. Fora de jogo e retorno

Cair na água do mapa 03 inicia o retorno. Cruzar o vão no ar permanece permitido. Aplicar a mesma recuperação se a bola escapar da região válida por falha de colisão.

Manter a tacada já contada, sem penalidade adicional. Após uma indicação breve de retorno, restaurar a posição imediatamente anterior ao último lançamento, zerar a velocidade, limpar a mira e liberar a bola. Se a posição guardada for inválida, usar a posição inicial do mapa. A duração inicial do retorno é 0,35 s; sua contagem fica congelada durante pausa.

## 6. Percursos

Origem no canto superior esquerdo; `x` cresce para a direita e `y` para baixo. Todos os mapas têm bordas em `x = 64 a 656` e `y = 200 a 1100`. As superfícies externas coincidem com essas bordas; os centros da bola também precisam respeitar o raio de 14 unidades. Retângulos usam **(x, y, largura, altura)**.

| Mapa | Nome | Posição inicial | Buraco | Paredes internas | Fora de jogo |
| --- | --- | --- | --- | --- | --- |
| 01 | Linha livre | (360, 990) | (360, 260) | Nenhuma | Nenhum |
| 02 | Volta pela lateral | (260, 990) | (260, 280) | (64, 550, 366, 28) | Nenhum |
| 03 | Passagem estreita | (360, 990) | (360, 280) | (248, 650, 224, 28) e (64, 360, 136, 28) | (520, 460, 136, 180) |

| Mapa | Rota de referência | Comprimentos dos segmentos |
| --- | --- | --- |
| 01 | (360, 990) → (360, 260) | 730,00 unidades |
| 02 | (260, 990) → (540, 760) → (540, 440) → (260, 280) | 362,35; 320,00; 322,49 unidades |
| 03 | (360, 990) → (170, 780) → (170, 460) → (360, 280) | 283,20; 320,00; 261,73 unidades |

As rotas são segmentos de referência, sem automação ou garantia de solução mínima. Rebater no mapa 02 é uma alternativa. Não há desbloqueios, mapas aleatórios, estrelas ou seleção de dificuldade.

A verificação geométrica da especificação encontrou segmentos livres dentro das bordas, considerando obstáculos e área fora de jogo ampliados pelo raio da bola. O modelo contínuo em campo livre permite distância nominal de parada de 1.000 unidades com a velocidade e a desaceleração previstas. Essas verificações não validam colisões da engine, conforto de controle ou jogabilidade.

## 7. Interrupções e abandono

Registrar motivos de pausa independentes, incluindo perda de foco, suspensão do aplicativo e confirmação de abandono. Retomar somente quando **todos** os motivos deixarem de existir. Durante pausa, congelar física e todos os temporizadores da sessão, incluindo confirmação de parada de 0,12 s, feedback de captura de aproximadamente 0,7 s e retorno breve.

Sempre cancelar a mira ativa e invalidar seu toque. Uma bola que estava em movimento preserva posição e velocidade para retomar; uma bola que estava pronta permanece pronta; uma mira cancelada retorna ao estado pronto. Captura e reposicionamento preservam o tempo restante e não repetem suas transições.

Abrir a confirmação é permitido nos estados pronto, mirando e em movimento. Durante captura ou reposicionamento, o acesso ao menu fica desativado até o estado pronto ou o resultado. Continuar fecha apenas o motivo de pausa da confirmação; se o aplicativo ainda estiver inativo, a sessão continua suspensa. Confirmar abandono descarta a sessão e volta ao menu, sem gravação de resultado parcial.

## 8. Melhor total e salvamento

Guardar um único registro local, sem dados pessoais ou credenciais:

```json
{
  "schema_version": 1,
  "best_total": null
}
```

`best_total` pode ser `null` ou um inteiro de pelo menos 3. Manter separados:

| Dado | Regra |
| --- | --- |
| `persisted_best` | Melhor total lido de um registro válido; só muda após uma gravação bem-sucedida. |
| `best_this_execution` | Menor total entre o valor persistido válido inicial e todas as sessões válidas concluídas nesta execução. |

Ao concluir uma sessão, atualizar `best_this_execution` com o menor total e, se ele for menor que o persistido ou não houver persistido, tentar gravá-lo. Uma sessão posterior também pode tentar salvar um melhor total anterior que permaneceu apenas em memória. Empates e resultados piores não substituem um recorde já salvo. Proteger a conclusão da sessão para executar essa atualização e tentativa uma única vez por sessão.

Em leitura ausente ou inválida, permitir jogar sem recorde válido. Se a versão do formato for desconhecida, preservar o arquivo e desativar gravações nele durante **toda a execução**, inclusive após repetir ou voltar ao menu. Não há migração automática.

Gravar em arquivo temporário, validar a conclusão da escrita e fazer substituição atômica apenas após sucesso; preservar o arquivo anterior até essa substituição. Falha de escrita não altera `persisted_best`. Conservar `best_this_execution` em memória ao repetir ou voltar ao menu e identificar resultados pendentes como **não salvos**. Fechar o aplicativo perde esses resultados pendentes; não tentar gravar no abandono ou no fechamento.

A interface distingue melhor total nesta execução de recorde salvo, conforme [TELAS.md](TELAS.md). Uma falha ou um formato desconhecido não impede jogar, concluir ou consultar o resultado.

## 9. Responsabilidades para implementação

| Componente | Contrato |
| --- | --- |
| Entrada | Toque/mouse, interação ativa, cancelamento, direção e potência. |
| Bola | Velocidade, desaceleração, colisão, confirmação de repouso. |
| Percurso | Dados dos mapas, paredes, alvo, região válida e fora de jogo. |
| Sessão | Estados, motivos de pausa, pontuação, guardas de transição, avanço e encerramento. |
| Interface | Telas, contadores, feedback, confirmação e distinção entre total salvo e não salvo. |
| Salvamento | Leitura, validação e gravação atômica sem bloquear a partida. |

Separar dados dos mapas da física e manter pontuação e transições verificáveis sem depender da aparência. A escolha dos nós e cenas pertence à implementação.

## 10. Validação necessária

Os comportamentos receberam verificações em engine/Linux, registradas no [relatório](VALIDACAO_3D.md). Avaliação humana e testes no iPhone permanecem pendentes. Verificar controles, limites de potência, paredes na velocidade máxima, repouso, captura lenta/rápida, retorno sem penalidade, avanço único, total durante captura, pausa em todos os estados e combinação de motivos de pausa. Cobrir leitura inválida/desconhecida, falha e recuperação de escrita, repetição, abandono e funcionamento offline.

Toque, área segura, desempenho e persistência no iPhone exigem execução real no aparelho; testes de mouse ou em outro ambiente não os substituem. Os critérios e as novas condições de altura estão no GDD e na conversão 3D.
