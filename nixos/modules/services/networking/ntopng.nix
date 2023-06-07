{ config, lib, options, pkgs, ... }:

with lib;

let

  cfg = config.services.ntopng;
  opt = options.services.ntopng;

  createRedis = cfg.redis.createInstance != null;
  redisService =
    if cfg.redis.createInstance == "" then
      "redis.service"
    else
      "redis-${cfg.redis.createInstance}.service";

  configFile = if cfg.configText != "" then
    pkgs.writeText "ntopng.conf" ''
      ${cfg.configText}
    ''
    else
    pkgs.writeText "ntopng.conf" ''
      ${concatStringsSep " " (map (e: "--interface=" + e) cfg.interfaces)}
      --http-port=${toString cfg.httpPort}
      --redis=${cfg.redis.address}
      --data-dir=/var/lib/ntopng
      --user=ntopng
      ${cfg.extraConfig}
    '';

in

{

  imports = [
    (mkRenamedOptionModule [ "services" "ntopng" "http-port" ] [ "services" "ntopng" "httpPort" ])
  ];

  options = {

    services.ntopng = {

      enable = mkOption {
        default = false;
        type = types.bool;
        description = lib.mdDoc ''
          Enable ntopng, a high-speed web-based traffic analysis and flow
          collection tool.

          With the default configuration, ntopng monitors all network
          interfaces and displays its findings at http://localhost:''${toString
          config.${opt.http-port}}. Default username and password is admin/admin.

          See the ntopng(8) manual page and http://www.ntop.org/products/ntop/
          for more info.

          Note that enabling ntopng will also enable redis (key-value
          database server) for persistent data storage.
        '';
      };

      interfaces = mkOption {
        default = [ "any" ];
        example = [ "eth0" "wlan0" ];
        type = types.listOf types.str;
        description = lib.mdDoc ''
          List of interfaces to monitor. Use "any" to monitor all interfaces.
        '';
      };

      httpPort = mkOption {
        default = 3000;
        type = types.int;
        description = lib.mdDoc ''
          Sets the HTTP port of the embedded web server.
        '';
      };

      redis.address = mkOption {
        type = types.str;
        example = literalExpression "config.services.redis.ntopng.unixSocket";
        description = lib.mdDoc ''
          Redis address - may be a Unix socket or a network host and port.
        '';
      };

      redis.createInstance = mkOption {
        type = types.nullOr types.str;
        default = optionalString (versionAtLeast config.system.stateVersion "22.05") "ntopng";
        description = lib.mdDoc ''
          Local Redis instance name. Set to `null` to disable
          local Redis instance. Defaults to `""` for
          `system.stateVersion` older than 22.05.
        '';
      };

      configText = mkOption {
        default = "";
        example = ''
          --interface=any
          --http-port=3000
          --disable-login
        '';
        type = types.lines;
        description = lib.mdDoc ''
          Overridable configuration file contents to use for ntopng. By
          default, use the contents automatically generated by NixOS.
        '';
      };

      extraConfig = mkOption {
        default = "";
        type = types.lines;
        description = lib.mdDoc ''
          Configuration lines that will be appended to the generated ntopng
          configuration file. Note that this mechanism does not work when the
          manual {option}`configText` option is used.
        '';
      };

    };

  };

  config = mkIf cfg.enable {

    # ntopng uses redis for data storage
    services.ntopng.redis.address =
      mkIf createRedis config.services.redis.servers.${cfg.redis.createInstance}.unixSocket;

    services.redis.servers = mkIf createRedis {
      ${cfg.redis.createInstance} = {
        enable = true;
        user = mkIf (cfg.redis.createInstance == "ntopng") "ntopng";
      };
    };

    # nice to have manual page and ntopng command in PATH
    environment.systemPackages = [ pkgs.ntopng ];

    systemd.tmpfiles.rules = [ "d /var/lib/ntopng 0700 ntopng ntopng -" ];

    systemd.services.ntopng = {
      description = "Ntopng Network Monitor";
      requires = optional createRedis redisService;
      after = [ "network.target" ] ++ optional createRedis redisService;
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.ntopng}/bin/ntopng ${configFile}";
      unitConfig.Documentation = "man:ntopng(8)";
    };

    users.extraUsers.ntopng = {
      group = "ntopng";
      isSystemUser = true;
    };

    users.extraGroups.ntopng = { };
  };

}
