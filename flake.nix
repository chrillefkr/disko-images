{
  inputs = {
    #nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    #nixlib.url = "github:nix-community/nixpkgs.lib";
    # disko = {
    #   url = "github:nix-community/disko";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };
  outputs = { self }@inputs:
  {
    nixosModules = rec {
      disko-images = ./disko-images.nix;
      default = disko-images;
    };
  };
}
