# This file was generated by nvfetcher, please do not modify it manually.
{
  fetchgit,
  fetchurl,
  fetchFromGitHub,
  dockerTools,
}: {
  everforest = {
    pname = "everforest";
    version = "87b8554b2872ef69018d4b13d288756dd4e47c0f";
    src = fetchFromGitHub {
      owner = "sainnhe";
      repo = "everforest";
      rev = "87b8554b2872ef69018d4b13d288756dd4e47c0f";
      fetchSubmodules = false;
      sha256 = "sha256-afe4oojyoNTGRPpykCsG0Sg5VOXno+tNNJlviOnrbQQ=";
    };
    date = "2024-09-30";
  };
}
