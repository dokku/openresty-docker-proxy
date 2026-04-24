-- Unit tests for allowed_ips module
-- Run with: resty -I /etc/nginx/lua /etc/nginx/lua/test_allowed_ips.lua

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

-- Mock state
local mock_exit_code = nil

-- Override ngx.exit to capture exit code instead of actually exiting
ngx.exit = function(code)
    mock_exit_code = code
    error("ngx.exit:" .. code)
end

-- Ensure ngx.var exists
if not ngx.var then
    ngx.var = {}
end

-- Reset mocks before each test
local function reset_mocks()
    mock_exit_code = nil
    ngx.var = {}
end

-- Load the module
package.loaded['allowed_ips'] = nil
local allowed_ips = require("allowed_ips")

-- IPv4 tests

test("Single IP: exact match returns true", function()
    reset_mocks()
    ngx.var.remote_addr = "192.168.1.100"
    assert_eq(true, allowed_ips.is_allowed("192.168.1.100"), "should match exact IP")
end)

test("Single IP: no match returns false", function()
    reset_mocks()
    ngx.var.remote_addr = "192.168.1.101"
    assert_eq(false, allowed_ips.is_allowed("192.168.1.100"), "should not match different IP")
end)

test("CIDR /24: match within range", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.0.42"
    assert_eq(true, allowed_ips.is_allowed("10.0.0.0/24"), "should match IP in /24 range")
end)

test("CIDR /24: no match outside range", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.1.1"
    assert_eq(false, allowed_ips.is_allowed("10.0.0.0/24"), "should not match IP outside /24 range")
end)

test("CIDR /8: match within large range", function()
    reset_mocks()
    ngx.var.remote_addr = "10.255.255.255"
    assert_eq(true, allowed_ips.is_allowed("10.0.0.0/8"), "should match IP in /8 range")
end)

test("CIDR /8: no match outside range", function()
    reset_mocks()
    ngx.var.remote_addr = "11.0.0.1"
    assert_eq(false, allowed_ips.is_allowed("10.0.0.0/8"), "should not match IP outside /8 range")
end)

test("CIDR /32: exact match only", function()
    reset_mocks()
    ngx.var.remote_addr = "192.168.1.1"
    assert_eq(true, allowed_ips.is_allowed("192.168.1.1/32"), "should match exact IP with /32")
end)

test("CIDR /32: no match for different IP", function()
    reset_mocks()
    ngx.var.remote_addr = "192.168.1.2"
    assert_eq(false, allowed_ips.is_allowed("192.168.1.1/32"), "should not match different IP with /32")
end)

test("CIDR /0: matches everything", function()
    reset_mocks()
    ngx.var.remote_addr = "123.45.67.89"
    assert_eq(true, allowed_ips.is_allowed("0.0.0.0/0"), "should match any IP with /0")
end)

test("Multiple entries: match on second entry", function()
    reset_mocks()
    ngx.var.remote_addr = "172.16.0.5"
    assert_eq(true, allowed_ips.is_allowed("10.0.0.0/8 172.16.0.0/12"), "should match second CIDR entry")
end)

test("Multiple entries: no match on any", function()
    reset_mocks()
    ngx.var.remote_addr = "8.8.8.8"
    assert_eq(false, allowed_ips.is_allowed("10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"), "should not match any entry")
end)

test("Mixed entries: plain IP and CIDR", function()
    reset_mocks()
    ngx.var.remote_addr = "1.2.3.4"
    assert_eq(true, allowed_ips.is_allowed("10.0.0.0/8 1.2.3.4"), "should match plain IP in mixed list")
end)

-- IPv6 client vs IPv4 entries (address family isolation)

test("IPv6 client does not match IPv4 entries", function()
    reset_mocks()
    ngx.var.remote_addr = "::1"
    assert_eq(false, allowed_ips.is_allowed("127.0.0.1"), "IPv6 address should not match IPv4 entries")
end)

test("IPv6 client does not match IPv4 CIDR /0", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:db8::1"
    assert_eq(false, allowed_ips.is_allowed("0.0.0.0/0"), "IPv6 address should not match even /0")
end)

-- IPv6 exact match tests

test("IPv6: exact match ::1 loopback", function()
    reset_mocks()
    ngx.var.remote_addr = "::1"
    assert_eq(true, allowed_ips.is_allowed("::1"), "should match IPv6 loopback")
end)

test("IPv6: exact match full form", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:0db8:0000:0000:0000:0000:0000:0001"
    assert_eq(true, allowed_ips.is_allowed("2001:db8::1"), "full form client should match compressed entry")
end)

