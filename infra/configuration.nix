let

  region = "us-east-2";
  accessKeyId = "hamclock";

in {

  network.description = "HamClock";

  resources.ec2KeyPairs.hamclock-key-pair = {
      inherit region accessKeyId;
    };

  resources.elasticIPs.hamclock-elastic-ip = {
    inherit region accessKeyId;
    vpc = true;
    name = "wx";
  };

  hamclock =
    { resources, pkgs, ... }:
    let

      hamclockWebSrc =
        pkgs.fetchFromGitHub {
          owner = "earldouglas";
          repo = "hamclock";
          rev = "857beea92f91ae3194738807dba07dcee1565c8b";
          sha256 = "0wiapkxk31nm6zrlfwvcbq8bzybbz2g61g4gn06jh85iw4z0s1pa";
        };

      hamclockWeb =
        import hamclockWebSrc {};

      callsign = builtins.getEnv "HC_CALLSIGN";
      grid = builtins.getEnv "HC_GRID";
      tz = builtins.getEnv "HC_TZ";

    in {

      # EC2 ############################################################
      deployment = {
        targetEnv = "ec2";
        ec2 = {
          accessKeyId = accessKeyId;
          region = region;
          instanceType = "t3a.nano";
          keyPair = resources.ec2KeyPairs.hamclock-key-pair;
          ami = "ami-00f27b88d169080ac";
          ebsInitialRootDiskSize = 12;
          elasticIPv4 = resources.elasticIPs.hamclock-elastic-ip;
        };
      };

      # GC #############################################################
      nix.gc.automatic = true;
      nix.gc.options = "-d";
      nix.optimise.automatic = true;

      # Disable docs ###################################################
      documentation.enable = false;
      documentation.dev.enable = false;
      documentation.doc.enable = false;
      documentation.info.enable = false;
      documentation.man.enable = false;
      documentation.nixos.enable = false;

      # Security #######################################################
      services.fail2ban.enable = true;
      networking.firewall.allowedTCPPorts = [ 22 80 443 ];

      # Service ########################################################
      users.extraUsers.hamclock = {
        isNormalUser = true;
        home = "/home/hamclock";
      };

      systemd.services.hamclock = {
        description = "hamclock";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        script = ''
          export PATH="$PATH:/run/current-system/sw/bin"
          ${hamclockWeb}/bin/hamclock-web-2400x1440 -k -g -o -f on -d /home/hamclock/.hamclock/
        '';
        serviceConfig = {
          WorkingDirectory = "/home/hamclock";
          User = "hamclock";
          Restart = "always";
        };
      };
 
      systemd.services.hamclockDe = {
        description = "Configure HamClock DE";
        after = [ "hamclock.service" ];
        wantedBy = [ "multi-user.target" ];
        script = ''
          ${pkgs.curl}/bin/curl --retry-connrefused --retry 10 'http://localhost:8080/set_newde?grid=${grid}&TZ=${tz}&call=${pkgs.lib.strings.toUpper callsign}'
        '';
        serviceConfig = {
          Type = "oneshot";
          PermissionsStartOnly = true;
        };
      };

      security.acme = {
        defaults.email = "james@earldouglas.com";
        acceptTerms = true;
      };

      services.nginx = {
        enable = true;
        recommendedGzipSettings = true;

        commonHttpConfig = ''
          charset utf-8;
          log_format postdata '$time_local\t$remote_addr\t$request_body';
          limit_req_zone $binary_remote_addr zone=ip:10m rate=5r/s;
          add_header Permissions-Policy "interest-cohort=()";
          add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        '';

        virtualHosts = {
          "hamclock.earldouglas.com" = {
            enableACME = true;
            onlySSL = false; # preferred for securitah
            forceSSL = true; # needed for acme?
            locations."/${callsign}".extraConfig = ''
              rewrite ^/${callsign}/$ /live.html break;
              rewrite /${callsign}/(.*) /$1 break;
              proxy_pass http://localhost:8081;
            '';
            locations."/".extraConfig = ''
              add_header Content-Type text/plain;
              return 200;
            '';
          };
        };
      };
  };
}
