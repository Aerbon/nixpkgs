{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "ferretdb";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "FerretDB";
    repo = "FerretDB";
    rev = "v${version}";
    sha256 = "sha256-V33NeNpQZFUN/aUCaaxnCgIYaVgbAI5L6GZQo8ZMvUI=";
  };

  postPatch = ''
    echo v${version} > build/version/version.txt
    echo nixpkgs     > build/version/package.txt
  '';

  vendorSha256 = "sha256-QoDNQXZGfUq/t8fiovCv0+N9e4shJGpwS3y/z0YXMi4=";

  CGO_ENABLED = 0;

  subPackages = [ "cmd/ferretdb" ];

  tags = [ "ferretdb_tigris" ];

  # tests in cmd/ferretdb are not production relevant
  doCheck = false;

  # the binary panics if something required wasn't set during compilation
  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/ferretdb --version | grep ${version}
  '';

  meta = with lib; {
    description = "A truly Open Source MongoDB alternative";
    homepage = "https://www.ferretdb.io/";
    license = licenses.asl20;
    maintainers = with maintainers; [ dit7ya noisersup julienmalka ];
  };
}
