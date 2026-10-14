# Validação 3D — versão 0.3.0

**Data:** 14/10/2026. **Engine:** Godot 4.6.3. **Alvo:** Linux x86_64, headless e janela nativa com Compatibility/Mesa llvmpipe. Interface 432 × 768; cenário em viewport 592 × 900. Câmera de jogo em perspectiva e visão geral ortográfica.

## Resultados

| Verificação | Resultado |
| --- | --- |
| Importação e suíte headless | 292 verificações, zero falhas |
| Suíte em janela gráfica | 292 verificações, zero falhas |
| Física e entrada nativas 3D | 31 verificações contra corpo, câmera e colisores reais |
| Nova câmera, gestos e áudio | 32 verificações de interação, pausa, altura e silenciamento |
| Regressões anteriores | 229 verificações de regras, salvamento e interface; adaptador plano apenas nos testes legados |
| Partida por eventos reais de mouse | Três percursos em `[1, 5, 4]`, total 10; recorde gravado e relido |
| Captura gráfica | Oito PNGs de menu, partida, mira, confirmação, captura, três temas e resultado; zero falhas |
| Prévia animada | 89 quadros nativos; mira, câmera acompanhando a tacada e primeiro buraco concluído em uma tacada |
| PCK iniciado fora do checkout | Três percursos, recorde relido e oito capturas; zero falhas |

O runner rejeita suítes 3D e de apresentação interrompidas ou que não concluíram. O total 10 é uma execução reproduzível, sem garantia de solução mínima.

## Casos de risco exercitados

A suíte nativa continua cobrindo gravidade, colisão na velocidade máxima, subida de rampa, terraço elevado, salto natural sobre a água, aterrissagem, captura apenas com apoio e retorno a uma pose segura. Inclui pouso no topo de um obstáculo e retorno à borda elevada da rampa.

Os novos testes mantêm os mesmos pixels de um gesto enquanto o tempo passa: pose e lente da câmera ficam imóveis, preservando direção e potência. A câmera volta a seguir após a soltura e congela durante motivos sobrepostos de pausa. Alternar a visão com outro dedo invalida o gesto anterior; soltar dedos antigos não cria tacada nem nova troca. Mouse e toque também funcionam no patamar de 0,60 m.

Os testes de áudio verificam indicação única de tacada, interrupção ao pausar, silêncio após desativar e retomada sem reproduzir eventos antigos. O driver Dummy verifica o fluxo e a síntese, sem comprovar como os sons ficam nos alto-falantes de um aparelho.

O cenário decorativo usa malhas próprias sem colisores. A água recebe o tempo visual da sessão, que fica congelado na pausa. Plantas repetidas usam MultiMesh; mira, rastro e anéis usam pools com tamanho limitado.

## Comandos

```sh
sh scripts/dev.sh import
sh scripts/dev.sh test
sh scripts/cloud-display.sh
DISPLAY=:99 XAUTHORITY=/workspace/.runtime/xvfb/Xauthority LIBGL_ALWAYS_SOFTWARE=1 sh scripts/dev.sh capture
sh scripts/dev.sh build
```

O display virtual usa autenticação, TCP desativado e a extensão MIT-SHM desativada para permitir redimensionamento entre namespaces de IPC das tarefas. O driver informa que não suporta alterar V-Sync; isso não impediu os testes nem mede desempenho no iPhone.

Para verificar o PCK sem incluir testes no pacote:

```sh
godot --main-pack builds/gamelab.pck --audio-driver Dummy --script /caminho/game-lab-dev/tests/capture.gd -- --driver-path=/caminho/game-lab-dev/tests/test_3d.gd
```

## Imagens e limites

Veja [menu](images/menu.png), [bosque](images/bosque.png), [terraços](images/terracos.png), [lagoa](images/partida.png), [mira](images/mira.png), [resultado](images/resultado.png) e a [prévia animada](images/jogada.gif). A prévia foi capturada do jogo em execução e não possui áudio.

As filmagens de referência e os seus limites estão em [REFERENCIAS_VISUAIS.md](REFERENCIAS_VISUAIS.md). A geometria jogável e os parâmetros físicos da versão 3D foram mantidos; esta revisão concentra-se em apresentação, câmera e efeitos.

Avaliação humana, controles em iPhone, área segura real, suspensão iOS, desempenho e audição dos efeitos no aparelho continuam pendentes. Não houve exportação iOS. A sessão funciona offline e o recorde continua em `record_3d.json`; o arquivo do protótipo plano permanece preservado.

O [relatório plano](VALIDACAO.md) é histórico. A conversão 3D anterior está no commit `63b441e` e na branch local `archive/3d-v0.2.0`.
