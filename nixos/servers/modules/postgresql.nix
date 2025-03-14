{ config, lib, inputs, pkgs, ... }:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16.withJIT;

    enableJIT = true;

    # TODO: Move this to midwork.nix which also defines the elixir service
    ensureDatabases = [ "midwork" ];
    ensureUsers = [{
      name = "midwork";
      ensureDBOwnership = true;
    }];

    extensions = [
      # TODO: Figure out how to get pg_duckdb and paradedb here
      pkgs.postgresqlPackages.postgis
    ];

    # Source: https://github.com/nix-community/infra/blob/db5fdfe6821fbf6132c2652b9dc3d6507dbfc8dd/hosts/build03/postgresql.nix
    settings = {
      # https://vadosware.io/post/everything-ive-seen-on-optimizing-postgres-on-zfs-on-linux/#zfs-related-tunables-on-the-postgres-side
      full_page_writes = "off";

      # Connectivity
      max_connections = 100;
      superuser_reserved_connections = 3;

      # Memory Settings
      shared_buffers = "65536 MB";
      work_mem = "128 MB";
      maintenance_work_mem = "1620 MB";
      huge_pages = "try"; # NB! requires also activation of huge pages via kernel params, see here for more: https://www.postgresql.org/docs/current/static/kernel-resources.htm;l#LINUX-HUGE-PAGES
      effective_cache_size = "179 GB";
      effective_io_concurrency = 7; # concurrent IO only really activated if OS supports posix_fadvise function
      random_page_cost = 4; # speed of random disk access relative to sequential access (1.0)

      # Monitoring
      shared_preload_libraries = "pg_stat_statements"; # per statement resource usage stats
      track_io_timing="on"; # measure exact block IO times
      track_functions="pl"; # track execution times of pl-language procedures if any

      # Replication
      wal_level = "replica"; # consider using at least "replica"
      max_wal_senders = 0;
      # POTENTIALLY DANGEROUS:
      synchronous_commit = "off";

      # Checkpointing:
      checkpoint_timeout = "15 min";
      checkpoint_completion_target = 0.9;
      max_wal_size = "32768 MB";
      min_wal_size = "16384 MB";


      # WAL writing
      wal_compression = "on";
      wal_buffers = -1; # auto-tuned by Postgres till maximum of segment size (16MB by default)
      wal_writer_delay = "200ms";
      wal_writer_flush_after = "1MB";


      # Background writer
      bgwriter_delay = "200ms";
      bgwriter_lru_maxpages = 100;
      bgwriter_lru_multiplier = 2.0;
      bgwriter_flush_after = 0;

      # Parallel queries:
      max_worker_processes = 6;
      max_parallel_workers_per_gather = 3;
      max_parallel_maintenance_workers = 3;
      max_parallel_workers = 6;
      parallel_leader_participation = "on";

      # Advanced features
      enable_partitionwise_join = "on";
      enable_partitionwise_aggregate = "on";
      jit = "on";
      max_slot_wal_keep_size = "10000 MB";
      track_wal_io_timing = "on";
      maintenance_io_concurrency = 7;
      wal_recycle = "on";
    };
  };

  # Updating the postgresql version is a bit tricky.
  # You should run the provided `upgrade-pg-cluster` script before you want to upgrade to next version.
  # Read more here https://nixos.org/manual/nixos/stable/#module-services-postgres-upgrading
  environment.systemPackages = [
    (let
      # TODO: specify the postgresql package you'd like to upgrade to.
      # Do not forget to list the extensions you need.
      newPostgres = pkgs.postgresql_16.withPackages (pp: [
        pp.postgis
      ]);
      cfg = config.services.postgresql;
    in pkgs.writeScriptBin "upgrade-pg-cluster" ''
      set -eux
      # XXX it's perhaps advisable to stop all services that depend on postgresql
      systemctl stop postgresql

      export NEWDATA="/var/lib/postgresql/${newPostgres.psqlSchema}"

      export NEWBIN="${newPostgres}/bin"

      export OLDDATA="${cfg.dataDir}"
      export OLDBIN="${cfg.package}/bin"

      install -d -m 0700 -o postgres -g postgres "$NEWDATA"
      cd "$NEWDATA"
      sudo -u postgres $NEWBIN/initdb -D "$NEWDATA" ${lib.escapeShellArgs cfg.initdbArgs}

      sudo -u postgres $NEWBIN/pg_upgrade \
        --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
        --old-bindir $OLDBIN --new-bindir $NEWBIN \
        "$@"
    '')
  ];
}