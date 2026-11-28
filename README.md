# Feir Controll

Mapeador comunitário para Windows que transforma controles USB compatíveis com o Feir em um DualShock 4 virtual. Projeto independente da Feir e da Sony.

- Remapeamento de 12 botões e das quatro setas do direcional e perfis separados para até dois controles.
- Vibração em jogos, com teste por controle e intensidades de 100%, 160% e 200%.
- Detecção de controles físicos, com apresentação do nome, ID USB e compatibilidade.
- Interface em português, inglês e espanhol, modo bandeja e inicialização opcional com o Windows.

## Compatibilidade

O alvo é Windows 10 22H2 e Windows 11 x64 com .NET Framework 4.8 ou posterior e Windows PowerShell 5.1. O aplicativo foi exercitado no Windows 10 21H2 x64. Windows de 32 bits e ARM64 estão fora do escopo desta versão.

O remapeamento aceita controles DirectInput com ID **0810:0001**. Esse ID é compartilhado por vários modelos. A vibração exige um relatório USB compatível e motores no controle físico. O teste pela Steam e em jogo foi confirmado no controle físico usado no desenvolvimento. Dois controles físicos simultâneos ainda precisam de validação.

## Instalação

1. Instale o [Visual C++ Redistributable x64](https://aka.ms/vc14/vc_redist.x64.exe) e o [usbip-win2 0.9.8.1 x64](https://github.com/vadimgrn/usbip-win2/releases/tag/v.0.9.8.1). Use o instalador assinado da versão de lançamento. Se ele pedir reinicialização, conclua-a antes de abrir o aplicativo.
2. Baixe o instalador **Feir-Controll-Setup-x64.exe** em [Releases](https://github.com/lucasfreitas611/feir-controll/releases). O instalador do projeto ainda não tem assinatura digital. Ele baixa bibliotecas verificadas por SHA-256 e compila o aplicativo localmente com as ferramentas do Windows.
3. Abra **Feir Controll** pelo menu Iniciar.

### Compilar pelo código-fonte

Extraia o ZIP do repositório, abra o **Windows PowerShell 5.1 x64** na pasta e execute **.\build.ps1**. Abra **dist\Feir Controll.exe** mantendo o conteúdo de **dist** junto. Para gerar o instalador, execute **.\package.ps1**.

## Uso

Conecte seu controle, abra o aplicativo e use **Detectar controles** para conferir a compatibilidade. Selecione **Controle 1** ou **Controle 2**. Para remapear, escolha uma função do PlayStation e selecione o botão físico na lista ou use **Detectar botão**. Clique em **Salvar mapeamento** para aplicar. Role a tabela até o fim para encontrar as quatro setas do direcional. Use **Testar controle** para conferir os botões, as diagonais do direcional e os dois analógicos do controle selecionado em tempo real. O desenho usa o mapeamento salvo.

Na Steam, selecione o **PS4 Controller** virtual e ative **Vibração do jogo**. O controle físico também pode aparecer na lista. No Feir Controll, marque **Vibração nos jogos** e ajuste **Intensidade nos jogos**. O resultado depende do jogo e dos motores do controle.

Fechar a janela mantém a emulação na bandeja. Use **Sair** no ícone da bandeja para encerrar. **Iniciar com o Windows** vale para a conta atual. Os arquivos de perfil e preferências ficam na pasta do executável. Ao instalar pelo pacote, a pasta é **%LOCALAPPDATA%\Feir Controll**.

## Desenvolvimento e licenças

- **FeirHost.cs** e **FeirControllTheme.cs** definem o executável WinForms e seus componentes visuais.
- **Feir-Interface.ps1** e **FeirControll-Languages.json** contêm a interface, perfis e traduções.
- **Feir-DualShock4.ps1**, **FeirRumble.cs** e **FeirViiper.cs** cuidam da leitura, emulação e vibração.
- Consulte o [guia de contribuição](CONTRIBUTING.md) para relatar problemas ou enviar alterações.

O código original do Feir Controll está sob a [licença MIT](LICENSE). O instalador carrega o código-fonte do projeto e compila no computador do usuário. As bibliotecas de terceiros são baixadas das publicações originais e mantêm suas próprias licenças. [VIIPER v1.0.1 (código-fonte)](https://github.com/DualSenseClient/VIIPER/tree/v1.0.1) é GPL-3.0 e fornece a emulação USB local. As bibliotecas SharpDX e ViGEm.NET usadas para DirectInput e os tipos de relatório vêm da publicação [UCR v0.9.0](https://github.com/Snoothy/UCR/releases/tag/v0.9.0).

## Problemas comuns

- **Controle físico ausente:** teste em **joy.cpl** e confira o ID USB em **Detectar controles**.
- **Analógicos sem resposta:** confira o botão **ANALOG** do controle físico.
- **Sem vibração:** teste primeiro pelo aplicativo, depois pela Steam no **PS4 Controller** virtual.
- **Dois controles aparecem na Steam:** escolha o PS4 virtual para usar o mapeamento e a vibração.




- **Botão ANALOG:** no Feir testado, com a luz apagada, os eixos compartilhados são interpretados como setas e os analógicos virtuais ficam centralizados. Com a luz acesa, setas e analógicos funcionam de forma independente. A detecção usa o padrão de sinais desse modelo.

