{ lib, config, disko, ... }:
{
  options.myHost.disko.disks = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [ "/dev/nvme0n1" "/dev/nvme1n1" ];
    description = lib.mdDoc "Disks formatted by disko";
  };

  config = {
    # "aacraid" if you have adaptec raid controller
    # boot.initrd.availableKernelModules = [ "aacraid"];
    boot.loader = {
      efi.canTouchEfiVariables = false;
      grub = {
        device = "nodev"; # https://github.com/NixOS/nixpkgs/issues/33593#issuecomment-356989055
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        mirroredBoots = [
          # In raidz3 we can lose 3 disks and still have the system running
          # Disko installs GRUB to /boot even if it's not mentioned here
          # { path = "/boot"; devices = [ "nodev" ]; }
          { path = "/boot-fallback-1"; devices = [ "nodev" ]; }
          { path = "/boot-fallback-2"; devices = [ "nodev" ]; }
          { path = "/boot-fallback-3"; devices = [ "nodev" ]; }
        ];
      };
    };

    # the default zpool import services somehow times out while this import works fine?
    boot.initrd.systemd.services.zfs-import-zroot.serviceConfig = {
      ExecStartPre = "${config.boot.zfs.package}/bin/zpool import -N -f zroot";
      # Sometimes fails after the first try, with duplicate pool name errors
      Restart = "on-failure";
    };

    # Trim deletes unused blocks left from ZFS Copy on Write operations
    services.fstrim.enable = true;
    services.zfs.trim.enable = true;
    
    # Scrub tries to find corrupted blocks from disks and fixes them
    # We should watch logs from these to find out if 1 or more disks are failing
    services.zfs.autoScrub.enable = true;
    services.zfs.autoScrub.interval = "weekly";

    disko.devices = {
      disk = lib.genAttrs config.myHost.disko.disks (device: {
        name = lib.replaceStrings [ "/" ] [ "_" ] device;
        device = device;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # for grub MBR
            };
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                # Only first 4 devices are mounted as bootable
                # 1st device into /boot and others to /boot-fallback-{1,2,3}
                # Nix can be pretty fugly with these kind of things
                mountpoint = lib.mkIf (builtins.elem device (lib.lists.take 4 config.myHost.disko.disks))
                  "/boot${
                    if device == (builtins.elemAt config.myHost.disko.disks 0)
                    then ""
                    else "-fallback-" + toString (lib.lists.findFirstIndex (x: x == device) null config.myHost.disko.disks)
                  }";
                mountOptions = [ "nofail" "umask=0077" ];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      });
      # Use the disks defined above in this pool
      zpool = {
        zroot = {
          type = "zpool";
          mode = "raidz3";
          rootFsOptions = {
            canmount = "off";
          };

          # Check the sector size of the physical drive and match this with the alignment shift
          # For example a HDD mounted in /dev/sda:
          # $ fdisk -l /dev/sda
          # Disk /dev/sda: 9.1 TiB, 10000831348736 bytes, 19532873728 sectors
          # Disk model: ST10000NM0156-2A
          # Units: sectors of 1 * 512 = 512 bytes
          # Sector size (logical/physical): 512 bytes / 4096 bytes
          # I/O size (minimum/optimal): 4096 bytes / 4096 bytes
          # Then check the value from the following table:
          # ashift | Sector size
          # 9	     | 512 bytes
          # 10	   | 1 KB
          # 11	   | 2 KB
          # 12	   | 4 KB
          # 13	   | 8 KB
          # 14	   | 16 KB
          options.ashift = "12";

          # Allow impermanence by creating the snapshot after the first boot
          #postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zroot@blank$' || zfs snapshot zroot@blank";

          datasets = {
            root = {
              type = "zfs_fs";
              mountpoint = "/";
              options.mountpoint = "legacy";
              options = {
                compression = "zstd";
                "com.sun:auto-snapshot" = "false";
              };
            };
            # For Postgresql
            postgres = {
              type = "zfs_fs";
              mountpoint = "/var/lib/postgresql";
              options.mountpoint = "legacy";
              options = {
                # Source: https://people.freebsd.org/~seanc/postgresql/scale15x-2017-postgresql_zfs_best_practices.pdf
                acltype = "posixacl";
                atime = "off"; # Don't store access time because it causes way too many writes
                # I tested html page compression with different values
                # With zstd default (-3) 109 KiB =>   33.6 KiB in 5ms
                # With zstd compression -6 109 KiB =>   31.2 KiB in 7ms
                # After this the next levels were neglible savings like under 0.1 KiB per additional 1ms
                # Read seemed to be as fast for both and since I will mostly write to this server this seems better
                # -> Most likely that lower 30% throughput between -3 and -6 is more important than tiny disk savings
                compression = "zstd-3";
                xattr = "sa";
                # reduce amount of metadata (may improve random writes)
                redundant_metadata = "most";
                "com.sun:auto-snapshot" = "false";
              };
            };
          };
        };
      };
    };
  };
}
