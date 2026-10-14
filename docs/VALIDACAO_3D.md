# Validação 3D — versão 0.2.0

**Data:** 14/10/2026. **Engine:** Godot 4.6.3. **Alvo:** Linux x86_64, modo headless e janela gráfica nativa, Compatibility/Mesa llvmpipe. Câmera ortográfica inclinada em viewport próprio; interface 432 × 768 no teste gráfico.

## Resultados

| Verificação | Resultado |
| --- | --- |
| Importação e suíte headless | 260 verificações, zero falhas |
| Suíte em janela gráfica | 260 verificações, zero falhas |
| Casos específicos de 3D | 31 verificações contra corpo, câmera e colisores reais |
| Regressões anteriores | 229 verificações de regras, salvamento e interface; adaptador plano somente nos testes legados |
| Partida por eventos de mouse projetados pela câmera | Três percursos concluídos em `[1, 5, 4]`, total 10, recorde gravado e relido |
| Captura gráfica da interface e dos mapas | Oito PNGs, fluxo completo e zero falhas |
| Suíte com criação de sockets bloqueada | 260 verificações, zero falhas; fluxo offline |
| PCK iniciado fora do checkout | Partida 3D completa `[1, 5, 4]`, recorde relido e oito capturas, zero falhas |

O runner também rejeita uma suíte 3D interrompida ou que não concluiu, em vez de considerar os testes anteriores como validação do cenário novo. A contagem acima corresponde aos casos efetivamente executados.

## O que foi exercitado em 3D

- Esfera cai pela gravidade e encontra o piso com colisão real.
- Colisão com parede na velocidade inicial máxima, sem atravessamento.
- Subida de rampa e repouso no terraço de 0,60 m.
- Salto natural pela rampa, passagem aérea sobre a água e aterrissagem.
- Passagem no ar sobre o buraco sem pontuação; captura após aterrissagem lenta.
- Retorno após queda na água, restaurando posição e altura segura sem penalidade adicional.
- Pouso no topo de um obstáculo, confirmação de repouso e mira preservando essa altura.
- Retorno à borda elevada da rampa, embora sua projeção coincida com o limite da área de água.
- Pausa preserva posição e velocidade do corpo, inclusive no ar.
- Mouse e toque projetados na câmera, inclusive ao iniciar mira em altura.
- Sessão completa com tacadas por entrada real e persistência do resultado.

Os dados injetados em casos específicos preparam cenários de teste; a sessão completa usa lançamentos e colisões reais, sem injetar a conclusão dos buracos. O total 10 é uma execução reproduzível, não um mínimo garantido.

## Comandos

```sh
sh scripts/dev.sh import
sh scripts/dev.sh test
sh scripts/cloud-display.sh
DISPLAY=:99 XAUTHORITY=/workspace/.runtime/xvfb/Xauthority \
  LIBGL_ALWAYS_SOFTWARE=1 sh scripts/dev.sh capture
sh scripts/dev.sh build
```

O driver virtual informa que não suporta mudança de V-Sync. A renderização e as verificações concluíram; isso não mede desempenho no iPhone.

As capturas atuais estão em [menu](images/menu.png), [percurso 03](images/partida.png) e [resultado](images/resultado.png).

Para testar o PCK sem incluir testes na entrega, o driver gráfico pode ser carregado externamente:

```sh
godot --main-pack builds/gamelab.pck --audio-driver Dummy \
  --script /caminho/game-lab-dev/tests/capture.gd \
  -- --driver-path=/caminho/game-lab-dev/tests/test_3d.gd
```

## Limites

Os controles em aparelho, área segura real, suspensão iOS, desempenho, calibração e avaliação humana ainda exigem teste próprio. Não houve exportação iOS nesta revisão. Os records planos anteriores permanecem no arquivo anterior; esta versão usa `record_3d.json`.

O [relatório anterior](VALIDACAO.md) é histórico da versão plana. As regras e alturas atuais estão no [GDD](GDD.md) e na [conversão 3D](CONVERSAO_3D.md).