test("IPv6: exact match compressed form", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:db8::1"
    assert_eq(true, allowed_ips.is_allowed("2001:0db8:0000:0000:0000:0000:0000:0001"), "compressed client should match full form entry")
end)

test("IPv6: no match different address", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:db8::1"
    assert_eq(false, allowed_ips.is_allowed("2001:db8::2"), "should not match different IPv6 address")
end)

test("IPv6: exact match all zeros ::", function()
    reset_mocks()
    ngx.var.remote_addr = "::"
    assert_eq(true, allowed_ips.is_allowed("::"), "should match all-zeros IPv6")
end)

test("IPv6: uppercase hex match", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:DB8::1"
    assert_eq(true, allowed_ips.is_allowed("2001:db8::1"), "should match uppercase hex")
end)

-- IPv6 CIDR tests

test("IPv6 CIDR /128: exact match only", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:db8::1"
    assert_eq(true, allowed_ips.is_allowed("2001:db8::1/128"), "should match exact with /128")
end)

test("IPv6 CIDR /128: no match", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:db8::2"
    assert_eq(false, allowed_ips.is_allowed("2001:db8::1/128"), "should not match different IP with /128")
end)

test("IPv6 CIDR /64: match within subnet", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:db8::ffff"
    assert_eq(true, allowed_ips.is_allowed("2001:db8::/64"), "should match IP in /64 subnet")
end)

test("IPv6 CIDR /64: no match outside subnet", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:db9::1"
    assert_eq(false, allowed_ips.is_allowed("2001:db8::/64"), "should not match IP outside /64 subnet")
end)

test("IPv6 CIDR /48: match within range", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:db8:0:1::1"
    assert_eq(true, allowed_ips.is_allowed("2001:db8::/48"), "should match IP in /48 range")
end)

test("IPv6 CIDR /32: match", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:db8:1:2:3:4:5:6"
    assert_eq(true, allowed_ips.is_allowed("2001:db8::/32"), "should match IP in /32 range")
end)

test("IPv6 CIDR /32: no match", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:db9::1"
    assert_eq(false, allowed_ips.is_allowed("2001:db8::/32"), "should not match IP outside /32 range")
end)

test("IPv6 CIDR /0: matches any IPv6", function()
    reset_mocks()
    ngx.var.remote_addr = "fe80::1"
    assert_eq(true, allowed_ips.is_allowed("::/0"), "should match any IPv6 with /0")
end)

test("IPv6 CIDR /0: does not match IPv4", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.0.1"
    assert_eq(false, allowed_ips.is_allowed("::/0"), "IPv6 /0 should not match IPv4 client")
end)

test("IPv6 CIDR /1: match upper half", function()
    reset_mocks()
    ngx.var.remote_addr = "8000::1"
    assert_eq(true, allowed_ips.is_allowed("8000::/1"), "should match in upper half of address space")
end)

test("IPv6 CIDR /1: no match lower half", function()
    reset_mocks()
    ngx.var.remote_addr = "7fff::1"
    assert_eq(false, allowed_ips.is_allowed("8000::/1"), "should not match lower half of address space")
end)

-- Mixed IPv4+IPv6 allow list tests

test("Mixed list: IPv4 client matches IPv4 entry", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.0.1"
    assert_eq(true, allowed_ips.is_allowed("2001:db8::/32 10.0.0.0/8 ::1"), "should match IPv4 in mixed list")
end)

test("Mixed list: IPv6 client matches IPv6 entry", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:db8::1"
    assert_eq(true, allowed_ips.is_allowed("10.0.0.0/8 2001:db8::/32 192.168.0.0/16"), "should match IPv6 in mixed list")
end)

test("Mixed list: IPv6 client no match (only IPv4 entries)", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:db8::1"
    assert_eq(false, allowed_ips.is_allowed("10.0.0.0/8 192.168.0.0/16"), "IPv6 client should not match IPv4-only list")
end)

test("Mixed list: IPv4 client no match (only IPv6 entries)", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.0.1"
    assert_eq(false, allowed_ips.is_allowed("2001:db8::/32 ::1"), "IPv4 client should not match IPv6-only list")
end)

test("Mixed list: IPv6 loopback in mixed list", function()
    reset_mocks()
    ngx.var.remote_addr = "::1"
    assert_eq(true, allowed_ips.is_allowed("127.0.0.1 ::1"), "should match IPv6 loopback in mixed list")
end)

-- Address family isolation

test("IPv4 client does not match IPv6 loopback", function()
    reset_mocks()
    ngx.var.remote_addr = "127.0.0.1"
    assert_eq(false, allowed_ips.is_allowed("::1"), "IPv4 loopback should not match IPv6 loopback")
end)

-- General edge cases

