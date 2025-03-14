{ inputs, pkgs, ... }:
{
  # Very nice for spotty connections
  programs.mosh.enable = true;
  
  # This has to be enabled if you want to use fish shell remotely
  programs.fish.enable = true;
}