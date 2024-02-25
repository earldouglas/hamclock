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
          rev = "76b6ee262ba12b97d8bea5abdf7868810e44195c";
          sha256 = "sha256-lL1rbbbit6uu2VWkoT+01z7LNgt7HUS4lh1b+1hzWD4=";
        };

      hamclockWeb =
        import hamclockWebSrc {
          pkgs = pkgs.pkgsCross.aarch64-multiplatform;
        };

      callsign = builtins.getEnv "HC_CALLSIGN";
      grid = builtins.getEnv "HC_GRID";
      tz = builtins.getEnv "HC_TZ";

    in {

      nixpkgs.system = "aarch64-linux";

      # EC2 ############################################################
      deployment = {
        targetEnv = "ec2";
        ec2 = {
          accessKeyId = accessKeyId;
          region = region;
          instanceType = "t4g.nano";
          keyPair = resources.ec2KeyPairs.hamclock-key-pair;
          ami = "ami-033ff64078c59f378";
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
        serviceConfig = {
          WorkingDirectory = "/home/hamclock";
          ExecStart = "${hamclockWeb}/bin/hamclock-web-2400x1440 -k";
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
