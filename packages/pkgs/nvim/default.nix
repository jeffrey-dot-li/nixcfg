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
  nvim-osc52 = pkgs.vimUtils.buildVimPlugin {
    name = "nvim-osc52";
    src = inputs.nvim-osc52;
  };
  plugins = let
    vip = pkgs.vimPlugins;
    # This can also be done with `with pkgs.vimPlugins; { ... }`
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
    nvim-osc52 = {
      package = nvim-osc52;
      setup = ''
        vim.g.clipboard = {
        name = "OSC 52",
        copy = {
        ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
        ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
        },
        paste = {
        ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
        ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
        },
        }
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
  nvfConfig = {
    config.vim = {
      luaConfigRC.custom = customRC;
      extraPlugins = plugins;
      # package = inputs.neovim-overlay.packages.${pkgs.system}.neovim;
      viAlias = false;
      vimAlias = true;
      enableLuaLoader = true;
      preventJunkFiles = true;
      # tabWidth = 4;
      clipboard = {
        # enable = true;
        # Use system register for clipboard
        # registers = "unnamedplus";
        # Don't use this, instead, to copy in vim, use "+y
      };
      options = {
        mouse = "a";
        cmdheight = 1;
        autoindent = true;
      };

      scrollOffset = 6;

      telescope = {
        enable = true;
        setupOpts.defaults.file_ignore_patterns = [
          "node_modules"
          ".git/"
          "dist/"
          "build/"
          "target/"
          "result/"
          "_sources/"
          "*.lock"
        ];
      };
      autopairs.nvim-autopairs.enable = true;

      notes = {
        todo-comments.enable = true;
      };

      utility = {
        surround.enable = true;
        ccc.enable = false;
        vim-wakatime.enable = false;
        diffview-nvim.enable = true;
        yanky-nvim.enable = false;
        # multicursors.enable=true;

        motion = {
          hop.enable = true;
          leap.enable = true;
          precognition.enable = true;
        };
      };

      theme = {
        enable = false;
      };

      globals.mapleader = " ";
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
          # "<leader>m" = {
          #   action = "<CMD>MarkdownPreviewToggle<CR>";
          #   silent = true;
          # };

          # Navigation override
          "<C-u>" = {
            action = "<C-u>zz";
            desc = "Half page up + recenter";
          };
          "<C-d>" = {
            action = "<C-d>zz";
            desc = "Half page down + recenter";
          };
          "<C-f>" = {
            action = "<C-f>zz";
            desc = "Full page up + recenter";
          };
          "<C-b>" = {
            action = "<C-b>zz";
            desc = "Full page down + recenter";
          };

          # Swap registers
          "<leader>ys" = {
            action = "<cmd>SwapRegisters<cr>";
            desc = "Swap \" and + registers";
          };
        };

        terminal = {
          # <C-\\> toggles terminal in nvim
          # get out of terminal mode in toggleterm
          "<leader>ys" = {
            action = "<cmd>SwapRegisters<cr>";
            desc = "Swap \" and + registers";
          };
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
      minimap = {
        minimap-vim.enable = false;
        codewindow.enable = true; # lighter, faster, and uses lua for configuration
      };

      treesitter = {
        enable = true;
        fold = true;
        context.enable = true;
        highlight.enable = true;
        indent.enable = true;
        addDefaultGrammars = false; # cuz its broken rn
      };

      autocomplete.nvim-cmp.enable = true;

      ui = {
        noice.enable = true;
      };

      # visuals = {
      #   enable = true;
      #   indentBlankline = {
      #     enable = true;
      #     #          eolChar = null;
      #     #fillChar = null;
      #   };
      #   highlight-undo.enable = true;
      # };

      notify = {
        nvim-notify.enable = true;
      };

      terminal.toggleterm = {
        enable = true;
        setupOpts.direction = "horizontal";
        mappings.open = "<C-\\>";
        lazygit = {
          enable = true;
        };
      };

      git = {
        enable = true;
        gitsigns = {
          enable = true;
        };
      };
      tabline = {
        nvimBufferline.enable = true;
      };
      binds = {
        whichKey.enable = true;
        cheatsheet.enable = true;
      };

      lsp = {
        enable = true;
        formatOnSave = true;
        lightbulb.enable = true;
        lspSignature.enable = true;
        lspconfig.enable = true;
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
  customNeovim = inputs.nvf.lib.neovimConfiguration {
    modules = [nvfConfig];
    inherit pkgs;
  };
in (customNeovim.neovim)
