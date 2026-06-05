# Gaming: emulators, Steam, and game launchers for the retro/multimedia PC.

{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # --- RetroArch (libretro frontend) with a broad core selection ---
    (retroarch.withCores (cores: with cores; [
      snes9x              # SNES
      genesis-plus-gx     # Mega Drive / Genesis / Game Gear / Master System
      mgba                # GBA / GB / GBC
      mupen64plus         # N64
      beetle-psx-hw       # PS1 (hardware-rendered Mednafen)
      beetle-saturn       # Saturn
      swanstation         # PS1 (alt, DuckStation core)
      desmume             # DS
      melonds             # DS (more accurate)
      fceumm              # NES
      nestopia            # NES (alt)
      picodrive           # 32X / Sega CD
      flycast             # Dreamcast
      ppsspp              # PSP
      stella              # Atari 2600
      parallel-n64        # N64 (alt)
      mame2003-plus       # Arcade (MAME 2003+)
      fbneo               # FinalBurn Neo (arcade)
      vba-next            # GBA (alt)
    ]))

    # --- Standalone emulators (often better than the libretro core) ---
    dolphin-emu     # GameCube / Wii
    pcsx2           # PS2
    rpcs3           # PS3
    ppsspp          # PSP
    duckstation     # PS1
    mgba            # GBA
    melonDS         # DS
    mupen64plus     # N64
    snes9x          # SNES
    mame            # Arcade (full MAME)
    scummvm         # Adventure games (LucasArts/Sierra)
    cemu            # Wii U
    flycast         # Dreamcast

    # --- Game launchers / clients ---
    steam           # Steam client
    steam-run       # Run vendor binaries in Steam runtime
    lutris          # Multi-platform game launcher (Wine, GOG, emus)
    heroic          # Epic Games / GOG / Amazon launcher
    bottles         # Wine prefix manager

    # --- Controller / input tools ---
    jstest-gtk      # Joystick test/calibration GUI
    sdl-jstest      # SDL joystick test
    antimicrox      # Map controller to keyboard/mouse
  ];

  # Joy-Con / Pro Controller: udev rules + joycond daemon at boot
  services.joycond.enable = true;
  programs."joycond-cemuhook".enable = true;

  # Steam with Remote Play + dedicated server firewall holes
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;   # Optional gamescope session for Big-Picture
  };

  # GameMode: CPU governor + I/O priority tweaks while a game is running
  programs.gamemode.enable = true;

  # Generic Xbox/8BitDo/PS controller udev rules
  hardware.xpadneo.enable = true;     # Xbox One / Series wireless via Bluetooth
  hardware.steam-hardware.enable = true;  # Steam Controller / Steam Deck dock udev

  # Pipewire (configured in audio.nix) already supplies 32-bit PulseAudio.
}
