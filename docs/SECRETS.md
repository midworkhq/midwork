# Introduction
This is a public repository which everyone in the world wide web can access.

We try to keep hidden stuff to the minimum but for example it's not nice to publicly mention our IP-addresses or API-keys for everyone to see.

Our servers are running behind Cloudflare so that they can't be DDOSsed easily and by publicly announcing the IP-addresses it kind of defeats the point.

## Adding new values to Github secrets
```
# Run this inside the repository
$ gh secret set RUSTY_IP --body "1.2.3.4"
```

## Creating new age encryption key
```sh
# Generate age key and link it to the proper place where sops can find it
$ age-keygen -o ~/.config/sops/age/keys.txt
$ ln -s ~/.config/sops ~/Library/Application\ Support/

# Get the public key and then copy it to the .sops.yml file
$ age-keygen -y ~/.config/sops/age/keys.txt
```

## Editing the secrets with SOPS
```
$ sops secrets.yaml
```

## Generating ssh/age keys into Github Actions
```
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

## Macbook with Secure Enclave
```sh
# FIXME: Replace homebrew with nix when this gets merged https://github.com/NixOS/nixpkgs/pull/382902
$ brew install age-plugin-se

# FIXME: age1se keys are not supported in SOPS :(
$ age-plugin-se keygen --access-control=any-biometry -o ~/.config/sops/age/secure-enclave-key.txt
```