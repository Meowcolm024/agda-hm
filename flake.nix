{
  description = "Agda + Home Manager module";

  inputs = {
    # nix and home manager
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # agda
    agda.url = "github:agda/agda/v2.8.0";
    agda.inputs.nixpkgs.follows = "nixpkgs";
    agda-stdlib.url = "github:agda/agda-stdlib/v2.3";
    agda-stdlib.flake = false;
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      agda,
      agda-stdlib,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      systems = nixpkgs.lib.systems.flakeExposed;

      perSystem =
        { system, pkgs, ... }:
        let
          agdaPkg = agda.packages.${system}.default; # agda binary

          buildAgdaLibrary =
            {
              name,
              src,
            }:
            pkgs.stdenv.mkDerivation {
              pname = name;
              version = "dev";

              inherit src;

              nativeBuildInputs = [ agdaPkg ];

              buildPhase = ''
                export HOME=$TMPDIR

                cp -r $src lib
                chmod -R u+w lib
                cd lib

                agda --build-library
              '';

              installPhase = ''
                mkdir -p $out
                cp -r . $out/
              '';
            };
        in
        {
          packages.agda-stdlib-bin = buildAgdaLibrary {
            name = "agda-stdlib-bin";
            src = agda-stdlib;
          };
        };

      flake.homeManagerModules.default =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        let
          system = pkgs.stdenv.hostPlatform.system;
          stdlib = inputs.self.packages.${system}.agda-stdlib-bin;
          agdaPkg = inputs.agda.packages.${system}.default;
        in
        {
          options.programs.agda.enable = lib.mkEnableOption "Agda";

          config = lib.mkIf config.programs.agda.enable {
            home.packages = [ agdaPkg ];

            home.file.".agda/libraries".text = ''
              ${stdlib}/standard-library.agda-lib
            '';

            home.file.".agda/defaults".text = ''
              standard-library
            '';
          };
        };
    };
}
