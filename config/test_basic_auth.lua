-- Unit tests for basic_auth module
-- Run with: resty -I /etc/nginx/lua /etc/nginx/lua/test_basic_auth.lua

local test_count = 0
local pass_count = 0

local function test(name, fn)
    test_count = test_count + 1
    local ok, err = pcall(fn)
    if ok then
        pass_count = pass_count + 1
        print("PASS: " .. name)
    else
        print("FAIL: " .. name .. " - " .. tostring(err))
    end
end

local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error((msg or "") .. " expected: " .. tostring(expected) .. ", got: " .. tostring(actual))
    end
end

-- Save real ngx functions
local real_exit = ngx.exit
local real_encode_base64 = ngx.encode_base64
local real_decode_base64 = ngx.decode_base64
local real_sha1_bin = ngx.sha1_bin

-- Mock state
local mock_exit_code = nil
local mock_headers = {}

-- Override ngx.exit to capture exit code instead of actually exiting
ngx.exit = function(code)
    mock_exit_code = code
    error("ngx.exit:" .. code)
end

-- Override ngx.header to capture headers
ngx.header = setmetatable({}, {
    __newindex = function(_, k, v)
        mock_headers[k] = v
    end,
    __index = function(_, k)
        return mock_headers[k]
    end,
})

-- Ensure ngx.var exists
if not ngx.var then
    ngx.var = {}
end

-- Reset mocks before each test
local function reset_mocks()
    mock_exit_code = nil
    mock_headers = {}
    ngx.var = {}
    ngx.header = setmetatable({}, {
        __newindex = function(_, k, v)
            mock_headers[k] = v
        end,
        __index = function(_, k)
            return mock_headers[k]
        end,
    })
end

-- Helper: encode credentials to Basic auth header value
local function basic_auth_header(user, pass)
    return "Basic " .. ngx.encode_base64(user .. ":" .. pass)
end

-- Load the module
package.loaded['basic_auth'] = nil
local basic_auth = require("basic_auth")

-- SHA-1 of "password" = W6ph5Mm5Pz8GgiULbPgzG37mj9g=
local sha_password = "{SHA}" .. ngx.encode_base64(ngx.sha1_bin("password"))

-- Tests

test("SHA-1: valid credentials pass", function()
    reset_mocks()
    ngx.var.http_authorization = basic_auth_header("testuser", "password")
    basic_auth.check("testuser:" .. sha_password)
    -- If we get here without error, auth passed
end)

test("SHA-1: wrong password returns 401", function()
    reset_mocks()
    ngx.var.http_authorization = basic_auth_header("testuser", "wrongpass")
    local ok, err = pcall(basic_auth.check, "testuser:" .. sha_password)
    assert_eq(false, ok, "should have called ngx.exit")
    assert_eq(401, mock_exit_code, "should return 401")
    assert_eq('Basic realm="Restricted"', mock_headers["WWW-Authenticate"], "should set WWW-Authenticate")
end)

test("Plain text: valid credentials pass", function()
    reset_mocks()
    ngx.var.http_authorization = basic_auth_header("admin", "secret123")
    basic_auth.check("admin:secret123")
end)

test("Plain text: wrong password returns 401", function()
    reset_mocks()
    ngx.var.http_authorization = basic_auth_header("admin", "wrong")
    local ok, err = pcall(basic_auth.check, "admin:secret123")
    assert_eq(false, ok, "should have called ngx.exit")
    assert_eq(401, mock_exit_code, "should return 401")
end)

test("Missing Authorization header returns 401", function()
    reset_mocks()
    ngx.var.http_authorization = nil
    local ok, err = pcall(basic_auth.check, "testuser:" .. sha_password)
    assert_eq(false, ok, "should have called ngx.exit")
    assert_eq(401, mock_exit_code, "should return 401")
    assert_eq('Basic realm="Restricted"', mock_headers["WWW-Authenticate"], "should set WWW-Authenticate")
end)

test("Non-Basic Authorization header returns 401", function()
    reset_mocks()
    ngx.var.http_authorization = "Bearer some-token"
    local ok, err = pcall(basic_auth.check, "testuser:" .. sha_password)
    assert_eq(false, ok, "should have called ngx.exit")
    assert_eq(401, mock_exit_code, "should return 401")
end)

test("Invalid Base64 in Authorization header returns 401", function()
    reset_mocks()
    ngx.var.http_authorization = "Basic !!!invalid!!!"
    local ok, err = pcall(basic_auth.check, "testuser:" .. sha_password)
    assert_eq(false, ok, "should have called ngx.exit")
    assert_eq(401, mock_exit_code, "should return 401")
end)

test("Unknown user returns 401", function()
    reset_mocks()
    ngx.var.http_authorization = basic_auth_header("unknown", "password")
    local ok, err = pcall(basic_auth.check, "testuser:" .. sha_password)
    assert_eq(false, ok, "should have called ngx.exit")
    assert_eq(401, mock_exit_code, "should return 401")
end)

test("Multiple users: first user authenticates", function()
    reset_mocks()
    local sha_secret = "{SHA}" .. ngx.encode_base64(ngx.sha1_bin("secret"))
    ngx.var.http_authorization = basic_auth_header("user1", "password")
    basic_auth.check("user1:" .. sha_password .. " user2:" .. sha_secret)
end)

test("Multiple users: second user authenticates", function()
    reset_mocks()
    local sha_secret = "{SHA}" .. ngx.encode_base64(ngx.sha1_bin("secret"))
    ngx.var.http_authorization = basic_auth_header("user2", "secret")
    basic_auth.check("user1:" .. sha_password .. " user2:" .. sha_secret)
end)

test("Multiple users: wrong password for matched user returns 401", function()
    reset_mocks()
    local sha_secret = "{SHA}" .. ngx.encode_base64(ngx.sha1_bin("secret"))
    ngx.var.http_authorization = basic_auth_header("user1", "wrong")
    local ok, err = pcall(basic_auth.check, "user1:" .. sha_password .. " user2:" .. sha_secret)
    assert_eq(false, ok, "should have called ngx.exit")
    assert_eq(401, mock_exit_code, "should return 401")
end)

test("Empty auth string returns 401", function()
    reset_mocks()
    ngx.var.http_authorization = basic_auth_header("testuser", "password")
    local ok, err = pcall(basic_auth.check, "")
    assert_eq(false, ok, "should have called ngx.exit")
    assert_eq(401, mock_exit_code, "should return 401")
end)

test("Malformed entry (no colon) is skipped, returns 401", function()
    reset_mocks()
    ngx.var.http_authorization = basic_auth_header("testuser", "password")
    local ok, err = pcall(basic_auth.check, "malformed-entry")
    assert_eq(false, ok, "should have called ngx.exit")
    assert_eq(401, mock_exit_code, "should return 401")
end)

test("Credentials without password part returns 401", function()
    reset_mocks()
    ngx.var.http_authorization = "Basic " .. ngx.encode_base64("useronly")
    local ok, err = pcall(basic_auth.check, "testuser:" .. sha_password)
    assert_eq(false, ok, "should have called ngx.exit")
    assert_eq(401, mock_exit_code, "should return 401")
end)

-- Summary
print("")
print(string.format("Results: %d/%d tests passed", pass_count, test_count))
if pass_count ~= test_count then
    print("FAILED")
    os.exit(1)
else
    print("OK")
end
