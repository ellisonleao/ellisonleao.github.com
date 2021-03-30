+++
title = "Criando plugins Lua para Neovim - Parte 2"
date = "2020-11-29"
tags = ["neovim", "lua", "plugin"]
keywords = ["plugin", "neovim", "lua"]
description = "Um plugin para o mundo real"
+++

**Caso ainda não tenha lido a primeira parte dessa série, [clique aqui](/posts/criando-plugins-para-neovim-parte-1/)**

Na segunda parte da nossa série vamos criar um plugin que poderá ser usado no dia-a-dia, onde iremos introduzir algumas funcionalidades
legais do Neovim, como as floating windows e algumas funções da API lua.

Vamos começar relembrando a estrutura de um plugin. Nosso plugin vai possuir a seguinte estrutura

```
weather.nvim
├── lua
│  └── weather.lua
└── plugin
   └── weather.vim
```

A idéia do plugin é mostrar a previsão do tempo atual em uma floating window, sendo chamado a partir de um comando.

Desenhando, vamos ter algo como:

![](/img/weather.png)

## Estrutura do módulo

Nosso módulo `weather.lua` vai conter a seguinte estrutura:

```lua
local M = {}

local function create_command()
-- vamos criar o comando :Weather aqui
end

function M.create_window()
-- aqui vamos criar a janela, um mapping para fechá-la e mostrar o tempo
end

function M.close_window()
-- uma funcao para fechar a janela atual, que sera usada em um mapping
end

return M
```

Analisando uma por uma, temos:

**`create_command()`**

A função `create_command()` vai criar nosso comando customizado (`command!`). Aqui introduzimos o `vim.cmd`,
que pode ser utilizada para chamar comandos `Ex` nativos do vim, mais conhecidos como os comandos `:`.

defininos nosso comando como:

```lua
vim.cmd("command! -bang -nargs=0 Weather lua require('weather').create_window()")
```

com isso, nosso commando, `:Weather`, vai chamar diretamente uma função do nosso módulo lua para esse plugin

**`create_window()`**

a função `create_window()` vai ser responsável por criar uma floating window no canto superior direito da tela e mostrar o conteúdo do tempo.
Para criar uma floating window, precisamos seguir os seguintes passos:

1. criar um buffer "descartável", que será usado para o conteúdo da janela
2. criar as configurações da janela (tamanho de linhas, colunas, posicao x e y na tela)
3. chamar o comando que "abre" a janela
4. criar um mapping para poder fechar a janela
5. criar o conteúdo do buffer, no nosso caso, o tempo atual.

Para o passo 1, temos:

```lua
buf = vim.api.nvim_create_buf(false, true)
```

Aqui temos outra novidade também, o `vim.api` , um conjunto de métodos para o neovim dentro do módulo lua `vim`.
`nvim_create_buf` aceita 2 parâmetros, se o buffer vai ser listado ou não (no nosso caso não, por isso o `false`) e ele será
descartável ou não (no nosso caso sim, por isso o `true`). Para saber mais sobre o método, chame `:help nvim_create_buf`
O método retorna o **id** do novo buffer criado, e a informação desse **id** é importante porque ele será usado para mais coisas
mais pra frente. Note aqui também que não estamos criando a váriavel `buf` dentro desse método, mas uma variável "global"
que também será usada por outros métodos dentro desse módulo.

Para o passo 2, temos:

```lua
  local columns = vim.api.nvim_get_option("columns")
  local lines = vim.api.nvim_get_option("lines")
  local win_height = math.ceil(lines * 0.6 - 8)
  local win_width = math.ceil(columns * 0.3 - 6)
  local x_pos = 1
  local y_pos = columns - win_width

  local configs = {
    relative = "editor",
    style = "minimal",
    width = win_width,
    height = win_height,
    row = x_pos,
    col = y_pos,
  }
```

Primeiro pegamos as variáveis de total de linhas e colunas do buffer atual para
fazer um cálculo proporcional do tamanho da nossa floating window.

