# Install Swiftly Automatically

Swiftly can be installed automatically in places like build/CI systems.

This guide will help you to script to the installation of swiftly and toolchains so that it can be unattended. We assume that you have working understanding of your build system. The examples are based on a typical Unix environment.

First, download the swiftly binary from swift.org for your operating system (e.g. Linux) and processor architecture (e.g. arm64, or x86_64). Here's an example using the popular curl command.

```
curl -L <location_of_swiftly_swift_org> > swiftly.tar.gz
tar zxf swiftly.tar.gz
```

On macOS you can download the pkg file and extract it like this from the command-line:

```
curl -L <location_of_swiftly_swift_org> > swiftly.pkg
installer -pkg swiftly.pkg -target CurrentUserHomeDirectory
```

> Tip: If you are using Linux you will need the "ca-certificates" package for the root certificate authorities that will establish the trust that swiftly needs to make API requests that it needs. This package is frequently pre-installed on end-user environments, but may not be present in more minimal installations.

Once swiftly is downloaded you can run the init subcommand to finish the installation. This command will print verbose outputs, assume yes for all prompts, and skip the automatic installation of the latest swift toolchain:

```
./swiftly init --verbose --assume-yes --skip-install    # the swiftly binary is extracted to ~/local/bin/swiftly on macOS
```

Swiftly is installed, but the current shell may not yet be updated with the new environment variables, such as the PATH. The init command prints instructions on how to update the current shell environment without opening a new shell. This is an example of the output taken from Linux, but the details might be different for other OSes, username, or shell.

```
To begin using installed swiftly from your current shell, first run the following command:

. "/root/.local/share/swiftly/env.sh"
```

> Note: on macOS systems you may need to run 'hash -r' to recalculate the zsh PATH cache when installing swiftly and toolchains.

You can go ahead and add this command to the list of commands in your build script so that the build can proceed to call swiftly from the path. The usual next step is to install a specific swift toolchain like this:

```
swiftly install 5.10.1 --post-install-file=post-install.sh
```

It's possible that there will be some post-installation steps to prepare the build system for using the swift toolchain. The `post-install-file` option gives a file, post-install.sh, that is created if there are post installation steps for this toolchain. You can check if the file exists and run it to perform those final steps. If the build runs as the root user you can check it and run it like this in a typical Unix shell:

```
if [ -f post-install.sh ]; then
    . post-install.sh
fi
```

> Note: If the build system runs your script as a regular user then you will need to take this into account by either pre-installing the toolchain's system dependencies or running the `post-install.sh` script in a secure manner as the administrative user.

If you want to install swiftly, or the binaries that it manages into different locations these can be customized using environment variables before running `swiftly init`.

```
SWIFTLY_HOME_DIR - The location of the swiftly configuration files, and environment scripts
SWIFTLY_BIN_DIR - The location of the swiftly binary and toolchain symbolic links (e.g. swift, swiftc, etc.)
```

Sometimes the build system platform can't be automatically detected, or isn't supported by swift. You can provide the platform as an option to the swiftly init subcommand:

```
swiftly init --platform=<platform_name>
```

There are other customizable options, such as overwrite. For more details about the available options, check the help:

```
swiftly init --help
```

In summary, swiftly can be installed and install toolchains unattended on build and CI-style systems. This HOWTO guide has outlined the process to script the process covering some of the different options available to you.
