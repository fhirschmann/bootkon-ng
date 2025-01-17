# Development Workflow

If you take the Cloud Shell route, <a href="https://console.cloud.google.com/cloudshell/open?git_repo=https://github.com/fhirschmann/bootkon&page=editor&tutorial=docs/book/run_own_bootkon_workflow.md&show=ide&cloudshell_workspace=" target="_blank">open this file in Cloud Shell</a> in tutorial mode and follow the next steps directly in Cloud Shell.

## Rationale

In this section, we will set up Git and introduce the development workflow.

## Authenticate to GitHub

Cloud Shell editor supports authentication to GitHub via an interactive authentication flow.
In this case, you just push your changes and a notification appears to guide you through this process. If you go this route, please continue with **Set up git**.

If, for some reason, this doesn't work for you, you can use the following method:

Create SSH keys if they don't exist yet (just hit return when it asks for passphrases):
```bash
test -f ~/.ssh/id_rsa.pub || ssh-keygen -t rsa
```

Display your newly created SSH key and [add it to your GitHub account](https://github.com/settings/keys):
```bash
cat ~/.ssh/id_rsa.pub
```

Overwrite the remote URL to use the SSH protocol insead of HTTPS. Adjust the command in case you are working on your personal fork:
```bash
git remote set-url origin git@github.com:fhirschmann/bootkon.git
```

## Set up git

```bash
git config --global user.name "John Doe"
```
```bash
git config --global user.email johndoe@example.com  
```

Check your git config:
```bash
cat ~/.gitconfig
```

## Pushing to GitHub

You can now commit changes and push them to GitHub. You can either use the version control of the Cloud Shell IDE (tree icon on the left hand side) or the command line:

```bash
git status
```

## Set up your development environment

During the first lab, participants are asked to edit `vars.sh`. It is suggested to make a copy of this file and not touch the original in order not to accidently commit it to git.

First, make a copy:
```bash
cp vars.sh vars.local.sh
```

And <walkthrough-editor-open-file filePath="vars.local.sh">edit it</walkthrough-editor-open-file>. It also runs on Argolis (for Google employees).

The last line in `vars.local.sh` is inteded for participants to reload the tutorial in case it disappears from Cloud Shell. We will use a different
command for development that applies jinja2 processing so that you can load and render individual markdown files instead of `.TUTORIAL.md`.
It also remembers the last file you opened so that you can just do `r` (without filename) for consecutive runs. Replace the last line with the following:

```bash
alias r='bash ~/cloudshell_open/bootkon/book/scripts/reload-tutorial'
```

Install dependencies:
```bash
pip install jinja2-cli
```

Next, instead of doing `source vars.sh` as requested in the labs, do
```bash
source vars.local.sh
```

Please note that you might have to **re-execute the last command** in case you reopen Cloud Shell.

## Reloading the tutorial

You can reload a lab on-the-fly by typing `r` followed by the lab markdown file into the terminal and pressing return. This is the alias we set up in `vars.local.sh`. Let's start by opening the tutorial:
```bash
r docs/book/fork.md
```

## Working with mdbook

You can run mdbook and compile the book in Cloud Shell directly. First, download mdbook:
```bash
wget -qO - https://github.com/rust-lang/mdBook/releases/download/v0.4.43/mdbook-v0.4.43-x86_64-unknown-linux-gnu.tar.gz | tar xvzf -
```

Install dependencies:
```bash
pip install jinja2 nbformat nbconvert
```

Next, run mdbook:
```bash
./mdbook serve -p 8080
```

You can now read the book using Cloud Shell's web preview by pressing the ![](https://cloud.google.com/static/shell/docs/images/web_preview.svg) button in Cloud Shell. Select **Preview on port 8080**. As soon as you change any of the markdown source files, mdbook will automatically reload it.