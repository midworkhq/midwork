{
  config,
  lib,
  ...
}:
{
  # NOTE: https://github.com/Mic92/sops-nix#initrd-secrets
  sops = {
    defaultSopsFile = ../../../secrets/secrets.yaml;
    gnupg.sshKeyPaths = [ ];

    secrets = {
      "github_actions/ssh/public_key" = {
        mode = "0660";
        owner = "github-actions";
        group = "github-actions";
      };
      ssh_host_ed25519_key = {
        mode = "0600";
        path = "/etc/ssh/ssh_host_ed25519_key";
        sopsFile = ../../../secrets/${config.networking.hostName}.yaml;
      };
      ssh_host_ed25519_key_pub = {
        mode = "0644";
        path = "/etc/ssh/ssh_host_ed25519_key.pub";
        sopsFile = ../../../secrets/${config.networking.hostName}.yaml;
      };
      new_relic_config = {
        format = "yaml";
        sopsFile = ../../../secrets/new-relic.yaml;
        # Instead of single key emit the whole file
        # https://github.com/Mic92/sops-nix#emit-plain-file-for-yaml-and-json-formats
        key = "";
      };
    };
  };
}