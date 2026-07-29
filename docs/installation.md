## Installation

Tealdoc can be installed using [Luarocks](https://luarocks.org/):

```
luarocks install tealdoc
```

### From a checkout

The generated Lua is not committed, so a checkout carries Teal only. `make
build` compiles it, and every target that needs it already depends on that:

```
make install   # deps, build, then luarocks make
make check     # the specs and the documentation smoke test
```

`luarocks make` on its own fails on a fresh checkout, because the rockspec
names compiled modules and nothing has compiled them yet. Run `make build`
first, or use `make install`, which does.

A release is `make dist`: it compiles, stages the Teal beside the Lua, tars
them together and writes the rockspec that names the tarball. The published
rock carries both, so a project depending on tealdoc can run it and type-check
against it.