# Auto-mount portable / removable drives when connected (e.g. USB sticks, external HDDs)
# Drives appear under /run/media/<username>/<label or device>

{ config, pkgs, ... }:

{
  services.udisks2.enable = true;
}
