name: { nixpkgs, pkgs, lib, home-manager, system, user, hyprland }:

nixpkgs.lib.nixosSystem {
  inherit system;

  nixpkgs.overlays = [
  (self: super: {
    fcitx-engines = pkgs.fcitx5;
  })
  ]

  modules = [

    ../hardware/${name}.nix
    ../machines/${name}.nix
    hyprland.nixosModules.default
    ../users/${user}/nixos.nix

    home-manager.nixosModules.home-manager {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${user} = import ../users/chaosinthecrd/home-manager.nix {
          inherit lib pkgs;
        };
    }

  ];
}
