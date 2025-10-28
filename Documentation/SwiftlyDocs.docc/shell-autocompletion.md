# Add shell auto-completions

Generate shell autocompletions for swiftly.

Swiftly can generate shell autocompletion scripts for your shell to automatically complete subcommands, arguments, options and flags. It does this using the [swift-argument-parser](https://apple.github.io/swift-argument-parser/documentation/argumentparser/installingcompletionscripts/), which has support for Bash, Z shell, and Fish.

You can ask swiftly to generate the script using the hidden `--generate-completion-script` flag with the type of shell like this:

```
swiftly --generate-completion-script <shell>
```

@TabNavigator {
    @Tab("zsh") {
        If you have [oh-my-zsh](https://ohmyz.sh/) installed then this command will install the swiftly completions into the default directory:

        ```
        swiftly --generate-completion-script zsh > ~/.oh-my-zsh/completions/_swiftly
        ```

        Otherwise, you'll need to add a path for completion scripts to your function path, and turn on completion script autoloading. First, add these lines to ~/.zshrc:

        ```
        fpath=(~/.zsh/completions $fpath)
        autoload -U compinit
        compinit
        ```

        Next, create the completion directory and add the swiftly completions to it:

        ```
        mkdir -p ~/.zsh/completions && swiftly --generate-completion-script zsh > ~/.zsh/completions/_swiftly
        ```
    }

    @Tab("bash") {
        If you have [bash-completion](https://github.com/scop/bash-completion) installed then this command will install the swiftly completions into the default directory:

        ```
        swiftly --generate-completion-script bash > swiftly.bash
        # copy swiftly.bash to /usr/local/etc/bash_completion.d
        ```

        Without bash-completion create a directory for the completion and generate the script in there:

        ```
        mkdir -p ~/.bash_completions && swiftly --generate-completion-script bash > ~/.bash_completions/swiftly.bash
        ```

        Add a line to source that script in your `~/.bash_profile` or `~/.bashrc` file:

        ```
        source ~/.bash_completions/swiftly.bash
        ```
    }

    @Tab("fish") {
        Generate the completion script to any path in the environment variable `$fish_completion_path`. Typically this command will generate the script in the right place:

        ```
        swiftly --generate-completion-script fish > ~/.config/fish/completions/swiftly.fish
        ```
    }
}

Once you have installed the completions you can type out a swiftly command, and press a special key (for example, tab) and the shell will show you the available subcommand, argument, or options to make it easier to assemble a working command-line.
