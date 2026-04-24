local _M = {}

local bit = require("bit")

-- constant_time_compare compares two strings in constant time
-- to prevent timing attacks from leaking hash prefix information
local function constant_time_compare(a, b)
    if #a ~= #b then
        return false
    end

    local result = 0
    for i = 1, #a do
        result = bit.bor(result, bit.bxor(string.byte(a, i), string.byte(b, i)))
    end

    return result == 0
end

-- check verifies HTTP Basic Authentication credentials against
-- a space-separated string of user:password_hash entries.
--
-- Supported password hash formats:
--   {SHA}base64hash - SHA-1 hash encoded in base64
--   plaintext       - plain text password (not recommended)
function _M.check(auth_entries_str)
    local header = ngx.var.http_authorization
    if not header then
        ngx.header["WWW-Authenticate"] = 'Basic realm="Restricted"'
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
        return
    end

    local encoded = header:match("^Basic%s+(.+)$")
    if not encoded then
        ngx.header["WWW-Authenticate"] = 'Basic realm="Restricted"'
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
        return
    end

    local decoded = ngx.decode_base64(encoded)
    if not decoded then
        ngx.header["WWW-Authenticate"] = 'Basic realm="Restricted"'
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
        return
    end

    local provided_user, provided_pass = decoded:match("^([^:]+):(.+)$")
    if not provided_user or not provided_pass then
        ngx.header["WWW-Authenticate"] = 'Basic realm="Restricted"'
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
        return
    end

    for entry in auth_entries_str:gmatch("%S+") do
        local user, stored_hash = entry:match("^([^:]+):(.+)$")
        if user and stored_hash and user == provided_user then
            local sha_hash = stored_hash:match("^{SHA}(.+)$")
            if sha_hash then
                local computed = ngx.encode_base64(ngx.sha1_bin(provided_pass))
                if constant_time_compare(computed, sha_hash) then
                    return
                end
            else
                if constant_time_compare(stored_hash, provided_pass) then
                    return
                end
            end
        end
    end

    ngx.header["WWW-Authenticate"] = 'Basic realm="Restricted"'
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

return _M
