# Feir Controller

Aplicativo comunitário para Windows que transforma controles USB compatíveis com o Feir em controles DualShock 4 virtuais. Projeto independente da Feir e da Sony.

## Compatibilidade

- Windows 10 ou 11 x64 com Windows PowerShell 5.1 e .NET Framework 4.8.
- Controles USB DirectInput com ID `VID_0810&PID_0001`. Esse ID é compartilhado por vários modelos, e o comportamento dos eixos pode variar.
- Até dois controles, com perfis separados. O Windows detectou dois DualShock 4 virtuais simultâneos. O teste completo com dois controles físicos está pendente.

## Instalação

1. Instale o [Microsoft Visual C++ Redistributable x64](https://aka.ms/vc14/vc_redist.x64.exe) e o [ViGEmBus 1.22.0](https://github.com/nefarius/ViGEmBus/releases/tag/v1.22.0). O ViGEmBus foi arquivado pelo mantenedor.
2. Baixe o código em **Code → Download ZIP** e extraia em uma pasta sua, como Documentos.
3. Com o **Windows PowerShell** de 64 bits aberto na pasta extraída, execute `.\build.ps1`. O script baixa as dependências de uma versão fixa, verifica o SHA-256 e compila o aplicativo.
4. Abra `dist\Feir Controller.exe`. Mantenha os arquivos da pasta `dist` juntos. Você pode criar um atalho para o executável na área de trabalho.

## Como usar

Conecte o controle, abra o aplicativo e escolha **Controle 1** ou **Controle 2**. Selecione uma função e clique em **Detectar botão** ou escolha um botão na lista. Clique em **Salvar mapeamento** para aplicar. A coluna **Entrada** mostra as funções acionadas. **Restaurar padrão** recupera as atribuições originais quando você salva.

O aplicativo remapeia 12 botões. O direcional e os analógicos seguem o mapeamento original. Fechar a janela mantém a emulação na bandeja. Para desligar, use **Sair** no menu do ícone. **Iniciar com o Windows** é opcional para a conta atual.

## Solução de problemas

- **Controle desconectado:** teste o controle físico em `joy.cpl` e confira seu VID/PID no Gerenciador de Dispositivos.
- **Analógicos sem resposta:** teste o botão **ANALOG** no controle e confira os eixos em `joy.cpl`.
- **Jogo sem símbolos de PlayStation:** o jogo precisa oferecer suporte aos ícones e ao DualShock 4. Confira também a configuração do Steam Input, se aplicável.
- **Dois dispositivos aparecem no jogo:** se o jogo oferecer seleção de entrada, escolha o DualShock 4 virtual. O Windows também expõe o dispositivo físico.
- **Emulação não abre:** confira o serviço `ViGEmBus` e a instalação do Visual C++ x64.

## Desenvolvimento

| Arquivo | Função |
| --- | --- |
| `FeirHost.cs` | Executável WinForms e desenho suavizado |
| `Feir-DualShock4.ps1` | Entrada DirectInput, emulação e bandeja |
| `Feir-Interface.ps1` | Interface, perfis e inicialização opcional |
| `build.ps1` | Obtenção das bibliotecas e compilação |

Feche o aplicativo antes de recompilar. Os perfis são arquivos JSON em `dist`. Consulte [CONTRIBUTING.md](CONTRIBUTING.md) para relatar problemas ou enviar alterações.

O build baixa as bibliotecas publicadas no [UCR v0.9.0](https://github.com/Snoothy/UCR/releases/tag/v0.9.0). O aplicativo usa [SharpDX](https://github.com/sharpdx/SharpDX) para DirectInput e [ViGEm](https://github.com/nefarius/ViGEmBus) para a saída virtual. As dependências têm licenças próprias.

