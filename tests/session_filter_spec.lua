local Session = require("sidekick.cli.session")
local Config = require("sidekick.config")

describe("session external filtering", function()
  local original_backends
  local original_did_setup

  before_each(function()
    -- Save original state
    original_backends = Session.backends
    original_did_setup = Session.did_setup

    -- Reset session state and prevent auto-setup
    Session._attached = {}
    Session.backends = {}
    Session.did_setup = true -- prevent setup() from auto-registering backends
  end)

  after_each(function()
    -- Restore original state
    Session._attached = {}
    Session.backends = original_backends
    Session.did_setup = original_did_setup
  end)

  describe("Session.sessions()", function()
    it("includes external sessions when mux.enabled = true", function()
      Config.cli.mux.enabled = true

      -- Register a mock backend that returns an external session
      Session.backends.mock_backend = {
        sessions = function()
          return { { id = "ext1", tool = "test", cwd = "/tmp" } }
        end,
        init = function(self)
          self.external = true -- mark session as external
        end,
      }

      local sessions = Session.sessions()
      assert.are.equal(1, #sessions)
      assert.are.equal("ext1", sessions[1].id)
    end)

    it("filters external sessions when mux.enabled = false", function()
      Config.cli.mux.enabled = false

      -- Register a mock backend that returns an external session
      Session.backends.mock_backend = {
        sessions = function()
          return { { id = "ext1", tool = "test", cwd = "/tmp" } }
        end,
        init = function(self)
          self.external = true -- mark session as external
        end,
      }

      local sessions = Session.sessions()
      assert.are.equal(0, #sessions)
    end)

    it("includes non-external sessions regardless of mux.enabled", function()
      Config.cli.mux.enabled = false

      -- Register a mock backend that returns a non-external session
      Session.backends.mock_backend = {
        sessions = function()
          return { { id = "local1", tool = "test", cwd = "/tmp" } }
        end,
        init = function(self)
          self.external = false -- mark session as non-external
        end,
      }

      local sessions = Session.sessions()
      assert.are.equal(1, #sessions)
      assert.are.equal("local1", sessions[1].id)
    end)

    it("includes sessions with nil external flag regardless of mux.enabled", function()
      Config.cli.mux.enabled = false

      -- Register a mock backend that returns a session without external flag
      Session.backends.mock_backend = {
        sessions = function()
          return { { id = "local1", tool = "test", cwd = "/tmp" } }
        end,
        init = function(self)
          -- don't set external, it defaults to nil
        end,
      }

      local sessions = Session.sessions()
      assert.are.equal(1, #sessions)
      assert.are.equal("local1", sessions[1].id)
    end)
  end)
end)
