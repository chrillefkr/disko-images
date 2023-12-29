{ self, config, lib, pkgs, modulesPath, specialArgs, ... }:

with lib;

let
  origConfig = config;
  diskoImages = import ./create-disko-images-in-vm.nix rec {
    inherit lib pkgs;
    config = origConfig;
    size = cfg.defaultDiskAllocSize;
    inherit (cfg) compress emulateUEFI includeChannel memory;
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
    includeChannel = mkOption {
      default = true;
      description = lib.mdDoc ''
        Whether to install nixpkgs.
      '';
    };
    memory = mkOption {
      default = 1024;
      description = lib.mdDoc ''
        How much memory (RAM) in MiB to allocate for VM during build.
        Some builds require more memory.
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
     emulateUEFI = mkOption {
       default = config.boot.loader.efi.canTouchEfiVariables;
       type = types.bool;
       defaultText = literalExpression "config.boot.loader.efi.canTouchEfiVariables";
       description = lib.mdDoc ''
         If true will emulate UEFI for storing EFI variables, e.g. boot entries. Variables will be stored as efidisk.qcow2
       '';
     };
  };

  config = {
    system.build.diskoImages = diskoImages.images;
  };
}
