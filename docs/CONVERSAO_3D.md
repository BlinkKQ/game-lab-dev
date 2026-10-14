# GameLab Minigolfe 3D — revisão de escopo

**Versão do projeto:** 0.3.0. **Engine:** Godot 4.6.3. Esta revisão atende ao pedido de mapa 3D com rampas, alturas e pequenos saltos. O jogo continua individual, offline, vertical e com três percursos em ordem fixa.

## O que mudou

O cenário é construído por nós e malhas 3D: pisos, rampas, paredes, bola esférica, alvo, bandeira, câmera e luzes. A bola é um `CharacterBody3D` com `SphereShape3D`; ela se move contra os colisores reais dos pisos e paredes. A interface de menu, pontuação e confirmação continua sobre o cenário.

As coordenadas dos mapas anteriores são uma grade de navegação. Cada 100 unidades lógicas representa 1 metro. O eixo X da grade vira X no mundo, o eixo Y da grade vira Z, e a altura passa a ser Y no mundo. O piso principal tem 5,92 × 9 metros e a esfera tem raio de 0,14 metro.

## Percursos e alturas

| Percurso | Terreno 3D | Caminho disponível |
| --- | --- | --- |
| 01 — Bosque Sereno | Piso principal plano. Rampa opcional em x480–620/y520–740 sobe 0,30 m; patamar em y400–520 | A rota central até o buraco continua livre; a rampa permite experimentar altura |
| 02 — Terraços do Sol | Piso inferior até y700; rampa em toda a largura de y700 a y450; terraço superior de 0,60 m até y200. O buraco está no terraço | Contornar a barreira pela direita, subir e ajustar a tacada no nível superior |
| 03 — Travessia Azul | Vão com água em x520–656/y460–640. Rampa em x520–646/y640–740 sobe 0,34 m e termina na borda | Rota esquerda segura ou tentativa de salto pela direita; ambos usam o mesmo alvo |

Os pisos e seus lados têm colisão. A água é uma área de retorno, sem transporte ou natação. As paredes externas acompanham a altura do terreno para cercar a rampa e o terraço.

## Movimento e controle

O gesto continua sendo tocar perto da bola, puxar e soltar. A câmera de jogo usa perspectiva e segue a bola; o botão de visão geral mostra o campo inteiro com projeção ortográfica inclinada. Durante a mira e a pausa, a câmera fica imóvel. A posição do toque é projetada para o plano da altura atual da bola; isso mantém o controle correto ao iniciar uma mira no terraço ou em uma rampa. Redimensionar a janela cancela um gesto em curso.

- Velocidade horizontal inicial máxima: 10 m/s, equivalente às 1.000 unidades/s anteriores.
- Frenagem horizontal no piso: 5 m/s². O contato e a gravidade também afetam o movimento nas rampas.
- Gravidade: 9,8 m/s². No ar, não aplicar a frenagem do piso.
- Ao sair da borda de uma rampa, conservar o movimento vertical adquirido; o salto acontece pela tacada, sem botão adicional.
- Aterrissagens deslizam sobre o piso. Paredes reduzem apenas a componente normal do rebote por 0,78.
- Liberar nova mira apenas após repouso apoiado no terreno durante 0,12 s. A passagem pelo ápice de um salto não conta como repouso.
- Capturar somente com apoio, proximidade e velocidade válidos na altura do buraco. Passar por cima dele no ar não conclui o percurso.
- Cair na água ou escapar dos limites retorna à posição e altura segura anteriores, sem tacada adicional.

Todo movimento e os temporizadores da sessão permanecem congelados durante pausa. Continuar, repetir, abandonar e contar resultados seguem as regras de pontuação do GDD.

## Recorde e preservação

O recorde desta versão fica em `user://record_3d.json`, com o mesmo formato validado `schema_version` e `best_total`. O arquivo anterior `record.json` permanece preservado. Os totais de percursos com alturas não são comparados ao recorde do protótipo plano.

A versão anterior está preservada no commit `a34a6e7` e na branch local `archive/2d-v0.1.1`. A conversão usa o mesmo checkout; não é necessário criar worktree.

## Como abrir

Baixe os arquivos atualizados, extraia o ZIP, importe `project.godot` no Godot 4.6.3 e pressione F5. A cena principal carrega o mapa 3D automaticamente; não é preciso escolher uma cena adicional nem montar o terreno manualmente.

## Validação

Os testes 3D exercitam gravidade, pisos reais, colisão na velocidade máxima, subida de rampa, terraço, salto sobre o vão, aterrissagem, captura somente apoiada, retorno, pausa, controle por câmera e partida completa com salvamento. O fluxo por eventos de mouse concluiu os três mapas com `[1, 5, 4]`, total 10; isso é uma execução de teste, sem promessa de solução mínima.

As regressões anteriores também continuam executadas. Elas usam o adaptador plano nos testes e não constituem, sozinhas, evidência de física 3D. Consulte o [relatório de validação](VALIDACAO_3D.md) para comandos e resultados desta revisão.

Avaliação humana da jogabilidade, calibração e execução real no iPhone permanecem pendentes. A alteração para 3D não significa que uma exportação iOS foi produzida.
