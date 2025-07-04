{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  jre_headless,
  nixosTests,
}:

let
  pname = "jicofo";
  version = "1.0-1138";
  src = fetchurl {
    url = "https://download.jitsi.org/stable/${pname}_${version}-1_all.deb";
    sha256 = "YLzWyeeWWgsqfGAKXPIKIkfIq3McFEjcZGYLhi2Otew=";
  };
in
stdenv.mkDerivation {
  inherit pname version src;

  dontBuild = true;

  nativeBuildInputs = [ dpkg ];

  installPhase = ''
    runHook preInstall
    substituteInPlace usr/share/jicofo/jicofo.sh \
      --replace "exec java" "exec ${jre_headless}/bin/java"

    mkdir -p $out/{share,bin}
    mv usr/share/jicofo $out/share/
    mv etc $out/
    cp ${./logging.properties-journal} $out/etc/jitsi/jicofo/logging.properties-journal
    ln -s $out/share/jicofo/jicofo.sh $out/bin/jicofo
    runHook postInstall
  '';

  passthru.tests = {
    single-node-smoke-test = nixosTests.jitsi-meet;
  };

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    description = "Server side focus component used in Jitsi Meet conferences";
    mainProgram = "jicofo";
    longDescription = ''
      JItsi COnference FOcus is a server side focus component used in Jitsi Meet conferences.
    '';
    homepage = "https://github.com/jitsi/jicofo";
    license = licenses.asl20;
    teams = [ teams.jitsi ];
    platforms = platforms.linux;
  };
}
