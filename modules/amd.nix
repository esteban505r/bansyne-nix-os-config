# AMD GPU basic setup (amdgpu driver)
# See: https://wiki.nixos.org/wiki/AMD_GPU
# Safe to use on shared configs: enable32Bit is useful for any GPU (e.g. Steam).

{
  # Graphics acceleration (enable is usually already set in configuration.nix; enable32Bit for 32-bit OpenGL/Vulkan, e.g. games)
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
}