test("Missing remote_addr returns false", function()
    reset_mocks()
    ngx.var.remote_addr = nil
    assert_eq(false, allowed_ips.is_allowed("10.0.0.0/8"), "nil remote_addr should return false")
end)

test("Malformed entry is skipped, valid entry still matches", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.0.1"
    assert_eq(true, allowed_ips.is_allowed("not-an-ip 10.0.0.0/8"), "should skip malformed and match valid")
end)

test("Malformed entry only, no match", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.0.1"
    assert_eq(false, allowed_ips.is_allowed("not-an-ip bad/entry"), "all malformed should return false")
end)

test("Empty string returns false", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.0.1"
    assert_eq(false, allowed_ips.is_allowed(""), "empty string should return false")
end)

test("Invalid IPv4 prefix length /33 is handled by ipmatcher", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.0.1"
    -- ipmatcher accepts /33 for IPv4 without error
    assert_eq(true, allowed_ips.is_allowed("10.0.0.0/33"), "ipmatcher handles /33 for IPv4")
end)

test("Edge case: 255.255.255.255 exact match", function()
    reset_mocks()
    ngx.var.remote_addr = "255.255.255.255"
    assert_eq(true, allowed_ips.is_allowed("255.255.255.255"), "should match 255.255.255.255")
end)

test("Edge case: 0.0.0.0 exact match", function()
    reset_mocks()
    ngx.var.remote_addr = "0.0.0.0"
    assert_eq(true, allowed_ips.is_allowed("0.0.0.0"), "should match 0.0.0.0")
end)

test("Edge case: octet out of range is skipped", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.0.1"
    assert_eq(false, allowed_ips.is_allowed("256.0.0.0/8"), "octet > 255 should be skipped")
end)

-- IPv6 malformed entry tests

test("IPv6 malformed: invalid prefix > 128 is skipped", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:db8::1"
    assert_eq(false, allowed_ips.is_allowed("2001:db8::/129"), "prefix > 128 should be skipped")
end)

test("IPv6 malformed entry skipped, valid entry matches", function()
    reset_mocks()
    ngx.var.remote_addr = "2001:db8::1"
    assert_eq(true, allowed_ips.is_allowed("not-valid 2001:db8::/32"), "should skip malformed and match valid IPv6")
end)

-- check() function tests

test("check: does not exit when IP matches", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.0.1"
    allowed_ips.check("10.0.0.0/8")
    -- If we get here without error, check passed
end)

test("check: exits 403 when IP does not match", function()
    reset_mocks()
    ngx.var.remote_addr = "192.168.1.1"
    local ok, err = pcall(allowed_ips.check, "10.0.0.0/8")
    assert_eq(false, ok, "should have called ngx.exit")
    assert_eq(403, mock_exit_code, "should return 403")
end)

test("CIDR /16: match within range", function()
    reset_mocks()
    ngx.var.remote_addr = "192.168.50.1"
    assert_eq(true, allowed_ips.is_allowed("192.168.0.0/16"), "should match IP in /16 range")
end)

test("Loopback: 127.0.0.1 match", function()
    reset_mocks()
    ngx.var.remote_addr = "127.0.0.1"
    assert_eq(true, allowed_ips.is_allowed("127.0.0.1"), "should match loopback")
end)

-- ip_source: x-forwarded-for tests

test("x-forwarded-for: single IP match", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.0.1"
    ngx.var.http_x_forwarded_for = "192.168.1.100"
    assert_eq(true, allowed_ips.is_allowed("192.168.1.0/24", "x-forwarded-for"), "should match XFF IP")
end)

test("x-forwarded-for: uses first IP from comma-separated list", function()
    reset_mocks()
    ngx.var.http_x_forwarded_for = "192.168.1.100, 10.0.0.1, 172.16.0.1"
    assert_eq(true, allowed_ips.is_allowed("192.168.1.100", "x-forwarded-for"), "should match first IP in XFF")
end)

test("x-forwarded-for: trims whitespace from first IP", function()
    reset_mocks()
    ngx.var.http_x_forwarded_for = " 192.168.1.100 , 10.0.0.1"
    assert_eq(true, allowed_ips.is_allowed("192.168.1.100", "x-forwarded-for"), "should trim whitespace from XFF IP")
end)

test("x-forwarded-for: no match returns false", function()
    reset_mocks()
    ngx.var.http_x_forwarded_for = "8.8.8.8"
    assert_eq(false, allowed_ips.is_allowed("192.168.1.0/24", "x-forwarded-for"), "should not match non-allowed XFF IP")
end)

test("x-forwarded-for: missing header returns false", function()
    reset_mocks()
    ngx.var.http_x_forwarded_for = nil
    assert_eq(false, allowed_ips.is_allowed("0.0.0.0/0", "x-forwarded-for"), "should return false when XFF header missing")
end)

