{ lib, pkgs, config, postVM ? "", size ? "2048M", includeChannel ? false, postInstallScript ? "", compress ? false }:
let
  compress_args = if compress then "-c" else "";
  channelSources =
    let
      nixpkgs = lib.cleanSource pkgs.path;
    in
    pkgs.runCommand "nixos-${config.system.nixos.version}" { } ''
      mkdir -p $out
      cp -prd ${nixpkgs.outPath} $out/nixos
      chmod -R u+w $out/nixos
      if [ ! -e $out/nixos/nixpkgs ]; then
        ln -s . $out/nixos/nixpkgs
      fi
      rm -rf $out/nixos/.git
      echo -n ${config.system.nixos.versionSuffix} > $out/nixos/.version-suffix
    '';

  closureInfo = pkgs.closureInfo {
    rootPaths = [ config.system.build.toplevel ]
      ++ (lib.optional includeChannel channelSources);
  };

  modulesTree = pkgs.aggregateModules
    (with config.boot.kernelPackages; [ kernel zfs ]);

  tools = lib.makeBinPath (
    with pkgs; [
      config.system.build.nixos-enter
      config.system.build.nixos-install
      dosfstools
      e2fsprogs
      gptfdisk
      nix
      parted
      util-linux
      zfs
    ]
  );

  disk_paths = with builtins; map (disk: disk.device) (attrValues config.disko.devices.disk);
  disk_names = with builtins; attrNames config.disko.devices.disk;

  images = (
    pkgs.vmTools.override {
      rootModules =
        [ "virtio_pci" "virtio_mmio" "virtio_blk" "virtio_balloon" "virtio_rng" "ext4" "unix" "9p" "9pnet_virtio" "crc32c_generic" ] ++
        [ "zfs" ] ++
        (pkgs.lib.optional pkgs.stdenv.hostPlatform.isx86 "rtc_cmos");
      kernel = modulesTree;
    }
  ).runInLinuxVM (
    pkgs.runCommand "${config.system.name}"
      {
        memSize = 1024;
        QEMU_OPTS = toString (builtins.map (disk_name: "-drive file=${builtins.baseNameOf disk_name}.qcow2,if=virtio,cache=unsafe,werror=report") disk_names);
        preVM = ''
          set -x
          PATH=$PATH:${pkgs.qemu_kvm}/bin
          mkdir -p $out

          for disk_image in ${ toString (map baseNameOf disk_names) }; do
            echo "Creating ''${disk_image}.qcow2 with size ${toString size}"
            qemu-img create -f qcow2 "''${disk_image}.qcow2" ${toString size}
          done
        '';

        postVM = ''
          set -x
          for disk_image in ${ toString (map baseNameOf disk_names) }; do
            echo Compressing "''${disk_image}.qcow2"
            ${pkgs.qemu}/bin/qemu-img convert -p -f qcow2 -O qcow2 ${compress_args} "''${disk_image}.qcow2" "''${out}/''${disk_image}.qcow2"
          done
          ${postVM}
        '';
      }
      ''
      export PATH=${tools}:$PATH
      set -x

      # Create symlinks with disko device paths pointing to /dev/vdX
      # It's stupid, but it works
      local_disks=( /dev/vd{a..z} )
      index=0
      for to in ${ toString disk_paths }; do
        from="''${local_disks[$index]}"
        if [ "$from" == "$to" ]; then continue; fi
        mkdir -p $( dirname $( realpath -s "$to" ) )
        ln -vs "''${from}" "''${to}"
        for i in $(seq 0 10); do
          ln -vs "''${from}''${i}" "''${to}''${i}"
          ln -vs "''${from}''${i}" "''${to}p''${i}"
          ln -vs "''${from}''${i}" "''${to}-part''${i}"
        done
        index=$(( $index + 1 ))
      done

      # Run disko-create
      ${config.system.build.formatScript}
      # Run disko-mount
      ${config.system.build.mountScript}

      # Install NixOS

      export NIX_STATE_DIR=$TMPDIR/state
      nix-store --load-db < ${closureInfo}/registration

      nixos-install \
        --root /mnt \
        --no-root-passwd \
        --system ${config.system.build.toplevel} \
        --substituters "" \
        ${lib.optionalString includeChannel ''--channel ${channelSources}''}

      # Run postInstallScript
      ${postInstallScript}

      # Clean up disk from unused sectors
      fstrim -av

      # Unmount all filesystems
      umount -Rv /mnt || :

      # Export all zfs zpools
      for zpool in ${toString ( builtins.attrNames config.disko.devices.zpool ) }; do
        echo Exporting zpool "$zpool"
        zpool export "$zpool"
      done

      # Disconnect all volume groups
      # for zpool in ''${toString ( builtins.attrNames (lib.attrValues config.disko.devices.zpool))}; do

      # done
    ''
  );
in
  {
    inherit images;
  }
