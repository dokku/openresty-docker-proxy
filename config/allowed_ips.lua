local _M = {}

local bit = require("bit")

-- parse_ipv4 converts a dotted-decimal IPv4 string to a 32-bit number.
-- Returns nil if the string is not a valid IPv4 address.
local function parse_ipv4(ip_str)
    local o1, o2, o3, o4 = ip_str:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not o1 then
        return nil
    end

    o1, o2, o3, o4 = tonumber(o1), tonumber(o2), tonumber(o3), tonumber(o4)
    if o1 > 255 or o2 > 255 or o3 > 255 or o4 > 255 then
        return nil
    end

    return bit.tobit(o1 * 16777216 + o2 * 65536 + o3 * 256 + o4)
end

-- cidr_mask builds a 32-bit subnet mask for a given prefix length (0-32).
local function cidr_mask(prefix_len)
    if prefix_len == 0 then
        return bit.tobit(0)
    end

    return bit.lshift(-1, 32 - prefix_len)
end

-- is_allowed checks whether ngx.var.remote_addr matches any entry
-- in the space-separated allowed_ips_str. Each entry is either a
-- plain IPv4 address (treated as /32) or a CIDR like 10.0.0.0/8.
-- Returns true if the IP matches any entry, false otherwise.
function _M.is_allowed(allowed_ips_str)
    local remote_addr = ngx.var.remote_addr
    if not remote_addr then
        return false
    end

    local client_ip = parse_ipv4(remote_addr)
    if not client_ip then
        return false
    end

    for entry in allowed_ips_str:gmatch("%S+") do
        local ip_part, prefix_str = entry:match("^(.+)/(%d+)$")
        if not ip_part then
            ip_part = entry
            prefix_str = "32"
        end

        local net_ip = parse_ipv4(ip_part)
        local prefix_len = tonumber(prefix_str)
        if net_ip and prefix_len and prefix_len >= 0 and prefix_len <= 32 then
            local mask = cidr_mask(prefix_len)
            if bit.band(client_ip, mask) == bit.band(net_ip, mask) then
                return true
            end
        end
    end

    return false
end

-- check denies the request with 403 Forbidden if the client IP
-- does not match any entry in allowed_ips_str.
function _M.check(allowed_ips_str)
    if not _M.is_allowed(allowed_ips_str) then
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end
end

return _M