test("x-forwarded-for: ignores remote_addr", function()
    reset_mocks()
    ngx.var.remote_addr = "192.168.1.100"
    ngx.var.http_x_forwarded_for = "8.8.8.8"
    assert_eq(false, allowed_ips.is_allowed("192.168.1.100", "x-forwarded-for"), "should use XFF not remote_addr")
end)

-- ip_source: x-real-ip tests

test("x-real-ip: exact match", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.0.1"
    ngx.var.http_x_real_ip = "192.168.1.100"
    assert_eq(true, allowed_ips.is_allowed("192.168.1.100", "x-real-ip"), "should match X-Real-IP")
end)

test("x-real-ip: no match returns false", function()
    reset_mocks()
    ngx.var.http_x_real_ip = "8.8.8.8"
    assert_eq(false, allowed_ips.is_allowed("192.168.1.0/24", "x-real-ip"), "should not match non-allowed X-Real-IP")
end)

test("x-real-ip: missing header returns false", function()
    reset_mocks()
    ngx.var.http_x_real_ip = nil
    assert_eq(false, allowed_ips.is_allowed("0.0.0.0/0", "x-real-ip"), "should return false when X-Real-IP header missing")
end)

test("x-real-ip: ignores remote_addr", function()
    reset_mocks()
    ngx.var.remote_addr = "192.168.1.100"
    ngx.var.http_x_real_ip = "8.8.8.8"
    assert_eq(false, allowed_ips.is_allowed("192.168.1.100", "x-real-ip"), "should use X-Real-IP not remote_addr")
end)

-- ip_source: backward compatibility tests

test("nil ip_source uses remote_addr", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.0.1"
    assert_eq(true, allowed_ips.is_allowed("10.0.0.0/8", nil), "nil source should use remote_addr")
end)

test("explicit remote_addr ip_source uses remote_addr", function()
    reset_mocks()
    ngx.var.remote_addr = "10.0.0.1"
    assert_eq(true, allowed_ips.is_allowed("10.0.0.0/8", "remote_addr"), "remote_addr source should use remote_addr")
end)

-- ip_source: check() passthrough tests

test("check with x-forwarded-for: does not exit when XFF IP matches", function()
    reset_mocks()
    ngx.var.http_x_forwarded_for = "10.0.0.1"
    allowed_ips.check("10.0.0.0/8", "x-forwarded-for")
end)

test("check with x-forwarded-for: exits 403 when XFF IP does not match", function()
    reset_mocks()
    ngx.var.http_x_forwarded_for = "192.168.1.1"
    local ok, err = pcall(allowed_ips.check, "10.0.0.0/8", "x-forwarded-for")
    assert_eq(false, ok, "should have called ngx.exit")
    assert_eq(403, mock_exit_code, "should return 403")
end)

-- IPv6 with ip_source tests

test("x-forwarded-for: IPv6 single IP match", function()
    reset_mocks()
    ngx.var.http_x_forwarded_for = "2001:db8::1"
    assert_eq(true, allowed_ips.is_allowed("2001:db8::1", "x-forwarded-for"), "should match IPv6 XFF IP")
end)

test("x-forwarded-for: IPv6 from comma-separated list", function()
    reset_mocks()
    ngx.var.http_x_forwarded_for = "2001:db8::1, 10.0.0.1"
    assert_eq(true, allowed_ips.is_allowed("2001:db8::/32", "x-forwarded-for"), "should match first IPv6 in XFF list")
end)

test("x-real-ip: IPv6 match", function()
    reset_mocks()
    ngx.var.http_x_real_ip = "::1"
    assert_eq(true, allowed_ips.is_allowed("::1", "x-real-ip"), "should match IPv6 X-Real-IP")
end)

test("x-real-ip: IPv6 CIDR match", function()
    reset_mocks()
    ngx.var.http_x_real_ip = "fe80::1"
    assert_eq(true, allowed_ips.is_allowed("fe80::/10", "x-real-ip"), "should match IPv6 CIDR via X-Real-IP")
end)

-- check() with IPv6 tests

test("check: does not exit when IPv6 matches", function()
    reset_mocks()
    ngx.var.remote_addr = "::1"
    allowed_ips.check("::1")
end)

test("check: exits 403 when IPv6 does not match", function()
    reset_mocks()
    ngx.var.remote_addr = "::1"
    local ok, err = pcall(allowed_ips.check, "2001:db8::/32")
    assert_eq(false, ok, "should have called ngx.exit")
    assert_eq(403, mock_exit_code, "should return 403")
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
