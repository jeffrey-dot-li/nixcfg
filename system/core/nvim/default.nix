{
  inputs,
  pkgs,
  lib,
  ...
}: let
  nvfetcher = builtins.mapAttrs (
    name: value:
      pkgs.vimUtils.buildVimPlugin {
        inherit name;
        inherit (value) src;
      }
  ) (pkgs.callPackages ./_sources/generated.nix {});
  plugins = let
    vip = pkgs.vimPlugins;
    # We don't like `with` statements it is confusing
  in {
    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/editors/vim/plugins/vim-plugin-names
    everforest = {
      # Alternatively set plugins using nvfetcher - these are equivilant if you are importing the package from nvfetcher.
      # package = vip.everforest;
      #
      package = nvfetcher.everforest;
      setup = ''
        vim.opt.background = 'light'
        vim.g.everforest_background = 'soft'
        -- vim.g.everforest_better_performance = 1 Unfortunately this is broken because it tries to write to readonly plugin dir `/after/syntax/`.
        -- https://github.com/sainnhe/everforest/blob/87b8554b2872ef69018d4b13d288756dd4e47c0f/doc/everforest.txt#L495
        vim.cmd('colorscheme everforest')
      '';
    };

    alpha-nvim = {
      package = vip.alpha-nvim;
      setup = ''
        local alpha = require("alpha")
        local dashboard = require("alpha.themes.dashboard")
        dashboard.section.header.val = {
        [[⠀⠀⠀⠀⠀⠀⢀⡤⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡀⠀⠀⠀⠀⠀⠀]],
        [[⠀⠀⠀⠀⠀⢀⡏⠀⠀⠈⠳⣄⠀⠀⠀⠀⠀⣀⠴⠋⠉⠉⡆⠀⠀⠀⠀⠀]],
        [[⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠈⠉⠉⠙⠓⠚⠁⠀⠀⠀⠀⣿⠀⠀⠀⠀⠀]],
        [[⠀⠀⠀⠀⢀⠞⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⣄⠀⠀⠀⠀]],
        [[⠀⠀⠀⠀⡞⠀⠀⠀⠀⠀⠶⠀⠀⠀⠀⠀⠀⠦⠀⠀⠀⠀⠀⠸⡆⠀⠀⠀]],
        [[⢠⣤⣶⣾⣧⣤⣤⣀⡀⠀⠀⠀⠀⠈⠀⠀⠀⢀⡤⠴⠶⠤⢤⡀⣧⣀⣀⠀]],
        [[⠻⠶⣾⠁⠀⠀⠀⠀⠙⣆⠀⠀⠀⠀⠀⠀⣰⠋⠀⠀⠀⠀⠀⢹⣿⣭⣽⠇]],
        [[⠀⠀⠙⠤⠴⢤⡤⠤⠤⠋⠉⠉⠉⠉⠉⠉⠉⠳⠖⠦⠤⠶⠦⠞⠁⠀⠀ ]],
        }
        dashboard.section.header.opts.hl = "Keyword"
        dashboard.section.buttons.val = {
        dashboard.button("e", "  New file", ":ene <BAR> startinsert <CR>"),
        dashboard.button("nf", "  Note Files", ":NoteFiles <CR>"),
        dashboard.button("ng", "  Search Notes", ":NoteText <CR>"),
        dashboard.button("c", "  Calendar", ":Calendar <CR>"),
        dashboard.button("f", "  Find file", ":Telescope find_files <CR>"),
        dashboard.button("g", "󰺄  Live grep", ":Telescope live_grep <CR>"),
        dashboard.button("q", "󰅚  Quit NVIM", ":qa<CR>"),
        }

        dashboard.section.footer.val = "meoww :3"
        dashboard.section.footer.opts.hl = "Keyword"

        dashboard.config.opts.noautocmd = true

        vim.cmd([[autocmd User AlphaReady set showtabline=0 | autocmd BufUnload <buffer> set showtabline=2]])

        alpha.setup(dashboard.config)
      '';
    };
  };
  customRC = "vim.cmd('source ${./init.vim}')" + builtins.readFile ./init.lua;
in {
  imports = [inputs.nvf.nixosModules.default];

  programs.nvf = {
    enable = true;

    settings.vim = {
      luaConfigRC.custom = customRC;
      extraPlugins = plugins;
      # package = inputs.neovim-overlay.packages.${pkgs.system}.neovim;
      viAlias = false;
      vimAlias = true;
      enableLuaLoader = true;
      preventJunkFiles = true;
      tabWidth = 4;
      autoIndent = true;
      cmdHeight = 1;
      useSystemClipboard = true;
      mouseSupport = "a";
      scrollOffset = 6;

      telescope.enable = true;

      autopairs.enable = true;

      notes = {
        todo-comments.enable = true;
      };

      utility = {
        surround.enable = true;
      };

      theme = {
        enable = false;
      };

      maps = {
        normal = {
          "<leader>t" = {
            action = "<CMD>Telescope find_files<CR>";
          };      
          "<leader>p" = {
            action = "<CMD>Telescope commands<CR>";
          };  
          "<leader>f" = {
            action = "<CMD>Telescope live_grep<CR>";
          };

          "<leader>v" = {
            action = "<CMD>Neotree toggle<CR>";
            silent = true;
          };
          "<leader>m" = {
            action = "<CMD>MarkdownPreviewToggle<CR>";
            silent = true;
          };
        };

        terminal = {
          # get out of terminal mode in toggleterm
          "<ESC>" = {
            action = "<C-\\><C-n>";
            silent = true;
          };
        };
      };

      filetree.neo-tree = {
        enable = true;
      };

      statusline.lualine = {
        enable = true;
        theme = "auto";
      };

      treesitter = {
        enable = true;
        fold = true;
        context.enable = true;
        highlight.enable = true;
        indent.enable = true;
        addDefaultGrammars = false; # cuz its broken rn
      };

      autocomplete = {
        enable = true;
        alwaysComplete = false;
      };

      ui = {
        noice.enable = true;
      };

      visuals = {
        enable = true;
        indentBlankline = {
          enable = true;
          #          eolChar = null;
          #fillChar = null;
        };
        highlight-undo.enable = true;
      };

      notify = {
        nvim-notify.enable = true;
      };

      terminal.toggleterm = {
        enable = true;
        setupOpts.direction = "tab";
        mappings.open = "<C-\\>";
      };

      git = {
        enable = true;
        gitsigns = {
          enable = true;
        };
      };

      lsp = {
        enable = true;
        lspSignature.enable = true;
        lspconfig.enable = true;
        lsplines.enable = true;
        mappings = {
          addWorkspaceFolder = "<leader>wa";
          codeAction = "<leader>a";
          format = "<C-f>";
          goToDeclaration = "gD";
          goToDefinition = "gd";
          hover = "K";
          listImplementations = "gi";
          listReferences = "gr";
          listWorkspaceFolders = "<leader>wl";
          nextDiagnostic = "<leader>k";
          previousDiagnostic = "<leader>j";
          openDiagnosticFloat = "<leader>e";
          removeWorkspaceFolder = "<leader>wr";
          renameSymbol = "<leader>r";
          signatureHelp = "<C-k>";
        };
      };

      languages = {
        enableDAP = true;
        enableExtraDiagnostics = true;
        enableFormat = true;
        enableLSP = true;
        enableTreesitter = true;
        bash.enable = true;
        clang = {
          enable = true;
          cHeader = true;
        };
        markdown.enable = true;
        nix = {
          enable = true;
        };
        rust = {
          enable = true;
          crates.enable = true;
        };
      };
    };
  };
}
