# NVIDIA GPU driver configuration
# See: https://wiki.nixos.org/wiki/NVIDIA

{ config, pkgs, ... }:

{
  # Enable NVIDIA driver (requires unfree)
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Use open-source kernel modules (Turing/RTX 20 and newer; set to false for older GPUs or proprietary modules)
    open = true;
    # Required for Wayland (Sway)
    modesetting.enable = true;
    # Optional: enable power management (can help with suspend/resume)
    powerManagement.enable = true;
    # Optional: enable fine-grained power management (Turing+)
    # powerManagement.finegrained = false;
    # Optional: use a specific driver version (default: stable)
    # package = config.boot.kernelPackages.nvidiaPackages.stable;
    # package = config.boot.kernelPackages.nvidiaPackages.production;
    # package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  # Laptop with hybrid graphics (Intel/AMD iGPU + NVIDIA dGPU): uncomment and set PCI bus IDs.
  # Find IDs with: nix shell nixpkgs#pciutils -c lspci -D -d ::03xx
  # Format: PCI:<bus>@<domain>:<device>:<func> (convert hex to decimal).
  # hardware.nvidia.prime = {
  #   offload.enable = true;
  #   offload.enableOffloadCmd = true;
  #   intelBusId = "PCI:0@0:2:0";   # Intel iGPU
  #   nvidiaBusId = "PCI:1@0:0:0";  # NVIDIA dGPU
  #   # amdgpuBusId = "PCI:5@0:0:0";  # AMD iGPU (use instead of intelBusId if AMD)
  # };
  # When using PRIME offload, also set:
  # services.xserver.videoDrivers = [ "modesetting" "nvidia" ];
}
