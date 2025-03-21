# Introduction

This is a public repository which everyone in the world wide web can access.
We try to keep hidden stuff to the minimum.
We don't want to publicly mention our IP-addresses or API-keys for everyone to see.

Our servers are running behind Cloudflare so that they can't be DDOSsed easily.
By publicly announcing the IP-addresses it kind of defeats the point.

## Adding new values to Github secrets

```sh
# Run this inside the repository
$ gh secret set RUSTY_IP --body "1.2.3.4"
```

## Creating new age encryption key

### Using MacOS with Secure Enclave

The private key is stored in encrypted way and needs touch-id to be used:

```sh
# FIXME: Replace homebrew with nix when this gets merged https://github.com/NixOS/nixpkgs/pull/382902
$ brew install age-plugin-se

# Generate the key
$ age-plugin-se keygen --access-control=any-biometry -o ~/.config/sops/age/secure-enclave-key.txt

# Get the public key and then copy it to the .sops.yml file
cat ~/.config/sops/age/secure-enclave-key.txt | grep "public key:"
```

### For other systems
>
> [!CAUTION]
> This key is stored in plaintext and it's thus easier to loose it for bad actors:

```sh
# Generate age key and link it to the proper place where sops can find it
$ age-keygen -o ~/.config/sops/age/keys.txt
$ ln -s ~/.config/sops ~/Library/Application\ Support/

# Get the public key and then copy it to the .sops.yml file
$ age-keygen -y ~/.config/sops/age/keys.txt
```

## Adding new recipients for existing secrets

After adding new public keys into `.sops.yml` you need to run:

```sh
sops updatekeys secrets/*
```

## Editing the secrets with SOPS

You can edit the secrets by running:

```sh
sops secrets.yaml
```

This opens the secrets in separate VS Code window for safety.

> [!CAUTION]
> To be extra safe with co-pilot you should copy the contents of:
> `.vscode/settings.json` to your own VS Code settings.

## Generating ssh/age keys into Github Actions

```sh
$ ssh-keygen -t ed25519 -a 100 -N "" -C "github-actions@midwork" -f github_actions
$ cat github_actions | gh secret set  -a actions SSH_KEY
$ nix-shell -p ssh-to-age
$ ssh-to-age -private-key -i github_actions -o github_actions_age.txt
$ ssh-to-age -i github_actions.pub -o github_actions_age_pub.txt
$ cat github_actions_age.txt | gh secret set AGE_SECRET_KEY
# Now add the contents of 'github_actions_age_pub.txt' to .sops.yml
# Then cleanup:
$ rm github_actions*
```
