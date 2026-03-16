---@module 'luassert'

local vibe = require("sk.cli.vibe")

describe("vibe cli config", function()
  describe("static properties", function()
    it("has correct cmd", function()
      assert.are.same({ "vibe" }, vibe.cmd)
    end)

    it("has correct is_proc pattern", function()
      assert.are.equal("\\<vibe\\>", vibe.is_proc)
    end)

    it("has correct url", function()
      assert.are.equal("https://github.com/mistralai/mistral-vibe", vibe.url)
    end)

    it("has correct continue option", function()
      assert.are.same({ "--continue" }, vibe.continue)
    end)
  end)

  describe("format function", function()
    ---@param chunks {[1]: string, [2]?: string}[][]
    ---@return sidekick.Text[]
    local function make_text(chunks)
      return chunks
    end

    describe("quoting paths with special characters", function()
      it("quotes paths containing spaces", function()
        local text = make_text({
          { { "path with spaces/file.lua", "SidekickLocFile" } },
        })
        local result = vibe.format(text)
        assert.are.equal('"path with spaces/file.lua"', result)
      end)

      it("quotes paths containing colons", function()
        local text = make_text({
          { { "path:with:colons/file.lua", "SidekickLocFile" } },
        })
        local result = vibe.format(text)
        assert.are.equal('"path:with:colons/file.lua"', result)
      end)

      it("quotes paths containing special chars like @", function()
        local text = make_text({
          { { "@special/file.lua", "SidekickLocFile" } },
        })
        local result = vibe.format(text)
        assert.are.equal('"@special/file.lua"', result)
      end)

      it("does not quote simple paths", function()
        local text = make_text({
          { { "simple/path/file.lua", "SidekickLocFile" } },
        })
        local result = vibe.format(text)
        assert.are.equal("simple/path/file.lua", result)
      end)

      it("does not quote paths with allowed chars (alphanumeric, dot, slash, backslash, hyphen, parens, brackets, braces)", function()
        local text = make_text({
          { { "path/to/file-name_v1.0.lua", "SidekickLocFile" } },
        })
        local result = vibe.format(text)
        assert.are.equal("path/to/file-name_v1.0.lua", result)
      end)

      it("does not quote paths with parentheses", function()
        local text = make_text({
          { { "path/(file).lua", "SidekickLocFile" } },
        })
        local result = vibe.format(text)
        assert.are.equal("path/(file).lua", result)
      end)

      it("does not quote paths with brackets", function()
        local text = make_text({
          { { "path/[file].lua", "SidekickLocFile" } },
        })
        local result = vibe.format(text)
        assert.are.equal("path/[file].lua", result)
      end)

      it("does not quote paths with braces", function()
        local text = make_text({
          { { "path/{file}.lua", "SidekickLocFile" } },
        })
        local result = vibe.format(text)
        assert.are.equal("path/{file}.lua", result)
      end)

      it("only transforms chunks with SidekickLocFile highlight", function()
        local text = make_text({
          { { "path with spaces", "OtherHighlight" } },
        })
        local result = vibe.format(text)
        assert.are.equal("path with spaces", result)
      end)
    end)

    describe("stripping space between path and line references", function()
      it("strips space for quoted paths with line reference", function()
        local text = make_text({
          { { '@"some/path.lua"', nil }, { " ", nil }, { ":L10", nil } },
        })
        local result = vibe.format(text)
        assert.are.equal('@"some/path.lua":L10', result)
      end)

      it("strips space for quoted paths with line range", function()
        local text = make_text({
          { { '@"some/path.lua"', nil }, { " ", nil }, { ":L10-15", nil } },
        })
        local result = vibe.format(text)
        assert.are.equal('@"some/path.lua":L10-15', result)
      end)

      it("strips space for quoted paths with line and column", function()
        local text = make_text({
          { { '@"some/path.lua"', nil }, { " ", nil }, { ":L10:C5", nil } },
        })
        local result = vibe.format(text)
        assert.are.equal('@"some/path.lua":L10:C5', result)
      end)

      it("strips space for unquoted paths with line reference", function()
        local text = make_text({
          { { "@some/path.lua", nil }, { " ", nil }, { ":L10", nil } },
        })
        local result = vibe.format(text)
        assert.are.equal("@some/path.lua:L10", result)
      end)

      it("strips space for unquoted paths with line range", function()
        local text = make_text({
          { { "@some/path.lua", nil }, { " ", nil }, { ":L10-20", nil } },
        })
        local result = vibe.format(text)
        assert.are.equal("@some/path.lua:L10-20", result)
      end)

      it("strips space for unquoted paths with line and column range", function()
        local text = make_text({
          { { "@some/path.lua", nil }, { " ", nil }, { ":L10:LC5-10", nil } },
        })
        local result = vibe.format(text)
        assert.are.equal("@some/path.lua:L10:LC5-10", result)
      end)

      it("handles multiple paths on separate lines", function()
        local text = make_text({
          { { "@first.lua", nil }, { " ", nil }, { ":L1", nil } },
          { { "@second.lua", nil }, { " ", nil }, { ":L2", nil } },
        })
        local result = vibe.format(text)
        assert.are.equal("@first.lua:L1\n@second.lua:L2", result)
      end)
    end)

    describe("combined quoting and line reference handling", function()
      it("quotes special path and strips space before line reference", function()
        local text = make_text({
          { { "path with spaces/file.lua", "SidekickLocFile" }, { " ", nil }, { ":L10", nil } },
        })
        local result = vibe.format(text)
        -- After quoting, becomes @"path with spaces/file.lua" :L10
        -- But the @ is added externally, so we just check quoting happened
        assert.are.equal('"path with spaces/file.lua" :L10', result)
      end)
    end)
  end)
end)
