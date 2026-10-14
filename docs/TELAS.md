# GameLab Minigolfe — telas e interação

**Fase:** 4 — protótipo construído.  
**Fonte:** [GDD v0.2](GDD.md) e [MECANICAS.md](MECANICAS.md).  
**Situação:** telas implementadas e inspecionadas em janela nativa Linux. Veja [VALIDACAO.md](VALIDACAO.md); testes no iPhone pendentes.

O jogo usa apresentação 2D superior e vertical, com três percursos offline. O iPhone é o primeiro alvo; mouse no computador permite desenvolver o mesmo fluxo. Não há contas, rede, ranking de outras pessoas ou publicação nesta fase.

## 1. Apresentação e área segura

Usar referência lógica de **720 × 1280**, escalando uniformemente o campo completo para caber na área segura. Preservar proporções e coordenadas dos mapas; adaptar o fundo ao espaço restante. Não cortar alvo, bola, textos ou botões essenciais, nem colocá-los sob recortes e áreas reservadas do sistema. Converter o toque para coordenadas lógicas antes de calcular a mira.

| Elemento | Apresentação inicial |
| --- | --- |
| Fundo | `#101827` |
| Campo | `#183E35` |
| Bola e textos | `#F3F6FA` |
| Alvo e detalhes | `#50D9D0` |
| Aviso e fora de jogo | `#F7A546` |

Usar geometria simples, bordas distinguíveis nos obstáculos e aro ciano no alvo. A região fora de jogo combina marcação laranja com símbolo próprio. Cor não é o único indicador. Textos, números e símbolos permitem entender força, pontuação e avisos. Evitar texturas que disputem atenção com a bola.

Os textos explicam ações do jogador. Coeficientes físicos, versões internas e opções de depuração ficam fora da interface normal.

## 2. Menu

| Conteúdo | Texto ou regra |
| --- | --- |
| Título | “GameLab Minigolfe”, nome de trabalho. |
| Ação principal | “Jogar”. Inicia mapa 01 com contadores zerados. |
| Recorde | “Melhor total salvo: X” quando existir um valor persistido válido; caso contrário, “Ainda sem recorde salvo”. |
| Melhor total pendente | Se a execução tiver um resultado melhor ainda não salvo, mostrar “Melhor total nesta execução: X — não salvo”. |
| Instrução | “Toque perto da bola, puxe e solte para lançar.” |
| Complemento | “Puxe mais para aumentar a força. Volte ao ponto inicial do toque para cancelar.” |

Voltar ao menu preserva o recorde salvo e o melhor total em memória, mas descarta a sessão abandonada. Não há entrada física para a bola no menu.

## 3. Partida e mira

Mostrar campo inteiro, bola, alvo, número do buraco **1/3, 2/3 ou 3/3**, tacadas do buraco atual, total acumulado e acesso ao menu. Os mapas seguem a ordem Linha livre, Volta pela lateral e Passagem estreita.

| Estado | Apresentação e entrada |
| --- | --- |
| Bola pronta | Bola parada; aceitar início de mira a até 72 unidades do centro. Menu disponível. |
| Mirando | Bola parada; seta inicial, barra e percentual seguem o arraste. Menu disponível por ação independente. |
| Em movimento | Mostrar movimento e contadores; bloquear novas tacadas. Menu disponível. |
| Reposicionar | Indicar retorno breve, bloquear tacadas e desativar menu até finalizar. |
| Buraco concluído | Mostrar feedback, bloquear tacadas e desativar menu durante a transição. |

A seta mostra apenas a direção inicial, sem prever rebotes. A zona neutra de até **12 unidades** não mostra seta de lançamento. A potência máxima ocorre em **180 unidades** de arraste. Usar o percentual arredondado para as faixas visuais: ciano até **33%**, amarelo de **34% a 66%** e laranja a partir de **67%**. A barra e o número continuam distinguindo intensidade sem depender da cor.

O dedo que iniciou a mira conserva a interação mesmo passando sobre o botão de menu; esse arraste não ativa o botão. Uma ação deliberada e independente, como `Esc` ou novo toque diretamente no menu, cancela a mira e abre a confirmação. Outros dedos fora desse comando da interface não assumem a mira. O mouse usa pressionar, arrastar e soltar com as mesmas regras.

Atualizar os contadores somente a partir do estado da sessão. O total é a soma dos resultados concluídos com as tacadas atuais. Não acrescentar o número mostrado no feedback de captura novamente ao total.

## 4. Confirmação de abandono

Exibir sobre a partida:

> Voltar ao menu? A partida atual será encerrada.

