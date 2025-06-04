{ pkgs, ... }:

{
  # https://devenv.sh/packages/
  packages = with pkgs; [
    zola
  ];

  # https://devenv.sh/git-hooks/
  git-hooks.hooks = {
    # shellcheck.enable = true;

    # TODO: 
    # eslint
    # vale

    # typos.enable = true;
    taplo.enable = true;
    # prettier = {
    #   enable = true;
    #   settings.parser = "scss";
    # };
  };

  # See full reference at https://devenv.sh/reference/options/
}
