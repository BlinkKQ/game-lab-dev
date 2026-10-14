# Reformulação visual a partir das filmagens

**Versão:** 0.3.0. **Data:** 14/10/2026. As gravações foram usadas como referência de apresentação e comportamento observável. Imagens, sons, nomes, código e arquivos do aplicativo filmado não foram extraídos para o projeto.

## Material analisado

| Gravação | Duração | Trechos úteis |
| --- | --- | --- |
| WhatsApp Video 2026-10-14 at 18.19.54.mp4 | 1 min 37 s | 18–24 s: mira; 24–27 s: movimento e câmera; 48–58 s: rampa e plataforma; 36–38, 61–63 e 83–86 s: captura |
| WhatsApp Video 2026-10-13 at 22.46.45 (1).mp4 | 3 min 54 s | 52–64 s: floresta, enquadramento e rolamento; 116–130 s: subida e captura |
| WhatsApp Video 2026-10-13 at 22.46.45 (2).mp4 | 3 min 54 s | Cópia idêntica da gravação anterior, confirmada por SHA-256 |

Os vídeos ficam fora do repositório e do pacote do jogo. As telas de loja, moedas, personalização, clãs e competição vistas nas gravações não são instruções de implementação.

## Observação e decisão de projeto

| Observado nas filmagens | Aplicação original no GameLab |
| --- | --- |
| Câmera em perspectiva próxima à bola, mudando de enquadramento durante a jogada | Câmera que segue a bola suavemente e botão de visão geral. Congelar a câmera durante mira e pausa |
| Vegetação, rochas e paisagem ao redor do campo | Bosque Sereno, Terraços do Sol e Travessia Azul, construídos com malhas e materiais próprios |
| Mira com pequenas setas e indicação de força por cor | Indicadores de direção, força e puxador com paleta do projeto |
| Rastro e sombra ajudam a acompanhar a bola | Rastro breve e sombra ligada à superfície, sem alterar colisões |
| Círculos e partículas no fim do buraco | Comemoração curta e efeito de captura próprios |
| Curvas, rampas, plataformas e partes em alturas diferentes | Preservar as rampas, terraços e salto reais da versão 3D; esta revisão mantém a geometria jogável dos três percursos |

Os sons desta revisão são síntese original. O efeito de retorno da água pertence ao nosso percurso; não foi observado com clareza nas filmagens.

## O que as filmagens não determinam

O dedo do jogador não aparece. A relação entre arraste e lançamento e quais mudanças de câmera são automáticas continuam sendo inferências. Atrito, gravidade, impulso, atributos dos equipamentos, regras internas e sincronização de rede não podem ser recuperados com exatidão desses vídeos.

O jogo continua individual e offline. O total de tacadas e o recorde 3D mantêm as regras anteriores. O som pode ser desligado durante a execução; não cria arquivos de preferências adicionais.

## Controles acrescentados

- **Visão geral / Seguir bola:** alternar entre o campo inteiro e a câmera próxima. Alternar invalida uma mira em andamento, sem contar tacada.
- **Som: sim / Som: não:** ativar ou silenciar os efeitos. A pausa e a perda de foco interrompem os sons ativos.

A avaliação visual e de jogabilidade em iPhone real continua pendente. A reformulação melhora a apresentação do protótipo; ela não reproduz os sistemas online do aplicativo filmado.