| Ação | Efeito |
| --- | --- |
| “Continuar” | Fecha a confirmação e preserva a sessão. Retoma somente quando não houver outro motivo de pausa. |
| “Voltar ao menu” | Descarta a sessão, sem resultado parcial ou tentativa de salvar recorde. |

Abrir a confirmação cancela a mira e congela física e temporizadores. Ao continuar, a mira cancelada precisa de um novo toque. A bola que estava em movimento retoma a posição e a velocidade preservadas. Eventos de soltura antigos não lançam a bola.

## 5. Retorno e conclusão do buraco

**Fora de jogo:** mostrar uma indicação breve de retorno e restaurar a posição anterior ao último lançamento. Manter a tacada já contada, sem penalidade adicional. Retomar com velocidade zero e mira limpa. A duração inicial desse feedback é 0,35 s.

**Captura:** mostrar “Buraco concluído” e a quantidade de tacadas daquele buraco por aproximadamente **0,7 s**. O valor vem de uma cópia registrada na captura, mesmo após zerar o contador atual. No mesmo instante da captura, o resultado passa à lista e o contador atual vira zero: o total permanece correto durante todo o feedback.

Após os mapas 01 e 02, avançar automaticamente ao seguinte. Após o mapa 03, abrir o resultado. Guardas da sessão impedem registrar ou avançar duas vezes. Durante retorno ou captura, o botão de menu fica desativado até o próximo estado pronto ou o resultado.

## 6. Resultado e estados de salvamento

Exibir tacadas dos três buracos, total da sessão, melhor total salvo e, quando aplicável, melhor total desta execução ainda não salvo. Exemplo de resultados: **3 + 4 + 5 = 12**. As ações são “Jogar novamente” e “Menu”; não há entrada física para a bola.

O melhor resultado alcançado e o recorde persistido são informações distintas. A gravação bem-sucedida é necessária para afirmar que o total foi salvo.

| Situação | Retorno ao jogador |
| --- | --- |
| Primeiro total válido ou melhora nesta execução | Pode mostrar “Novo melhor total!” sobre o resultado alcançado. |
| Gravação concluída | “Recorde salvo: X”. Atualizar o melhor total salvo. |
| Gravação falhou | “O recorde não pôde ser salvo.” e “Melhor total nesta execução: X — não salvo”. Preservar o recorde salvo anterior, se existir. |
| Gravação desativada por formato desconhecido | “O recorde não foi salvo.” e indicar o melhor total desta execução como não salvo. Preservar o arquivo existente. |
| Empate ou total pior, sem melhor pendente | Mostrar o resultado e o recorde salvo existente; não anunciar uma melhora. |

Um melhor total pendente pode ser de uma sessão anterior nesta mesma execução. Ao concluir outra sessão, a aplicação tenta salvar esse melhor valor se ele for menor que o persistido, ou se não houver persistido, e o formato permitir escrita. A interface só remove o estado “não salvo” após sucesso. Repetir ou voltar ao menu conserva o melhor em memória; fechar o aplicativo perde o valor não salvo. Não prometer persistência após reabrir.

## 7. Interrupção do aplicativo

Ao perder foco ou ser suspenso, cancelar a mira e pausar a sessão. Congelar movimento e todos os temporizadores: confirmação de repouso de **0,12 s**, feedback de captura de aproximadamente **0,7 s** e retorno breve. Ao retornar, continuar com o tempo restante e o estado preservado, sem nova contagem de tacada ou avanço repetido.

Tratar os motivos de pausa separadamente. Se a confirmação de abandono estiver aberta quando o aplicativo retornar, mantê-la aberta e a sessão suspensa. Fechar a confirmação não retoma a sessão enquanto o aplicativo continuar inativo. A retomada ocorre apenas quando todos os motivos terminarem.

## 8. Som e verificação

O fluxo deve ser compreensível apenas pela apresentação visual. Sons próprios ou autorizados de lançamento, colisão e captura podem ser adicionados no polimento; limitar a frequência dos sons de colisão. Música, voz e controles de volume não bloqueiam a primeira avaliação. Não reutilizar áudio da referência.

Verificar o campo completo em proporções distintas, legibilidade, alinhamento do toque, acesso deliberado ao menu durante mira, contadores durante captura e avisos de gravação. Testar interrupções em mira, movimento, captura, retorno e confirmação de abandono, incluindo motivos simultâneos de pausa.

Toque, área segura, desempenho e persistência no iPhone exigem teste real no aparelho. O PCK foi construído e verificado em Linux. Exportação iOS, publicação e distribuição permanecem pendentes.
