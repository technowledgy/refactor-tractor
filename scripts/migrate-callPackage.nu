#!/usr/bin/env nu

use std log

def ast-grep-run [selector: string, pattern: string]: string -> table {
    $in
    | ^ast-grep run --stdin --lang nix --json --selector $selector --pattern $pattern
    | from json
    | get metaVariables.single
}

def callPackage []: string -> table {
    $in
    | ast-grep-run binding "{ _NAME = callPackage _FILE _ARGS }"
    | each {|row| { name: $row.NAME.text, file: $row.FILE.text, args: $row.ARGS.text }}
}

def binding []: string -> table {
    $in
    | ast-grep-run binding "{ _NAME = _VALUE; }"
    | each {|row| { name: $row.NAME.text, value: $row.VALUE.text }}
}

def ast-grep-rewrite [file: string, selector: string, pattern: string, rewrite: string]: nothing -> nothing {
    ^ast-grep run --lang nix --selector $selector --pattern $pattern --rewrite $rewrite --update-all $file
}

def main [path: string] {
    open --raw $path
    | callPackage
    | where file =~ $"/by-name/($it.name | str substring 0..1)/($it.name)/package.nix"
    | each {|match|
        let bindings = $match.args | binding
        if ($bindings | any {|it| $it.value =~ "\\."}) {
          return
        }

        let file = $path | path dirname | path join $match.file

        $bindings | each {|it| ast-grep-rewrite $file identifier $it.name $it.value}

        ast-grep-rewrite $path binding $"{ ($match.name) = callPackage _FILE _ARGS; }" ""
    }
}
