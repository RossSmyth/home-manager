{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.programs.jujutsu;
  tomlFormat = pkgs.formats.toml { };

  configDir = if pkgs.stdenv.isDarwin then
    "Library/Application Support"
  else
    config.xdg.configHome;

in {
  meta.maintainers = [ maintainers.shikanime ];

  imports = let
    mkRemovedShellIntegration = name:
      mkRemovedOptionModule [ "programs" "jujutsu" "enable${name}Integration" ]
      "This option is no longer necessary.";
  in map mkRemovedShellIntegration [ "Bash" "Fish" "Zsh" ];

  options.programs.jujutsu = {
    enable =
      mkEnableOption "a Git-compatible DVCS that is both simple and powerful";

    package = mkPackageOption pkgs "jujutsu" { };

    ediff = mkOption {
      type = types.bool;
      default = config.programs.emacs.enable;
      defaultText = literalExpression "config.programs.emacs.enable";
      description = ''
        Enable ediff as a merge tool
      '';
    };

    difftastic = {
      enable = mkEnableOption "" // {
        description = ''
          Enable the {command}`difftastic` syntax highlighter.
          See <https://github.com/Wilfred/difftastic>.
        '';
      };

      package = mkPackageOption pkgs "difftastic" { };

      background = mkOption {
        type = types.enum [ "light" "dark" ];
        default = "light";
        example = "dark";
        description = ''
          Determines whether difftastic should use the lighter or darker colors
          for syntax highlighting.
        '';
      };

      color = mkOption {
        type = types.enum [ "always" "auto" "never" ];
        default = "auto";
        example = "always";
        description = ''
          Determines when difftastic should color its output.
        '';
      };

      display = mkOption {
        type =
          types.enum [ "side-by-side" "side-by-side-show-both" "inline" ];
        default = "side-by-side";
        example = "inline";
        description = ''
          Determines how the output displays - in one column or two columns.
        '';
      };
    };

    settings = mkOption {
      type = tomlFormat.type;
      default = { };
      example = {
        user = {
          name = "John Doe";
          email = "jdoe@example.org";
        };
      };
      description = ''
        Options to add to the {file}`config.toml` file. See
        <https://github.com/martinvonz/jj/blob/main/docs/config.md>
        for options.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = [ cfg.package ];

      xdg.configFile = 
        (mkIf (cfg.settings != { }) {
          "jj/config.toml".text = tomlFormat.generate "jujutsu-config" cfg.settings;
        });
    }

    (mkIf cfg.difftastic.enable {
      home.packages = [ cfg.difftastic.package ];

      jujutsu.settings.ui.diff.tool = [
          "${getExe cfg.difftastic.package}"
          "--color ${cfg.difftastic.color}"
          "--background ${cfg.difftastic.background}"
          "--display ${cfg.difftastic.display}"
          "$left"
          "$right"
        ];
    })

    (mkIf cfg.ediff {
        jujutsu.setting.merge-tools.ediff = let
        emacsDiffScript = pkgs.writeShellScriptBin "emacs-ediff" ''
          set -euxo pipefail
          ${config.programs.emacs.package}/bin/emacsclient -c --eval "(ediff-merge-files-with-ancestor \"$1\" \"$2\" \"$3\" nil \"$4\")"
        '';
        in 
          {
            program = getExe emacsDiffScript;
            merge-args = [ "$left" "$right" "$base" "$output" ];
          };
    })
    ]);
}
