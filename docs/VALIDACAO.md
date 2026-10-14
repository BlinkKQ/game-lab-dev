# Validação do protótipo — Linux

**Data:** 14/10/2026. **Engine:** Godot 4.6.3 estável oficial. **Projeto:** GameLab Minigolfe 0.1.1. **Alvo executado:** Linux x86_64; janela nativa 432 × 768 com renderizador Compatibility/Mesa llvmpipe. A execução gráfica usou Xvfb autenticado, sem porta TCP.

As evidências correspondem à versão 0.1.1 deste checkout e ao PCK gerado com ela. Esta validação não representa publicação do jogo, exportação iOS ou aceite no aparelho.

## Resultados executados

| Verificação | Resultado observado |
| --- | --- |
| Importação do projeto com Godot 4.6.3 | Concluída, sem erros de scripts ou recursos |
| `sh scripts/dev.sh test` | 229 verificações, zero falhas, código de saída 0 |
| Suíte com criação de sockets bloqueada por `strace` | 227 verificações da versão 0.1.0, zero falhas; não repetida na revisão 0.1.1 |
| Percursos por arrastes e física a 60 passos/s | Resultados `[1, 3, 3]`, total 7; nenhuma posição de bola ou pontuação injetada na sessão completa |
| Janela nativa, teste `tests/capture.gd` | Oito PNGs, menu → três mapas → resultado, total 7 salvo e relido do arquivo, zero falhas |
| `sh scripts/dev.sh build` | PCK gerado com cena e scripts compilados; testes/documentos excluídos |
| PCK iniciado fora do diretório do projeto | Teste gráfico completo com `[1, 3, 3]`, recorde 7 relido, oito capturas, zero falhas |

O driver virtual informou que não suporta mudança de V-Sync. A renderização e o ciclo do jogo concluíram normalmente; essa execução não mede desempenho de iPhone.

## Cobertura e limites dos critérios

| Critérios | Evidência obtida nesta entrega | O que permanece pendente |
| --- | --- | --- |
| AC-01–AC-06, AC-09, AC-26–AC-27 | Modelo e eventos reais do viewport: início, zona neutra, potência, gesto exclusivo, solturas antigas, menu e mouse emulado | Toque e interação no aparelho; conforto avaliado por uma pessoa |
| AC-07–AC-12, AC-29–AC-30 | Frenagem, repouso, captura rápida/lenta, colisões contínuas em paredes/cantos e retorno sem penalidade | Calibração e experiência real de jogo no aparelho |
| AC-13–AC-15, AC-23 | Sessão completa, troca ordenada de mapas, repetição/abandono, totais 3/7/12 durante feedback e guardas contra duplicação | Avaliação manual e execução iPhone |
| AC-16–AC-18, AC-24, AC-28 | Gravação e reabertura, JSON integral/inválido, formato desconhecido preservado, falhas de abertura/escrita/substituição e nova tentativa | Persistência e comportamento do sistema de arquivos no iPhone |
| AC-19, AC-21, AC-25 | Cancelamento de mira, pausas independentes, confirmação/foco sobrepostos e temporizadores congelados | Suspensão e notificações reais no iPhone |
| AC-20 | Transformações em quatro proporções, área segura simulada, renderização e inspeção dos oito estados a 432 × 768 | Recortes e área segura reais; teste visual em mais telas e aparelhos |
| AC-22 | Suíte sem criação de sockets; fluxo e recorde locais; PCK sem dependências de serviço | Jogo no aparelho com rede indisponível |

Os critérios têm validação parcial por alvo. O resultado em engine/Linux não marca o aceite no iPhone nem substitui avaliação humana de conforto e diversão.

## Procedimentos reproduzíveis

```sh
sh scripts/dev.sh import
sh scripts/dev.sh test
sh scripts/dev.sh build
```

Para a verificação sem sockets, em Linux com `strace`:

```sh
strace -f -e trace=socket -e inject=socket:error=ENETDOWN \
  -o /tmp/gamelab-offline.log sh scripts/dev.sh test
```

Para renderização nativa no ambiente preparado:

```sh
sh scripts/cloud-display.sh
DISPLAY=:99 XAUTHORITY=/workspace/.runtime/xvfb/Xauthority \
  LIBGL_ALWAYS_SOFTWARE=1 sh scripts/dev.sh capture
```

O mesmo teste foi executado contra o PCK a partir de `/tmp`, carregando o driver de teste pelo caminho absoluto e os recursos do jogo a partir do pacote:

```sh
DISPLAY=:99 XAUTHORITY=/workspace/.runtime/xvfb/Xauthority \
  LIBGL_ALWAYS_SOFTWARE=1 \
  XDG_DATA_HOME=/workspace/.runtime/data \
  XDG_CONFIG_HOME=/workspace/.runtime/config \
  XDG_CACHE_HOME=/workspace/.runtime/cache \
  godot --main-pack /workspace/game-lab-dev/builds/gamelab.pck \
  --audio-driver Dummy \
  --script /workspace/game-lab-dev/tests/capture.gd \
  -- --capture-dir=/workspace/.runtime/packed-captures
```

O teste gráfico usa arquivo de recorde próprio, relê o valor salvo e remove esse arquivo. Os testes de regra/persistência usam nomes únicos no diretório de cache retornado pela engine. O recorde real do jogador não participa das verificações.

## Revisão 0.1.1 e entrega

O ZIP da versão anterior foi extraído em um diretório novo, sem cache Godot; importação, 227 verificações e inicialização concluíram. O erro de download relatado não foi atribuído a corrupção do arquivo. Esta interface não disponibiliza ferramenta de exportação de anexos; um caminho `/workspace` ou link `sandbox:` não confirma uma transferência para o usuário.

A revisão corrigiu um problema reproduzido no jogo: pressionar a bola, redimensionar a janela e soltar no mesmo ponto físico gerava uma tacada de potência máxima. Mudanças na transformação agora cancelam a mira e gestos de interface pendentes. Dois testes da cena real verificam o cancelamento e a ausência de tacada.

Os caminhos de teste passaram a usar o cache da engine e o README inclui instruções Windows sem shell POSIX. A entrega pelo repositório GitHub depende de autorização para enviar os arquivos; nenhum push foi feito durante a preparação desta revisão.

## Capturas do jogo nativo

As imagens foram geradas pelo viewport real, durante o teste do fluxo:

- [Menu](images/menu.png)
- [Percurso 03](images/partida.png)
- [Resultado](images/resultado.png)

## Escolhas da implementação

- Engine fixada em 4.6.3; renderização compatível por desenho vetorial em `Node2D`.
- Movimento determinístico com desaceleração constante, varredura contínua de círculo contra paredes/retângulos e cantos arredondados; rebote reduz só a componente normal.
- Retorno breve fixado inicialmente em 0,35 s. Os demais parâmetros e as coordenadas dos três mapas foram preservados.
- Arquivo de recorde em `user://record.json`, escrito em temporário no mesmo diretório e substituído sem apagar o anterior antes.
- Todo registro público do desempenho ou aceite no iPhone exige nova evidência no aparelho. Calibração e distribuição privada seguem o [roadmap](ROADMAP.md).
