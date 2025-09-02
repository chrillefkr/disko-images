This project is discontinued.
Upstream disko has got [its own implementation](https://github.com/nix-community/disko/blob/a5c4f2ab72e3d1ab43e3e65aa421c6f2bd2e12a1/docs/disko-images.md) for creating disk images.

# Disko Images

Create disk image files from NixOS + [disko](https://github.com/nix-community/disko) configuration.

This is done by running `disko-create`, `disko-mount`and then`nixos-install` in a VM, where
each `config.disko.devices.disk` is mounted as a qcow2 image.

It heavily relies on qcow2 as to not create too large image files. Compression is optional.

## Usage

Add disko-images as a NixOS module (using flakes):

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-22.11";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko-images.url = "github:chrillefkr/disko-images";
  };
  outputs = { self, nixpkgs, disko, disko-images, ... } @inputs:
  let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
  in
  {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      inherit pkgs;
      specialArgs.inputs = inputs;
      modules = [
        ./configuration.nix
        ./disko.nix
        disko.nixosModules.disko
        disko-images.nixosModules.disko-images
      ];
    };
  };
}
```

Build disko images using `nix build '.#nixosConfigurations.my-machine.config.system.build.diskoImages'`.

Your disk image files appear at `./results/*.qcow2`.

## About

First of all, this is a very simple (but working) way of creating disk images from NixOS + disko configuration.
I've used it mainly to create Raspberry Pi SD card images.

Inspired by:

* https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/sd-card/sd-image-aarch64.nix
* https://nixos.wiki/wiki/NixOps/Virtualization

## TODO

* [ ] Ensure support for
  * [X] zfs
  * [ ] btrfs
  * [ ] lvm
* [ ] Individual disk size (`config.diskoImages.diskAllocSizes`)
* [ ] Create tests
* [ ] Create examples

## Known issues

### Raspberry Pi Linux kernel

The Raspberry Pi 4 Linux kernel (`pkgs.linuxPackages_rpi4`) (and problably kernels for the older boards) doesn't seem to work, as
the kernel seems to lack support for 9pnet_virtio. It gives me the error message `9pnet_virtio: no channels available for device <device>`
when it attemts to mount the nix store.

A fix is to use official Linux kernel, e.g.:
`boot.kernelPackages = pkgs.linuxPackages;`

## Contribution

Please help. I'm quite new to Nix and NixOS, so any PR or issue is appreciated.
