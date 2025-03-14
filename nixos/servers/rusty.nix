# Built from this example: https://github.com/nix-community/infra/blob/master/hosts/build01/default.nix
{ inputs, lib, pkgs, config, ... }:
let
  # Get the SSH keys collected from onnimonnis github
  inherit (inputs) onnimonni-ssh-keys;
in
{
  # Old Hetzner SX292 server from their Server auction

  # Give the machine unique name
  networking.hostName = "rusty";

  imports = [
    ./modules/disko-zfs.nix
    ./modules/programs.nix
    ./modules/postgresql.nix
    ./modules/sops.nix
    ./modules/new-relic.nix
  ];

  # Each disk is 10TB, contains small boot partitions and rest is for zfs pool
  # IMPORTANT: If you get more disks, don't change the order of the first 4 disks
  myHost.disko.disks = [
    # Mounted as /boot/
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA27YTZS"
    # Mounted to /boot-fallback-1
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA24E41J"
    # Mounted to /boot-fallback-2
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA25HDS1"
    # Mounted to /boot-fallback-3
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA26YMDV"
    # Following disks contain boot partitions too but are not mounted
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA27YTV6"
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA27YTWJ"
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA27YTY7"
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA27Z0LD"
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA27Z0QB"
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA27Z0QT"
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA294VWP"
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA29ENQD"
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA2AX1TV"
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA2AX1XV"
    "/dev/disk/by-id/ata-ST10000NM0156-2AA111_ZA27Z0Q2"
  ];

  # For some reason nix-channel is missing from the server
  # Without this we can't build directly in the server which is useful with Apple Silicon laptop
  # https://discourse.nixos.org/t/nix-channel-not-found-in-nixos-server/52322/2?u=onnimonni
  nix.channel.enable = lib.mkForce true;

  users.users = {
    onnimonni = {
      isNormalUser = true;
      shell = pkgs.fish;
      extraGroups = [ "users" "wheel" ];
      # Copy keys available in github.com directly here
      openssh.authorizedKeys.keyFiles = [ onnimonni-ssh-keys.outPath ];
    };
    # Create separate user for Github Actions so that we can deploy with them
    # TODO: Figure out if there would be better way to deploy
    github-actions = {
      isNormalUser = true;
      group = "github-actions";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ 
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPLiKMq7I730f07HwwZljX5QM/U0b1KPCDJRjmA77Ys/ github-actions@midwork"
      ];
    };
  };
  users.groups.github-actions = {};
  
  # TODO: Remove root user access completely
  users.users.root.openssh.authorizedKeys.keyFiles = [ onnimonni-ssh-keys.outPath ];

  # remove the fsck that runs at startup. It will always fail to run, stopping
  # your boot until you press *.
  boot.initrd.checkJournalingFS = false;

  # We don't use systemd-boot because Hetzner uses BIOS legacy boot.
  # Source: https://gist.github.com/bitonic/78529d3dd007d779d60651db076a321a
  boot.loader.systemd-boot.enable = false;

  boot.kernelParams = [
    # POTENTIALLY DANGEROUS: If the server will crash we will loose last 1 second of data
    # But it increases perf
    # "zfs.zfs_txg_timeout=1"

    # POTENTIALLY DANGEROUS: If we will run untrusted code it can escalate root privileges
    # Postgres perf can be improved 5-10% with this.
    # https://www.enterprisedb.com/blog/postgresql-meltdown-benchmarks
    # Turn off Spectre and Meltdown kernel mitigations
    # "mitigations=off"
  ];
  boot.initrd.kernelModules = [ "kvm-intel" ];

  # Stop power saving features, speeds up the server by 5%
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  # FIXME: Nixos doesn't support reading the IPv6 from SOPS
  # See more: https://discourse.nixos.org/t/using-sops-to-hide-the-ip-address-of-the-server-in-public-repository/61264/3
  # Because of this we need to read it from env instead
  # This sadly requires --impure flag as well
  systemd.network.networks."10-uplink".networkConfig.Address = builtins.getEnv "RUSTY_IPV6";

  services.postgresql = {
    ensureUsers = [
      {
        name = "midwork";
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [ "midwork" ];
  };

  # Before altering please read the comments:
  # https://nixos.org/manual/nixos/stable/#sec-upgrading
  system.stateVersion = "24.11";

  # TODO: Add automatic upgrades. See more https://nixos.wiki/wiki/Automatic_system_upgrades
}