{
  pkgs,
  ...
}:

let
  sgconfig = pkgs.writeText "sgconfig" ''
    ruleDirs:
    - rules
    testConfigs:
    - testDir: tests
    customLanguages:
      nix:
        libraryPath: ${pkgs.vimPlugins.nvim-treesitter-parsers.nix}/parser/nix.so
        extensions: [nix]
        expandoChar: _
  '';
in
{
  packages = with pkgs; [
    ast-grep
    git
    nushell
  ];

  languages.nix.enable = true;

  enterShell = ''
    ln -sf ${sgconfig} sgconfig.yml
  '';

  enterTest = ''
    ast-grep test
  '';

  git-hooks.hooks = {
    nixfmt-rfc-style.enable = true;
    yamlfmt.enable = true;
  };
}
