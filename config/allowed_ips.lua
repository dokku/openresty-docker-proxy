local _M = {}

local ipmatcher = require("resty.ipmatcher")

-- is_allowed checks whether the client IP matches any entry
-- in the space-separated allowed_ips_str. Each entry is either a
-- plain IPv4 address (treated as /32), a CIDR like 10.0.0.0/8,
-- a plain IPv6 address (treated as /128), or an IPv6 CIDR like 2001:db8::/32.
-- IPv4 entries are only matched against IPv4 clients, and IPv6
-- entries are only matched against IPv6 clients.
-- ip_source selects where the client IP comes from:
--   nil/""/remote_addr  -> ngx.var.remote_addr (default)
--   "x-forwarded-for"   -> first IP in X-Forwarded-For header
--   "x-real-ip"         -> X-Real-IP header
-- Returns true if the IP matches any entry, false otherwise.
function _M.is_allowed(allowed_ips_str, ip_source)
    local remote_addr
    if ip_source == "x-forwarded-for" then
        local xff = ngx.var.http_x_forwarded_for
        if xff then
            remote_addr = xff:match("^%s*([^,]+)")
            if remote_addr then
                remote_addr = remote_addr:match("^%s*(.-)%s*$")
            end
        end
    elseif ip_source == "x-real-ip" then
        remote_addr = ngx.var.http_x_real_ip
    else
        remote_addr = ngx.var.remote_addr
    end

    if not remote_addr then
        return false
    end

    local ip_list = {}
    for entry in allowed_ips_str:gmatch("%S+") do
        ip_list[#ip_list + 1] = entry
    end

    if #ip_list == 0 then
        return false
    end

    -- Fast path: try all entries at once
    local matcher = ipmatcher.new(ip_list)
    if matcher then
        local ok = matcher:match(remote_addr)
        return ok == true
    end

    -- Fallback: malformed entry detected, try individually (skip bad ones)
    for _, entry in ipairs(ip_list) do
        matcher = ipmatcher.new({entry})
        if matcher then
            local ok = matcher:match(remote_addr)
            if ok then
                return true
            end
        end
    end

    return false
end

-- check denies the request with 403 Forbidden if the client IP
-- does not match any entry in allowed_ips_str.
function _M.check(allowed_ips_str, ip_source)
    if not _M.is_allowed(allowed_ips_str, ip_source) then
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end
end

return _M
