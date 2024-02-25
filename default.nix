{ pkgs ? import <nixpkgs> {}}:
pkgs.stdenv.mkDerivation {

  name = "hamclock";
  src =
    pkgs.fetchFromGitHub {
      owner = "earldouglas";
      repo = "hamclock";
      rev = "3.05";
      sha256 = "sha256-5+YpKTFgomGyDJT7hlcho8ze2n83E1BQMUpYE4AIvEA=";
    };

  nativeBuildInputs = [
    pkgs.gcc
  ];

  buildInputs = [
    pkgs.xorg.libX11
  ];

  dontConfigure = true;

  buildPhase = ''

    make hamclock-web-800x480
    install -Dm 555 -t $out/bin/ hamclock-web-800x480

    make hamclock-web-1600x960
    install -Dm 555 -t $out/bin/ hamclock-web-1600x960

    make hamclock-web-2400x1440
    install -Dm 555 -t $out/bin/ hamclock-web-2400x1440

    make hamclock-web-3200x1920
    install -Dm 555 -t $out/bin/ hamclock-web-3200x1920

  '';

  meta = with pkgs.lib; {
    description = "A desk clock with information useful for hams.";
    homepage = "https://www.clearskyinstitute.com/ham/HamClock/";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = with maintainers; [ earldouglas ];
  };
}
