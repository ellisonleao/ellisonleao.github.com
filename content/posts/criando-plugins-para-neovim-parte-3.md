+++
title = "Criando plugins Lua para Neovim - Parte 3"
date = "2021-03-30"
tags = ["neovim", "lua", "plugin", "dotfiles"]
keywords = ["plugin", "neovim", "lua"]
description = "Migrando do init.vim para o init.lua"
+++

**Caso ainda não tenha lido a primeira e segunda parte dessa série, [clique aqui](/posts/criando-plugins-para-neovim-parte-1/)**
**Todo código mostrado aqui só funcionará nas versões 0.5+ do Neovim**

Para fechar nossa série de criação de plugins em Lua para o Neovim, vamos mudar um pouco
o foco na criação de plugins para um tutorial de como podemos migrar toda nossa configuração do
Neovim usando o tradicional Vimscript, para **Lua**.

> Mas por que Lua?

A decisão tomada pelo _core team_ de desenvolvimento do Neovim tem várias respostas diversas,
que vão desde velocidade a facilidade de escrita, pelo fato de Lua ser uma linguagem bem
extensível. Para entender as principais motivações, sugiro dar uma pausa no post e apreciem a talk
**"We can have nice things"**, do [Justin M. Keyes](https://github.com/justinmk), um dos líderes de
desenvolvimento do Neovim.

{{< youtube Bt-vmPC_-Ho >}}

## A migração

Caso você ainda não conheça a estrutura de diretórios do Neovim, toda configuração vai
em:

- Unix: **~/.config/nvim/init.vim**
- Windows: **~/AppData/Local/nvim/init.vim**

ou, caso você queria um path de config customizado, onde `$XDG_CONFIG_HOME` é definido,
fica assim:

- **\$XDG_CONFIG_HOME/nvim/init.vim**

Esse arquivo é o ponto de entrada para as configurações customizadas do editor, desde
cores, tamanhos de fonte, a instalação de plugins.

No nosso caso, começaremos renomeando o arquivo `init.vim` para `init.old` e criando um
novo arquivo chamado `init.lua`.

> Por quê precisamos renomear o init.vim?

No neovim não é possível existir 2 pontos de entrada para as configurações, então você
só poderá usar o `init.vim` ou o mais recente, `init.lua`

Para o nosso tutorial não ficar bastante extenso, iremos usar um `init.vim`
relativamente pequeno, explicando as principais configurações e como portá-las para a
versão em lua.

Mas primeiro precisamos relembrar como a API em Lua se comporta:

## O namespace _vim_

Na implementação da API Lua para o Neovim, existe uma variável chamada `vim`, que é o
ponto de entrada para todas as funções da chamada "biblioteca padrão" Lua para o Neovim. Essas funções servem
diferentes propósitos, mas o principal sendo a ponte entre o código lua e o editor.

- **vim.inspect**: uma função de debug para inspecionar resultados. Geralmente em lua,
  os resultados vem em tables, e esses são difíceis de ser expostos em formato de "print".
  Essa função "disseca" a váriável que você gostaria de expor de uma forma mais
  amigável.

- **vim.regex**: Módulo que possibilita o uso de regexes diretamente no código Lua. Para
  mais info `:h vim.regex`

- **vim.api**: Provavelmente o módulo mais importante dessa API. Aqui encontramos todas
  a funções para trabalhar com buffers, windows, chamar comandos do neovim, etc.

- **vim.loop**: Módulo que funciona como uma camada de abstração da LibUV, a camada de _event-loop_ do Neovim. Pra quem quer usar concorrência, timers, etc,
  esse módulo é o caminho.

- **vim.lsp**: Pra quem trabalhar diretamente na fantástica implementação nativa de um cliente LSP dentro do Neovim.

- **vim.treesitter**: O módulo que expõe algumas funções para se trabalhar diretamente
  com o [tree-sitter](https://tree-sitter.github.io/tree-sitter/).

Para este post, focaremos apenas na **vim.api**

## Nosso arquivo init.lua

Levando em consideração que nosso `init.vim` tinha a seguinte cara:

```vimrc
" Parte 1
set colorcolumn=80
set expandtab
set tabstop=4
set autoindent
set incsearch
set hlsearch
set termguicolors

" Parte 2
let g:minha_config = 'valor'
let g:algumnamespace#teste#variavel = "valor"

" Parte 3
nmap <leader>, <Cmd>:noh<CR>
nnoremap <leader>h <Cmd>split<CR>
vnoremap < <gv

" Parte 4
autocmd BufEnter * echo "hello nvim"

" Parte 5
function! SayHello()
  echohl WarningMsg
  echo "Hello World"
  echohl
endfunction
```

separamos a migração em 4 partes:

- _options_
- _vars_
- _mappings_
- _autocmds_
- _functions_

Para a **parte 1**, temos as seguintes funções da **vim.api**:

- **vim.api.nvim_set_option**
- **vim.api.nvim_buf_set_option**
- **vim.api.nvim_win_set_option**

Para facilitar a escrita, temos os atalhos correspondentes:

- **vim.o**
- **vim.bo**
- **vim.wo**

```lua
vim.o.termguicolors = true   -- set termguicolors
vim.wo.colorcolumn=80        -- set colorcolumn=80
vim.o.expandtab              -- set expandtab
vim.o.tabstop=4              -- set tabstop=4
vim.o.autoindent = true      -- set autoindent
vim.o.incsearch = true       -- set incsearch
vim.o.hlsearch = true        -- set hlsearch
```

os `meta-acessors` (veja `:h lua-vim-options`) `vim.[o|wo|bo]` funcionam como getters e setters na atribuição dessas opções, ou seja, caso algum
valor seja passado a essas variáveis, ela substituirá o valor anterior e caso deseje pegar o valor atual, é só atribuir
o valor dela em outra variável.

Como vocês podem perceber, não é tão fácil ainda saber quando usar `vim.o`, `vim.bo`, ou `vim.wo`, sem conhecer
pra que serve cada opção e qual o escopo onde elas funcionam. Existe um [PR](https://github.com/neovim/neovim/pull/13479)
onde será introduzido o módulo `vim.opt`, tornando essas configurações tão fáceis quanto no vimscript. Caso deseje uma
opção paliativa, você pode usar a seguinte função:

```lua
local opts_info = vim.api.nvim_get_all_options_info()
local opt = setmetatable({}, {
  __index = vim.o,
  __newindex = function(_, key, value)
    vim.o[key] = value
    local scope = opts_info[key].scope
    if scope == "win" then
      vim.wo[key] = value
    elseif scope == "buf" then
      vim.bo[key] = value
    end
  end,
})
```

A variável `opt` vai servir como uma função "helper", checando qual o escopo de cada variável, e atribuindo o valor
de acordo com o resultado dele. Então você poderá substituir o código anterior por:

```lua
opt.termguicolors = true   -- set termguicolors
opt.colorcolumn = 80       -- set colorcolumn=80
opt.expandtab = true       -- set expandtab
opt.tabstop = 4            -- set tabstop=4
opt.autoindent = true      -- set autoindent
opt.incsearch = true       -- set incsearch
opt.hlsearch = true        -- set hlsearch
```

O que resolve o problema de escopo das options.

Continuando com a **parte 2**, temos uma declaração de uma variável global (escopo `g:`). Na API, podemos utilizar as
seguintes funções:

- **vim.api.nvim_set_var** e suas variações (**vim.api.nvim_get_var** e **vim.api.nvim_del_var**)

Aqui também temos uma versão "minimalista" com seus respectivo **meta-acessor** (ver **:h lua-vim-variables** para mais
detalhes):

- **vim.g** - Também funciona como um getter/setter

Temos então nosso código lua, com a parte 2:

```lua
-- parte 1
opt.termguicolors = true   -- set termguicolors
opt.colorcolumn = 80       -- set colorcolumn=80
opt.expandtab = true       -- set expandtab
opt.tabstop = 4            -- set tabstop=4
opt.autoindent = true      -- set autoindent
opt.incsearch = true       -- set incsearch
opt.hlsearch = true        -- set hlsearch

-- parte 2
vim.g.minha_config = "valor"
 -- o `meta-acessor` é uma table, então podemos atribuir valores usando também os colchetes
vim.g["algumnamespace#teste#variavel"] = "valor"
```

Para a **parte 3** temos os mappings e para isso temos 2 funções que podem ser utilizadas:

- **vim.api.nvim_set_keymap**: mappings que serão atribuídos para todos os buffers
- **vim.api.nvim_buf_set_keymap**: mappings que serão exclusivos de algum buffer em particular

**vim.api.nvim_set_keymap** tem os seguintes parâmetros:

```
vim.api.nvim_set_keymap(modo, atalho, comando_a_ser_executado, opcoes)
```

Onde:

- **modo**: Opções mais usadas são: **"n"**, **"v"**, **"i"** sendo os mais utilizados respectivamente para os modos **normal**, **visual** e **insert**
- **atalho**: a combinação de teclas que chamará o `comando_a_ser_executado`
- **comando_a_ser_executado**: o comando que será executado quando o atalho for executado no modo específico
- **opcoes**: uma table opcional de parâmetros booleanos. Os parâmetros dizem a respeito das variadas opções de mapping para cada
  estado, sendo alguma delas:
  - _noremap_
  - _silent_
  - _expr_
  - _nowait_

Temos então, no nosso arquivo lua:

```lua
-- parte 1
opt.termguicolors = true   -- set termguicolors
opt.colorcolumn = 80       -- set colorcolumn=80
opt.expandtab = true       -- set expandtab
opt.tabstop = 4            -- set tabstop=4
opt.autoindent = true      -- set autoindent
opt.incsearch = true       -- set incsearch
opt.hlsearch = true        -- set hlsearch

-- parte 2
vim.g.minha_config = "valor"
 -- o `meta-acessor` é uma table, então podemos atribuir valores usando também os colchetes
vim.g["algumnamespace#teste#variavel"] = "valor"

-- parte 3
vim.api.nvim_set_keymap("n", "<leader>,", "<Cmd>:noh<CR>", nil) -- nmap <leader>, <Cmd>:noh<CR>
vim.api.nvim_set_keymap("n", "<leader>h", "<Cmd>split<CR>", {noremap = true}) -- nnoremap <leader>h <Cmd>split<CR>
vim.api.nvim_set_keymap("v", "<", "<gv", {noremap = true}) -- vnoremap < <gv
```

Já para a **parte 4**, vamos adicionar os autocmd e augroups. Como, até o momento, não existe uma API direta para criar
os autocmds, vamos utilizar a função `vim.api.nvim_command` ou sua versão reduzida `vim.cmd`, que executa um código
vimscript dentro do código lua.

Temos então no nosso arquivo lua:

```lua
-- parte 1
opt.termguicolors = true   -- set termguicolors
opt.colorcolumn = 80       -- set colorcolumn=80
opt.expandtab = true       -- set expandtab
opt.tabstop = 4            -- set tabstop=4
opt.autoindent = true      -- set autoindent
opt.incsearch = true       -- set incsearch
opt.hlsearch = true        -- set hlsearch

-- parte 2
vim.g.minha_config = "valor"
 -- o `meta-acessor` é uma table, então podemos atribuir valores usando também os colchetes
vim.g["algumnamespace#teste#variavel"] = "valor"

-- parte 3
vim.api.nvim_set_keymap("n", "<leader>,", "<Cmd>:noh<CR>", nil) -- nmap <leader>, <Cmd>:noh<CR>
vim.api.nvim_set_keymap("n", "<leader>h", "<Cmd>split<CR>", {noremap = true}) -- nnoremap <leader>h <Cmd>split<CR>
vim.api.nvim_set_keymap("v", "<", "<gv", {noremap = true}) -- vnoremap < <gv

-- parte 4
vim.cmd("autocmd BufEnter * echo 'hello nvim'")
```

Para a última parte, temos uma função vimscript que poderá ser portada utilizando a função `vim.api.nvim_exec`, que
avalia um código vimscript contendo várias linhas. A assinatura da função é da seguinte forma:

```
vim.api.nvim_exec(bloco_de_codigo, retorno)
```

Onde:

- **bloco_de_codigo**: A string multiline ou não do bloco de código vimscript que será executado
- **retorno**: _true_ caso deseje retornar o resultado string da execução do bloco, _false_ para retornar uma
  string vazia

Temos então a versão final da config lua:

```lua
local opts_info = vim.api.nvim_get_all_options_info()
local opt = setmetatable({}, {
  __index = vim.o,
  __newindex = function(_, key, value)
    vim.o[key] = value
    local scope = opts_info[key].scope
    if scope == "win" then
      vim.wo[key] = value
    elseif scope == "buf" then
      vim.bo[key] = value
    end
  end,
})

-- parte 1
opt.termguicolors = true   -- set termguicolors
opt.colorcolumn = 80       -- set colorcolumn=80
opt.expandtab = true       -- set expandtab
opt.tabstop = 4            -- set tabstop=4
opt.autoindent = true      -- set autoindent
opt.incsearch = true       -- set incsearch
opt.hlsearch = true        -- set hlsearch

-- parte 2
vim.g.minha_config = "valor"
 -- o `meta-acessor` é uma table, então podemos atribuir valores usando também os colchetes
vim.g["algumnamespace#teste#variavel"] = "valor"

-- parte 3
vim.api.nvim_set_keymap("n", "<leader>,", "<Cmd>:noh<CR>", nil) -- nmap <leader>, <Cmd>:noh<CR>
vim.api.nvim_set_keymap("n", "<leader>h", "<Cmd>split<CR>", {noremap = true}) -- nnoremap <leader>h <Cmd>split<CR>
vim.api.nvim_set_keymap("v", "<", "<gv", {noremap = true}) -- vnoremap < <gv

-- parte 4
vim.cmd("autocmd BufEnter * echo 'hello nvim'")

-- parte 5
vim.api.nvim_exec([[
function! SayHello()
  echohl WarningMsg
  echo "Hello World"
  echohl
endfunction
]], false)
```

## Limitações da Lua API

Até o momento deste post, algumas limitações ainda são presentes, dentre elas:

- API de criação de _commands_ customizados: [PR #11613](https://github.com/neovim/neovim/pull/11613)
- API de criação de _autocmds_ e _augroups_: [PR #12378](https://github.com/neovim/neovim/pull/12378)
- API de criação de _options_: [PR #13479](https://github.com/neovim/neovim/pull/13479)

## Conclusão

Mostramos que, apesar de algumas limitações, portar uma configuração em vimscript para Lua está cada dia mais fácil com a API vigente.
Até a criação desde post a versão 0.5 do Neovim ainda não foi lançada, então é bom lembrar que muita dessas APIs só irão funcionar dentro essa versão.

Para um exemplo de configuração mais extensa usando mais elementos da API Lua, visite a [minha configuração do neovim](https://github.com/ellisonleao/dotfiles/tree/main/configs/.config/nvim)

Lembrando que faço lives na [Twitch](https://twitch.tv/npxbr)! Caso deseje ver esse tipo de conteúdo ao vivo, não deixe
de me seguir por lá e também acompanhar meu [Twitter](https://twitter.com/ellisonleao)

## Links Úteis

- [Github](https://github.com/npxbr)
- [VimBR no telegram](https://t.me/vimbr)
- [Documentação Oficial Neovim e Lua](https://neovim.io/doc/user/lua.html)

## Para ouvir

{{< youtube Rv_a6rlRjZk >}}
