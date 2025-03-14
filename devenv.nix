{ pkgs, lib, config, inputs, ... }:

{
  # Use VS Code as the default editor for sops secrets
  env.EDITOR = "code --wait";

  # https://devenv.sh/packages/
  packages = [ pkgs.age pkgs.sops pkgs.git pkgs.cloudflared pkgs.nixos-rebuild ];
  # TODO: add age-plugin-se when https://github.com/NixOS/nixpkgs/pull/382902 is merged

  # https://devenv.sh/languages/
  # languages.rust.enable = true;

  # https://devenv.sh/processes/
  # processes.cargo-watch.exec = "cargo-watch";

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo Loaded the environment for MidWork
  '';

  enterShell = ''
    hello
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
