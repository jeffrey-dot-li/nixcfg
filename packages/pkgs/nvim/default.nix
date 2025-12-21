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
    cmp-cmdline = {
      package = vip.cmp-cmdline;
      setup = ''
        local cmp = require("cmp")

        -- Enable completion for ':' (cmdline)
        cmp.setup.cmdline(':', {
          mapping = cmp.mapping.preset.cmdline(),
          sources = cmp.config.sources({
            { name = 'path' }    -- Hints for file paths
          }, {
            { name = 'cmdline' } -- Hints for commands (e.g., :wq, :noh)
          })
        })
        cmp.setup.cmdline('/', {
          mapping = cmp.mapping.preset.cmdline(),
          sources = {
            { name = 'buffer' } -- Hints words from the current file
          }
        })
      '';
    };
    auto-session = {
      package = vip.auto-session;
      setup = ''
        require("auto-session").setup({})
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
        scrolloff = 6;
        autoindent = true;
      };

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
          # Can bind something to this if it makes sense
          # "<leader>\\" = {
          #   action = "<CMD>Telescope find_files<CR>";
          # };
          "<leader>fp" = {
            action = "<CMD>Telescope buffers<CR>";
          };
          "<leader>fo" = {
            action = "<CMD>Telescope current_buffer_fuzzy_find<CR>";
          };
          # "<leader>f" = {
          #   action = "<CMD>Telescope live_grep<CR>";
          # };

          "<leader>tt" = {
            action = "<CMD>ToggleTerm<CR>";
            desc = "Toggle terminal";
          };
          "<leader>t1" = {
            action = "<CMD>ToggleTermSingle 1<CR>";
            desc = "Toggle terminal";
          };
          "<leader>t2" = {
            action = "<CMD>ToggleTermSingle 2<CR>";
            desc = "Toggle terminal";
          };
          "<leader>t3" = {
            action = "<CMD>ToggleTermSingle 3<CR>";
            desc = "Toggle terminal";
          };
          "<leader>t4" = {
            action = "<CMD>ToggleTermSingle 4<CR>";
            desc = "Toggle terminal";
          };

          "<leader>v" = {
            action = "<CMD>Neotree toggle<CR>";
            silent = true;
          };
          # TODO: Override leader k /j which are go to prev / next diagnostic
          # TODO: Figure out how to open hover / peek def

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
          "<leader>y" = {
            action = "<cmd>SwapRegisters<cr>";
            desc = "Swap \" and + registers";
          };

          # Apparent sometimes Ctrl + / is sent as Ctrl + _ (apparently ascii is pretty troll)
          # To test, go to insert mode, then do Ctrl + V then Ctrl + / (or whatever character)
          # And it will print the control character it receives
          "<C-/>" = {
            action = "<cmd>nohlsearch<cr>";
            desc = "Clear search highlight";
          };
        };
        # Command line mode
        command = {
          "<M-Left>" = {
            action = "<S-Left>";
            desc = "Move back a word";
          };
          "<M-Right>" = {
            action = "<S-Right>";
            desc = "Move forward a word";
          };
          "<M-BS>" = {
            action = "<C-w>";
            desc = "Delete a word";
          };
        };

        terminal = {
          # <C-\\> toggles terminal in nvim
          # get out of terminal mode in toggleterm
          "<leader>ys" = {
            action = "<cmd>SwapRegisters<cr>";
            desc = "Swap \" and + registers";
          };
          "<leader>tt" = {
            action = "<CMD>ToggleTerm<CR>";
            desc = "Toggle terminal";
          };
          "<leader>t1" = {
            action = "<CMD>ToggleTermSingle 1<CR>";
            desc = "Toggle terminal";
          };
          "<leader>t2" = {
            action = "<CMD>ToggleTermSingle 2<CR>";
            desc = "Toggle terminal";
          };
          "<leader>t3" = {
            action = "<CMD>ToggleTermSingle 3<CR>";
            desc = "Toggle terminal";
          };
          "<leader>t4" = {
            action = "<CMD>ToggleTermSingle 4<CR>";
            desc = "Toggle terminal";
          };
          "<C-Esc>" = {
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

      autocomplete = {
        nvim-cmp = {
          enable = true;
          # https://github.com/NotAShelf/nvf/blob/4b95ae106c832bea347ad2bd53f2c40d880f0d27/modules/plugins/completion/nvim-cmp/nvim-cmp.nix#L64
          # mappings = {};
        };
        blink-cmp = {
          # enable = true;
        };
      };

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
        setupOpts = {
          direction = "horizontal";
          winbar.enabled = true;
          enable_winbar = true;
        };
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
          extensions.crates-nvim.enable = true;
        };
      };
    };
  };
  customNeovim = inputs.nvf.lib.neovimConfiguration {
    modules = [nvfConfig];
    inherit pkgs;
  };
in (customNeovim.neovim)
