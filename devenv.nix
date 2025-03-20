{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

rec {
  # Use VS Code as the default editor
  # To see all undocumented VS Code flags visit:
  # https://github.com/microsoft/vscode/blob/main/src/vs/platform/environment/node/argv.ts
  env.EDITOR = "code --wait --skip-welcome --skip-release-notes --disable-telemetry --skip-add-to-recently-opened";
  # I noticed that when typing $ sops secret.yaml, that copilot was enabled
  # This made me worry that the secrets were being sent to a remote server
  # Disable co-pilot and all other extensions when editing SOPS secrets
  env.SOPS_EDITOR = "${env.EDITOR} --new-window --disable-workspace-trust --disable-extensions";

  # https://devenv.sh/packages/
  packages = with pkgs; [
    age
    git
    cloudflared
    nixos-rebuild

    # FIXME: Build sops from the main branch until 3.10 is released
    # See full parameters for sops nix build here:
    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/so/sops/package.nix
    (sops.overrideAttrs (
      finalAttrs: oldAttrs: {
        version = "3.10.0-unreleased";
        vendorHash = "sha256-anKhfq3bIV27r/AvvhSSniKUf72gklv8waqRz0lKypQ=";
        src = fetchFromGitHub {
          inherit (oldAttrs.src) owner repo;
          rev = "2eb776b01df5df04eee626da3e99e9717fffd9e0";
          hash = "sha256-VB4/DyQoQnV/AAXteJPsD2vbtAilZcJPTCXk2nvUZU8=";
        };
        postPatch = ''
          substituteInPlace go.mod \
            --replace-fail "go 1.22" "go ${finalAttrs.passthru.go.version}"
        '';
      }
    ))
  ];
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
  pre-commit.excludes = [ ".devenv" ];
  git-hooks.hooks = {
    # Nix files
    nixfmt-rfc-style.enable = true;
    # Github Actions
    actionlint.enable = true;
    # Markdown files
    markdownlint.enable = true;
    # Leaking secrets
    trufflehog.enable = true;
    ripsecrets.enable = true;
  };
  # Prevents unencrypted sops files from being committed
  pre-commit.hooks.pre-commit-hook-ensure-sops = {
    enable = true;
    # FIXME: doesn't support env file
    files = "secret.*\\.(yaml|yml|json)$";
  };

  # Security hardening to prevent malicious takeover of Github Actions:
  # https://news.ycombinator.com/item?id=43367987
  # Replaces tags like "v4" in 3rd party Github Actions to the commit hashes
  git-hooks.hooks.lock-github-action-tags = {
    enable = true;
    files = "^.github/workflows/";
    types = [ "yaml" ];
    entry =
      let
        script_path = pkgs.writeShellScript "lock-github-action-tags" ''
          for workflow in "$@"; do
            grep -E "uses:[[:space:]]+[A-Za-z0-9._-]+/[A-Za-z0-9._-]+@v[0-9]+" "$workflow" | while read -r line; do
              repo=$(echo "$line" | sed -E 's/.*uses:[[:space:]]+([A-Za-z0-9._-]+\/[A-Za-z0-9._-]+)@v[0-9]+.*/\1/')
              tag=$(echo "$line" | sed -E 's/.*@((v[0-9]+)).*/\1/')
              commit_hash=$(git ls-remote "https://github.com/$repo.git" "refs/tags/$tag" | cut -f1)
              [ -n "$commit_hash" ] && sed -i.bak -E "s|(uses:[[:space:]]+$repo@)$tag|\1$commit_hash #$tag|g" "$workflow" && rm -f "$workflow.bak"
            done
          done
        '';
      in
      toString script_path;
  };

  # See full reference at https://devenv.sh/reference/options/
}
