{
  description = "pCloud Drive flake package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (if pkg ? pname then pkg.pname else (builtins.parseDrvName pkg.name).name) [ "pcloud" "pcloud-drive" ];
      };
    in
    {
      packages.${system} = {
        pcloud = pkgs.callPackage ./pkgs/pcloud { };

        default = self.packages.${system}.pcloud;
      };

      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.pcloud}/bin/pcloud";
      };
    };
}
