# Hard-coded #!/bin/bash shebangs expect FHS paths; NixOS normally only has bash on PATH.
{ pkgs, ... }:

{
  system.activationScripts.binbash = ''
    mkdir -p /bin
    chmod 0755 /bin
    ln -sfn ${pkgs.bash}/bin/bash /bin/bash
  '';
}