`relative="editor"` é a opção que vai dizer que iremos usar as coordenadas x e y globais, relativas ao editor, tendo tamanho
inicial (0,0) até (linhas-1, colunas-1)

`style = "minimal"`, vai deixar nossa janela com configurações mínimas, removendo
a maioria das opções de UI. Isso é essencial para janelas temporárias, onde não iremos
precisar fazer nenhuma alteração.

`width` e `height` é o calculo proporcional do tamanho da janela, adicionando um padding para que ela não fique simplesmente
"grudada" no canto superior direito da tela. Cada unidade de medida corresponde a um
caracter

`row` e `col` vai setar a posição x e y da nossa janela

Para o passo 3, temos:

```lua
win = vim.api.nvim_open_win(buf, true, win_opts)
```

Aqui chamamos a `vim.api.nvim_open_win`, o método que vai abrir nossa janela, usando o buffer que criamos, com a configuração
que passamos. Nos parâmetros, podemos também ver o `true`, que vai setar a janela como a atual. Vamos precisar disso para
chamar o comando que gera o conteúdo da mesma. Note também que nossa variável `win` também é "global", pois vamos precisar
da informação dela para criar os mappings que vão poder fechá-la.

Para o passo 4, temos:

```lua
vim.api.nvim_buf_set_keymap(buf, "n", "q", ":lua require('weather').close_window()<cr>", {noremap = true, silent = true})
```

Usamos o método `nvim_buf_set_keymap` para criar um `nnoremap` local, que basicamente irá chamar outro método, do nosso módulo,
para fechar a janela. Iremos explicar o método `close_window()` mais pra frente.

Como parâmetros, podemos ver que primeiro passamos o buffer **id** que criamos no passo 1, depois o modo, no caso o modo Normal,
depois o comando que esse mapping irá chamar. Aqui podemos ver uma das coisas legais do Neovim com a linguagem Lua já integrada no core,
onde chamamos o método do nosso plugin usando diretamente o comando `:lua`. Finalmente temos uma table com possíveis opções para o mapping, como `noremap`, `silent`, etc. No nosso caso, só queremos que o comando não coloque nenhum output na tela e não utilize nenhum outro mapping com a letra `q`, caso haja algum.

Finalmente para o passo 5, temos:

```lua
local command = "curl https://wttr.in/?0"
vim.api.nvim_call_function("termopen", {command})
```

Aqui nos beneficiamos do terminal embutido no neovim e chamar o comando `curl`, que irá nos trazer o conteúdo do tempo em um terminal embutido na nossa janela. Podemos ver também que nesse caso estamos usando o `vim.api.nvim_call_function`, que basicamente chama a função nativa do vim pelo código lua. No nosso caso, chamamos a função `termopen` e como parâmetros dela, o comando `curl`

**`close_window()`**

A função close window no nosso caso só vai ser uma chamada direta para o `nvim_win_close`:

```lua
vim.api.nvim_win_close(win, true)
```

Aqui passamos a variável `win`, que é o **id** da nossa janela criada e `true` fala que queremos forçar o fechamendo da janela.

## Conclusão

Com isso, nosso primeiro plugin "para o mundo real", está pronto. A versão do código para esse post pode ser vista [clicando aqui](https://github.com/npxbr/criando-plugins-lua-neovim/tree/master/parte-2).

Para ver a versão completa do plugin, com mais customizações, [clique aqui e já manda o star!](https://github.com/npxbr/weather.nvim). Para a parte 3 da nossa série, vamos mostrar como portar nossa config do neovim em vimscript totalmente para Lua. Não deixem de acompanhar!

## Links Úteis

- [Twitch](https://twitch.tv/npxbr)
- [Twitter NpX](https://twitter.com/ellisonleao)
- [Github](https://github.com/npxbr)
- [VimBR no telegram](https://t.me/vimbr)
- [Documentação Oficial Neovim e Lua](https://neovim.io/doc/user/lua.html)

## Para ouvir

{{< youtube oKz-YAs6ZsA >}}
