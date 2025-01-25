#!/usr/bin/env nu

use std log

def ast-grep-scan [root: string]: nothing -> table {
    ^ast-grep scan --json --rule rules/nullify-replace-vars.yml $root
    | from json
}

def nix-build [
  root: string,
  match: record
]: nothing -> record {
    let expression = $"
        with import ($root)/default.nix {};
        ($match.replacement)
    "
    log debug $"building for '($match.file)' with:($expression)"

    # Change working directory to location of .nix file to make relative
    # path to `src` work.
    $match.file | path dirname | cd $in
    let result = ^nix-build --no-link -E $expression | complete

    return {
        ...$match,
        ...$result
    }
}

def main [path: string] {
    let root = $path | path expand
    log debug $"nixpkgs root is: ($root)"

    let builds = ast-grep-scan $root
                 | par-each {|match| if ([
                         # hardcoded exclusions list for:
                         # the tool and tests themselves
                         pkgs/build-support/replace-vars/replace-vars.nix
                         pkgs/test/replace-vars/default.nix
                         # expression as source file
                         pkgs/applications/editors/emacs/make-emacs.nix
                         pkgs/applications/science/logic/z3/default.nix
                         pkgs/development/compilers/llvm/common/default.nix
                         pkgs/development/tools/ocaml/merlin/4.x.nix
                         # expression generating replacements
                         pkgs/development/python-modules/pysdl2/default.nix
                     ] | any {|exclusion| $match.file | str ends-with $exclusion }) {
                         $match
                     } else {
                         nix-build $root $match
                     }
                   }
                 | default $"(ansi red_bold)skipped(ansi reset)" stdout
                 | default 0 exit_code

    let exit_code = (
        $builds | reduce -f 0 {|result, exit_code|
            if $result.exit_code != 0 {
                log error $"nix-build for '($result.file)' failed:\n($result.stderr)"
                return 1
            } else {
                return $exit_code
            }
        }
    )

    if $exit_code == 0 {
        $builds
        | select file stdout
        | rename file build
        | update file {|row| $row.file | path relative-to $root }
        | sort-by file
        | sort-by { ($in.build | ansi strip) == "skipped" }
        | print
    }

    exit $exit_code
}
