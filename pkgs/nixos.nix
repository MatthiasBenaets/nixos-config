{ pkgs, ... }:
with pkgs;

{
  home = {
    packages = with pkgs; [
      spotify bitwarden _1password-gui pavucontrol pamixer lsof wtype slack thunderbird-unwrapped pamixer
      pinentry
    ];
  };
}