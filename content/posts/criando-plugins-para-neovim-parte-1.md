+++
title = "Criando plugins Lua para Neovim - Parte 1"
date = "2020-10-02"
author = "Ellison Leão"
tags = ["neovim", "lua", "plugin"]
keywords = ["plugin", "neovim", "lua"]
description = "Uma série mostrando um passo a passo na criação de plugins Lua para o Neovim"
+++

Desde que migrei para o Neovim em 2019, depois passar 8 anos usando vim com seus plugins fantásticos,
comecei a descobrir as motivações que levaram os core devs a criar esse fork.

Podemos ficar um bom tempo aqui falando sobre elas (e você pode ver uma palestra muito
interessante sobre [clicando aqui](https://www.youtube.com/watch?v=Bt-vmPC_-Ho)), mas o intuito desde texto é apenas
destacar uma delas, e a que eu considero uma das mais importantes: **Lua**

Quando você instala o Neovim hoje, a linguagem Lua, ou mais especificamente o **LuaJIT**, uma versão
otimizada da linguagem está inserida no core e você consegue usá-la diretamente num vimscript
ou chamando um arquivo lua diretamente. Mas como isso acontece?

Esse texto vai fazer parte de uma série onde vou mostrar como é possível criar seu primeiro plugin para o
Neovim usando puramente Lua. Primeiro vamos voltar um pouco e mostrar a estrutura de um plugin convencional
para o Vim:

```
~/seu-plugin/
|--plugin/
|--ftplugin/
|--after/
|--autoload/
```

Para nossa série, iremos focar na pasta `plugin` por enquanto.

A pasta `plugin` é usada como ponto de entrada no carregamento do vim. Lá é o lugar onde
irão viver os plugins globais. Guarde essa informação pois ela vai ser importante na
criação do nosso plugin.

## Criando nosso hello-world.nvim plugin

TL;DR : Código para o plugin da primeira parte [aqui](https://github.com/npxbr/criando-plugins-lua-neovim)

Como não utilizaremos de nenhum gerenciador de plugins nessa série, vamos facilitar um
pouco o carregamento do mesmo e iremos criar os arquivos diretamente no `runtimepath` do
neovim, mais precisamente em

`~/.local/share/nvim/site/plugin`

Caso essa pasta não exista em seu sistema, crie com

```sh
$ mkdir -p ~/.local/share/nvim/site/plugin
```

Nosso plugin irá utilizar a versão nightly do neovim (`0.5.x`) que ainda está em fase beta
e será lançada em breve. No decorrer dos próximos posts iremos mostrar como deixar o
plugin compatível para versões `0.4.x` e também para o Vim.

Dentro da pasta plugin crie a pasta `hello-world.nvim` e as subpastas `plugin` e `lua`.

```sh
$ mkdir -p hello-world.nvim/{plugin,lua}
```

Observe que agora temos uma nova pasta, `lua`. Ela tem uma função parecida com a `plugin`
mas para arquivos `.lua` , ou seja, qualquer arquivo que seja colocado lá, fica
disponível para ser importando a qualquer momento.

Um módulo lua pode ser representado como:

```lua
-- exemplo de um modulo lua
local M = {}

function M.minha_funcao()
  print("olá!")
end

return M
```

No caso do nosso plugin, iremos criar um simples commando `:HelloWorld` , que printa
`Hello World Lua` no prompt de comando do Neovim. Crie um arquivo chamado `hello-world.lua`
dentro da pasta `lua` e adicione as seguintes linhas:

```lua
-- modulo hello-world
local M = {}

-- hello_world printa a string "Hello World!" na tela
function M.hello_world()
  print("Hello World Lua!")
end

function M.create_command()
  vim.cmd("command! -bang -nargs=* HelloWorld lua require('hello-world').hello_world()")
end

function M.init()
  M.create_command()
end

return M
```

Podemos ver já o uso do `vim.cmd`, uma ponte entre lua e a chamada da função ou de um
comando vimscript. Iremos explicar mais exemplos dele e outras APIs, como o `vim.api`, a
mais importante delas.

Agora vamos para a pasta `plugin`. Infelizmente no estado atual do Neovim (Outubro 2020)
ainda não temos uma maneira totalmente nativa para carregar os plugins globais usando
somente arquivos `.lua` de uma maneira trivial. Então iremos criar um simples arquivo
`hello_world.vim` dentro da pasta `plugin` para chamar nosso módulo hello-world

Dentro do arquivo `hello_world.vim`, digite:

```viml
lua require("hello-world").init()
```

a diretriz `lua` dentro do vimscript roda uma chamada de código Lua, que no nosso caso é
a inicialização do módulo hello-world ao iniciar o vim.

Se tudo deu certo você já poderá rodar o commando no seu prompt de comando do vim
digitando:

`:HelloWorld`

## Conclusão

Esta é só a ponta do iceberg do que podemos fazer com Lua no neovim hoje. Nos próximos
posts da série iremos abordar como criar floating windows, configurar seu Neovim para
usar o LSP nativo (e fugir daquele plugin javascript que você deseja tanto) e no fim da
série vou explicar como migrar seu vimfiles totalmente para lua usando o máximo de
plugins puramente feitos em lua no dia-a-dia (sim, isso já é possível!)

Aguardem os próximos posts e não esqueçam de seguir nossas redes e live streams

## Links Úteis

- [Twitch](https://twitch.tv/npxbr)
- [Twitter NpX](https://twitter.com/npxbr)
- [Github](https://github.com/npxbr)
- [Documentação Oficial Neovim e Lua](https://neovim.io/doc/user/lua.html)

### Para ouvir

{{< youtube -xKgOYIGXo4 >}}
