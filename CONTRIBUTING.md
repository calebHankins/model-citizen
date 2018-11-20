# Contributing to the Project

## Getting Started

1. Create a [Github account](https://github.com/signup/free).
2. [Fork](https://help.github.com/articles/fork-a-repo/) the repository on Github.
3. Implement your feature / bugfix
4. Submit a [pull request](https://help.github.com/articles/creating-a-pull-request/) against the project for review.

## Style Guide

All commits to the project must pass linting and style guidelines. 

### Perl
- Code should be formatted using the `.perltidyrc` in the project's root and the Perl::Tidy tool.
    - If the build fails due to a failed style check, try running `tidyall -a` and recommitting.
- Code should pass Perl::Critic with no errors/warnings using the `.perlcriticrc` in the project's root.
    - Any exceptions should be documented, noted in the pull request, and an exception added to the `.perlcriticrc` file.
- Please Build the project and make sure all meta files are up to date
	- See https://metacpan.org/pod/Module::Build for more info on Module::Build 
```powershell
perl ./Build.PL 
./Build
./Build manifest
./Build test
./Build dist

```

#### Suggested tools
#### vscode
If you are using [vscode](https://code.visualstudio.com/) as your development environment, the following extensions are recommended to ease linting tasks:
- https://marketplace.visualstudio.com/items?itemName=sfodje.perlcritic
- https://marketplace.visualstudio.com/items?itemName=sfodje.perltidy

The project's style and linting files can be integrated with code similar to the following in your `settings.json` file.
```json
{
	"settings": {
		"perlcritic.additionalArguments": [
			"--profile",
			"C:\\git\\model-citizen\\.perlcriticrc"
		],
		"perltidy.profile": "C:\\git\\model-citizen\\.perltidyrc"
	}
}
```




