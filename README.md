# The refactor tractor

This repository contains some scripts for automated refactors of [nixpkgs](https://github.com/NixOS/nixpkgs).

It uses [devenv.sh](https://devenv.sh/).
[Enter the shell](https://devenv.sh/getting-started/#commands) and then:

- Run `no-substitute-all <path-to-nixpkgs> --write` to get rid of the evil `substituteAll`.
  At least the nix-variant of it.
- Run `lint-replace-vars <path-to-nixpkgs>` to confirm that nobody uses `replaceVars`
  in a way they really shouldn't.
- Run `build-replace-vars <path-to-nixpkgs>` to build all `replaceVars` derivations
  in a minimal fashion. See below.

All of those scripts are based on [ast-grep](https://ast-grep.github.io).

## `build-replace-vars`

When testing the refactor of 100s of `substituteAll` to `replaceVars` we end up
with 1000s of rebuilds necessarily. We don't really care about building all those
packages, though, because `replaceVars` has error detection built-in already: We
only need to build the `replaceVars` derivation itself and it will tell us whether
any replacements are missing or can be removed.

One approach would be to take the big list of rebuilds and then filter out all those
that belong to a `replaceVars` call. This will still lead to a ton of rebuilds, though,
because all the dependencies for each replacement need to be build first - and those
are likely part of the rebuilds itself, too.

Here, we take a different approach:

- Extract the call to `replaceVars` with ast-grep.
- Change all replacements to pass in `null`.
- Build the resulting code with nix.

If it passes, we have the right replacements. If it doesn't we either miss some replacements,
or can remove some.
