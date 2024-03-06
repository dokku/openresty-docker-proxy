module('allow_domain', package.seeall)

-- allowed is a function that returns true if the domain is allowed to have letsencrypt certificates issued
function allowed(domain)
    return true
end
