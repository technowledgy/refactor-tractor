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

  scripts.no-substitute-all = {
    exec = ''
      def main [nixpkgs: string, --write (-w)] {
          if $write {
              ast-grep scan --rule rules/no-substitute-all-nix.yml $nixpkgs --update-all
          } else {
              ast-grep scan --rule rules/no-substitute-all-nix.yml $nixpkgs
          }
      }
    '';
    package = pkgs.nushell;
    binary = "nu";
    description = "Find (and replace) all substituteAll calls in nixpkgs.";
  };

  scripts.lint-replace-vars = {
    exec = ''
      def main [nixpkgs: string] {
          ast-grep scan --rule rules/no-broken-replace-vars.yml $nixpkgs
      }
    '';
    package = pkgs.nushell;
    binary = "nu";
    description = "Lint replaceVars for bad usage patterns.";
  };

  enterShell = ''
    ln -sf ${sgconfig} sgconfig.yml

    echo "Available scripts:"
    echo "  no-substitute-all <path-to-nixpkgs>"
    echo "  no-substitute-all <path-to-nixpkgs> --write"
    echo "  lint-replace-vars <path-to-nixpkgs>"
  '';

  enterTest = ''
    ast-grep test
  '';

  git-hooks.hooks = {
    nixfmt-rfc-style.enable = true;
    yamlfmt.enable = true;
  };
}
