package main

import (
	"nixpkgut"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	subcmd := os.Args[1]
	args := os.Args[2:]

	var err error
	switch subcmd {
	case "search", "s":
		err = nixpkgut.Run(args)
	case "download", "dl":
		err = nixpkgut.RunDownload(args)
	case "help", "h", "-h", "--help":
		printUsage()
		os.Exit(0)
	default:
		printUsage()
		os.Exit(1)
	}

	if err != nil {
		os.Exit(1)
	}
}

func printUsage() {
	println(`Usage: nixpkgut <command> [options]

Commands:
  search, s     Search for Nix packages
  download, dl  Download NAR from binary cache

Examples:
  nixpkgut search hello
  nixpkgut search -P -n 5 hello
  nixpkgut download /nix/store/xxx-hello-2.12.3

Note: For search, flags must appear before the query argument.`)
}