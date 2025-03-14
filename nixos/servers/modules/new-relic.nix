{ inputs, pkgs, config, ... }:
{
  nixpkgs = {
    overlays = [
      inputs.nix-relic.overlays.additions
    ];
  };

  # See more in https://github.com/DavSanchez/Nix-Relic
  services.newrelic-infra = {
    enable = true;
    # You need to create a key with type "INGEST - LICENSE" from
    # https://one.eu.newrelic.com/admin-portal/api-keys/home
    configFile = config.sops.secrets.new_relic_config.path;
  };
}