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
    languageInjections:
    - hostLanguage: nix
      injected: bash
      rule:
        kind: string_fragment
        pattern: _CONTENT
        any:
        - inside:
            stopBy: end
            kind: binding
            has:
              field: attrpath
              # mkDerivation args
              regex: ^pre[A-Z]|^post[A-Z]|[a-z]Phase$|^buildCommand$|^extraBuildCommands$
        - inside:
            field: argument
            stopBy: end
            any:
            - kind: apply_expression
              has:
                field: function
                has:
                  field: function
                  has:
                    field: function
                    regex: ^runCommand$
            - kind: apply_expression
              has:
                field: function
                has:
                  field: function
                  regex: ^runCommandWith$
            - kind: apply_expression
              has:
                field: function
                all:
                - has:
                    field: function
                    regex: ^builtins.toFile|toFile$
                - has:
                    field: argument
                    regex: '\.(sh|bash)"$'
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

  scripts.build-replace-vars = {
    exec = builtins.readFile ./scripts/build-replace-vars.nu;
    package = pkgs.nushell;
    binary = "nu";
    description = "Check whether all uses of replaceVars and replaceVarsWith build fine with their replacements.";
  };

  enterShell = ''
    ln -sf ${sgconfig} sgconfig.yml

    echo "Available scripts:"
    echo "  no-substitute-all <path-to-nixpkgs>"
    echo "  no-substitute-all <path-to-nixpkgs> --write"
    echo "  lint-replace-vars <path-to-nixpkgs>"
    echo "  build-replace-vars <path-to-nixpkgs>"
  '';

  enterTest = ''
    ast-grep test
  '';

  git-hooks.hooks = {
    actionlint.enable = true;
    nixfmt-rfc-style.enable = true;
    markdownlint.enable = true;
    yamlfmt.enable = true;
  };
}
