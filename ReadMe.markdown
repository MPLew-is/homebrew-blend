# brew-blend: meta-formulae for homebrew #


## What? ##

This is a `homebrew` external command, implementing meta-formulae called `Blends`

This is implemented as what amounts to a wrapper around [`brew-bundle`](https://github.com/Homebrew/homebrew-bundle), which performs the actual installation of formulae; as such, any valid `Brewfile` is a valid `Blend`

Please note that this is **experimental**, and may accidentally install or uninstall your homebrew formulae

Please feel free to file an issue if you find it, and I'll work to get it fixed as soon as I can.


## Why? ##

`homebrew` does not have any meta-formula functionality built in, which would allow for the easy installation of related formulae, such as a MAMP stack, with one command, instead of needing to install each dependency separately

`brew-bundle` is an excellent way to get the dependencies specific to a project, but it does not have any management of installed formulae other than the `Brewfile` itself

Essentially, I wanted to take the ideas from `brew-bundle` and make it as `homebrew`-like as possible, including having a way to install formulae from anywhere (instead of needing to point to a specific `Brewfile`), and uninstalling formulae that have been installed


## How? ##


### Requirements ###

- [`homebrew`](https://github.com/Homebrew/brew), at least version 1.0

- [`jq`](https://github.com/stedolan/jq), at least version 1.0

	- This is installed automatically when installing through homebrew, which is the only supported installation method

The script is written to be as POSIX-compliant as possible, but if you find any inadvertent errors or bashisms, please file an issue!


### Basic overview of commands ###

- `brew blend help` prints a help message explaining the purpose of and options to the script

- `brew blend check` checks that `brew blend` has been installed, exiting with a non-zero status if not

- `brew blend install --self` creates and sets permissions for the blends directory

- `brew blend uninstall --self` removes the directories used by `brew-blend`

	- Please note that this does not uninstall any of the blends installed, but will delete the files used to manage those blends

- `brew blend list` lists all installed blends

- `brew blend info` provides information about a specific blend

- `brew blend search` searches for a given string in all taps that support `brew-blend`

- `brew blend install` installs a given blend

- `brew blend uninstall` uninstalls a given blend

	- Formulae will be uninstalled only if they are:
	
		- (a) not present in any other blend
		
		- (b) not dependencies of any other formulae (determined using `brew leaves`)
	
	- Taps will be untapped only if they:
	
		- (a) are not present in any other blend
		
		- (b) do not have any formulae installed
	
	- Casks will be uninstalled if they are not present in any other blend
	
		- There doesn't seem to be way to determine cask depencies with `brew-cask`, so this may inadvertently remove casks requried for other casks

- `brew blend update` compares installed blends with their upstream versions, printing the blend name if they differ

	- `brew update` will update your existing taps so that `brew-blend` can find updated formulae, but it is **not** currently run automatically

- `brew blend upgrade` upgrades specific installed blends (or all, if none are provided) to their most updated versions

- `brew blend --quiet {command}` can be used to silence status output from the script (`help` excluded)


More information is available by running `brew blend help` once installed


### Installation with homebrew ###

[`homebrew`](https://github.com/Homebrew/brew) is the only supported way of installing `brew blend`. This will take care of most of the initial setup, so you can get started more quickly. Simply run the commands below to get started:

```shell
brew tap MPLew-is/experimental
brew install brew-blend
brew blend install --self
```


### Uninstallation ###

To uninstall `brew-blend`, you have two choices:

1. Uninstall all blends installed with `brew-blend`, which you may or may not be using

	- The easiest way to do this is `brew blend list | xargs brew blend uninstall`
	
	- This will not uninstall any formulae that are dependencies of other installed formulae, so you can safely uninstall all blends as long as you're done using everything listed in the blend file

2. Leave all existing blends in place, which may lead to extra formulae installed


After choosing an option, run:

1. `brew blend uninstall --self` to remove the directories used by `brew-blend` to manage installations

2. `brew uninstall brew-blend` to uninstall `brew-blend` itself from your system


## Where? ##

`brew-blend` uses an approach similar to `homebrew` and `brew-cask`, which is to use a "room" to store directories for each installed formula. `brew-blend` calls its room ["Elevage"](https://en.wiktionary.org/wiki/élevage), which is the step in the process of making wine where blending of different varietes occur. There wasn't an easily-findable equivalent for beer, or I would've used that instead 😉.

Inside the Elevage are individual directories for each blend installed. As of now, these only contain the `.brewfile`s used to install the formulae, but that will likely change at some point.

In order to find formulae to install, `brew-blend` searches all of your current taps (with pinned taps searched first) for files in a directory with the name of `BlendFormula`. It searches these directories for files with extensions `.brewfile` and `.text`, which contain the blend's components and information, respectively. The `.text` file is what is output to the terminal when a user runs `brew bundle info`. Having two files was chosen to allow perfect compatibility with `brew-bundle`, so that existing `Brewfiles` can be copied or even symlinked to become blends.


## Summary (TL;DR) ##

1. `brew install brew-blend`

2. `brew blend install --self`

3. `brew blend install {BLEND}`

4. That's it!


### Random tips ###

You can append as many files of one type as you like to almost all commands (except the `search` command), for instance `brew blend install {BLEND} {BLEND} {BLEND} ...`. This makes using the script with `xargs` a lot easier.

You can edit the script however works best for you. I've tried my best to put everything that could be considered "configuration" in a group of variables at the top of the file, so you can, for instance, easily change the directory from `Elevage` to whatever you want.



## Who? ##

Hi, I'm Mike, an IT administrator and full-stack developer, dealing primarily with LAMP-based stacks. Using meta-formulae will drastically speed up my management of both development and non-development machines, so here we are.



## To do/known issues ##

- [ ] Allow uninstallation of blend without uninstalling its components

- [ ] Add `man` page/other documentation

- [ ] Flesh out code comments

- [ ] Clean up some variable naming schemes

- [ ] Integrate with CI
