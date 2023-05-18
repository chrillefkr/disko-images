{ self, config, lib, pkgs, modulesPath, specialArgs, ... }:

with lib;

let
  origConfig = config;
  diskoImages = import ./create-disko-images-in-vm.nix rec {
    inherit lib pkgs;
    config = origConfig;
    size = cfg.defaultDiskAllocSize;
    inherit (cfg) compress;
  };
  cfg = config.diskoImages;
in
{
  options.diskoImages = {
    compress = mkOption {
      default = true;
      description = lib.mdDoc ''
        Compresses qcow2 image as final step when enabled
      '';
    };
    defaultDiskAllocSize = mkOption {
      default = "2048M";
      description = lib.mdDoc ''
        Default initial qcow2 image file size allocation (in MB) for each disk in disko.devices.disk.
        Use config.diskoImages.diskAllocSizes for specific allocation sizes per disk.
      '';
    };
    diskAllocSizes = mkOption {
      default = {};
      description = lib.mdDoc ''
        Initial qcow2 image file size allocation (in MB) for each disko.devices.disk.xyz. Defaults to config.diskoImages.defaultDiskAllocSize
      '';
    };
  };

  config = {
    system.build.diskoImages = diskoImages.images;
  };
}
