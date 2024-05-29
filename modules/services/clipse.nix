{ pkgs, config, lib, ... }:
let
  cfg = config.services.clipse;
  jsonFormat = pkgs.formats.json { };
in

with lib;

{
  options.services.clipse = {
    enable = mkEnableOption "Enable clipse clipboard manager";

    package = mkPackageOption pkgs "clipse" { };

    systemdTarget = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      example = "sway-session.target";
      description = ''
        The systemd target that will automatically start the clipse service.

        When setting this value to `"sway-session.target"`,
        make sure to also enable {option}`wayland.windowManager.sway.systemd.enable`,
        otherwise the service may never be started.
      '';
    };

    historySize = mkOption {
      type = types.int;
      default = 100;
      description = "Number of history lines to keep.";
    };

    theme = mkOption {
      type = jsonFormat.type;

      default = {
        useCustomTheme = false;
      };

      example = literalExpression ''
        {
          useCustomTheme = true;
          DimmedDesc = "#ffffff";
          DimmedTitle = "#ffffff";
          FilteredMatch = "#ffffff";
          NormalDesc = "#ffffff";
          NormalTitle = "#ffffff";
          SelectedDesc = "#ffffff";
          SelectedTitle = "#ffffff";
          SelectedBorder = "#ffffff";
          SelectedDescBorder = "#ffffff";
          TitleFore = "#ffffff";
          Titleback = "#434C5E";
          StatusMsg = "#ffffff";
          PinIndicatorColor = "#ff0000";
        };
      '';

      description = ''
        Configuration written to
        {file}`$XDG_CONFIG_HOME/clipse/custom_theme.json`.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      (lib.hm.assertions.assertPlatform "services.clipse" pkgs
        lib.platforms.linux)
    ];

    home.packages = [ cfg.package ];

    xdg.configFile."clipse/config.json".source = jsonFormat.generate "settings" {
      historyFile = "clipboard_history.json";
      maxHistory = cfg.historySize;
      themeFile = "custom_theme.json";
      tempDir = "tmp_files";
    };

    xdg.configFile."clipse/custom_theme.json".source = jsonFormat.generate "theme" cfg.theme;

    systemd.user.services.clipse = {
      Unit = {
        Description = "Clipboard management daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/clipse --listen-shell > /dev/null";
        Restart = "on-failure";
      };

      Install = { WantedBy = [ cfg.systemdTarget ]; };
    };
  };
}

