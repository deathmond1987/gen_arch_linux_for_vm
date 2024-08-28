bash script to generate a disk image (vhdx, mvdk, qemu img, tar.gz(wsl2 rootfs)) with arch linux installed with lvm and uefi.
can gen OS in hosts like debian, arch, fedora and alpine linux
build image:

      sudo ./archlinux_vm_generator.sh
without options it creates img for qemu with my personal configs (with user kosh and passwd qwe)
  options: 
```
      --wsl/-w - create tar archive for wsl.
      --clean/-c - create clean Arch Linux image (without my personal config).
      --qemu/-q - check created image in qemu (Not working with --wsl key)
      --vmware/-v - gen image for VMWARE (Not working with --wsl key)
      --hyperv/-y - gen image for HYPER-V (Not working with --wsl key)
      --user-name/-u - user name in created system
      --password/-p - user and root password in created system
```
  examples:
```
sudo ./archlinux_vm_generator.sh --qemu
(generates qemu image with my config. and run that image in qemu)

sudo ./archlinux_vm_generator.sh --vmware --hyperv --user anna --password example
(generates vmdk and vhdx images with user anna and password example in OS)
```
